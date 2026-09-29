#!/usr/bin/env python3
"""Build a local ARM64 macOS application, without raw original game inputs.

Requires an explicitly supplied Godot binary and isolated PyInstaller/Pillow
build environment. Never downloads, publishes or overwrites an existing app.
"""
from __future__ import annotations
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import plistlib
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
VERSION = '0.1.0-alpha.3'
BUNDLE_VERSION = '24'
APP_NAME = 'M1 Abrams Battle Tank Remastered'
REPOSITORY = 'https://github.com/NellInc/Abrams'
sys.path.insert(0, str(ROOT))
from tools import package_build
from tools.standalone.runtime import CONTENT_SHA, ROM_SHA, sha


def clone_file(source, destination):
    # APFS copy-on-write keeps local rollback builds inexpensive. On another
    # filesystem, ordinary copying remains the fallback; source is never edited.
    if sys.platform == 'darwin':
        result=subprocess.run(['/bin/cp','-c',str(source),str(destination)],capture_output=True)
        if not result.returncode:return destination
    shutil.copy2(source,destination)
    return destination


def payload(root):
    names = package_build.selected_files(root, 'private')
    package_build.check_source_closure(root, names, include_assets=True)
    package_build.verify_private_inputs(root)
    original_hashes = {row['sha256'] for row in json.loads((root/'tools/package/game-inputs.json').read_text())['files']} | {CONTENT_SHA, ROM_SHA}
    chosen = []
    for name in names:
        if name.startswith('GAME/') or name == '.runtime/pc-core/abrams-ref.zip': continue
        digest = sha(root/name)
        if digest in original_hashes:
            raise ValueError('An original input appears outside the excluded locations: '+name)
        chosen.append({'path':name, 'sha256':digest, 'size':(root/name).stat().st_size,
                       'mode':0o755 if name.endswith(('.command','.sh')) else 0o644})
    return chosen


