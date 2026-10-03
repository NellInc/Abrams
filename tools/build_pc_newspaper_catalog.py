#!/usr/bin/env python3
"""Bind Genesis-authored newspapers to exact original PC plate/header pixels.

The original END program selects the outcome and draws the subsequent prose.
A matched 72-row header never authorizes replacing any lower-page pixel.
"""
import argparse
import hashlib
import json
import sys
from pathlib import Path
from PIL import Image
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[1]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.inspect_scenarios import decode_resource
from tools.extract_pc_ui import screen_pixels
from tools.extract_genesis_newspapers import ENTRIES, ROM_SHA
from tools.source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]
PINS = {'END.EXE':'82ab4efab14dfdfd6d9d0c6c8276e2c2187dbe4e6f8f09cc9fc0fa6267ad0c40'}
# These plates use only monochrome slots 0..3; refuse any other palette index.
PALETTE = [(0,0,0),(255,255,255),(170,170,170),(85,85,85)]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def build(root=ROOT):
    manifest = root/'local-art/genesis/source/newspapers-v1/manifest.json'
    provenance = json.loads(manifest.read_text())
    if provenance['rom_sha256'] != ROM_SHA: raise ValueError('wrong Genesis source')
    if sha(root/'GAME/END.EXE') != PINS['END.EXE']: raise ValueError('wrong PC executable')
    result = {'schema':1,'sources':{'END.EXE':PINS['END.EXE']},'entries':[],
              'genesis_manifest_sha256':sha(manifest),'header_height':72,'scope':__doc__}
    for name, (_, _, _, original) in ENTRIES.items():
        raw = root/'GAME'/original
        indices = screen_pixels(decode_resource(raw.read_bytes()))
        if any(i >= 4 for i in indices): raise ValueError('newspaper uses unproven palette')
        rgb = bytes(c for i in indices for c in PALETTE[i])
        result['sources'][original] = sha(raw)
        record = {'name':name,'source':original,'rgb_sha256':hashlib.sha256(rgb).hexdigest(),
                  'header_sha256':hashlib.sha256(rgb[:320*72*3]).hexdigest()}
        for key, path in [('native',manifest.parent/(name+'-original.png')),
                          ('art',root/'local-art/genesis/remastered/newspapers-v1'/(name+'-v1.png'))]:
            with Image.open(path) as im: size = list(im.size)
            if key == 'native' and sha(path) != provenance['entries'][name]['image_sha256']:
                raise ValueError('Genesis donor changed')
            record[key] = {'path':str(path.relative_to(root)),'sha256':sha(path),'size':size}
        result['entries'].append(record)
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if inside_source(a.output, ROOT):
        p.error('output must remain outside original source directories')
    data=build();a.output.mkdir(parents=True,exist_ok=False)
    for e in data['entries']:
        indices=screen_pixels(decode_resource((ROOT/'GAME'/e['source']).read_bytes()))
        Image.frombytes('RGB',(320,200),bytes(c for i in indices for c in PALETTE[i])).save(a.output/(e['name']+'-pc.png'))
    path=a.output/'newspapers.json';path.write_text(json.dumps(data,indent=2)+'\n');print(sha(path))

if __name__=='__main__':main()
