#!/usr/bin/env python3
"""Assemble the browser remaster under the isolated project webpage."""
from __future__ import annotations

import hashlib
import contextlib
import fcntl
import io
import json
import os
import re
import stat
import tempfile
from pathlib import Path
import shutil
import zipfile
from build_remaster_assets import generated_lock

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'web-prototype'
TARGET = ROOT / 'website/dist/play'
LOCAL_LOCK = '.generated/.abrams-build.lock'
RUNTIME = (
    'build-info.json', 'core.js', 'core.wasm', 'game-inputs.json',
    'genesis-input.json', 'python-source.zip', 'remaster-assets.json',
    'web-core-corresponding-source.tar.gz',
)
GODOT = (
    'index.js', 'index.wasm', 'index.pck', 'index.icon.png',
    'index.audio.worklet.js', 'index.audio.position.worklet.js',
)
PYODIDE = (
    'pyodide.mjs', 'pyodide.asm.js', 'pyodide.asm.wasm',
    'python_stdlib.zip', 'pyodide-lock.json',
    'pillow-11.3.0-cp313-cp313-pyemscripten_2025_0_wasm32.whl',
)
APP = (
    'remaster.html', 'remaster.mjs', 'remaster.service.worker.js',
    'THIRD_PARTY.txt',
    'style.css', 'bridge_host.mjs', 'bridge_worker.mjs', 'core_worker.mjs',
    'browser_observer.mjs', 'checkpoint_core.mjs', 'zip_store.mjs',
    'claim_catalog.mjs', 'remaster_assets.mjs', 'derived_art.mjs',
    'assets/Barlow-OFL.txt', 'assets/BarlowCondensed-SemiBold-latin.woff2',
)

# Licence and notice texts published beside the app. Each font the Godot PCK
# embeds needs its OFL text here or in APP (test_package_site checks this).
LICENSES = {
    'LICENSES/GPL-2.0.txt': ROOT / 'LICENSES/GPL-2.0.txt',
    **{'LICENSES/' + name: SOURCE / 'LICENSES' / name
       for name in ('Godot-4.7.2.json', 'Pyodide-MPL-2.0.txt',
                    'CPython-3.13.2.txt', 'Pillow-11.3.0.txt')},
    'LICENSES/IBM-Plex-OFL.txt': ROOT / 'godot/assets/fonts/Plex-OFL.txt',
    'NOTICE.txt': ROOT / 'NOTICE.md',
}


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def observer_drift(archive_path: Path) -> list[str]:
    """Observer members whose packaged bytes differ from the working tree.

    python-source.zip carries the Python observer that produces every packet
    Godot consumes; it must be built from the same sources as index.pck.
    """
    from build_observer import write_source_archive
    expected = io.BytesIO()
    write_source_archive(expected)
    def members(source):
        with zipfile.ZipFile(source) as archive:
            # Later duplicate names win, exactly as zipfile and Pyodide read them.
            return {item.filename: archive.read(item) for item in archive.infolist()}
    wanted, packaged = members(expected), members(archive_path)
    return sorted(name for name in wanted.keys() | packaged.keys() if wanted.get(name) != packaged.get(name))


def local_lock_identity(path: Path) -> tuple | None:
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    if not stat.S_ISREG(info.st_mode):
        raise SystemExit('Refusing an invalid local browser build lock')
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_mode


@contextlib.contextmanager
def retained_lock(target: Path):
    path = target / LOCAL_LOCK
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW)
    except FileNotFoundError:
        yield None
        return
    except OSError as error:
        raise SystemExit('Refusing an invalid local browser build lock') from error
    try:
        info = os.fstat(fd)
        identity = (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_mode)
        if not stat.S_ISREG(info.st_mode):
            raise SystemExit('Refusing an invalid local browser build lock')
        if local_lock_identity(path) != identity:
            raise SystemExit('Local browser build lock changed')
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise SystemExit('Local browser build lock is in use') from error
        yield identity
    finally:
        os.close(fd)


def verify_owned(target: Path) -> bytes | None:
    if not target.exists():
        return None
    if target.is_symlink():
        raise SystemExit('Refusing to replace a symlinked browser site')
    manifest_path = target / 'BUNDLE.json'
    if not manifest_path.is_file():
        raise SystemExit('Refusing to replace an unowned browser site directory')
    raw = manifest_path.read_bytes()
    previous = json.loads(raw)
    records = previous.get('files', {})
    actual = {p.relative_to(target).as_posix() for p in target.rglob('*') if p.is_file()}
    if local_lock_identity(target / LOCAL_LOCK) is not None:
        actual.discard(LOCAL_LOCK)
    if LOCAL_LOCK in records:
        raise SystemExit('Local browser build lock cannot be published')
    if previous.get('schema') != 1 or not isinstance(records, dict) or set(records) | {'BUNDLE.json'} != actual or any(p.is_symlink() for p in target.rglob('*')):
        raise SystemExit('Refusing to replace changed browser site files')
    for name, row in records.items():
        path = target / name
        if not isinstance(row, dict) or path.stat().st_size != row.get('bytes') or sha(path) != row.get('sha256'):
            raise SystemExit(f'Refusing to replace changed browser site file: {name}')
    return raw


def install_bundle(inputs: dict[str, Path], target: Path, expected: dict | None = None) -> dict:
    with retained_lock(target) as lock:
        return _install_bundle(inputs, target, expected, lock)


