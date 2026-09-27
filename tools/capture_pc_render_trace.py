#!/usr/bin/env python3
"""Capture actual original render passes with a separately pinned tracing core.

The native callback observes guest registers/RAM in-place and only copies data
out. The host never writes guest memory. Baseline mode checks the same source
build without hooks; both modes retain full-RAM/framebuffer hashes per frame.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256
    from tools.pc_live_state import SimStateReader
    from tools.verify_pc_bridge import STEPS
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256
    from pc_live_state import SimStateReader
    from verify_pc_bridge import STEPS

ROOT = Path(__file__).resolve().parents[1]

try:
    from tools.pc_render_trace import Collector
except ModuleNotFoundError:
    from pc_render_trace import Collector


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mode', choices=['trace','baseline','reference'], default='trace')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--frames', type=int, default=180)
    parser.add_argument('--profile', choices=['turn', 'controls'], default='turn')
    parser.add_argument('--state', type=Path, required=True)
    parser.add_argument('--state-core-sha256', help='defaults to the selected reference or source-baseline pin')
    args = parser.parse_args()
    if not 1 <= args.frames <= 3000: parser.error('frames must be 1..3000')
    if args.output.resolve().is_relative_to((ROOT / 'GAME').resolve()): parser.error('output must be outside original GAME')
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())
    if args.mode == 'reference':
        library, pin = ROOT / '.runtime/pc-core/dosbox_pure_libretro.dylib', CORE_SHA256
    else:
        library = ROOT / '.runtime/pc-core' / ('abrams-trace.dylib' if args.mode == 'trace' else 'source-baseline.dylib')
        pin = manifest[args.mode + '_sha256']
    source_pin = args.state_core_sha256 or (CORE_SHA256 if args.mode == 'reference' else manifest['baseline_sha256'])
    reader = SimStateReader(ROOT / 'GAME/SIM.EXE')
    collector = Collector(reader, args.output)
    core = PcReferenceCore(library, ROOT / '.runtime/pc-core/abrams-ref.zip', args.output / 'saves', expected_sha256=pin)
    frames = []
    try:
        core.run(240)
        core.restore(args.state, expected_source_sha256=source_pin)
        core.run(1)
        core.pause_at_frame_end()
        state = reader.read(core.conventional_memory())
        if state is None: raise ValueError('restored state lacks the fingerprinted original SIM')
        if args.mode == 'trace':
            collector.attach(core, state['load_segment'])
        presentations = []
        stages = {}
        if args.profile == 'controls':
            steps = STEPS + [('commander-key', 3, ['f2']), ('commander', 60, []),
                ('cupola-key', 3, ['f3']), ('cupola', 60, []), ('return-gunner-key', 3, ['f1']), ('return-gunner', 60, [])]
            inputs = [(name, keys, n == count - 1) for name, count, keys in steps for n in range(count)]
        else:
            inputs = [('turn', ['c'] if i < 3 else ['kp6'] if 30 <= i < 90 else [], i == args.frames - 1)
                      for i in range(args.frames)]
        for i, (stage, keys, end_stage) in enumerate(inputs):
            core.run(1, keys)
            if collector.error: raise collector.error
            if args.mode == 'trace':
                paired = collector.paired_video(core.last_video)
                presentations.append({k: v for k, v in paired.items() if k != 'draw_pass'} |
                    {'draw_sequence': paired['draw_pass']['sequence'] if paired.get('draw_pass') else None,
                     'latest_complete_sequence': collector.passes[-1]['sequence'] if collector.passes else None})
            frames.append({'index': i, 'keys': keys, 'ram_sha256': hashlib.sha256(core.last_video_ram).hexdigest(),
                'video_sha256': hashlib.sha256(core.last_video[0]).hexdigest()})
            if end_stage: stages[stage] = reader.read(core.last_video_ram)
        core.screenshot().save(args.output / 'last-frame.png')
        result = {'mode': args.mode, 'core_sha256': pin, 'source_commit': manifest['commit'], 'frames': frames,
            'state_sha256': hashlib.sha256(args.state.read_bytes()).hexdigest(),
            'state_core_sha256': source_pin, 'trace_header_sha256': manifest['trace_header_sha256'],
            'profile': args.profile, 'stages': stages,
            'original_vertices_checked': collector.vertices_checked,
            'presentations': presentations, 'render_passes': list(collector.passes), 'incomplete_pass_at_stop': collector.active is not None,
            'scope': 'actual original normal-core instruction hooks; no guest writes; compare baseline/reference hashes separately'}
        (args.output / 'report.json').write_text(json.dumps(result, indent=2) + '\n')
        print(json.dumps({'mode': args.mode, 'frames': len(frames), 'render_passes': len(collector.passes),
            'dynamic_contexts': sum(o['dynamic_instance'] for p in collector.passes for o in p['objects'])}))
    finally:
        core.pause_at_frame_end()
        if args.mode == 'trace': collector.detach(core)
        core.close()


if __name__ == '__main__': main()
