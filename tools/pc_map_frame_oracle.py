#!/usr/bin/env python3
"""Verify unchanged original FRAME argument blocks in an isolated x86 CPU.

Stops before the original far loader call: no file I/O, live mission, selection,
render timing or complete driver proof is implied.
"""
import argparse,json,struct
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_EFLAGS
from pc_bearing_oracle import ROOT,LOAD,cpu,original_unpack,set_registers,run_until,sha256
CASES=[('START',0x1505,0xbdd,0xbe1,0x2d0,0x760,0x7fa),('END',0xd22,0x2e0,0x2e4,0x3aa,0x477,0x802)]
def run():
 rows=[]
 for name,ds,start,call,pointer,segment,ip in CASES:
  raw=(ROOT/'GAME'/f'{name}.EXE').read_bytes();image,proof=original_unpack(raw)
  m=cpu();m.mem_write(LOAD*16,image)
  set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,LOAD+ds),(UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0xffe0),(UC_X86_REG_EFLAGS,2)))
  run_until(m,LOAD*16+start,LOAD*16+call,50)
  arg=struct.unpack('<H',m.mem_read(0x40000+m.reg_read(UC_X86_REG_SP),2))[0]
  assert arg==pointer and bytes(m.mem_read((LOAD+ds)*16+arg,6))==b'frame\0'
  assert image[call:call+5]==b'\x9a'+struct.pack('<HH',ip,LOAD+segment)
  rows.append({'program':name,'source_sha256':sha256(raw),'ds':ds,'argument_block':start,'loader_call':call,
               'filename_pointer':arg,'filename':'frame','loader_target':[segment,ip],'unpack':proof})
 return {'schema':1,'scope':__doc__,'rows':rows}
if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=run()
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(r,indent=2)+'\n');print('PC_MAP_FRAME_ORACLE: 2 original FRAME argument blocks verified')
