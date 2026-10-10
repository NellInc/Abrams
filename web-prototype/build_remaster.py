#!/usr/bin/env python3
"""Produce a local Godot Web Play export plus authored-asset pack."""
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / '.runtime/Godot.app/Contents/MacOS/Godot'
WEB = ROOT / 'web-prototype/.generated/godot'
STAGE = ROOT / '.runtime/web-godot-project'
MARKER = STAGE / '.abrams-web-staging'


def main():
    if not GODOT.is_file():
        raise SystemExit('Pinned local Godot 4.7.2 editor is missing')
    if STAGE.exists():
        if not MARKER.is_file():
            raise SystemExit('Refusing to replace an unowned Godot staging directory')
        shutil.rmtree(STAGE)
    STAGE.mkdir(parents=True)
    MARKER.write_text('Generated only by web-prototype/build_remaster.py\n')
    # Export from a clean presentation project. The desktop checkout contains
    # original-PC diagnostic snapshots under godot/artifacts; those must never
    # be copied into a browser pack, even as incidental all_resources inputs.
    source = ROOT / 'godot'
    project = (source / 'project.godot').read_text()
    main_scene = 'run/main_scene="res://scenes/main.tscn"'
    if project.count(main_scene) != 1:
        raise SystemExit('Desktop development main scene changed; review the Web entry point')
    # Exported Web templates start the project MainLoop, not an editor-style
    # `-s` script. Register Play as that loop in staging so the unrelated
    # development range can never become the browser game.
    (STAGE / 'project.godot').write_text(project.replace(
        main_scene, 'run/main_scene="res://scenes/web_entry.tscn"\n'
                    'run/main_loop_type="AbramsWebPlayLoop"'))
    for name in ('scripts', 'assets', 'data', 'scenes'):
        shutil.copytree(source / name, STAGE / name,
                        ignore=shutil.ignore_patterns('.DS_Store', '__pycache__', '*.pyc'))
    viewer = STAGE / 'scripts/pc_bridge_viewer.gd'
    viewer.write_text('class_name AbramsWebPlayLoop\n' + viewer.read_text())
    # The Web template insists on a main-scene resource even with a custom
    # MainLoop. This inert scene is never the development range.
    (STAGE / 'scenes/web_entry.tscn').write_text(
        '[gd_scene format=3]\n\n[node name="WebEntry" type="Node"]\n')
    preset = (source / 'export_presets.cfg').read_text()
    preset = preset.replace('../.runtime/godot-web-templates/',
                            str(ROOT / '.runtime/godot-web-templates') + '/')
    (STAGE / 'export_presets.cfg').write_text(preset)
    WEB.mkdir(parents=True, exist_ok=True)
    # A previous export may have left PWA support files. This wrapper owns its
    # own isolation worker, so never ship stale Godot-generated entry points.
    for name in ('index.service.worker.js', 'index.manifest.json',
                 'index.offline.html', 'index.144x144.png', 'index.180x180.png',
                 'index.512x512.png'):
        (WEB / name).unlink(missing_ok=True)
    subprocess.run([str(GODOT), '--headless', '--path', str(STAGE),
                    '--export-release', 'Abrams Web local', str(WEB / 'index.html')],
                   check=True, cwd=ROOT)
    # The generated HTML would launch the project's separate development
    # range. Only remaster.html may launch this export as the PC Play viewer.
    (WEB / 'index.html').unlink()
    subprocess.run(['python3', str(ROOT / 'web-prototype/build_remaster_assets.py')],
                   check=True, cwd=ROOT)
    print('Local Web Play export ready under ignored web-prototype/.generated/')


if __name__ == '__main__':
    main()