def freeze(cache, python, target="macos"):
    native = target != "macos"
    destination = cache/'dist/AbramsRuntime'
    marker = cache/'frozen.json'
    # The frozen binary contains only the entry point, standard library and Pillow.
    # Project modules remain verified data files in the external installation.
    modules = set()
    for path in (ROOT/'tools').rglob('*.py'):
        for node in ast.walk(ast.parse(path.read_text())):
            candidates = [alias.name for alias in node.names] if isinstance(node, ast.Import) else ([node.module] if isinstance(node, ast.ImportFrom) and not node.level and node.module else [])
            modules.update(name for name in candidates if name.split('.')[0] in sys.stdlib_module_names)
    config = {'entry_sha256':sha(ROOT/'tools/standalone/entry.py'), 'stdlib':sorted(modules), 'pyinstaller':'6.22.3', 'pillow':'12.0.0', 'target':target, 'machine':platform.machine()}
    if native: config['python_options'] = ['X utf8']
    if destination.exists():
        if not marker.is_file() or json.loads(marker.read_text()) != config:
            raise ValueError('Frozen runtime inputs changed; use a fresh build-cache path')
        return destination
    cache.mkdir(parents=True, exist_ok=True)
    version = subprocess.check_output([str(python), '-c', 'import PyInstaller,PIL;print(PyInstaller.__version__+" "+PIL.__version__)'], text=True).strip()
    if version != '6.22.3 12.0.0': raise ValueError('Expected PyInstaller 6.22.3 and Pillow 12.0.0 in isolated build interpreter')
    command = [str(python), '-m', 'PyInstaller','--onedir','--name','AbramsRuntime','--noupx',
               '--distpath',str(cache/'dist'),'--workpath',str(cache/'work'),'--specpath',str(cache), '--collect-submodules','PIL']
    if not native: command += ['--target-arch','arm64']
    else: command += ['--python-option','X utf8']
    for name in sorted(modules): command += ['--hidden-import',name]
    command.append(str(ROOT/'tools/standalone/entry.py'))
    subprocess.run(command, check=True, env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
    marker.write_text(json.dumps(config,indent=2)+'\n')
    return destination


def verify(bundle):
    resources=bundle/'Contents/Resources'
    manifest=json.loads((resources/'RUNTIME.json').read_text())
    from tools.standalone.runtime import valid_payload
    valid_payload(resources, manifest)
    banned={CONTENT_SHA,ROM_SHA} | {r['sha256'] for r in json.loads((resources/'kit/tools/package/game-inputs.json').read_text())['files']}
    machos=0; count=0; total=0
    for path in bundle.rglob('*'):
        if path.is_symlink():
            if not path.resolve().is_relative_to(bundle.resolve()): raise ValueError('External bundle symlink: '+str(path))
            continue
        if not path.is_file():continue
        count+=1; total+=path.stat().st_size
        if sha(path) in banned:raise ValueError('Original content embedded in app: '+str(path))
        with path.open('rb') as stream:magic=stream.read(4)
        if magic not in [b'\xcf\xfa\xed\xfe',b'\xfe\xed\xfa\xcf',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca']:continue
        machos+=1
        linked=subprocess.check_output(['otool','-L',str(path)],text=True)
        for line in linked.splitlines()[1:]:
            library=line.strip().split(' (')[0]
            if library.startswith('/') and not library.startswith(('/usr/lib/','/System/Library/')):
                raise ValueError('External non-system dylib dependency: '+library+' in '+str(path))
        subprocess.run(['codesign','--verify',str(path)],check=True,capture_output=True)
    subprocess.run(['codesign','--verify','--deep','--strict',str(bundle)],check=True,capture_output=True)
    return {'schema':1,'bundle':str(bundle),'build_id':manifest['build_id'],'files':count,'bytes':total,
            'mach_o_files':machos,'originals_included':False,'external_non_system_dylibs':0,'release_ready':False,
            'rights':'Unofficial fan remaster. Original and third-party rights remain with their holders. See NOTICE.md. Signing status must be checked separately.'}


def build(output, godot, python, cache):
    if sys.platform!='darwin' or os.uname().machine!='arm64':raise ValueError('This builder targets native ARM64 macOS only')
    if output.suffix!='.app' or output.exists():raise ValueError('Output must be a new .app path')
    if shutil.disk_usage(ROOT).free<2*1024**3:raise ValueError('At least 2 GiB of free build space required; no prior artifacts are removed')
    rows=payload(ROOT)
    frozen=freeze(cache,python)
    contents=output/'Contents'; resources=contents/'Resources'; macos=contents/'MacOS'
    macos.mkdir(parents=True); resources.mkdir()
    renderer_app=contents/'Helpers/AbramsRenderer.app'
    renderer=renderer_app/'Contents/MacOS/AbramsRenderer'
    renderer.parent.mkdir(parents=True)
    for row in rows:
        dest=resources/'kit'/row['path'];dest.parent.mkdir(parents=True,exist_ok=True)
        clone_file(ROOT/row['path'],dest);dest.chmod(row['mode'])
        if sha(dest)!=row['sha256']:raise ValueError('Source changed during assembly: '+row['path'])
    shutil.copytree(frozen,resources/'runtime/AbramsRuntime',symlinks=True,copy_function=clone_file)
    # Copy/thin, never change the user's installed Godot application.
    subprocess.run(['lipo',str(godot),'-thin','arm64','-output',str(renderer)],check=True)
    renderer.chmod(0o755)
    subprocess.run(['swiftc','-O','-target','arm64-apple-macosx14.0','-module-cache-path',str(cache/'swift-modules'),str(ROOT/'tools/standalone/Launcher.swift'),'-o',str(macos/'Abrams')],check=True)
    icon_source=ROOT/'branding/abrams-icon.png'
    icon_cache=cache/('icon-'+sha(icon_source)[:16]);iconset=icon_cache/'Abrams.iconset'
    if not (icon_cache/'Abrams.icns').exists():
        iconset.mkdir(parents=True,exist_ok=True)
        for extent in [16,32,128,256,512]:
            for scale in [1,2]:
                name='icon_%dx%d%s.png'%(extent,extent,'@2x' if scale==2 else '')
                subprocess.run(['sips','-z',str(extent*scale),str(extent*scale),str(icon_source),'--out',str(iconset/name)],check=True,capture_output=True)
        subprocess.run(['iconutil','-c','icns',str(iconset)],check=True)
    shutil.copyfile(icon_cache/'Abrams.icns',resources/'Abrams.icns')
    (renderer_app/'Contents/Resources').mkdir()
    shutil.copyfile(icon_cache/'Abrams.icns',renderer_app/'Contents/Resources/Abrams.icns')
    notices=resources/'notices';notices.mkdir()
    for name in ['LICENSE','NOTICE.md']:
        shutil.copyfile(ROOT/name,notices/name)
    shutil.copytree(ROOT/'LICENSES',notices/'LICENSES')
    subprocess.run([str(godot),'--headless','--audio-driver','Dummy','--path',str(ROOT/'godot'),'--script',str(ROOT/'tools/standalone/licenses.gd'),'--',str(notices/'Godot.json')],check=True)
    shutil.copyfile(ROOT/'.runtime/dosbox-pure-source/LICENSE',notices/'DOSBox-Pure-LICENSE.txt')
    # Read licence texts from the selected build interpreter's distributions.
    notice_code = '''import importlib.metadata as m,json,pathlib,sysconfig
out={}
for package in ['Pillow','PyInstaller']:
 d=m.distribution(package)
 for f in d.files:
  if '.dist-info/licenses/' in str(f) and d.locate_file(f).is_file():out[package+'/'+str(f).split('/licenses/')[1]]=d.locate_file(f).read_text()
p=pathlib.Path(sysconfig.get_path('stdlib'))/'LICENSE.txt'
if p.is_file():out['Python/LICENSE.txt']=p.read_text()
else:raise RuntimeError('Python licence text not found')
print(json.dumps(out,indent=2))'''
    (notices/'Python-runtime.json').write_bytes(subprocess.check_output([str(python),'-c',notice_code]))
    identity=hashlib.sha256(json.dumps({'files':rows,'godot':sha(godot),'frozen':json.loads((cache/'frozen.json').read_text())},sort_keys=True).encode()).hexdigest()[:20]
    manifest={'schema':1,'version':VERSION,'repository':REPOSITORY,'build_id':identity,'originals_included':False,'files':rows,'platform':'macOS arm64',
              'release_ready':False,'minimum_os':'14.0','godot_sha256':sha(godot),'runtime_entry_sha256':sha(ROOT/'tools/standalone/entry.py')}
    (resources/'RUNTIME.json').write_text(json.dumps(manifest,indent=2)+'\n')
    info={'CFBundleExecutable':'Abrams','CFBundleIdentifier':'org.nellinc.abrams.private-alpha','CFBundleName':APP_NAME,
          'CFBundleDisplayName':APP_NAME,'CFBundlePackageType':'APPL','CFBundleVersion':BUNDLE_VERSION,'CFBundleShortVersionString':'0.1.0',
          'AbramsReleaseVersion':VERSION,'AbramsRepositoryURL':REPOSITORY,
          'LSMinimumSystemVersion':'14.0','LSArchitecturePriority':['arm64'],'NSHighResolutionCapable':True,'CFBundleIconFile':'Abrams.icns',
          'NSHumanReadableCopyright':'Unofficial fan remaster. Original game copyrights and trademarks remain with their respective owners.'}
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    renderer_info=dict(info,CFBundleExecutable='AbramsRenderer',CFBundleIdentifier='org.nellinc.abrams.renderer')
    (renderer_app/'Contents/Info.plist').write_bytes(plistlib.dumps(renderer_info))
    # The copied Python framework needs its resource envelope re-sealed; the
    # PyInstaller onedir binary alone carries no framework resource directory seal.
    for framework in sorted((resources/'runtime').rglob('*.framework'),key=lambda p:len(p.parts),reverse=True):
        subprocess.run(['codesign','--force','--sign','-',str(framework)],check=True)
    # PyInstaller signs its own closure. Sign newly compiled/copied executable
    # code then seal the outer app; this is not Developer ID or notarization.
    for path in [renderer,renderer_app,macos/'Abrams']:
        subprocess.run(['codesign','--force','--sign','-',str(path)],check=True)
    subprocess.run(['codesign','--force','--sign','-',str(output)],check=True)
    report=verify(output)
    (output.parent/(output.stem+'-verification.json')).write_text(json.dumps(report,indent=2)+'\n')
    return report


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path);p.add_argument('--godot',type=Path);p.add_argument('--python',type=Path)
    p.add_argument('--cache',type=Path,default=ROOT/'.runtime/app-build-cache');p.add_argument('--verify',type=Path)
    a=p.parse_args()
    if a.verify:result=verify(a.verify.resolve())
    else:
        if not all([a.output,a.godot,a.python]):p.error('--output, --godot and --python are required')
        result=build(a.output.resolve(),a.godot.resolve(),a.python.absolute(),a.cache.resolve())
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
