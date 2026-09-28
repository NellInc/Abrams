#!/usr/bin/env python3
"""Audit surviving STRUT3 ownership and prepare finite presentation fixtures."""
import base64
import hashlib
import io
import json
from pathlib import Path
from PIL import Image
from tools.pc_bitmaps import decode_bitmaps
from tools.inspect_scenarios import decode_resource
from tools.build_pc_graphics_catalog import PALETTE

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/finish-20260928/cursor-struts'


def build():
    OUT.mkdir(parents=True,exist_ok=True)
    path=ROOT/'artifacts/pc-driver-assembly-trace-03/report.json';report=json.loads(path.read_text())
    sources=decode_bitmaps(decode_resource((ROOT/'GAME/STRUTS.BMP').read_bytes()));sprite=sources[3]
    plate=Image.new('RGB',(320,200));plate.putdata([PALETTE[c] for b in decode_resource((ROOT/'GAME/DRIVER.BIN').read_bytes()) for c in(b>>4,b&15)])
    rows=[]
    for sample in report['ui_presentations']:
        if sample['stage'] not in ['driver-centered','driver-turned','driver-reversed','driver-aligned']:continue
        packet=report['presentations'][sample['frame_index']]
        overlay=packet['driver_overlay'];mask=Image.open(io.BytesIO(base64.b64decode(overlay['mask_png']))).convert('RGB')
        if hashlib.sha256(mask.tobytes()).hexdigest()!=overlay['mask_sha256']:raise ValueError('driver mask changed')
        image=Image.open(path.parent/sample['image']).convert('RGB')
        ui=Image.open(path.parent/sample['mask']);tags=Image.open(path.parent/sample['plate_mask'])
        points=[];surviving=overwritten=0
        for yy in range(9):
            for xx in range(80):
                colour=sprite['pixels'][yy*80+xx]
                if not colour:continue
                point=(240+xx,128+yy)
                if ui.getpixel(point)!=255:raise ValueError('strut pixel lost UI custody')
                if mask.getpixel(point)==(0,64,255):
                    if image.getpixel(point)!=tuple(PALETTE[colour]):raise ValueError('surviving strut pixel changed')
                    surviving+=1
                elif tags.getpixel(point)==4 and image.getpixel(point)==plate.getpixel(point):
                    overwritten+=1
                else:raise ValueError('unattributed strut pixel')
                points.append(list(point))
        if (surviving,overwritten)!=(595,79):raise ValueError('source strut coverage changed')
        drawing=next(d for d in report['render_passes'] if d['sequence']==sample['draw_sequence'])
        packet=dict(packet,draw_pass={'camera':drawing['camera']})
        packet['ui_overlay']=dict(packet['ui_overlay'],mask_png=base64.b64encode((path.parent/sample['mask']).read_bytes()).decode())
        packet['plate_overlay']=dict(packet['plate_overlay'],mask_png=base64.b64encode((path.parent/sample['plate_mask']).read_bytes()).decode())
        rows.append({'name':sample['stage'],'source_path':str((path.parent/sample['image']).relative_to(ROOT)),
                     'packet':packet,'donor':4,'points':points,'surviving_strut_pixels':surviving,'later_plate_pixels':overwritten})
    # A separate original-source fixture tests the newly verified clipped AA
    # claim. It is intentionally labelled synthetic rather than a live capture.
    source=Image.new('RGB',(320,200));source.putdata([PALETTE[c] for b in decode_resource((ROOT/'GAME/AA.BIN').read_bytes()) for c in(b>>4,b&15)])
    source_path=OUT/'cupola-original.png';source.save(source_path)
    mask=Image.new('L',(320,200));tags=Image.new('L',(320,200));points=[];sprite=sources[5]
    for yy in range(7):
        for xx in range(161):
            if not sprite['pixels'][yy*168+xx]:continue
            point=(159+xx,110+yy);mask.putpixel(point,255);tags.putpixel(point,3);points.append(list(point))
    def encoded(image):
        out=io.BytesIO();image.save(out,format='PNG');return base64.b64encode(out.getvalue()).decode()
    packet={'palette_rgb':PALETTE,'draw_pass':{'camera':{'clip':[0,0,319,199]}},
            'ui_overlay':{'width':320,'height':200,'mask_png':encoded(mask)},
            'plate_overlay':{'width':320,'height':200,'mask_png':encoded(tags),'plates':{'3':{'source':'AA.BIN','source_sha256':hashlib.sha256((ROOT/'GAME/AA.BIN').read_bytes()).hexdigest(),'pixels':len(points)}}}}
    rows.append({'name':'cupola-clipped-source-fixture','source_path':str(source_path.relative_to(ROOT)),
                 'packet':packet,'donor':3,'points':points,'synthetic':True})
    result={'schema':1,'historical_capture':str(path.relative_to(ROOT)),'capture_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
            'samples':rows,'scope':__doc__}
    (OUT/'coverage-fixtures.json').write_text(json.dumps(result,indent=2)+'\n')
    print('STRUT_COVERAGE:',len(rows),'samples; driver595 surviving +79 later plate pixels; cupola',len(points),'visible source pixels')


if __name__=='__main__':build()
