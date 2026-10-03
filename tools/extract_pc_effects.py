#!/usr/bin/env python3
"""Extract original PC effect samples with the observed palette and native mask.

Outputs remain local reference art, with no redistribution permission implied.
"""
import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw
try:
    from tools.pc_bitmaps import decode_bitmaps, verify_loaded_effects
    from tools.pc_live_state import SimStateReader
    from tools.inspect_scenarios import decode_resource
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_bitmaps import decode_bitmaps, verify_loaded_effects
    from pc_live_state import SimStateReader
    from inspect_scenarios import decode_resource
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--trace', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    if inside_source(args.output, ROOT, ('GAME',)): p.error('output must be outside GAME')
    ram = args.capture.read_bytes()
    trace = json.loads(args.trace.read_text())
    first = trace['render_passes'][0]
    if first['start_ram_sha256'] != hashlib.sha256(ram).hexdigest(): p.error('RAM and palette capture do not match')
    palette = first['palette_rgb']
    if len(palette) != 16 or any(len(c) != 3 or any(not 0 <= v <= 255 for v in c) for c in palette):
        p.error('unsupported captured palette')
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: p.error('original SIM missing')
    raw = (ROOT / 'GAME/EFFECTS.BMP').read_bytes()
    images = verify_loaded_effects(ram, (state['load_segment'] + 0x19E0) * 16, decode_bitmaps(decode_resource(raw)))
    args.output.mkdir(parents=True, exist_ok=False)
    sheet = Image.new('RGB', (8 * 256, 8 * 216), '#293338')
    draw = ImageDraw.Draw(sheet)
    for sprite in images:
        im = Image.new('RGBA', (sprite['width'], sprite['height']))
        im.putdata([tuple(palette[color]) + (255 if opaque else 0,)
                    for color, opaque in zip(sprite['pixels'], sprite['opaque'])])
        name = f'effect-{sprite["index"]:02d}.png'
        im.save(args.output / name)
        sprite['image'] = name
        x, y = sprite['index'] % 8 * 256, sprite['index'] // 8 * 216
        draw.text((x + 12, y + 10), f'{sprite["index"]:02d}   {im.width} x {im.height}', fill='white')
        enlarged = im.resize((im.width * 4, im.height * 4), Image.Resampling.NEAREST)
        sheet.paste(enlarged, (x + 12, y + 28), enlarged)
    sheet.save(args.output / 'contact-sheet.png')
    result = {'source': 'GAME/EFFECTS.BMP', 'source_sha256': hashlib.sha256(raw).hexdigest(),
        'capture_sha256': hashlib.sha256(ram).hexdigest(), 'palette_rgb': palette, 'images': images,
        'scope': 'all source pixels and masks match original loaded EGA memory; native samples, not screenshots; local reference only'}
    (args.output / 'effects.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'Extracted {len(images)} verified original PC effects into {args.output}')


if __name__ == '__main__': main()
