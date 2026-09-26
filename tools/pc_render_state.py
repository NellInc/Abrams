"""Read the original renderer's camera and select static primitive faces.

This is presentation-only. The original render queue is consumed as captured;
no replacement gameplay visibility or targeting decision is made here.
"""
from __future__ import annotations

import struct

try:
    from tools.pc_world import world_position, window_origin
    from tools.inspect_shapes import primitive_vertices
except ModuleNotFoundError:
    from pc_world import world_position, window_origin
    from inspect_shapes import primitive_vertices


def signed16(value: int) -> int:
    return (value + 32768) % 65536 - 32768


def transform(vector, matrix, mode):
    """SIM 0b4d:1175, signed Q14 matrix with original word wrapping."""
    if mode == 0:
        return list(vector)
    return [signed16(sum(vector[j] * matrix[j * 3 + i] for j in range(3)) >> 14)
            for i in range(3)]


def select_root(shape: dict, projected_size: int) -> dict:
    selectors = shape["selectors"]
    selected = selectors[-1]
    for item in selectors:
        if signed16(item["word"]) <= signed16(projected_size):
            selected = item
            break
    return next(root for root in shape["roots"] if root["offset"] == selected["target"])


def select_static_faces(shape: dict, projected_size: int, delta: list[int]) -> dict:
    """SIM 0b4d:2867 root choice and 0541/1cf3 static face rejection."""
    if not shape["vector_count"]:
        return {"primitive_ids": [], "unsupported": "opaque shape"}
    root = select_root(shape, projected_size)
    if root["byte_0"] & 128:
        return {"primitive_ids": [], "unsupported": "sprite root"}
    groups = {g["offset"]: g for g in shape["groups"]}
    primitives = {p["offset"]: p for p in shape["primitives"]}
    selected = []
    for group_pointer in root["group_pointers"]:
        for pointer in groups[group_pointer]["primitive_pointers"]:
            primitive = primitives[pointer]
            normal_index, first_color, _ = primitive["prefix_bytes"]
            if normal_index != 255:
                if first_color == 255 or not primitive["encoded_indices"]:
                    continue
                normal, vertex = primitive_vertices(shape, {"encoded_indices": [
                    normal_index, primitive["encoded_indices"][0]]})
                dot = sum(normal[i] * signed16(vertex[i] + delta[i]) for i in range(3))
                if dot & 0x80000000 == 0:
                    continue
            selected.append(pointer)
    return {"root": root["offset"], "primitive_ids": selected,
            "opaque_commands": len(root["command_pointers"])}


def read_camera(ram: bytes, ds: int, objects: dict) -> dict | None:
    def words(at, count=1, signed=True):
        return list(struct.unpack_from("<" + ("h" if signed else "H") * count, ram, ds + at))

    view = words(0x116E, signed=False)[0]
    if view >= 10:
        return None
    # The shared raster clip (3593..) is subsequently overwritten by cockpit
    # instruments. 3383 retains each 3D view's own rectangle in these arrays.
    left, right, top, bottom = [words(at + view * 2)[0] for at in (0x1A8B, 0x1A9F, 0x1AB3, 0x1AC7)]
    near, distance_cutoff, shift = words(0x12C2, 3)
    count = words(0x8DD2, signed=False)[0]
    mode = ram[ds + 0x12C1]
    if (not 0 <= left < right < 320 or not 0 <= top < bottom < 200
            or not 0 < near < 4096 or shift not in (6, 7, 8, 9)
            or not 0 <= mode <= 3 or not 0 <= count <= 163):
        return None  # Initializing or a renderer state outside this decoder.
    pointers = words(0x6F58, count, signed=False)
    allocated = {o["pointer"]: o for name in ("static", "dynamic") for o in objects[name]}
    if any(p not in allocated for p in pointers):
        return None  # VGA boundary can straddle object allocation/render passes.
    local = words(0x8B52, 3)
    return {"view_index": view, "position_local_raw": local, "world_position_raw": world_position(local, window_origin(ram, ds)),
            "matrix_q14_columns": words(0x117D, 9), "matrix_mode": mode,
            "clip": [left, top, right, bottom], "center": words(0x1B2B, 2),
            "near_raw": near, "focal_pixels": 1 << shift,
            "distance_cutoff_raw": distance_cutoff, "draw_order": pointers,
            "sampling": "last renderer state at VGA boundary; logic-tick atomicity unproven"}


def static_faces_for_state(state: dict, shapes: list) -> list:
    camera = state.get("camera")
    if camera is None:
        return []
    objects = {o["pointer"]: o for o in state["world"]["static"]}
    result = []
    for pointer in camera["draw_order"]:
        if pointer not in objects:
            continue
        obj = objects[pointer]
        delta = [signed16(a - b) for a, b in zip(obj["position_local_raw"], camera["position_local_raw"])]
        faces = select_static_faces(shapes[obj["shape_index"]], obj["projected_size_raw"], delta)
        result.append({"pointer": pointer, "world_entry_offset": obj["world_entry_offset"], **faces})
    return result
