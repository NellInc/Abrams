#!/usr/bin/env python3
"""Build exact PC office recognition hashes; Genesis supplies all rendered art.

The prefix above a complete original dialogue border must match in its entirety.
No text recognition, screenshot-derived artwork, guest writes or tolerant match.
The catalog is local-only, derived from the supplied original resources.
"""
import argparse
import base64
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


def motor_pool(game):
    name='ATBASE.BIN'
    pin='7a2b2e763b37623f423c7f332c2a34d4bb810f5a457a3d8f55aec27e9262ac03'
    source=(game/name).read_bytes()
    if hashlib.sha256(source).hexdigest()!=pin: raise ValueError('unsupported original '+name)
    packed=decode_resource(source)
    if len(packed)!=32000: raise ValueError('unsupported motor-pool dimensions')
    return {'schema':1,'source':name,'source_sha256':pin,'width':320,'height':200,
            'packed_indices_base64':base64.b64encode(packed).decode(),
            'scope':'Original PC indices for recognition only. Genesis supplies replacement artwork.'}


def arming_panel(game):
    source=(game/'CLIP.BMP').read_bytes()
    pin='496e4349840d934c42da24fc929b25869a0db050dd6a66ac68a9349af6b7e6ce'
    if hashlib.sha256(source).hexdigest()!=pin: raise ValueError('unsupported original CLIP.BMP')
    images=decode_bitmaps(decode_resource(source))
    if len(images)!=1 or (images[0]['width'],images[0]['height'])!=(88,113):
        raise ValueError('unsupported clipboard geometry')
    return {'schema':1,'source':'CLIP.BMP','source_sha256':pin,'origin':[239,87],
            'width':88,'height':113,'indices_base64':base64.b64encode(bytes(images[0]['pixels'])).decode(),
            'preserved_pixels':[[312,199]],
            'scope':'Original clipboard recognition only. Genesis menu supplies rendered panel style. One intermittently overwritten bottom pixel remains original.'}


def information(game, capture):
    from PIL import Image
    try:
        from tools.capture_pc_session import INFORMATION_PAGES, INFORMATION_HEIGHT
        from tools.extract_pc_portraits import verify_loaded
    except ModuleNotFoundError:
        from capture_pc_session import INFORMATION_PAGES, INFORMATION_HEIGHT
        from extract_pc_portraits import verify_loaded
    pins={'START.EXE':'a6fd07ae3df4f61806852d92c0c50354b7f7afccee10da88710ef0bc3361ca6a',
          'INFO.BMP':'3cdf0c2dcadc387215a1bf4251ceb046820db6439ffcce419a9de2b61bcceff2'}
    for name,pin in pins.items():
        if hashlib.sha256((game/name).read_bytes()).hexdigest()!=pin: raise ValueError('unsupported '+name)
    report=json.loads((capture/'report.json').read_text())
    if report['mode']!='baseline' or not all(report['checks'].values()): raise ValueError('passing original information capture required')
    sprites=decode_bitmaps(decode_resource((game/'INFO.BMP').read_bytes()))
    definitions=[('ax',[112,22,200,65],[(0,112,22)],'info-v1/ammo-ax-v2.png'),
                 ('sabot',[122,22,192,64],[(2,122,22)],'info-v1/ammo-sabot-v2.png'),
                 ('coax',[146,89,144,35],[(4,146,89)],'armament-v1/weapon-coax-v2.png'),
                 ('cannon',[135,89,176,27],[(6,135,89)],'armament-v1/weapon-cannon-v2.png'),
                 ('smoke',[182,88,129,42],[(8,182,88),(9,247,88)],'armament-v1/weapon-smoke-v2.png')]
    entries=[]
    for name,rect,placements,art in definitions:
        source=Image.open(capture/(name+'.png')).convert('RGB')
        if source.size!=(320,200): raise ValueError('unsupported source frame')
        pin=hashlib.sha256(source.crop((0,0,320,INFORMATION_HEIGHT)).tobytes()).hexdigest()
        if pin!=INFORMATION_PAGES[name]: raise ValueError('source page differs: '+name)
        proof=[]
        for index,x,y in placements:
            sprite=sprites[index]
            for i,c in enumerate(sprite['pixels']):
                if c and source.getpixel((x+i%sprite['width'],y+i//sprite['width']))!=PALETTE[c]:
                    raise ValueError('original illustration differs: '+name)
            proof.append(verify_loaded((capture/(name+'.bin')).read_bytes(),sprite))
        path=game.parent/'local-art/genesis/remastered'/art
        image=Image.open(path)
        entries.append({'name':name,'rgb_sha256':pin,'rect':rect,'art':art,
                        'art_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'size':list(image.size),'loaded_source_proof':proof})
    return {'schema':1,'sources':pins,'recognition_height':INFORMATION_HEIGHT,'entries':entries,
            'scope':'Exact original page prefix and loaded INFO bitmap proof. Genesis illustrations only; all text, borders below row 175 and unsupported pages stay original.'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    mode=p.add_mutually_exclusive_group()
    mode.add_argument('--motor-pool',action='store_true')
    mode.add_argument('--arming-panel',action='store_true')
    mode.add_argument('--information-capture',type=Path);a=p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS')):
        p.error('output must be outside original sources')
    data=information(ROOT/'GAME',a.information_capture) if a.information_capture else arming_panel(ROOT/'GAME') if a.arming_panel else motor_pool(ROOT/'GAME') if a.motor_pool else build(ROOT/'GAME')
    a.output.mkdir(parents=True,exist_ok=False)
    payload=(json.dumps(data,indent=2)+'\n').encode()
    (a.output/('information.json' if a.information_capture else 'arming-panel.json' if a.arming_panel else 'motor-pool.json' if a.motor_pool else 'office.json')).write_bytes(payload)
    print(json.dumps({'catalog_sha256':hashlib.sha256(payload).hexdigest(),
                      'poses':[x['portrait_rect'] for x in data.get('templates',[])]}))


if __name__=='__main__':main()
