#!/usr/bin/env python3
"""Local macOS app provisioning. Originals and profiles stay outside the app."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROM_SHA = 'ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea'
CONTENT_SHA = 'c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05'
MIN_FREE = 1024 ** 3


def sha(path):
    # Streaming SHA-256 also supports the source kit's Python 3.10 baseline.
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def write_json(path, value):
    # Same-directory exclusive temporary file, followed by atomic replacement.
    with tempfile.NamedTemporaryFile(mode='w', dir=path.parent, prefix='.'+path.name, delete=False) as stream:
        json.dump(value, stream, indent=2); stream.write('\n'); stream.flush(); os.fsync(stream.fileno())
        temporary = Path(stream.name)
    temporary.replace(path)


def regular(path):
    path = Path(path)
    return path.is_file() and not path.is_symlink()


def managed(home, path):
    """Reject links inside managed storage before reading or creating children."""
    path = Path(path)
    relative = path.relative_to(home)
    for i in range(1, len(relative.parts)+1):
        if home.joinpath(*relative.parts[:i]).is_symlink():
            raise ValueError('Managed player data cannot contain symlinks: '+str(path))
    return path


def app_resources(bundle):
    bundle = Path(bundle).resolve()
    root = bundle / 'Contents/Resources' if bundle.suffix == '.app' else bundle
    manifest = json.loads((root/'RUNTIME.json').read_text())
    if manifest.get('schema') != 1 or manifest.get('originals_included') is not False:
        raise ValueError('Unsupported application manifest')
    if not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', str(manifest.get('build_id', ''))):
        raise ValueError('Unsafe application build identifier')
    return root, manifest


def profile_home(bundle, requested=None):
    selected = requested or os.environ.get('ABRAMS_DATA_HOME')
    if selected:
        home = Path(selected).expanduser()
    elif sys.platform == 'win32':
        base = os.environ.get('LOCALAPPDATA')
        home = (Path(base) if base else Path.home()/'AppData/Local')/'Abrams'
    elif sys.platform == 'darwin':
        home = Path.home()/'Library/Application Support/Abrams'
    else:
        base = os.environ.get('XDG_DATA_HOME')
        home = (Path(base) if base else Path.home()/'.local/share')/'abrams'
    if not home.is_absolute() or home.resolve().is_relative_to(Path(bundle).resolve()):
        raise ValueError('Player data must use an absolute directory outside the application')
    return home.resolve()


def source_records(resources):
    rows = json.loads((resources/'kit/tools/package/game-inputs.json').read_text())['files']
    names = [row['name'] for row in rows]
    if not names or len(set(names)) != len(names) or any(not name or name in {'.','..'} or Path(name).name != name or '\\' in name for name in names):
        raise ValueError('Unsafe original input manifest')
    return rows


def validate_content(resources, content):
    for row in source_records(resources):
        path = content/'GAME'/row['name']
        managed(content, path)
        if not regular(path) or sha(path) != row['sha256']:
            raise ValueError('Imported PC game files in the player data folder are missing or changed. They and your saves were kept for diagnosis. Restore the profile from a backup, or use a fresh data home (ABRAMS_DATA_HOME or --data-home).')
    archive = content/'.runtime/pc-core/abrams-ref.zip'
    managed(content, archive)
    if not regular(archive) or sha(archive) != CONTENT_SHA:
        raise ValueError('Imported PC content is incomplete or changed; existing saves have been preserved.')


def genesis_enabled(home):
    receipt = managed(home, home/'content/genesis.json')
    if not receipt.exists(): return False
    if not regular(receipt): raise ValueError('Genesis receipt must be a regular file')
    data = json.loads(receipt.read_text())
    if data != {'schema': 1, 'rom_sha256': ROM_SHA}:
        raise ValueError('Unsupported Genesis import receipt')
    return True


def status(bundle, home):
    resources, manifest = app_resources(bundle)
    content = managed(home, home/'content'/CONTENT_SHA)
    installed = False
    problem = ''
    if content.exists():
        try: validate_content(resources, content); installed = True
        except (ValueError, OSError) as error: problem = str(error)
    return {'pc_installed': installed, 'genesis_enabled': genesis_enabled(home),
            'problem': problem, 'data_home': str(home), 'build_id': manifest['build_id']}


def import_games(bundle, home, game=None, genesis=None):
    resources, _ = app_resources(bundle)
    # Validate optional input before committing either import.
    if genesis and (not regular(genesis) or sha(genesis) != ROM_SHA):
        raise ValueError('Unsupported Genesis ROM. Select the original raw ROM revision documented in the README; no data was replaced.')
    target = managed(home, home/'content'/CONTENT_SHA)
    if game:
        game = Path(game)
        rows = source_records(resources)
        if not game.is_dir() or game.is_symlink(): raise ValueError('Choose an extracted PC game folder')
        # Validate everything before creating any destination. DOS filenames are
        # case-insensitive, but case collisions are ambiguous and rejected.
        candidates = {}
        for path in game.iterdir(): candidates.setdefault(path.name.upper(), []).append(path)
        for row in rows:
            paths = candidates.get(row['name'].upper(), [])
            if len(paths) != 1 or not regular(paths[0]) or sha(paths[0]) != row['sha256']:
                raise ValueError('Unsupported or missing PC file: '+row['name']+'. Originals and existing saves are unchanged.')
        if target.exists(): validate_content(resources, target)
        else:
            home.mkdir(parents=True, exist_ok=True)
            if shutil.disk_usage(home).free < MIN_FREE: raise ValueError('At least 1 GiB of free disk space is required')
            target.parent.mkdir(parents=True, exist_ok=True)
            staging = Path(tempfile.mkdtemp(prefix='.import-', dir=target.parent))
            # Reuse the existing pinned-content reconstruction; the normalized
            # input staging preserves every byte and never changes source files.
            normalized = staging/'input'; normalized.mkdir()
            for row in rows: shutil.copyfile(candidates[row['name'].upper()][0], normalized/row['name'])
            sys.path.insert(0, str(resources/'kit'))
            from tools.package_setup import prepare
            prepared = staging/'prepared'
            prepare(normalized, prepared, rows)
            validate_content(resources, prepared)
            prepared.rename(target)
            # Retain small staging inputs rather than deleting files automatically.
    elif not target.exists():
        raise ValueError('Choose the original PC game folder first. Genesis alone cannot run the PC simulation.')
    validate_content(resources, target)
    if genesis:
        (home/'content').mkdir(parents=True, exist_ok=True)
        write_json(home/'content/genesis.json', {'schema': 1, 'rom_sha256': ROM_SHA})
    return status(bundle, home)


def valid_payload(resources, manifest):
    names = set()
    for row in manifest['files']:
        name = row['path']; relative = Path(name)
        if not name or relative.as_posix() != name or '\\' in name or ':' in name or relative.is_absolute() or '..' in relative.parts or name in names:
            raise ValueError('Unsafe application payload manifest')
        names.add(name)
        path = resources/'kit'/name
        if any((resources/'kit'/Path(*relative.parts[:i])).is_symlink() for i in range(1,len(relative.parts)+1)):
            raise ValueError('Application payload contains an unexpected symlink')
        if not regular(path) or sha(path) != row['sha256']:
            raise ValueError('Application payload is missing or changed: '+name)


def prepare_install(bundle, home):
    resources, manifest = app_resources(bundle)
    valid_payload(resources, manifest)
    content = managed(home, home/'content'/CONTENT_SHA)
    validate_content(resources, content)
    home.mkdir(parents=True, exist_ok=True)
    target = managed(home, home/'versions'/manifest['build_id'])
    if target.is_symlink(): raise ValueError('Versioned installation cannot be a symlink')
    if not target.exists():
        if shutil.disk_usage(home).free < MIN_FREE: raise ValueError('At least 1 GiB of free disk space is required')
        target.parent.mkdir(parents=True, exist_ok=True)
        staging = Path(tempfile.mkdtemp(prefix='.install-', dir=target.parent))
        for row in manifest['files']:
            destination = staging/row['path']; destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(resources/'kit'/row['path'], destination)
            destination.chmod(row['mode'])
        shutil.copytree(content/'GAME', staging/'GAME')
        shutil.copyfile(content/'.runtime/pc-core/abrams-ref.zip', staging/'.runtime/pc-core/abrams-ref.zip')
        write_json(staging/'INSTALL.json', {'schema':1,'build_id':manifest['build_id']})
        staging.rename(target)
    # Refuse changed code/resources rather than repairing over an existing kit.
    for row in manifest['files']:
        path = managed(home, target/row['path'])
        if not regular(path) or sha(path) != row['sha256']:
            raise ValueError('Versioned installation changed: '+row['path']+'. Keep it for recovery and use a fresh data home.')
    validate_content(resources, target)
    return target


def launch(bundle, home, extra):
    forbidden = {'--saves','--output','--trace','--reference','--pc-only','--graphics'}
    if any(arg.split('=')[0] in forbidden for arg in extra):
        raise ValueError('The application owns content, presentation and save paths; use its importer/settings.')
    resources, _ = app_resources(bundle)
    install = prepare_install(bundle, home)
    portable = Path(bundle).suffix != '.app'
    godot = Path(bundle)/('renderer/AbramsRenderer.exe' if sys.platform == 'win32' else 'renderer/AbramsRenderer') if portable else Path(bundle)/'Contents/Helpers/AbramsRenderer.app/Contents/MacOS/AbramsRenderer'
    runtime = resources/'runtime/AbramsRuntime'/('AbramsRuntime.exe' if sys.platform == 'win32' else 'AbramsRuntime')
    for path in [godot,runtime]:
        if not regular(path) or not os.access(path,os.X_OK): raise ValueError('Bundled runtime is unavailable')
    managed(home, home/'saves').mkdir(exist_ok=True); managed(home, home/'logs').mkdir(exist_ok=True)
    env = dict(os.environ, ABRAMS_PYTHON=str(runtime), PYTHONDONTWRITEBYTECODE='1')
    # Ignore developer-machine overrides and package-manager Python search paths.
    for key in ['PYTHONHOME','PYTHONPATH','GODOT_BIN']:
        env.pop(key,None)
    with (home/'logs/application.log').open('a') as log:
        for arguments in [
            [str(godot),'--headless','--path',str(install/'godot'),'--editor','--import'],
            [str(godot),'--headless','--path',str(install/'godot'),'--script','res://scripts/pc_bridge_viewer.gd','--check-only']]:
            subprocess.run(arguments,env=env,stdout=log,stderr=subprocess.STDOUT,check=True)
    args=[str(godot),'--path',str(install/'godot'),'--script','res://scripts/pc_bridge_viewer.gd','--','--boot','--play','--saves',str(home/'saves'),'--output',str(home/'logs')]
    if not genesis_enabled(home): args.append('--pc-only')
    args.extend(extra)
    if portable:
        # Game console output goes to the profile log, not the bounded setup pipes;
        # a failure reports the exit code and this session's last log lines.
        game_log = home/'logs/game.log'
        with game_log.open('ab') as log:
            log.write(b'\n== game session ==\n'); log.flush(); start = log.tell()
            code = subprocess.call(args, env=env, stdout=log, stderr=subprocess.STDOUT)
        if code:
            with game_log.open('rb') as log:
                log.seek(max(start, log.seek(0, 2)-1000)); tail = log.read().decode('utf-8', 'replace').strip()
            print(json.dumps({'error': f'The game exited with code {code}. Details: {game_log}'+('\n'+tail if tail else '')}), file=sys.stderr)
        return code
    os.execve(godot,args,env)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,required=True)
    p.add_argument('--data-home')
    p.add_argument('--status',action='store_true')
    p.add_argument('--game',type=Path)
    p.add_argument('--genesis',type=Path)
    p.add_argument('--prepare',action='store_true')
    p.add_argument('--play',action='store_true')
    args,extra=p.parse_known_args()
    try:
        home=profile_home(args.bundle,args.data_home)
        if args.game or args.genesis: import_games(args.bundle,home,args.game,args.genesis)
        if args.prepare: print(json.dumps({'installation':str(prepare_install(args.bundle,home))}))
        elif args.play: return launch(args.bundle,home,extra)
        else:
            if extra: raise ValueError('Unknown setup arguments')
            print(json.dumps(status(args.bundle,home)))
    except (ValueError,OSError,KeyError,subprocess.SubprocessError,json.JSONDecodeError) as error:
        print(json.dumps({'error':str(error)}),file=sys.stderr);return 1
    return 0

if __name__=='__main__':raise SystemExit(main())
