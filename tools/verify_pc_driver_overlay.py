#!/usr/bin/env python3
"""Bounded original replay/code/UI-custody proof for the driver material layer."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import struct
from PIL import Image
try:
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.unpack_pc_executables import unpack
except ModuleNotFoundError:
    from pc_live_state import SimStateReader, SIM_SHA256
    from unpack_pc_executables import unpack

ROOT = Path(__file__).resolve().parents[1]


def verify(trace_path, baseline_path):
    trace = json.loads(trace_path.read_text())
    baseline = json.loads(baseline_path.read_text())
    checks = {key: trace[key] == baseline[key]
              for key in ('frames', 'stages', 'state_sha256', 'state_core_sha256')}
    if not all(checks.values()): raise ValueError('original replay differs: ' + str(checks))
    ram = (trace_path.parent / 'first-render.bin').read_bytes()
    load = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)['load_segment']
    decoded, metadata = unpack((ROOT / 'GAME/SIM.EXE').read_bytes())
    expected = bytearray(decoded)
    relocations = []
    for relocation in metadata['relocations']:
        at = relocation['load_offset']
        if 0x5B98 <= at < 0x5DA7:
            relocations.append(at)
            struct.pack_into('<H', expected, at, (struct.unpack_from('<H', expected, at)[0] + load) & 65535)
    code = ram[load*16+0x5B98:load*16+0x5DA7]
    if code != expected[0x5B98:0x5DA7]: raise ValueError('loaded driver routine differs from original executable')
    samples, total, offsets = [], 0, set()
    for sample in trace['ui_presentations']:
        overlay = trace['presentations'][sample['frame_index']].get('driver_overlay')
        counts = {}
        if overlay:
            if overlay['source'] != 'SIM.EXE:5ba1..5da3' or overlay['source_sha256'] != SIM_SHA256:
                raise ValueError('unverified assembly source')
            with Image.open(io.BytesIO(base64.b64decode(overlay['mask_png']))) as im:
                if im.mode != 'RGB' or im.size != (320,200): raise ValueError('unsupported driver mask')
                raw = im.tobytes()
            if hashlib.sha256(raw).hexdigest() != overlay['mask_sha256']: raise ValueError('driver mask hash differs')
            with Image.open(trace_path.parent / sample['mask']) as im:
                ui = im.tobytes()
            for at in range(64000):
                low, high, owned = raw[at*3:at*3+3]
                if owned == 0:
                    if low or high: raise ValueError('unclaimed driver pixel has offset')
                    continue
                if owned != 255 or high > 127 or ui[at] != 255: raise ValueError('invalid driver/UI ownership')
                offset = low + 256*high - 16384
                x, y = at % 320, at // 320
                # Disassembled roof bitmap/polygons and the two lower struts.
                if not (y < 77 or (128 <= y < 137 and (x < 80 or x >= 240) and offset == 0)):
                    raise ValueError('driver mask escaped original assembly drawing bounds')
                counts[offset] = counts.get(offset, 0) + 1
                offsets.add(offset)
            total += sum(counts.values())
        samples.append({'stage':sample['stage'], 'offset_pixels':counts})
    if not (0 in offsets and min(offsets) < 0 < max(offsets)):
        raise ValueError('route lacks centred and both-direction original assembly samples')
    return {'trace':str(trace_path), 'baseline':str(baseline_path), 'checks':checks,
            'frames':len(trace['frames']), 'stages':len(trace['stages']), 'core_sha256':trace['core_sha256'],
            'original_routine_bytes':len(code), 'loaded_code_sha256':hashlib.sha256(code).hexdigest(),
            'relocation_offsets':relocations, 'assembly_pixels_checked':total,
            'offsets':sorted(offsets), 'samples':samples,
            'scope':'bounded replay, original relocated routine and captured assembly/UI custody; full turret travel and finished art remain open'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--trace', type=Path, required=True)
    parser.add_argument('--baseline', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = verify(args.trace, args.baseline)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'samples'}, indent=2))
