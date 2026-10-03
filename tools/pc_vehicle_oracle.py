#!/usr/bin/env python3
"""Verify original vehicle drawing math, including register-sensitive quirks.

Executes unmodified instructions on isolated RAM copies. Does not write to the
live core, patch instructions, or claim that VGA snapshots carry CPU registers.
"""
from __future__ import annotations
import argparse
import hashlib
import itertools
import json
from pathlib import Path
import random
import struct

import unicorn
from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_EFLAGS, UC_X86_REG_CX, UC_X86_REG_AX
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.pc_vehicle_math import object_matrix, orientation_mode, compose, packed_axis_table
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from pc_vehicle_math import object_matrix, orientation_mode, compose, packed_axis_table
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]


class Probe:
    def __init__(self, ram):
        state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
        if not state: raise ValueError('supported original SIM required')
        self.load = state['load_segment']
        self.ds = self.load + 0x19E0
        self.code = self.load + 0xB4D
        self.machine = cpu()
        self.machine.mem_write(0, ram)
        self.sine = self.words(0x1D9C, 256)
        self.cosine = self.words(0x1E1C, 256)

    def write(self, at, values):
        self.machine.mem_write(self.ds * 16 + at, struct.pack('<' + 'H' * len(values), *(v & 65535 for v in values)))

    def words(self, at, count):
        return list(struct.unpack('<' + 'h' * count, self.machine.mem_read(self.ds * 16 + at, count * 2)))

    def call(self, entry, args, cx=0):
        set_registers(self.machine, ((UC_X86_REG_CS, self.code), (UC_X86_REG_DS, self.ds),
            (UC_X86_REG_ES, self.ds), (UC_X86_REG_SS, 0x8000), (UC_X86_REG_SP, 0xF000),
            (UC_X86_REG_EFLAGS, 2), (UC_X86_REG_CX, cx)))
        self.machine.mem_write(0x8F000, struct.pack('<' + 'H' * (len(args) + 1), 0xFF00, *args))
        run_until(self.machine, self.code * 16 + entry, self.code * 16 + 0xFF00, 100_000)
        if self.machine.reg_read(UC_X86_REG_SP) != 0xF002: raise ValueError('unbalanced original stack')

    def matrix(self, angles):
        mode = orientation_mode(angles)
        self.machine.mem_write(self.ds * 16 + 0xF000, bytes(angles))
        self.call(0xAA2, (0xF000, 0xF010, mode))
        return self.words(0xF010, 9), mode


def run(ram):
    probe = Probe(ram)
    rng = random.Random(1988)
    angles = {(0, 0, 0)}
    for axis in range(3):
        for angle in range(256):
            triple = [0, 0, 0]; triple[axis] = angle; angles.add(tuple(triple))
    angles.update(itertools.product((0, 1, 63, 64, 127, 128, 192, 255), repeat=3))
    angles.update(tuple(rng.randrange(256) for _ in range(3)) for _ in range(1024))
    matrices = []
    for triple in sorted(angles):
        actual, mode = probe.matrix(triple)
        expected = object_matrix(triple, probe.sine, probe.cosine)
        if actual != expected: raise ValueError(f'object matrix differs at {triple}: {actual} != {expected}')
        matrices.append((actual, mode))
    print(f'PASS {len(matrices)} original object matrices', flush=True)
    # Check every packed coefficient table used by these verified matrices.
    coefficients = sorted({value for matrix, _ in matrices for value in matrix})
    for coefficient in coefficients:
        probe.write(0xF100, [coefficient] * 9)
        probe.call(0x1E49, (0xF100, 3, 0xF200))
        actual = probe.words(0xF200, 17 * 9)
        expected = packed_axis_table(coefficient) * 9
        if actual != expected: raise ValueError(f'packed lookup differs at coefficient {coefficient}')
    print(f'PASS {len(coefficients)} original packed rotation tables', flush=True)
    # Include all actual builder modes and deliberately varied incoming CX.
    groups = {mode: [(m, mode) for m, k in matrices if k == mode] for mode in range(4)}
    count = 0
    quirks = []
    for left_mode, right_mode in itertools.product(range(4), repeat=2):
        for _ in range(24):
            left, _ = rng.choice(groups[left_mode]); right, _ = rng.choice(groups[right_mode])
            for cx in (0, 1, 16383, 32768, 65535):
                probe.write(0xF100, left); probe.write(0xF120, right)
                probe.call(0xC6E, (0xF100, left_mode, 0xF120, right_mode, 0xF140), cx=cx)
                actual = probe.words(0xF140, 9)
                actual_mode = probe.machine.reg_read(UC_X86_REG_AX)
                expected, expected_mode = compose(left, left_mode, right, right_mode, cx)
                if (actual, actual_mode) != (expected, expected_mode):
                    raise ValueError(f'composition differs modes {left_mode}/{right_mode}, CX={cx}: {actual} != {expected}')
                count += 1
    print(f'PASS {count} original register-explicit matrix compositions', flush=True)
    # A compact reproducible witness: same matrices, different CX, different result.
    a, am = probe.matrix([0, 0, 30]); b, bm = probe.matrix([0, 0, 47])
    for cx in (0, 65535):
        probe.write(0xF100, a); probe.write(0xF120, b)
        probe.call(0xC6E, (0xF100, am, 0xF120, bm, 0xF140), cx=cx)
        quirks.append({'incoming_cx': cx, 'matrix': probe.words(0xF140, 9)})
    if quirks[0]['matrix'] == quirks[1]['matrix']: raise ValueError('register-dependence witness did not discriminate')
    return {'schema': 1, 'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(ram).hexdigest(),
        'object_matrix_cases': len(matrices), 'packed_coefficient_cases': len(coefficients),
        'packed_table_words_checked': len(coefficients) * 17 * 9,
        'matrix_composition_cases': count, 'register_dependence_witness': {'left_angles': [0,0,30],
            'right_angles': [0,0,47], 'results': quirks},
        'scope': 'isolated original vehicle drawing arithmetic; incoming CX observed as required input, absent from current VGA snapshot protocol'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if unicorn.__version__ != '2.1.4': raise ValueError('pinned Unicorn 2.1.4 required')
    if inside_source(args.output, ROOT, ('GAME',)): parser.error('output must be outside original GAME')
    result = run(args.capture.read_bytes())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__': main()
