#!/usr/bin/env python3
"""Check an already provisioned private kit, then run the original-PC bridge in Play mode."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def data_home(root=ROOT):
    override = os.environ.get('ABRAMS_DATA_HOME')
    path = Path(override).expanduser() if override else Path.home() / 'Library/Application Support/Abrams'
    if not path.is_absolute():
        raise ValueError('ABRAMS_DATA_HOME must be absolute')
    if path.resolve().is_relative_to(root.resolve()):
        raise ValueError('Player data must remain outside the kit, so upgrades preserve it')
    return path.resolve()


def dependencies(root=ROOT):
    if sys.version_info < (3, 10):
        raise ValueError('Python 3.10 or newer is required')
    if platform.system() != 'Darwin' or platform.machine() != 'arm64':
        raise ValueError('This local core is macOS ARM64 only; other targets need their own reviewed build')
    try:
        import PIL
    except ImportError:
        raise ValueError('Pillow is required in ABRAMS_PYTHON; install it in your chosen environment') from None
    godot = os.environ.get('GODOT_BIN') or shutil.which('godot')
    if not godot:
        for path in [Path('/Applications/Godot.app/Contents/MacOS/Godot'), root / '.runtime/Godot.app/Contents/MacOS/Godot']:
            if path.is_file():
                godot = str(path)
                break
    if not godot:
        raise ValueError('Godot 4.4+ is required; set GODOT_BIN to its executable (tested with 4.7.2)')
    version = subprocess.check_output([godot, '--version'], text=True, timeout=15).strip()
    match = re.match(r'4\.(\d+)\.', version)
    if not match or int(match[1]) < 4:
        raise ValueError(f'Godot 4.4+ is required, found {version}')
    for name in ['GAME/SIM.EXE', 'GAME/SHAPE.TBL', '.runtime/pc-core/abrams-ref.zip', '.runtime/pc-core/abrams-trace.dylib', '.runtime/pc-core/abrams-trace.json']:
        if not (root / name).is_file():
            raise ValueError(f'Missing private input: {name}. The source kit is not playable.')
    try:
        from tools.package_build import selected_files, verify_private_inputs, check_source_closure
    except ModuleNotFoundError:
        from package_build import selected_files, verify_private_inputs, check_source_closure
    check_source_closure(root, selected_files(root, 'private'), include_assets=True)
    verify_private_inputs(root)
    manifest = json.loads((root / '.runtime/pc-core/abrams-trace.json').read_text())
    return {'python': sys.version.split()[0], 'pillow': PIL.__version__, 'godot': version, 'godot_bin': godot,
            'core_sha256': manifest['trace_sha256'], 'data_home': str(data_home(root))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args, game_args = parser.parse_known_args()
    try:
        report = dependencies()
        if args.check:
            print(json.dumps(report, indent=2))
            return
        # Managed launch owns paths, preventing accidental writes into an old kit.
        if any(a.split('=')[0] in {'--saves', '--output', '--trace', '--reference'} for a in game_args):
            raise ValueError('Use ABRAMS_DATA_HOME for a profile; legacy snapshot diagnostics are not packaged')
        home = Path(report['data_home'])
        (home / 'saves').mkdir(parents=True, exist_ok=True)
        (home / 'logs').mkdir(parents=True, exist_ok=True)
        env = dict(os.environ, ABRAMS_PYTHON=sys.executable, GODOT_BIN=report['godot_bin'], PYTHONDONTWRITEBYTECODE='1')
        # Source kits need an initial import. No downloads or package installation.
        subprocess.run([report['godot_bin'], '--headless', '--path', str(ROOT / 'godot'), '--editor', '--import'], env=env, check=True)
        subprocess.run([report['godot_bin'], '--headless', '--path', str(ROOT / 'godot'), '--script', 'res://scripts/pc_bridge_viewer.gd', '--check-only'], env=env, check=True)
        os.execve(str(ROOT / 'PC Bridge.command'), [str(ROOT / 'PC Bridge.command'), '--play', '--saves', str(home / 'saves'), '--output', str(home / 'logs'), *game_args], env)
    except (ValueError, OSError, subprocess.SubprocessError, KeyError) as error:
        print(f'Abrams setup: {error}', file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
