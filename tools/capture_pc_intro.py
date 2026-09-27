#!/usr/bin/env python3
"""Record every original intro frame, deduplicating only stored RGB images.

Keyboard input and full paired RAM/video hashes remain per-frame. No guest
memory writes, authored animation timer or changes to original reference files.
"""
import argparse
import hashlib
import json
from pathlib import Path

from tools.pc_reference_core import PcReferenceCore
from tools.pc_live_state import SimStateReader
from tools.pc_session import PresentationSession
from tools.inspect_scenarios import decode_resource

ROOT = Path(__file__).resolve().parents[1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--mode', choices=['baseline', 'trace'], required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--frames', type=int, default=2400)
    p.add_argument('--skip-after', type=int, help='press space for three frames at this recorded index')
    p.add_argument('--compare', type=Path)
    p.add_argument('--boot-state', type=Path, default=ROOT/'artifacts/pc-neutral-boot-01/neutral-boot/reference.state')
    args = p.parse_args()
    if not 3 <= args.frames <= 6000: p.error('frames must be 3..6000')
    if args.skip_after is not None and not 3 <= args.skip_after <= args.frames-3:
        p.error('skip must follow joystick selection and fit in recorded frames')
    if any(args.output.resolve().is_relative_to((ROOT/n).resolve()) for n in ['GAME', 'GENESIS']):
        p.error('output must be outside source directories')
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((ROOT/'.runtime/pc-core/abrams-trace.json').read_text())
    library = 'source-baseline.dylib' if args.mode == 'baseline' else 'abrams-trace.dylib'
    core = PcReferenceCore(ROOT/'.runtime/pc-core'/library, ROOT/'.runtime/pc-core/abrams-ref.zip',
                           args.output/'saves', expected_sha256=manifest[args.mode+'_sha256'])
    session = PresentationSession(core, SimStateReader(ROOT/'GAME/SIM.EXE'),
                                  decode_resource((ROOT/'GAME/SHAPE.TBL').read_bytes()), trace=args.mode=='trace')
    records, images = [], {}
    try:
        core.run(240)
        core.restore(args.boot_state, expected_source_sha256=manifest['baseline_sha256'])
        core.run(1)
        for index in range(args.frames):
            keys = ['return'] if index < 3 else ['space'] if args.skip_after is not None and args.skip_after <= index < args.skip_after+3 else []
            session.step(1, keys)
            picture = core.screenshot()
            rgb_hash = hashlib.sha256(picture.tobytes()).hexdigest()
            if rgb_hash not in images:
                name = f'frame-{index:04d}.png'
                picture.save(args.output/name)
                images[rgb_hash] = {'image': name, 'first_index': index, 'size': list(picture.size)}
            sample = session.sample()
            records.append({'index': index, 'frame': core.frame, 'keys': keys,
                            'ram_sha256': hashlib.sha256(core.last_video_ram).hexdigest(),
                            'video_sha256': hashlib.sha256(core.last_video[0]).hexdigest(),
                            'rgb_sha256': rgb_hash, 'program': sample['program']})
        checks = {'all_START': all(r['program'] and r['program']['name']=='START' for r in records),
                  'all_320x200': all(i['size']==[320,200] for i in images.values())}
        report = {'schema': 1, 'mode': args.mode, 'core_sha256': core.core_sha256,
                  'boot_state_sha256': hashlib.sha256(args.boot_state.read_bytes()).hexdigest(),
                  'frames': args.frames, 'skip_after': args.skip_after,
                  'records': records, 'images': images, 'transitions': session.transitions, 'checks': checks}
        if args.compare:
            other = json.loads(args.compare.read_text())
            checks['all_records_identical'] = records == other['records']
            checks['all_images_identical'] = images == other['images']
            checks['all_transitions_identical'] = session.transitions == other['transitions']
            report['comparison'] = str(args.compare)
        (args.output/'report.json').write_text(json.dumps(report, indent=2)+'\n')
        print(json.dumps({'frames': len(records), 'unique_images': len(images), 'checks': checks}, indent=2))
        if not all(checks.values()): raise SystemExit(1)
    finally:
        session.close()
        core.close()


if __name__ == '__main__': main()
