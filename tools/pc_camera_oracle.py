#!/usr/bin/env python3
"""Check camera transforms and static draw selection against original instructions.

Uses only isolated copies of captured RAM. Replays the original draw callback
with its original SS=DS stack convention; no original code is patched. VGA port
and framebuffer effects are not a rasterization proof. No output returns to the
live original game. Requires the existing pinned Unicorn analysis environment.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import random
import struct

import unicorn
from unicorn import UC_HOOK_CODE
from unicorn.x86_const import (
    UC_X86_REG_CS, UC_X86_REG_DS, UC_X86_REG_ES, UC_X86_REG_SS,
    UC_X86_REG_SP, UC_X86_REG_EFLAGS, UC_X86_REG_SI, UC_X86_REG_DI, UC_X86_REG_AX,
)
try:
    from tools.pc_bearing_oracle import cpu, set_registers, run_until
    from tools.pc_live_state import SimStateReader, SIM_SHA256
    from tools.inspect_shapes import inspect_shapes
    from tools.inspect_scenarios import decode_resource
    from tools.pc_render_state import transform, static_faces_for_state, select_root
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from pc_bearing_oracle import cpu, set_registers, run_until
    from pc_live_state import SimStateReader, SIM_SHA256
    from inspect_shapes import inspect_shapes
    from inspect_scenarios import decode_resource
    from pc_render_state import transform, static_faces_for_state, select_root
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]


def verify_root_thresholds(ram, reader, shapes):
    state = reader.read(ram)
    load, ds = state["load_segment"], state["load_segment"] + 0x19E0
    machine = cpu()
    machine.mem_write(0, ram)
    checked = 0
    for shape in shapes[:127]:
        if not shape["vector_count"]:
            continue
        sizes = {0, 1, 32767}
        sizes.update(max(0, min(32767, s["word"] + d)) for s in shape["selectors"] for d in (-1, 0, 1))
        for size in sorted(sizes):
            machine.mem_write(ds * 16 + 0x7ACF, bytes([shape["index"]]))
            machine.mem_write(ds * 16 + 0x7ADE, struct.pack("<H", size))
            set_registers(machine, ((UC_X86_REG_CS, load + 0xB4D), (UC_X86_REG_DS, ds),
                          (UC_X86_REG_ES, ds), (UC_X86_REG_SS, ds),
                          (UC_X86_REG_SP, 0x9800), (UC_X86_REG_EFLAGS, 2)))
            machine.mem_write(ds * 16 + 0x9800, struct.pack("<3H", 0xFF00, load + 0xB4D, 0x7ACE))
            run_until(machine, (load + 0xB4D) * 16 + 0x2867, (load + 0xB4D) * 16 + 0x28D0, 10_000)
            if machine.reg_read(UC_X86_REG_DI) != select_root(shape, size)["offset"]:
                raise ValueError("original detail-root threshold differs")
            checked += 1
    return checked


def synthetic_matrix(ram, reader, angles):
    """Exercise the original pitch/roll branches absent from these live views."""
    state = reader.read(ram)
    load, ds = state["load_segment"], state["load_segment"] + 0x19E0
    mode = (2 if angles[0] or angles[1] else 0) + bool(angles[2])
    machine = cpu()
    machine.mem_write(0, ram)
    machine.mem_write(ds * 16 + 0xF000, bytes(angles))
    for entry, args in ((0xAA2, (0xF000, 0x117D, mode)), (0xC47, (0x117D,))):
        set_registers(machine, ((UC_X86_REG_CS, load + 0xB4D), (UC_X86_REG_DS, ds),
                      (UC_X86_REG_ES, ds), (UC_X86_REG_SS, 0x8000),
                      (UC_X86_REG_SP, 0xF000), (UC_X86_REG_EFLAGS, 2)))
        machine.mem_write(0x8F000, struct.pack("<" + "H" * (len(args) + 1), 0xFF00, *args))
        run_until(machine, (load + 0xB4D) * 16 + entry, (load + 0xB4D) * 16 + 0xFF00, 100_000)
    # Retain only the generated matrix/mode. Scratch bytes never enter a capture.
    result = bytearray(ram)
    result[ds * 16 + 0x117D:ds * 16 + 0x118F] = machine.mem_read(ds * 16 + 0x117D, 18)
    result[ds * 16 + 0x12C1] = mode
    return bytes(result)


def verify_capture(ram, reader, shapes):
    state = reader.read(ram)
    if not state or not state["camera"]:
        raise ValueError("capture lacks a supported camera state")
    load = state["load_segment"]
    ds = load + 0x19E0
    camera = state["camera"]
    machine = cpu()
    machine.mem_write(0, ram)
    polygons, selected, roots = [], {}, {}
    current_object = 0
    current_primitive = 0

    def word(at):
        return struct.unpack("<H", machine.mem_read(ds * 16 + at, 2))[0]

    def observe(_machine, address, _size, _context):
        nonlocal current_object, current_primitive
        offset = address - load * 16
        if offset == 0xB4D0 + 0x28D0:
            current_object = word(0x12CC)
            roots[current_object] = machine.reg_read(UC_X86_REG_DI)
        elif offset == 0xB4D0 + 0x596:
            current_primitive = machine.reg_read(UC_X86_REG_SI)
            selected.setdefault(current_object, []).append(current_primitive)
        else:
            sp, ss = machine.reg_read(UC_X86_REG_SP), machine.reg_read(UC_X86_REG_SS)
            count, xp, yp = struct.unpack("<3H", machine.mem_read(ss * 16 + sp + 4, 6))
            if count > 64:
                raise ValueError("unexpected polygon count")
            xy = [list(struct.unpack("<" + "h" * count, machine.mem_read(ds * 16 + at, count * 2)))
                  for at in (xp, yp)]
            polygons.append({"pointer": current_object, "primitive": current_primitive,
                             "pixels_before_viewport_clip": list(map(list, zip(*xy)))})
    for offset in (0xB4D0 + 0x28D0, 0xB4D0 + 0x596, 0xF8D0 + 0x357):
        machine.hook_add(UC_HOOK_CODE, observe, begin=load * 16 + offset, end=load * 16 + offset)
    # The original static normal-dot helper addresses stack temporaries through
    # DS:SI. SS must equal DS, unlike simpler BP-only isolated world routines.
    set_registers(machine, ((UC_X86_REG_CS, load), (UC_X86_REG_DS, ds), (UC_X86_REG_ES, ds),
                  (UC_X86_REG_SS, ds), (UC_X86_REG_SP, 0x9800), (UC_X86_REG_EFLAGS, 2)))
    machine.mem_write(ds * 16 + 0x9800, struct.pack("<HH", 0xFF00, load))
    run_until(machine, load * 16 + 0x8AC4, load * 16 + 0xFF00, 5_000_000)
    faces = static_faces_for_state(state, shapes)
    for item in faces:
        pointer = item["pointer"]
        if (item.get("unsupported") or item["root"] != roots.get(pointer)
                or sorted(item["primitive_ids"]) != sorted(selected.get(pointer, []))):
            raise ValueError(f"original static root/faces disagree for {pointer:#x}: {item}, actual {selected.get(pointer)}")
    # Independent original matrix execution over deterministic signed vectors.
    machine = cpu()
    machine.mem_write(0, ram)
    vectors = [[0, 0, 0], [100, 200, 300], [-100, -200, -300]]
    randomizer = random.Random(1988)
    vectors += [[randomizer.randrange(-12000, 12001) for _ in range(3)] for _ in range(100)]
    projections = []
    for vector in vectors:
        set_registers(machine, ((UC_X86_REG_CS, load + 0xB4D), (UC_X86_REG_DS, ds),
                      (UC_X86_REG_ES, ds), (UC_X86_REG_SS, 0x8000),
                      (UC_X86_REG_SP, 0xF000), (UC_X86_REG_EFLAGS, 2)))
        machine.mem_write(ds * 16 + 0xF000, struct.pack("<3h", *vector))
        machine.mem_write(0x8F000, struct.pack("<5H", 0xFF00, 0xF000, 0x117D, camera["matrix_mode"], 0xF010))
        run_until(machine, (load + 0xB4D) * 16 + 0x1175, (load + 0xB4D) * 16 + 0xFF00, 10_000)
        actual = list(struct.unpack("<3h", machine.mem_read(ds * 16 + 0xF010, 6)))
        if actual != transform(vector, camera["matrix_q14_columns"], camera["matrix_mode"]):
            raise ValueError("original camera vector transform differs")
        if actual[1] >= 128:
            center, focal = camera["center"], camera["focal_pixels"]
            # Execute the original signed divide/projection too. A wide raster
            # clip is an explicit oracle input, allowing off-screen arithmetic
            # to be checked independently of the live view's clipping decision.
            machine.mem_write(ds * 16 + 0x3593, struct.pack("<4h", -32768, 32767, -32768, 32767))
            set_registers(machine, ((UC_X86_REG_CS, load), (UC_X86_REG_DS, ds),
                          (UC_X86_REG_SS, ds), (UC_X86_REG_SP, 0x9800), (UC_X86_REG_EFLAGS, 2)))
            machine.mem_write(ds * 16 + 0x9800, struct.pack("<4H", 0xFF00, 0xF010, 0xF020, 0xF022))
            run_until(machine, load * 16 + 0x7A, load * 16 + 0xFF00, 100_000)
            pixels = list(struct.unpack("<2h", machine.mem_read(ds * 16 + 0xF020, 4)))
            divide = lambda n: (abs(n) // actual[1]) * (-1 if n < 0 else 1)
            if machine.reg_read(UC_X86_REG_AX) != 1 or pixels != [center[0] + divide(actual[0] * focal), center[1] - divide(actual[2] * focal)]:
                raise ValueError("original signed perspective projection differs")
            # Fractional projection intentionally exposes the original camera
            # geometry before integer pixel rounding, for high-resolution Godot.
            projections.append({"local_delta": vector, "camera_i16": actual, "pixel_i16": pixels,
                                "pixel_float": [center[0] + actual[0] * focal / actual[1],
                                                center[1] - actual[2] * focal / actual[1]]})
    return {"state": state, "static_faces": faces, "drawn_polygons": polygons,
            "matrix_vectors_checked": len(vectors), "projection_samples": projections,
            "ram_sha256": hashlib.sha256(ram).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if unicorn.__version__ != "2.1.4":
        raise ValueError("pinned Unicorn 2.1.4 required")
    if inside_source(args.output, ROOT):
        parser.error("output must be outside original GAME and GENESIS")
    reader = SimStateReader(ROOT / "GAME/SIM.EXE")
    shapes = inspect_shapes(decode_resource((ROOT / "GAME/SHAPE.TBL").read_bytes()))["shapes"]
    captures = {}
    for path in sorted(args.captures.glob("*.bin")):
        captures[path.stem] = verify_capture(path.read_bytes(), reader, shapes)
        print(f"PASS {path.stem}: camera and {len(captures[path.stem]['static_faces'])} static draw objects", flush=True)
    if not captures:
        raise ValueError("no original RAM captures")
    baseline = (args.captures / "gunner-forward.bin").read_bytes()
    for name, angles in (("synthetic-pitch-roll", [16, 8, 0]), ("synthetic-pitch-roll-yaw", [16, 8, 30])):
        captures[name] = verify_capture(synthetic_matrix(baseline, reader, angles), reader, shapes)
        captures[name]["synthetic_angles_u8"] = angles
        print(f"PASS {name}: original-generated matrix; no live viewpoint claim", flush=True)
    result = {"schema": 1, "sim_sha256": SIM_SHA256, "captures": captures,
              "static_root_threshold_cases": verify_root_thresholds(baseline, reader, shapes),
              "scope": "camera matrices and static root/face selection; not rasterization, timing or dynamic render parity"}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")


if __name__ == "__main__":
    main()
