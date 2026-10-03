#!/usr/bin/env python3
"""Inspect SHAPE.TBL storage, decode primitive vertices, export a cube fixture.

Primitive vertex conversion is checked by pc_world_oracle.py against original
instructions. Physical units, colors, culling and commands remain unresolved.
"""
from __future__ import annotations
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct

try:
    from tools.inspect_scenarios import decode_resource, parse_shape_table
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from inspect_scenarios import decode_resource, parse_shape_table
    from source_guard import inside_source


def inspect_shapes(data: bytes) -> dict:
    directory = parse_shape_table(data)
    shapes = []
    for entry in directory["records"]:
        start = entry["offset"]
        end = start + entry["size"]
        if start + 8 > end:
            raise ValueError("truncated shape header")
        count = data[start + 3]
        vectors_start = int.from_bytes(data[start + 4:start + 6], "little")
        if not start + 8 <= vectors_start <= end or vectors_start + count * 6 != end:
            raise ValueError("vector array does not exactly fill shape tail")
        vectors = [list(v) for v in struct.iter_unpack("<hhh", data[vectors_start:end])]
        regions = {}

        def region(a: int, z: int, kind: str) -> None:
            if not start <= a < z <= vectors_start:
                raise ValueError(f"{kind} outside control region")
            previous = regions.get(a)
            if previous is not None and previous != (z, kind):
                raise ValueError("conflicting pointer target interpretation")
            regions[a] = (z, kind)

        def pointer_list(at: int) -> tuple[list[int], int]:
            result = []
            while at + 2 <= vectors_start:
                pointer = int.from_bytes(data[at:at + 2], "little")
                at += 2
                if pointer == 65535:
                    return result, at
                if not start <= pointer < vectors_start:
                    raise ValueError("pointer outside control region")
                result.append(pointer)
            raise ValueError("unterminated pointer list")

        selectors = []
        at = start + 6
        while True:
            if at + 2 > vectors_start:
                raise ValueError("unterminated selector directory")
            word = int.from_bytes(data[at:at + 2], "little")
            if word == 65535:
                at += 2
                break
            if at + 4 > vectors_start:
                raise ValueError("truncated selector entry")
            target = int.from_bytes(data[at + 2:at + 4], "little")
            if not start <= target < vectors_start:
                raise ValueError("selector target outside control region")
            selectors.append({"offset": at, "word": word, "target": target})
            at += 4
        region(start, at, "header")
        roots, groups, primitives, commands = {}, {}, {}, {}
        if count:
            for selector in selectors:
                root = selector["target"]
                group_ptrs, after = pointer_list(root + 2)
                command_ptrs, after = pointer_list(after)
                region(root, after, "root")
                roots[root] = {"offset": root, "byte_0": data[root], "byte_1": data[root + 1],
                               "group_pointers": group_ptrs, "command_pointers": command_ptrs}
                for command in command_ptrs:
                    region(command, command + 4, "opaque_command")
                    commands[command] = {"offset": command, "hex": data[command:command + 4].hex(" ")}
                for group in group_ptrs:
                    primitive_ptrs, after = pointer_list(group + 2)
                    region(group, after, "group")
                    groups[group] = {"offset": group, "byte_0": data[group], "byte_1": data[group + 1],
                                     "primitive_pointers": primitive_ptrs}
                    for primitive in primitive_ptrs:
                        if primitive + 4 > vectors_start:
                            raise ValueError("truncated primitive")
                        terminator = data.find(b"\xff", primitive + 3, vectors_start)
                        if terminator < 0:
                            raise ValueError("unterminated primitive")
                        encoded = list(data[primitive + 3:terminator])
                        indices = [value & 127 for value in encoded]
                        if any(index >= count for index in indices):
                            raise ValueError("primitive index exceeds vector count")
                        region(primitive, terminator + 1, "primitive")
                        primitives[primitive] = {"offset": primitive,
                            "prefix_bytes": list(data[primitive:primitive + 3]),
                            "encoded_indices": encoded, "indices_low7": indices}
        else:
            for selector in selectors:
                target = selector["target"]
                region(target, target + 2, "opaque_pair")
                commands[target] = {"offset": target, "hex": data[target:target + 2].hex(" ")}
        # Pointer spans must partition every control byte. Repeated references to
        # the same span are allowed; partial overlaps and gaps are not.
        cursor = start
        for a, (z, _kind) in sorted(regions.items()):
            if a != cursor:
                raise ValueError("control regions overlap or leave a gap")
            cursor = z
        if cursor != vectors_start:
            raise ValueError("unparsed control-region tail")
        shapes.append({**entry, "header_word_0": int.from_bytes(data[start:start + 2], "little"),
                       "header_byte_2": data[start + 2], "vector_count": count,
                       "vectors_offset": vectors_start, "vectors_i16le": vectors,
                       "selectors": selectors, "roots": list(roots.values()),
                       "groups": list(groups.values()), "primitives": list(primitives.values()),
                       "opaque_commands": list(commands.values()),
                       "control_coverage": "exact nonoverlapping partition"})
    return {"schema": 1, "decoded_sha256": hashlib.sha256(data).hexdigest(), "shapes": shapes,
            "evidence": "storage validated; primitive vertex conversion available; complete renderer semantics unresolved"}


