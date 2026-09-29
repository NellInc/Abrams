"""Portable launcher, with bounded setup requests and owned game lifetime."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from tools.standalone.runtime import app_resources, sha, valid_payload


def verify(bundle):
    resources, manifest = app_resources(bundle)
    valid_payload(resources, manifest)
    names = set()
    for row in manifest['portable_files']:
        name = row['path']
        relative = Path(name)
        if not name or relative.is_absolute() or '..' in relative.parts or '\\' in name or ':' in name or name in names:
            raise ValueError('Unsafe portable integrity member')
        names.add(name)
        path = resources / relative
        if any(resources.joinpath(*relative.parts[:i]).is_symlink() for i in range(1,len(relative.parts)+1)):
            raise ValueError('Portable runtime contains a symlink')
        if not path.is_file() or sha(path) != row['sha256']:
            raise ValueError('Portable runtime changed: '+name)
    return manifest


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,required=True)
    p.add_argument('--invoke',action='store_true')
    args,extra=p.parse_known_args()
    bundle=args.bundle.resolve()
    try:
        verify(bundle)
        runtime=bundle/'runtime/AbramsRuntime'/('AbramsRuntime.exe' if os.name=='nt' else 'AbramsRuntime')
        if args.invoke:
            # Setup requests are bounded; gameplay owns its lifetime and exits
            # through the existing original-game shutdown/overlay flush path.
            result=subprocess.run([str(runtime),*extra],capture_output=True,text=True,
                                  timeout=None if '--play' in extra else 300)
            print(result.stdout or result.stderr,end='')
            return result.returncode
        renderer=bundle/'renderer'/('AbramsRenderer.exe' if os.name=='nt' else 'AbramsRenderer')
        env=dict(os.environ,ABRAMS_BUNDLE=str(bundle),ABRAMS_PYTHON=str(runtime))
        for name in ('PYTHONHOME','PYTHONPATH','GODOT_BIN'):env.pop(name,None)
        return subprocess.call([str(renderer),'--path',str(bundle/'kit/godot'),
            '--script','res://scripts/portable_setup.gd',*extra],env=env)
    except (ValueError,OSError,KeyError,subprocess.SubprocessError) as error:
        print(json.dumps({'error':str(error)}));return 1

if __name__=='__main__':raise SystemExit(main())
