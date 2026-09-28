#!/usr/bin/env python3
"""Execute unchanged PC systems-lamp instructions and compare complete VGA planes.

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
    UC_X86_REG_BP, UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_SI, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.unpack_pc_executables import unpack
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from unpack_pc_executables import unpack

ROOT = Path(__file__).resolve().parents[1]


def verify(ram, target_lock=False):
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

    def run(kind, entry, changes, rectangles, page=0, mode=16, end=0xFF00, si=0, locals=None):
        nonlocal planes, mask
        planes = [bytearray(p) for p in seed]; expected = [bytearray(p) for p in seed]
        mask = 255; latch[:] = [0]*4
        word(0x35A8, 0xA000 + page//16); byte(0x35AE, mode); byte(0x359B, 0)
        for at, value, width in changes:
            (word if width == 2 else byte)(at, value)
        machine.mem_write(0x8F000, struct.pack('<H', 0xFF00))
        set_registers(machine, ((UC_X86_REG_CS, load), (UC_X86_REG_DS, ds),
            (UC_X86_REG_ES, ds), (UC_X86_REG_SS, 0x8000), (UC_X86_REG_SP, 0xF000),
            (UC_X86_REG_SI, si), (UC_X86_REG_BP, 0xEF00), (UC_X86_REG_EFLAGS, 2)))
        if locals:
            for offset, value in locals.items(): machine.mem_write(0x8EF00+offset, struct.pack('<H',value))
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

    if target_lock:
        for mode in (16,0):
            for on in (0,1):
                for page in (0,8192):
                    run('target_lock',0x59D7,[(0xDB0,on,1)],
                        [[271,180,13,11,(6 if mode==16 else 14) if on else 0]],page,mode,0x5A0E)
        return {'cases':cases,'case_count':len(cases),'original_instruction_locations_checked':len(checked),
            'plane_bytes_checked_including_untouched':len(cases)*4*65536,'sim_sha256':SIM_SHA256,
            'scope':'unchanged target-lock lamp fragment 59d7..5a0e, both original palette branches and pages'}

    # Whole original commander routine, all states in every placement,
    # both source palette branches and alternating displayed pages.
    for mode in (16, 0):
        palette = (8,10,6) if mode==16 else (12,13,14)
        patterns = [[state]*12 for state in range(3)]
        patterns += [[state if i==j else 0 for i in range(12)] for j in range(12) for state in (1,2)]
        for index, states in enumerate(patterns):
            changes=[(0xC94+3*i,state,1) for i,state in enumerate(states)]
            rects=[[284 if i>=6 else 208,172+(i%6)*2,3,1,palette[state]] for i,state in enumerate(states)]
            run('commander_systems',0x6D18,changes,rects,(index%2)*8192,mode)
        # STATUS lamp fragment skips resource/font calls and enters at 6e01
        # with the original stack locals. Classifier and rectangle draw execute
        # unchanged. This proves raster semantics, not whole-modal timing.
        for i in range(12):
            for state in range(3):
                for page in (0,8192):
                    x,y=301 if i>=6 else 11,109+(i%6)*13
                    run('status_systems',0x6E01,[(0xC94+3*i,state,1)],
                        [[x,y,10,6,palette[state]]],page,mode,0x6E2D,
                        locals={-4:0xC92+3*i,-6:y+1,-2:x})
    return {'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(ram).hexdigest(),
        'engine': 'unicorn-2.1.4/x86-16', 'cases': cases, 'case_count': len(cases),
        'original_instruction_locations_checked': len(checked), 'vga_writes': writes,
        'plane_bytes_checked_including_untouched': len(cases)*4*65536,
        'scope': 'whole original commander lamp routine and STATUS lamp fragment, classifier and rectangle rasterizer; isolated fixtures, no live reachability or whole-modal timing claim'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target-lock',action='store_true')
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT/name).resolve()) for name in ('GAME', 'GENESIS')):
        parser.error('output must be outside original reference directories')
    result = verify(args.capture.read_bytes(),args.target_lock)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k != 'cases'}, indent=2))
