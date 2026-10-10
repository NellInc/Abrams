#!/usr/bin/env python3
"""Package the exact modified DOSBox Pure source used by the Web core."""
from __future__ import annotations

import gzip
import hashlib
import io
from pathlib import Path
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.standalone.source_bundle import collect

OUTPUT = ROOT / 'web-prototype/.generated/web-core-corresponding-source.tar.gz'


def main() -> None:
    files, _ = collect(ROOT)
    for name in ('core_frontend.cpp', 'claim_core.h', 'build_core.py'):
        path = ROOT / 'web-prototype' / name
        if not path.is_file() or path.is_symlink():
            raise SystemExit(f'Missing regular Web core source: {name}')
        files['web-prototype/' + name] = (path.read_bytes(), 0o644)
    inputs = ROOT / 'tools/package/game-inputs.json'
    files['tools/package/game-inputs.json'] = (inputs.read_bytes(), 0o644)
    core = ROOT / 'web-prototype/.generated/core.wasm'
    if not core.is_file():
        raise SystemExit('Build the Web core before its source archive')
    wasm_sha = hashlib.sha256(core.read_bytes()).hexdigest()
    files['WEB-BUILD.md'] = (f'''# Abrams Web core corresponding source

The `source/` tree is the pinned DOSBox Pure source, including every modified
upstream file and all five added observer headers. `web-prototype/` contains
the Web frontend, claim header and Emscripten build script. The original PC
game and Genesis ROM are not included or needed to compile this core.

Distributed core.wasm SHA-256: {wasm_sha}
Pinned upstream commit: 73e03aa145e0549ed4d5a20f8e65532714da33f5

To rebuild, place `source/` at `.runtime/dosbox-pure-source/`, put
`SOURCE-FILES.json` at `.runtime/pc-core/SOURCE-FILES.json`, and place the files
in `web-prototype/` and `tools/package/` at the matching paths in this
project. Install Emscripten 6.0.10, activate its environment, then run
`python3 web-prototype/build_core.py --source-archive`. The published source
inventory is checked before compilation. No native core or original game
is needed. The emitted JavaScript and WebAssembly live under
`web-prototype/.generated/`.

This source is GPL-2.0-or-later. Preserve upstream and component notices.
See `source/LICENSE` and `LICENSES/GPL-2.0.txt` in the site package.
'''.encode(), 0o644)
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    # The generated directory is script-owned; rebuild the single artifact.
    with OUTPUT.open('wb') as stream:
        with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0) as compressed:
            with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
                for name, (data, mode) in sorted(files.items()):
                    info = tarfile.TarInfo('abrams-web-core-source/' + name)
                    info.size = len(data)
                    info.mode = mode
                    info.mtime = info.uid = info.gid = 0
                    archive.addfile(info, io.BytesIO(data))
    print(f'Packaged {len(files)} Web core source files ({OUTPUT.stat().st_size} bytes)')


if __name__ == '__main__':
    main()
