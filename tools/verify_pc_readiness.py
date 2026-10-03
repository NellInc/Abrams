#!/usr/bin/env python3
"""Verify original reload-to-visible-READY delay and unchanged trace parity."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path
try:
    from tools.pc_readiness import ReadinessBark
    from tools.verify_pc_audio_trace import verify as verify_audio
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_readiness import ReadinessBark
    from verify_pc_audio_trace import verify as verify_audio


def verify(trace,baseline):
    result=verify_audio(trace,baseline)
    groups=defaultdict(list)
    for event in trace['audio_events']: groups[event['frame_index']].append(event)
    gate=ReadinessBark();barks=[]
    if len(trace['presentations'])!=len(trace['audio_states']): raise ValueError('unpaired readiness states')
    for i,(view,status) in enumerate(zip(trace['presentations'],trace['audio_states'])):
        if status['frame_index']!=i: raise ValueError('misordered readiness state')
        barks.extend(event | {'frame_index':i} for event in gate.advance(i,groups[i],view,status))
    result['checks'].update({
        'three_once_only_visible_readiness_events':len(barks)==3,
        'only_loaded_voice_without_effect':all(e['voice']=='loaded' and e['sample'] is None for e in barks),
        'original_muted_load_stays_silent':[e['enabled'] for e in barks]==[True,False,True],
        'all_wait_three_frames_for_original_READY':all(e['frame_index']-e['completion_frame']==3 for e in barks),
        'strictly_newer_original_text_draw':all(e['text_draw_sequence']>e['text_sequence'] for e in barks),
    })
    result['readiness_events']=barks
    result['scope']='bounded original reload and visible READY custody; performance playback verified separately in native Godot'
    return result


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--trace',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    result=verify(json.loads(args.trace.read_text()),json.loads(args.baseline.read_text()))
    result['inputs']=[{'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
                      for path in (args.trace,args.baseline)]
    args.output.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    if not all(result['checks'].values()): raise SystemExit(1)


if __name__=='__main__': main()
