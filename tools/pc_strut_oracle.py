#!/usr/bin/env python3
"""Execute unchanged loaded STRUTS bitmap blits and verify clipped custody.

Bounded source oracle, not a live play/reachability or timing claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys
from unicorn import UC_HOOK_CODE, UC_HOOK_INSN, UC_HOOK_MEM_READ, UC_HOOK_MEM_WRITE
from unicorn.x86_const import UC_X86_INS_OUT, UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_EFLAGS
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[1]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.pc_bearing_oracle import cpu,set_registers,run_until
from tools.pc_live_state import SimStateReader,SIM_SHA256
from tools.pc_bitmaps import decode_bitmaps,read_ega_bitmap
from tools.inspect_scenarios import decode_resource
from tools.unpack_pc_executables import unpack
from tools.pc_plate_trace import PlateLoads
from tools.pc_strut_trace import StrutDraws
from tools.source_guard import inside_source

ROOT=Path(__file__).resolve().parents[1]
POSITIONS={0:[(57,10),(257,10)],1:[(72,18)],2:[(0,128)],3:[(240,128)],4:[(0,110)],5:[(159,110)],6:[(95,85)]}


def verify(ram):
    state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram)
    if not state: raise ValueError('original SIM missing')
    load=state['load_segment'];ds=load+0x19E0;cs=load+0xF8D;base=load*16
    sources=decode_bitmaps(decode_resource((ROOT/'GAME/STRUTS.BMP').read_bytes()))
    table=struct.unpack_from('<H',ram,ds*16+0x798E)[0]
    driver_ip,driver_cs=struct.unpack_from('<HH',ram,ds*16+0x35BC)
    if driver_cs*16+driver_ip != cs*16+0x4512:raise ValueError('unsupported bitmap driver')
    loaded=[]
    for index,source in enumerate(sources):
        descriptor=struct.unpack_from('<H',ram,ds*16+table+2*index)[0]
        sprite=read_ega_bitmap(ram,ds*16,descriptor)
        if any(sprite[k]!=source[k] for k in ('width','height','pixels')) or sprite['opaque']!=[c!=0 for c in source['pixels']]:
            raise ValueError('loaded strut differs')
        loaded.append(sprite|{'index':index,'descriptor':descriptor})
    original,metadata=unpack((ROOT/'GAME/SIM.EXE').read_bytes());original=bytearray(original)
    for relocation in metadata['relocations']:
        at=relocation['load_offset'];struct.pack_into('<H',original,at,(struct.unpack_from('<H',original,at)[0]+load)&65535)
    m=cpu();m.mem_write(0,ram)
    planes=[bytearray(8000) for _ in range(4)];latch=[0]*4;graphics={};sequencer={};checked=set()
    returned=False
    def instruction(_m,address,size,_user):
        nonlocal returned
        # Empty clipped draws use a second original far-return path. Stop at
        # the verified root return rather than letting it enter fixture caller.
        if m.mem_read(address,1)==b'\xcb' and m.reg_read(UC_X86_REG_SP)==0xF000:
            returned=True;m.emu_stop();return
        if (address,size) in checked:return
        at=address-base
        if not 0<=at<=len(original)-size or m.mem_read(address,size)!=original[at:at+size]:raise ValueError('instruction differs from source')
        checked.add((address,size))
    def out(_m,port,size,value,_user):
        if size!=2 or port not in (0x3CE,0x3C4):raise ValueError(f'unsupported VGA port {port:x}/{size}/{value:x}')
        index,value=value&255,value>>8
        if port==0x3CE:
            if index not in (0,1,3,4,5,8):raise ValueError('unsupported graphics register')
            graphics[index]=value
        else:
            if index!=2:raise ValueError('unsupported sequencer register')
            sequencer[index]=value
    def read(_m,_access,address,size,_value,_user):
        if size!=1 or address>=0xA1F40:raise ValueError('unsupported VGA read')
        latch[:]=[p[address-0xA0000] for p in planes]
        m.mem_write(address,bytes([latch[graphics[4]]]))
    def write(_m,_access,address,size,value,_user):
        if size!=1 or address>=0xA1F40:raise ValueError('unsupported VGA write')
        if graphics[3]!=0 or graphics[1]!=0 or graphics[5] not in (0,2):raise ValueError('unsupported VGA pipeline')
        mask=graphics[8]
        for p in range(4):
            if sequencer[2]&(1<<p):
                colour=(255 if value&(1<<p) else 0) if graphics[5]==2 else value
                planes[p][address-0xA0000]=(colour&mask)|(latch[p]&(255^mask))
    m.hook_add(UC_HOOK_CODE,instruction)
    m.hook_add(UC_HOOK_INSN,out,None,1,0,UC_X86_INS_OUT)
    m.hook_add(UC_HOOK_MEM_READ,read,None,0xA0000,0xAFFFF)
    m.hook_add(UC_HOOK_MEM_WRITE,write,None,0xA0000,0xAFFFF)
    observer=StrutDraws(ROOT/'GAME',PlateLoads(ROOT/'GAME'));cases=[]
    for sprite in loaded:
        index=sprite['index']
        for x,y in POSITIONS[index]:
            for clip in [(0,319,0,199),(160,318,112,114)]:
                graphics.update({0:0,1:0,3:0,4:0,5:2,8:255});sequencer[2]=15;latch[:]=[0]*4
                for p in range(4):planes[p][:]=bytes([255 if 5&(1<<p) else 0])*8000
                fixture=bytearray(ram)
                struct.pack_into('<4h',fixture,ds*16+0x3593,*clip)
                fixture[ds*16+0x359B]=1;fixture[ds*16+0x359F]=15
                struct.pack_into('<H',fixture,ds*16+0x35A8,0xA000)
                caller=0x0D92 if index==5 else 0xFF00
                struct.pack_into('<HHHhh',fixture,ds*16+0xF000,caller,load,sprite['descriptor'],x,y)
                m.mem_write(0,bytes(fixture))
                regs={'cs':cs,'ds':ds,'ss':ds,'sp':0xF000}
                observer.begin(bytes(fixture),regs,index)
                set_registers(m,((UC_X86_REG_CS,driver_cs),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),(UC_X86_REG_SS,ds),(UC_X86_REG_SP,0xF000),(UC_X86_REG_EFLAGS,2)))
                returned=False
                m.emu_start(driver_cs*16+driver_ip,0,timeout=5_000_000,count=500_000)
                if not returned:raise ValueError('bitmap did not reach original far return')
                if m.reg_read(UC_X86_REG_SP)!=0xF000:raise ValueError('bitmap stack imbalance')
                expected=bytearray([5])*64000;ink=[]
                for sy in range(sprite['height']):
                    for sx in range(sprite['width']):
                        at=sy*sprite['width']+sx
                        if sprite['opaque'][at] and clip[0]<=x+sx<=clip[1] and clip[2]<=y+sy<=clip[3]:
                            expected[(y+sy)*320+x+sx]=sprite['pixels'][at];ink.append((y+sy)*320+x+sx)
                actual=bytes(sum(1<<p for p in range(4) if planes[p][at//8]&(128>>(at&7))) for at in range(64000))
                if actual!=expected:raise ValueError(f'strut{index} original framebuffer differs')
                claim=observer.finish(actual,0)
                if index==5:
                    if claim is None or claim[0]!=3 or sum(b.bit_count() for b in claim[1])!=len(ink):raise ValueError('clipped cupola custody differs')
                cases.append({'index':index,'origin':[x,y],'clip':list(clip),'opaque_pixels':len(ink),'plate_claim':claim[0] if claim else None})
    return {'sim_sha256':SIM_SHA256,'capture_sha256':hashlib.sha256(ram).hexdigest(),'case_count':len(cases),
            'checked_instruction_locations':len(checked),'framebuffer_pixels_checked':len(cases)*64000,
            'indices':sorted(POSITIONS),'cases':cases,'observer':observer.report(),'scope':__doc__}


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    if inside_source(a.output):p.error('output must stay outside originals')
    report=verify(a.capture.read_bytes());a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps({k:v for k,v in report.items() if k not in ('cases','observer')},indent=2))
