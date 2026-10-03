#!/usr/bin/env python3
"""Source-proven effect bindings and alpha visibility inventory, without emulation."""
import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

try:
    from tools.extract_genesis_effects import ROM_HASH, decode_effects
    from tools.inspect_scenarios import decode_resource
    from tools.inspect_shapes import inspect_shapes
    from tools.pc_bitmaps import decode_bitmaps
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from extract_genesis_effects import ROM_HASH, decode_effects
    from inspect_scenarios import decode_resource
    from inspect_shapes import inspect_shapes
    from pc_bitmaps import decode_bitmaps

ROOT = Path(__file__).resolve().parents[1]
BASES = [15, 16, 17, *range(15), 62, 63]


def source_bindings(shape_data):
    """Decode the original selector target and bitmap command, never infer by art."""
    result = {}
    for shape in inspect_shapes(shape_data)['shapes']:
        if shape['vector_count']:
            continue
        commands = {item['offset']: bytes.fromhex(item['hex']) for item in shape['opaque_commands']}
        for selector in shape['selectors']:
            command = commands[selector['target']]
            if len(command) != 2 or command[0] != 0x80 or command[1] in result:
                raise ValueError('unsupported or repeated effect binding')
            result[command[1]] = {'shape': shape['index'], 'root': selector['target'], 'selector': selector['word']}
    if set(result) != set(range(64)):
        raise ValueError('effect bindings do not cover exactly 64 originals')
    return result


def inventory(root=ROOT):
    rom = (root / 'GENESIS/M-1 Abrams Battle Tank (USA, Europe).md').read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_HASH:
        raise ValueError('unrecognized Genesis source')
    source = decode_effects(rom)
    pc = decode_bitmaps(decode_resource((root / 'GAME/EFFECTS.BMP').read_bytes()))
    shape_data = decode_resource((root / 'GAME/SHAPE.TBL').read_bytes())
    bindings = source_bindings(shape_data)
    assets = json.loads((root / 'local-art/genesis/remastered/effects-v2/manifest.json').read_text())
    donors = {entry['source_index']: entry for entry in assets['assets']}
    rows = []
    for index, (native, original) in enumerate(zip(source, pc)):
        for field in ('width', 'height', 'pixels'):
            if native[field] != original[field]:
                raise ValueError(f'PC/Genesis disagreement {index} {field}')
        if native['opaque'] != [c != 0 for c in original['pixels']]:
            raise ValueError('preservation mask differs')
        base = index % 18 if index < 54 else 62 + index % 2
        asset = donors[base]
        path = root / 'local-art/genesis/remastered' / asset['file']
        if hashlib.sha256(path.read_bytes()).hexdigest() != asset['sha256']:
            raise ValueError('authored donor changed')
        def opaque_bounds(sprite):
            points = [(n % sprite['width'], n // sprite['width']) for n, v in enumerate(sprite['opaque']) if v]
            return (min(x for x, y in points), min(y for x, y in points),
                    max(x for x, y in points) + 1, max(y for x, y in points) + 1)
        target = opaque_bounds(native)
        origin = opaque_bounds(source[base])
        with Image.open(path) as image:
            alpha = image.convert('RGBA').resize((512, 512), Image.Resampling.LANCZOS).getchannel('A')
            candidate = []
            # GPU bilinear sampling has a two-texel footprint even when shrinking.
            # PIL.resize-to-native uses an area reduction and is not that sampler.
            for y in range(native['height']):
                for x in range(native['width']):
                    if not target[0] <= x < target[2] or not target[1] <= y < target[3]:
                        candidate.append(False)
                        continue
                    u = (origin[0] + (x + 0.5 - target[0]) / (target[2] - target[0]) * (origin[2] - origin[0])) / source[base]['width']
                    v = (origin[1] + (y + 0.5 - target[1]) / (target[3] - target[1]) * (origin[3] - origin[1])) / source[base]['height']
                    if BASES.index(base) >= 3:
                        box = asset['cutout_bbox']
                        w, h = asset['size']
                        u = (box[0] + (x + 0.5 - target[0]) / (target[2] - target[0]) * (box[2] - box[0])) / w
                        v = (box[1] + (y + 0.5 - target[1]) / (target[3] - target[1]) * (box[3] - box[1])) / h
                    px, py = u * 512 - 0.5, v * 512 - 0.5
                    ix, iy = math.floor(px), math.floor(py)
                    fx, fy = px - ix, py - iy
                    def a(dx, dy):
                        return alpha.getpixel((min(511, max(0, ix + dx)), min(511, max(0, iy + dy))))
                    value = (a(0, 0) * (1 - fx) + a(1, 0) * fx) * (1 - fy) + (a(0, 1) * (1 - fx) + a(1, 1) * fx) * fy
                    candidate.append(value >= 127.5)
        mask = native['opaque']
        union = sum(a or b for a, b in zip(mask, candidate))
        rows.append({'index': index, **bindings[index], 'donor': BASES.index(base), 'base_index': base,
                     'dimensions': [native['width'], native['height']],
                     'source_opaque': sum(mask), 'source_colors': sorted({p for p, a in zip(native['pixels'], mask) if a}),
                     'candidate_opaque_native_scale': sum(candidate),
                     'native_mask_iou': sum(a and b for a, b in zip(mask, candidate)) / union,
                     'authored_asset': asset['file'],
                     'palette_gate': 'exact captured PC palette shared by normal/thermal/STATUS; unknown RGB palettes retain original',
                     'live_sequence_evidence': index in (51, 52, 53)})
    return {'schema': 1, 'rom_sha256': ROM_HASH, 'shape_decoded_sha256': hashlib.sha256(shape_data).hexdigest(),
            'count': len(rows), 'authored_donors': len(donors), 'images': rows,
            'scope': 'Source bindings and alpha differences; no claim of human tactical acceptance or all-family live timing.'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    result = inventory()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(f"EFFECT_INVENTORY: {result['count']} source bindings, {result['authored_donors']} authored donors")


if __name__ == '__main__':
    main()
