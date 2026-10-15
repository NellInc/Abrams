#!/usr/bin/env python3
"""Stream WebAssembly frontend callback packets through the desktop observer.

Original-derived data arrives only on stdin and is never printed or persisted.
This is an offline transport check, not a browser presentation path.
"""
from __future__ import annotations

import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.pc_frontend_text import FrontendText

SOURCE = sys.stdin.buffer
# Mirrors kTraceLimit in core_frontend.cpp and browser_observer.MAX_PACKET.
MAX_PACKET = 64 * 1024 * 1024


def read_exact(length: int) -> bytes:
    data = SOURCE.read(length)
    if len(data) != length:
        raise ValueError("truncated original frontend stream")
    return data


def replay(packet: bytes, observer: FrontendText) -> int:
    cursor = count = 0
    while cursor < len(packet):
        if len(packet) - cursor < 36:
            raise ValueError("truncated frontend event header")
        event, offset, length = struct.unpack_from("<III", packet, cursor)
        registers = struct.unpack_from("<12H", packet, cursor + 12)
        cursor += 36
        if length > len(packet) - cursor:
            raise ValueError("truncated frontend event data")
        observer.observe_packet(event, registers, packet[cursor:cursor + length], offset)
        if observer.error:
            raise observer.error
        cursor += length
        count += 1
    return count


def main() -> None:
    observer = FrontendText()
    frames = events = 0
    while True:
        length, = struct.unpack("<I", read_exact(4))
        if length == 0xFFFFFFFF:
            break
        if length > MAX_PACKET:
            raise ValueError("frontend packet exceeds native trace bound")
        events += replay(read_exact(length), observer)
        frames += 1
    width, height, pitch, size = struct.unpack("<4I", read_exact(16))
    if (width, height) != (320, 200) or pitch != width * 4 or size != pitch * height:
        raise ValueError("unsupported frontend video dimensions")
    video = read_exact(size)
    ram = read_exact(640 * 1024)
    if SOURCE.read(1):
        raise ValueError("trailing frontend stream data")
    presentation = observer.paired_video((video, width, height, pitch), ram)
    program = (presentation.get("frontend_program") or {}).get("name")
    print(json.dumps({"frames": frames, "events": events, "program": program,
                      "text_runs": len(presentation.get("text_runs", [])),
                      "draw_pass": bool(presentation.get("draw_pass")),
                      "ui_overlay": bool(presentation.get("ui_overlay"))}))
    if program != "START" or not presentation.get("ui_overlay"):
        raise ValueError("browser trace did not reconstruct original START presentation")


if __name__ == "__main__":
    main()
