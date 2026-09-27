#!/usr/bin/env python3
"""Extract PC portrait verification samples; Genesis remains the visual donor.

Every decoded pixel and preservation-mask bit must occur in the original loaded
EGA data. No original memory is written. Outputs contain proprietary samples and
belong in the ignored local-art directory, never the source distribution.
"""
import argparse
import hashlib
import json
from pathlib import Path

try:
    from tools.inspect_scenarios import decode_resource
    from tools.pc_bitmaps import decode_bitmaps
except ModuleNotFoundError:
    from inspect_scenarios import decode_resource
    from pc_bitmaps import decode_bitmaps

ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHA256 = 'e769b71bee8a40023e6ffdb3ac0fd5db0a7485148c1d2eb3fd4fe3b1da6ffa42'


def planar_sample(item):
    width, height = item['width'], item['height']
    if width % 8 or len(item['pixels']) != width * height:
        raise ValueError('unsupported portrait dimensions')
    size = width // 8 * height
    planes, mask = bytearray(size * 4), bytearray(size)
    for index, colour in enumerate(item['pixels']):
        byte, bit = index // 8, 128 >> (index % 8)
        for plane in range(4):
            if colour & (1 << plane): planes[plane * size + byte] |= bit
        if colour == 0: mask[byte] |= bit
    return bytes(planes), bytes(mask)


def verify_loaded(ram, item):
    planes, mask = planar_sample(item)
    at = ram.find(planes)
    if at < 0 or ram.find(planes, at + 1) >= 0:
        raise ValueError('portrait planes missing or ambiguous in original memory')
    if ram[at + len(planes):at + len(planes) + len(mask)] != mask:
        raise ValueError('original portrait preservation mask differs')
    return {'index': item['index'], 'physical_offset': at,
            'pixels_checked': item['width'] * item['height'], 'mask_bits_checked': len(mask) * 8}


def catalog(source, palette):
    if hashlib.sha256(source).hexdigest() != SOURCE_SHA256:
        raise ValueError('unsupported original FACES.BMP fingerprint')
    if (len(palette) != 16 or any(len(c) != 3 or any(type(v) is not int or not 0 <= v <= 255 for v in c) for c in palette)):
        raise ValueError('unsupported palette')
    images = decode_bitmaps(decode_resource(source))
    if [(s['width'], s['height']) for s in images] != [(56, 47), (56, 48), (56, 48), (56, 48)]:
        raise ValueError('unsupported original portrait set')
    return {'schema': 1, 'source': 'FACES.BMP', 'source_sha256': SOURCE_SHA256,
            'palette_rgb': palette, 'images': images}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--trace', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT / n).resolve()) for n in ('GAME', 'GENESIS')):
        parser.error('output must be outside original sources')
    ram = args.capture.read_bytes()
    trace = json.loads(args.trace.read_text())['render_passes'][0]
    if hashlib.sha256(ram).hexdigest() != trace['start_ram_sha256']:
        parser.error('RAM and observed palette trace differ')
    data = catalog((ROOT / 'GAME/FACES.BMP').read_bytes(), trace['palette_rgb'])
    proof = [verify_loaded(ram, item) for item in data['images']]
    args.output.mkdir(parents=True, exist_ok=False)
    payload = (json.dumps(data, indent=2) + '\n').encode()
    (args.output / 'faces.json').write_bytes(payload)
    receipt = {'catalog_sha256': hashlib.sha256(payload).hexdigest(),
               'capture': str(args.capture), 'ram_sha256': hashlib.sha256(ram).hexdigest(),
               'trace': str(args.trace), 'portraits': proof,
               'scope': 'PC source matching and original loaded pixel/mask proof only; no Genesis identity or live rendering claim'}
    (args.output / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))


if __name__ == '__main__': main()
