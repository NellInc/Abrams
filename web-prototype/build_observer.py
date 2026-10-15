#!/usr/bin/env python3
"""Stage the pinned Pyodide runtime and authored Python observer for local Web QA.

The resulting directory contains code only. Original game data is supplied by
each visitor and never copied into this package.
"""
from pathlib import Path
import io
import shutil
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PYODIDE = ROOT / '.runtime/pyodide/node_modules/pyodide'
OUTPUT = ROOT / 'web-prototype/.generated'
NAMES = (
    'pyodide.mjs', 'pyodide.asm.js', 'pyodide.asm.wasm', 'python_stdlib.zip',
    'pyodide-lock.json',
    'pillow-11.3.0-cp313-cp313-pyemscripten_2025_0_wasm32.whl',
)


def write_source_archive(stream) -> None:
    """Write python-source.zip: the observer and the desktop tools it reuses."""
    with zipfile.ZipFile(stream, 'w', zipfile.ZIP_DEFLATED) as archive:
        archive.writestr('tools/__init__.py', '')
        for source in sorted((ROOT / 'tools').glob('*.py')):
            archive.write(source, 'tools/' + source.name)
        for source in sorted((ROOT / 'godot/data').glob('*.json')):
            archive.write(source, 'godot/data/' + source.name)
        archive.write(ROOT / 'web-prototype/browser_observer.py', 'browser_observer.py')


def main():
    if sys.argv[1:] == ['--source-zip-stdout']:
        # Integration tests consume the working-tree observer without
        # replacing the generated site input.
        buffer = io.BytesIO()
        write_source_archive(buffer)
        sys.stdout.buffer.write(buffer.getvalue())
        return
    if sys.argv[1:]:
        raise SystemExit('usage: build_observer.py [--source-zip-stdout]')
    if not all((PYODIDE / name).is_file() for name in NAMES):
        raise SystemExit('Install pinned Pyodide 0.29.5 and Pillow into .runtime/pyodide first')
    target = OUTPUT / 'pyodide'
    target.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        shutil.copy2(PYODIDE / name, target / name)
    with (OUTPUT / 'python-source.zip').open('wb') as stream:
        write_source_archive(stream)
    print('Staged self-hosted Pyodide and observer source without original game files')


if __name__ == '__main__':
    main()
