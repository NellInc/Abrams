"""Read-only original PC streaming-world coordinates and object pools.

The coordinate origin follows SIM 0b4d:0088 and its four window-shift routines.
Active means allocated, never visible. Consumers must not use this diagnostic
pool as a finished gameplay visibility list.
"""
from __future__ import annotations

import struct

CELL_SIZE = 4096
STATIC_START, STATIC_STRIDE, STATIC_COUNT = 0x7ACE, 23, 128
DYNAMIC_START, DYNAMIC_STRIDE, DYNAMIC_COUNT = 0x709E, 58, 30


def world_position(local: list | tuple, origin: list | tuple) -> list[int]:
    """Signed local X/Y/Z plus [column, row] -> east/south/original-height."""
    return [local[0] + (origin[0] + 4) * CELL_SIZE,
            (origin[1] + 4) * CELL_SIZE - local[1], local[2]]


def window_origin(ram: bytes, ds: int) -> list[int]:
    return [ram[ds + 0x886A], ram[ds + 0x776C]]


def read_objects(ram: bytes, ds: int) -> dict:
    origin = window_origin(ram, ds)
    pools = {}
    for name, start, stride, count in (("static", STATIC_START, STATIC_STRIDE, STATIC_COUNT),
                                       ("dynamic", DYNAMIC_START, DYNAMIC_STRIDE, DYNAMIC_COUNT)):
        objects = []
        for slot in range(count):
            pointer = start + slot * stride
            at = ds + pointer
            flags = ram[at]
            if not flags & 128:
                continue
            local = list(struct.unpack_from("<3h", ram, at + 4))
            item = {"slot": slot, "pointer": pointer, "flags": flags,
                    "shape_index": ram[at + 1], "shape_header_word": struct.unpack_from("<H", ram, at + 2)[0],
                    "projected_size_raw": struct.unpack_from("<h", ram, at + 16)[0],
                    "position_local_raw": local, "world_position_raw": world_position(local, origin)}
            if name == "static":
                cell = ram[at + 20]
                item.update({"world_entry_offset": struct.unpack_from("<H", ram, at + 18)[0],
                             "window_cell": cell,
                             "cell": [origin[0] + (cell & 7), origin[1] + (cell >> 3)]})
            else:
                item["orientation_u8"] = list(ram[at + 24:at + 27])
            objects.append(item)
        pools[name] = objects
    return {"window_origin": origin, "cell_size_raw": CELL_SIZE,
            "axes": ["east", "south", "original_height"],
            "visibility": "unverified; allocated objects only", **pools}
