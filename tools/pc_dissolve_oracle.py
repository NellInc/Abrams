#!/usr/bin/env python3
"""Run the original CPU-assembled EGA dissolve copy without patching instructions."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import time
try:
    from tools.pc_plate_oracle import PlateVga, ROOT
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.pc_bearing_oracle import cpu, set_registers
except ModuleNotFoundError:
    from pc_plate_oracle import PlateVga, ROOT
    from pc_live_state import SimStateReader, SIM_SHA256
    from pc_bearing_oracle import cpu, set_registers
import unicorn
from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_EFLAGS, UC_X86_REG_SI, UC_X86_REG_DI, UC_X86_REG_BP, UC_X86_REG_IP)

DRIVER_SHA256 = 'c37f06142efc6b74d1536483c15ee4e062b9ad1402c134cf2f915b92c0dc13af'


class DissolveVga(PlateVga):
    def __init__(self):
        super().__init__()
        self.graphics[7] = 15
        self.graphics_index = 0

    def out(self, port, size, value):
        if port == 0x3CE and size == 1 and value in self.graphics:
            self.graphics_index = value
        elif port == 0x3CF and size == 1:
            self.graphics[self.graphics_index] = value
        else:
            super().out(port,size,value)

    def write(self, address, size, value):
        at = self.offset(address,size)
        if self.graphics[5] != 2 or self.graphics[3] != 0 or self.plane_mask != 15:
            raise ValueError('unsupported dissolve pipeline')
        mask = self.graphics[8]
        for p in range(4):
            self.planes[p][at] = ((255 if value & (1 << p) else 0) & mask) | (self.latch[p] & (mask ^ 255))
        self.writes += 1


def verify(ram):
    if unicorn.__version__ != '2.1.4': raise ValueError('requires pinned unicorn==2.1.4')
    state = SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('original SIM unavailable')
    load = state['load_segment']
    ds, cs = load+0x19E0, load+0x1388
    if struct.unpack_from('<HH',ram,ds*16+0x3604) != (0x1FF3,cs): raise ValueError('unsupported dissolve driver')
    code = ram[cs*16+0x1FF3:cs*16+0x20D1]
    if hashlib.sha256(code).hexdigest() != DRIVER_SHA256 or (ROOT/'GAME/SIM.EXE').read_bytes()[0x15A73:0x15A73+len(code)] != code:
        raise ValueError('dissolve driver differs from original executable')
    cases = []
    for source,dest in ((0,8192),(8192,0)):
        vga = DissolveVga()
        # Make the two pages intentionally different, with all 16 colours.
        for p in range(4): vga.planes[p][8192:16192] = bytes(v ^ 0xA5 for v in vga.planes[p][8192:16192])
        expected = [bytearray(plane) for plane in vga.planes]
        for p in range(4):
            retained = expected[p][dest+7999] & 128
            expected[p][dest:dest+8000] = expected[p][source:source+8000]
            # The original exits when its LFSR returns to seed f9ff, before
            # writing that seed. Its low three bits select 1<<7, so physical
            # pixel (312,199), not (319,199), remains from the destination.
            expected[p][dest+7999] = (expected[p][dest+7999] & 127) | retained
        m = cpu()
        m.mem_write(0,ram)
        m.mem_write(ds*16+0x35A2,struct.pack('<HH',0xA000+source//16,0xA000+dest//16))
        m.mem_write(0x8F000,struct.pack('<HH',0xFF00,cs))
        saved = ((UC_X86_REG_DS,ds),(UC_X86_REG_SS,0x8000),(UC_X86_REG_SP,0xF000),
                 (UC_X86_REG_BP,123),(UC_X86_REG_SI,456),(UC_X86_REG_DI,789))
        set_registers(m,saved+((UC_X86_REG_CS,cs),(UC_X86_REG_ES,ds),(UC_X86_REG_EFLAGS,2)))
        def out(_m,port,size,value,_user): vga.out(port,size,value)
        def read(_m,_access,address,size,_value,_user): m.mem_write(address,bytes([vga.read(address,size)]))
        def write(_m,_access,address,size,value,_user): vga.write(address,size,value)
        m.hook_add(UC_HOOK_INSN,out,None,1,0,UC_X86_INS_OUT)
        m.hook_add(UC_HOOK_MEM_READ,read,None,0xA0000,0xAFFFF)
        m.hook_add(UC_HOOK_MEM_WRITE,write,None,0xA0000,0xAFFFF)
        # This 64,000-pixel CPU loop exceeded the smaller oracles' five-second
        # host limit. Keep an explicit time/instruction bound and report both
        # partial write count and CPU position if it still cannot complete.
        started = time.monotonic()
        m.emu_start(cs*16+0x1FF3,cs*16+0x20D0,timeout=30_000_000,count=10_000_000)
        elapsed = time.monotonic()-started
        at = m.reg_read(UC_X86_REG_CS)*16 + m.reg_read(UC_X86_REG_IP)
        if at != cs*16+0x20D0:
            raise ValueError(f'dissolve did not return: {at:x}; writes={vga.writes}; elapsed={elapsed:.3f}s')
        if any(m.reg_read(r)!=v for r,v in saved): raise ValueError('dissolve epilogue did not restore registers')
        if vga.planes != expected:
            errors = [[p,i,a,b] for p in range(4) for i,(a,b) in enumerate(zip(vga.planes[p],expected[p])) if a!=b]
            raise ValueError(f'dissolve copy differs: {errors[:12]}; mismatched plane bytes={len(errors)}; writes={vga.writes}; elapsed={elapsed:.3f}s')
        if vga.writes != 63999: raise ValueError('unexpected number of original dissolve pixel writes')
        cases.append({'source':source,'dest':dest,'pixel_writes':vga.writes,'host_seconds':elapsed})
    return {'cases':cases,'rendered_pixels_checked':128000,'planar_bytes_checked_including_untouched':524288,
            'driver_sha256':DRIVER_SHA256,'sim_sha256':SIM_SHA256,
            'original_retained_destination_pixel':[312,199],
            'capture_sha256':hashlib.sha256(ram).hexdigest(),
            'scope':'unmodified original dissolve driver, bounded mode-2 VGA observer; no file I/O or timing claim'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args = parser.parse_args()
    result = verify(args.capture.read_bytes())
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
