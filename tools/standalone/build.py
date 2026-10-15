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
VERSION = '0.1.0-alpha.5'
BUNDLE_VERSION = '31'
APP_NAME = 'M1 Abrams Battle Tank Fan Remaster'
REPOSITORY = 'https://github.com/NellInc/Abrams'
sys.path.insert(0, str(ROOT))
from tools import package_build
from tools.standalone.runtime import CONTENT_SHA, ROM_SHA, sha, derive, DerivationInputs
from tools.source_guard import inside_source

# Native apps never ship raw Genesis extracts, reference captures or decoded
# original PC data. Reproducible files are derived on the player's machine at
# import time (tools/standalone/runtime.py); the rest stay out entirely.
DERIVED_TABLE = 'tools/standalone/import-derived.json'
# The frontend score mixes percussion extracted from the Genesis ROM, whose
# redistribution rights are not established; without it the original audio
# path plays (pc_frontend_music.gd treats the score as optional).
NATIVE_EXCLUDED_PREFIXES = ('reference/', 'local-art/genesis/source/', 'local-audio/frontend-music-v1/')
# Reviewed exceptions to the exclusion above. Deliberately empty: an entry needs
# the owner's explicit decision, recorded in docs/release-rights.md.
NATIVE_RAW_WHITELIST = frozenset()
# SIM's observed EGA palette, as recorded by the original extraction receipts.
EGA = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],[170,0,0],[170,85,0],
       [0,170,0],[85,255,85],[255,255,85],[0,0,0],[255,85,85],[0,0,170],[85,255,255],[255,255,255]]
# Gunner-station CRAM rebuilt from the ROM's palette records near 58E20: banks
# 0, 1 (14 words plus its two shared leading entries), 2 (plus 58FF2) and 3.
GENESIS_PALETTE = [[0x58EDE,16],[0x58E20,14],[0x58EDE,2],[0x58F2A,14],[0x58FF2,2],[0x58F04,16]]
NATIVE_EXCLUDED = {
    'local-art/pc-ui-v2/panel-contact.png': 'contact sheet of decoded PC plates; not read at runtime',
    'local-art/pc-graphics-native-v1/plates.png': 'composite of emulator-captured Genesis screens; needs a Genesis capture at import',
}
# Reviewed shipped files that touch original data but carry no original pixel,
# colour or sample content. Recorded in the table so a change needs review.
NATIVE_REVIEWED = {
    'local-art/genesis/status-damage-v1/difference-*.png': 'five 113-344-byte one-bit masks (32x16 to 72x24) of where the five damage states differ; no original colours or pixels',
    'local-art/genesis/status-damage-v1/damage-*.png': 'authored remaster art',
    'local-art/pc-information-completion-v1/information.json': 'caption "mask"/"original_mask" fields are 120-265-bit one-bit cell masks of the five-pixel words ABRAMS and M1A1 plus vector contours; the topdown donor crops live under local-art/genesis/source and are excluded',
}
# Genesis tile plates decoded from the ROM's own compressed resources: tile
# bank, 40x25 map, palette command lists and, for scene 2, the map-23 smoke.
NEWSPAPERS = {'victory': (0x2A1BA, 0x1A816), 'defeat': (0x2CC2C, 0x1AEFC), 'stalemate': (0x2F588, 0x1B5DE)}
AFTERMATH = {'scene1': (0x31C40, 0x1BCAC, 0x58E42, None), 'scene2': (0x34A84, 0x1C2F2, 0x58E68, 0x1C5AC)}
# Modern's per-shape SHAPE.TBL structure; catalog.json pins it, never ships it.
SHAPE_REGISTRY = 'local-art/pc-modern/source-shapes.json'
MODERN_CATALOG = 'local-art/pc-modern/catalog.json'


def check_registry_pin(root, rows):
    """The derived registry must be exactly the one catalog.json pins.

    Original-free checkouts carry no catalogue; the shipped one is checked."""
    catalog = root/MODERN_CATALOG
    if not catalog.is_file(): return
    pin = json.loads(catalog.read_text()).get('source_registry', {})
    row = next((row for row in rows if row['path'] == SHAPE_REGISTRY), None)
    if row is None or pin.get('file') != Path(SHAPE_REGISTRY).name or pin.get('sha256') != row['sha256']:
        raise ValueError('Modern source registry pin differs from '+MODERN_CATALOG+'; rebuild the catalogue, then run tools/standalone/build.py --refresh-derived')


