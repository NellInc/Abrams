#!/usr/bin/env python3
"""Execute the original packed cockpit-plate driver, without patching code.

Isolated instruction/planar-write parity only. This does not emulate file I/O,
prove live plate attribution, or authorise replacing subsequent instrument writes.
Requires the pinned analysis environment's unicorn==2.1.4.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

try:
    from tools.inspect_scenarios import decode_resource
    from tools.pc_live_state import SimStateReader, SIM_SHA256
except ModuleNotFoundError:
    from inspect_scenarios import decode_resource
    from pc_live_state import SimStateReader, SIM_SHA256

ROOT = Path(__file__).resolve().parents[1]
PLATES = ('FRAME', 'DRIVER.BIN', 'AA.BIN', 'TC.BIN', 'GPS.BIN', 'STATUS.BIN', 'IDENTIFY')
DRIVER_SHA256 = '98cd27399ec7b1ce25249512a3f2e328bd6846fc3ff50d643aa3d65227eac989'


class PlateVga:
    """Bounded mode-0 pipeline; unsupported guest operations fail closed."""
    def __init__(self):
        self.planes = [bytearray((i * 13 + p * 57) & 255 for i in range(65536)) for p in range(4)]
        self.latch = [0] * 4
        self.graphics = {0: 0, 1: 0, 3: 0, 4: 0, 5: 2, 8: 255}
        self.sequence_index = 2
        self.plane_mask = 15
        self.writes = 0

    def out(self, port, size, value):
        if port == 0x3CE and size == 2:
            index, data = value & 255, value >> 8
            if index not in self.graphics: raise ValueError(f'unsupported graphics register {index}')
            self.graphics[index] = data
        elif port == 0x3C4 and size == 1 and value == 2:
            self.sequence_index = value
        elif port == 0x3C5 and size == 1 and self.sequence_index == 2 and 0 <= value <= 15:
            self.plane_mask = value
        else:
            raise ValueError(f'unsupported VGA port {port:x}/{size}/{value:x}')

    @staticmethod
    def offset(address, size):
        if size != 1 or not 0xA0000 <= address < 0xB0000:
            raise ValueError('unsupported plate VGA access')
        return address - 0xA0000

    def read(self, address, size):
        at = self.offset(address, size)
        if not 0 <= self.graphics[4] < 4: raise ValueError('unsupported read map')
        self.latch[:] = [p[at] for p in self.planes]
        return self.latch[self.graphics[4]]

    def write(self, address, size, value):
        at = self.offset(address, size)
        if self.graphics[1] != 0 or self.graphics[3] != 0 or self.graphics[5] != 0:
            raise ValueError(f'unsupported plate write pipeline {self.graphics}')
        mask = self.graphics[8]
        for p in range(4):
            if self.plane_mask & (1 << p):
                self.planes[p][at] = (value & mask) | (self.latch[p] & (mask ^ 255))
        self.writes += 1


def verify(ram):
    import unicorn
    from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
    from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS,
        UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_EFLAGS,
        UC_X86_REG_BP, UC_X86_REG_SI, UC_X86_REG_DI)
    try:
        from tools.pc_bearing_oracle import cpu, set_registers, run_until
    except ModuleNotFoundError:
        from pc_bearing_oracle import cpu, set_registers, run_until
    if unicorn.__version__ != '2.1.4': raise ValueError('requires pinned unicorn==2.1.4')
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('original SIM unavailable')
    load = state['load_segment']
    ds = load + 0x19E0
    ip, cs = struct.unpack_from('<HH', ram, ds * 16 + 0x35F0)
    if (cs - load, ip) != (0x1388, 0x2217): raise ValueError('unsupported plate driver')
    code = ram[cs * 16 + 0x2206:cs * 16 + 0x231C]
    source = (ROOT / 'GAME/SIM.EXE').read_bytes()
    if hashlib.sha256(code).hexdigest() != DRIVER_SHA256 or source[0x15C86:0x15C86+len(code)] != code:
        raise ValueError('loaded driver/helper differ from original executable bytes')
    if ram[ds * 16 + 0x3592] != 0 or ram[ds * 16 + 0x51BE] != 0:
        raise ValueError('unsupported captured raster operation')
    if struct.unpack_from('<200H', ram, ds * 16 + 0x3F40) != tuple(y * 40 for y in range(200)):
        raise ValueError('unexpected original row lookup')
    m = cpu()
    m.mem_write(0, ram)
    vga = None

    def out(_m, port, size, value, _user):
        vga.out(port, size, value)

    def read(_m, _access, address, size, _value, _user):
        m.mem_write(address, bytes([vga.read(address, size)]))

    def write(_m, _access, address, size, value, _user):
        vga.write(address, size, value)

    m.hook_add(UC_HOOK_INSN, out, None, 1, 0, UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ, read, None, 0xA0000, 0xAFFFF)
    m.hook_add(UC_HOOK_MEM_WRITE, write, None, 0xA0000, 0xAFFFF)
    cases = []
    for name in PLATES:
        raw = (ROOT / 'GAME' / name).read_bytes()
        data = decode_resource(raw)
        if len(data) != 32000: raise ValueError('unsupported plate size')
        pixels = [n for b in data for n in (b >> 4, b & 15)]
        for page in (0, 8192):
            for chunk_rows in (1, 20, 200):
                vga = PlateVga()
                expected = [bytearray(p) for p in vga.planes]
                for at in range(8000):
                    for p in range(4):
                        expected[p][page + at] = sum((128 >> b) for b in range(8) if pixels[at * 8 + b] & (1 << p))
                m.mem_write(ds * 16 + 0x35A8, struct.pack('<H', 0xA000 + page // 16))
                for y in range(0, 200, chunk_rows):
                    # Deliberately non-canonical source pointer exercises the
                    # original offset-to-segment normalization. Fixture data and
                    # stack are separate from the captured original code/data.
                    chunk = data[y * 160:(y + chunk_rows) * 160]
                    m.mem_write(0x71234, chunk)
                    m.mem_write(0x8F000, struct.pack('<7H', 0xFF00, cs, 0x1234, 0x7000, len(chunk), 0, y))
                    saved = ((UC_X86_REG_DS, ds), (UC_X86_REG_SS, 0x8000), (UC_X86_REG_SP, 0xF000),
                             (UC_X86_REG_BP, 0x1234), (UC_X86_REG_SI, 0x4567), (UC_X86_REG_DI, 0x6789))
                    set_registers(m, saved + ((UC_X86_REG_CS, cs), (UC_X86_REG_ES, ds), (UC_X86_REG_EFLAGS, 2)))
                    # Stop after the epilogue, before RETF (same Unicorn return
                    # boundary as the bitmap oracle). No instruction replacement.
                    run_until(m, cs * 16 + ip, cs * 16 + 0x231B, 2_000_000)
                    if any(m.reg_read(reg) != value for reg, value in saved):
                        raise ValueError('plate driver failed to restore saved registers/stack')
                    if vga.plane_mask != 15 or vga.graphics[5] != 2 or vga.graphics[3] != 0:
                        raise ValueError('plate driver failed to restore VGA state')
                if vga.planes != expected:
                    errors = [[p, i, a, b] for p in range(4) for i, (a, b) in
                              enumerate(zip(vga.planes[p], expected[p])) if a != b][:10]
                    raise ValueError(f'{name}, page {page}, chunk {chunk_rows}: {errors}')
                if vga.writes != 32000: raise ValueError('unexpected plate plane write count')
                cases.append({'plate': name, 'page_offset': page, 'rows_per_chunk': chunk_rows,
                              'source_sha256': hashlib.sha256(raw).hexdigest(),
                              'decoded_sha256': hashlib.sha256(data).hexdigest()})
    return {'engine': 'unicorn-2.1.4/x86-16', 'driver': '1388:2217',
            'driver_and_helper_sha256': DRIVER_SHA256, 'cases': cases, 'plate_count': len(PLATES),
            'case_count': len(cases), 'rendered_pixels_checked': len(cases) * 64000,
            'planar_bytes_checked_including_untouched': len(cases) * 4 * 65536}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    ram = args.capture.read_bytes()
    result = verify(ram) | {'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(ram).hexdigest(),
        'scope': 'unmodified packed-plate driver; bounded mode-0 VGA observer; no file I/O or live UI attribution'}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({key: value for key, value in result.items() if key != 'cases'}, indent=2))


if __name__ == '__main__': main()
