#!/usr/bin/env python3
"""Extract local PC cockpit plates and verified native strut bitmaps.

The seven full-screen plates have structural decode evidence. STRUTS pixels
and masks are checked against the original loaded EGA descriptors. No gameplay
screenshots are used as the asset source, and nothing is made distributable.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
from PIL import Image, ImageDraw
try:
    from tools.inspect_scenarios import decode_resource
    from tools.pc_bitmaps import decode_bitmaps, read_ega_bitmap
    from tools.pc_live_state import SimStateReader
except ModuleNotFoundError:
    from inspect_scenarios import decode_resource
    from pc_bitmaps import decode_bitmaps, read_ega_bitmap
    from pc_live_state import SimStateReader

ROOT = Path(__file__).resolve().parents[1]
PLATES = ('FRAME', 'DRIVER.BIN', 'AA.BIN', 'TC.BIN', 'GPS.BIN', 'STATUS.BIN', 'IDENTIFY')


def screen_pixels(data):
    if len(data) != 32000: raise ValueError('unsupported packed 320x200 plate length')
    return [color for value in data for color in (value >> 4, value & 15)]


def loaded_struts(ram, ds, sources):
    table, = struct.unpack_from('<H', ram, ds + 0x798E)
    if not table: raise ValueError('original cockpit struts are not loaded')
    images = []
    for source in sources:
        descriptor, = struct.unpack_from('<H', ram, ds + table + source['index'] * 2)
        loaded = read_ega_bitmap(ram, ds, descriptor)
        if any(loaded[k] != source[k] for k in ('width', 'height', 'pixels')):
            raise ValueError('source strut differs from original loaded bitmap')
        if loaded['opaque'] != [v != 0 for v in source['pixels']]:
            raise ValueError('source strut preservation mask differs')
        images.append(loaded | {'index': source['index'], 'descriptor': descriptor})
    return images


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--trace', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to((ROOT / 'GAME').resolve()): parser.error('output must be outside GAME')
    ram = args.capture.read_bytes()
    ram_hash = hashlib.sha256(ram).hexdigest()
    trace = json.loads(args.trace.read_text())
    first = trace['render_passes'][0]
    if first['start_ram_sha256'] != ram_hash: parser.error('RAM and palette trace differ')
    palette = first['palette_rgb']
    if len(palette) != 16 or any(len(rgb) != 3 or any(not 0 <= v <= 255 for v in rgb) for rgb in palette):
        parser.error('unsupported observed palette')
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: parser.error('original SIM unavailable')
    raw_struts = (ROOT / 'GAME/STRUTS.BMP').read_bytes()
    struts = loaded_struts(ram, (state['load_segment'] + 0x19E0) * 16, decode_bitmaps(decode_resource(raw_struts)))
    args.output.mkdir(parents=True, exist_ok=False)
    entries = []
    sheet = Image.new('RGB', (960,675), '#141b1d')
    draw = ImageDraw.Draw(sheet)
    for index, name in enumerate(PLATES):
        raw = (ROOT / 'GAME' / name).read_bytes()
        decoded = decode_resource(raw)
        image = Image.new('RGB', (320,200))
        image.putdata([tuple(palette[c]) for c in screen_pixels(decoded)])
        filename = name.lower().replace('.', '-') + '.png'
        image.save(args.output / filename)
        x, y = index % 3 * 320, index // 3 * 225
        draw.text((x+5,y+5), name, fill='white')
        sheet.paste(image, (x,y+20))
        entries.append({'source': 'GAME/' + name, 'image': filename,
            'source_sha256': hashlib.sha256(raw).hexdigest(), 'decoded_sha256': hashlib.sha256(decoded).hexdigest(),
            'width': 320, 'height': 200, 'encoding': 'high-nibble-first indexed pixels',
            'validation': 'structural decode; full original-loader parity not yet established'})
    sheet.save(args.output / 'panel-contact.png')
    for sprite in struts:
        image = Image.new('RGBA', (sprite['width'],sprite['height']))
        image.putdata([tuple(palette[c]) + (255 if opaque else 0,)
                       for c, opaque in zip(sprite['pixels'],sprite['opaque'])])
        filename = f'strut-{sprite["index"]:02d}.png'
        image.save(args.output / filename)
        entries.append({'source': 'GAME/STRUTS.BMP', 'source_sha256': hashlib.sha256(raw_struts).hexdigest(),
            'image': filename, 'width': sprite['width'], 'height': sprite['height'], 'index': sprite['index'],
            'descriptor': sprite['descriptor'], 'validation': 'every pixel and preservation-mask bit matches loaded original EGA memory'})
    for entry in entries: entry['image_sha256'] = hashlib.sha256((args.output/entry['image']).read_bytes()).hexdigest()
    receipt = {'palette_rgb': palette, 'trace': str(args.trace), 'ram_sha256': ram_hash,
        'strut_pixels_verified': sum(s['width'] * s['height'] for s in struts), 'assets': entries,
        'scope': 'native source extracts; no remastered-art, runtime replacement or redistribution claim'}
    (args.output/'manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(f'Extracted {len(entries)} UI assets; {receipt["strut_pixels_verified"]} strut pixels and masks match original memory')


if __name__ == '__main__': main()
