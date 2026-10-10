#!/usr/bin/env python3
"""Stage authored presentation assets for local Godot Web QA.

The visitor's PC game and optional Genesis ROM are never read by this builder.
Only files loaded by the desktop Play presentation are eligible.
"""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tools.standalone.runtime import ROM_SHA
OUT = ROOT / 'web-prototype/.generated'
KINDS = {'.png', '.json', '.ttf', '.gpl', '.svg'}
MAX_PART_BYTES = 48_000_000
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
    reviewed = json.loads((ROOT / 'tools/package/allowlist.json').read_text())['private']
    names = {name for name in reviewed if name.startswith((
        'local-art/', 'local-audio/frontend-music-v1/', 'docs/player-reference/',
        'reference/genesis/extracted/gunner/palette.gpl', 'branding/abrams-cover-remastered.png'))}
    # Newer Play art has not yet entered the prior private-alpha allowlist.
    names.add('local-art/pc-ui-remastered/gunner-plate-v2.png')
    for name in sorted(names):
        path = ROOT / name
        if path.is_symlink() or not path.is_file():
            raise SystemExit(f'Missing or linked desktop presentation asset: {name}')
        if path.suffix.lower() == '.json' and name not in RUNTIME_JSON:
            continue
        if path.suffix.lower() in (KINDS | {'.wav'} if name.startswith('local-audio/') else KINDS):
            yield path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
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
        parts.append({'name': archive.name, 'bytes': archive.stat().st_size,
                      'sha256': hashlib.sha256(archive.read_bytes()).hexdigest()})
        bundle = None
    for path in selected():
        if not path.is_file():
            raise SystemExit(f'Missing desktop presentation asset: {path}')
        name = path.relative_to(ROOT).as_posix()
        if name.startswith(('GAME/', 'GENESIS/')):
            raise SystemExit(f'Original game file cannot be bundled: {name}')
        estimated = path.stat().st_size + 100 + 2 * len(name.encode())
        if estimated > MAX_PART_BYTES:
            raise SystemExit(f'One authored asset exceeds a Web part: {name}')
        if bundle is None or part_bytes + estimated > MAX_PART_BYTES:
            finish_part()
            archive = OUT / f'remaster-assets-{len(parts):02d}.zip'
            bundle = zipfile.ZipFile(archive, 'w', zipfile.ZIP_STORED, allowZip64=False)
            part_bytes = 0
        raw = path.read_bytes()
        bundle.writestr(name, raw)
        part_bytes += estimated
        manifest.append({'path': name, 'bytes': len(raw),
                         'sha256': hashlib.sha256(raw).hexdigest()})
    finish_part()
    (OUT / 'remaster-assets.zip').unlink(missing_ok=True)
    (OUT / 'remaster-assets.json').write_text(json.dumps({
        'schema': 2, 'parts': parts,
        'files': manifest}, separators=(',', ':')) + '\n')
    (OUT / 'genesis-input.json').write_text(json.dumps({
        'sha256': ROM_SHA, 'bytes': 524288}, separators=(',', ':')) + '\n')
    print(f'Staged {len(manifest)} authored files in {len(parts)} parts '
          f'({sum(part["bytes"] for part in parts)} bytes); no original PC game files')


if __name__ == '__main__':
    main()
