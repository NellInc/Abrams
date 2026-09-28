#!/usr/bin/env python3
"""Execute original radio selection, equipment gating and retrieval in isolation.

Scenario directory/string bytes are taken unchanged from the supplied resources
and placed in caller-provided isolated memory. Original instructions execute;
backend 2 avoids host sound devices. This proves selected message routing, not
mission trigger eligibility, visibility, timing or live occurrence.
"""
import argparse
import json
import struct
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
    if sha256(source)!=SIM_SHA256:raise ValueError('unknown original SIM')
    image,unpacked=original_unpack(source);ds=DATA_SEGMENT*16;rows=[];resources={}

    def machine(health):
        m=cpu();m.mem_write(LOAD*16,image)
        for at,value in ((0x58ee,0),(0x94e,0),(0x6468,0),(0x6466,0)):
            m.mem_write(ds+at,struct.pack('<H',value))
        m.mem_write(ds+0x950,b'\0');m.mem_write(ds+0xca6,bytes([health]))
        m.mem_write(ds+0x35ac,b'\x02')
        return m

    def call(m,ip,arg=None):
        set_registers(m,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,DATA_SEGMENT),
            (UC_X86_REG_ES,DATA_SEGMENT),(UC_X86_REG_SS,0x4000),
            (UC_X86_REG_SP,0xffe0),(UC_X86_REG_EFLAGS,2)))
        m.mem_write(0x4ffe0,struct.pack('<H',RETURN_IP)+(struct.pack('<H',arg) if arg is not None else b''))
        run_until(m,LOAD*16+ip,LOAD*16+RETURN_IP,10000)
        if m.reg_read(UC_X86_REG_SP)!=0xffe2:raise ValueError('original radio stack imbalance')

    def observe(m):
        events=[]
        def hook(mm,address,_size,_user):
            ip=address-LOAD*16
            if ip in (0x3c90,0x3cd4,0x3f73):events.append({'ip':ip})
            if ip==0x9107:
                sp=mm.reg_read(UC_X86_REG_SP)
                caller,value=struct.unpack('<HH',mm.mem_read(0x40000+sp,4))
                events.append({'ip':ip,'caller':caller,'value':value})
        m.hook_add(unicorn.UC_HOOK_CODE,hook)
        return events

    def finish(m,events,health,expected_pointer,entry):
        pointer=struct.unpack('<H',m.mem_read(ds+0x94e,2))[0]
        queued=health!=2
        if pointer!=(expected_pointer if queued else 0):raise ValueError('original radio equipment gate differs')
        countdown=struct.unpack('<H',m.mem_read(ds+0x6468,2))[0]
        if countdown!=(15 if queued else 0):raise ValueError('original pending-radio countdown differs')
        expected_events=[{'ip':entry},{'ip':0x9107,'caller':0x3c97 if entry==0x3c90 else 0x3cdb,'value':11}] if queued else []
        if events!=expected_events:raise ValueError('unexpected original assignment/notification')
        before=list(events);call(m,0x3f62)
        opened=bytes(m.mem_read(ds+0x950,1))[0]
        if opened!=int(queued):raise ValueError('original retrieve-radio gate differs')
        if events!=before+([{'ip':0x3f73}] if queued else []):raise ValueError('unexpected original retrieval identity')
        if struct.unpack('<H',m.mem_read(ds+0x6466,2))[0]!=(3 if queued else 0):raise ValueError('original open-radio countdown differs')
        return {'health':health,'queued':queued,'assignment_ip':entry if queued else None,
            'pointer':pointer,'queue_countdown':countdown,'retrieved':bool(opened),'events':events}

    for scenario in range(8):
        name=f'SNARIO{scenario}.SSS';raw=(ROOT/'GAME'/name).read_bytes();decoded=decode_resource(raw);parsed=parse_scenario(decoded)
        start=parsed['message_directory_offset']+2;count=len(parsed['messages']);strings=start+count*3+2
        directory=decoded[start:start+count*3];text=decoded[strings:parsed['unparsed_tail_offset']]
        resources[name]={'sha256':sha256(raw),'directory_sha256':sha256(directory),'strings_sha256':sha256(text)}
        for message in parsed['messages']:
            if message['flag_byte']!=4:continue
            relative=message['offset']-strings
            for health in range(3):
                m=machine(health);events=observe(m)
                m.mem_write(ds+0xa000,directory);m.mem_write(ds+0xb000,text)
                m.mem_write(ds+0x8660,struct.pack('<H',0xa000));m.mem_write(ds+0x7994,struct.pack('<H',0xb000))
                call(m,0x3c46,message['index'])
                row=finish(m,events,health,0xb000+relative,0x3c90)
                rows.append({'resource':name,'index':message['index'],'caption':message['text'],
                    'relative_pointer':relative,**row})
    for pointer in (0x211,0x23d):
        end=image.index(0,0x19e00+pointer);caption=image[0x19e00+pointer:end].decode('ascii')
        for health in range(3):
            m=machine(health);events=observe(m);call(m,0x3cb2,pointer)
            rows.append({'resource':'SIM.EXE','caption':caption,**finish(m,events,health,pointer,0x3cd4)})
    m=machine(0);events=observe(m);call(m,0x3c46,65535)
    if events or struct.unpack('<H',m.mem_read(ds+0x94e,2))[0]:raise ValueError('original no-message sentinel queued radio')
    return {'source_sha256':SIM_SHA256,'unpack':unpacked,'engine':'unicorn-2.1.4/x86-16',
        'resources':resources,'rows':rows,'no_message_sentinel':'silent','scope':__doc__}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--check-fixture',type=Path);a=p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ('GAME','GENESIS')):p.error('output must be outside original files')
    result=run()
    if a.check_fixture and json.loads(a.check_fixture.read_text())!=result:raise ValueError('original radio fixture differs')
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(result,indent=2)+'\n')
    print('PC_RADIO_ORACLE: 30 original selection/equipment/retrieval cases and no-message sentinel')

if __name__=='__main__':main()
