#!/usr/bin/env python3
"""Bind three Genesis-derived overhead selection diagrams to exact PC pages.

No menu, simulation, source-game or model writes. The complete original page
identity and every nonzero INFO sprite pixel are checked independently.
"""
import hashlib
import json
from pathlib import Path
from PIL import Image
from tools.build_pc_frontend_catalog import PALETTE
from tools.capture_pc_session import INFORMATION_PAGES
from tools.extract_pc_portraits import verify_loaded
from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps

ROOT = Path(__file__).resolve().parents[1]
PLACEMENTS = [('coax', 3, 124), ('cannon', 5, 125), ('smoke', 7, 125)]

def vector_face(mask,w,h,path,word):
    from fontTools.fontBuilder import FontBuilder
    from fontTools.pens.ttGlyphPen import TTGlyphPen
    from tools.build_pc_outline_fonts import contours, simplify, point_in_polygon
    polys=[[list(point) for point in simplify(p,'CAPTION',ord('M'))] for p in contours(mask,w,h)]
    for i,ink in enumerate(mask):
        values=[point_in_polygon((i%w+.5,i//w+.5),p) for p in polys]
        if None not in values and (sum(values)%2==1)!=bool(ink):raise ValueError('caption contour changed source cell')
    glyphs={};pen=TTGlyphPen(None);glyphs['.notdef']=pen.glyph();pen=TTGlyphPen(None)
    for polygon in polys:
        points=[(a*1536/h,(h-b)*1536/h) for a,b in polygon];pen.moveTo(points[0])
        for point in points[1:]:pen.lineTo(point)
        pen.closePath()
    glyphs['caption']=pen.glyph();fb=FontBuilder(1536,isTTF=True);fb.setupGlyphOrder(['.notdef','caption']);fb.setupCharacterMap({65:'caption'});fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics({'.notdef':(round(w/h*1536),0),'caption':(round(w/h*1536),0)})
    fb.setupHorizontalHeader(ascent=1536,descent=0,lineGap=0);fb.setupOS2(sTypoAscender=1536,sTypoDescender=0,sTypoLineGap=0,usWinAscent=1536,usWinDescent=0)
    fb.setupNameTable({'familyName':'Abrams embedded '+word,'styleName':'Regular','uniqueFontIdentifier':'Abrams embedded '+word+' v1','fullName':'Abrams embedded '+word,'psName':'AbramsEmbedded'+word});fb.setupPost();fb.setupMaxp();fb.font['head'].created=fb.font['head'].modified=3862857600;fb.font.recalcTimestamp=False
    fb.save(path)
    return polys

def crew_captions(root):
    """Optical contour cleanup of the two original embedded Genesis captions."""
    source=Image.open(root/'artifacts/pc-information-baseline-02/crew.png').convert('RGB')
    genesis=Image.open(root/'local-art/genesis/source/crew-information-original.png').convert('RGB')
    captions=[]
    out=root/'local-art/genesis/remastered/information-completion-v1'
    for name,word,rect in [('abrams','ABRAMS',[72,64,53,5]),('m1a1','M1A1',[72,75,24,5])]:
        x,y,w,h=rect
        mask=[]
        for dy in range(h):
            for dx in range(w):
                pc=source.getpixel((x+dx,y+dy));md=genesis.getpixel((x+dx-4,y+dy+6))
                if pc not in [(0,0,0),(255,255,255)] or md!=((172,170,172) if pc==(255,255,255) else (0,0,0)):
                    raise ValueError('embedded caption source correspondence differs')
                mask.append(int(pc==(255,255,255)))
        path=out/(name+'-caption-v1.ttf')
        polys=vector_face(mask,w,h,path,word)
        captions.append({'text':word,'rect':rect,'art':'information-completion-v1/'+path.name,'art_sha256':sha(path),'mask':mask,'contours':polys,'foreground':[172,170,172],'background':[0,0,0],'glyph':'A'})
    return captions

def overhead_captions(root):
    """Genesis embedded M1A1 forms, with PC forms retained for Original text."""
    captions=[]
    for name,index,x in PLACEMENTS:
        donor=root/'local-art/genesis/source/info-v1'/('weapon-'+name+'-screen.png')
        genesis=Image.open(donor).convert('RGB')
        pixels=list(genesis.crop((139,19,165,24)).getdata())
        if set(pixels)!={(238,238,238),(65,68,238)}:raise ValueError('Genesis embedded overhead label differs')
        mask=[int(c==(238,238,238)) for c in pixels]
        pc=Image.open(root/'artifacts/pc-information-baseline-02'/(name+'.png')).convert('RGB')
        original=list(pc.crop((x+3,25,x+28,30)).getdata())
        if set(original)!={(255,255,255),(85,85,255)}:raise ValueError('PC embedded overhead label differs')
        path=root/'local-art/genesis/remastered/information-completion-v1/overhead-m1a1-caption-v1.ttf'
        polys=vector_face(mask,26,5,path,'OverheadM1A1')
        # A code-native blue label matte covers the generated bitmap letters.
        # Its donor-sampled colour keeps the source page's uncluttered caption.
        image=Image.open(root/'local-art/genesis/remastered/information-completion-v1'/(name+'-topdown-v1.png')).convert('RGB')
        background=list(image.getpixel((150,150)))
        captions.append({'page':name,'text':'M1A1','rect':[x+3,25,26,5],
            'clear_rect':[x+1,24,34,9],'original_rect':[x+3,25,25,5],
            'original_mask':[int(c==(255,255,255)) for c in original],
            'art':'information-completion-v1/'+path.name,'art_sha256':sha(path),
            'mask':mask,'contours':polys,'foreground':[238,238,238],
            'background':background,'glyph':'A','donor':str(donor.relative_to(root)),
            'donor_sha256':sha(donor),'donor_rect':[139,19,26,5]})
    if any(c['mask']!=captions[0]['mask'] for c in captions):raise ValueError('Genesis labels differ')
    return captions

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def observed_crew_frames(root):
    report_path=root/'artifacts/finish-20260928/crew-footer-native/report.json'
    report=json.loads(report_path.read_text())
    original=Image.open(root/'artifacts/pc-information-baseline-02/crew.png').convert('RGB')
    pins=[]
    for sample in report['samples']:
        image=Image.open(report_path.parent/sample['image']).convert('RGB')
        raw=image.tobytes()
        pin=hashlib.sha256(raw).hexdigest()
        if pin!=sample['rgb_sha256'] or hashlib.sha256(raw[:320*175*3]).hexdigest()!=INFORMATION_PAGES['crew']:
            raise ValueError('crew capture fingerprint differs')
        for y in range(175,200):
            for x in range(320):
                if image.getpixel((x,y))!=original.getpixel((x,y)) and not (y==175 and 10<=x<310):
                    raise ValueError('crew footer contains more than animated menu seam')
        if pin not in pins:pins.append(pin)
    return {'full_rgb_sha256':pins,'capture':str(report_path.relative_to(root)),
            'capture_sha256':sha(report_path),'difference_bounds':[10,175,300,1]}

def build(root=ROOT):
    sprites = decode_bitmaps(decode_resource((root/'GAME/INFO.BMP').read_bytes()))
    receipt = json.loads((root/'local-art/genesis/source/information-completion-v1/manifest.json').read_text())
    entries = []
    for name, index, x in PLACEMENTS:
        capture = root/'artifacts/pc-information-baseline-02'
        source = Image.open(capture/(name+'.png')).convert('RGB')
        fingerprint = hashlib.sha256(source.crop((0,0,320,175)).tobytes()).hexdigest()
        if fingerprint != INFORMATION_PAGES[name]: raise ValueError('PC page differs: '+name)
        sprite = sprites[index]
        count = 0
        for i,c in enumerate(sprite['pixels']):
            if not c: continue
            if source.getpixel((x+i%sprite['width'],22+i//sprite['width'])) != PALETTE[c]:
                raise ValueError('PC topdown sprite placement differs: '+name)
            count += 1
        donor = next(a for a in receipt['assets'] if a['name']==name)
        for field,pin in [('source','source_sha256'),('file','sha256')]:
            if sha(root/donor[field]) != donor[pin]: raise ValueError('Genesis donor differs: '+name)
        original = Image.open(root/donor['source']).convert('RGB')
        crop = Image.open(root/donor['file']).convert('RGB')
        if original.crop(donor['crop_xyxy']).tobytes()!=crop.tobytes(): raise ValueError('donor crop differs')
        art='information-completion-v1/'+name+'-topdown-v1.png'
        path=root/'local-art/genesis/remastered'/art
        with Image.open(path) as image: size=list(image.size)
        entries.append({'name':name,'rgb_sha256':fingerprint,
                        'layer':{'name':name+'-topdown','rect':[x,22,sprite['width'],sprite['height']],
                                 'art':art,'art_sha256':sha(path),'size':size,'fit':'stretch','frame_rgb':None},
                        'source_sprite':index,'source_pixels_checked':count,
                        'loaded_source_proof':verify_loaded((capture/(name+'.bin')).read_bytes(),sprite),
                        'genesis_donor':donor})
    frames=[]
    capture=root/'artifacts/pc-information-baseline-02'
    for name in ['ax','sabot','coax','cannon','smoke']:
        donor=root/'local-art/genesis/source/info-v1'/(
            ('ammo-' if name in ['ax','sabot'] else 'weapon-')+name+'-screen.png')
        image=Image.open(donor).convert('RGB')
        if any(image.getpixel((x,y))!=(0,0,0) for y in range(200) for x in range(8)):
            raise ValueError('Genesis outer background differs: '+name)
        footers=[]
        for suffix in ['', '-wait']:
            source=Image.open(capture/(name+suffix+'.png')).convert('RGB')
            pin=hashlib.sha256(source.crop((0,175,320,200)).tobytes()).hexdigest()
            if pin not in footers: footers.append(pin)
        # Remove the PC outer bevel and green outer/title box, matching the
        # Genesis black surround. Illustration layers draw above this backdrop;
        # their existing authorized rectangles remain complete.
        frames.append({'name':name,'rgb_sha256':INFORMATION_PAGES[name],
                       'rects':[[0,0,320,10],[0,10,10,165],[310,10,10,165],[10,19,300,1]],
                       'footer_rect':[0,175,320,25],'footer_sha256':footers,
                       'donor':str(donor.relative_to(root)),'donor_sha256':sha(donor),
                       'background_rgb':[0,0,0]})
    return {'schema':1,'crew_frames':observed_crew_frames(root),'entries':entries,'frames':frames,'crew_captions':crew_captions(root),'overhead_captions':overhead_captions(root),'scope':'Three overhead selection diagrams, five Genesis-derived embedded caption contours and five Genesis-black outer page surrounds. Every visible PC value remains source-owned. Footer replacement additionally requires an exact observed footer hash; unknown footer bytes remain original.'}

def main():
    output=ROOT/'local-art/pc-information-completion-v1/information.json'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(build(),indent=2)+'\n')
    print(sha(output))

if __name__=='__main__': main()