def derivation_specs():
    """Path -> (origin, recipe without its JSON template)."""
    specs = {}
    for name in ('FRAME','DRIVER.BIN','AA.BIN','TC.BIN','GPS.BIN','STATUS.BIN','IDENTIFY'):
        specs['local-art/pc-ui-v2/'+name.lower().replace('.','-')+'.png'] = ('pc', {'kind':'pc-plates','sources':[name],'palette':EGA})
    for index in range(7):
        specs[f'local-art/pc-ui-v2/strut-{index:02d}.png'] = ('pc', {'kind':'pc-bitmap','source':'STRUTS.BMP','index':index,'palette':EGA})
    specs['local-art/pc-graphics-native-v1/expected.png'] = ('pc', {'kind':'pc-plates','palette':EGA,
        'sources':['GPS.BIN','TC.BIN','AA.BIN','DRIVER.BIN','STATUS.BIN','ATBASE.BIN']})
    specs['local-art/pc-portraits-v1/faces.json'] = ('pc', {'kind':'json','fills':[
        {'at':['images'],'value':{'kind':'pc-bitmaps','source':'FACES.BMP'}}]})
    specs['local-art/pc-motor-pool-v1/motor-pool.json'] = ('pc', {'kind':'json','fills':[
        {'at':['packed_indices_base64'],'value':{'kind':'pc-resource-base64','source':'ATBASE.BIN'}}]})
    specs['local-art/pc-arming-panel-v1/arming-panel.json'] = ('pc', {'kind':'json','fills':[
        {'at':['indices_base64'],'value':{'kind':'pc-bitmap-base64','source':'CLIP.BMP','index':0}}]})
    specs[SHAPE_REGISTRY] = ('pc', {'kind':'pc-shape-registry','source':'SHAPE.TBL'})
    specs['reference/genesis/extracted/gunner/palette.gpl'] = ('genesis', {'kind':'gimp-palette',
        'name':'Abrams Genesis captured palette','segments':GENESIS_PALETTE})
    specs['local-art/genesis/source/effects-v1/effects.json'] = ('genesis', {'kind':'json','fills':
        [{'at':['palette_rgb'],'value':{'kind':'genesis-palette','segments':[[0x58F04,16]]}}]+
        [{'at':['images',index,field],'value':{'kind':'genesis-effect','index':index,'field':field}}
         for index in range(64) for field in ('pixels','opaque')]})
    for name, (tiles, table) in NEWSPAPERS.items():
        specs[f'local-art/genesis/source/newspapers-v1/{name}-original.png'] = ('genesis', {'kind':'genesis-plate',
            'tiles':tiles, 'map':table, 'palette_commands':[0x58E8E, 0x58FE6], 'overlay':None})
    for name, (tiles, table, palette, overlay) in AFTERMATH.items():
        specs[f'local-art/genesis/source/aftermath-v1/{name}-original.png'] = ('genesis', {'kind':'genesis-plate',
            'tiles':tiles, 'map':table, 'palette_commands':[palette], 'overlay':overlay})
    return specs


