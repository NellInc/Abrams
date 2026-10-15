#!/usr/bin/env python3
"""Read a small, evidenced subset of the original SIM's conventional RAM.

No writes, inferred damage model, enemy simulation or world-unit conversion.
Anchors are derived locally from the user's fingerprinted executable.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
import struct

try:
    from tools.unpack_pc_executables import unpack
    from tools.pc_world import world_position, window_origin, read_objects
    from tools.pc_render_state import read_camera
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from unpack_pc_executables import unpack
    from pc_world import world_position, window_origin, read_objects
    from pc_render_state import read_camera

SIM_SHA256 = "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"


def active_program(ram: bytes) -> dict | None:
    """Pinned DOSBox Pure SDA/MCB observation, not an executable-byte search.

    dos_inc.h places SDA at 00b2:0000 and current PSP at offset 10h. The
    preceding allocated MCB supplies its owner and eight-byte program name.
    This avoids treating freed but still resident SIM code as an active game.
    """
    if len(ram) != 640 * 1024: raise ValueError('expected physical conventional RAM')
    psp, = struct.unpack_from('<H',ram,0xB30)
    at = (psp-1)*16
    if psp < 1 or at+16+256 > len(ram): return None
    if ram[at] not in (ord('M'),ord('Z')) or struct.unpack_from('<H',ram,at+1)[0] != psp:
        return None
    if ram[psp*16:psp*16+2] != b'\xcd\x20': return None
    raw = ram[at+8:at+16].split(b'\0',1)[0].rstrip(b' ')
    if not raw or any(v < 32 or v > 126 for v in raw): return None
    return {'name': raw.decode('ascii'), 'psp': psp, 'load_segment': psp+16,
            'basis': 'pinned DOSBox Pure active PSP and allocated MCB'}


def bearing(angle: int) -> int:
    return (360 - ((angle & 255) * 360 >> 8)) % 360


class SimStateReader:
    def __init__(self, executable: Path):
        source = executable.read_bytes()
        if hashlib.sha256(source).hexdigest() != SIM_SHA256:
            raise ValueError("unsupported PC executable; offsets must be verified per version")
        decoded, _ = unpack(source)
        self.loop_end_instructions = decoded[0x0E54:0x0E87]
        # These instruction spans have no relocations and no mutable globals.
        self.anchors = [(offset, decoded[offset:offset + length]) for offset, length
                        in ((0x56EA, 62), (0x6790, 24), (0x91F8, 10))]
        self._located_ram = None
        self._located_base = None

    def locate(self, ram: bytes) -> int | None:
        if len(ram) != 640 * 1024:
            raise ValueError("expected the physical 640 KiB conventional-memory image")
        # A received bytes object is an immutable snapshot. sample() and read()
        # ask about that exact object twice; retain only that completed result.
        # Different snapshots (even equal bytes), mutable buffers and subclasses
        # still perform the complete scan and ambiguous-image check.
        if type(ram) is bytes and ram is self._located_ram:
            return self._located_base
        result = self._locate_snapshot(ram)
        if type(ram) is bytes:
            self._located_ram, self._located_base = ram, result
        return result

    def _locate_snapshot(self, ram: bytes) -> int | None:
        offset, anchor = self.anchors[0]
        candidates, at = [], ram.find(anchor)
        while at >= 0:
            base = at - offset
            if (base >= 0 and base % 16 == 0 and base + 0x19E00 + 65536 <= len(ram)
                    and all(ram[base + o:base + o + len(a)] == a for o, a in self.anchors)):
                candidates.append(base)
            at = ram.find(anchor, at + 1)
        if len(candidates) > 1:
            raise ValueError("ambiguous SIM load image")
        return candidates[0] if candidates else None

    def read_loop_end(self, ram: bytes, registers, ip: int) -> dict | None:
        """Validate the diagnostic boundary independently of video attribution."""
        program = active_program(ram)
        base = self.locate(ram)
        if (ip != 0x0E85 or len(registers) != 12 or not program or program['name'] != 'SIM'
                or base != program['load_segment'] * 16
                or registers[8] != program['load_segment']
                or registers[9] != program['load_segment'] + 0x19E0):
            raise ValueError('loop diagnostic requires active fingerprinted SIM at 0000:0e85')
        relocated = bytearray(self.loop_end_instructions)
        for offset in (0x0E6C, 0x0E80):
            value = struct.unpack_from('<H', relocated, offset - 0x0E54)[0]
            struct.pack_into('<H', relocated, offset - 0x0E54,
                             (value + program['load_segment']) & 65535)
        if ram[base + 0x0E54:base + 0x0E87] != relocated:
            raise ValueError('original SIM loop diagnostic instructions differ')
        return self.read(ram)

    def read(self, ram: bytes) -> dict | None:
        base = self.locate(ram)
        if base is None:
            return None
        ds = base + 0x19E00

        def word(offset, signed=False):
            return struct.unpack_from("<h" if signed else "<H", ram, ds + offset)[0]

        body, turret = word(0x799B), word(0x7999)
        if not 0 < body <= 65536 - 42 or not 0 < turret <= 65536 - 16:
            return None  # SIM may be resident but still initializing.
        hull_angle, turret_angle = ram[ds + body + 26], ram[ds + turret + 11]
        station, weapon = ram[ds + 0x799D], ram[ds + 0x79A9]
        if station > 3 or weapon not in (0, 1, 2, 255):
            return None
        speed_raw = word(body + 36, signed=True)
        local_position = [word(body + delta, signed=True) for delta in (4, 6, 8)]
        origin = window_origin(ram, ds)
        objects = read_objects(ram, ds)
        return {
            "schema": 2, "basis": "original-PC-SIM-read-only",
            "load_segment": base // 16,
            "scenario_resource_index": ram[ds + 0x8D74],
            "station": ("gunner", "commander", "cupola", "driver")[station],
            "position_raw": local_position,
            "world_position_raw": world_position(local_position, origin),
            "world": objects,
            "camera": read_camera(ram, ds, objects),
            "position_units": "unverified-original-units",
            "hull_angle_u8": hull_angle, "turret_relative_u8": turret_angle,
            "heading_degrees": bearing(hull_angle),
            "bearing_degrees": bearing(hull_angle + turret_angle),
            "speed_raw": speed_raw,
            "speed_display": (abs(speed_raw) * 100 // 76) * (-1 if speed_raw < 0 else 1),
            "fuel_display": word(0x79A2),
            "ammunition": dict(zip(("COAX", "HEAT", "SABOT", "AX"),
                                   struct.unpack_from("<4h", ram, ds + 0x79B4))),
            "selected_weapon": ("HEAT", "SABOT", "AX")[weapon] if weapon < 3 else "COAX",
        }
