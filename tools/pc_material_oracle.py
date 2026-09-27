#!/usr/bin/env python3
"""Run original EGA span instructions in isolated RAM with a mode-2 write observer.

No instructions are patched. The VGA observation models bit-mask writes for the
span's selected mode only. This is independent colour/coverage evidence for those
routines, not an emulator or whole-game raster/timing equivalence claim.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct

from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS,
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_AX, UC_X86_REG_BX,
    UC_X86_REG_CX, UC_X86_REG_DX, UC_X86_REG_DI, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.pc_materials import read_materials, material_pixel
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from pc_materials import read_materials, material_pixel

ROOT = Path(__file__).resolve().parents[1]


def verify(ram):
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('original SIM missing')
    load = state['load_segment']
    ds, cs = load + 0x19E0, load + 0xF8D
    m = cpu()
    m.mem_write(0, ram)
    mask, observed = [255], [15] * 320

    def out(_m, port, size, value, _user):
        if port != 0x3CE or size != 2 or value & 255 != 8:
            raise ValueError(f'unsupported port operation: {port:x}/{size}/{value:x}')
        mask[0] = value >> 8

    def write(_m, _access, address, size, value, _user):
        if address < 0xA0000 or address >= 0xA0028: return
        if address + size > 0xA0028: raise ValueError('span exceeded test row')
        for i in range(size):
            color = (value >> (i * 8)) & 15
            base = (address + i - 0xA0000) * 8
            for bit in range(8):
                if mask[0] & (128 >> bit): observed[base + bit] = color

    m.hook_add(UC_HOOK_INSN, out, None, 1, 0, UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_WRITE, write)
    cases = pixels = 0
    materials = read_materials(ram, ds * 16)
    for material, words in enumerate(materials):
        first, second = words
        for y in (0, 1):
            for x in range(16):
                for width in (0, 1, 2, 7, 8, 9, 15, 16, 31, 64):
                    observed[:] = [15] * 320
                    mask[0] = 255
                    m.mem_write(ds * 16 + 0x3644, struct.pack('<H', y & 1))
                    m.mem_write(0x8F000, struct.pack('<HH', 0xFF00, cs))
                    set_registers(m, ((UC_X86_REG_CS, cs), (UC_X86_REG_DS, ds),
                        (UC_X86_REG_ES, 0xA000), (UC_X86_REG_SS, 0x8000), (UC_X86_REG_SP, 0xF000),
                        (UC_X86_REG_AX, first), (UC_X86_REG_DX, second), (UC_X86_REG_BX, x),
                        (UC_X86_REG_CX, width), (UC_X86_REG_DI, 0), (UC_X86_REG_EFLAGS, 2)))
                    entry = 0x5AEF if first == second else 0x59FD
                    run_until(m, cs * 16 + entry, cs * 16 + 0xFF00, 20_000)
                    expected = [material_pixel(words, at, y) if x <= at < x + width else 15 for at in range(320)]
                    if observed != expected:
                        raise ValueError(f'material {material}, x={x}, y={y}, width={width}: '
                                         f'{[(i,a,b) for i,(a,b) in enumerate(zip(observed, expected)) if a!=b][:10]}')
                    cases += 1
                    pixels += 320
    return {'materials': len(materials), 'span_cases': cases, 'checked_pixels_including_untouched': pixels}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--capture', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    ram = args.capture.read_bytes()
    result = verify(ram) | {'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(ram).hexdigest(),
        'scope': 'original span instructions; observed mode-2 VGA bit-mask writes; isolated colour/coverage cases'}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
