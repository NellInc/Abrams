#!/usr/bin/env python3
"""Execute original sound dispatch and bytecode interpreter in an isolated CPU.

Only call arguments, test driver selection, stack and interpreter's documented
channel-table context are supplied. No original instruction is replaced. This
does not run DOS, emulate an audio chip or establish historical pacing.
"""
import argparse
import json
import struct
from pathlib import Path
import unicorn
from unicorn.x86_const import UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_SI, UC_X86_REG_EFLAGS
try:
    from tools.pc_bearing_oracle import ROOT, LOAD, DATA_SEGMENT, RETURN_IP, SIM_SHA256, cpu, original_unpack, set_registers, run_until, sha256
    from tools.pc_audio_loops import read_loops, LAYOUTS
except ModuleNotFoundError:
    from pc_bearing_oracle import ROOT, LOAD, DATA_SEGMENT, RETURN_IP, SIM_SHA256, cpu, original_unpack, set_registers, run_until, sha256
    from pc_audio_loops import read_loops, LAYOUTS


def run():
    if unicorn.__version__ != '2.1.4': raise ValueError('pinned Unicorn 2.1.4 required')
    source = (ROOT/'GAME/SIM.EXE').read_bytes()
    if sha256(source) != SIM_SHA256: raise ValueError('unknown SIM executable')
    image, unpack_receipt = original_unpack(source)
    sound_segment = LOAD + 0x18B5
    sound = sound_segment*16
    cases = []
    for backend in (0,1):
        machine = cpu()
        machine.mem_write(LOAD*16,image)
        machine.mem_write(DATA_SEGMENT*16+0x35AC,bytes([backend]))
        table, _ = LAYOUTS[backend]
        # The original interrupt wrapper sets these before stepping channels.
        machine.mem_write(sound+0xF51,struct.pack('<H',table))
        machine.mem_write(sound+0xF53,struct.pack('<H',0x10F6 if backend==0 else 0x1290))
        machine.mem_write(sound+table,b'\0'*(48*4))
        def call(ip,arg=0,channel=None):
            ds = DATA_SEGMENT if channel is None else sound_segment
            set_registers(machine,((UC_X86_REG_CS,LOAD),(UC_X86_REG_DS,ds),(UC_X86_REG_ES,ds),
                (UC_X86_REG_SS,0x4000),(UC_X86_REG_SP,0xFFF0),(UC_X86_REG_EFLAGS,2),
                (UC_X86_REG_SI,table+(channel or 0)*48)))
            machine.mem_write(0x4FFF0,struct.pack('<HH',RETURN_IP,arg))
            run_until(machine,LOAD*16+ip,LOAD*16+RETURN_IP,10000)
            if machine.reg_read(UC_X86_REG_SP)!=0xFFF2: raise ValueError('unbalanced original sound stack')
        def tick():
            for channel in range(4):
                at=sound+table+channel*48
                if struct.unpack('<H',machine.mem_read(at,2))[0]: call(0x8F33,channel=channel)
        def observe(): return read_loops(bytes(machine.mem_read(0,640*1024)),LOAD*16,backend)
        rows=[]
        def stage(label,command,ticks,parameter=None):
            if command is not None: call(0x9107,command)
            if parameter is not None: call(0x91D6,parameter)
            for index in range(ticks):
                tick()
                rows.append({'stage':label,'tick':index,'loops':observe()})
        stage('stopped',0,2)
        stage('engine_idle',4,250,0)
        stage('engine_fast',None,250,9)
        stage('turret_start',5,180)
        stage('turret_release',12,180)
        stage('engine_stop',13,2)
        # Other channel users must never masquerade as either loop.
        for event in (1,2,3,6,7,8,9,10,11,14,15,16): stage('other-'+str(event),event,240)
        by=lambda label:[r['loops'] for r in rows if r['stage']==label]
        checks={
            'stopped_has_no_loops':all(not x['engine']['active'] and not x['turret']['active'] for x in by('stopped')),
            'engine_loops':all(x['engine']['active'] for x in by('engine_idle')),
            'parameter_reaches_original_tone':by('engine_fast')[-1]['engine']['period'] < by('engine_idle')[-1]['engine']['period'],
            'turret_starts':all(x['turret']['active'] for x in by('turret_start')),
            'turret_decelerates_then_stops':any(x['turret']['active'] for x in by('turret_release')) and not by('turret_release')[-1]['turret']['active'],
            'engine_stop':not by('engine_stop')[-1]['engine']['active'],
            'other_sounds_never_claim_loops':all(not x['engine']['active'] and not x['turret']['active']
                for r in rows if r['stage'].startswith('other-') for x in [r['loops']]),
        }
        cases.append({'backend':backend,'checks':checks,'rows':rows})
    return {'source_sha256':SIM_SHA256,'engine':'unicorn-2.1.4/x86-16','unpack':unpack_receipt,
            'cases':cases,'scope':'original sound routines, isolated supplied channel context; no live writes, chip recording or timing claim'}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    result=run();args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'cases':[{'backend':c['backend'],'ticks':len(c['rows']),'checks':c['checks']} for c in result['cases']]},indent=2))
    if not all(v for c in result['cases'] for v in c['checks'].values()): raise SystemExit(1)


if __name__=='__main__': main()
