#!/usr/bin/env python3
"""Capture actual original render passes with a separately pinned tracing core.

The native callback observes guest registers/RAM in-place and only copies data
out. The host never writes guest memory. Baseline mode checks the same source
build without hooks; both modes retain full-RAM/framebuffer hashes per frame.
"""
from __future__ import annotations
import argparse
import base64
import hashlib
import json
from pathlib import Path

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256
    from tools.pc_live_state import SimStateReader, active_program
    from tools.pc_audio_events import audio_status
    from tools.verify_pc_bridge import STEPS
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256
    from pc_live_state import SimStateReader, active_program
    from pc_audio_events import audio_status
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
    parser.add_argument('--profile', choices=['turn', 'controls', 'plates', 'audio'], default='turn')
    parser.add_argument('--state', type=Path, required=True)
    parser.add_argument('--state-core-sha256', help='defaults to the selected reference or source-baseline pin')
    parser.add_argument('--capture-sprites', action='store_true', help='save first paired framebuffer for each observed effect image')
    parser.add_argument('--capture-ui', action='store_true', help='save paired source/UI masks at end-of-stage samples')
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
    frames, audio_events, audio_states = [], [], []
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
        sprite_presentations, captured_sprites, ui_presentations = [], set(), []
        stages = {}
        if args.profile in ('controls', 'plates', 'audio'):
            steps = STEPS + [('commander-key', 3, ['f2']), ('commander', 60, [])]
            if args.profile == 'plates':
                steps += [('damage-key', 3, ['d']), ('damage', 120, []),
                          ('damage-close-key', 3, ['space']), ('damage-closed', 60, [])]
            steps += [('cupola-key', 3, ['f3']), ('cupola', 60, []),
                      ('return-gunner-key', 3, ['f1']), ('return-gunner', 240 if args.profile == 'plates' else 60, [])]
            if args.profile == 'audio':
                steps += [('machinegun-key', 3, ['m']), ('machinegun', 60, []),
                          ('smoke-key', 3, ['s']), ('smoke', 60, []),
                          ('mute-key', 3, ['f5']), ('muted', 30, []),
                          ('muted-fire-key', 3, ['space']), ('muted-fire', 300, []),
                          ('unmute-key', 3, ['f5']), ('unmuted', 30, []),
                          ('pause-key', 3, ['escape']), ('paused', 60, []),
                          ('resume-key', 3, ['space']), ('resumed', 60, []),
                          ('audible-fire-key', 3, ['space']), ('audible-fire-wait', 15, []),
                          ('rejected-fire-key', 3, ['space']), ('audible-fire', 282, [])]
            inputs = [(name, keys, n == count - 1) for name, count, keys in steps for n in range(count)]
        else:
            inputs = [('turn', ['c'] if i < 3 else ['kp6'] if 30 <= i < 90 else [], i == args.frames - 1)
                      for i in range(args.frames)]
        for i, (stage, keys, end_stage) in enumerate(inputs):
            captured_sprite = False
            core.run(1, keys)
            if collector.error: raise collector.error
            audio_events.extend(e | {"frame_index": i, "stage": stage} for e in collector.audio.drain())
            if args.mode == 'trace':
                paired = collector.paired_video(core.last_video)
                metadata = {k: v for k, v in paired.items() if k not in ('draw_pass', 'ui_overlay', 'plate_overlay')}
                metadata['ui_overlay'] = {k:v for k,v in (paired.get('ui_overlay') or {}).items() if k != 'mask_png'}
                metadata['plate_overlay'] = {k:v for k,v in (paired.get('plate_overlay') or {}).items() if k != 'mask_png'}
                presentations.append(metadata |
                    {'draw_sequence': paired['draw_pass']['sequence'] if paired.get('draw_pass') else None,
                     'latest_complete_sequence': collector.passes[-1]['sequence'] if collector.passes else None})
                if args.capture_sprites and paired.get('draw_pass'):
                    drawing = paired['draw_pass']
                    ids = {o['sprite']['index'] for o in drawing['objects'] if o.get('sprite')}
                    if ids - captured_sprites:
                        filename = f'sprite-pass-{drawing["sequence"]:05d}-frame-{i:05d}.png'
                        core.screenshot().save(args.output / filename)
                        sprite_presentations.append({'draw_sequence': drawing['sequence'], 'frame_index': i,
                            'bitmap_indices': sorted(ids), 'image': filename})
                        captured_sprites.update(ids)
                        captured_sprite = True
                if args.capture_ui and (end_stage or captured_sprite) and paired.get('draw_pass') and paired.get('ui_overlay'):
                    ui_stage = stage if end_stage else f'sprite-{drawing["sequence"]}'
                    filename = f'ui-{ui_stage}-frame-{i:05d}'
                    core.screenshot().save(args.output / (filename + '.png'))
                    (args.output / (filename + '-mask.png')).write_bytes(base64.b64decode(paired['ui_overlay']['mask_png']))
                    plate_mask = None
                    if paired.get('plate_overlay'):
                        plate_mask = filename + '-plate.png'
                        (args.output / plate_mask).write_bytes(base64.b64decode(paired['plate_overlay']['mask_png']))
                    ui_presentations.append({'stage': ui_stage, 'draw_sequence': paired['draw_pass']['sequence'],
                        'frame_index': i, 'image': filename + '.png', 'mask': filename + '-mask.png', 'plate_mask':plate_mask})
            if args.profile == 'audio':
                current_ram = core.conventional_memory()
                audio_states.append({'frame_index':i, 'stage':stage,
                                     **audio_status(current_ram,active_program(current_ram))})
            frames.append({'index': i, 'keys': keys, 'ram_sha256': hashlib.sha256(core.last_video_ram).hexdigest(),
                'video_sha256': hashlib.sha256(core.last_video[0]).hexdigest()})
            if end_stage: stages[stage] = reader.read(core.last_video_ram)
        core.screenshot().save(args.output / 'last-frame.png')
        result = {'mode': args.mode, 'core_sha256': pin, 'source_commit': manifest['commit'], 'frames': frames,
            'state_sha256': hashlib.sha256(args.state.read_bytes()).hexdigest(),
            'state_core_sha256': source_pin, 'trace_header_sha256': manifest['trace_header_sha256'],
            'profile': args.profile, 'stages': stages, 'audio_events': audio_events, 'audio_states': audio_states,
            'original_vertices_checked': collector.vertices_checked,
            'effect_pixels_checked': collector.effect_pixels_checked,
            'plate_loads': collector.plates.report(),
            'sprite_presentations': sprite_presentations,
            'ui_presentations': ui_presentations,
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
