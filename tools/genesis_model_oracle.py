#!/usr/bin/env python3
"""Verify the Genesis model extractor against unchanged original M68000 code.

Synthetic isolated identity pose, not a running game's state. No ROM patches,
live core writes, projection, hidden-state inference or runtime-parity claim.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN, UC_PROT_READ, UC_PROT_EXEC, UC_HOOK_CODE
from unicorn.m68k_const import (UC_CPU_M68K_M68000, UC_M68K_REG_SR,
    UC_M68K_REG_A0, UC_M68K_REG_A1, UC_M68K_REG_A6, UC_M68K_REG_A7,
    UC_M68K_REG_D0, UC_M68K_REG_D2, UC_M68K_REG_D7, UC_M68K_REG_PC)
try:
    from tools.extract_genesis_models import ROOT, ROM_HASH, DISPATCH, MATERIAL_MAP, PATTERNS, POLYGONS, decode_models
except ModuleNotFoundError:
    from extract_genesis_models import ROOT, ROM_HASH, DISPATCH, MATERIAL_MAP, PATTERNS, POLYGONS, decode_models

STOP = 0x70000
STACK = 0xFFFFDF00
WORK = 0xFFFF5E10
FLAGS = 0xFFFF6E10


def verify(rom):
    catalog = decode_models(rom)
    cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    cpu.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    cpu.mem_map(0, 0x80000)
    cpu.mem_write(0, rom)
    cpu.mem_protect(0, 0x80000, UC_PROT_READ | UC_PROT_EXEC)
    cpu.mem_map(0xFFFF0000, 0x10000)

    def run(entry, stop=STOP, count=20000):
        cpu.emu_start(entry, stop, count=count)
        if cpu.reg_read(UC_M68K_REG_PC) != stop:
            raise ValueError(f"Original handler {entry:#x} did not finish at {stop:#x}")

    def reset():
        cpu.mem_write(0xFFFF0000, bytes(65536))
        cpu.reg_write(UC_M68K_REG_SR, 0x2000)
        cpu.reg_write(UC_M68K_REG_A7, STACK)
        cpu.reg_write(UC_M68K_REG_A6, STOP)

    for entry in catalog["directory"]:
        reset()
        cpu.mem_write(STACK, struct.pack(">I", STOP))
        cpu.reg_write(UC_M68K_REG_D0, entry["index"])
        run(0x3FBA)
        if cpu.reg_read(UC_M68K_REG_A0) != entry["offset"]:
            raise ValueError("Native directory pointer differs")
        cpu.reg_write(UC_M68K_REG_A7, STACK)
        cpu.reg_write(UC_M68K_REG_D0, entry["index"])
        run(0x3FEE)
        if cpu.reg_read(UC_M68K_REG_D0) & 65535 != entry["source_extent"]:
            raise ValueError("Native directory extent differs")

    poses, steps, compared, branch_steps = [], 0, 0, 0
    for model in catalog["models"]:
        commands = {c["offset"]: c for c in model["commands"]}
        for pose in model["poses"]:
            reset()
            seed = bytes([0xA5]) * 4096
            cpu.mem_write(WORK, seed)
            cpu.mem_write(0xFFFFE45A, struct.pack(">10h", 32766, 0, 0, 0, 32766, 0, 0, 0, 32766, 0))
            cpu.mem_write(0xFFFFE576, struct.pack(">I", 0xFFFF9000))
            cpu.mem_write(0xFFFFE536, struct.pack(">I", FLAGS))
            cpu.mem_write(FLAGS + 252, bytes([pose["detail_flag_fc"]]))
            cpu.reg_write(UC_M68K_REG_A1, WORK)
            path = pose["construction_path"]
            for position, at in enumerate(path):
                c = commands[at]
                op = c["opcode"]
                # Facing/projection do not construct the local vertices. They
                # remain untouched source commands, deliberately outside this oracle.
                if op in (0, 0x54, 0x58, 0x5C):
                    continue
                cpu.reg_write(UC_M68K_REG_D0, op)
                cpu.reg_write(UC_M68K_REG_A0, at + 1)
                handler = struct.unpack_from(">I", rom, DISPATCH + op)[0]
                run(handler)
                following = path[position + 1] if position + 1 < len(path) else pose["stop"]
                if cpu.reg_read(UC_M68K_REG_A0) != following:
                    raise ValueError(f"Model {model['index']} command {at:#x} consumed/jumped to wrong byte")
                steps += 1
                branch_steps += int(op in (0x68, 0x6C, 0x74))
            expected = bytearray(seed)
            for i, vector in pose["vertices"].items():
                struct.pack_into(">hhh", expected, i * 16, *vector)
            actual = bytes(cpu.mem_read(WORK, 4096))
            if actual != expected:
                bad = [i for i in range(256) if actual[i * 16:(i + 1) * 16] != expected[i * 16:(i + 1) * 16]]
                raise ValueError(f"Model {model['index']} FC={pose['detail_flag_fc']} native vertex mismatch: {bad}")
            if cpu.reg_read(UC_M68K_REG_A7) != STACK:
                raise ValueError("Native construction did not balance the original stack")
            compared += 4096
            poses.append({"index": model["index"], "detail_flag_fc": pose["detail_flag_fc"],
                          "vertices": len(pose["vertices"]), "workspace_sha256": hashlib.sha256(actual).hexdigest()})

    unique = {c['offset']: c for m in catalog['models'] for c in m['commands']}
    branch_cases, polygon_cases, line_cases, sort_cases = 0, 0, 0, 0
    for c in unique.values():
        op, at = c['opcode'], c['offset']
        if op not in POLYGONS | {0x60, 0x64, 0x68, 0x6C, 0x74, 0x8C, 0x90, 0x94, 0xEC}:
            continue
        for flag in (0, 1):
            reset()
            cpu.mem_write(WORK, b'\xff' * 4096)  # Explicitly clipped projected slots, no raster writes.
            cpu.mem_write(0xFFFFE536, struct.pack('>I', FLAGS))
            cpu.mem_write(FLAGS, bytes([flag]) * 256)
            cpu.reg_write(UC_M68K_REG_A1, WORK)
            cpu.reg_write(UC_M68K_REG_D0, op)
            cpu.reg_write(UC_M68K_REG_A0, at + 1)
            if op == 0xEC:
                if flag:
                    continue
                cpu.mem_write(WORK, bytes(4096))  # Equal depths; observe every sorted subprogram call.
                cpu.reg_write(UC_M68K_REG_A0, at + 2)
                called = []
                def subprogram(machine, address, size, _data):
                    if address != STOP:
                        return
                    sp = machine.reg_read(UC_M68K_REG_A7)
                    if sp == STACK:
                        machine.emu_stop()
                        return
                    called.append(machine.reg_read(UC_M68K_REG_A0))
                    return_pc = struct.unpack('>I', bytes(machine.mem_read(sp, 4)))[0]
                    machine.reg_write(UC_M68K_REG_A7, sp + 4)
                    machine.reg_write(UC_M68K_REG_PC, return_pc)
                hook = cpu.hook_add(UC_HOOK_CODE, subprogram, begin=STOP, end=STOP)
                try:
                    cpu.emu_start(0x10630, STOP + 16, count=20000)
                finally:
                    cpu.hook_del(hook)
                if cpu.reg_read(UC_M68K_REG_PC) != STOP or sorted(called) != sorted(c['targets']):
                    raise ValueError(f'Original sorted subprogram targets differ at {at:#x}')
                expected, expected_stack = c['end'], []
                sort_cases += 1
            else:
                run(struct.unpack_from('>I', rom, DISPATCH + op)[0])
                expected, expected_stack = c['end'], []
                if op == 0x74 or op == 0x68 and flag or op == 0x6C and not flag or op == 0x64 and not flag:
                    expected = c['targets'][0]
                if op == 0x60:
                    expected = c['end'] if flag else c['targets'][1]
                    expected_stack = [c['targets'][1] if flag else c['end'], c['targets'][0]]
                elif op == 0x64 and flag:
                    expected_stack = [c['targets'][1]]
                if op in POLYGONS:
                    polygon_cases += 1
                elif op in (0x8C, 0x90, 0x94):
                    line_cases += 1
                else:
                    branch_cases += 1
            if cpu.reg_read(UC_M68K_REG_A0) != expected:
                raise ValueError(f'Original command {at:#x}, flag {flag}, has different next byte')
            sp = cpu.reg_read(UC_M68K_REG_A7)
            stack = [struct.unpack('>I', bytes(cpu.mem_read(sp + i * 4, 4)))[0] for i in range(len(expected_stack))]
            if sp != STACK - len(expected_stack) * 4 or stack != expected_stack:
                raise ValueError(f'Original bytecode continuation stack differs at {at:#x}')

    # Original span-fill material translation, including both pattern rows.
    # Stop before any raster write; this verifies the exact lookup instructions.
    materials = sorted({p["material"] for m in catalog["models"] for pose in m["poses"]
                        for p in pose["polygons"] + pose["lines"]})
    for material in materials:
        reset()
        cpu.mem_write(0xFFFFE54E, struct.pack(">I", MATERIAL_MAP))
        cpu.reg_write(UC_M68K_REG_D2, material)
        run(0x4C7A, 0x4C8C)
        actual = struct.pack(">II", cpu.reg_read(UC_M68K_REG_D7), cpu.reg_read(UC_M68K_REG_A6))
        pattern = rom[MATERIAL_MAP + material]
        if actual != rom[PATTERNS + pattern * 8:PATTERNS + pattern * 8 + 8]:
            raise ValueError("Native material-pattern translation differs")
    return {"rom_sha256": ROM_HASH, "cpu": "Unicorn M68000, read/execute-only original ROM",
            "directory_pointers": 188, "directory_extents": 188,
            "neutral_poses": poses, "executed_construction_commands": steps,
            "executed_construction_branches": branch_steps, "compared_workspace_bytes": compared,
            "control_branch_cases": branch_cases, "clipped_polygon_cases": polygon_cases,
            "clipped_line_cases": line_cases, "sorted_subprogram_cases": sort_cases,
            "material_patterns": len(materials), "mismatches": 0,
            "scope": "Synthetic neutral-pose construction, control-flow byte bases/stacks, equal-depth sort call targets, clipped polygon/line consumption, workspace guards and ordinary material lookup. No projection, visible rasterization, nontrivial depth sorting, live animation or game-parity claim."}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    if a.output.exists():
        p.error("output must be a fresh report path")
    result = verify(a.rom.read_bytes())
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "neutral_poses"}))


if __name__ == "__main__":
    main()
