#!/usr/bin/env python3
"""Check an already provisioned private kit, then run the original-PC bridge in Play mode."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
IMPORT_MARKER = '.godot/abrams-kit-import.json'
PREFLIGHT_TIMEOUT = 300
# Zero-exit compile failures. A bare 'ERROR:' is not fatal on its own during
# editor import, so it is not a refusal marker here.
PREFLIGHT_ERRORS = re.compile(br'SCRIPT ERROR|Parse Error|SHADER ERROR')


def data_home(root=ROOT):
    override = os.environ.get('ABRAMS_DATA_HOME')
    path = Path(override).expanduser() if override else Path.home() / 'Library/Application Support/Abrams'
    if not path.is_absolute():
        raise ValueError('ABRAMS_DATA_HOME must be absolute')
    # resolve() keeps case on APFS, so 'kit/x' must also match 'Kit' through samefile.
    path, root = path.resolve(), root.resolve()
    if path.is_relative_to(root) or any(os.path.samefile(a, root) for a in (path, *path.parents) if a.exists() and root.exists()):
        raise ValueError('Player data must remain outside the kit, so upgrades preserve it')
    return path.resolve()


def dependencies(root=ROOT, closure=False):
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
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from package_build import selected_files, verify_private_inputs, check_source_closure
    names = selected_files(root, 'private')
    # The closure is a build-time property (build and verify enforce it); launch
    # keeps presence and hash checks and leaves the full walk to --check.
    if closure:
        check_source_closure(root, names, include_assets=True)
    verify_private_inputs(root)
    manifest = json.loads((root / '.runtime/pc-core/abrams-trace.json').read_text())
    return {'python': sys.version.split()[0], 'pillow': PIL.__version__, 'godot': version, 'godot_bin': godot,
            'core_sha256': manifest['trace_sha256'], 'data_home': str(data_home(root))}


def preflight(arguments, env, log_path):
    """Run one Godot preflight with a deadline, refusing zero-exit compile errors.

    Working if: a hung import fails after PREFLIGHT_TIMEOUT seconds and a
    SCRIPT ERROR/Parse Error/SHADER ERROR never reaches gameplay, as in the
    standalone renderer_preflight; output is kept in the profile log.
    """
    with log_path.open('ab') as log:
        start = log.tell()
        try:
            result = subprocess.run(arguments, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=PREFLIGHT_TIMEOUT)
        except subprocess.TimeoutExpired as error:
            raise subprocess.SubprocessError(f'Godot preflight timed out after {PREFLIGHT_TIMEOUT} seconds. Details: {log_path}') from error
    with log_path.open('rb') as log:
        log.seek(start)
        output = log.read()
    match = PREFLIGHT_ERRORS.search(output)
    if result.returncode or match:
        detail = (output[match.start():].split(b'\n', 1)[0][:512] if match else output[-2048:]).decode('utf-8', errors='replace').strip()
        raise subprocess.SubprocessError(f'Godot preflight failed (exit {result.returncode}). Details: {log_path}' + ('\n' + detail if detail else ''))


def import_stamp(root=ROOT, godot='', godot_bin=''):
    # The receipt fingerprints every kit member, so it changes with any content.
    # Kits bring no engine, so the Godot version and executable join the stamp:
    # another engine's imported cache is never reused.
    receipt = root / 'PACKAGE.json'
    if not receipt.is_file():
        return None
    return hashlib.sha256(receipt.read_bytes() + b'\0' + godot.encode() + b'\0' + godot_bin.encode()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args, game_args = parser.parse_known_args()
    try:
        report = dependencies(closure=args.check)
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
        log = home / 'logs/application.log'
        project = ROOT / 'godot'
        # Kits need an initial import, repeated only when the kit receipt or the
        # Godot engine changes or .godot is cleared; a checkout without a receipt
        # imports every time. No downloads or package installation.
        stamp, marker = import_stamp(ROOT, report['godot'], report['godot_bin']), project / IMPORT_MARKER
        # The marker is never written through a link, as in the standalone renderer_import.
        if marker.parent.is_symlink() or marker.is_symlink():
            raise ValueError('Godot import cache godot/.godot and its kit marker cannot be symlinks')
        if not stamp or not marker.is_file() or marker.read_text() != stamp + '\n':
            print(f'Abrams setup: importing Godot resources; this can take a few minutes. Log: {log}', file=sys.stderr, flush=True)
            preflight([report['godot_bin'], '--headless', '--path', str(project), '--editor', '--import'], env, log)
            if stamp:
                marker.parent.mkdir(exist_ok=True)
                marker.write_text(stamp + '\n')
        # Script compilation is checked on every launch, as in the standalone app.
        preflight([report['godot_bin'], '--headless', '--path', str(project), '--script', 'res://scripts/pc_bridge_viewer.gd', '--check-only'], env, log)
        os.execve(str(ROOT / 'PC Bridge.command'), [str(ROOT / 'PC Bridge.command'), '--play', '--saves', str(home / 'saves'), '--output', str(home / 'logs'), *game_args], env)
    except (ValueError, OSError, subprocess.SubprocessError, KeyError) as error:
        print(f'Abrams setup: {error}', file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
