#!/usr/bin/env python3
"""Compare the bounded incoming-hit/damage route with the untouched original.

This fixture stops at first SIM exit. Its RAM-only snapshot does not establish
matching disk-dependent debrief outcomes or whole-game dialogue coverage.
"""
import argparse
import hashlib
import json
from pathlib import Path


def verify(trace,baseline):
    first={}
    for change in trace['changes']:
        for message in change['messages']:
            first.setdefault(message['id'],(change['frame_index'],message))
    barks=[e for e in trace['audio_events'] if e['kind']=='crew_visible']
    expected_ids=list(range(1,15))+[16,17]
    by_id={e['message_id']:e for e in barks}
    proof=all(e['message_id'] in first and
        first[e['message_id']][0]==e['frame_index'] and
        first[e['message_id']][1]['text']==e['text'] and
        first[e['message_id']][1]['parts']==e['parts'] and
        first[e['message_id']][1]['assignment_ip']==e['ip'] for e in barks)
    assignments=trace['message_epochs'][0]['assignments']
    checks={
        'same_snapshot':trace['state_sha256']==baseline['state_sha256'],
        'same_baseline_core':trace['state_core_sha256']==baseline['core_sha256'],
        'all_8576_inputs_RAM_video_and_queued_states_equal':len(trace['frames'])==8576 and trace['frames']==baseline['frames'],
        'same_final_state_and_program':trace['final_state']==baseline['final_state'] and trace['final_program']==baseline['final_program'],
        'one_SIM_message_epoch':len(trace['message_epochs'])==1,
        'all_17_original_assignments_observed':len(assignments)==17 and [m['id'] for m in assignments]==list(range(1,18)),
        '16_complete_visible_assignments':sorted(first)==expected_ids,
        'exactly_one_bark_per_visible_assignment':[e['message_id'] for e in barks]==expected_ids,
        '14_distinct_observed_voice_assets':len({e['voice'] for e in barks})==14,
        'each_bark_at_first_complete_pixel_verified_display':proof,
        'same_041_bearing_three_distinct_occurrences':all(by_id.get(i,{}).get('text')=="We've been hit! Bearing 041" for i in (2,3,4)),
        'unseen_COAX_destroyed_stays_silent':assignments[14]['parts'][-1]['text']==' destroyed' and 15 not in first and 15 not in by_id,
        'voice_only_original_gate_and_portrait':all(e['sample'] is None and e['speaker']==3 and e['enabled'] for e in barks),
        'radio_unobserved_and_unsounded':trace['message_epochs'][0]['counts'].get('radio',0)==0 and not any('radio' in e['voice'] and e['text']!='Radio Equipment damaged' for e in barks),
    }
    return {'checks':checks,'visible_barks':barks,'text_epochs':trace['text_epochs'],
            'scope':__doc__}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--trace',type=Path,required=True);p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    result=verify(json.loads(a.trace.read_text()),json.loads(a.baseline.read_text()))
    result['inputs']=[{'path':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in (a.trace,a.baseline)]
    a.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'checks':result['checks'],'text_epochs':result['text_epochs']},indent=2))
    if not all(result['checks'].values()):raise SystemExit(1)


if __name__=='__main__':main()
