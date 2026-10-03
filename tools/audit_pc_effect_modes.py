#!/usr/bin/env python3
"""Inventory effect-relevant display modes from existing immutable PC captures."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image
try:
    from tools.unpack_pc_executables import unpack
    from tools.pc_live_state import SIM_SHA256
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from unpack_pc_executables import unpack
    from pc_live_state import SIM_SHA256

ROOT = Path(__file__).resolve().parents[1]
CAPTURES = [('artifacts/finish-20260928/target-live-trace-02/report.json', ['selected', 'thermal', 'thermal-off']),
            ('artifacts/pc-cockpit-trace-05/report.json', ['damage-settled'])]


def audit(root=ROOT):
    original = (root / 'GAME/SIM.EXE').read_bytes()
    if hashlib.sha256(original).hexdigest() != SIM_SHA256:
        raise ValueError('changed original executable')
    decoded, _ = unpack(original)
    regions = [(0xb4d, 0x28d0, 0x28e4), (0xb4d, 0x437c, 0x4401), (0, 0x8b08, 0x8b56)]
    code = [{'segment': seg, 'start': start, 'end': end,
             'sha256': hashlib.sha256(decoded[seg * 16 + start:seg * 16 + end]).hexdigest()}
            for seg, start, end in regions]
    rows = []
    for relative, stages in CAPTURES:
        path = root / relative
        raw = path.read_bytes()
        data = json.loads(raw)
        passes = {p['sequence']: p for p in data['render_passes']}
        for stage in stages:
            entry = next(p for p in data['ui_presentations'] if p['stage'] == stage)
            packet = data['presentations'][entry['frame_index']]
            drawing = passes[entry['draw_sequence']]
            if packet['palette_rgb'] != drawing['palette_rgb']:
                raise ValueError('display and drawing palette disagree')
            mask_path = path.parent / entry['mask']
            with Image.open(mask_path) as mask:
                values = list(mask.convert('L').getdata())
                if set(values) - {0, 255}:
                    raise ValueError('nonbinary source ownership mask')
                owned = sum(v == 255 for v in values)
            if owned != packet['ui_overlay']['ui_pixels']:
                raise ValueError('source ownership count differs')
            rows.append({'stage': stage, 'report': relative,
                         'report_sha256': hashlib.sha256(raw).hexdigest(),
                         'frame_index': entry['frame_index'], 'draw_sequence': entry['draw_sequence'],
                         'palette_rgb': packet['palette_rgb'], 'camera': drawing['camera'],
                         'materials': drawing['materials'], 'background': drawing['background'],
                         'reticle_color': packet.get('reticle', {}).get('color'),
                         'ui_owned_pixels': owned, 'image': str((path.parent / entry['image']).relative_to(root)),
                         'mask': str(mask_path.relative_to(root)),
                         'image_sha256': hashlib.sha256((path.parent / entry['image']).read_bytes()).hexdigest(),
                         'mask_sha256': hashlib.sha256(mask_path.read_bytes()).hexdigest(),
                         'status_plate_pixels': packet.get('plate_overlay', {}).get('plates', {}).get('5', {}).get('pixels', 0),
                         'effect_sprite_indices': [o['bitmap_index'] for o in drawing['objects'] if o.get('kind') == 'sprite']})
    if len({json.dumps(r['palette_rgb']) for r in rows}) != 1:
        raise ValueError('new palette needs source analysis before admission')
    if rows[1]['reticle_color'] != 1 or rows[2]['reticle_color'] != 0:
        raise ValueError('thermal transition not established')
    if rows[1]['background']['colors'] != [0, 3] or rows[2]['background']['colors'] != [5, 8]:
        raise ValueError('expected original thermal background transition absent')
    if rows[3]['ui_owned_pixels'] != 64000 or rows[3]['status_plate_pixels'] == 0:
        raise ValueError('damage label is not an actual STATUS overlay')
    return {'source_sha256': SIM_SHA256, 'source_regions': code, 'modes': rows,
            'unique_palettes': 1,
            'conclusion': 'These observed thermal and STATUS modes keep the normal RGB palette. Thermal changes original draw indices; STATUS owns all screen pixels. No guessed effect recoloring is supported.',
            'scope': 'Recorded mode contexts and source drawing path. No live effect occurrence in these four selected mode frames.'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    result = audit()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('EFFECT_MODES: 4 source contexts, 1 exact palette; thermal background changes, STATUS owns 64000 pixels')


if __name__ == '__main__':
    main()
