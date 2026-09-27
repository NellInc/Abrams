#!/usr/bin/env python3
"""Cold-boot/quit/reentry trace and unmodified-core comparison, local only.

Runs the original menus, briefings and mission in their own disk overlay. It
does not restore RAM without its filesystem, author menu rules or write RAM.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
try:
    from tools.pc_reference_core import PcReferenceCore
    from tools.pc_live_state import SimStateReader, active_program
    from tools.pc_session import PresentationSession
    from tools.inspect_scenarios import decode_resource
    from tools.pc_render_trace import Collector
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore
    from pc_live_state import SimStateReader, active_program
    from pc_session import PresentationSession
    from inspect_scenarios import decode_resource
    from pc_render_trace import Collector

ROOT = Path(__file__).resolve().parents[1]


def steps():
    fixture = ROOT / 'godot/tests/fixtures'
    boot = json.loads((fixture / 'pc_boot_steps.json').read_text())
    return ([{'label': 'ready', 'frames': 1, 'keys': []}] +
            [{'label': f'boot-{i:02d}', 'frames': n, 'keys': keys} for i,(n,keys) in enumerate(boot)] +
            json.loads((fixture / 'pc_reentry_steps.json').read_text()))


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=['trace','baseline'], required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--compare', type=Path, help='other capture report, compared after this run')
    p.add_argument('--boot-state', type=Path, help='shared neutral START snapshot for byte-exact comparison')
    args = p.parse_args()
    if any(args.output.resolve().is_relative_to((ROOT / name).resolve()) for name in ('GAME','GENESIS')):
        p.error('output must be outside original source directories')
    args.output.mkdir(parents=True,exist_ok=False)
    manifest = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())
    library = 'abrams-trace.dylib' if args.mode == 'trace' else 'source-baseline.dylib'
    core = PcReferenceCore(ROOT / '.runtime/pc-core' / library, ROOT / '.runtime/pc-core/abrams-ref.zip',
                           args.output / 'saves', expected_sha256=manifest[args.mode+'_sha256'])
    collectors = []
    def factory(*args, **kwargs):
        collector = Collector(*args, **kwargs)
        collectors.append(collector)
        return collector
    session = PresentationSession(core,SimStateReader(ROOT/'GAME/SIM.EXE'),
                                  decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()),trace=args.mode=='trace',
                                  collector_factory=factory)
    records, samples = [], []
    try:
        core.run(240)  # Same original startup boundary as the live host.
        if args.boot_state:
            core.restore(args.boot_state,expected_source_sha256=manifest['baseline_sha256'])
            core.run(1)  # Native framebuffer priming after snapshot restore.
            program = active_program(core.conventional_memory())
            if not program or program['name'] != 'START': raise ValueError('comparison requires a neutral START snapshot')
        for step in steps():
            for _ in range(step['frames']):
                session.step(1,step['keys'])
                records.append({'frame':core.frame, 'keys':step['keys'],
                    'ram_sha256':hashlib.sha256(core.last_video_ram).hexdigest(),
                    'video_sha256':hashlib.sha256(core.last_video[0]).hexdigest()})
            sample = session.sample()
            sample["audio"] = session.drain_audio()
            filename = step['label']+'.png'
            core.screenshot().save(args.output/filename)
            samples.append(step | sample | {'frame':core.frame, 'image':filename})
        by_name = {sample['label']:sample for sample in samples}
        programs = [entry['program']['name'] if entry['program'] else None for entry in session.transitions]
        checks = {
            'program_lifecycle': programs == ['START','BRIEF','SIM','END','START','BRIEF','SIM'],
            'debrief_is_original_END': by_name['debrief']['program']['name']=='END',
            'menus_have_no_SIM_state_or_geometry': all(
                s['state'] is None and s['presentation'].get('draw_pass') is None
                for s in samples if not s['program'] or s['program']['name']!='SIM'),
            'second_mission_initialized': bool(by_name['second-mission']['state']) and
                by_name['second-mission']['state']['scenario_resource_index']==6,
        }
        if args.mode == 'trace':
            checks['fresh_second_render_epoch'] = by_name['second-mission']['render_epoch']==2
            checks['second_mission_paired'] = bool(by_name['second-mission']['presentation'].get('draw_pass'))
            checks['quit_dialog_fully_original'] = by_name['quit-dialog']['presentation'].get('ui_overlay',{}).get('ui_pixels')==64000
        report = {'mode':args.mode,'core_sha256':core.core_sha256,'source_commit':manifest['commit'],
            'initial_unrecorded_frames':240,'records':records,'samples':samples,
            'boot_state_sha256':hashlib.sha256(args.boot_state.read_bytes()).hexdigest() if args.boot_state else None,
            'restore_priming_frames':1 if args.boot_state else 0,
            'transitions':session.transitions,'checks':checks,
            'plate_epochs':[c.plates.report() for c in collectors],
            'scope':'bounded original cold-boot, quit and reentry; compare full paired RAM/video/input records separately'}
        if args.compare:
            other = json.loads(args.compare.read_text())
            mismatches = [i for i,(a,b) in enumerate(zip(records,other['records'])) if a!=b]
            comparable = lambda r: [{k:s[k] for k in ('label','frame','keys','program','state')} for s in r['samples']]
            checks['equal_frame_count'] = len(records)==len(other['records'])
            checks['all_RAM_video_and_inputs_identical'] = not mismatches
            checks['all_stage_states_identical'] = comparable(report)==comparable(other)
            checks['program_boundaries_identical'] = report['transitions']==other['transitions']
            report['comparison'] = {'path':str(args.compare),'core_sha256':other['core_sha256'],
                                    'mismatch_count':len(mismatches),'first_mismatches':mismatches[:20]}
        (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({'mode':args.mode,'frames':len(records),'stages':len(samples),'checks':checks},indent=2))
        if not all(checks.values()): raise SystemExit(1)
    finally:
        session.close()
        core.close()


if __name__ == '__main__': main()
