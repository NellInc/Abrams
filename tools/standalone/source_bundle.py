#!/usr/bin/env python3
"""Archive verified, locally patched DOSBox Pure corresponding source, offline.

Reads Git objects and regular source files only. Never builds, downloads, changes
source, or includes the compiled core. Outputs are exclusive and deterministic.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import stat
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
UPSTREAM = '73e03aa145e0549ed4d5a20f8e65532714da33f5'
UPSTREAM_URL = 'https://github.com/schellingb/dosbox-pure'
PREFIX = 'dosbox-pure-abrams-source'
PATCHED = {
    'src/dos/drives.h', 'src/dos/drive_union.cpp',
    'src/hardware/vga_draw.cpp', 'src/hardware/vga_memory.cpp',
    'dosbox_pure_libretro.cpp',
}
HEADERS = {
    'src/cpu/abrams_trace.h': 'trace_header_sha256',
    'src/cpu/abrams_vga_ownership.h': 'ownership_header_sha256',
    'src/cpu/abrams_plate_ownership.h': 'plate_ownership_header_sha256',
    'src/cpu/abrams_observer_checkpoint.h': 'observer_checkpoint_header_sha256',
    'src/dos/abrams_state_overlay.h': 'state_overlay_header_sha256',
}
ORIGINAL_ARCHIVE_SHA = 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05'
ROM_SHA = 'ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encoded(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def git(source, *args):
    return subprocess.check_output(['git', '-C', str(source), *args])


def validate_name(name):
    parts = name.split('/')
    banned = {'.git', '.runtime', '.ssh', 'game', 'rom', 'roms', 'saves',
              'states', 'private', 'build', 'obj', '__pycache__'}
    suffixes = {'.exe', '.com', '.dll', '.dylib', '.so', '.a', '.o', '.obj',
                '.zip', '.rom', '.sav', '.state', '.env', '.pem', '.key'}
    if (not name or '\\' in name or any(ord(c) < 32 for c in name)
            or any(p in ('', '.', '..') for p in parts)
            or any(p.lower() in banned or p.lower().startswith('.env') for p in parts)
            or PurePosixPath(name).suffix.lower() in suffixes):
        raise ValueError('Unsafe source name: ' + name)


def regular_bytes(base, name):
    validate_name(name)
    path = base
    for part in name.split('/'):
        path = path / part
        if path.is_symlink():
            raise ValueError('Symlink source input: ' + name)
    if not path.is_file() or not stat.S_ISREG(path.stat().st_mode):
        raise ValueError('Missing regular source input: ' + name)
    return path.read_bytes()


def collect(root):
    # Normalize the caller-selected root (macOS /var aliases /private/var);
    # links within the source and runtime inputs remain forbidden.
    root = root.resolve()
    source = root / '.runtime/dosbox-pure-source'
    if source.is_symlink():
        raise ValueError('Symlink source checkout')
    # Runtime input paths are deliberately outside the archive-name policy.
    receipt_path = root / '.runtime/pc-core/abrams-trace.json'
    core_path = root / '.runtime/pc-core/abrams-trace.dylib'
    for path in (receipt_path, core_path):
        if any(p.is_symlink() for p in (path, *path.parents)) or not path.is_file():
            raise ValueError('Core receipt/core must be regular non-symlink files')
    receipt_bytes = receipt_path.read_bytes()
    receipt = json.loads(receipt_bytes)
    if (receipt['commit'] != UPSTREAM or receipt['upstream'] != UPSTREAM_URL
            or git(source, 'rev-parse', 'HEAD').decode().strip() != UPSTREAM):
        raise ValueError('Unreviewed upstream identity')
    if digest(core_path.read_bytes()) != receipt['trace_sha256']:
        raise ValueError('Core fingerprint mismatch')
    if set(receipt['video_patch_hashes']) != PATCHED:
        raise ValueError('Unrecognized source patch set')
    extra = set(git(source, 'ls-files', '--others', '--exclude-standard', '-z').decode().split('\0')) - {''}
    if extra - HEADERS.keys():
        raise ValueError('Unrecognized untracked source files: ' + repr(sorted(extra - HEADERS.keys())))
    # Read the complete commit tree, not a suffix allowlist that could omit
    # vendored source, resources, copyright notices or platform build files.
    tracked = {}
    for row in git(source, 'ls-tree', '-rz', UPSTREAM).split(b'\0'):
        if not row:
            continue
        metadata, raw_name = row.split(b'\t', 1)
        mode, kind, _ = metadata.decode().split()
        name = raw_name.decode()
        validate_name(name)
        if kind != 'blob' or mode not in ('100644', '100755'):
            raise ValueError('Non-regular upstream entry: ' + name)
        tracked[name] = int(mode, 8) & 0o777
    if not {'LICENSE', 'Makefile', 'README.md', 'src/cpu/core_normal.cpp'} <= tracked.keys():
        raise ValueError('Missing upstream source/build/license closure')
    with tarfile.open(fileobj=io.BytesIO(git(source, 'archive', '--format=tar', UPSTREAM))) as archive:
        originals = {item.name: archive.extractfile(item).read()
                     for item in archive.getmembers() if item.isfile()}
    if set(originals) != set(tracked):
        raise ValueError('Upstream archive/tree disagreement')
    patches = dict(receipt['video_patch_hashes'])
    patches['src/cpu/core_normal.cpp'] = {
        'original': receipt['source_core_normal_sha256'],
        'patched': receipt['patched_core_normal_sha256'],
    }
    banned = {ORIGINAL_ARCHIVE_SHA, ROM_SHA}
    banned.update(row['sha256'] for row in json.loads(
        (root / 'tools/package/game-inputs.json').read_text())['files'])
    files = {}
    for name, mode in sorted(tracked.items()):
        current = regular_bytes(source, name)
        if name in patches:
            if (digest(originals[name]) != patches[name]['original']
                    or digest(current) != patches[name]['patched']):
                raise ValueError('Patched source fingerprint mismatch: ' + name)
        elif current != originals[name]:
            raise ValueError('Unrecognized tracked source changes: ' + name)
        files['source/' + name] = (current, mode)
    for name, key in HEADERS.items():
        current = regular_bytes(source, name)
        authored = regular_bytes(root, 'tools/pc_core/' + PurePosixPath(name).name)
        if digest(current) != receipt[key] or current != authored:
            raise ValueError('Header fingerprint mismatch: ' + name)
        files['source/' + name] = (current, 0o644)
    for name, (data, _) in files.items():
        if digest(data) in banned:
            raise ValueError('Original game input detected: ' + name)
        if data[:4] in (b'\x7fELF', b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xca\xfe\xba\xbe') or data[:2] == b'MZ':
            raise ValueError('Compiled executable detected: ' + name)
    readme = f'''# DOSBox Pure: Abrams corresponding source

Upstream: {UPSTREAM_URL}
Upstream commit: {UPSTREAM}
Corresponding compiled core SHA-256: {receipt['trace_sha256']}

The source/ directory contains every tracked upstream file at this commit,
with the local source modifications recorded in CORE-BUILD.json and five
additional Abrams headers. All upstream licence and copyright notices remain
in their original files, including source/LICENSE, DOSBOX-AUTHORS and
DOSBOX-THANKS. DOSBox Pure and the Abrams modifications are GPL-2.0-or-later;
retain applicable component notices in source files when redistributing.

Local changes add instruction/render observation, VGA and plate ownership,
video presentation/raster callbacks, and observer checkpoint/save-overlay
interfaces. The complete modified files and added headers are included.
SOURCE-FILES.json records every included source file's SHA-256 and mode.
CORE-BUILD.json is the original compiled-core build receipt.

## Build on macOS ARM64

Install Apple's command-line developer tools (make and a C++ compiler), unpack
this archive into a new directory, then run:

    cd source
    make -j4

The output is dosbox_pure_libretro.dylib. The recorded compiler was:
{receipt['compiler']}
The distributed binary is named abrams-trace.dylib. No patching step, game
installation, ROM, save data, baseline binary or network download is required
to compile this supplied patched source. See source/README.md and Makefile for
upstream build instructions and other target platforms. Recompilation was not
performed during archive creation; matching the recorded binary byte-for-byte
also depends on the original toolchain and build environment.

This archive contains emulator source and upstream resources only. It contains
no original Abrams game files or game ROM and confers no rights to those works.
'''
    rows = [{'path': name, 'sha256': digest(data), 'size': len(data), 'mode': mode}
            for name, (data, mode) in sorted(files.items())]
    inventory = {'schema': 1, 'upstream_commit': UPSTREAM,
                 'core_sha256': receipt['trace_sha256'], 'files': rows}
    files['SOURCE-FILES.json'] = (encoded(inventory), 0o644)
    files['CORE-BUILD.json'] = (receipt_bytes, 0o644)
    files['README.md'] = (readme.encode(), 0o644)
    return files, inventory


def build(root, output):
    if output.exists() or output.is_symlink():
        raise ValueError('Output must be a new exclusive path')
    files, inventory = collect(root)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open('xb') as stream:
        with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
                for name, (data, mode) in sorted(files.items()):
                    info = tarfile.TarInfo(PREFIX + '/' + name)
                    info.size = len(data)
                    info.mode = mode
                    info.mtime = info.uid = info.gid = 0
                    info.uname = info.gname = ''
                    archive.addfile(info, io.BytesIO(data))
    return {'schema': 1, 'archive_sha256': digest(output.read_bytes()),
            'archive_bytes': output.stat().st_size, 'members': len(files),
            'source_files': len(inventory['files']), 'upstream_commit': UPSTREAM,
            'core_sha256': inventory['core_sha256'],
            'source_inventory_sha256': digest(encoded(inventory)),
            'originals_included': False, 'rebuilt': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(ROOT, args.output), sort_keys=True, indent=2))


if __name__ == '__main__':
    main()
