#!/usr/bin/env python3
"""Exact original office recognition for CO.BMP poses 3, 4 and 5.

The two original programs contain the same six-entry placement table. Source
pixels supply recognition and performance identity; authored Genesis-derived
portrait variants supply only the remaster artwork. No guest or source writes.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
from PIL import Image

from tools.build_pc_frontend_catalog import PALETTE, HEIGHTS, PINS, compose
from tools.extract_pc_ui import screen_pixels
from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps
from tools.unpack_pc_executables import unpack

ROOT = Path(__file__).resolve().parents[1]
PLACEMENTS = [(3,84,36,'arm-lowered'),(4,82,36,'pistol-raised'),(5,66,33,'thumbs-up')]
PROGRAMS = {
    'BRIEF.EXE': {'sha256':'11565943351af89d069595864d26728c866ffa30cb09e66a1765c571978a7c92',
                  'data_segment':0xc71,'table_offset':0x76a,'draw_call':'0512 -> 03c7:034f'},
    'END.EXE': {'sha256':'82ab4efab14dfdfd6d9d0c6c8276e2c2187dbe4e6f8f09cc9fc0fa6267ad0c40',
                'data_segment':0xd22,'table_offset':0x434,'draw_call':'0940 -> 0477:034b'},
}
ART_REFERENCE = 'local-art/genesis/remastered/wilson-v1.png'
ART_REFERENCE_SHA = '82d31f8db905605a772ff6aa564a20dc7dc385433e2abacfe92b506511a4e2a9'
EXPECTED_COORDINATES = (89,86,91,84,82,66,36,36,47,36,36,33)


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def source_templates(root=ROOT):
    game=root/'GAME'
    for name,pin in PINS.items():
        if sha(game/name)!=pin: raise ValueError('unsupported original '+name)
    for name,definition in PROGRAMS.items():
        if sha(game/name)!=definition['sha256']: raise ValueError('unsupported original '+name)
        code,_=unpack((game/name).read_bytes())
        address=definition['data_segment']*16+definition['table_offset']
        if struct.unpack_from('<12H',code,address)!=EXPECTED_COORDINATES:
            raise ValueError('original Wilson placement table differs: '+name)
    office=screen_pixels(decode_resource((game/'OFFICE').read_bytes()))
    sprites=decode_bitmaps(decode_resource((game/'CO.BMP').read_bytes()))
    if len(sprites)!=6: raise ValueError('unsupported CO bitmap count')
    expected_sizes={3:(136,130),4:(144,130),5:(152,132)}
    entries=[]
    for index,x,y,name in PLACEMENTS:
        sprite=sprites[index]
        if (sprite['width'],sprite['height'])!=expected_sizes[index]: raise ValueError('unsupported CO geometry')
        rgb=compose(office,sprite,x,y)
        points=[(i%sprite['width'],i//sprite['width']) for i,c in enumerate(sprite['pixels']) if c]
        left,top=min(p[0] for p in points),min(p[1] for p in points)
        right,bottom=max(p[0] for p in points)+1,max(p[1] for p in points)+1
        entries.append({'pose':index,'name':name,'source':'CO.BMP','source_index':index,
                        'source_origin':[x,y],'source_size':[sprite['width'],sprite['height']],
                        'source_opaque_pixels':len(points),
                        'portrait_rect':[x+left,y+top,right-left,bottom-top],
                        'hashes':{str(h):hashlib.sha256(rgb[:320*h*3]).hexdigest() for h in HEIGHTS}})
    return entries,sprites,office


def extract(root,output):
    entries,sprites,office=source_templates(root)
    output.mkdir(parents=True,exist_ok=False)
    for entry in entries:
        sprite=sprites[entry['pose']]
        image=Image.new('RGBA',tuple(entry['source_size']))
        image.putdata([(*PALETTE[c],255 if c else 0) for c in sprite['pixels']])
        image.save(output/('co-%02d.png'%entry['pose']))
        rgb=compose(office,sprite,*entry['source_origin'])
        Image.frombytes('RGB',(320,200),rgb).save(output/('office-co-%02d.png'%entry['pose']))
    (output/'manifest.json').write_text(json.dumps({'sources':PINS|{n:d['sha256'] for n,d in PROGRAMS.items()},
        'placements':entries,'program_tables':PROGRAMS,
        'scope':'Lossless PC recognition/reference extracts; these are not remastered artwork.'},indent=2)+'\n')


def build(root=ROOT):
    entries,_,_=source_templates(root)
    if sha(root/ART_REFERENCE)!=ART_REFERENCE_SHA: raise ValueError('selected Genesis Wilson differs')
    for entry in entries:
        relative='wilson-completion-v1/wilson-'+entry['name']+'-v1.png'
        path=root/'local-art/genesis/remastered'/relative
        with Image.open(path) as image:
            if image.mode!='RGBA' or image.width<512 or image.height<512:
                raise ValueError('high-resolution RGBA artwork required: '+entry['name'])
            alpha=image.getchannel('A')
            if alpha.getextrema()!=(0,255): raise ValueError('genuine alpha required: '+entry['name'])
            entry['art']={'file':relative,'sha256':sha(path),'size':list(image.size),
                          'alpha_bbox':list(alpha.getbbox()),'alpha_extrema':list(alpha.getextrema())}
        entry['art']['basis']='Authored performance variant of approved Genesis-derived Wilson; not a recovered Genesis animation frame.'
    return {'schema':1,'sources':PINS|{n:d['sha256'] for n,d in PROGRAMS.items()},
            'heights':HEIGHTS,'palette_rgb':PALETTE,'templates':entries,'program_tables':PROGRAMS,
            'art_reference':{'file':ART_REFERENCE,'sha256':ART_REFERENCE_SHA},
            'scope':'Additional exact original office-prefix hashes only. Runtime must retain its complete source match, original dialogue border, BRIEF/END program gates and protected dialogue. No new pose timing or simulation.'}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--extract',type=Path)
    parser.add_argument('--output',type=Path,default=ROOT/'local-art/pc-wilson-completion-v1/office.json')
    args=parser.parse_args()
    destination=args.extract or args.output
    if any(destination.resolve().is_relative_to((ROOT/name).resolve()) for name in ('GAME','GENESIS')):
        parser.error('output must be outside original sources')
    if args.extract:
        extract(ROOT,args.extract)
    else:
        data=build();args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(json.dumps(data,indent=2)+'\n')
        print(json.dumps({'file':str(args.output),'sha256':sha(args.output),
                          'poses':[t['pose'] for t in data['templates']]}))


if __name__=='__main__': main()
