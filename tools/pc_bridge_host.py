#!/usr/bin/env python3
"""Local stdin/stdout research bridge. PC code owns all gameplay decisions.

Only bounded keyboard steps and graceful shutdown are accepted. No sockets,
original memory writes, replacement combat simulation or mixed audio capture.
"""
from __future__ import annotations

import argparse
import base64
import io
import json
import os
from pathlib import Path
import sys
import struct

try:
    from tools.pc_reference_core import PcReferenceCore, CORE_SHA256, KEYS
    from tools.pc_live_state import SimStateReader
    from tools.inspect_scenarios import decode_resource
    from tools.inspect_shapes import inspect_shapes, primitive_vertices
except ModuleNotFoundError:
    from pc_reference_core import PcReferenceCore, CORE_SHA256, KEYS
    from pc_live_state import SimStateReader
    from inspect_scenarios import decode_resource
    from inspect_shapes import inspect_shapes, primitive_vertices

ROOT = Path(__file__).resolve().parents[1]


def validate_command(command):
    if not isinstance(command, dict) or command.get("op") not in ("step", "quit"):
        raise ValueError("expected step or quit")
    if command["op"] == "quit":
        if set(command) != {"op"}:
            raise ValueError("unexpected quit fields")
        return
    if set(command) != {"op", "id", "frames", "keys"}:
        raise ValueError("unexpected step fields")
    if type(command["id"]) is not int or command["id"] < 0:
        raise ValueError("nonnegative request id required")
    if type(command["frames"]) is not int or not 1 <= command["frames"] <= 600:
        raise ValueError("step must contain 1 to 600 frames")
    keys = command["keys"]
    if (not isinstance(keys, list) or len(keys) > 16
            or any(not isinstance(k, str) or k not in KEYS for k in keys)
            or len(keys) != len(set(keys))):
        raise ValueError("invalid keyboard set")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--state", type=Path, required=True)
    p.add_argument("--saves", type=Path, required=True)
    p.add_argument("--core", type=Path, default=ROOT / ".runtime/pc-core/dosbox_pure_libretro.dylib")
    p.add_argument("--content", type=Path, default=ROOT / ".runtime/pc-core/abrams-ref.zip")
    args = p.parse_args()
    # Core printf/log output must never corrupt the JSON channel.
    output = os.fdopen(os.dup(sys.stdout.fileno()), "w", buffering=1)
    os.dup2(sys.stderr.fileno(), sys.stdout.fileno())
    reader = SimStateReader(ROOT / "GAME/SIM.EXE")
    core = None

    def send(message):
        output.write(json.dumps(message, separators=(",", ":")) + "\n")

    try:
        core = PcReferenceCore(args.core, args.content, args.saves)
        core.run(240)
        core.restore(args.state)
        core.run(1)  # documented stale-native-framebuffer priming step
        core.run(1)  # first paired state/video sample
        sequence = 0

        def packet(kind, request_id):
            state = reader.read(core.last_video_ram)
            image = io.BytesIO()
            core.screenshot().save(image, format="PNG")
            return {"type": kind, "id": request_id, "sequence": sequence,
                    "state": state, "png": base64.b64encode(image.getvalue()).decode("ascii"),
                    "fps": core.pause_at_frame_end().timing.fps}

        ready = packet("ready", -1)
        ready.update({"protocol": 1, "core_sha256": CORE_SHA256,
                      "startup_frames_after_restore": 2,
                      "sampling": "paired completed VGA boundary; original drawing may lag simulation"})
        shape_bytes = decode_resource((ROOT / "GAME/SHAPE.TBL").read_bytes())
        if ready["state"] is None:
            raise ValueError("SIM not initialized for original shape extraction")
        ds = ready["state"]["load_segment"] * 16 + 0x19E00
        offset, segment = struct.unpack_from("<HH", core.last_video_ram, ds + 0x6D50)
        address = segment * 16 + offset
        if core.last_video_ram[address:address + len(shape_bytes)] != shape_bytes:
            raise ValueError("supplied SHAPE.TBL does not match the running original")
        shapes = inspect_shapes(shape_bytes)
        # Local research geometry only. All primitive lists are included, so
        # this is explicitly a wire survey, not a visibility/LOD-correct view.
        ready["static_wire_geometry"] = {
            str(shape["index"]): [primitive_vertices(shape, p) for p in shape["primitives"]]
            for shape in shapes["shapes"][:127]}
        send(ready)
        while True:
            line = sys.stdin.readline(8193)
            if not line:
                break
            if len(line) > 8192:
                raise ValueError("oversized bridge command")
            command = json.loads(line)
            validate_command(command)
            if command["op"] == "quit":
                break
            core.run(command["frames"], command["keys"])
            sequence += command["frames"]
            send(packet("sample", command["id"]))
    except BrokenPipeError:
        pass  # parent closed its pipe; shut down only our own core
    except Exception as error:
        send({"type": "error", "message": str(error)})
        raise
    finally:
        if core:
            core.close()
        output.close()


if __name__ == "__main__":
    main()
