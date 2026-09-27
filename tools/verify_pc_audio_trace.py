#!/usr/bin/env python3
"""Verify bounded original audio requests, silent shots and read-only parity."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path


def verify(trace, baseline):
    events = trace['audio_events']
    sounds = [e for e in events if e['kind'] == 'sound']
    cannon = [e for e in sounds if e.get('sample') == 'cannon']
    counts = Counter(e.get('sample') or 'unmapped' for e in sounds)
    gates = [e for e in events if e['kind'] == 'gate']
    base = trace['stages']['baseline']['ammunition']
    final = trace['stages']['audible-fire']['ammunition']
    checks = {
        'same_comparison_start': trace['state_sha256'] == baseline['state_sha256'] and
            trace['state_core_sha256'] == baseline['state_core_sha256'],
        'same_audio_input_profile': trace['profile'] == baseline['profile'] == 'audio',
        'all_RAM_video_inputs_identical': trace['frames'] == baseline['frames'] and len(trace['frames']) > 2000,
        'all_stage_states_identical': trace['stages'] == baseline['stages'],
        'three_accepted_cannon_requests': len(cannon) == 3 and counts['machinegun'] == counts['smoke'] == 1,
        'original_consumed_ammunition': final['HEAT'] == base['HEAT']-3 and
            final['COAX'] == base['COAX']-1 and final['SABOT'] == base['SABOT'] and final['AX'] == base['AX'],
        'F5_and_pause_gates': [(e['return_ip'],e['enabled']) for e in gates] ==
            [(0x1E7B,False),(0x1E7B,True),(0x4080,False),(0x4092,True)],
        'muted_shot_still_executed_without_audio': [e['enabled'] for e in cannon] == [True,False,True],
        'three_original_reload_completions': sum(e['kind']=='reload_complete' for e in events) == 3,
        'rejected_repeat_shot_no_extra_request': not any(e['stage']=='rejected-fire-key' and
            e.get('sample')=='cannon' for e in events) and
            trace['stages']['rejected-fire-key']['ammunition']['HEAT'] == final['HEAT'],
        'only_context_correct_voices': all(e.get('voice') in (None,'on_the_way','smoke') for e in events),
        'event_frame_order': all(a['frame_index']<=b['frame_index'] for a,b in zip(events,events[1:])),
    }
    audio_states = trace.get('audio_states', [])
    if audio_states:
        stages = lambda name: [r for r in audio_states if r['stage'] == name]
        checks.update({
            'original_sound_channel_states_identical': audio_states == baseline.get('audio_states'),
            'engine_idle_channel_present': all(r['loops']['engine']['active'] for r in stages('baseline')),
            'engine_tone_changes_with_original_program': len({r['loops']['engine']['period'] for r in audio_states}) > 1,
            'turret_persists_on_key_release': all(r['loops']['turret']['active'] for r in stages('turn-coast')),
            'turret_original_deceleration_tail': any(r['loops']['turret']['active'] for r in stages('turret-stopped')) and
                not stages('turret-stopped')[-1]['loops']['turret']['active'],
            'mute_and_pause_preserve_silent_engine_state': all(r['loops']['engine']['active'] and not r['enabled']
                for r in stages('muted') + stages('paused')),
        })
    return {'checks':checks,'frames':len(trace['frames']),'events':len(events),
            'sample_request_counts':dict(counts),'core_sha256':trace['core_sha256'],
            'baseline_sha256':baseline['core_sha256'], 'state_sha256':trace['state_sha256']}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--trace',type=Path,required=True)
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    args=p.parse_args()
    result=verify(json.loads(args.trace.read_text()),json.loads(args.baseline.read_text()))
    result['inputs']=[{'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
                      for path in (args.trace,args.baseline)]
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if not all(result['checks'].values()): raise SystemExit(1)


if __name__=='__main__': main()
