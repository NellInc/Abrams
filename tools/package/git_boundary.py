#!/usr/bin/env python3
"""Read-only index/history guard. Never prints matching credential contents."""
from __future__ import annotations
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
MAX_BYTES = 50_000_000
PRIVATE_PARTS = {'.runtime', '.godot', '.git', 'game', 'genesis', 'reference',
                 'local-art', 'local-audio', 'artifacts', 'capture', 'saves', 'states',
                 '__pycache__', 'builds', '.ssh', '.aws'}
BINARY_SUFFIXES = {'.rom', '.smd', '.bin', '.exe', '.com', '.dylib', '.dll', '.so',
                   '.state', '.zip', '.7z', '.rar', '.pyc', '.p12', '.pfx', '.pem', '.key'}
SECRET_PATTERNS = [
    re.compile(rb'-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----'),
    re.compile(rb'\bgh[pousr]_[A-Za-z0-9]{36,}\b'),
    re.compile(rb'\bgithub_pat_[A-Za-z0-9_]{70,}\b'),
    re.compile(rb'\bAKIA[0-9A-Z]{16}\b'),
    re.compile(rb'\bsk-(?:proj-)?[A-Za-z0-9_-]{32,}\b'),
]
WEB_GENERATED = 'website/dist/play/.generated/'
WEB_ZIPS = {'python-source.zip', 'pyodide/python_stdlib.zip'}
WEB_ASSET_ZIP = re.compile(r'remaster-assets-[0-9]{2}\.zip\Z')
WEB_WASM = WEB_GENERATED + 'godot/index.wasm'
WEB_WASM_SHA256 = 'fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0'


def limit_text():
    # Read at call time so the reported limit always matches the enforced one.
    return f'{MAX_BYTES // 1_000_000} MB' if MAX_BYTES % 1_000_000 == 0 else f'{MAX_BYTES:,} bytes'


def web_zip_kind(name):
    if not name.startswith(WEB_GENERATED):
        return None
    suffix = name[len(WEB_GENERATED):]
    if suffix in WEB_ZIPS:
        return 'source'
    if WEB_ASSET_ZIP.fullmatch(suffix):
        return 'assets'
    return None


def public_asset_member(name):
    path = PurePosixPath(name)
    if (any(part.startswith('.env') or part.endswith('.env') for part in path.parts) or
            path.name.lower() in {'credentials', 'id_rsa', 'id_ed25519'} or
            path.suffix.lower() not in {'.png', '.svg', '.ttf', '.json', '.wav', '.gpl'}):
        return False
    return (name.startswith(('branding/', 'docs/player-reference/', 'local-art/',
                             'local-audio/frontend-music-v1/')) or
            name == 'reference/genesis/extracted/gunner/palette.gpl')


def path_problem(name):
    p = PurePosixPath(name)
    parts = [part.lower() for part in p.parts]
    if ('\\' in name or p.is_absolute() or '..' in parts or str(p) != name
            or any(ord(c) < 32 for c in name)):
        return 'unsafe path'
    if any(part in PRIVATE_PARTS or part.startswith('.env') or part.endswith('.env') for part in parts):
        return 'private directory or environment file'
    if (p.suffix.lower() in BINARY_SUFFIXES and not web_zip_kind(name)) or p.name.lower() in {'credentials', 'id_rsa', 'id_ed25519'}:
        return 'original/runtime/archive/credential format'
    return None


def known_inputs():
    records = json.loads((ROOT / 'tools/package/game-inputs.json').read_text())['files']
    # Reuse the existing canonical ROM pin without importing optional libraries.
    text = (ROOT / 'tools/extract_genesis_samples.py').read_text()
    rom = re.search(r'^ROM_HASH = "([0-9a-f]{64})"$', text, re.MULTILINE)
    if not rom:
        raise ValueError('Canonical Genesis ROM pin missing')
    from tools.package_setup import CONTENT_SHA
    return {r['sha256'] for r in records} | {rom[1], CONTENT_SHA}


def inspect_public_web_zip(data, kind, known_hashes):
    """Inspect published archive members instead of exempting opaque ZIP bytes."""
    try:
        with zipfile.ZipFile(BytesIO(data)) as archive:
            members = archive.infolist()
            if len(members) != len({item.filename for item in members}):
                return 'unsafe browser archive member'
            total = 0
            for item in members:
                name = item.filename.rstrip('/')
                member_problem = path_problem(name) if name else 'unsafe path'
                if member_problem and not (kind == 'assets' and
                                           member_problem == 'private directory or environment file' and
                                           public_asset_member(name)):
                    return 'unsafe browser archive member'
                if kind == 'assets' and not public_asset_member(name):
                    return 'unreviewed browser asset path'
                if (item.flag_bits & 1 or item.compress_type not in
                        {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED} or
                        stat.S_ISLNK(item.external_attr >> 16)):
                    return 'unsafe browser archive member'
                if item.is_dir():
                    continue
                total += item.file_size
                if item.file_size > MAX_BYTES or total > 2 * MAX_BYTES:
                    return 'browser archive expands beyond bound'
                problem = inspect_blob(archive.read(item), known_hashes)
                if problem:
                    return f'browser archive member: {problem}'
    except (OSError, RuntimeError, ValueError, zipfile.BadZipFile, NotImplementedError):
        return 'invalid browser archive'
    return None


