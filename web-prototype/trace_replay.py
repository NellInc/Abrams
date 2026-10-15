#!/usr/bin/env python3
"""Replay local WebAssembly observer packets through the desktop collector.

The test supplies original-derived bytes on stdin. Never write or print them.
This checks the packet boundary, not a browser Python runtime or live claim hook.
"""
from __future__ import annotations

import base64
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.pc_live_state import SimStateReader
from tools.pc_render_trace import Collector
from tools.pc_trace_windows import build_window_bundles


def core_window_bundles() -> bool:
    """SIM event packet format of the generated Web core under test."""
    return build_window_bundles(json.loads((ROOT / "web-prototype/.generated/build-info.json").read_text()))


def replay(packet: bytes, collector: Collector) -> int:
    cursor = count = 0
    while cursor < len(packet):
        if len(packet) - cursor < 36:
            raise ValueError("truncated browser observer header")
        event, offset, length = struct.unpack_from("<III", packet, cursor)
        registers = struct.unpack_from("<12H", packet, cursor + 12)
        cursor += 36
        if length > len(packet) - cursor:
            raise ValueError("truncated browser observer data")
        collector.observe_packet(event, registers, packet[cursor:cursor + length], offset)
        if collector.error:
            raise collector.error
        cursor += length
        count += 1
    return count


def replay_to_summary(value: dict) -> dict:
    collector = Collector(SimStateReader(ROOT / "GAME/SIM.EXE"), history_limit=2,
                          window_bundles=core_window_bundles())
    count = sum(replay(base64.b64decode(raw, validate=True), collector)
                for raw in value["packets"])
    video = base64.b64decode(value["video"], validate=True)
    frame = collector.paired_video((video, value["width"], value["height"], value["pitch"]))
    drawing = frame.get("draw_pass")
    if not drawing or not drawing["objects"]:
        raise ValueError("browser trace did not reconstruct a desktop draw pass")
    return {"events": count, "draw_pass": True,
            "objects": len(drawing["objects"]),
            "text_runs": len(frame.get("text_runs", [])),
            "ui_overlay": bool(frame.get("ui_overlay"))}


def main() -> None:
    print(json.dumps(replay_to_summary(json.load(sys.stdin))))


if __name__ == "__main__":
    main()
