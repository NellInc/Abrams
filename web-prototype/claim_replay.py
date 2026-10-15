#!/usr/bin/env python3
"""Check native Web claim receipts against the unchanged desktop observer."""
import base64
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.pc_strut_trace import StrutDraws
from tools.pc_plate_trace import PlateLoads
from tools.pc_trace_windows import build_window_bundles, event_ram


def check(frames, window_bundles=None):
    if window_bundles is None:
        # The packet format the generated Web core under test declares.
        window_bundles = build_window_bundles(
            json.loads((ROOT / 'web-prototype/.generated/build-info.json').read_text()))
    plates = PlateLoads(ROOT / 'GAME')
    struts = StrutDraws(ROOT / 'GAME', plates)
    matched = 0
    for frame in frames:
        receipt = base64.b64decode(frame['receipts'], validate=True)
        remaining = []
        at = 0
        while at < len(receipt):
            if at + 8 > len(receipt):
                raise ValueError('truncated native receipt header')
            page, plate = struct.unpack_from('<II', receipt, at)
            at += 8
            mask = b''
            if plate:
                if at + 8000 > len(receipt):
                    raise ValueError('truncated native strut receipt')
                mask = receipt[at:at + 8000]
                at += 8000
            remaining.append((page, plate, mask))

        def claim(actual):
            nonlocal matched
            native = remaining.pop(0) if remaining else None
            if native != actual:
                if native and native[:2] == actual[:2]:
                    different = next((at for at, (a, b) in enumerate(zip(native[2], actual[2]))
                                      if a != b), None)
                    raise ValueError(f'native strut mask differs from desktop at byte {different}: '
                                     f'native={native[2][different] if different is not None else None} '
                                     f'desktop={actual[2][different] if different is not None else None}')
                raise ValueError(f'native strut identity differs from desktop: '
                                 f'native={native[:2] if native else None} desktop={actual[:2]}')
            matched += 1
        packet = base64.b64decode(frame['packet'], validate=True)
        cursor = 0
        while cursor < len(packet):
            if len(packet) - cursor < 36:
                raise ValueError('truncated claim event header')
            event, offset, length = struct.unpack_from('<III', packet, cursor)
            registers = struct.unpack_from('<12H', packet, cursor + 12)
            cursor += 36
            if length > len(packet) - cursor:
                raise ValueError('truncated claim event data')
            raw = packet[cursor:cursor + length]
            cursor += length
            if event == 29:
                names = ('ax', 'bx', 'cx', 'dx', 'si', 'di', 'bp', 'sp', 'cs', 'ds', 'es', 'ss')
                struts.begin(event_ram(raw, window_bundles), dict(zip(names, registers)), offset)
            elif event == 30:
                result = struts.finish(raw, offset)
                if result: claim((offset, result[0], result[1]))
            elif event == 32:
                if plates.verify_motor_pool(raw, offset): claim((offset, 0, b''))
            else:
                raise ValueError('unsupported claim event')
        if remaining:
            raise ValueError('native claim lacks desktop source proof')
    return {'claims': matched, 'frames': len(frames)}


if __name__ == '__main__':
    print(json.dumps(check(json.load(sys.stdin))))