def cube_geometry(shape: dict) -> tuple[list[list[int]], list[list[int]]]:
    """Return the corpus cube only after independently checking its topology."""
    faces = [primitive["indices_low7"] for primitive in shape["primitives"]]
    if len(faces) != 6 or any(len(face) != 4 or len(set(face)) != 4 for face in faces):
        raise ValueError("cube must have six nondegenerate quadrilateral index lists")
    used = sorted({index for face in faces for index in face})
    vectors = shape["vectors_i16le"]
    if len(used) != 8:
        raise ValueError("cube must reference exactly eight vectors")
    vertices = [vectors[index] for index in used]
    expected = {(x, y, z) for x in (-32, 32) for y in (-32, 32) for z in (-32, 32)}
    if {tuple(vertex) for vertex in vertices} != expected:
        raise ValueError("cube corners must equal all combinations of +/-32")
    remap = {old: new for new, old in enumerate(used)}
    mapped = [[remap[index] for index in face] for face in faces]
    planes = set()
    edges = Counter()
    for face in mapped:
        points = [vertices[index] for index in face]
        constant_axes = [axis for axis in range(3) if len({point[axis] for point in points}) == 1]
        if len(constant_axes) != 1:
            raise ValueError("cube face must lie on one boundary plane")
        axis = constant_axes[0]
        planes.add((axis, points[0][axis]))
        for a, z in zip(face, face[1:] + face[:1]):
            edges[tuple(sorted((a, z)))] += 1
            if sum(abs(vertices[a][k] - vertices[z][k]) for k in range(3)) != 64:
                raise ValueError("face contains a diagonal instead of a cube edge")
    if len(planes) != 6 or len(edges) != 12 or set(edges.values()) != {2}:
        raise ValueError("cube topology is not a closed six-face boundary")
    return vertices, mapped


def primitive_vertices(shape: dict, primitive: dict) -> list[list[int]]:
    """SIM 0b4d:1a5c: high-bit references use centered, scaled grid vectors.

    Returns object-local positions, not normals, visibility, LOD or materials.
    Ordinary references retain the original signed coordinate words.
    """
    shift = shape["header_byte_2"]
    if not 0 <= shift <= 15:
        raise ValueError("unsupported packed-vector shift")
    result = []
    for encoded in primitive["encoded_indices"]:
        vector = shape["vectors_i16le"][encoded & 127]
        if encoded & 128:
            # The original uses only each word's low byte, wraps at 16 bits,
            # then performs an arithmetic right shift by header byte 2.
            vector = [((((v & 255) * 256 - 2048 + 32768) % 65536) - 32768) >> shift for v in vector]
        result.append(list(vector))
    return result


def cube_obj(shape: dict) -> str:
    vertices, faces = cube_geometry(shape)
    lines = ["# Original SHAPE.TBL record 166, verified closed cube topology.",
             "# Raw coordinate axes and units preserved; no original materials or culling semantics.",
             "o shape_166_cube"]
    lines += ["v " + " ".join(str(value) for value in vertex) for vertex in vertices]
    lines += ["f " + " ".join(str(index + 1) for index in face) for face in faces]
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=Path("GAME/SHAPE.TBL"))
    parser.add_argument("--output", type=Path, default=Path("reference/reports/shape-structure.json"))
    parser.add_argument("--export-cube", action="store_true")
    args = parser.parse_args()
    source_dir = args.source.resolve().parent
    if inside_source(args.output) or inside_source(args.output, source_dir.parent, (source_dir.name,)):
        parser.error("output must be outside source directory")
    result = inspect_shapes(decode_resource(args.source.read_bytes()))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    if args.export_cube:
        output = args.output.parent / "shape-166-cube.obj"
        output.write_text(cube_obj(result["shapes"][166]))
    shapes = result["shapes"]
    print(f"Parsed {len(shapes)} shape records; {sum(bool(s['vector_count']) for s in shapes)} with vectors; "
          f"{sum(len(s['primitives']) for s in shapes)} primitive lists")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
