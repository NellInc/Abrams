#!/usr/bin/env python3
"""Replay bounded controls against the original executable, twice, read-only.

Local proof for the pinned emulator/backend only. This does not establish DOSBox-X
timing equivalence, mission outcomes, or the finished remaster's gameplay parity.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256
    from tools.pc_live_state import SimStateReader, SIM_SHA256
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256
    from pc_live_state import SimStateReader, SIM_SHA256

ROOT = Path(__file__).resolve().parents[1]
STEPS = [
    ("baseline", 30, []),
    ("driver-key", 3, ["f4"]), ("driver", 30, []),
    ("forward-key", 60, ["kp8"]), ("forward-coast", 60, []),
    ("stop-key", 3, ["kp5"]), ("stopped", 240, []),
    ("gunner-key", 3, ["f1"]), ("gunner", 30, []),
    ("control-key", 3, ["c"]), ("control", 30, []),
    ("turn-key", 60, ["kp6"]), ("turn-coast", 60, []),
    ("stop-turn-key", 3, ["kp5"]), ("turret-stopped", 60, []),
    ("fire-key", 3, ["space"]), ("after-fire", 300, []),
]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--state", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--core", type=Path, default=ROOT / ".runtime/pc-core/dosbox_pure_libretro.dylib")
    p.add_argument("--content", type=Path, default=ROOT / ".runtime/pc-core/abrams-ref.zip")
    args = p.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    reader = SimStateReader(ROOT / "GAME/SIM.EXE")
    core = PcReferenceCore(args.core, args.content, args.output / "saves")
    traces, stages = [], []
    try:
        core.run(240)
        for take in range(2):
            core.restore(args.state)
            # The native framebuffer cache is not restored. Advance one explicit
            # neutral frame before comparing video; RAM was already identical.
            core.run(1)
            trace, stage_states = [], {}
            directory = args.output / f"take-{take + 1}"
            directory.mkdir()
            for name, frames, keys in STEPS:
                for _ in range(frames):
                    core.run(1, keys)
                    ram = core.last_video_ram
                    state = reader.read(ram)
                    if state is None:
                        raise RuntimeError(f"SIM mapping unavailable during {name}")
                    trace.append({"index": len(trace), "keys": keys, "state": state,
                                  "ram_sha256": hashlib.sha256(ram).hexdigest(),
                                  "video_sha256": hashlib.sha256(core.last_video[0]).hexdigest()})
                stage_states[name] = trace[-1]["state"]
                if not keys:
                    core.screenshot().save(directory / f"{name}.png")
            (directory / "trace.json").write_text(json.dumps(trace, indent=2) + "\n")
            traces.append(trace)
            stages.append(stage_states)
        mismatches = [i for i, (a, b) in enumerate(zip(*traces)) if a != b]
        s = stages[0]
        checks = {
            "equal_replays_including_RAM_and_video": not mismatches,
            "driver_station": s["driver"]["station"] == "driver",
            "gunner_station": s["gunner"]["station"] == "gunner",
            "original_moves_player": s["forward-coast"]["position_raw"][:2] != s["baseline"]["position_raw"][:2],
            "keypad_stop": s["stopped"]["speed_raw"] == 0,
            "original_rotates_turret": s["turret-stopped"]["turret_relative_u8"] != s["gunner"]["turret_relative_u8"],
            "original_consumes_one_HEAT": s["after-fire"]["ammunition"]["HEAT"] == s["baseline"]["ammunition"]["HEAT"] - 1,
            "other_ammunition_unchanged": all(s["after-fire"]["ammunition"][k] == s["baseline"]["ammunition"][k] for k in ("COAX", "SABOT", "AX")),
        }
        report = {"core_sha256": CORE_SHA256, "sim_sha256": SIM_SHA256,
                  "initial_state_sha256": hashlib.sha256(args.state.read_bytes()).hexdigest(),
                  "content_sha256": hashlib.sha256(args.content.read_bytes()).hexdigest(),
                  "neutral_video_priming_frames_after_restore": 1,
                  "frames_per_take": len(traces[0]), "checks": checks,
                  "mismatch_count": len(mismatches), "first_mismatches": mismatches[:20],
                  "stages": stages}
        (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({k: v for k, v in report.items() if k != "stages"}, indent=2))
        if not all(checks.values()):
            raise SystemExit(1)
    finally:
        core.close()


if __name__ == "__main__":
    main()
