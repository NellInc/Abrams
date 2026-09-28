#!/usr/bin/env python3
"""Recover local editable model references from the pinned Genesis drawing VM.

This is an authoring extractor, never a replacement simulation or visibility
engine. Preserve commands, branches, materials and source addresses alongside
the neutral-pose polygon union. The latter is not a rendered game frame.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ROM_HASH = "ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea"
DIRECTORY = 0x4DC98
DIRECTORY_COUNT = 188
CLASS_MODELS = range(115, 168)
DISPATCH = 0xF51A
MATERIAL_MAP = 0xCC6  # Ordinary source mode, selected by ROM 4738 / 10f62.
PATTERNS = 0xBC6
CONDITIONAL_POLYGONS = {0xA8, 0xAC, 0xB0, 0xB4, 0xBC, 0xC0}
POLYGONS = CONDITIONAL_POLYGONS | {0xA0, 0xA4, 0xB8}
LENGTHS = {
    0x00: 0, 0x0C: 0, 0x10: 1, 0x14: 1, 0x18: 1, 0x1C: 1,
    0x20: 1, 0x24: 0, 0x28: 0, 0x2C: 1, 0x30: 1, 0x34: 3,
    0x38: 3, 0x3C: 0, 0x40: 0, 0x54: 2, 0x60: 9, 0x64: 9,
    0x68: 5, 0x6C: 5, 0x70: 0, 0x74: 2, 0x80: 1, 0x84: 1,
    0x8C: 1, 0x90: 3, 0x94: 3, 0xCC: 4, 0xD0: 2, 0xD8: 5,
    0xE0: 8, 0xE4: 2, 0xF0: 0,
}


def pinned(rom: bytes) -> None:
    if hashlib.sha256(rom).hexdigest() != ROM_HASH:
        raise ValueError("Unrecognized Genesis ROM; model addresses are version-specific")


def directory(rom: bytes) -> list[dict]:
    pinned(rom)
    return [{"index": i, "entry": DIRECTORY + i * 4,
             "offset": DIRECTORY + struct.unpack_from(">H", rom, DIRECTORY + i * 4)[0],
             "source_extent": struct.unpack_from(">H", rom, DIRECTORY + i * 4 + 2)[0]}
            for i in range(DIRECTORY_COUNT)]


def command(rom: bytes, at: int, lower=0, upper=None) -> dict:
    """Decode one VM instruction, including all static control-flow targets.

    Lengths and branch bases follow original handlers. In particular ADDA with
    (A0)+ uses the post-incremented A0, confirmed by the separate CPU oracle.
    """
    upper = len(rom) if upper is None else upper
    if not 0 <= lower <= at < upper <= len(rom):
        raise ValueError("Command outside model region")
    op, p = rom[at], at + 1

    def need(size):
        if p + size > upper:
            raise ValueError(f"Truncated model command at {at:#x}")

    n = LENGTHS.get(op)
    if op == 0x04:
        need(3)
        if not rom[p + 1] or rom[p] + rom[p + 1] > 256:
            raise ValueError("Invalid vertex-load range")
        n = 3 + 6 * rom[p + 1]
    elif op in (0x58, 0x5C):
        need(2)
        if not rom[p + 1] or rom[p] + rom[p + 1] > 256:
            raise ValueError("Invalid facing-flag range")
        n = 2 + 3 * rom[p + 1]
    elif op in POLYGONS:
        prefix = 3 if op in CONDITIONAL_POLYGONS else 2
        need(prefix)
        if rom[p + prefix - 1] < 3:
            raise ValueError("Unsupported polygon vertex count")
        n = prefix + rom[p + prefix - 1]
    elif op == 0xEC:
        need(3)
        if rom[p] != 8 or not rom[p + 1]:
            raise ValueError("Unsupported secondary command or empty sort")
        n = 3 + 6 * rom[p + 1]
    if n is None:
        raise ValueError(f"Unknown model opcode {op:#x} at {at:#x}")
    need(n)
    end = p + n
    out = {"offset": at, "opcode": op, "end": end,
           "hex": rom[at:end].hex(), "targets": [], "successors": [end]}
    args = rom[p:end]
    if op == 0x04:
        out.update(destination=args[0], count=args[1], matrix=args[2],
                   vertices=[list(v) for v in struct.iter_unpack(">hhh", args[3:])])
    elif op in POLYGONS:
        skip = int(op in CONDITIONAL_POLYGONS)
        out.update(material=args[skip], indices=list(args[skip + 2:]))
        if skip:
            out["condition_flag"] = args[0]
    elif op in (0x58, 0x5C):
        out.update(destination=args[0], count=args[1],
                   triples=[list(args[i:i + 3]) for i in range(2, len(args), 3)])
    elif op == 0xEC:
        out.update(center=args[2], groups=[])
        for i in range(args[1]):
            field = p + 3 + i * 6
            target = field + 4 + struct.unpack_from(">i", rom, field)[0]
            vertex = struct.unpack_from(">H", rom, field + 4)[0]
            if vertex >= 256:
                raise ValueError("Sort vertex outside workspace")
            out["groups"].append({"target": target, "sort_vertex": vertex})
            out["targets"].append(target)
    elif op in (0x74, 0xD0):
        out["targets"] = [end + struct.unpack_from(">h", rom, p)[0]]
        if op == 0x74:
            out["successors"] = []
    elif op in (0x60, 0x64, 0x68, 0x6C):
        out["condition_flag"] = args[0]
        out["targets"] = [field + 4 + struct.unpack_from(">i", rom, field)[0]
                          for field in range(p + 1, end, 4)]
    elif op in (0x70, 0xF0):
        out["successors"] = []
    out["successors"] += out["targets"]
    if any(not lower <= target < upper for target in out["successors"]):
        raise ValueError(f"Control flow outside model region at {at:#x}")
    return out


def program(rom: bytes, start: int, lower=0, upper=None) -> list[dict]:
    """Traverse the union of explicit branches, calls and sorted subprograms."""
    pending, decoded, owner = [start], {}, {}
    while pending:
        at = pending.pop()
        if at in decoded:
            continue
        if len(decoded) >= 4096:
            raise ValueError("Model exceeds bounded command budget")
        item = command(rom, at, lower, upper)
        for byte in range(at, item["end"]):
            if byte in owner:
                raise ValueError("Overlapping commands or branch into operand bytes")
            owner[byte] = at
        decoded[at] = item
        pending.extend(item["successors"])
    return [decoded[at] for at in sorted(decoded)]


def signed(value):
    return (value + 32768) % 65536 - 32768


def neutral_geometry(commands: list[dict], start: int, detail=True) -> dict:
    """Authoring pose: zero actor angles, original identity matrix, flag FC.

    Projection/facing routines are deliberately not simulated. The original
    instructions independently verify construction in genesis_model_oracle.py.
    The two truck paths retain their separate generated vertices.
    """
    by_at = {c["offset"]: c for c in commands}
    vertices, matrices, stack, path, projections = {}, {0: [32766, 32766, 32766]}, [], [], []
    vector, at = [0, 0, 0], start

    def put(index, value):
        if not 0 <= index < 256:
            raise ValueError("Vertex outside original workspace")
        vertices[index] = [signed(x) for x in value]

    def get(index):
        if index not in vertices:
            raise ValueError(f"Read of undefined neutral vertex {index}")
        return vertices[index].copy()

    for _ in range(2048):
        c = by_at[at]
        op = c["opcode"]
        args = bytes.fromhex(c["hex"])[1:]
        if op in POLYGONS or op in (0xEC, 0x60, 0x64, 0x80, 0xCC, 0xF0):
            break
        path.append(at)
        following = c["end"]
        if op == 0xD8:
            matrices[args[4]] = matrices[args[3]].copy()
        elif op == 0xE0:
            scale = struct.unpack_from(">hhh", args)
            matrices[args[7]] = [signed((x * s) >> 15)
                                 for x, s in zip(matrices[args[6]], scale)]
        elif op == 0xE4:
            x, y, z = matrices[args[1]]
            corners = [(x, -y, -z), (x, -y, z), (-x, -y, z), (-x, -y, -z),
                       (x, y, -z), (x, y, z), (-x, y, z), (-x, y, -z)]
            for i, v in enumerate(corners):
                put(args[0] + i, v)
        elif op == 0x04:
            if matrices.get(c["matrix"]) != [32766] * 3:
                raise ValueError("Literal load requires verified neutral identity")
            for i, v in enumerate(c["vertices"]):
                put(c["destination"] + i, v)
        elif op == 0x0C:
            vector = [0, 0, 0]
        elif op == 0x10:
            vector = get(args[0])
        elif op == 0x14:
            put(args[0], vector)
        elif op in (0x18, 0x1C, 0x20):
            other = get(args[0])
            vector = [signed(x + (-y if op == 0x20 else y)) for x, y in zip(vector, other)]
            if op == 0x18:
                vector = [x >> 1 for x in vector]
        elif op in (0x24, 0x28):
            vector = [signed(-v) if op == 0x24 or i != 1 else v for i, v in enumerate(vector)]
        elif op in (0x2C, 0x30):
            shift = args[0] & 63
            vector = [signed(v << shift) if op == 0x2C else v >> shift for v in vector]
        elif op in (0x34, 0x38):
            for i in range(args[2]):
                source = get(args[0] + i)
                put(args[1] + i, [-x for x in source] if op == 0x38 else
                    [x + y for x, y in zip(source, vector)])
        elif op == 0x3C:
            stack.append(vector.copy())
        elif op == 0x40:
            if not stack:
                raise ValueError("Unbalanced neutral vector stack")
            vector = stack.pop()
        elif op == 0x74:
            following = c["targets"][0]
        elif op in (0x68, 0x6C):
            if c["condition_flag"] != 252:
                raise ValueError("Unknown construction branch condition")
            if detail == (op == 0x68):
                following = c["targets"][0]
        elif op == 0x54:
            projections += list(range(args[0], args[0] + args[1]))
        elif op not in (0, 0x58, 0x5C):
            raise ValueError(f"Unsupported neutral construction command {op:#x}")
        at = following
    else:
        raise ValueError("Neutral construction did not terminate")
    if stack:
        raise ValueError("Unbalanced neutral vector stack at geometry boundary")
    return {"vertices": vertices, "construction_path": path, "stop": at,
            "projected_indices": projections, "detail_flag_fc": int(detail),
            "pose": "zero actor angles; original 32766 identity; raw Genesis XYZ"}


def geometry_union(commands: list[dict], geometry: dict) -> dict:
    vertices = geometry["vertices"]
    polygons, lines, omitted = [], [], []
    pen, material = None, None
    for c in commands:
        op = c["opcode"]
        args = bytes.fromhex(c["hex"])[1:]
        if op in POLYGONS:
            if any(i not in vertices for i in c["indices"]):
                omitted.append(c["offset"])
            else:
                polygons.append({k: c[k] for k in ("offset", "opcode", "material", "indices", "condition_flag") if k in c})
        elif op == 0x80:
            material = args[0]
        elif op == 0x84:
            pen = args[0]
        elif op in (0x8C, 0x90, 0x94):
            target = args[-1]
            if pen is None or material is None:
                raise ValueError("Line union lacks explicit pen/material context")
            if pen not in vertices or target not in vertices:
                omitted.append(c["offset"])
            else:
                lines.append({"offset": c["offset"], "opcode": op, "material": material,
                              "indices": [pen, target], "condition_flags": list(args[:-1])})
            pen = target
        elif op == 0xCC:
            omitted.append(c["offset"])  # Keep the circle command in JSON, never guess a mesh.
        elif op in (0xF0, 0x70):
            pen, material = None, None
    return {"polygons": polygons, "lines": lines, "unmeshed_commands": omitted,
            "scope": "Union of source definitions, including opposite-facing alternatives; no runtime visibility, sorting, motion or circle approximation."}


def decode_models(rom: bytes) -> dict:
    entries = directory(rom)
    models = []
    for index in CLASS_MODELS:
        entry = entries[index]
        commands = program(rom, entry["offset"], 0x4DFE0, 0x7755C)
        poses = []
        for detail in ([False, True] if index == 159 else [True]):
            geometry = neutral_geometry(commands, entry["offset"], detail)
            poses.append(geometry | geometry_union(commands, geometry))
        models.append(entry | {"commands": commands, "poses": poses})
    return {"schema": 1, "rom_sha256": ROM_HASH, "directory": entries, "models": models}


def canonical_cycle(points):
    points = tuple(tuple(p) for p in points)
    return min(sequence[i:] + sequence[:i] for sequence in (points, points[::-1]) for i in range(len(points)))


def compare_pc(models, shape_file: Path) -> dict:
    try:
        from tools.inspect_shapes import inspect_shapes, primitive_vertices
        from tools.inspect_scenarios import decode_resource
    except ModuleNotFoundError:
        from inspect_shapes import inspect_shapes, primitive_vertices
        from inspect_scenarios import decode_resource
    shapes = inspect_shapes(decode_resource(shape_file.read_bytes()))["shapes"]
    results = []
    for model in models:
        pc = shapes[model["index"]]
        for pose in model["poses"]:
            # Coordinate correspondence only. Axis order does not authorize
            # replacing PC visibility or assuming matching dynamic transforms.
            mapped = {i: [v[0], v[2], v[1]] for i, v in pose["vertices"].items()}
            wanted = {tuple(v) for p in pc["primitives"] for v in primitive_vertices(pc, p)}
            have = set(map(tuple, mapped.values()))
            source_faces = Counter(canonical_cycle(primitive_vertices(pc, p)) for p in pc["primitives"] if len(p["encoded_indices"]) >= 3)
            genesis_faces = Counter(canonical_cycle([mapped[i] for i in p["indices"]]) for p in pose["polygons"])
            links = []
            for primitive in pc["primitives"]:
                if len(primitive["encoded_indices"]) < 3:
                    continue
                key = canonical_cycle(primitive_vertices(pc, primitive))
                donors = [p for p in pose["polygons"] if canonical_cycle([mapped[i] for i in p["indices"]]) == key]
                links.append({"pc_primitive": primitive["offset"], "pc_material": primitive["prefix_bytes"][2],
                              "genesis_commands": [p["offset"] for p in donors],
                              "genesis_materials": [p["material"] for p in donors],
                              "material_plus_16_matches": bool(donors) and all(p["material"] == 16 + primitive["prefix_bytes"][2] for p in donors)})
            results.append({"index": model["index"], "detail_flag_fc": pose["detail_flag_fc"],
                            "pc_used_vertices": len(wanted), "matching_vertices": len(wanted & have),
                            "pc_vertices_absent": sorted(wanted - have),
                            "pc_unique_polygons": len(source_faces), "genesis_unique_polygons": len(genesis_faces),
                            "matching_unique_polygons": len(source_faces.keys() & genesis_faces.keys()),
                            "pc_polygons_absent": [list(k) for k in source_faces.keys() - genesis_faces.keys()],
                            "genesis_extra_polygons": [list(k) for k in genesis_faces.keys() - source_faces.keys()],
                            "polygon_links": links})
    return {"source_sha256": hashlib.sha256(shape_file.read_bytes()).hexdigest(),
            "coordinate_conversion": "Genesis (x,y,z) to PC (x,z,y)", "models": results,
            "scope": "Coordinate/topology sets only; neither material equivalence, conditional visibility nor runtime parity."}


def obj(model, pose, material_file):
    lines = ["# Original Genesis neutral authoring geometry. See adjacent JSON for all commands.",
             "# This polygon union includes visibility alternatives and is NOT a rendered source frame.",
             f"mtllib {material_file}", f"o genesis_shape_{model['index']}"]
    # Unused source vectors include plane normals and sort references. They
    # belong in JSON, not the editable mesh's bounds or auto-framing.
    used = sorted({i for p in pose["polygons"] + pose["lines"] for i in p["indices"]})
    indices = {index: i + 1 for i, index in enumerate(used)}
    lines += ["v " + " ".join(map(str, pose["vertices"][i])) for i in indices]
    for kind, primitives in (("f", pose["polygons"]), ("l", pose["lines"])):
        for p in primitives:
            lines += [f"g command_{p['offset']:06x}", f"usemtl source_{p['material']:02x}",
                      kind + " " + " ".join(str(indices[i]) for i in p["indices"])]
    return "\n".join(lines) + "\n"


def export_models(rom_path: Path, capture: Path, output: Path) -> dict:
    try:
        from tools.extract_genesis_vdp import VDP
    except ModuleNotFoundError:
        from extract_genesis_vdp import VDP
    rom = rom_path.read_bytes()
    catalog = decode_models(rom)
    vdp = VDP(capture)
    if vdp.receipt["rom_sha256"] != ROM_HASH:
        raise ValueError("Palette capture belongs to a different ROM")
    material_ids = sorted({p["material"] for m in catalog["models"] for pose in m["poses"]
                           for p in pose["polygons"] + pose["lines"]})
    materials, mtl = [], ["# Ordinary source mode CC6, native gunner palette bank 3. Flat dither mean."]
    for material in material_ids:
        pattern = rom[MATERIAL_MAP + material]
        packed = rom[PATTERNS + pattern * 8:PATTERNS + pattern * 8 + 8]
        indices = [c for b in packed for c in (b >> 4, b & 15)]
        rgb = [sum(vdp.palette[48 + i][c] for i in indices) / 16 for c in range(3)]
        materials.append({"material": material, "pattern": pattern, "packed_hex": packed.hex(),
                          "palette_indices": indices, "mean_rgb": rgb})
        mtl += [f"newmtl source_{material:02x}", "Kd " + " ".join(f"{c / 255:.8f}" for c in rgb), "illum 0", ""]
    output.mkdir(parents=True, exist_ok=False)
    (output / "source-materials.mtl").write_text("\n".join(mtl))
    for model in catalog["models"]:
        model["files"] = []
        for pose in model["poses"]:
            name = f"shape-{model['index']:03d}-fc{pose['detail_flag_fc']}.obj"
            (output / name).write_text(obj(model, pose, "source-materials.mtl"))
            model["files"].append(name)
        (output / f"shape-{model['index']:03d}.json").write_text(json.dumps(model, indent=2) + "\n")
    catalog.update(materials=materials, palette_capture=str(capture), palette_bank=3,
                   palette_receipt_sha256=hashlib.sha256((capture / "receipt.json").read_bytes()).hexdigest(),
                   material_scope="Ordinary CC6 translation and palette bank 3; other source modes are not selected. OBJ materials average the two native pattern rows.",
                   scope="Local editable source references, not remastered art or live visibility. Original commands and omitted circles retained. No redistribution permission.")
    catalog["files"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.iterdir())}
    (output / "catalog.json").write_text(json.dumps(catalog, indent=2) + "\n")
    return catalog


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    p.add_argument("--capture", type=Path, required=True)
    p.add_argument("--output", type=Path, required=True)
    p.add_argument("--compare-pc", type=Path)
    a = p.parse_args()
    if any(a.output.resolve().is_relative_to((ROOT / n).resolve()) for n in ("GAME", "GENESIS")):
        p.error("output must be outside original source directories")
    result = export_models(a.rom, a.capture, a.output)
    if a.compare_pc:
        (a.output / "pc-correspondence.json").write_text(json.dumps(compare_pc(result["models"], a.compare_pc), indent=2) + "\n")
    print(f"Recovered {len(result['models'])} Genesis model programs into {a.output}")


if __name__ == "__main__":
    main()
