#!/usr/bin/env python3
"""Execute remaining original crew routing/assignment paths in isolated Unicorn.

Source scenario bytes and original class pointer table are supplied as caller
memory. No instruction patched. Proves caption/portrait/setter, not live branch
eligibility, timing or visibility. No original assets leave the local machine.
"""
import argparse,json,struct
from pathlib import Path
import unicorn
from unicorn.x86_const import UC_X86_REG_CS,UC_X86_REG_DS,UC_X86_REG_ES,UC_X86_REG_SS,UC_X86_REG_SP,UC_X86_REG_EFLAGS
try:
    from tools.pc_bearing_oracle import ROOT,LOAD,DATA_SEGMENT,RETURN_IP,SIM_SHA256,cpu,original_unpack,set_registers,run_until,sha256
    from tools.inspect_scenarios import decode_resource,parse_scenario
except ModuleNotFoundError:
    from pc_bearing_oracle import ROOT,LOAD,DATA_SEGMENT,RETURN_IP,SIM_SHA256,cpu,original_unpack,set_registers,run_until,sha256
    from inspect_scenarios import decode_resource,parse_scenario


def run():
    if unicorn.__version__!='2.1.4':raise ValueError('pinned Unicorn required')
    source=(ROOT/'GAME/SIM.EXE').read_bytes()
    if sha256(source)!=SIM_SHA256:raise ValueError('unknown SIM')
    image,unpack=original_unpack(source);ds=DATA_SEGMENT*16;rows=[]
    def machine():
        m=cpu();m.mem_write(LOAD*16,image);m.mem_write(ds+0x58ee,b'\0\0');return m
    def finish(m,entry,arg,expected_ip,expected_caption=None,end=RETURN_IP):
        set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,DATA_SEGMENT),(UC_X86_REG_ES,DATA_SEGMENT),
            (UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0xffe0),(UC_X86_REG_EFLAGS,2)))
        m.mem_write(0x4ffe0,struct.pack('<HH',RETURN_IP,arg));seen=[]
        m.hook_add(unicorn.UC_HOOK_CODE,lambda _m,a,_s,_d: seen.append(a-LOAD*16) if a-LOAD*16 in (0x3d0c,0x3d8e,0x3dd2) else None)
        run_until(m,LOAD*16+entry,LOAD*16+end,10000)
        pointers=[struct.unpack('<H',m.mem_read(ds+p,2))[0] for p in (0x94c,0x646a)]
        pointers=[p for p in pointers if p];parts=[]
        for p in pointers:
            raw=bytes(m.mem_read(ds+p,256));parts.append(raw[:raw.index(0)].decode('ascii'))
        caption=''.join(parts)
        if seen!=[expected_ip] or (expected_caption is not None and caption!=expected_caption):raise ValueError('source assignment mismatch')
        return {'assignment_ip':expected_ip,'speaker':bytes(m.mem_read(ds+0x6464,1))[0],
            'pointers':pointers,'parts':parts,'caption':caption}
    for scenario in range(8):
        name=f'SNARIO{scenario}.SSS';raw=(ROOT/'GAME'/name).read_bytes();decoded=decode_resource(raw);parsed=parse_scenario(decoded)
        start=parsed['message_directory_offset']+2;count=len(parsed['messages']);strings=start+count*3+2
        for message in parsed['messages']:
            if message['flag_byte']==4:continue
            m=machine();m.mem_write(ds+0xa000,decoded[start:start+count*3]);m.mem_write(ds+0xb000,decoded[strings:parsed['unparsed_tail_offset']])
            m.mem_write(ds+0x8660,struct.pack('<H',0xa000));m.mem_write(ds+0x7994,struct.pack('<H',0xb000))
            row=finish(m,0x3c46,message['index'],0x3d8e,message['text'])
            if row['speaker']!=message['flag_byte'] or len(row['parts'])!=1:raise ValueError('scenario identity mismatch')
            rows.append({'family':'mission','resource':name,'resource_sha256':sha256(raw),'index':message['index'],**row})
    # Original startup builds these 31 pointers from its 30-byte class records.
    for index in range(31):
        m=machine();m.mem_write(ds+0x8654,struct.pack('<H',0xa000));m.mem_write(ds+0xa000,struct.pack('<31H',*(0x510+i*30 for i in range(31))))
        rows.append({'family':'destroyed','class_index':index,**finish(m,0x3ce0,index,0x3d0c)})
    for speed in range(3):
        m=machine();m.mem_write(ds+0xa02,struct.pack('<H',speed))
        rows.append({'family':'speed','speed_index':speed,**finish(m,0x4bee,0,0x3dd2,end=0x4c03)})
    return {'schema':1,'source_sha256':SIM_SHA256,'unpack':unpack,'scope':__doc__,'rows':rows}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--check-fixture',type=Path);a=p.parse_args();r=run()
    if a.check_fixture and json.loads(a.check_fixture.read_text())!=r:raise ValueError('fixture mismatch')
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(r,indent=2)+'\n');print(f"REMAINING_VOICE: {len(r['rows'])} original assignments")
if __name__=='__main__':main()
