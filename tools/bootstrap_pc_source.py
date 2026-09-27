#!/usr/bin/env python3
"""Replay the observed source-build boot path into the original Mossel scenario.

All actions are original keyboard input. Source content stays in its read-only
ZIP; filesystem changes go to the output's save overlay. This is a local fixture
builder, not a replacement menu flow or a gameplay parity claim.
"""
from __future__ import annotations
import argparse
import json
from pathlib import Path
try:
    from tools.pc_reference_core import PcReferenceCore
    from tools.pc_live_state import SimStateReader
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore
    from pc_live_state import SimStateReader

ROOT = Path(__file__).resolve().parents[1]
# Preserve the actual observed probe sequence, including ineffective credit-skip
# attempts. Optimizing its timing would require a new reference comparison.
STEPS = [(3,['return']), (720,[]), (3,['escape']), (180,[]), (3,['space']),
         (300,[]), (60,['return']), (120,[]), (300,[]), (3,['return']), (30,[]),
         (3,['return']), (300,[]), (3,['space']), (240,[]), (3,['space']), (180,[]),
         (3,['space']), (180,[]), (3,['space']), (180,[]), (180,[]),
         (3,['return']), (360,[])]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    for name in ('GAME', 'GENESIS'):
        if args.output.resolve().is_relative_to((ROOT / name).resolve()): parser.error('output must be outside proprietary source directories')
    args.output.mkdir(parents=True, exist_ok=False)
    manifest = json.loads((ROOT / '.runtime/pc-core/abrams-trace.json').read_text())
    core = PcReferenceCore(ROOT / '.runtime/pc-core/source-baseline.dylib', ROOT / '.runtime/pc-core/abrams-ref.zip',
                           args.output / 'saves', expected_sha256=manifest['baseline_sha256'])
    try:
        core.run(240)
        for frames, keys in STEPS: core.run(frames, keys)
        state = SimStateReader(ROOT / 'GAME/SIM.EXE').read(core.conventional_memory())
        if (state is None or state['scenario_resource_index'] != 6 or state['station'] != 'gunner'
                or state['world_position_raw'] != [79872,141312,50]
                or state['ammunition'] != {'COAX':80,'HEAT':10,'SABOT':6,'AX':18}):
            core.screenshot().save(args.output / 'unexpected-screen.png')
            raise ValueError('original boot path did not reach the observed mission-entry contract')
        core.dump(args.output / 'mission-entry')
        (args.output / 'steps.json').write_text(json.dumps({'initial_frames': 240, 'steps': STEPS}, indent=2) + '\n')
        print('PC_SOURCE_BOOT: original Mossel/day/novice default entry, 3600 frames, source-pinned save state')
    finally:
        core.close()


if __name__ == '__main__': main()
