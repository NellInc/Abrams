#!/usr/bin/env python3
"""Execute unchanged original class-pointer and shape-relocation loops in isolation."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import unicorn
from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_ES,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_EFLAGS
try:
    from tools.pc_vehicle_catalog import ROOT,DATA,TABLE,STRIDE,COUNT,VARIANTS,source_catalog,verify_live
    from tools.pc_bearing_oracle import cpu,set_registers,run_until
    from tools.pc_live_state import SimStateReader
    from tools.unpack_pc_executables import unpack
except ModuleNotFoundError:
    from pc_vehicle_catalog import ROOT,DATA,TABLE,STRIDE,COUNT,VARIANTS,source_catalog,verify_live
    from pc_bearing_oracle import cpu,set_registers,run_until
    from pc_live_state import SimStateReader
    from unpack_pc_executables import unpack


def verify(ram):
    if unicorn.__version__!='2.1.4':raise ValueError('requires pinned Unicorn 2.1.4')
    catalog,_=source_catalog();live=verify_live(ram,catalog)
    state=SimStateReader(ROOT/'GAME/SIM.EXE').read(ram);load=state['load_segment'];ds=(load+0x19E0)*16
    source,_=unpack((ROOT/'GAME/SIM.EXE').read_bytes())
    spans=[(0x506C,0x5091),(0x5114,0x5159)];code=[]
    for start,end in spans:
        actual=ram[load*16+start:load*16+end]
        if actual!=source[start:end]:raise ValueError('original initialization loop differs from source')
        code.append({'start':start,'end':end,'sha256':hashlib.sha256(actual).hexdigest()})
    m=cpu();m.mem_write(0,ram)
    original=source[DATA+TABLE:DATA+TABLE+STRIDE*COUNT]
    m.mem_write(ds+TABLE,original)
    pointers=struct.unpack_from('<H',ram,ds+0x8654)[0]
    m.mem_write(ds+pointers,bytes([0xCC])*(2*COUNT))
    set_registers(m,((UC_X86_REG_CS,load),(UC_X86_REG_DS,ds//16),(UC_X86_REG_ES,ds//16),
        (UC_X86_REG_SS,ds//16),(UC_X86_REG_SP,0xF000),(UC_X86_REG_BP,0xF000),(UC_X86_REG_EFLAGS,2)))
    before=bytes(m.mem_read(0,len(ram)))
    for start,end in spans:run_until(m,load*16+start,load*16+end,10000)
    after=bytes(m.mem_read(0,len(ram)))
    allowed=set(range(ds+0xEFF8,ds+0xF000))|set(range(ds+pointers,ds+pointers+2*COUNT))|{ds+0x7998}
    for row in catalog['classes']:
        at=row['table_offset'];allowed.update(range(ds+at+6,ds+at+9))
        if struct.unpack_from('<H',after,ds+pointers+2*row['class_index'])[0]!=at:raise ValueError('CPU pointer construction mismatch')
        expected=bytes(255 if row['shapes'][v] is None else row['shapes'][v] for v in VARIANTS)
        if after[ds+at+6:ds+at+9]!=expected:raise ValueError('CPU shape relocation mismatch')
    changed={i for i,(a,b) in enumerate(zip(before,after)) if a!=b}
    if changed-allowed:raise ValueError('unexpected original-loop memory writes')
    if after[ds+0x7998]!=125:raise ValueError('original player class selection mismatch')
    return {'checks':{'31_pointer_entries':True,'93_shape_fields_including_sentinels':True,'original_player_shape_125':True,'all_640KiB_writes_within_original_loop_outputs':True},
            'changed_bytes':len(changed),'code_spans':code,'live':live,'unicorn':unicorn.__version__,
            'scope':'Unchanged original loops with reset source table and existing loaded context, isolated synthetic memory only. No live guest writes or DOS/timing claim.'}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=verify(a.capture.read_bytes());a.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
