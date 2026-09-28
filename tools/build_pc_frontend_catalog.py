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


def crew_information(game, capture):
    """Compose only a fully identified original crew page, with Genesis donors."""
    from PIL import Image
    try:
        from tools.extract_pc_portraits import verify_loaded
    except ModuleNotFoundError:
        from extract_pc_portraits import verify_loaded
    source=Image.open(capture/'crew.png').convert('RGB')
    fingerprint=hashlib.sha256(source.tobytes()).hexdigest()
    if fingerprint!='ab6177af9b4cf2442a41a1a7bf3f88dbafb5116186cbf4b7760efa196e798977':
        raise ValueError('unsupported complete original crew page')
    sprites=decode_bitmaps(decode_resource((game/'CREW.BMP').read_bytes()))
    ram=(capture/'crew.bin').read_bytes()
    proof=[verify_loaded(ram,sprite) for sprite in sprites]
    portraits=[(0,'gunner',18,23,49,48,'gunner-v2.png'),
               (1,'driver',18,121,49,48,'driver-v2.png'),
               (2,'loader',253,121,49,48,'loader-v1.png'),
               (3,'commander',253,24,49,47,'commander-v1.png')]
    boxes=[];layers=[]
    for index,name,x,y,w,h,art in portraits:
        sprite=sprites[index]
        for i,c in enumerate(sprite['pixels']):
            if c and source.getpixel((x+i%sprite['width'],y+i//sprite['width']))!=PALETTE[c]:
                raise ValueError('crew portrait placement differs: '+name)
        boxes.append((x,y,x+w,y+h))
        layers.append({'name':'crew-'+name,'rect':[x,y,w,h],
                       'art':'crew-v1/'+art,'fit':'stretch','frame_rgb':None})
    # This is the source diagram's measured green-ink bounding box. Registration
    # maps the selected derivative's ink bounds to it, leaving original callouts
    # and seat rectangles at their exact original positions.
    layers.insert(0,{'name':'crew-diagram','rect':[63,64,194,53],
                     'art':'crew-diagram-v1/crew-diagram-v2.png','source_rect':[33,62,2106,560],
                     'frame_rgb':None})
    genesis_path=game.parent/'local-art/genesis/source/crew-information-original.png'
    if hashlib.sha256(genesis_path.read_bytes()).hexdigest()!='766fa75a68a6cf02a5ce2b1442a6b559c9a239856cc30b1152e913eebf31d632':
        raise ValueError('Genesis crew source differs')
    genesis=Image.open(genesis_path).convert('RGB')
    # Both technical-caption masks match the Genesis source, translated only.
    caption_count=0
    for y in range(66,127):
        for x in range(56,256):
            rgb=genesis.getpixel((x,y))
            if rgb in [(172,170,172),(65,68,65)]:
                expected=(255,255,255) if rgb==(172,170,172) else (85,85,85)
                if source.getpixel((x+4,y-6))!=expected: raise ValueError('Genesis caption correspondence differs')
                caption_count+=1
    if caption_count!=386: raise ValueError('incomplete Genesis technical caption')
    wire_count=0;overdraw_count=0
    for y in range(66,127):
        for x in range(56,256):
            if genesis.getpixel((x,y))!=(98,137,65): continue
            actual=source.getpixel((x+4,y-6))
            if actual not in [(0,170,0),(255,85,85)]: raise ValueError('Genesis wireframe registration differs')
            wire_count+=1;overdraw_count+=actual==(255,85,85)
    if (wire_count,overdraw_count)!=(1853,22): raise ValueError('incomplete Genesis wireframe registration')
    colours={(255,255,85):(238,238,65),(85,255,255):(65,238,238),
             (255,85,85):(238,0,0),(170,85,0):(205,101,32)}
    overlays={}
    def ink(x,y):
        if any(left<=x<right and top<=y<bottom for left,top,right,bottom in boxes): return None
        rgb=source.getpixel((x,y))
        if 16<=x<304 and 10<=y<18 and rgb==(0,170,0): return (238,238,238)
        if 68<=x<129 and 62<=y<83:
            if rgb==(255,255,255): return (172,170,172)
            if rgb==(85,85,85): return (65,68,65)
        if 8<=x<312 and 20<=y<170 and rgb in colours:
            if rgb==(170,85,0) and 59<=x<261 and 60<=y<121: return (98,32,0)
            return colours[rgb]
        return None
    for y in range(200):
        x=0
        while x<320:
            rgb=ink(x,y)
            if rgb is None: x+=1;continue
            end=x+1
            while end<320 and ink(end,y)==rgb: end+=1
            overlays.setdefault(rgb,[]).append([x,y,end-x,1]);x=end
    return {'name':'crew','rect':[0,0,320,200],
            'rgb_sha256':hashlib.sha256(source.tobytes()[:320*175*3]).hexdigest(),
            'full_rgb_sha256':fingerprint,'background_rgb':[0,0,0],
            'layers':layers,'overlays':[{'rgb':list(rgb),'rects':rects} for rgb,rects in overlays.items()],
            'loaded_source_proof':proof,'genesis_caption_pixels_checked':caption_count,
            'genesis_wire_pixels_checked':wire_count,'original_red_callout_overdraw_pixels':overdraw_count,
            'genesis_source_sha256':hashlib.sha256(genesis_path.read_bytes()).hexdigest()}


def information_text(game, capture, name):
    """Match original loaded strings to complete glyph cells, without OCR.

    The fixed original string table is independently pinned. Longest complete
    strings win over their substrings; every accepted foreground/background
    pixel must equal its original font bit. Runtime still gates the entire page.
    """
    from PIL import Image
    try:
        from tools.pc_fonts import decode_font, text_pixels
    except ModuleNotFoundError:
        from pc_fonts import decode_font, text_pixels
    ram=(capture/'ax.bin').read_bytes()
    start=ram.index(b'C  R  E  W    S  T  A  T  I  O  N  S\0')
    end=ram.index(b'BEGIN\0CONTINUE\0REVIEW\0ERASE\0',start)
    table=ram[start:end]
    if hashlib.sha256(table).hexdigest()!='183409cc8b714bee9206d31593607b36c314142b79651206f17e51b6d4ded9d1':
        raise ValueError('original information string table differs')
    words=sorted(set(table.split(b'\0'))-{b''},key=lambda w:(-len(w),w))
    fonts={n:decode_font((game/n).read_bytes()) for n in ['6X6.FNT','8X6.FNT','8X8.FNT','STENCIL.FNT']}
    colours=[(255,255,255),(0,170,0),(255,255,85),(85,255,255),(255,85,85),(170,85,0)]
    pairs=[(colour,(0,0,0)) for colour in colours]
    if name=='crew': pairs += [((0,0,0),colour) for colour in colours]
    source=Image.open(capture/(name+'.png')).convert('RGB');rgb=source.tobytes()
    runs=[];covered=set()
    for word in words:
        for face,font in fonts.items():
            w,h,bits=text_pixels(font,word)
            if w>320: continue
            row=max(range(h),key=lambda y:sum(bits[y*w:(y+1)*w]))
            for fg,bg in pairs:
                pattern=bytes(c for bit in bits for c in (fg if bit else bg))
                needle=pattern[row*w*3:(row+1)*w*3];at=rgb.find(needle)
                while at>=0:
                    pixel=at//3;x=pixel%320;y=pixel//320-row
                    if at%3==0 and 0<=y and y+h<=175 and x+w<=320 and source.crop((x,y,x+w,y+h)).tobytes()==pattern:
                        coords={(sx,sy) for sy in range(y,y+h) for sx in range(x,x+w)}
                        if not covered.intersection(coords):
                            covered |= coords
                            runs.append({'text':word.decode('ascii'),'font':face,'font_sha256':font['sha256'],
                                         'rect':[x,y,w,h],'cell':[font['width'],h],
                                         'source_foreground':list(fg),'source_background':list(bg),
                                         'foreground':list(fg),'background':list(bg)})
                    at=rgb.find(needle,at+1)
    if name=='crew':
        palette={(0,170,0):(238,238,238),(255,255,85):(238,238,65),
                 (85,255,255):(65,238,238),(255,85,85):(238,0,0),(170,85,0):(205,101,32)}
        for run in runs:
            for key in ['foreground','background']: run[key]=list(palette.get(tuple(run[key]),tuple(run[key])))
    return sorted(runs,key=lambda r:(r['rect'][1],r['rect'][0]))


def information(game, capture):
    from PIL import Image
    try:
        from tools.capture_pc_session import INFORMATION_PAGES, INFORMATION_HEIGHT
        from tools.extract_pc_portraits import verify_loaded
    except ModuleNotFoundError:
        from capture_pc_session import INFORMATION_PAGES, INFORMATION_HEIGHT
        from extract_pc_portraits import verify_loaded
    pins={'START.EXE':'a6fd07ae3df4f61806852d92c0c50354b7f7afccee10da88710ef0bc3361ca6a',
          'INFO.BMP':'3cdf0c2dcadc387215a1bf4251ceb046820db6439ffcce419a9de2b61bcceff2',
          'CREW.BMP':'6351763f4ccbe4daca199a0ac9738039ddbd6a30720476dc5488fd84d95805bf'}
    for name,pin in pins.items():
        if hashlib.sha256((game/name).read_bytes()).hexdigest()!=pin: raise ValueError('unsupported '+name)
    report=json.loads((capture/'report.json').read_text())
    if report['mode']!='baseline' or not all(report['checks'].values()): raise ValueError('passing original information capture required')
    sprites=decode_bitmaps(decode_resource((game/'INFO.BMP').read_bytes()))
    definitions=[('ax',[112,22,200,65],[(0,112,22)],'info-v1/ammo-ax-v2.png'),
                 ('heat',[104,22,208,67],[(1,104,22)],'info-v1/ammo-heat-v2.png'),
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
        with Image.open(path) as image: size=list(image.size)
        entries.append({'name':name,'rgb_sha256':pin,'rect':rect,'art':art,
                        'art_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'size':size,'loaded_source_proof':proof})
    crew=crew_information(game,capture)
    for layer in crew['layers']:
        path=game.parent/'local-art/genesis/remastered'/layer['art']
        layer['art_sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
        with Image.open(path) as image: layer['size']=list(image.size)
    entries.append(crew)
    for entry in entries: entry['text_runs']=information_text(game,capture,entry['name'])
    return {'schema':3,'sources':pins,'recognition_height':INFORMATION_HEIGHT,'entries':entries,
            'scope':'Exact original prefix and loaded bitmap proof. Six illustration boxes and complete source-matched text cells may be remastered. The crew page requires its complete frame hash before Genesis composition; original words and callout/seat relationships remain PC-owned.'}


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
