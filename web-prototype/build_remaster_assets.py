#!/usr/bin/env python3
"""Stage authored presentation assets for local Godot Web QA.

The visitor's PC game and optional Genesis ROM are never read by this builder.
Only files loaded by the desktop Play presentation are eligible.
"""
from pathlib import Path
from contextlib import contextmanager
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.standalone.runtime import ROM_SHA
OUT = ROOT / 'web-prototype/.generated'
KINDS = {'.png', '.json', '.ttf', '.gpl', '.svg'}
MAX_PART_BYTES = 48_000_000
GODOT_FILES = ('index.js', 'index.wasm', 'index.pck', 'index.icon.png',
               'index.audio.worklet.js', 'index.audio.position.worklet.js')
STALE_GODOT_FILES = ('index.html', 'index.service.worker.js', 'index.manifest.json',
                     'index.offline.html', 'index.144x144.png', 'index.180x180.png',
                     'index.512x512.png')
RUNTIME_JSON = {
    'docs/player-reference/manual-content.json',
    'docs/player-reference/visuals.json',
    'docs/player-reference/credits.json',
    'local-art/genesis/source/effects-v1/effects.json',
    'local-art/genesis/status-damage-v1/manifest.json',
    'local-art/pc-arming-panel-v1/arming-panel.json',
    'local-art/pc-frontend-v1/office.json',
    'local-art/pc-graphics-native-v1/graphics.json',
    'local-art/pc-information-completion-v1/information.json',
    'local-art/pc-information-v3/information.json',
    'local-art/pc-intro-v2/intro.json',
    'local-art/pc-map-frame-v1/frame.json',
    'local-art/pc-modern/catalog.json',
    'local-art/pc-modern/tree.json',
    'local-art/pc-motor-pool-v1/motor-pool.json',
    'local-art/pc-newspapers-v1/newspapers.json',
    'local-art/pc-outline-fonts-v5/manifest.json',
    'local-art/pc-portraits-v1/faces.json',
    'local-art/pc-splash-aftermath-v1/catalog.json',
    'local-art/pc-wilson-completion-v1/office.json',
    'local-audio/frontend-music-v1/manifest.json',
}


def selected():
    # The desktop kit already has a reviewed asset allowlist. Packaging every
    # file in local-art also published donor captures, rejected studies and
    # authoring prompts that Play never reads.
    inventory = json.loads((ROOT / 'tools/package/allowlist.json').read_text())
    reviewed = inventory['private']
    names = {name for name in reviewed if name.startswith((
        'local-art/', 'local-audio/frontend-music-v1/', 'docs/player-reference/',
        'reference/genesis/extracted/gunner/palette.gpl', 'branding/abrams-cover-remastered.png'))}
    # Newer Play art has not yet entered the prior private-alpha allowlist.
    names.add('local-art/pc-ui-remastered/gunner-plate-v2.png')
    # The guide's three runtime indices are reviewed source, not private art.
    # Without them the illustrations install but the reader has no content.
    names.update(name for name in inventory['source']
                 if name.startswith('docs/player-reference/') and name in RUNTIME_JSON)
    for name in sorted(names):
        path = ROOT / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f'Missing or linked desktop presentation asset: {name}')
        if path.suffix.lower() == '.json' and name not in RUNTIME_JSON:
            continue
        if path.suffix.lower() in (KINDS | {'.wav'} if name.startswith('local-audio/') else KINDS):
            yield path


def fingerprint(path):
    if path.is_symlink() or not path.is_file():
        raise SystemExit(f'Missing or linked build file: {path}')
    stat = path.stat()
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    after = path.stat()
    identity = (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)
    if identity != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
        raise SystemExit(f'Build file changed while reading: {path}')
    return (*identity, digest.hexdigest())


