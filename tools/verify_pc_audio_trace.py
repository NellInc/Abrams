#!/usr/bin/env python3
"""Verify bounded original audio requests, silent shots and read-only parity."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
try:
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]
CORE_MANIFEST = ROOT / '.runtime/pc-core/abrams-trace.json'


def load_manifest(path=CORE_MANIFEST):
    """The pinned core receipt, or {} so every pin check fails rather than raises."""
    path = Path(path)
    return json.loads(path.read_text()) if path.is_file() else {}


def check_core_pins(trace, baseline, manifest, require_header=True):
    """Read-only parity is evidence only for a trace run against a distinct, pinned baseline core.

    Self-comparison (the same report twice, or two trace-core runs) must fail. Only the trace
    run's header is compared with the receipt: the baseline core has no trace header, so a
    reused baseline stays valid while baseline_sha256 is unchanged. capture_pc_render_trace has
    always recorded the header, so it is required unless the caller (dialogue captures made
    before capture_pc_dialogue recorded it) opts out; a recorded header is always compared.
    """
    trace_core, baseline_core = trace.get('core_sha256'), baseline.get('core_sha256')
    checks = {
        'modes_trace_and_baseline': trace.get('mode') == 'trace' and baseline.get('mode') == 'baseline',
        'core_pins_distinct_and_match_receipt': bool(manifest) and trace_core != baseline_core and
            trace_core == manifest.get('trace_sha256') and baseline_core == manifest.get('baseline_sha256'),
    }
    if require_header or 'trace_header_sha256' in trace:
        checks['trace_header_matches_receipt'] = bool(manifest.get('trace_header_sha256')) and \
            trace.get('trace_header_sha256') == manifest['trace_header_sha256']
    return checks


def verify(trace, baseline, manifest=None, legacy_no_loop_states=False):
    manifest = load_manifest() if manifest is None else manifest
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
        **check_core_pins(trace, baseline, manifest),
    }
    audio_states = trace.get('audio_states') or []
    # Loop-channel parity fails closed: absent states or a renamed stage is a failure,
    # never a vacuous all() over nothing. Pre-loop-state reports need the explicit flag.
    if not legacy_no_loop_states:
        checks['audio_states_present'] = bool(audio_states) and bool(baseline.get('audio_states'))
    if audio_states or not legacy_no_loop_states:
        stages = lambda name: [r for r in audio_states if r['stage'] == name]
        held = lambda name, test: bool(stages(name)) and all(test(r) for r in stages(name))
        stopped = stages('turret-stopped')
        checks.update({
            'original_sound_channel_states_identical': audio_states == baseline.get('audio_states'),
            'engine_idle_channel_present': held('baseline', lambda r: r['loops']['engine']['active']),
            'engine_tone_changes_with_original_program': len({r['loops']['engine']['period'] for r in audio_states}) > 1,
            'turret_persists_on_key_release': held('turn-coast', lambda r: r['loops']['turret']['active']),
            'turret_original_deceleration_tail': any(r['loops']['turret']['active'] for r in stopped) and
                bool(stopped) and not stopped[-1]['loops']['turret']['active'],
            'mute_and_pause_preserve_silent_engine_state': held('muted', lambda r: r['loops']['engine']['active'] and not r['enabled']) and
                held('paused', lambda r: r['loops']['engine']['active'] and not r['enabled']),
        })
    return {'checks':checks,'frames':len(trace['frames']),'events':len(events),
            'sample_request_counts':dict(counts),'core_sha256':trace['core_sha256'],
            'baseline_sha256':baseline['core_sha256'], 'state_sha256':trace['state_sha256']}


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--trace',type=Path,required=True)
    p.add_argument('--baseline',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--manifest',type=Path,default=CORE_MANIFEST)
    p.add_argument('--legacy-no-loop-states',action='store_true',
                   help='accept a report captured before original loop-channel states were recorded')
    args=p.parse_args()
    if inside_source(args.output,ROOT): p.error('output must be outside original sources')
    result=verify(json.loads(args.trace.read_text()),json.loads(args.baseline.read_text()),
                  load_manifest(args.manifest),args.legacy_no_loop_states)
    result['inputs']=[{'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
                      for path in (args.trace,args.baseline)]
    args.output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
    if not all(result['checks'].values()): raise SystemExit(1)


if __name__=='__main__': main()
