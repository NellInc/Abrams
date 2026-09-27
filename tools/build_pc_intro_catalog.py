#!/usr/bin/env python3
"""Build local title/flash/credit bindings from complete original PC frames.

Genesis supplies the artwork; PC source bitmaps independently prove the title
and four cumulative flash poses. Credits retain exact source-shaped lettering.
"""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops
from tools.inspect_scenarios import decode_resource
from tools.extract_pc_ui import screen_pixels
from tools.pc_bitmaps import decode_bitmaps
from tools.pc_fonts import decode_font, text_pixels

ROOT = Path(__file__).resolve().parents[1]
PINS = {'START.EXE':'a6fd07ae3df4f61806852d92c0c50354b7f7afccee10da88710ef0bc3361ca6a',
        'CREDITS':'97b431e019a277f63239da90ddebd27c02a2417a2d7dfa750e94fc6faf7a07ae',
        'EXPLO.BMP':'db1cdf18b4b0ac0d6e4fc5f0a5a99a14eb6ee4cf63f7296e6c94176940cdce33'}
PALETTE = [(0,0,0),(255,255,255),(170,170,170),(85,85,85),(85,85,255),
           (85,255,255),(255,85,85),(170,85,0),(0,170,0),(85,255,85),(255,255,85),(0,0,0)]
FRAMES = [403,404,405,408,411,514,754,995,1235,1475,1712,1952,2193]
POSES = [(173,100),(178,100),(182,93),(196,87)]
# Explicit atlas donor regions omit only transparent margins/isolated generated
# specks. Target bounds come from the actual cumulative PC frame, not a timer.
DONORS = [[63,127,350,255],[813,124,448,319],[61,604,586,432],[784,577,664,509]]
# Source bytes verify every letter before any outline face may replace it.
# These are the actual displayed names, including VOLKMER and RICH HILLEMAN.
CREDIT_LINES = [
    [('DIRECTOR',221,120,True),('DAMON SLYE',214,136,False)],
    [('SIMULATION',211,120,True),('DAVID MCCLURG',200,136,False)],
    [('PRODUCT SHELL',204,117,True),('RICHARD RAYL',206,131,False),('GREG VOLKMER',206,140,False)],
    [('ARTISTRY',221,117,True),('KOBI MILLER',206,131,False),('CYRUS KANGA',206,140,False)],
    [('DESIGN',229,120,True),('DAMON SLYE',214,136,False)],
    [('WORLD',226,117,True),('CREATION',218,126,True),('JERRY LUTTRELL',198,139,False)],
    [('PRODUCER',221,120,True),('RICH HILLEMAN',202,136,False)],
    [('ABRAMS BATTLETANK',175,118,True),('COPYRIGHT 1988,89',175,130,True),('DYNAMIX,INC',194,150,True)]]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def spans(image, box):
    result = {}
    x0,y0,x1,y1 = box
    for y in range(y0,y1):
        x = x0
        while x < x1:
            rgb = image.getpixel((x,y)); end = x+1
            while end < x1 and image.getpixel((end,y)) == rgb: end += 1
            result.setdefault(rgb, []).append([x,y,end-x,1]); x = end
    return [{'rgb':list(rgb), 'rects':rects} for rgb,rects in sorted(result.items())]