@contextmanager
def generated_lock(out, exclusive=True):
    """Cooperating writers/readers hold one stable lock inode; never unlink it."""
    import fcntl  # These pinned local Web build tools run on POSIX hosts.
    if out.is_symlink() or (out.exists() and not out.is_dir()):
        raise SystemExit('Refusing a linked or non-directory generated target')
    out.mkdir(parents=True, exist_ok=True)
    descriptor = os.open(out / '.abrams-build.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        try:
            fcntl.flock(descriptor, (fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH) | fcntl.LOCK_NB)
        except BlockingIOError:
            raise SystemExit('Generated build is in use by another builder or packager')
        yield
    finally:
        os.close(descriptor)


def output_identity(out, include_godot=False):
    if out.is_symlink() or (out / 'godot').is_symlink():
        raise SystemExit('Refusing a linked generated target')
    names = {'remaster-assets.json', 'genesis-input.json', 'remaster-assets.zip'}
    names.update(p.name for p in out.glob('remaster-assets-*.zip')
                 if re.fullmatch(r'remaster-assets-\d{2}\.zip', p.name))
    if include_godot:
        names.update('godot/' + name for name in GODOT_FILES + STALE_GODOT_FILES)
    return {name: fingerprint(out / name) if (out / name).exists() or (out / name).is_symlink() else None
            for name in sorted(names)}


def install_outputs(inputs, out, expected, include_godot=False):
    """Recover handled failures, preserving unrelated generated files.

    Call under generated_lock. This is a guarded multi-file promotion, not
    atomic visibility or power-loss durability. An incomplete recovery retains
    its journal and backup. Working if: failed promotion restores old bytes,
    concurrent target edits are refused, and foreign generated files stay exact.
    """
    allowed = {'remaster-assets.json', 'genesis-input.json'}
    if include_godot: allowed.update('godot/' + name for name in GODOT_FILES)
    if not inputs or any(name not in allowed and not re.fullmatch(r'remaster-assets-\d{2}\.zip', name) for name in inputs):
        raise SystemExit('Unsafe generated output name')
    temporary = Path(tempfile.mkdtemp(prefix='.abrams-promotion-', dir=out))
    candidate, backup = temporary / 'candidate', temporary / 'previous'
    moved, installed, rows = [], [], {}
    retain = False
    try:
        for name, source in inputs.items():
            before = fingerprint(source)
            destination = candidate / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            if fingerprint(source) != before or fingerprint(destination)[-1] != before[-1]:
                raise SystemExit(f'Generated candidate changed during copying: {name}')
            rows[name] = {'bytes': before[2], 'sha256': before[-1]}
        if output_identity(out, include_godot) != expected:
            raise SystemExit('Generated target changed during building; previous build retained')
        # Persist recovery information before the first target mutation.
        journal = {'managed_before': expected, 'candidate': rows,
                   'moved': moved, 'installed': installed}
        def record():
            (temporary / 'recovery.json').write_text(json.dumps(journal, indent=2) + '\n')
        record()
        try:
            for name, identity in expected.items():
                if identity is not None:
                    saved = backup / name
                    saved.parent.mkdir(parents=True, exist_ok=True)
                    (out / name).replace(saved)
                    moved.append(name); record()
            for name in inputs:
                destination = out / name
                destination.parent.mkdir(parents=True, exist_ok=True)
                (candidate / name).replace(destination)
                installed.append(name); record()
        except BaseException as error:
            failures = []
            for name in reversed(installed):
                try:
                    path = out / name
                    if path.exists() and fingerprint(path)[-1] != rows[name]['sha256']:
                        raise RuntimeError('Installed output changed during recovery')
                    path.unlink(missing_ok=True)
                except BaseException as failure: failures.append(f'{name}: {failure}')
            for name in reversed(moved):
                try:
                    if (out / name).exists() or (out / name).is_symlink():
                        raise RuntimeError('Recovery destination is occupied')
                    (backup / name).replace(out / name)
                except BaseException as failure: failures.append(f'{name}: {failure}')
            if failures:
                retain = True
                raise RuntimeError(f'Generated replacement failed; recovery retained at {temporary}: {failures}') from error
            raise
    finally:
        if not retain: shutil.rmtree(temporary)
    return rows


def stage_assets(out):
    out.mkdir(parents=True, exist_ok=True)
    control = ROOT / 'tools/package/allowlist.json'
    control_identity = fingerprint(control)
    paths = list(selected())
    if not 1 <= len(paths) <= 10000:
        raise SystemExit('Authored asset inventory is empty or exceeds its consumer limit')
    identities = {path: fingerprint(path) for path in paths}
    # Keep every static-hosting object below ordinary Git's 100 MB limit.
    # Entry-aligned ZIP parts can be loaded one at a time in the browser.
    parts = []
    manifest = []
    bundle = None
    archive = None
    part_bytes = 0
    def finish_part():
        nonlocal bundle
        if bundle is None:
            return
        bundle.close()
        if not 22 <= archive.stat().st_size <= MAX_PART_BYTES:
            raise SystemExit('Completed authored asset part exceeds its Web limit')
        parts.append({'name': archive.name, 'bytes': archive.stat().st_size,
                      'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()})
        bundle = None
    try:
        for path in paths:
            name = path.relative_to(ROOT).as_posix()
            if not re.fullmatch(r'[A-Za-z0-9_./-]+', name) or any(p in ('', '.', '..') for p in name.split('/')) or name.startswith(('GAME/', 'GENESIS/')):
                raise SystemExit(f'Unsafe authored asset path: {name}')
            raw = path.read_bytes()
            if fingerprint(path) != identities[path] or hashlib.sha256(raw).hexdigest() != identities[path][-1]:
                raise SystemExit(f'Authored asset changed during building: {name}')
            estimated = len(raw) + 100 + 2 * len(name.encode())
            if estimated + 22 > MAX_PART_BYTES:
                raise SystemExit(f'One authored asset exceeds a Web part: {name}')
            if bundle is None or part_bytes + estimated > MAX_PART_BYTES:
                finish_part()
                if len(parts) >= 100: raise SystemExit('Too many authored asset parts')
                archive = out / f'remaster-assets-{len(parts):02d}.zip'
                bundle = zipfile.ZipFile(archive, 'w', zipfile.ZIP_STORED, allowZip64=False)
                part_bytes = 22
            bundle.writestr(name, raw)
            part_bytes += estimated
            manifest.append({'path': name, 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()})
        finish_part()
    finally:
        if bundle is not None: bundle.close()
    if fingerprint(control) != control_identity or list(selected()) != paths or any(fingerprint(p) != identities[p] for p in paths):
        raise SystemExit('Authored inventory changed during building; previous build retained')
    (out / 'remaster-assets.json').write_text(json.dumps({
        'schema': 2, 'parts': parts,
        'files': manifest}, separators=(',', ':')) + '\n')
    (out / 'genesis-input.json').write_text(json.dumps({
        'sha256': ROM_SHA, 'bytes': 524288}, separators=(',', ':')) + '\n')
    print(f'Staged {len(manifest)} authored files in {len(parts)} parts '
          f'({sum(part["bytes"] for part in parts)} bytes); no original PC game files')
    return {name: out / name for name in ['remaster-assets.json', 'genesis-input.json'] + [p['name'] for p in parts]}


def main():
    with generated_lock(OUT):
        expected = output_identity(OUT)
        with tempfile.TemporaryDirectory(prefix='.abrams-assets-', dir=OUT) as workspace:
            inputs = stage_assets(Path(workspace))
            install_outputs(inputs, OUT, expected)


if __name__ == '__main__':
    main()
