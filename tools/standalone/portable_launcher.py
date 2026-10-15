"""Portable launcher, with bounded setup requests and owned game lifetime."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from tools.standalone.runtime import (app_resources, sha, valid_payload, profile_home, managed, renderer_preflight,
                                      renderer_import, is_link, PAYLOAD_VERIFIED_ENV)

OUTPUT_TAIL_BYTES = 65536


def invoke_runtime(command, timeout, env=None):
    """Drain both pipes concurrently, retaining only their UTF-8 failure tails."""
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    tails = [b'', b'']
    tail_lock = threading.Lock()

    def stop_child():
        # Only the direct Popen child belongs to this invocation.
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=1)
            except subprocess.TimeoutExpired:
                process.kill()
                try:
                    process.wait(timeout=1)
                except subprocess.TimeoutExpired as error:
                    raise subprocess.SubprocessError('Owned runtime did not exit after termination. Close this launcher and recheck installation.') from error

    def drain(pipe, index):
        try:
            while True:
                chunk = pipe.read(8192)
                if not chunk:
                    break
                with tail_lock:
                    tails[index] = (tails[index] + chunk)[-OUTPUT_TAIL_BYTES:]
        finally:
            pipe.close()

    readers = [threading.Thread(target=drain, args=(pipe, index), daemon=True)
               for index, pipe in enumerate((process.stdout, process.stderr))]
    timed_out = False
    try:
        for reader in readers:
            reader.start()
        code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        # Popen owns this direct finite setup child. Never signal a process group,
        # controller or another job. Gameplay passes timeout=None.
        timed_out = True
        stop_child()
    except BaseException as error:
        # A drain-thread startup failure must not leave our child behind.
        stop_child()
        if isinstance(error, RuntimeError):
            raise subprocess.SubprocessError('Runtime output readers could not start. Close unused applications and recheck installation.') from error
        raise
    finally:
        # A descendant retaining a pipe must not hold the finite setup deadline.
        # Readers are daemon threads and close their own pipe on EOF.
        for reader, pipe in zip(readers, (process.stdout, process.stderr)):
            if reader.ident is not None:
                reader.join(timeout=1)
            else:
                pipe.close()
    if not timed_out and any(reader.is_alive() for reader in readers):
        raise subprocess.SubprocessError('Runtime exited but its output pipes stayed open. Recheck installation.')
    with tail_lock:
        stdout, stderr = tails
    if timed_out:
        raise subprocess.TimeoutExpired(command, timeout, output=stdout, stderr=stderr)
    return subprocess.CompletedProcess(command, code,
        stdout.decode('utf-8', errors='replace'), stderr.decode('utf-8', errors='replace'))


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
        if any(is_link(resources.joinpath(*relative.parts[:i])) for i in range(1,len(relative.parts)+1)):
            raise ValueError('Portable runtime contains a symlink or junction')
        if not path.is_file() or sha(path) != row['sha256']:
            raise ValueError('Portable runtime changed: '+name)
    return manifest


def main():
    if sys.platform == 'win32' and not sys.flags.utf8_mode:
        raise RuntimeError('The bundled Windows runtime must use UTF-8 mode')
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--bundle',type=Path,required=True)
    p.add_argument('--invoke',action='store_true')
    p.add_argument('--data-home')
    args,extra=p.parse_known_args()
    bundle=args.bundle.resolve()
    try:
        env=dict(os.environ)
        if args.data_home:
            # Validated here (absolute, outside the application) and inherited by
            # the setup UI and every runtime request it makes.
            env['ABRAMS_DATA_HOME']=str(profile_home(bundle,args.data_home))
        runtime=bundle/'runtime/AbramsRuntime'/('AbramsRuntime.exe' if os.name=='nt' else 'AbramsRuntime')
        if args.invoke:
            # Status only reports profile state; every request that copies,
            # imports or runs code from this build verifies it first.
            if extra[:1]!=['--status'] or len(extra)!=1:
                env[PAYLOAD_VERIFIED_ENV]=verify(bundle)['build_id']
            # Setup requests are bounded; gameplay owns its lifetime and exits
            # through the existing original-game shutdown/overlay flush path.
            result=invoke_runtime([str(runtime),*extra],
                                  timeout=None if '--play' in extra else 300,env=env)
            # Success replies are JSON on stdout; failures explain themselves on stderr.
            print(result.stdout if result.returncode==0 or not result.stderr.strip() else result.stderr,end='')
            return result.returncode
        # Only setup-UI arguments after '--' pass through; anything else would
        # otherwise reach Godot as an engine option and be silently ignored.
        if extra and extra[0]!='--':
            raise ValueError('Unknown launcher arguments: '+' '.join(extra)+'. Supported: --data-home /absolute/path')
        manifest=verify(bundle)
        renderer=bundle/'renderer'/('AbramsRenderer.exe' if os.name=='nt' else 'AbramsRenderer')
        env['ABRAMS_PYTHON']=str(runtime)
        for name in ('PYTHONHOME','PYTHONPATH','GODOT_BIN','ABRAMS_BUNDLE',PAYLOAD_VERIFIED_ENV):env.pop(name,None)
        # A fresh portable kit has no platform import cache for its fonts/assets.
        # Working if: first setup imports cleanly before its theme is parsed.
        home=profile_home(bundle,env.get('ABRAMS_DATA_HOME'))
        home.mkdir(parents=True,exist_ok=True)
        logs=managed(home,home/'logs');logs.mkdir(exist_ok=True)
        log=managed(home,logs/'setup.log')
        renderer_import(renderer,bundle/'kit/godot',manifest['build_id'],env,log,extra=('--audio-driver','Dummy'),
                        preflight=lambda *request: renderer_preflight(*request))
        renderer_preflight([str(renderer),'--headless','--audio-driver','Dummy',
            '--path',str(bundle/'kit/godot'),'--script',
            'res://scripts/portable_setup.gd','--check-only'],env,log)
        return subprocess.call([str(renderer),'--path',str(bundle/'kit/godot'),
            '--script','res://scripts/portable_setup.gd',*extra],env=env)
    except (ValueError,OSError,KeyError,subprocess.SubprocessError) as error:
        print(json.dumps({'error':str(error)}));return 1

if __name__=='__main__':raise SystemExit(main())