def refresh_derivations(root=ROOT):
    """Re-pin the derivation table from local originals; every pin is proven."""
    rom = (root/'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_SHA: raise ValueError('Unsupported local Genesis ROM')
    inputs = DerivationInputs(game=root/'GAME', rom=rom)
    rows = []
    for name, (origin, recipe) in sorted(derivation_specs().items()):
        data = (root/name).read_bytes()
        if recipe['kind'] == 'json':
            template = json.loads(data)
            for fill in recipe['fills']:
                at = template
                for key in fill['at'][:-1]: at = at[key]
                at[fill['at'][-1]] = None
            recipe = dict(recipe, template=template)
        if derive(recipe, inputs) != data:
            raise ValueError('Derivation does not reproduce the local file exactly: '+name)
        rows.append({'path':name, 'origin':origin, 'sha256':hashlib.sha256(data).hexdigest(), 'recipe':recipe})
    check_registry_pin(root, rows)
    table = {'schema':1, 'rom_sha256':ROM_SHA, 'excluded_prefixes':list(NATIVE_EXCLUDED_PREFIXES),
             'excluded':NATIVE_EXCLUDED, 'reviewed':NATIVE_REVIEWED, 'derived':rows}
    output = root/DERIVED_TABLE
    if inside_source(output, root): raise ValueError('Refusing to write inside original sources')
    # Never sort keys: JSON templates must keep their original member order.
    output.write_text(json.dumps(table, indent=1)+'\n')
    if json.loads(output.read_text()) != table: raise ValueError('Derivation table did not round-trip')
    for row in json.loads(output.read_text())['derived']:
        if hashlib.sha256(derive(row['recipe'], inputs)).hexdigest() != row['sha256']:
            raise ValueError('Written derivation does not reproduce its pin: '+row['path'])
    return table


def native_derivations(root):
    """The committed derivation table, checked against any local copy."""
    table = json.loads((root/DERIVED_TABLE).read_text())
    if table.get('schema') != 1 or tuple(table.get('excluded_prefixes', ())) != NATIVE_EXCLUDED_PREFIXES:
        raise ValueError('Unsupported native derivation table')
    specs = derivation_specs()
    if {row['path'] for row in table['derived']} != set(specs) or table['excluded'] != NATIVE_EXCLUDED or table.get('reviewed') != NATIVE_REVIEWED:
        raise ValueError('Native derivation table is stale; run tools/standalone/build.py --refresh-derived')
    for row in table['derived']:
        local = root/row['path']
        # Original-free CI checkouts have no local copy; the pin still applies.
        if local.is_file() and sha(local) != row['sha256']:
            raise ValueError('Derived input changed: '+row['path']+'; run tools/standalone/build.py --refresh-derived')
    check_registry_pin(root, table['derived'])
    return table


def native_excluded(name, table):
    if name in NATIVE_RAW_WHITELIST: return False
    return (name.startswith(NATIVE_EXCLUDED_PREFIXES) or name in table['excluded']
            or name in {row['path'] for row in table['derived']})


def check_native_payload(rows, table):
    # Defence in depth against a widened allowlist or a later payload edit.
    leaked = [row['path'] for row in rows if native_excluded(row['path'], table)]
    if leaked: raise ValueError('Original-derived data must not ship in a native app: '+', '.join(leaked[:5]))
    banned = {row['sha256'] for row in table['derived']}
    if any(row['sha256'] in banned for row in rows): raise ValueError('A pinned derived file appears under another payload path')


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
    table = native_derivations(root)
    # The app is the tester handoff, so it carries the review kits' boundary
    # scan (fingerprints, LFS pointers, credentials). Pinned originals at their
    # pinned paths are never shipped, so nothing here needs that exemption.
    guard = package_build.boundary_guard()
    chosen = []
    for name in names:
        if name.startswith('GAME/') or name == '.runtime/pc-core/abrams-ref.zip' or native_excluded(name, table): continue
        data = (root/name).read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        if digest in original_hashes:
            raise ValueError('An original input appears outside the excluded locations: '+name)
        guard(name, data, 'standalone')
        chosen.append({'path':name, 'sha256':digest, 'size':(root/name).stat().st_size,
                       'mode':0o755 if name.endswith(('.command','.sh')) else 0o644})
    check_native_payload(chosen, table)
    return chosen


# Licence texts of the interpreter and packages that are actually frozen.
NOTICE_CODE = '''import importlib.metadata as m,json,pathlib,sys,sysconfig
out={}
for package in ['Pillow','PyInstaller']:
 d=m.distribution(package)
 for f in d.files:
  if '.dist-info/licenses/' in str(f) and d.locate_file(f).is_file():out[package+'/'+str(f).split('/licenses/')[1]]=d.locate_file(f).read_text()
for p in [pathlib.Path(sysconfig.get_path('stdlib'))/'LICENSE.txt',pathlib.Path(sys.base_prefix)/'LICENSE.txt']:
 if p.is_file():out['Python/LICENSE.txt']=p.read_text();break
else:raise RuntimeError('Python licence text not found')
print(json.dumps(out,indent=2))'''
PROBE_CODE = 'import sys,PyInstaller,PIL;print(PyInstaller.__version__);print(PIL.__version__);print(sys.version.split()[0]);print(sys.implementation.cache_tag)'


def freeze(cache, python, target="macos"):
    native = target != "macos"
    destination = cache/'dist/AbramsRuntime'
    marker = cache/'frozen.json'
    notices = cache/'Python-runtime.json'
    # The frozen binary contains only the entry point, standard library and Pillow.
    # Project modules remain verified data files in the external installation.
    modules = set()
    for path in (ROOT/'tools').rglob('*.py'):
        for node in ast.walk(ast.parse(path.read_text())):
            candidates = [alias.name for alias in node.names] if isinstance(node, ast.Import) else ([node.module] if isinstance(node, ast.ImportFrom) and not node.level and node.module else [])
            modules.update(name for name in candidates if name.split('.')[0] in sys.stdlib_module_names)
    # Probe the selected interpreter before any cache reuse, so a different
    # Python or package release can never reuse an older frozen runtime.
    probe = subprocess.check_output([str(python), '-c', PROBE_CODE], text=True).split()
    if len(probe) != 4 or probe[:2] != ['6.22.3', '12.0.0']:
        raise ValueError('Expected PyInstaller 6.22.3 and Pillow 12.0.0 in isolated build interpreter')
    config = {'entry_sha256':sha(ROOT/'tools/standalone/entry.py'), 'stdlib':sorted(modules), 'pyinstaller':probe[0], 'pillow':probe[1],
              'python':probe[2], 'cache_tag':probe[3], 'target':target, 'machine':platform.machine()}
    if native: config['python_options'] = ['X utf8']
    if destination.exists():
        recorded = json.loads(marker.read_text()) if marker.is_file() else {}
        if {k: v for k, v in recorded.items() if k != 'notices_sha256'} != config or not notices.is_file() or sha(notices) != recorded.get('notices_sha256'):
            raise ValueError('Frozen runtime inputs changed; use a fresh build-cache path')
        return destination
    cache.mkdir(parents=True, exist_ok=True)
    command = [str(python), '-m', 'PyInstaller','--onedir','--name','AbramsRuntime','--noupx',
               '--distpath',str(cache/'dist'),'--workpath',str(cache/'work'),'--specpath',str(cache), '--collect-submodules','PIL']
    if not native: command += ['--target-arch','arm64']
    else: command += ['--python-option','X utf8']
    for name in sorted(modules): command += ['--hidden-import',name]
    command.append(str(ROOT/'tools/standalone/entry.py'))
    subprocess.run(command, check=True, env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
    # Notices are captured with the runtime they describe and reused with it.
    notices.write_bytes(subprocess.check_output([str(python), '-c', NOTICE_CODE]))
    marker.write_text(json.dumps(dict(config, notices_sha256=sha(notices)),indent=2)+'\n')
    return destination


def verify(bundle):
    resources=bundle/'Contents/Resources'
    manifest=json.loads((resources/'RUNTIME.json').read_text())
    from tools.standalone.runtime import valid_payload
    valid_payload(resources, manifest)
    check_native_payload(manifest['files'], native_derivations(ROOT))
    banned={CONTENT_SHA,ROM_SHA} | {r['sha256'] for r in json.loads((resources/'kit/tools/package/game-inputs.json').read_text())['files']}
    banned|={row['sha256'] for row in manifest.get('derived',[])}
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
    # Licence texts captured from the interpreter that produced this frozen runtime.
    shutil.copyfile(cache/'Python-runtime.json',notices/'Python-runtime.json')
    derived=native_derivations(ROOT)['derived']
    identity=hashlib.sha256(json.dumps({'files':rows,'derived':derived,'godot':sha(godot),'frozen':json.loads((cache/'frozen.json').read_text())},sort_keys=True).encode()).hexdigest()[:20]
    manifest={'schema':1,'version':VERSION,'repository':REPOSITORY,'build_id':identity,'originals_included':False,'files':rows,'derived':derived,'platform':'macOS arm64',
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
    p.add_argument('--refresh-derived',action='store_true',help='re-pin '+DERIVED_TABLE+' from local originals')
    a=p.parse_args()
    if a.refresh_derived:result={'derived':len(refresh_derivations()['derived'])}
    elif a.verify:result=verify(a.verify.resolve())
    else:
        if not all([a.output,a.godot,a.python]):p.error('--output, --godot and --python are required')
        result=build(a.output.resolve(),a.godot.resolve(),a.python.absolute(),a.cache.resolve())
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
