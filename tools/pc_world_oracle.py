#!/usr/bin/env python3
"""Compare world decoding with the original SIM's executed object loader.

Unmodified original instructions run inside pinned Unicorn, with synthetic RAM
inputs and locally decoded resources. Also compares resources/objects with an
actual original-game capture. No original files or live game memory are written.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

import unicorn
from unicorn.x86_const import (
    UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS,
    UC_X86_REG_SP, UC_X86_REG_EFLAGS,
    UC_X86_REG_AX, UC_X86_REG_BP,
)

try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until, original_unpack, LOAD, DATA_SEGMENT
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.pc_world import read_objects, world_position, STATIC_START, STATIC_STRIDE
    from tools.inspect_scenarios import decode_resource, parse_world, parse_shape_table
    from tools.inspect_shapes import inspect_shapes, primitive_vertices
except ModuleNotFoundError:
    from pc_bearing_oracle import cpu, set_registers, run_until, original_unpack, LOAD, DATA_SEGMENT
    from pc_live_state import SimStateReader, SIM_SHA256
    from pc_world import read_objects, world_position, STATIC_START, STATIC_STRIDE
    from inspect_scenarios import decode_resource, parse_world, parse_shape_table
    from inspect_shapes import inspect_shapes, primitive_vertices

ROOT = Path(__file__).resolve().parents[1]
CODE_SEGMENT = LOAD + 0xB4D
DS = DATA_SEGMENT * 16


class OriginalWorld:
    def __init__(self, source: bytes, shapes: bytes):
        if unicorn.__version__ != "2.1.4" or hashlib.sha256(source).hexdigest() != SIM_SHA256:
            raise ValueError("world oracle requires pinned Unicorn and SIM.EXE")
        image, self.unpack_receipt = original_unpack(source)
        self.machine = cpu()
        self.machine.mem_write(LOAD * 16, image)
        self.machine.mem_write(0x50000, shapes)
        self.write(0x8D82, struct.pack("<H", 0x5000))
        self.write(0x7ACA, struct.pack("<HH", 0, 0x6000))
        self.write(0x6D54, struct.pack("<128H", *(STATIC_START + i * STATIC_STRIDE for i in range(128))))

    def write(self, offset, data):
        self.machine.mem_write(DS + offset, data)

    def call(self, entry, args, far=True, registers=()):
        set_registers(self.machine, (
            (UC_X86_REG_CS, CODE_SEGMENT), (UC_X86_REG_DS, DATA_SEGMENT),
            (UC_X86_REG_ES, DATA_SEGMENT), (UC_X86_REG_SS, 0x8000),
            (UC_X86_REG_SP, 0xF000), (UC_X86_REG_EFLAGS, 2),
        ))
        set_registers(self.machine, registers)
        words = [0xFF00] + ([CODE_SEGMENT] if far else []) + list(args)
        self.machine.mem_write(0x8F000, struct.pack("<" + "H" * len(words), *(v & 65535 for v in words)))
        run_until(self.machine, CODE_SEGMENT * 16 + entry, CODE_SEGMENT * 16 + 0xFF00, 100_000)
        if self.machine.reg_read(UC_X86_REG_SP) != 0xF000 + (4 if far else 2):
            raise ValueError("unbalanced original world routine stack")

    def origin(self, column, row):
        self.write(0x886A, bytes([column]))
        self.write(0x776C, bytes([row]))

    def objects(self):
        return read_objects(bytes(self.machine.mem_read(0, 640 * 1024)), DS)["static"]


def check_live(ram: bytes, root: Path) -> dict:
    reader = SimStateReader(root / "SIM.EXE")
    state = reader.read(ram)
    if not state:
        raise ValueError("original SIM absent from capture")
    ds = state["load_segment"] * 16 + 0x19E00
    index = state["scenario_resource_index"]
    resources = {}
    for name, pointer in (("SHAPE.TBL", 0x6D50), (f"SNARIO{index}.WLD", 0x7ACA)):
        data = decode_resource((root / name).read_bytes())
        offset, segment = struct.unpack_from("<HH", ram, ds + pointer)
        start = segment * 16 + offset
        if ram[start:start + len(data)] != data:
            raise ValueError(f"live {name} differs from resource (possibly runtime mutation)")
        resources[name] = {"physical_address": start, "bytes": len(data),
                           "sha256": hashlib.sha256(data).hexdigest(), "exact_match": True}
    shapes = decode_resource((root / "SHAPE.TBL").read_bytes())
    world = parse_world(decode_resource((root / f"SNARIO{index}.WLD").read_bytes()))
    entries = {e["offset"]: (r, e) for r in world["records"] for e in r["entries"] if not e["unused"]}
    origin = state["world"]["window_origin"]
    expected = {offset for offset, (r, e) in entries.items()
                if origin[0] <= r["column"] < origin[0] + 8 and origin[1] <= r["row"] < origin[1] + 8}
    found = set()
    for obj in state["world"]["static"]:
        offset = obj["world_entry_offset"]
        if offset not in entries or offset in found:
            raise ValueError("unknown/duplicate live world entry")
        found.add(offset)
        record, entry = entries[offset]
        header = struct.unpack_from("<H", shapes, struct.unpack_from("<H", shapes, entry["shape_index"] * 2)[0])[0]
        if (obj["shape_index"] != entry["shape_index"] or obj["shape_header_word"] != header
                or obj["cell"] != [record["column"], record["row"]]
                or obj["world_position_raw"] != entry["world_position_raw"]):
            raise ValueError(f"live placement disagrees at WLD offset {offset:#x}")
    if expected != found:
        raise ValueError("live object pool does not equal decoded current window")
    return {"resources": resources, "window_origin": origin, "static_objects_matched": len(found),
            "player_world_position": state["world_position_raw"]}


def run(root: Path, capture: Path) -> dict:
    shapes = decode_resource((root / "SHAPE.TBL").read_bytes())
    table = parse_shape_table(shapes)["records"]
    original = OriginalWorld((root / "SIM.EXE").read_bytes(), shapes)
    checks = {"cell_centers": 0, "packed_positions": 0, "extended_positions": 0,
              "world_entries": 0, "render_vertices": 0, "window_shifts": 0}
    # Original cell->local and local->cell routines, every slot at several origins.
    for column, row in ((0, 0), (15, 31), (56, 56)):
        original.origin(column, row)
        for slot in range(64):
            r, c = row + slot // 8, column + slot % 8
            original.write(0xF000, bytes([r, c]))
            original.call(0x88, (0xF000, 0xF010))
            local = struct.unpack("<3h", original.machine.mem_read(DS + 0xF010, 6))
            if world_position(local, [column, row]) != [c * 4096 + 2048, r * 4096 + 2048, 0]:
                raise ValueError("original cell center transform differs")
            original.call(0xCC, (0xF010, 0xF020))
            if bytes(original.machine.mem_read(DS + 0xF020, 2)) != bytes([r, c]):
                raise ValueError("original inverse center transform differs")
            checks["cell_centers"] += 1
    # Exhaust every packed nibble position in every streaming-window slot.
    original.origin(15, 31)
    for slot in range(64):
        for packed in range(256):
            original.write(0xF020, bytes(23))
            original.write(0xF034, bytes([slot]))
            original.write(0xF010, bytes([packed]))
            original.call(0x2AF2, (0xF010, DATA_SEGMENT, 128, 0xF020), far=False)
            actual = struct.unpack("<3h", original.machine.mem_read(DS + 0xF024, 6))
            expected = ((packed >> 4) * 256 + (slot % 8) * 4096 - 16384,
                        (packed & 15) * 256 - (slot // 8) * 4096 + 12288, 0)
            if actual != expected:
                raise ValueError("original packed position differs")
            checks["packed_positions"] += 1
        for vector in ((0, 0, 0), (-2048, 2047, -50), (2047, -2048, 300)):
            original.write(0xF010, struct.pack("<3h", *vector))
            original.call(0x2AF2, (0xF010, DATA_SEGMENT, 0, 0xF020), far=False)
            actual = struct.unpack("<3h", original.machine.mem_read(DS + 0xF024, 6))
            expected = (vector[0] + (slot % 8) * 4096 - 14336,
                        vector[1] - (slot // 8) * 4096 + 14336, vector[2])
            if actual != expected:
                raise ValueError("original extended position differs")
            checks["extended_positions"] += 1
    worlds = []
    for scenario in range(8):
        data = decode_resource((root / f"SNARIO{scenario}.WLD").read_bytes())
        original.machine.mem_write(0x60000, data)
        world = parse_world(data)
        objects = 0
        for record in world["records"]:
            c, r = record["column"], record["row"]
            origin = [min(max(c - 4, 0), 56), min(max(r - 4, 0), 56)]
            slot = (r - origin[1]) * 8 + c - origin[0]
            original.origin(*origin)
            original.write(STATIC_START, bytes(128 * STATIC_STRIDE))
            original.call(0x2BD0, (record["directory_offset"], slot * 4))
            actual = original.objects()
            expected = [e for e in record["entries"] if not e["unused"]]
            if len(actual) != len(expected):
                raise ValueError("original loaded a different object count")
            for a, e in zip(actual, expected):
                header = struct.unpack_from("<H", shapes, table[e["shape_index"]]["offset"])[0]
                if (a["world_position_raw"] != e["world_position_raw"] or a["shape_index"] != e["shape_index"]
                        or a["world_entry_offset"] != e["offset"] or a["shape_header_word"] != header
                        or a["window_cell"] != slot):
                    raise ValueError(f"original loaded a different object in scenario {scenario}")
            objects += len(actual)
        worlds.append({"scenario": scenario, "nonempty_cells": len(world["records"]), "objects_matched": objects})
        checks["world_entries"] += objects
    # Execute the actual renderer vertex reader with identity camera and zero
    # translation. Each call clears its per-index cache to remain independent.
    original.write(0x1CDF, b"\x01")
    original.write(0x1CDE, b"\0")
    original.write(0x142C, bytes(6))
    for shape in inspect_shapes(shapes)["shapes"]:
        original.write(0x1425, bytes([shape["header_byte_2"]]))
        seen = {}
        for primitive in shape["primitives"]:
            for encoded, expected in zip(primitive["encoded_indices"], primitive_vertices(shape, primitive)):
                if encoded in seen:
                    continue
                seen[encoded] = expected
                original.write(0x1499, bytes(128))
                original.call(0x1A5C, (), far=False, registers=(
                    (UC_X86_REG_AX, encoded), (UC_X86_REG_BP, shape["vectors_offset"]),
                    (UC_X86_REG_ES, 0x5000),
                ))
                index = encoded & 127
                actual = [struct.unpack("<h", original.machine.mem_read(DS + a + index * 2, 2))[0]
                          for a in (0x1519, 0x1619, 0x1719)]
                if actual != expected:
                    raise ValueError(f"original vertex differs for shape {shape['index']}, reference {encoded}")
                checks["render_vertices"] += 1
    # Force each original streaming-window shift in an isolated world. Retained
    # objects and the player must retain continuous coordinates across rebases.
    original.machine.mem_write(0x60000, decode_resource((root / "SNARIO6.WLD").read_bytes()))
    for routine, expected_origin in ((0x2DAC, [16, 31]), (0x2E48, [14, 31]),
                                      (0x2EEA, [15, 32]), (0x2F7E, [15, 30])):
        original.call(0x3010, (31, 15))
        original.write(0x709E, bytes([128, 125, 0, 0]) + struct.pack("<3h", 2048, 2048, 50))
        before = {o["world_entry_offset"]: o["world_position_raw"] for o in original.objects()}
        original.call(routine, ())
        after = original.objects()
        actual_origin = [original.machine.mem_read(DS + at, 1)[0] for at in (0x886A, 0x776C)]
        local = struct.unpack("<3h", original.machine.mem_read(DS + 0x709E + 4, 6))
        if actual_origin != expected_origin or world_position(local, actual_origin) != [79872, 141312, 50]:
            raise ValueError("original window shift changed continuous player position")
        retained = [o for o in after if o["world_entry_offset"] in before]
        if not retained or any(o["world_position_raw"] != before[o["world_entry_offset"]] for o in retained):
            raise ValueError("original window shift changed retained object positions")
        checks["window_shifts"] += 1
    live = check_live(capture.read_bytes(), root)
    return {"schema": 1, "engine": "unicorn-2.1.4/x86-16", "unpacker": original.unpack_receipt,
            "routines": ["0b4d:0088", "0b4d:00cc", "0b4d:1a5c", "0b4d:2af2", "0b4d:2bd0",
                         "0b4d:2dac", "0b4d:2e48", "0b4d:2eea", "0b4d:2f7e"],
            "checks": checks, "worlds": worlds, "live_capture": str(capture),
            "live_ram_sha256": hashlib.sha256(capture.read_bytes()).hexdigest(), "live": live,
            "scope": "static world placement and streaming coordinates; visibility/materials/physical units unresolved"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT / "GAME")
    parser.add_argument("--capture", type=Path, default=ROOT / "reference/pc-live/mission-entry/conventional.bin")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.resolve().is_relative_to(args.root.resolve()):
        parser.error("output must be outside original directory")
    result = run(args.root, args.capture)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