def build(root, capture):
    for name,pin in PINS.items():
        if sha(root/'GAME'/name)!=pin: raise ValueError('unsupported original '+name)
    report = json.loads((capture/'report.json').read_text())
    if report['mode']!='trace' or not report['checks'].get('all_records_identical'):
        raise ValueError('requires original-baseline compared trace')
    base = Image.new('RGB',(320,200))
    base.putdata([PALETTE[c] for c in screen_pixels(decode_resource((root/'GAME/CREDITS').read_bytes()))])
    sprites = decode_bitmaps(decode_resource((root/'GAME/EXPLO.BMP').read_bytes()))
    if [(s['width'],s['height']) for s in sprites]!=[(64,46),(80,60),(128,95),(160,125)]:
        raise ValueError('unsupported original flash directory')
    current = base.copy(); entries = []
    for index,frame in enumerate(FRAMES):
        record = report['records'][frame]
        path = capture/report['images'][record['rgb_sha256']]['image']
        with Image.open(path) as raw: image = raw.convert('RGB')
        if record['program']['name']!='START' or hashlib.sha256(image.tobytes()).hexdigest()!=record['rgb_sha256']:
            raise ValueError('capture identity differs')
        if 1 <= index <= 4:
            sprite = sprites[index-1]
            rgb = Image.new('RGB',(sprite['width'],sprite['height']))
            rgb.putdata([PALETTE[c] for c in sprite['pixels']])
            mask = Image.new('L',rgb.size); mask.putdata([255 if c else 0 for c in sprite['pixels']])
            current.paste(rgb, POSES[index-1], mask)
        if index <= 4 and current.tobytes()!=image.tobytes():
            raise ValueError('original title/flash source composition differs')
        entry = {'name':'title' if index==0 else f'flash-{index}' if index<=4 else f'credit-{index-4}',
                 'rgb_sha256':record['rgb_sha256'], 'capture_image':path.name, 'flash':min(index,4),
                 'overlays':[], 'text_runs':[]}
        if index >= 5:
            box = (194,110,314,150) if index < 12 else (172,110,314,162)
            outside = image.copy(); outside.paste(current.crop(box),box[:2])
            if outside.tobytes()!=current.tobytes(): raise ValueError('credit changed pixels outside original card')
            entry['credit_rect'] = [box[0],box[1],box[2]-box[0],box[3]-box[1]]
            entry['overlays'] = spans(image,box)
            for words,x,y,stencil in CREDIT_LINES[index-5]:
                name='STENCIL.FNT' if stencil else '8X6.FNT'
                font=decode_font((root/'GAME'/name).read_bytes())
                width,height,bits=text_pixels(font,words.encode('ascii'))
                fg=(85,85,255) if stencil and index<12 else (255,255,255)
                expected=bytes(c for bit in bits for c in (fg if bit else (0,0,0)))
                if image.crop((x,y,x+width,y+height)).tobytes()!=expected:
                    raise ValueError('credit text differs from original glyph bytes: '+words)
                entry['text_runs'].append({'text':words,'font':name,'font_sha256':font['sha256'],
                                          'rect':[x,y,width,height],'cell':[font['width'],font['height']],
                                          'foreground':list(fg)})
        entries.append(entry)
    flashes = []
    for index,frame in enumerate(FRAMES[1:5]):
        with Image.open(capture/f'frame-{frame:04d}.png') as raw: image = raw.convert('RGB')
        x0,y0,x1,y1 = ImageChops.difference(base,image).getbbox()
        flashes.append({'rect':[x0,y0,x1-x0,y1-y0], 'source_rect':DONORS[index]})
    assets = {}
    for name,file in [('title','title-v1.png'),('flash','intro-v1/flash-atlas-v1.png')]:
        path = root/'local-art/genesis/remastered'/file
        with Image.open(path) as image: size = list(image.size)
        assets[name] = {'path':file,'sha256':sha(path),'size':size}
    return {'schema':1, 'sources':PINS, 'assets':assets, 'entries':entries, 'flashes':flashes,
            'capture_report_sha256':sha(capture/'report.json'),
            'source_proof':{'complete_title_and_flash_frames':5,'compared_rgb_pixels':320000,
                            'cumulative_sprite_positions':[list(p) for p in POSES]},
            'scope':__doc__}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--capture',type=Path,default=ROOT/'artifacts/pc-intro-trace-01')
    p.add_argument('--output',type=Path,required=True)
    args = p.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ['GAME','GENESIS']):
        p.error('output must be outside source directories')
    data = build(ROOT,args.capture)
    args.output.mkdir(parents=True,exist_ok=False)
    path = args.output/'intro.json'; path.write_text(json.dumps(data,indent=2)+'\n')
    print(len(data['entries']),'complete frame bindings;',sha(path))


if __name__ == '__main__': main()
