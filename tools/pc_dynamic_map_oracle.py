#!/usr/bin/env python3
"""Execute exact original map argument blocks; no live-state or VGA parity claim."""
import argparse,json,struct
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_BP,UC_X86_REG_AX,UC_X86_REG_EFLAGS
from pc_bearing_oracle import ROOT,LOAD,cpu,original_unpack,set_registers,run_until,sha256

def run():
 raw=(ROOT/'GAME/SIM.EXE').read_bytes();image,proof=original_unpack(raw);m=cpu();m.mem_write(LOAD*16,image)
 cases=[]
 for x,y in [(16,63),(157,63),(16,157),(157,157),(88,109)]:
  for color in range(16):
   for start,stop,locals_,expected in [(0x0ff8,0x1011,{-6:color,-8:x,-10:y},[x,y,x+2,y]),(0x1019,0x102c,{-8:x,-10:y},[x,y+1,x+2,y+1])]:
    for at,value in locals_.items():m.mem_write(0x48000+at,struct.pack('<h',value))
    set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,LOAD+0x19e0),(UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0x7fc0),(UC_X86_REG_BP,0x8000),(UC_X86_REG_EFLAGS,2)))
    run_until(m,LOAD*16+start,LOAD*16+stop,100)
    actual=list(struct.unpack('<4h',m.mem_read(0x40000+m.reg_read(UC_X86_REG_SP),8)))
    assert actual==expected
    assert bytes(m.mem_read((LOAD+0x19e0)*16+0x359d,2))==bytes([color,color])
    cases.append({'caller':stop,'line':actual,'color_fixture':color})
 for start,stop,expected in [(0x1253,0x1263,[87,110,88,110]),(0x126b,0x1279,[87,111,88,111])]:
  m.mem_write(0x47ffe,struct.pack('<h',88));m.mem_write(0x47ffc,struct.pack('<h',111))
  set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,LOAD+0x19e0),(UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0x7fc0),(UC_X86_REG_BP,0x8000),(UC_X86_REG_EFLAGS,2)))
  run_until(m,LOAD*16+start,LOAD*16+stop,100)
  actual=list(struct.unpack('<4h',m.mem_read(0x40000+m.reg_read(UC_X86_REG_SP),8)));assert actual==expected
  cases.append({'caller':stop,'line':actual})
 for color in (5,6):
  m.mem_write(0x47ffc,struct.pack('<h',73));m.mem_write(0x47ffa,struct.pack('<h',101))
  set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,LOAD+0x19e0),(UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0x7fc0),(UC_X86_REG_BP,0x8000),(UC_X86_REG_AX,color),(UC_X86_REG_EFLAGS,2)))
  run_until(m,LOAD*16+0x1190,LOAD*16+0x1197,100)
  actual=list(struct.unpack('<3h',m.mem_read(0x40000+m.reg_read(UC_X86_REG_SP),6)));assert actual==[73,101,color]
  cases.append({'caller':0x1197,'point_color':actual})
 return {'source_sha256':sha256(raw),'scope':__doc__,'unpack':proof,'cases':cases}
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=run();a.output.write_text(json.dumps(r,indent=2)+'\n');print('PC_DYNAMIC_MAP_ORACLE:',len(r['cases']),'exact original argument blocks passed')
