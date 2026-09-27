#!/usr/bin/env python3
"""Check bounded text capture parity and independently crop saved source frames."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
from PIL import Image


def verify(trace_path, baseline_path):
    trace=json.loads(trace_path.read_text());baseline=json.loads(baseline_path.read_text())
    rows=trace['presentations'];runs=[run for row in rows for run in row.get('text_runs',[])]
    counts=Counter((run['kind'],run['text']) for run in runs)
    stats=trace['text_observation']
    checks={
        'same_profile_and_start':trace['profile']==baseline['profile'] and
            trace['state_sha256']==baseline['state_sha256'] and
            trace['state_core_sha256']==baseline['state_core_sha256'],
        'full_RAM_video_inputs_identical':trace['frames']==baseline['frames'] and len(trace['frames'])>1000,
        'all_stage_states_identical':trace['stages']==baseline['stages'],
        'all_native_text_returns_match_source_glyphs':stats.get('entries',0)>0 and
            stats.get('entries')==stats.get('glyph_verified'),
        'no_unsupported_or_bad_glyph_entries':not any(stats.get(k,0) for k in
            ('unsupported_entries','unsupported_returns','glyph_mismatches')),
        'presented_evidence_accounted':len(runs)==stats.get('presented_runs'),
        'visibility_gate_exercised':stats.get('frame_mismatches',0)>0,
        'every_run_belongs_to_scanned_page':all(run['page_offset']==row['page_offset'] for row in rows for run in row.get('text_runs',[])),
    }
    readiness_delays=[]
    if trace['profile']=='audio':
        checks['three_original_weapon_labels_visible']=all(counts[('weapon_status',text)]>0 for text in ('READY ','TRACK ','LOAD  '))
        for event in trace['audio_events']:
            if event['kind']!='reload_complete': continue
            frame=event['frame_index']
            first=next((i for i in range(frame,len(rows)) if any(run['kind']=='weapon_status' and
                run['text']=='READY ' for run in rows[i].get('text_runs',[]))),None)
            readiness_delays.append({'completion_frame':frame,'first_visible_ready':first,
                                     'delay_frames':None if first is None else first-frame})
        checks['observed_reload_is_earlier_than_visible_readiness']=len(readiness_delays)==3 and all(
            item['delay_frames'] is not None and item['delay_frames']>0 for item in readiness_delays)
    if trace['profile']=='text':
        checks['original_empty_smoke_message_visible']=counts[('crew_primary','No smoke mortars left')]>0
        expiry=next(item for item in trace['ui_presentations'] if item['stage']=='crew-expired')
        checks['erased_message_not_exposed']=not any(run['kind'].startswith('crew_') for run in rows[expiry['frame_index']].get('text_runs',[]))
    captures=[]
    for sample in trace['ui_presentations']:
        source=trace_path.parent/sample['image']
        with Image.open(source) as image:
            image=image.convert('RGB')
            for run in rows[sample['frame_index']].get('text_runs',[]):
                x,y,w,h=run['rect'];actual=hashlib.sha256(image.crop((x,y,x+w,y+h)).tobytes()).hexdigest()
                captures.append({'image':sample['image'],'kind':run['kind'],'text':run['text'],
                                 'sha256':actual,'matches':actual==run['pixel_sha256']})
    checks['saved_source_crops_match_runtime_evidence']=all(c['matches'] for c in captures)
    if trace['profile']=='text': checks['saved_crew_crop_exercised']=any(c['kind']=='crew_primary' for c in captures)
    return {'checks':checks,'frames':len(trace['frames']),'text_observation':stats,
            'visible_runs':[{'kind':kind,'text':text,'frames':n} for (kind,text),n in sorted(counts.items())],
            'saved_crops':captures,'readiness_delays':readiness_delays,
            'inputs':[{'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
                      for path in (trace_path,baseline_path)],
            'scope':'bounded source-text visibility and unchanged guest RAM/video/input; no voice scheduling or complete dialogue claim'}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--trace',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    result=verify(args.trace,args.baseline)
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if not all(result['checks'].values()): raise SystemExit(1)


if __name__=='__main__': main()
