#!/usr/bin/env python3
"""Run unchanged gunner reticle/line instructions in the pinned isolated CPU.

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
    UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_AX, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import cpu,set_registers,run_until
    from tools.pc_live_state import SimStateReader,SIM_SHA256
    from tools.unpack_pc_executables import unpack
    from tools.pc_reticle import lines,ink_pixels,TABLE_SHA256,CLIP,ReticleRuns
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu,set_registers,run_until
    from pc_live_state import SimStateReader,SIM_SHA256
    from unpack_pc_executables import unpack
    from pc_reticle import lines,ink_pixels,TABLE_SHA256,CLIP,ReticleRuns

ROOT=Path(__file__).resolve().parents[1]


def verify(ram):
    if unicorn.__version__!='2.1.4': raise ValueError('requires pinned Unicorn 2.1.4')
    state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('missing original SIM')
    load=state['load_segment'];base=load*16;ds=load+0x19E0;data=ds*16
    original,report=unpack((ROOT/'GAME/SIM.EXE').read_bytes());original=bytearray(original)
    for entry in report['relocations']:
        at=entry['load_offset'];struct.pack_into('<H',original,at,(struct.unpack_from('<H',original,at)[0]+load)&65535)
    if hashlib.sha256(ram[data+0xBBA:data+0xBFA]).hexdigest()!=TABLE_SHA256:
        raise ValueError('reticle table differs')
    m=cpu();m.mem_write(0,ram)
    seed=[bytes((i*13+p*57)&255 for i in range(65536)) for p in range(4)]
    planes=[];latch=[0]*4;mask=255;checked=set();observed=[];center=None;writes=0
    observer=ReticleRuns()

    def instruction(_m,address,size,_user):
        nonlocal center
        if (address,size) not in checked:
            at=address-base
            if not 0<=at<=len(original)-size or m.mem_read(address,size)!=original[at:at+size]:
                raise ValueError(f'instruction differs from original: {address:x}')
            checked.add((address,size))
        if address==base+0x65F1:
            center=(m.reg_read(UC_X86_REG_AX)+32768)%65536-32768
            observer.begin(bytes(m.mem_read(data,65536)),{'cs':load,'ds':ds,'ax':center&65535})
        elif address==base+0x6620:
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
    cases=[];turret=struct.unpack_from('<H',ram,data+0x7999)[0]
    for zoom in (7,8,9):
        for pitch in sorted(set(range(-256,257,8))|set(range(-12,13))):
            for color in (0,1):
                page=8192*color;fixture=bytearray(ram)
                for at,value,width in [(0x645C,pitch,2),(0x79AF,0,2),(turret+5,zoom,1),
                    (0x359B,1,1),(0x359E,color,1),(0x35A8,0xA000+page//16,2)]:
                    fixture[data+at:data+at+width]=(value&((1<<(width*8))-1)).to_bytes(width,'little')
                struct.pack_into('<4h',fixture,data+0x3593,CLIP[0],CLIP[2],CLIP[1],CLIP[3])
                m.mem_write(0,bytes(fixture));planes=[bytearray(p) for p in seed];mask=255;latch[:]=[0]*4
                observed=[];center=None
                m.mem_write(0x8F000,struct.pack('<H',0xFF00))
                set_registers(m,((UC_X86_REG_CS,load),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),
                    (UC_X86_REG_SS,0x8000),(UC_X86_REG_SP,0xF000),(UC_X86_REG_EFLAGS,2)))
                run_until(m,base+0x65E4,base+0xFF00,200_000)
                if m.reg_read(UC_X86_REG_SP)!=0xF002: raise ValueError('reticle stack imbalance')
                if observed!=lines(center): raise ValueError('original reticle line geometry differs')
                expected=[bytearray(p) for p in seed];ink=ink_pixels(center)
                for x,y in ink:
                    at=page+y*40+x//8;bit=128>>(x&7)
                    for p in range(4): expected[p][at]=(expected[p][at]&(255^bit))|(bit if color&(1<<p) else 0)
                if planes!=expected:
                    bad=[(p,i,a,b) for p in range(4) for i,(a,b) in enumerate(zip(planes[p],expected[p])) if a!=b][:12]
                    raise ValueError(f'pitch={pitch} zoom={zoom} center={center} color={color}: {bad}')
                pixels=bytes(sum(1<<p for p in range(4) if planes[p][page+y*40+x//8]&(128>>(x&7)))
                             for y in range(13,110) for x in range(134,185))
                observer.finish(struct.pack('<5H',134,13,51,97,page)+pixels)
                candidate=observer.scanout(page)
                if bool(candidate)!=bool(ink): raise ValueError('observer visibility differs from original CPU')
                cases.append({'pitch':pitch,'zoom':zoom,'center':center,'color':color,'page':page,
                              'lines':observed,'ink_pixels':ink,'pixels_hex':pixels.hex() if ink else '',
                              'presentation':candidate[0] if candidate else {}})
    # Exhaustive on-screen/clipping-centre coverage of the unchanged original
    # line wrapper, entered directly with each table line as stack arguments.
    # These are raster fixtures, not claims that every centre is live reachable.
    raster_cases=[]
    for center in range(-21,131):
        for color in (0,1):
            page=color*8192;planes=[bytearray(p) for p in seed];mask=255;latch[:]=[0]*4
            struct.pack_into('<H',fixture,data+0x35A8,0xA000+page//16);fixture[data+0x359E]=color
            m.mem_write(0,bytes(fixture))
            for point in lines(center):
                m.mem_write(0x8F000,struct.pack('<HH4h',0xFF00,load,*point))
                set_registers(m,((UC_X86_REG_CS,load+0xF8D),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),
                    (UC_X86_REG_SS,0x8000),(UC_X86_REG_SP,0xF000),(UC_X86_REG_EFLAGS,2)))
                run_until(m,base+0xF8D0+0x25A,base+0xFF00,200_000)
                if m.reg_read(UC_X86_REG_SP)!=0xF004: raise ValueError('line wrapper stack imbalance')
            expected=[bytearray(p) for p in seed]
            for x,y in ink_pixels(center):
                at=page+y*40+x//8;bit=128>>(x&7)
                for p in range(4): expected[p][at]=(expected[p][at]&(255^bit))|(bit if color&(1<<p) else 0)
            if planes!=expected: raise ValueError(f'clipped line raster mismatch center={center} color={color}')
            raster_cases.append({'center':center,'color':color,'ink_pixels':ink_pixels(center)})
    return {'sim_sha256':SIM_SHA256,'capture_sha256':hashlib.sha256(ram).hexdigest(),
        'engine':'unicorn-2.1.4/x86-16','case_count':len(cases),'instruction_locations':len(checked),
        'vga_writes':writes,'plane_bytes_compared':(len(cases)+len(raster_cases))*4*65536,'cases':cases,
        'clipping_raster_cases':len(raster_cases),'raster_cases':raster_cases,'observer':observer.report(),
        'scope':'unchanged 65e4 reticle, 21ea projection and original clipped line rasterizer; isolated input data, no live reachability or whole-game timing claim'}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS')): p.error('output must be outside original references')
    result=verify(a.capture.read_bytes());a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k not in ('cases','raster_cases')},indent=2))
