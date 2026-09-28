#!/usr/bin/env python3
"""Execute source-selected STATUS damage EGA bitmap blits with a bounded VGA memory/port observer.

No guest instruction substitutions. Hardware observation supports the planar
mode-0/mode-2 operations used here; it is not a complete VGA emulator.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from unicorn import UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_DS,
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.pc_bitmaps import decode_bitmaps, read_ega_bitmap
    from tools.inspect_scenarios import decode_resource
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from pc_bitmaps import decode_bitmaps, read_ega_bitmap
    from inspect_scenarios import decode_resource

ROOT = Path(__file__).resolve().parents[1]


def verify(ram, output):
    state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('original SIM missing')
    ds = state['load_segment'] + 0x19E0
    damage=(ROOT/'GAME/DAMAGE.BMP').read_bytes()
    if hashlib.sha256(damage).hexdigest()!='765a4b564fad3865e564427b957cbee2cb0b5695a878b63e3c07c141bbb68cdc':raise ValueError('unsupported DAMAGE source')
    images = decode_bitmaps(decode_resource(damage))
    table, = struct.unpack_from('<H', ram, ds*16+0x7098)
    loaded=[]
    for source in images:
        descriptor, = struct.unpack_from('<H',ram,ds*16+table+source['index']*2)
        sprite=read_ega_bitmap(ram,ds*16,descriptor)
        assert all(sprite[k]==source[k] for k in ('width','height','pixels'))
        assert sprite['opaque']==[p!=0 for p in source['pixels']]
        loaded.append(sprite|{'index':source['index'],'descriptor':descriptor})
    ip, cs = struct.unpack_from('<HH', ram, ds * 16 + 0x35BC)
    if cs * 16 + ip != (state['load_segment'] + 0xF8D) * 16 + 0x4512:
        raise ValueError('unsupported original bitmap driver')
    m = cpu()
    m.mem_write(0, ram)
    planes = [bytearray(65536) for _ in range(4)]
    from tools.unpack_pc_executables import unpack
    original, report=unpack((ROOT/'GAME/SIM.EXE').read_bytes());original=bytearray(original)
    for item in report['relocations']:
        at=item['load_offset'];struct.pack_into('<H',original,at,(struct.unpack_from('<H',original,at)[0]+state['load_segment'])&65535)
    checked=set()
    def instruction(_m,address,size,_u):
        at=address-state['load_segment']*16
        if size>16 or address+size>0x100000:raise ValueError(f'invalid instruction address={address:x} size={size} cs={m.reg_read(UC_X86_REG_CS):x} ip={m.reg_read(UC_X86_REG_IP):x} sp={m.reg_read(UC_X86_REG_SP):x}')
        if (address,size) not in checked:
            assert bytes(m.mem_read(address,size))==original[at:at+size], hex(address)
            checked.add((address,size))
    m.hook_add(UC_HOOK_CODE,instruction)
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
        if not 0xA0000 <= address < 0xB0000: return
        if address + size > 0xB0000 or size != 1: raise ValueError('unsupported bitmap VGA read')
        raw = []
        for i in range(size):
            for p in range(4): latch[p] = planes[p][address + i - 0xA0000]
            raw.append(latch[graphics[4]])
        m.mem_write(address, bytes(raw))

    def write(_m, _access, address, size, value, _user):
        if not 0xA0000 <= address < 0xB0000:return
        if address+size>0xB0000 or size not in (1,2):raise ValueError('unsupported bitmap write width')
        if graphics[3]!=0 or graphics[1]!=0 or graphics[5] not in (0,2):raise ValueError(f'unsupported pipeline {graphics}')
        mask=graphics[8]
        if size==2 and mask!=255:raise ValueError('word write with partial latch mask')
        for byte in range(size):
            v=(value>>(byte*8))&255
            for p in range(4):
                if sequencer[2]&(1<<p):
                    color=(255 if v&(1<<p) else 0) if graphics[5]==2 else v
                    planes[p][address+byte-0xA0000]=(color&mask)|(latch[p]&(255^mask))

    m.hook_add(UC_HOOK_INSN, out, None, 1, 0, UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ, read)
    m.hook_add(UC_HOOK_MEM_WRITE, write)
    plate=(ROOT/'GAME/STATUS.BIN').read_bytes()
    if hashlib.sha256(plate).hexdigest()!='7d2abcfd40a79002087bd1534c9ac74ba846dd1cbf03b93f3f66314068b62166':raise ValueError('unsupported STATUS source')
    packed=decode_resource(plate)
    base_pixels=bytes(color for byte in packed for color in (byte>>4,byte&15))
    assert len(base_pixels)==64000
    cases=[]
    origins=[(188,54),(206,38),(203,83),(251,50),(146,65)]
    for mode in (16,):
      for page in (0,8192):
       for bits in range(32):
        graphics.update({0:0,1:0,3:0,4:0,5:2,8:255});sequencer[2]=15;latch[:]=[0]*4
        for p in range(4):
            planes[p][:]=bytes(65536)
            for at,color in enumerate(base_pixels):
                if color&(1<<p):planes[p][page+at//8]|=128>>(at&7)
        m.mem_write(ds*16+0x3593,struct.pack('<4H',0,319,0,199))
        m.mem_write(ds*16+0x359B,b'\x01')
        m.mem_write(ds*16+0x35A8,struct.pack('<H',0xA000+page//16))
        for sprite,(x,y) in zip(loaded,origins):
            if not bits&(1<<sprite['index']):continue
            m.mem_write(ds*16+0xF000,struct.pack('<HHHhh',0xFF00,cs,sprite['descriptor'],x,y))
            set_registers(m,((UC_X86_REG_CS,cs),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),
                (UC_X86_REG_SS,ds),(UC_X86_REG_SP,0xF000),(UC_X86_REG_EFLAGS,2)))
            run_until(m,cs*16+ip,cs*16+0x1862,200000)
            assert m.reg_read(UC_X86_REG_SP)==0xF000
        expected=bytearray(base_pixels);tags=bytearray([5])*64000
        for sprite,(x,y) in zip(loaded,origins):
            if not bits&(1<<sprite['index']):continue
            for sy in range(sprite['height']):
                for sx in range(sprite['width']):
                    at=sy*sprite['width']+sx
                    if sprite['opaque'][at]:
                        target=(y+sy)*320+x+sx;expected[target]=sprite['pixels'][at];tags[target]=0
        expected_planes=[bytearray(65536) for _ in range(4)]
        for at,color in enumerate(expected):
            for p in range(4):
                if color&(1<<p):expected_planes[p][page+at//8]|=128>>(at&7)
        assert planes==expected_planes, (bits,mode,page)
        if mode==16 and page==0:
            (output/f'state-{bits:02}.bin').write_bytes(expected)
            (output/f'tags-{bits:02}.bin').write_bytes(tags)
        cases.append({'bits':bits,'mode':mode,'page':page})
    return {'cases':cases,'instruction_locations':len(checked),'whole_plane_bytes_checked':len(cases)*65536*4,
        'source_selection':'five 6f22..7007 source-known combinations; unchanged original bitmap driver with full-screen clipping, stops before RETF',
        'images':len(loaded)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT/name).resolve()) for name in ('GAME','GENESIS')):
        parser.error('output must be outside original reference directories')
    raw = args.capture.read_bytes()
    args.output.parent.mkdir(parents=True,exist_ok=True)
    result = verify(raw,args.output.parent) | {'sim_sha256': SIM_SHA256, 'capture_sha256': hashlib.sha256(raw).hexdigest(),
        'scope': 'original bitmap instructions and loaded pixels/masks; bounded mode-0/mode-2 VGA observer'}
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__': main()
