#!/usr/bin/env python3
"""Recover damage messages by executing the original isolated message paths.

Subsystem cases start after the original random subsystem selection, with its
table index and stack locals supplied. Mobility cases run the whole damage
routine. No live game state/instructions are patched, and no occurrence, timing
or visibility claim is made by this oracle.
"""
import argparse
import json
import struct
from pathlib import Path
import unicorn
from unicorn.x86_const import (UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_AX, UC_X86_REG_EFLAGS)
try:
    from tools.pc_bearing_oracle import (ROOT, LOAD, DATA_SEGMENT, RETURN_IP,
        SIM_SHA256, cpu, original_unpack, set_registers, run_until, sha256)
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_bearing_oracle import (ROOT, LOAD, DATA_SEGMENT, RETURN_IP,
        SIM_SHA256, cpu, original_unpack, set_registers, run_until, sha256)


def run():
    if unicorn.__version__!='2.1.4': raise ValueError('pinned Unicorn required')
    source=(ROOT/'GAME/SIM.EXE').read_bytes()
    if sha256(source)!=SIM_SHA256: raise ValueError('unknown SIM executable')
    image,unpacked=original_unpack(source)
    ds=DATA_SEGMENT*16
    rows=[]
    for family,count,table in [('subsystem',9,0xc92),('mobility',3,0xcad)]:
        for index in range(count):
            for condition in range(3):
                m=cpu();m.mem_write(LOAD*16,image)
                m.mem_write(ds+0x58ee,b'\0\0') # isolated CRT stack lower bound
                at=table+3*index
                m.mem_write(ds+at+2,bytes([condition]))
                m.mem_write(ds+0x94c,b'\0\0')
                m.mem_write(ds+0x646a,b'\0\0')
                set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,DATA_SEGMENT),
                    (UC_X86_REG_ES,DATA_SEGMENT),(UC_X86_REG_SS,0x4000),
                    (UC_X86_REG_SP,0xffe0),(UC_X86_REG_EFLAGS,2)))
                if family=='subsystem':
                    # 69b6 has stored the chosen table record at BP-4, AX=record.
                    set_registers(m,((UC_X86_REG_BP,0xfff0),(UC_X86_REG_AX,at)))
                    m.mem_write(0x4ffec,struct.pack('<H',at))
                    run_until(m,LOAD*16+0x69b9,LOAD*16+0x6a18,10000)
                    if m.reg_read(UC_X86_REG_SP)!=0xffe0: raise ValueError('subsystem stack imbalance')
                    expected=min(condition+1,2)
                else:
                    health,damage=[(100,50),(50,40),(10,1)][condition]
                    m.mem_write(ds+0xcc4+2*index,struct.pack('<H',health))
                    m.mem_write(0x4ffe0,struct.pack('<HHH',RETURN_IP,damage,index))
                    run_until(m,LOAD*16+0x6a2c,LOAD*16+RETURN_IP,10000)
                    if m.reg_read(UC_X86_REG_SP)!=0xffe2: raise ValueError('mobility stack imbalance')
                    expected=min(condition+1,2)
                actual=bytes(m.mem_read(ds+at+2,1))[0]
                if actual!=expected: raise ValueError('unexpected original condition transition')
                pointers=[struct.unpack('<H',m.mem_read(ds+p,2))[0] for p in (0x94c,0x646a)]
                def string(pointer):
                    data=bytes(m.mem_read(ds+pointer,128))
                    return data[:data.index(0)].decode('cp437')
                parts=[string(p) for p in pointers] if pointers[0] else []
                if bool(parts)!=(condition!=2): raise ValueError('unexpected assignment/suppression')
                speaker=bytes(m.mem_read(ds+0x6464,1))[0] if parts else None
                if parts and speaker!=3: raise ValueError('unexpected original portrait')
                rows.append({'family':family,'index':index,'condition_before':condition,
                    'condition_after':actual,'speaker':speaker,'assignment_ip':0x3dd2 if parts else None,
                    'pointers':pointers,'parts':parts,'caption':''.join(parts)})
    return {'source_sha256':SIM_SHA256,'engine':'unicorn-2.1.4/x86-16','unpack':unpacked,
        'scope':__doc__,'rows':rows}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--check-fixture',type=Path)
    args=p.parse_args();result=run()
    if args.check_fixture and result!=json.loads(args.check_fixture.read_text()):
        raise ValueError('original damage messages differ from fixture')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('PC_DAMAGE_VOICE: 36 original cases, 24 two-part reports and 12 repeat suppressions')


if __name__=='__main__': main()
