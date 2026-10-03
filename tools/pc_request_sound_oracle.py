#!/usr/bin/env python3
"""Execute exact original argument-producing blocks until the sound dispatcher.

No original instructions replaced. Proves source request/return-IP identity,
not branch eligibility, historic timing, semantic meaning or live occurrence.
"""
import json,struct
from pathlib import Path
from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_ES,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_EFLAGS
try:
 from tools.pc_bearing_oracle import ROOT,LOAD,DATA_SEGMENT,SIM_SHA256,cpu,original_unpack,set_registers,run_until,sha256
except ModuleNotFoundError as error:
 if error.name != 'tools': raise
 from pc_bearing_oracle import ROOT,LOAD,DATA_SEGMENT,SIM_SHA256,cpu,original_unpack,set_registers,run_until,sha256
CASES=((0x19ca,7,0x19d1),(0x520,9,0x527),(0x96d,10,0x974),(0x7789,10,0x7790),(0x348,15,0x34f),(0x8212,16,0x8219),(0x824f,16,0x8256))
def run():
 source=(ROOT/'GAME/SIM.EXE').read_bytes()
 if sha256(source)!=SIM_SHA256:raise ValueError('unknown SIM')
 image,unpack=original_unpack(source);rows=[]
 for entry,request,caller in CASES:
  m=cpu();m.mem_write(LOAD*16,image)
  set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,DATA_SEGMENT),(UC_X86_REG_ES,DATA_SEGMENT),(UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0xffe0),(UC_X86_REG_EFLAGS,2)))
  run_until(m,LOAD*16+entry,LOAD*16+0x9107,100)
  actual=struct.unpack('<HH',m.mem_read(0x40000+m.reg_read(UC_X86_REG_SP),4))
  if actual!=(caller,request):raise ValueError('source request differs')
  rows.append({'entry_ip':entry,'return_ip':caller,'request':request,'sample':f'pc_request_{request:02}'})
 return {'source_sha256':SIM_SHA256,'unpack':unpack,'scope':__doc__,'rows':rows}
if __name__=='__main__':
 import argparse
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();r=run();a.output.write_text(json.dumps(r,indent=2)+'\n');print('PC_REQUEST_SOUNDS: 7 original call blocks verified')
