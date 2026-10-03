#!/usr/bin/env python3
"""Check every supplied native font glyph against the unchanged EGA character driver.

Isolated CPU plus bounded mode-2 planar observation. No original instruction
substitutions, font smoothing, DOS services, live guest writes or timing claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import unicorn
from unicorn import UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_DX, UC_X86_REG_AX, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu,set_registers,run_until
    from tools.pc_live_state import SimStateReader,SIM_SHA256
    from tools.pc_fonts import FONT_NAMES,decode_font,loaded_font
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_bearing_oracle import cpu,set_registers,run_until
    from pc_live_state import SimStateReader,SIM_SHA256
    from pc_fonts import FONT_NAMES,decode_font,loaded_font

ROOT=Path(__file__).resolve().parents[1]
DRIVER_SHA='f4139b282b485998e11c05b9c9ca4f87b0a3f583ee7e2a167f9e7acebfa194c7'


def verify(ram):
    if unicorn.__version__ != '2.1.4': raise ValueError('requires pinned Unicorn 2.1.4')
    state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('missing fingerprinted SIM')
    load=state['load_segment'];ds=(load+0x19E0)*16;cs=load+0x1388
    if struct.unpack_from('<HH',ram,ds+0x35B4)!=(0x68,cs): raise ValueError('unknown original font driver')
    code=ram[cs*16+0x68:cs*16+0x32D]
    if hashlib.sha256(code).hexdigest()!=DRIVER_SHA or (ROOT/'GAME/SIM.EXE').read_bytes()[80616:80616+len(code)]!=code:
        raise ValueError('font driver differs from original source bytes')
    catalog={name:(ROOT/'GAME'/name).read_bytes() for name in FONT_NAMES}
    current=loaded_font(ram,ds,catalog)
    m=cpu();m.mem_write(0,ram)
    seed=[bytes((i*13+p*57)&255 for i in range(65536)) for p in range(4)]
    planes=[];latch=[0]*4;mask=255;writes=0
    def out(_m,port,size,value,_user):
        nonlocal mask
        if port!=0x3CE or size!=2 or value&255!=8: raise ValueError('unsupported font graphics port')
        mask=value>>8
    def read(_m,_access,address,size,_value,_user):
        if size!=1: raise ValueError('unsupported font VGA read')
        at=address-0xA0000
        latch[:]=[p[at] for p in planes]
        m.mem_write(address,bytes([latch[0]]))
    def write(_m,_access,address,size,value,_user):
        nonlocal writes
        if size!=1: raise ValueError('unsupported font VGA write')
        at=address-0xA0000
        for p in range(4): planes[p][at]=((255 if value&(1<<p) else 0)&mask)|(latch[p]&(mask^255))
        writes+=1
    m.hook_add(UC_HOOK_INSN,out,None,1,0,UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ,read,None,0xA0000,0xAFFFF)
    m.hook_add(UC_HOOK_MEM_WRITE,write,None,0xA0000,0xAFFFF)
    cases=[];total=0
    positions=[(24,20),(25,25),(31,40),(312,190)]
    for name,raw in catalog.items():
        font=decode_font(raw)
        m.mem_write(0x70000,raw[4:])
        for at,value in zip((0x364E,0x3662,0x3676,0x368A),raw[:4]): m.mem_write(ds+at,bytes([value]))
        m.mem_write(ds+0x369E,struct.pack('<H',0x7000))
        for index,glyph in enumerate(font['glyphs']):
            char=index+font['first']
            for mode in (0,1):
                foreground,background=(14,3) if mode==0 else (1,0)
                m.mem_write(ds+0x3642,bytes([foreground,background]))
                m.mem_write(ds+0x3592,bytes([mode]))
                for x,y in positions:
                    page=8192 if char&1 else 0
                    planes=[bytearray(p) for p in seed];expected=[bytearray(p) for p in seed];mask=255
                    m.mem_write(ds+0xF000,struct.pack('<HH',0xFF00,cs))
                    set_registers(m,((UC_X86_REG_CS,cs),(UC_X86_REG_DS,ds//16),(UC_X86_REG_ES,0xA000+page//16),
                        (UC_X86_REG_SS,ds//16),(UC_X86_REG_SP,0xF000),(UC_X86_REG_BP,y),
                        (UC_X86_REG_DX,x),(UC_X86_REG_AX,char),(UC_X86_REG_EFLAGS,2)))
                    run_until(m,cs*16+0x68,cs*16+0x32C,20000)
                    if m.reg_read(UC_X86_REG_SP)!=0xF000 or m.reg_read(UC_X86_REG_DS)!=ds//16:
                        raise ValueError('font driver epilogue differs')
                    # Original signed SUB/JL rejects bytes >=128 in these
                    # supplied fonts (all begin at32 and have count<128).
                    for gy in range(font['height'] if char < 128 else 0):
                        for gx in range(font['width']):
                            ink=glyph[gy*font['width']+gx]
                            if not ink and mode: continue
                            color=foreground if ink else background
                            at=page+(y+gy)*40+(x+gx)//8;bit=128>>((x+gx)&7)
                            for p in range(4): expected[p][at]=(expected[p][at]&(~bit&255))|(bit if color&(1<<p) else 0)
                    if planes!=expected:
                        bad=[(p,i,a,b) for p in range(4) for i,(a,b) in enumerate(zip(planes[p],expected[p])) if a!=b]
                        raise ValueError(f'{name} char={char} mode={mode} pos={x,y}: {bad[:10]}')
                    total+=1
        cases.append({'source':name,'source_sha256':font['sha256'],'cell':[font['width'],font['height']],
                      'first':font['first'],'glyphs':font['count'],'driver_rejected_codes':list(range(128,font['first']+font['count'])),'cases':font['count']*len(positions)*2})
    return {'sim_sha256':SIM_SHA256,'driver_sha256':DRIVER_SHA,'capture_sha256':hashlib.sha256(ram).hexdigest(),
            'loaded_font_sources':current['sources'],'cases':cases,'blit_cases':total,'plane_bytes_checked':total*4*65536,
            'VGA_writes':writes,'scope':'unchanged original EGA font driver, full planes including untouched bytes, both pages and opaque/transparent text; no DOS or timing claim'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=verify(a.capture.read_bytes());a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
