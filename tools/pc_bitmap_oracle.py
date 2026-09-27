#!/usr/bin/env python3
"""Execute original EGA bitmap blits with a bounded VGA memory/port observer.

No guest instruction substitutions. Hardware observation supports the planar
mode-0/mode-2 operations used here; it is not a complete VGA emulator.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_DS,
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.pc_bitmaps import decode_bitmaps, verify_loaded_effects
    from tools.inspect_scenarios import decode_resource
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from pc_bitmaps import decode_bitmaps, verify_loaded_effects
    from inspect_scenarios import decode_resource

ROOT = Path(__file__).resolve().parents[1]


def verify(ram):
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('original SIM missing')
    ds = state['load_segment'] + 0x19E0
    images = decode_bitmaps(decode_resource((ROOT / 'GAME/EFFECTS.BMP').read_bytes()))
    loaded = verify_loaded_effects(ram, ds * 16, images)
    ip, cs = struct.unpack_from('<HH', ram, ds * 16 + 0x35BC)
    if cs * 16 + ip != (state['load_segment'] + 0xF8D) * 16 + 0x4512:
        raise ValueError('unsupported original bitmap driver')
    m = cpu()
    m.mem_write(0, ram)
    planes = [bytearray(8000) for _ in range(4)]
    latch = [0] * 4
    graphics, sequencer = {}, {}

    def out(_m, port, size, value, _user):
        if size != 2 or port not in (0x3CE, 0x3C4):
            raise ValueError(f'unsupported VGA port {port:x}/{size}/{value:x}')
        index, value = value & 255, value >> 8
        if port == 0x3CE:
            if index not in (0, 1, 3, 4, 5, 8): raise ValueError(f'unsupported graphics register {index}')
            graphics[index] = value
        else:
            if index != 2: raise ValueError(f'unsupported sequencer register {index}')
            sequencer[index] = value

    def read(_m, _access, address, size, _value, _user):
        if not 0xA0000 <= address < 0xA1F40: return
        if address + size > 0xA1F40 or size != 1: raise ValueError('unsupported bitmap VGA read')
        raw = []
        for i in range(size):
            for p in range(4): latch[p] = planes[p][address + i - 0xA0000]
            raw.append(latch[graphics[4]])
        m.mem_write(address, bytes(raw))

    def write(_m, _access, address, size, value, _user):
        if not 0xA0000 <= address < 0xA1F40: return
        if address + size > 0xA1F40 or size != 1: raise ValueError('unsupported bitmap VGA write')
        if graphics[3] != 0 or graphics[1] != 0 or graphics[5] not in (0, 2):
            raise ValueError(f'unsupported write pipeline {graphics}')
        mask = graphics[8]
        for p in range(4):
            if not sequencer[2] & (1 << p): continue
            color = (255 if value & (1 << p) else 0) if graphics[5] == 2 else value
            planes[p][address - 0xA0000] = (color & mask) | (latch[p] & (255 ^ mask))

    m.hook_add(UC_HOOK_INSN, out, None, 1, 0, UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ, read)
    m.hook_add(UC_HOOK_MEM_WRITE, write)
    cases = 0
    positions = [(128, 50), (129, 51), (28, 10), (280, 100), (100, 8), (128, 105), (-80, 40), (300, 40)]
    for sprite in loaded:
        for x, y in positions:
            graphics.update({0: 0, 1: 0, 3: 0, 4: 0, 5: 2, 8: 255})
            sequencer[2] = 15
            latch[:] = [0] * 4
            for p in range(4): planes[p][:] = bytes([255 if 5 & (1 << p) else 0]) * 8000
            m.mem_write(ds * 16 + 0x3593, struct.pack('<4H', 32, 287, 13, 109))
            m.mem_write(ds * 16 + 0x359B, b'\x01')
            m.mem_write(ds * 16 + 0x35A8, struct.pack('<H', 0xA000))
            m.mem_write(ds * 16 + 0xF000, struct.pack('<HHHhh', 0xFF00, cs, sprite['descriptor'], x, y))
            set_registers(m, ((UC_X86_REG_CS, cs), (UC_X86_REG_DS, ds), (UC_X86_REG_ES, ds),
                (UC_X86_REG_SS, ds), (UC_X86_REG_SP, 0xF000), (UC_X86_REG_EFLAGS, 2)))
            try:
                # Observe through the complete blit and stack epilogue, stopping
                # before RETF. Unicorn re-executed that far return in the first
                # harness; return-transfer correctness is outside this oracle.
                run_until(m, cs * 16 + ip, cs * 16 + 0x1862, 200_000)
                if m.reg_read(UC_X86_REG_SP) != 0xF000 or m.reg_read(UC_X86_REG_SS) != ds:
                    raise ValueError('bitmap epilogue did not restore the stack')
            except Exception as error:
                raise ValueError(f'bitmap {sprite["index"]}, position {x,y}, '
                    f'CPU {m.reg_read(UC_X86_REG_CS):04x}:{m.reg_read(UC_X86_REG_IP):04x}') from error
            expected = bytearray([5]) * 64000
            for sy in range(sprite['height']):
                for sx in range(sprite['width']):
                    at = sy * sprite['width'] + sx
                    if sprite['opaque'][at] and 32 <= x + sx <= 287 and 13 <= y + sy <= 109:
                        expected[(y + sy) * 320 + x + sx] = sprite['pixels'][at]
            errors = []
            for at in range(64000):
                bit = 128 >> (at & 7)
                actual = sum(1 << p for p in range(4) if planes[p][at // 8] & bit)
                if actual != expected[at]:
                    errors.append([at % 320, at // 320, actual, expected[at]])
                    if len(errors) == 10: break
            if errors: raise ValueError(f'sprite {sprite["index"]}, position {x,y}: {errors}')
            cases += 1
    return {'images': len(loaded), 'loaded_pixels_and_masks': sum(p['width'] * p['height'] for p in loaded),
            'blit_cases': cases, 'framebuffer_pixels_checked': cases * 64000}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    raw = args.capture.read_bytes()
    result = verify(raw) | {'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(raw).hexdigest(),
        'scope': 'original bitmap instructions and loaded pixels/masks; bounded mode-0/mode-2 VGA observer'}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
