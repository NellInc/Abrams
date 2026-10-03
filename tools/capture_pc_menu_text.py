#!/usr/bin/env python3
"""Capture original frontend text and compare an ordinary-key route to baseline."""
import argparse
import hashlib
import json
import sys
from pathlib import Path
ROOT_FOR_IMPORT = Path(__file__).resolve().parents[1]
if str(ROOT_FOR_IMPORT) not in sys.path: sys.path.insert(0, str(ROOT_FOR_IMPORT))
from tools.pc_reference_core import PcReferenceCore
from tools.pc_live_state import SimStateReader
from tools.pc_session import PresentationSession
from tools.inspect_scenarios import decode_resource
from tools.capture_pc_session import information_steps,steps
from tools.source_guard import inside_source
ROOT=Path(__file__).resolve().parents[1]

def menu_steps():
    route=[{'label':'joystick','frames':1,'keys':[]}]
    def press(name,key):
        route.extend([{'label':name+'-press','frames':10,'keys':[key]},
                      {'label':name,'frames':90,'keys':[]}])
    press('joystick-yes','up');press('joystick-no','down')
    boot=json.loads((ROOT/'godot/tests/fixtures/pc_boot_steps.json').read_text())
    route.extend({'label':f'boot-{i:02d}','frames':n,'keys':k} for i,(n,k) in enumerate(boot[:10]))
    press('scenario','return')
    for name,key in [('skill-select','up'),('skill-next','right'),('skill-restore','left'),
                     ('time-select','up'),('time-next','right'),('time-restore','left'),('mission-select','up')]:press(name,key)
    for i in range(8):press('mission-'+str(i),'right')
    press('scenario-close','escape');press('campaign-select','right');press('campaign-menu','return')
    press('campaign-name-open','return')
    for i,key in enumerate(['n','e','l','l','backspace','l']):press('name-'+str(i),key)
    press('name-cancel','escape');press('campaign-close','escape')
    press('information-select','right');press('information-menu','return')
    press('information-close','escape');press('exit-select','right');press('exit-dialog','return')
    return route

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode',choices=['trace','baseline'],required=True)
    parser.add_argument('--route',choices=['menus','information','lifecycle'],default='menus')
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--compare',type=Path)
    args=parser.parse_args()
    if inside_source(args.output):parser.error('output must be outside original sources')
    args.output.mkdir(parents=True,exist_ok=False)
    manifest=json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    library='abrams-trace.dylib' if args.mode=='trace' else 'source-baseline.dylib'
    core=PcReferenceCore(ROOT/'.runtime/pc-core'/library,ROOT/'.runtime/pc-core/abrams-ref.zip',args.output/'saves',expected_sha256=manifest[args.mode+'_sha256'])
    session=PresentationSession(core,SimStateReader(ROOT/'GAME/SIM.EXE'),decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()),trace=args.mode=='trace')
    records=[];samples=[]
    try:
        # Arm before EXEC/unpacking to observe the first joystick prompt.
        session.step(240)
        core.screenshot().save(args.output/'cold-boot.png')
        cold=session.sample()
        # Shared neutral guest state removes independent-cold-boot RAM noise.
        # Preexisting candidates may survive only by exact current RGB matching.
        core.restore(ROOT/'artifacts/pc-neutral-boot-01/neutral-boot/reference.state',expected_source_sha256=manifest['baseline_sha256'])
        session.step(1)
        route=menu_steps() if args.route=='menus' else information_steps() if args.route=='information' else steps()
        for step in route:
            for _ in range(step['frames']):
                session.step(1,step['keys'])
                records.append({'frame':core.frame,'keys':step['keys'],'ram':hashlib.sha256(core.last_video_ram).hexdigest(),'video':hashlib.sha256(core.last_video[0]).hexdigest()})
            sample=session.sample();session.drain_audio()
            image=core.screenshot();image.save(args.output/(step['label']+'.png'))
            samples.append(step|sample|{'image':step['label']+'.png','frame_size':list(image.size)})
        checks={'game_frames_320x200':all(s['frame_size']==[320,200] for s in samples if not s['label'].startswith('exit-dialog')),
                'original_programs':all(s['program'] and s['program']['name'] in ['START','BRIEF','SIM','END'] for s in samples if not s['label'].startswith('exit-dialog'))}
        if args.route=='menus':checks['original_exit_reached']=samples[-1]['program'] is None
        if args.compare:
            other=json.loads(args.compare.read_text())
            checks['same_record_count']=len(records)==len(other['records'])
            mismatches=[i for i,(a,b) in enumerate(zip(records,other['records'])) if a!=b]
            checks['identical_original_RAM_video_inputs']=not mismatches
            checks['identical_programs']= [s['program'] for s in samples]==[s['program'] for s in other['samples']]
            print('MISMATCHES',len(mismatches),mismatches[:10])
        report={'mode':args.mode,'route':args.route,'core_sha256':core.core_sha256,'checks':checks,
                'records':records,'samples':samples,'cold_boot':cold}
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'checks':checks,'frames':len(records),'samples':len(samples),
              'cold_text':[r['text'] for r in cold['presentation'].get('text_runs',[])],
              'texts':{s['label']:[r['text'] for r in s['presentation'].get('text_runs',[])] for s in samples if not s['label'].endswith('-press')}},indent=2))
        if not all(checks.values()):raise SystemExit(1)
    finally:session.close();core.close()
if __name__=='__main__':main()
