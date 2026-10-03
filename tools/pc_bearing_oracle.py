#!/usr/bin/env python3
"""Run original PC unpackers and bearing routines in an isolated 16-bit CPU.

Requires unicorn==2.1.4. No DOS, filesystem or hardware services are emulated;
interrupts fail closed. No original instruction is patched or substituted.
This proves only the listed routines, not whole-game behaviour or timing.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import struct

import unicorn
from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_INTR
from unicorn.x86_const import (
    UC_X86_REG_CS, UC_X86_REG_IP, UC_X86_REG_DS, UC_X86_REG_ES,
    UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_AX, UC_X86_REG_EFLAGS,
)

try:
    from tools.unpack_pc_executables import NAMES, unpack, sha256
    from tools.source_guard import inside_source
except ModuleNotFoundError as error:
    if error.name != 'tools': raise
    from unpack_pc_executables import NAMES, unpack, sha256
    from source_guard import inside_source

ROOT = Path(__file__).resolve().parents[1]
SIM_SHA256 = "9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099"
LOAD = 0x1000
DATA_SEGMENT = LOAD + 0x19E0
RETURN_IP = 0xFF00


def cpu() -> Uc:
    machine = Uc(UC_ARCH_X86, UC_MODE_16)
    machine.mem_map(0, 0x100000)

    def no_interrupt(_machine, number, _context):
        raise ValueError(f"unexpected interrupt {number:#x}; outside isolated oracle")

    machine.hook_add(UC_HOOK_INTR, no_interrupt)
    return machine


def set_registers(machine: Uc, values: tuple) -> None:
    for register, value in values:
        machine.reg_write(register, value)


def run_until(machine: Uc, start: int, end: int, count: int) -> None:
    machine.emu_start(start, end, timeout=5_000_000, count=count)
    actual = machine.reg_read(UC_X86_REG_CS) * 16 + machine.reg_read(UC_X86_REG_IP)
    if actual != end:
        raise ValueError(f"CPU did not reach expected return: {actual:#x} != {end:#x}")


def original_unpack(source: bytes) -> tuple[bytes, dict]:
    decoded, report = unpack(source)
    h = struct.unpack_from("<14H", source)
    machine = cpu()
    machine.mem_write(LOAD * 16, source[h[4] * 16:])
    set_registers(machine, (
        (UC_X86_REG_CS, LOAD + h[11]), (UC_X86_REG_IP, h[10]),
        (UC_X86_REG_DS, LOAD - 16), (UC_X86_REG_ES, LOAD - 16),
        (UC_X86_REG_SS, LOAD + h[7]), (UC_X86_REG_SP, h[8]),
        (UC_X86_REG_EFLAGS, 2),
    ))
    entry = (LOAD + report["entry"]["cs"]) * 16 + report["entry"]["ip"]
    run_until(machine, (LOAD + h[11]) * 16 + h[10], entry, 1_000_000)
    expected = bytearray(decoded)
    for item in report["relocations"]:
        at = item["load_offset"]
        word = int.from_bytes(expected[at:at + 2], "little")
        struct.pack_into("<H", expected, at, (word + LOAD) & 65535)
    actual = bytes(machine.mem_read(LOAD * 16, len(decoded)))
    if actual != expected:
        raise ValueError("original unpacker disagrees with decoded/relocated image")
    if (machine.reg_read(UC_X86_REG_SS), machine.reg_read(UC_X86_REG_SP)) != (
            LOAD + report["stack"]["ss"], report["stack"]["sp"]):
        raise ValueError("original unpacker restored an unexpected stack")
    if (machine.reg_read(UC_X86_REG_DS), machine.reg_read(UC_X86_REG_ES)) != (LOAD - 16, LOAD - 16):
        raise ValueError("original unpacker did not restore PSP segments")
    return actual, {"source_sha256": sha256(source), "decoded_sha256": sha256(decoded),
                    "relocated_sha256": sha256(actual), "decoded_bytes": len(decoded),
                    "relocations": len(report["relocations"]), "status": "exact CPU comparison"}


def bearing_rows(relocated_image: bytes) -> list:
    rows = []
    for internal_byte in range(256):
        # A fresh machine per input keeps calls independent. Only CPU/RAM are
        # provided. The original stack-allocation and multiply routines execute.
        machine = cpu()
        machine.mem_write(LOAD * 16, relocated_image)
        machine.mem_write(DATA_SEGMENT * 16 + 0x58EE, b"\0\0")  # CRT stack lower bound

        def call(offset):
            set_registers(machine, (
                (UC_X86_REG_CS, LOAD), (UC_X86_REG_DS, DATA_SEGMENT),
                (UC_X86_REG_ES, DATA_SEGMENT), (UC_X86_REG_SS, 0x4000),
                (UC_X86_REG_SP, 0xFFF0), (UC_X86_REG_EFLAGS, 2),
            ))
            machine.mem_write(0x4FFF0, struct.pack("<HH", RETURN_IP, internal_byte))
            run_until(machine, LOAD * 16 + offset, LOAD * 16 + RETURN_IP, 10_000)
            if machine.reg_read(UC_X86_REG_SP) != 0xFFF2:
                raise ValueError("original routine did not balance its stack")

        call(0x56EA)
        degrees = machine.reg_read(UC_X86_REG_AX)
        call(0x3D0E)
        raw = bytes(machine.mem_read(DATA_SEGMENT * 16 + 0x6472, 4))
        if raw[3] != 0 or not raw[:3].isdigit():
            raise ValueError("original bark did not produce three digits and NUL")
        digits = raw[:3].decode("ascii")
        if int(digits) != degrees:
            raise ValueError("original numeric and bark paths disagree")
        rows.append([internal_byte, degrees, digits])
    return rows


def run(root: Path) -> dict:
    if unicorn.__version__ != "2.1.4":
        raise ValueError("oracle requires pinned unicorn==2.1.4")
    receipts = {}
    for name in NAMES:
        source = (root / f"{name}.EXE").read_bytes()
        if name == "SIM" and sha256(source) != SIM_SHA256:
            raise ValueError("bearing addresses require the fingerprinted SIM.EXE")
        image, receipts[name] = original_unpack(source)
        if name == "SIM":
            rows = bearing_rows(image)
    return {"schema": 1, "engine": "unicorn-2.1.4/x86-16", "load_segment": LOAD,
            "source_sha256": SIM_SHA256, "unpackers": receipts,
            "routines": {"degrees": "0000:56ea", "hit_bark": "0000:3d0e"},
            "scope": "isolated original instructions, no DOS/device/timing parity",
            "row_fields": ["internal_byte", "display_degrees", "hit_bark_digits"], "rows": rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT / "GAME")
    parser.add_argument("--out", type=Path, default=ROOT / "artifacts/pc-bearing-oracle.json")
    parser.add_argument("--check-fixture", type=Path)
    args = parser.parse_args()
    source = args.root.resolve()
    if inside_source(args.out, source.parent, (source.name,)):
        parser.error("output must be outside original reference directory")
    result = run(args.root)
    if args.check_fixture and result != json.loads(args.check_fixture.read_text()):
        raise ValueError("fresh original CPU results differ from committed fixture")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print("PC_ORACLE: 4 original unpackers and all 256 bearing/bark inputs match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