def inspect_blob(data, known_hashes, name=None):
    if len(data) > MAX_BYTES:
        return f'file exceeds {limit_text()}'
    # An original zero-byte marker is indistinguishable from harmless empty
    # Python package markers; it carries no original game content.
    if data and hashlib.sha256(data).hexdigest() in known_hashes:
        return 'fingerprinted original game/ROM/content archive'
    kind = web_zip_kind(name) if name else None
    if kind:
        return inspect_public_web_zip(data, kind, known_hashes)
    # This exact pinned Godot 4.7.2 binary includes a false-positive key
    # header sequence. New engine bytes must be reviewed rather than bypassed.
    if name == WEB_WASM and hashlib.sha256(data).hexdigest() == WEB_WASM_SHA256:
        return None
    if any(pattern.search(data) for pattern in SECRET_PATTERNS):
        return 'credential signature'
    return None


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args])


def check(root, history=False, known_hashes=None):
    known_hashes = known_inputs() if known_hashes is None else known_hashes
    entries = set()
    for record in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if record:
            meta, name = record.split(b'\t', 1)
            mode, oid, stage = meta.decode().split()
            if stage != '0':
                raise ValueError('Resolve conflicted index before boundary validation')
            entries.add((mode, oid, name.decode('utf-8', 'surrogateescape')))
    if history:
        if git(root, 'rev-parse', '--is-shallow-repository').strip() == b'true':
            raise ValueError('Full history required; shallow checkout cannot prove the boundary')
        for commit in git(root, 'rev-list', '--all').splitlines():
            for record in git(root, 'ls-tree', '-r', '-z', commit.decode()).split(b'\0'):
                if record:
                    meta, name = record.split(b'\t', 1)
                    mode, kind, oid = meta.decode().split()
                    entries.add((mode, oid, name.decode('utf-8', 'surrogateescape')))
    failures = set()
    blobs = {}
    for mode, oid, name in entries:
        problem = path_problem(name)
        if problem:
            failures.add((name, problem))
        if mode not in {'100644', '100755'}:
            failures.add((name, 'symlink, submodule or nonregular entry'))
        else:
            blobs.setdefault(oid, set()).add(name)
    if blobs:
        sizes = git_sizes(root, blobs)
        # Stream one bounded blob at a time; never materialize whole history.
        with subprocess.Popen(['git', '-C', str(root), 'cat-file', '--batch'],
                              stdin=subprocess.PIPE, stdout=subprocess.PIPE) as process:
            for oid, names in sorted(blobs.items()):
                if sizes[oid] > MAX_BYTES:
                    problem = f'file exceeds {limit_text()}'
                else:
                    process.stdin.write((oid + '\n').encode()); process.stdin.flush()
                    header = process.stdout.readline().split()
                    if len(header) != 3 or header[1] != b'blob':
                        raise ValueError('Git blob unavailable')
                    data = process.stdout.read(int(header[2]))
                    if process.stdout.read(1) != b'\n':
                        raise ValueError('Malformed git blob stream')
                    problem = None
                for name in names:
                    result = problem or inspect_blob(data, known_hashes, name)
                    if result:
                        failures.add((name, result))
            process.stdin.close()
            if process.wait() != 0:
                raise ValueError('Git object inspection failed')
    return sorted(failures)


def git_sizes(root, blobs):
    result = subprocess.run(['git', '-C', str(root), 'cat-file', '--batch-check=%(objectname) %(objecttype) %(objectsize)'],
                            input='\n'.join(blobs) + '\n', text=True, capture_output=True, check=True)
    sizes = {}
    for line in result.stdout.splitlines():
        oid, kind, size = line.split()
        if kind != 'blob':
            raise ValueError('Git object is not a blob')
        sizes[oid] = int(size)
    return sizes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--history', action='store_true', help='also scan all reachable local refs; requires full history')
    args = parser.parse_args()
    try:
        failures = check(ROOT, history=args.history)
        for name, reason in failures:
            print(f'{name!r}: {reason}')
        if failures:
            raise SystemExit(1)
        print('PASS: index' + (' and all reachable history' if args.history else '') + f' boundary ({limit_text()}; known inputs; credential signatures)')
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Boundary check failed: {error}\n')


if __name__ == '__main__':
    main()
