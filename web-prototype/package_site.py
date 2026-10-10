#!/usr/bin/env python3
"""Assemble the browser remaster under the isolated project webpage."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'web-prototype'
TARGET = ROOT / 'website/dist/play'
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
    'style.css', 'bridge_host.mjs', 'bridge_worker.mjs',
    'browser_observer.mjs', 'checkpoint_core.mjs', 'zip_store.mjs',
    'claim_catalog.mjs', 'remaster_assets.mjs',
    'assets/Barlow-OFL.txt', 'assets/BarlowCondensed-SemiBold-latin.woff2',
)


def sha(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    generated = SOURCE / '.generated'
    asset_manifest = json.loads((generated / 'remaster-assets.json').read_text())
    if asset_manifest.get('schema') != 2:
        raise SystemExit('Build the remaster assets before packaging the site')
    inputs = {name: SOURCE / name for name in APP}
    inputs.update({'.generated/' + name: generated / name for name in RUNTIME})
    inputs.update({'.generated/' + part['name']: generated / part['name']
                   for part in asset_manifest['parts']})
    inputs.update({'.generated/godot/' + name: generated / 'godot' / name
                   for name in GODOT})
    inputs.update({'.generated/pyodide/' + name: generated / 'pyodide' / name
                   for name in PYODIDE})
    inputs['LICENSES/GPL-2.0.txt'] = ROOT / 'LICENSES/GPL-2.0.txt'
    inputs['NOTICE.txt'] = ROOT / 'NOTICE.md'
    for name, path in inputs.items():
        if not path.is_file() or path.is_symlink() or path.stat().st_size >= 100_000_000:
            raise SystemExit(f'Unsafe or missing browser publication file: {name}')
    if TARGET.exists():
        manifest_path = TARGET / 'BUNDLE.json'
        if not manifest_path.is_file():
            raise SystemExit('Refusing to replace an unowned browser site directory')
        previous = json.loads(manifest_path.read_text())
        allowed = set(previous.get('files', {})) | {'BUNDLE.json'}
        actual = {p.relative_to(TARGET).as_posix() for p in TARGET.rglob('*') if p.is_file()}
        if previous.get('schema') != 1 or allowed != actual or any(p.is_symlink() for p in TARGET.rglob('*')):
            raise SystemExit('Refusing to replace changed browser site files')
        shutil.rmtree(TARGET)
    TARGET.mkdir(parents=True)
    records = {}
    for name, path in sorted(inputs.items()):
        destination = TARGET / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, destination)
        records[name] = {'bytes': destination.stat().st_size, 'sha256': sha(destination)}
    (TARGET / 'BUNDLE.json').write_text(json.dumps({
        'schema': 1, 'original_pc_files_included': False,
        'files': records}, indent=2, sort_keys=True) + '\n')
    print(f'Packaged {len(records)} browser files ({sum(r["bytes"] for r in records.values())} bytes) under website/dist/play')


if __name__ == '__main__':
    main()
