#!/usr/bin/env python3
"""Record normal original-PC inputs and a real checkpoint into replay packets."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--drive-checkpoint',action='store_true');p.add_argument('--showcase',action='store_true');a=p.parse_args()
    out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    source=ROOT/'artifacts/pc-source-boot-01/mission-entry/reference.state'
    fingerprints={str(f.relative_to(ROOT)):hashlib.sha256(f.read_bytes()).hexdigest() for f in [source,ROOT/'godot/scripts/pc_bridge_viewer.gd',ROOT/'.runtime/pc-core/abrams-trace.dylib']}
    with (out/'host.log').open('w') as log:
        host=subprocess.Popen([sys.executable,str(ROOT/'tools/pc_bridge_host.py'),'--backend','trace','--state',str(source),'--saves',str(out/'saves'),'--frame-audit'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True)
        counter=0
        def read():
            line=host.stdout.readline()
            if not line:raise RuntimeError('Original host exited without response; see host.log')
            value=json.loads(line)
            if value['type']=='error':raise RuntimeError(value['message'])
            return value
        def request(op,**kw):
            nonlocal counter
            counter+=1;host.stdin.write(json.dumps({'op':op,'id':counter,**kw})+'\n');host.stdin.flush();value=read()
            assert value['id']==counter
            return value
        ready=read();assert ready['state'] and ready['program']['name']=='SIM'
        records=[];events=[];native_index=0;checkpoints=[]
        def shot(name,steps):
            nonlocal native_index
            path=out/(name+'.jsonl');count=0
            with path.open('w') as f:
                for n,keys in steps:
                    for _ in range(n):
                        packet=request('step',frames=2,keys=keys);native_index+=2
                        packet['promo_native_index']=native_index;packet['promo_keys']=keys
                        f.write(json.dumps(packet,separators=(',',':'))+'\n');count+=1
                        for event in (packet.get('audio') or {}).get('events',[]):events.append({'shot':name,'frame':count-1,'event':event})
            records.append({'name':name,'packets':path.name,'frames':count,'fps':30,'duration':count/30,'native_frames_per_output':2,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
            print('CAPTURE',name,count,flush=True)
        try:
            # Ordinary station changes, turret inputs, smoke and original firing.
            if a.showcase:
                shot('stations',[(2,['f2']),(58,[]),(2,['f3']),(58,[]),(2,['f4']),(58,[]),(2,['f1']),(58,[])])
                shot('clear-fire',[(114,[]),(2,['space']),(124,[])])
            elif a.drive_checkpoint:
                # Proven original vehicle-approach route uses arrows here.
                shot('terrain',[(2,['f4']),(20,[]),(25,['right']),(110,['up']),(2,['kp5']),(51,[])])
            else:
                shot('horizon',[(2,['f1']),(40,[]),(2,['c']),(45,['right']),(2,['kp5']),(59,[])])
                shot('terrain',[(2,['f4']),(20,[]),(55,['kp8']),(90,[]),(2,['kp5']),(41,[])])
                shot('smoke-fire',[(2,['f1']),(30,[]),(2,['s']),(80,[]),(2,['space']),(94,[])])
                shot('stations',[(2,['f2']),(58,[]),(2,['f3']),(58,[]),(2,['f4']),(58,[]),(2,['f1']),(58,[])])
            if not a.showcase:
                saved=request('save_state',slot=1);assert saved['success'];checkpoints.append(saved)
                shot('checkpoint-away',[(60,['up'] if a.drive_checkpoint else ['kp8']),(28,[]),(2,['kp5'])])
                restored=request('load_state',slot=1);assert restored['success'];checkpoints.append(restored)
                # Both packets are the worker's held local-checkpoint frame; equality
                # shows slot identity and no display advance, not a fresh audit.
                # Native integrity is the host restore_local conventional-RAM sha256.
                for result in (saved,restored):
                    assert result['restored'].get('held_frame') is True and result['restored'].get('startup')=='local-checkpoint',result['restored'].get('startup')
                assert restored['restored']['frame_audit']==saved['restored']['frame_audit']
                with (out/'checkpoint-return.jsonl').open('w') as f:
                    packet=restored['restored'];f.write(json.dumps(packet,separators=(',',':'))+'\n')
                    for _ in range(89):
                        step=request('step',frames=2,keys=[]);assert not step.get('held_frame'),'Post-restore step did not produce a fresh frame audit'
                        f.write(json.dumps(step,separators=(',',':'))+'\n')
                path=out/'checkpoint-return.jsonl';records.append({'name':'checkpoint-return','packets':path.name,'frames':90,'fps':30,'duration':3,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
                print('CAPTURE checkpoint-return 90',flush=True)
        finally:
            if host.poll() is None:host.stdin.write('{"op":"quit"}\n');host.stdin.flush()
            code=host.wait();host.stdin.close();host.stdout.close()
            if code:raise RuntimeError('Original host returned '+str(code))
    (out/'recording.json').write_text(json.dumps({'clips':records,'audio_events':events,'checkpoint_results':checkpoints,'source_fingerprints':fingerprints,'scope':'Original SIM execution via trace bridge, ordinary keyboard inputs only. Real slot 1 save/load; isolated profile. Output samples two native frames apart at 30 fps.'},indent=2)+'\n')
    print('CAPTURE_COMPLETE',out,flush=True)

if __name__=='__main__':main()
