#!/usr/bin/env python3
"""Capture paired original RAM/framebuffers across crew views, read-only."""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256
    from tools.pc_live_state import SimStateReader
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256
    from pc_live_state import SimStateReader

ROOT = Path(__file__).resolve().parents[1]
STAGES = [
    ("gunner-forward", [(30, [])]),
    ("gunner-turned", [(3, ["c"]), (30, []), (60, ["kp6"]), (60, []), (3, ["kp5"]), (60, [])]),
    ("commander", [(3, ["f2"]), (60, [])]),
    ("commander-left", [(3, ["z"]), (60, [])]),
    ("cupola", [(3, ["f3"]), (60, [])]),
    ("driver", [(3, ["f4"]), (60, [])]),
    ("driver-forward-input", [(60, ["kp8"]), (60, [])]),
    ("driver-stop-input", [(3, ["kp5"]), (240, [])]),
    ("gunner-restored", [(3, ["f1"]), (60, [])]),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to((ROOT / "GAME").resolve()):
        parser.error("output must be outside original GAME")
    args.output.mkdir(parents=True, exist_ok=False)
    reader = SimStateReader(ROOT / "GAME/SIM.EXE")
    state_path = ROOT / "reference/pc-live/mission-entry/reference.state"
    core = PcReferenceCore(ROOT / ".runtime/pc-core/dosbox_pure_libretro.dylib",
                           ROOT / ".runtime/pc-core/abrams-ref.zip", args.output / "saves")
    report = {"core_sha256": CORE_SHA256, "start_state_sha256": hashlib.sha256(state_path.read_bytes()).hexdigest(),
              "sampling": "paired VGA boundary, not proven atomic logic tick", "captures": []}
    try:
        core.run(240)
        core.restore(state_path)
        core.run(1)
        for name, steps in STAGES:
            for frames, keys in steps:
                core.run(frames, keys)
            ram = core.last_video_ram
            state = reader.read(ram)
            if not state or not state["camera"]:
                raise ValueError(f"coherent camera state unavailable at {name}")
            (args.output / (name + ".bin")).write_bytes(ram)
            core.screenshot().save(args.output / (name + ".png"))
            report["captures"].append({"name": name, "ram_sha256": hashlib.sha256(ram).hexdigest(), "state": state})
        (args.output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps({"captures": [{"name": c["name"], "station": c["state"]["station"],
                          "clip": c["state"]["camera"]["clip"], "mode": c["state"]["camera"]["matrix_mode"]}
                         for c in report["captures"]]}, indent=2))
    finally:
        core.close()


if __name__ == "__main__":
    main()
