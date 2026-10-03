#!/usr/bin/env python3
"""Execute original warning assignment blocks, after their branch is selected.

No live memory or original instruction is modified. Caller-selected basic blocks
prove wording, portrait, pointers and setter identity, not trigger eligibility,
whole-routine behaviour, timing, or visible occurrence in a running mission.
"""
import argparse
import json
import struct
from pathlib import Path
import unicorn
from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import ROOT, LOAD, DATA_SEGMENT, SIM_SHA256, cpu, original_unpack, set_registers, run_until, sha256
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_bearing_oracle import ROOT, LOAD, DATA_SEGMENT, SIM_SHA256, cpu, original_unpack, set_registers, run_until, sha256
    from source_guard import inside_source

# Exact original argument-producing blocks through the returned original setter.
CASES=[('out_of_fuel',0x704d,0x7058,2,0x3d8e,[0xd0e]),
       ('engine_overheating',0x7080,0x7090,2,0x3dd2,[0xc8a,0xd21]),
       ('assigned_area',0x768e,0x7698,0,0x3d8e,[0xd4c]),
       ('assigned_area',0x20cd,0x20d7,0,0x3d8e,[0x272]),
       ('not_amphibious',0x76cd,0x7698,2,0x3d8e,[0xd6e]),
       ('slope_too_steep',0x7733,0x7698,2,0x3d8e,[0xd8d]),
       ('smoke_inoperable',0x7bdf,0x7bea,1,0x3d8e,[0xf73]),
       ('no_smoke_mortars',0x7bf7,0x7bea,1,0x3d8e,[0xf94]),
       ('convoy_destroyed',0x1b92,0x1b9c,0,0x3d8e,[0x220])]


def run():
    if unicorn.__version__!='2.1.4': raise ValueError('pinned Unicorn required')
    source=(ROOT/'GAME/SIM.EXE').read_bytes()
    if sha256(source)!=SIM_SHA256: raise ValueError('unknown original SIM')
    image,unpacked=original_unpack(source);ds=DATA_SEGMENT*16;rows=[]
    for name,start,end,speaker,assignment,pointers in CASES:
        m=cpu();m.mem_write(LOAD*16,image)
        m.mem_write(ds+0x58ee,b'\0\0')
        for p in (0x94c,0x646a):m.mem_write(ds+p,b'\xff\xff')
        m.mem_write(ds+0x6464,b'\xff')
        m.mem_write(0x4ffee,struct.pack('<H',0xcb3)) # overheat caller BP-2
        set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,DATA_SEGMENT),
            (UC_X86_REG_ES,DATA_SEGMENT),(UC_X86_REG_SS,0x4000),
            (UC_X86_REG_SP,0xffe0),(UC_X86_REG_BP,0xfff0),(UC_X86_REG_EFLAGS,2)))
        observed=[]
        m.hook_add(unicorn.UC_HOOK_CODE,lambda _m,address,_size,_data: observed.append(address-LOAD*16)
                   if address-LOAD*16 in (0x3d8e,0x3dd2) else None)
        run_until(m,LOAD*16+start,LOAD*16+end,10000)
        actual=[struct.unpack('<H',m.mem_read(ds+p,2))[0] for p in (0x94c,0x646a)]
        if actual!=pointers+([0] if len(pointers)==1 else []):raise ValueError('unexpected original pointers')
        if bytes(m.mem_read(ds+0x6464,1))[0]!=speaker:raise ValueError('unexpected portrait')
        if observed!=[assignment]:raise ValueError('unexpected setter path')
        if m.reg_read(UC_X86_REG_SP)!=0xffe0-2*(len(pointers)+1):raise ValueError('argument/stack mismatch')
        parts=[]
        for pointer in pointers:
            raw=bytes(m.mem_read(ds+pointer,128));parts.append(raw[:raw.index(0)].decode('cp437'))
        rows.append({'name':name,'entry_ip':start,'return_ip':end,'assignment_ip':assignment,
            'speaker':speaker,'pointers':pointers,'parts':parts,'caption':''.join(parts)})
    return {'source_sha256':SIM_SHA256,'engine':'unicorn-2.1.4/x86-16','unpack':unpacked,'scope':__doc__,'rows':rows}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--check-fixture',type=Path);a=p.parse_args()
    if inside_source(a.output, ROOT):p.error('output must be outside original files')
    result=run()
    if a.check_fixture and result!=json.loads(a.check_fixture.read_text()):raise ValueError('warning fixture differs')
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
    print('PC_WARNING_VOICE: 9 original assignment blocks, 8 distinct captions')

if __name__=='__main__':main()
