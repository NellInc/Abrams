#!/usr/bin/env python3
"""Run unchanged target-box/line instructions in the pinned isolated CPU.

    Fixtures alter isolated input data only. No live guest writes or instruction
    substitutions. Every executed instruction is checked against SIM.EXE.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import unicorn
from unicorn import UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import (UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS,
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_AX, UC_X86_REG_BP, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu,set_registers,run_until
    from tools.pc_live_state import SimStateReader,SIM_SHA256
    from tools.unpack_pc_executables import unpack
    from tools.pc_reticle_target import lines,ink_pixels,CLIP,TargetBoxRuns
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu,set_registers,run_until
    from pc_live_state import SimStateReader,SIM_SHA256
    from unpack_pc_executables import unpack
    from pc_reticle_target import lines,ink_pixels,CLIP,TargetBoxRuns

ROOT=Path(__file__).resolve().parents[1]


def verify(ram):
    if unicorn.__version__!='2.1.4': raise ValueError('requires pinned Unicorn 2.1.4')
    state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('missing original SIM')
    load=state['load_segment'];base=load*16;ds=load+0x19E0;data=ds*16
    original,report=unpack((ROOT/'GAME/SIM.EXE').read_bytes());original=bytearray(original)
    for entry in report['relocations']:
        at=entry['load_offset'];struct.pack_into('<H',original,at,(struct.unpack_from('<H',original,at)[0]+load)&65535)
    m=cpu();m.mem_write(0,ram)
    seed=[bytes((i*13+p*57)&255 for i in range(65536)) for p in range(4)]
    planes=[];latch=[0]*4;mask=255;checked=set();observed=[];center=None;writes=0
    observer=TargetBoxRuns()

    def instruction(_m,address,size,_user):
        nonlocal center
        if (address,size) not in checked:
            at=address-base
            if not 0<=at<=len(original)-size or m.mem_read(address,size)!=original[at:at+size]:
                raise ValueError(f'instruction differs from original: {address:x}')
            checked.add((address,size))
        if address-base in (0x66DB,0x66F9,0x6717,0x6735):
            stack=m.reg_read(UC_X86_REG_SS)*16+m.reg_read(UC_X86_REG_SP)
            observed.append(struct.unpack('<4h',m.mem_read(stack,8)))
            observer.line(bytes(m.mem_read(stack,8))+bytes(m.mem_read(data+0x359E,1))+bytes(m.mem_read(data+0x359B,1))+bytes(m.mem_read(data+0x35A8,2)))

    def out(_m,port,size,value,_user):
        nonlocal mask
        if port==0x3CE and size==2 and value in (0x205,0x003,0x001,0x000,0x004): return
        if port!=0x3CE or size!=2 or value&255!=8: raise ValueError(f'unsupported VGA port {port:x}/{size}/{value:x}')
        mask=value>>8
    def read(_m,_access,address,size,_value,_user):
        if size!=1: raise ValueError('unsupported VGA read size')
        latch[:]=[p[address-0xA0000] for p in planes]
        m.mem_write(address,bytes([latch[0]]))
    def write(_m,_access,address,size,value,_user):
        nonlocal writes
        if size!=1: raise ValueError('unsupported VGA write size')
        at=address-0xA0000
        for p in range(4): planes[p][at]=((255 if value&(1<<p) else 0)&mask)|(latch[p]&(mask^255))
        writes+=1
    m.hook_add(UC_HOOK_CODE,instruction)
    m.hook_add(UC_HOOK_INSN,out,None,1,0,UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ,read,None,0xA0000,0xAFFFF)
    m.hook_add(UC_HOOK_MEM_WRITE,write,None,0xA0000,0xAFFFF)
    cases=[]
    xs=[-6,26,27,28,31,32,33,36,37,159,281,282,283,286,287,288,292,293,325]
    ys=[-6,7,8,9,12,13,14,17,18,60,103,104,105,108,109,110,114,115,206]
    for cx in xs:
        for cy in ys:
            for color in (0,1):
                page=color*8192;fixture=bytearray(ram)
                for at,value,width in [(0x79AF,1,2),(0x799D,0,1),(0x359B,1,1),(0x359E,color,1),(0x35A8,0xA000+page//16,2)]:
                    fixture[data+at:data+at+width]=value.to_bytes(width,'little')
                struct.pack_into('<4h',fixture,data+0x3593,CLIP[0],CLIP[2],CLIP[1],CLIP[3])
                m.mem_write(0,bytes(fixture));planes=[bytearray(p) for p in seed];mask=255;latch[:]=[0]*4
                observed=[]
                m.mem_write(0x8EEFA,struct.pack('<h',cx));m.mem_write(0x8EEF8,struct.pack('<h',cy))
                set_registers(m,((UC_X86_REG_CS,load),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),
                    (UC_X86_REG_SS,0x8000),(UC_X86_REG_SP,0xF000),(UC_X86_REG_BP,0xEF00),(UC_X86_REG_EFLAGS,2)))
                observer.begin(bytes(m.mem_read(data,65536)),{'cs':load,'ds':ds})
                run_until(m,base+0x66C5,base+0x673D,200_000)
                if m.reg_read(UC_X86_REG_SP)!=0xF000: raise ValueError('target fragment stack imbalance')
                if observed!=lines(cx,cy): raise ValueError('original target geometry differs')
                expected=[bytearray(p) for p in seed];ink=ink_pixels(cx,cy)
                for x,y in ink:
                    at=page+y*40+x//8;bit=128>>(x&7)
                    for p in range(4):expected[p][at]=(expected[p][at]&(255^bit))|(bit if color&(1<<p) else 0)
                if planes!=expected:raise ValueError(f'target raster mismatch center={cx},{cy} color={color}')
                pixels=bytes(sum(1<<p for p in range(4) if planes[p][page+y*40+x//8]&(128>>(x&7)))
                             for y in range(13,110) for x in range(32,288))
                observer.finish(struct.pack('<5H',32,13,256,97,page)+pixels)
                candidate=observer.scanout(page)
                if bool(candidate)!=bool(ink):raise ValueError('target observer differs from CPU ink')
                cases.append({'center':[cx,cy],'color':color,'page':page,'lines':observed,'ink_pixels':ink})
    return {'sim_sha256':SIM_SHA256,'capture_sha256':hashlib.sha256(ram).hexdigest(),
        'engine':'unicorn-2.1.4/x86-16','case_count':len(cases),'instruction_locations':len(checked),
        'vga_writes':writes,'plane_bytes_compared':len(cases)*4*65536,'cases':cases,
        'observer':observer.report(),
        'scope':'unchanged 66c5..673d target-box draw fragment and original line rasterizer; isolated projected screen positions, no projection substitution in live bridge or live reachability claim'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS')): p.error('output must be outside original references')
    result=verify(a.capture.read_bytes());a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('cases','raster_cases')},indent=2))
