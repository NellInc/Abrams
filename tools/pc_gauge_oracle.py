#!/usr/bin/env python3
"""Execute unchanged PC gauge instructions and compare complete VGA planes.

Isolated fixtures only: no live guest writes, instruction substitutions or
whole-game timing claim. Requires the existing pinned Unicorn 2.1.4 environment.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

import unicorn
from unicorn import UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS,
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_SI, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.unpack_pc_executables import unpack
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from unpack_pc_executables import unpack

ROOT = Path(__file__).resolve().parents[1]


def signed16(value):
    return (value + 32768) % 65536 - 32768


def segments(value, denominator, count, threshold, low, high):
    # CWD after IMUL discards the high product word before signed division.
    product = signed16(signed16(abs(signed16(value))) * count)
    filled = abs(product) // denominator * (-1 if product < 0 else 1)
    return [3 if i >= filled else low if i < threshold else high for i in range(count)]


def verify(ram):
    if unicorn.__version__ != '2.1.4': raise ValueError('requires pinned Unicorn 2.1.4')
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('missing fingerprinted SIM')
    load = state['load_segment']; ds = load + 0x19E0; base = load * 16
    original, report = unpack((ROOT / 'GAME/SIM.EXE').read_bytes())
    original = bytearray(original)
    for item in report['relocations']:
        at = item['load_offset']
        struct.pack_into('<H', original, at, (struct.unpack_from('<H', original, at)[0] + load) & 65535)
    machine = cpu(); machine.mem_write(0, ram)
    seed = [bytes((i * 13 + p * 57) & 255 for i in range(65536)) for p in range(4)]
    planes = []; latch = [0] * 4; mask = 255; checked = set(); writes = 0

    def instruction(_m, address, size, _user):
        key = (address, size)
        if key in checked: return
        at = address - base
        if not 0 <= at <= len(original) - size or machine.mem_read(address, size) != original[at:at+size]:
            raise ValueError(f'executed instruction differs from relocated original at {address:x}')
        checked.add(key)

    def out(_m, port, size, value, _user):
        nonlocal mask
        if port == 0x3CE and size == 2 and value in (0x205, 0x003, 0x001, 0x000, 0x004):
            return  # Explicitly restore the already active mode-2 pipeline.
        if port != 0x3CE or size != 2 or value & 255 != 8:
            raise ValueError(f'unsupported mode-2 gauge port {port:x}/{size}/{value:x}')
        mask = value >> 8

    def read(_m, _access, address, size, _value, _user):
        if size != 1: raise ValueError('unsupported gauge VGA read')
        at = address - 0xA0000
        latch[:] = [p[at] for p in planes]
        machine.mem_write(address, bytes([latch[0]]))

    def write(_m, _access, address, size, value, _user):
        nonlocal writes
        if size != 1: raise ValueError('unsupported gauge VGA write')
        at = address - 0xA0000
        for p in range(4):
            planes[p][at] = ((255 if value & (1 << p) else 0) & mask) | (latch[p] & (mask ^ 255))
        writes += 1

    machine.hook_add(UC_HOOK_CODE, instruction)
    machine.hook_add(UC_HOOK_INSN, out, None, 1, 0, UC_X86_INS_OUT)
    machine.hook_add(UC_HOOK_MEM_READ, read, None, 0xA0000, 0xAFFFF)
    machine.hook_add(UC_HOOK_MEM_WRITE, write, None, 0xA0000, 0xAFFFF)
    cases = []

    def word(at, value): machine.mem_write(ds*16+at, struct.pack('<H', value & 65535))
    def byte(at, value): machine.mem_write(ds*16+at, bytes([value]))

    def run(kind, entry, changes, rectangles, page=0, mode=16, end=0xFF00, si=0):
        nonlocal planes, mask
        planes = [bytearray(p) for p in seed]; expected = [bytearray(p) for p in seed]
        mask = 255; latch[:] = [0]*4
        word(0x35A8, 0xA000 + page//16); byte(0x35AE, mode); byte(0x359B, 0)
        for at, value, width in changes:
            (word if width == 2 else byte)(at, value)
        machine.mem_write(0x8F000, struct.pack('<H', 0xFF00))
        set_registers(machine, ((UC_X86_REG_CS, load), (UC_X86_REG_DS, ds),
            (UC_X86_REG_ES, ds), (UC_X86_REG_SS, 0x8000), (UC_X86_REG_SP, 0xF000),
            (UC_X86_REG_SI, si), (UC_X86_REG_EFLAGS, 2)))
        run_until(machine, base+entry, base+end, 200_000)
        if machine.reg_read(UC_X86_REG_SP) != (0xF002 if end == 0xFF00 else 0xF000):
            raise ValueError('gauge stack imbalance')
        for x, y, width, height, colour in rectangles:
            for py in range(y, y+height):
                for px in range(x, x+width):
                    at = page + py*40 + px//8; bit = 128 >> (px & 7)
                    for p in range(4):
                        expected[p][at] = (expected[p][at] & (255 ^ bit)) | (bit if colour & (1 << p) else 0)
        if planes != expected:
            bad = [(p, i, a, b) for p in range(4) for i, (a, b) in enumerate(zip(planes[p], expected[p])) if a != b][:12]
            raise ValueError(f'{kind} {changes} page={page} mode={mode}: {bad}')
        cases.append({'kind': kind, 'inputs': changes, 'mode': mode, 'page': page,
                      'rectangles': rectangles})

    body = struct.unpack_from('<H', ram, ds*16+0x799B)[0]
    for mode in (16, 0):
        for station in (0, 1, 2):
            for value in list(range(-76, 77)) + [-32768, -841, -840, 840, 841, 32767]:
                colors = segments(value, 76, 39, 30, 8 if mode == 16 else 14, 8 if mode == 16 else 14)
                rects = [[(13 if station == 0 else 16)+i*2, 186, 1, 6, c] for i, c in enumerate(colors)] if station < 2 else []
                run('speed', 0x5B2E, [(0x799D, station, 1), (body+0x24, value, 2)], rects,
                    8192 if value & 1 else 0, mode)
        for value in list(range(-2, 103)) + [-32768, 1170, 1171, 32767]:
            colors = segments(value, 100, 28, 4, 6 if mode == 16 else 14, 8 if mode == 16 else 12)
            run('fuel', 0x5AE8, [(0x79A2, value, 2)], [[103+i*2, 186, 1, 6, c] for i, c in enumerate(colors)],
                8192 if value & 1 else 0, mode)
        for temp in (-32768, 174, 175, 176, 32767):
            for status in (-32768, 12, 13, 32767):
                for blink in (0, 1):
                    red = 6 if mode == 16 else 14
                    color = (8 if mode == 16 else 12) if temp < 175 else (10 if mode == 16 else 13) if status <= 12 else red if blink else 0
                    changes = [(0x79A4, temp, 2), (0x887A, status, 2), (0xA6A, blink, 1)]
                    run('gunner_temperature', 0x5A14, changes, [[271,154,13,11,color]], blink*8192, mode)
                    # Driver fragment enters after its red-colour setup; stop
                    # before the containing function's stack epilogue.
                    run('driver_temperature', 0x684F, changes, [[233,190,19,7,color]], blink*8192, mode, 0x6893, red)
    return {'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(ram).hexdigest(),
        'engine': 'unicorn-2.1.4/x86-16', 'cases': cases, 'case_count': len(cases),
        'original_instruction_locations_checked': len(checked), 'vga_writes': writes,
        'plane_bytes_checked_including_untouched': len(cases)*4*65536,
        'scope': 'original gauge callers, classifier, line and rectangle rasterization; isolated fixture data; no live guest changes or timing proof'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT/name).resolve()) for name in ('GAME', 'GENESIS')):
        parser.error('output must be outside original reference directories')
    result = verify(args.capture.read_bytes())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'cases'}, indent=2))