def _install_bundle(inputs: dict[str, Path], target: Path, expected: dict | None, lock: tuple | None) -> dict:
    # Stage then promote with rollback. The two renames are not a no-gap exchange.
    # A copy/space/hash failure leaves it untouched; a failed rename restores it.
    target.parent.mkdir(parents=True, exist_ok=True)
    previous_manifest = verify_owned(target)
    for name in inputs:
        if not re.fullmatch(r'[A-Za-z0-9_./-]+', name) or any(p in ('', '.', '..') for p in name.split('/')) or name in ('BUNDLE.json', LOCAL_LOCK):
            raise SystemExit(f'Unsafe browser bundle path: {name}')
    temporary = Path(tempfile.mkdtemp(prefix='.abrams-play-', dir=target.parent))
    retain_backup = False
    try:
        staging = temporary / 'candidate'
        backup = temporary / 'previous'
        staging.mkdir()
        records = {}
        for name, path in sorted(inputs.items()):
            destination = staging / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            identity = path.stat()
            shutil.copy2(path, destination)
            after = path.stat()
            if (identity.st_ino, identity.st_size, identity.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
                raise SystemExit(f'Browser input changed during packaging: {name}')
            records[name] = {'bytes': destination.stat().st_size, 'sha256': sha(destination)}
        for name, wanted in (expected or {}).items():
            if name not in records or not isinstance(wanted, dict) or any(records[name].get(key) != value for key, value in wanted.items()):
                raise SystemExit(f'Browser input differs from its build manifest: {name}')
        if lock is not None:
            preserved = staging / LOCAL_LOCK
            preserved.parent.mkdir(parents=True, exist_ok=True)
            os.link(target / LOCAL_LOCK, preserved, follow_symlinks=False)
            if local_lock_identity(preserved) != lock:
                raise SystemExit('Local browser build lock changed during packaging')
        (staging / 'BUNDLE.json').write_text(json.dumps({
            'schema': 1, 'original_pc_files_included': False,
            'files': records}, indent=2, sort_keys=True) + '\n')
        # Recheck ownership immediately before the swap, including all file hashes.
        if verify_owned(target) != previous_manifest or local_lock_identity(target / LOCAL_LOCK) != lock:
            raise SystemExit('Browser site changed during packaging; previous build retained')
        moved = False
        if previous_manifest is not None:
            target.replace(backup)
            moved = True
        try:
            staging.replace(target)
        except BaseException:
            if moved:
                try:
                    backup.replace(target)
                except BaseException as recovery_error:
                    retain_backup = True
                    raise RuntimeError(f'Browser bundle replacement failed; accepted build retained at {backup}') from recovery_error
            raise
    finally:
        if not retain_backup:
            shutil.rmtree(temporary)
    return records


def _main() -> None:
    generated = SOURCE / '.generated'
    asset_manifest = json.loads((generated / 'remaster-assets.json').read_text())
    if asset_manifest.get('schema') != 3 or not isinstance(asset_manifest.get('parts'), list):
        raise SystemExit('Build the remaster assets before packaging the site')
    drift = observer_drift(generated / 'python-source.zip')
    if drift:
        raise SystemExit('python-source.zip differs from the working-tree observer (' + ', '.join(drift[:5]) +
                         (', …' if len(drift) > 5 else '') + '); rebuild it with web-prototype/build_observer.py')
    names = [part.get('name') for part in asset_manifest['parts'] if isinstance(part, dict)]
    if not names or len(names) != len(asset_manifest['parts']) or any(not isinstance(name, str) or not re.fullmatch(r'remaster-assets-\d{2}\.zip', name) for name in names) or len(set(names)) != len(names):
        raise SystemExit('Unsafe remaster asset part manifest')
    expected = {}
    for part in asset_manifest['parts']:
        if type(part.get('bytes')) is not int or not 22 <= part['bytes'] <= 48_000_000 or not isinstance(part.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}', part['sha256']):
            raise SystemExit('Invalid remaster asset part identity')
        expected['.generated/' + part['name']] = {'bytes': part['bytes'], 'sha256': part['sha256']}
    build_info = json.loads((generated / 'build-info.json').read_text())
    identity = build_info.get('wasm_sha256')
    if not isinstance(identity, str) or not re.fullmatch(r'[0-9a-f]{64}', identity):
        raise SystemExit('Invalid Web core build identity')
    expected['.generated/core.wasm'] = {'sha256': identity}
    inputs = {name: SOURCE / name for name in APP}
    inputs.update({'.generated/' + name: generated / name for name in RUNTIME})
    inputs.update({'.generated/' + part['name']: generated / part['name']
                   for part in asset_manifest['parts']})
    inputs.update({'.generated/godot/' + name: generated / 'godot' / name
                   for name in GODOT})
    inputs.update({'.generated/pyodide/' + name: generated / 'pyodide' / name
                   for name in PYODIDE})
    inputs.update(LICENSES)
    for name, path in inputs.items():
        if not path.is_file() or path.is_symlink() or path.stat().st_size >= 100_000_000:
            raise SystemExit(f'Unsafe or missing browser publication file: {name}')
    records = install_bundle(inputs, TARGET, expected)
    print(f'Packaged {len(records)} browser files ({sum(r["bytes"] for r in records.values())} bytes) under website/dist/play')


def main() -> None:
    # Snapshot readers cooperate with export/asset promotion; never package a
    # partially replaced generated set. The accepted website swap stays intact.
    with generated_lock(SOURCE / '.generated', exclusive=False):
        _main()


if __name__ == '__main__':
    main()
