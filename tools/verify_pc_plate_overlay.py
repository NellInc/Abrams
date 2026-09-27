#!/usr/bin/env python3
"""Verify every attributed plate pixel against saved original framebuffer RGB."""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image
try:
    from tools.pc_plate_trace import PlateLoads, PLATE_IDS
except ModuleNotFoundError:
    from pc_plate_trace import PlateLoads, PLATE_IDS

ROOT = Path(__file__).resolve().parents[1]


def verify(report_path):
    report = json.loads(report_path.read_text())
    sources = PlateLoads(ROOT / 'GAME').resources
    colors = {i+1:[n for b in sources[name][0] for n in (b >> 4,b & 15)] for i,name in enumerate(PLATE_IDS)}
    frames, total = [], 0
    for sample in report['ui_presentations']:
        if not sample.get('plate_mask'): raise ValueError('captured frame lacks plate attribution')
        presentation = report['presentations'][sample['frame_index']]
        metadata = presentation['plate_overlay']
        with Image.open(report_path.parent / sample['plate_mask']) as mask_image:
            if mask_image.mode != 'L' or mask_image.size != (320,200): raise ValueError('invalid plate mask PNG')
            mask = mask_image.tobytes()
        if hashlib.sha256(mask).hexdigest() != metadata['mask_sha256']: raise ValueError('mask capture differs from paired scanout')
        with Image.open(report_path.parent / sample['mask']) as ui_image:
            ui = ui_image.tobytes()
        with Image.open(report_path.parent / sample['image']) as frame:
            if frame.size != (320,200): raise ValueError('unsupported original dimensions')
            rgb = list(frame.convert('RGB').getdata())
        counts = {name:0 for name in PLATE_IDS}
        for at, plate in enumerate(mask):
            if not plate: continue
            if plate not in colors or ui[at] != 255: raise ValueError('plate claims unobserved or world pixel')
            name = PLATE_IDS[plate-1]
            if metadata['plates'][str(plate)]['source_sha256'] != sources[name][1]:
                raise ValueError('plate source fingerprint differs')
            expected = tuple(presentation['palette_rgb'][colors[plate][at]])
            if rgb[at] != expected:
                raise ValueError(f'{sample["stage"]}: {name} at {at%320},{at//320}: {rgb[at]} != {expected}')
            counts[name] += 1
        for i,name in enumerate(PLATE_IDS):
            if counts[name] != metadata['plates'][str(i+1)]['pixels']: raise ValueError('plate pixel count differs')
        checked = sum(counts.values())
        frames.append({'stage':sample['stage'],'pixels':checked,'plates':counts})
        total += checked
    if total == 0: raise ValueError('no replaceable plate pixels were verified')
    return {'capture':str(report_path),'frames':frames,'pixels_checked':total,
            'scope':'all attributed pixels in captured samples equal original source plate at same coordinate; no completeness claim'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    result = verify(args.report)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'frames':len(result['frames']),'pixels_checked':result['pixels_checked']}))
