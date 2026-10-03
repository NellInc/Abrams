#!/usr/bin/env python3
"""Read-only replay of original Shift+3 speed control and ordinary ammunition 3.

Original SIM 0000:4bd8 compares ASCII #, cycles DS:0a02 through 0..2, and
uses that value as a loop bound at 4c1b. This probe only reads that state.
"""
import argparse,hashlib,json,struct
from pathlib import Path
try:
    from tools.pc_reference_core import PcReferenceCore
    from tools.pc_live_state import SimStateReader
    from tools.pc_session import PresentationSession
    from tools.inspect_scenarios import decode_resource
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_reference_core import PcReferenceCore
    from pc_live_state import SimStateReader
    from pc_session import PresentationSession
    from inspect_scenarios import decode_resource
    from source_guard import inside_source
ROOT=Path(__file__).resolve().parents[1]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode',choices=['baseline','trace'],required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--compare',type=Path);args=p.parse_args()
    if inside_source(args.output,ROOT,('GAME','GENESIS')):
        p.error('output must be outside original source directories')
    args.output.mkdir(parents=True,exist_ok=False)
    manifest=json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    lib='source-baseline.dylib' if args.mode=='baseline' else 'abrams-trace.dylib'
    core=PcReferenceCore(ROOT/'.runtime/pc-core'/lib,ROOT/'.runtime/pc-core/abrams-ref.zip',args.output/'saves',expected_sha256=manifest[args.mode+'_sha256'])
    reader=SimStateReader(ROOT/'GAME/SIM.EXE')
    session=PresentationSession(core,reader,decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()),trace=args.mode=='trace')
    records=[];stages=[]
    route=[('initial',30,[]),('plain-three',10,['3']),('plain-three-settled',90,[]),
           ('heat',10,['1']),('heat-settled',90,[])]
    for i in range(3):route += [(f'shift-three-{i}',10,['shift','3']),(f'shift-three-{i}-settled',90,[])]
    try:
        core.run(240);core.restore(ROOT/'artifacts/pc-source-boot-01/mission-entry/reference.state',expected_source_sha256=manifest['baseline_sha256']);core.run(1)
        for label,frames,keys in route:
            for _ in range(frames):
                session.step(1,keys)
                records.append({'frame':core.frame,'keys':keys,'ram_sha256':hashlib.sha256(core.last_video_ram).hexdigest(),'video_sha256':hashlib.sha256(core.last_video[0]).hexdigest()})
            state=reader.read(core.last_video_ram)
            speed=struct.unpack_from('<H',core.last_video_ram,state['load_segment']*16+0x19e00+0xa02)[0]
            stages.append({'label':label,'speed_index':speed,'weapon':state['selected_weapon']})
            core.screenshot().save(args.output/(label+'.png'))
        by={s['label']:s for s in stages};initial=by['initial']['speed_index']
        checks={'plain_three_selects_AX':by['plain-three-settled']['weapon']=='AX',
                'plain_three_keeps_system_speed':by['plain-three-settled']['speed_index']==initial,
                'one_restores_HEAT':by['heat-settled']['weapon']=='HEAT'}
        for i in range(3):
            s=by[f'shift-three-{i}-settled'];checks[f'shift_three_cycles_speed_{i}']=s['speed_index']==(initial+i+1)%3
            checks[f'original_shift_three_also_selects_AX_{i}']=s['weapon']=='AX'
        if args.compare:
            other=json.loads(args.compare.read_text());checks['all_source_RAM_video_keys_equal']=records==other['records'];checks['original_results_equal']=stages==other['stages']
        report={'checks':checks,'records':records,'stages':stages,'core_sha256':core.core_sha256,'scope':__doc__}
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'checks':checks,'stages':stages},indent=2))
        if not all(checks.values()):raise SystemExit(1)
    finally:session.close();core.close()


if __name__=='__main__':main()
