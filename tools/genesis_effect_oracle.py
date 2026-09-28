#!/usr/bin/env python3
"""Execute the original Genesis effect blitter in an isolated M68000 oracle.

No changes to the live core, ROM or reference state. This checks source decoding
against original instructions; it does not prove live animation timing.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct

from unicorn import Uc, UC_ARCH_M68K, UC_MODE_BIG_ENDIAN
from unicorn.m68k_const import (UC_CPU_M68K_M68000, UC_M68K_REG_SR,
    UC_M68K_REG_A0, UC_M68K_REG_A7, UC_M68K_REG_D0, UC_M68K_REG_D1,
    UC_M68K_REG_PC)
try:
    from tools.extract_genesis_effects import ROOT, ROM_HASH, TABLE, decode_effects
except ModuleNotFoundError:
    from extract_genesis_effects import ROOT, ROM_HASH, TABLE, decode_effects


def verify(rom):
    if hashlib.sha256(rom).hexdigest() != ROM_HASH:
        raise ValueError("Unrecognized original ROM")
    cpu = Uc(UC_ARCH_M68K, UC_MODE_BIG_ENDIAN)
    cpu.ctl_set_cpu_model(UC_CPU_M68K_M68000)
    cpu.mem_map(0, 0x80000)
    cpu.mem_write(0, rom)
    cpu.mem_map(0xFFFF0000, 0x10000)
    # An 80x64 native column-tiled backing surface, with original lookup ABI.
    cpu.mem_write(0xFFFFE592, struct.pack(">IH", 0xFFFFE000, 0xF000))
    cpu.mem_write(0xFFFFE000, struct.pack(">4h", 0, 0, 79, 63))
    cpu.mem_write(0xFFFFF000, struct.pack(">HI", 0xF100, 0xFFFF0000))
    cpu.mem_write(0xFFFFF100, struct.pack(">10H", *[x * 256 for x in range(10)]))
    positions = [(8 + phase, 8) for phase in range(8)] + [(0, 0), (64, 54), (12, -3), (-8, 10), (80, 0), (0, 64)]
    cases, compared = 0, 0
    for sprite in decode_effects(rom):
        for background in (0, 5, 15):
            for x, y in positions:
                backing = bytes([background * 17]) * 2560
                cpu.mem_write(0xFFFF0000, backing)
                cpu.reg_write(UC_M68K_REG_SR, 0x2000)
                cpu.reg_write(UC_M68K_REG_A7, 0xFFFFDF00)
                cpu.mem_write(0xFFFFDF00, struct.pack(">I", 0x70000))
                cpu.reg_write(UC_M68K_REG_A0, TABLE + sprite["index"] * 8)
                cpu.reg_write(UC_M68K_REG_D0, x & 0xFFFFFFFF)
                cpu.reg_write(UC_M68K_REG_D1, y & 0xFFFFFFFF)
                cpu.emu_start(0x5988, 0x70000, count=100000)
                if cpu.reg_read(UC_M68K_REG_PC) != 0x70000:
                    raise ValueError("Original blitter did not return within its instruction bound")
                result = bytes(cpu.mem_read(0xFFFF0000, 2560))
                for py in range(64):
                    for px in range(80):
                        expected = background
                        sx, sy = px - x, py - y
                        if 0 <= sx < sprite["width"] and 0 <= sy < sprite["height"]:
                            source = sy * sprite["width"] + sx
                            if sprite["opaque"][source]:
                                expected = sprite["pixels"][source]
                        address = (px // 8 * 64 + py) * 4 + px % 8 // 2
                        actual = result[address] >> (4 if px % 2 == 0 else 0) & 15
                        if actual != expected:
                            raise ValueError(f"Effect {sprite['index']} at {(x, y)}, background {background}: pixel {(px, py)} is {actual}, expected {expected}")
                compared += 80 * 64
                cases += 1
    return {"rom_sha256": ROM_HASH, "entry": "0x5988", "return": "0x70000",
            "cpu": "Unicorn M68000, original instructions unchanged",
            "effects": 64, "positions": positions, "backgrounds": [0, 5, 15],
            "cases": cases, "compared_pixels": compared, "mismatched_pixels": 0,
            "scope": "Source decode, nibble alignment, opaque/preserve behavior and bounded clipping. Separate from native live timing and palette proof."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("output must be a fresh report path")
    result = verify(args.rom.read_bytes())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result))


if __name__ == "__main__":
    main()
