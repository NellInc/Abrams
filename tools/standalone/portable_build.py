#!/usr/bin/env python3
"""Assemble a native Windows/Linux x86_64 portable app, without game originals.

Inputs are explicit, local and versioned. No downloads, runtime installers,
publication, overwrite, or source-game modifications are performed.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from tools import package_build
from tools.standalone.build import APP_NAME, VERSION, REPOSITORY, clone_file, freeze
from tools.standalone.runtime import CONTENT_SHA, ROM_SHA, sha
from tools.standalone.portable_launcher import verify
from tools.pc_reference_core import core_suffix


def payload(root):
    allow=json.loads((root/'tools/package/allowlist.json').read_text())
    if allow.get('schema') != 1:raise ValueError('Unsupported allowlist')
    source=set(allow['source'])
    names=allow['source']+allow['private']
    if len(names)!=len(set(names)):raise ValueError('Duplicate allowlist member')
    rows=[]
    banned={CONTENT_SHA,ROM_SHA}|{r['sha256'] for r in json.loads((root/'tools/package/game-inputs.json').read_text())['files']}
    for name in sorted(names):
        package_build.validate_name(name,'source' if name in source else 'private')
        if name.startswith('GAME/') or name=='.runtime/pc-core/abrams-ref.zip':continue
        if name=='.runtime/pc-core/abrams-trace.dylib':name='.runtime/pc-core/abrams-trace'+core_suffix()
        relative=Path(name)
        path=root/relative
        if any(root.joinpath(*relative.parts[:i]).is_symlink() for i in range(1,len(relative.parts)+1)) or not path.is_file():
            raise ValueError('Missing regular portable payload: '+name)
        digest=sha(path)
        if digest in banned:raise ValueError('Original content found outside excluded input locations: '+name)
        rows.append({'path':name,'sha256':digest,'size':path.stat().st_size,'mode':0o755 if name.endswith(('.sh','.command')) else 0o644})
    package_build.check_source_closure(root,[r['path'] for r in rows],include_assets=True)
    return rows


def inspect_core():
    manifest=json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    path=ROOT/('.runtime/pc-core/abrams-trace'+core_suffix())
    if manifest.get('commit')!='73e03aa145e0549ed4d5a20f8e65532714da33f5' or sha(path)!=manifest.get('trace_sha256'):
        raise ValueError('Unpinned native trace core')
    # The source observers and native bytes are separate provenance checks.
    for field,name in [('trace_header_sha256','abrams_trace.h'),('ownership_header_sha256','abrams_vga_ownership.h'),
                       ('plate_ownership_header_sha256','abrams_plate_ownership.h'),
                       ('observer_checkpoint_header_sha256','abrams_observer_checkpoint.h'),
                       ('state_overlay_header_sha256','abrams_state_overlay.h')]:
        if sha(ROOT/'tools/pc_core'/name)!=manifest.get(field):raise ValueError('Trace observer changed: '+name)
    return manifest


def notices(output, godot, python, core_source):
    directory=output/'notices';directory.mkdir()
    for name in ('LICENSE','NOTICE.md'):shutil.copyfile(ROOT/name,directory/name)
    shutil.copytree(ROOT/'LICENSES',directory/'LICENSES')
    shutil.copyfile(core_source/'LICENSE',directory/'DOSBox-Pure-LICENSE.txt')
    subprocess.run([str(godot),'--headless','--audio-driver','Dummy','--path',str(ROOT/'godot'),
                    '--script',str(ROOT/'tools/standalone/licenses.gd'),'--',str(directory/'Godot.json')],check=True)
    code='''import importlib.metadata as m,json,pathlib,sys,sysconfig
out={}
for package in ['Pillow','PyInstaller']:
 d=m.distribution(package)
 for f in d.files:
  if '.dist-info/licenses/' in str(f) and d.locate_file(f).is_file():out[package+'/'+str(f).split('/licenses/')[1]]=d.locate_file(f).read_text()
for p in [pathlib.Path(sysconfig.get_path('stdlib'))/'LICENSE.txt',pathlib.Path(sys.base_prefix)/'LICENSE.txt']:
 if p.is_file():out['Python/LICENSE.txt']=p.read_text();break
else:raise RuntimeError('Python licence text not found')
print(json.dumps(out,indent=2))'''
    (directory/'Python-runtime.json').write_bytes(subprocess.check_output([str(python),'-c',code]))


def build(output,godot,python,cache,core_source):
    if sys.platform not in ('win32','linux') or platform.machine().lower() not in ('x86_64','amd64'):
        raise ValueError('Run on native Windows or Linux x86_64')
    if output.exists():raise ValueError('Output must be a new directory')
    if shutil.disk_usage(ROOT).free<2*1024**3:raise ValueError('At least 2 GiB free build space required')
    inspect_core()
    commit=subprocess.check_output(['git','-C',str(core_source),'rev-parse','HEAD'],text=True).strip()
    if commit != '73e03aa145e0549ed4d5a20f8e65532714da33f5':raise ValueError('Unpinned core source for notices')
    rows=payload(ROOT)
    frozen=freeze(cache,python,target=sys.platform)
    output.mkdir(parents=True)
    for row in rows:
        dest=output/'kit'/row['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        clone_file(ROOT/row['path'],dest);dest.chmod(row['mode'])
        if sha(dest)!=row['sha256']:raise ValueError('Payload changed during assembly: '+row['path'])
    shutil.copytree(frozen,output/'runtime/AbramsRuntime',copy_function=clone_file)
    renderer=output/'renderer'/('AbramsRenderer.exe' if os.name=='nt' else 'AbramsRenderer')
    renderer.parent.mkdir();shutil.copyfile(godot,renderer);renderer.chmod(0o755)
    # Bundle the full Godot Windows executable, not its tiny console wrapper.
    notices(output,godot,python,core_source)
    if os.name=='nt':
        icon=cache/'Abrams.ico'
        subprocess.run([str(python),'-c','from PIL import Image;import sys;Image.open(sys.argv[1]).save(sys.argv[2],format="ICO",sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])',str(ROOT/'branding/abrams-icon.png'),str(icon)],check=True)
        resource=cache/'launcher.rc';resource.write_text('1 ICON "'+icon.as_posix()+'"\n')
        obj=cache/'launcher-icon.o'
        subprocess.run(['windres',str(resource),'-o',str(obj)],check=True)
        subprocess.run(['gcc','-Os','-municode','-mwindows','-static',str(ROOT/'tools/standalone/portable_launcher.c'),str(obj),'-o',str(output/(APP_NAME+'.exe'))],check=True)
        (output/(APP_NAME+'.cmd')).write_text('@echo off\r\n"%~dp0runtime\\AbramsRuntime\\AbramsRuntime.exe" --launcher %*\r\n',newline='')
    else:
        launcher=output/(APP_NAME+'.sh')
        launcher.write_text('#!/bin/sh\nset -eu\nHERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\nexec "$HERE/runtime/AbramsRuntime/AbramsRuntime" --launcher "$@"\n')
        launcher.chmod(0o755)
    runtime_files=[{'path':p.relative_to(output).as_posix(),'sha256':sha(p),'size':p.stat().st_size}
        for p in sorted(output.rglob('*')) if p.is_file() and not p.is_relative_to(output/'kit')]
    identity=hashlib.sha256(json.dumps({'files':rows,'runtime':runtime_files},sort_keys=True).encode()).hexdigest()[:20]
    manifest={'schema':1,'version':VERSION,'repository':REPOSITORY,'build_id':identity,'originals_included':False,
              'files':rows,'portable_files':runtime_files,'platform':sys.platform+' x86_64',
              'release_ready':False,'minimum_os':'Windows 10' if os.name=='nt' else 'glibc 2.35 Linux',
              'godot_sha256':sha(godot),'runtime_entry_sha256':sha(ROOT/'tools/standalone/entry.py')}
    (output/'RUNTIME.json').write_text(json.dumps(manifest,indent=2)+'\n')
    verify(output)
    banned={CONTENT_SHA,ROM_SHA}|{r['sha256'] for r in json.loads((ROOT/'tools/package/game-inputs.json').read_text())['files']}
    for path in output.rglob('*'):
        if path.is_file() and sha(path) in banned:raise ValueError('Original content embedded in portable app')
    archive=output.with_suffix('.zip')
    if archive.exists():raise ValueError('Archive already exists')
    # ZIP member permissions preserve Linux launchability across extraction.
    shutil.make_archive(str(archive.with_suffix('')),'zip',root_dir=output.parent,base_dir=output.name)
    return {'bundle':str(output),'archive':str(archive),'build_id':identity,'originals_included':False,
            'integrity_verified':True,'native_runtime_acceptance':'requires platform smoke tests'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path);p.add_argument('--godot',type=Path);p.add_argument('--python',type=Path)
    p.add_argument('--cache',type=Path,default=ROOT/'.runtime/portable-build-cache');p.add_argument('--verify',type=Path)
    p.add_argument('--core-source',type=Path,default=ROOT/'.runtime/dosbox-pure-source')
    a=p.parse_args()
    if a.verify:result=verify(a.verify.resolve())
    else:
        if not all((a.output,a.godot,a.python)):p.error('--output, --godot and --python required')
        result=build(a.output.resolve(),a.godot.resolve(),a.python.absolute(),a.cache.resolve(),a.core_source.resolve())
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
