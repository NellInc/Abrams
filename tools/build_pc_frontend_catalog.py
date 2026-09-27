#!/usr/bin/env python3
"""Build exact PC office recognition hashes; Genesis supplies all rendered art.

The prefix above a complete original dialogue border must match in its entirety.
No text recognition, screenshot-derived artwork, guest writes or tolerant match.
The catalog is local-only, derived from the supplied original resources.
"""
import argparse
import hashlib
import json
from pathlib import Path

try:
    from tools.inspect_scenarios import decode_resource
    from tools.extract_pc_ui import screen_pixels
    from tools.pc_bitmaps import decode_bitmaps
except ModuleNotFoundError:
    from inspect_scenarios import decode_resource
    from extract_pc_ui import screen_pixels
    from pc_bitmaps import decode_bitmaps

ROOT = Path(__file__).resolve().parents[1]
# Every used entry is observed in exact native office/character pixels. BRIEF
# uses bright red at index 6, unlike SIM's darker instrument red.
PALETTE = [(0,0,0),(255,255,255),(170,170,170),(85,85,85),(85,85,255),
           (85,255,255),(255,85,85),(170,85,0),(0,170,0),(85,255,85),
           (255,255,85),(0,0,0)]
POSES = [(0,89,36,'neutral'),(1,86,36,'speaking'),(2,91,47,'facepalm')]
HEIGHTS = [200,187,177,167,157,147,137]
PINS = {'OFFICE':'7781ed38148b800526c336c841ebfc548b06721849a36ee8b0300eb7ab496929',
        'CO.BMP':'e15faa367625c87dd1d93e934d19d3b2c13c7f887b2806bf441d86102a146fa0'}


def compose(office, sprite, x, y):
    if len(office)!=64000: raise ValueError('unsupported office dimensions')
    if x<0 or y<0 or x+sprite['width']>320 or y+sprite['height']>200:
        raise ValueError('portrait outside original frame')
    pixels = list(office)
    for i,c in enumerate(sprite['pixels']):
        if c: pixels[(y+i//sprite['width'])*320+x+i%sprite['width']] = c
    if any(c<0 or c>=len(PALETTE) for c in pixels): raise ValueError('unobserved office palette entry')
    return bytes(channel for c in pixels for channel in PALETTE[c])


def build(game):
    for name,pin in PINS.items():
        if hashlib.sha256((game/name).read_bytes()).hexdigest()!=pin:
            raise ValueError('unsupported original '+name)
    office = screen_pixels(decode_resource((game/'OFFICE').read_bytes()))
    sprites = decode_bitmaps(decode_resource((game/'CO.BMP').read_bytes()))
    entries=[]
    for index,x,y,name in POSES:
        sprite=sprites[index];rgb=compose(office,sprite,x,y)
        points=[(i%sprite['width'],i//sprite['width']) for i,c in enumerate(sprite['pixels']) if c]
        left,top=min(p[0] for p in points),min(p[1] for p in points)
        right,bottom=max(p[0] for p in points)+1,max(p[1] for p in points)+1
        entries.append({'pose':index,'name':name,'portrait_rect':[x+left,y+top,right-left,bottom-top],
            'hashes':{str(h):hashlib.sha256(rgb[:320*h*3]).hexdigest() for h in HEIGHTS}})
    return {'schema':1,'sources':{n:hashlib.sha256((game/n).read_bytes()).hexdigest()
                                for n in [*PINS,'BRIEF.EXE','END.EXE']},
            'palette_rgb':PALETTE,'heights':HEIGHTS,'templates':entries,
            'scope':__doc__}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS')):
        p.error('output must be outside original sources')
    data=build(ROOT/'GAME')
    a.output.mkdir(parents=True,exist_ok=False)
    payload=(json.dumps(data,indent=2)+'\n').encode()
    (a.output/'office.json').write_bytes(payload)
    print(json.dumps({'catalog_sha256':hashlib.sha256(payload).hexdigest(),
                      'poses':[x['portrait_rect'] for x in data['templates']]}))


if __name__=='__main__':main()
