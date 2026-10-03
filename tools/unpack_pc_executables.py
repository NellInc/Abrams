#!/usr/bin/env python3
"""Decode the supplied PC EXEPACK variant for local static analysis.

Outputs load-relative bytes and relocation metadata, never replacement EXEs.
Only the observed 16-byte header / 277-byte stub is supported. This deliberately
rejects other EXEPACK variants rather than guessing their layout.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

STUB_SHA256 = "a146eddf8f6523a9b05e070f126a755e5b5c4444181258faa3939010fd2d61b3"
RELOC_OFFSET = 0x125
NAMES = ("START", "BRIEF", "SIM", "END")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def decode_runs(packed: bytes, size: int) -> tuple[bytes, dict]:
    """Follow the backwards B0/B2 loop at stub offsets 0050..0094.

Reject overwrites of unread input and require the remaining prefix to coincide.
These constraints hold for all four supplied executables. Broader EXEPACK
behaviour is intentionally outside this bounded decoder's contract.
    """
    if not 0 < len(packed) <= size <= 1024 * 1024:
        raise ValueError("invalid compressed or decoded size")
    output = bytearray(packed) + bytearray(size - len(packed))
    src, dst = len(packed), size
    while src and packed[src - 1] == 255 and len(packed) - src < 15:
        src -= 1
    padding = len(packed) - src
    commands = []
    while True:
        if src < 3:
            raise ValueError("truncated command or missing terminal bit")
        command_at = src - 1
        opcode = packed[command_at]
        src -= 3
        length = int.from_bytes(packed[src:src + 2], "little")
        if length > dst:
            raise ValueError("command exceeds decoded bounds")
        dst -= length
        if opcode & 254 == 0xB0:
            src -= 1
            if src < 0 or dst < src:
                raise ValueError("fill reads outside input or overwrites unread input")
            output[dst:dst + length] = bytes([packed[src]]) * length
        elif opcode & 254 == 0xB2:
            src -= length
            if src < 0 or dst < src:
                raise ValueError("copy reads outside input or overwrites unread input")
            output[dst:dst + length] = packed[src:src + length]
        else:
            raise ValueError(f"unsupported EXEPACK command {opcode:#x}")
        commands.append({"packed_offset": command_at, "opcode": opcode,
                         "length": length, "decoded_offset": dst})
        if opcode & 1:
            break
    if src != dst:
        raise ValueError("uncompressed prefix boundaries differ")
    return bytes(output), {"padding_bytes": padding, "prefix_bytes": src,
                           "commands": commands}


def unpack(data: bytes) -> tuple[bytes, dict]:
    if len(data) < 28:
        raise ValueError("truncated MZ header")
    h = struct.unpack_from("<14H", data)
    if h[0] != 0x5A4D or h[3] != 0 or h[10] != 16 or h[13] != 0:
        raise ValueError("unsupported MZ/EXEPACK layout")
    if not h[2] or h[1] > 511:
        raise ValueError("invalid MZ file length")
    declared = (h[2] - 1) * 512 + (h[1] or 512)
    header_end = h[4] * 16
    packed_end = header_end + h[11] * 16
    if declared != len(data) or not 28 <= header_end < packed_end <= len(data) - RELOC_OFFSET:
        raise ValueError("MZ extent does not match file")
    ip, cs, mem, block_size, sp, ss, paragraphs, signature = struct.unpack_from("<8H", data, packed_end)
    if mem != 0 or signature != 0x4252 or packed_end + block_size != len(data):
        raise ValueError("invalid EXEPACK metadata")
    stub = data[packed_end + 16:packed_end + RELOC_OFFSET]
    if sha256(stub) != STUB_SHA256:
        raise ValueError("unknown decompression stub")
    decoded, run_info = decode_runs(data[header_end:packed_end], paragraphs * 16)
    if cs * 16 + ip >= len(decoded):
        raise ValueError("entry point is outside load image")
    # The stub consumes sixteen count/offset groups, one per 64 KiB window.
    at = packed_end + RELOC_OFFSET
    relocations = []
    for group in range(16):
        if at + 2 > len(data):
            raise ValueError("truncated relocation count")
        count = int.from_bytes(data[at:at + 2], "little")
        at += 2
        if at + 2 * count > len(data):
            raise ValueError("truncated relocation offsets")
        for offset, in struct.iter_unpack("<H", data[at:at + 2 * count]):
            linear = group * 65536 + offset
            if linear + 2 > len(decoded):
                raise ValueError("relocation word outside load image")
            relocations.append({"segment": group * 4096, "offset": offset,
                                "load_offset": linear})
        at += 2 * count
    if at != len(data):
        raise ValueError("unparsed relocation tail")
    return decoded, {
        "source_sha256": sha256(data), "decoded_sha256": sha256(decoded),
        "source_bytes": len(data), "decoded_bytes": len(decoded),
        "mz_header_bytes": header_end, "exepack_header_file_offset": packed_end,
        "stub_sha256": STUB_SHA256, "entry": {"cs": cs, "ip": ip},
        "stack": {"ss": ss, "sp": sp}, "relocations": relocations,
        "address_basis": "unrelocated load image; segment * 16 + offset",
        **run_info,
    }


def compare_independent(decoded: bytes, report: dict, exe: bytes) -> None:
    """Compare a separate unpacker's MZ output, ignoring header padding/checksum."""
    if len(exe) < 28:
        raise ValueError("truncated independent MZ")
    h = struct.unpack_from("<14H", exe)
    if (h[0] != 0x5A4D or h[4] * 16 < 28 or h[12] < 28
            or h[12] + h[3] * 4 > h[4] * 16):
        raise ValueError("invalid independent MZ layout")
    if exe[h[4] * 16:] != decoded:
        raise ValueError("independent load-image comparison failed")
    if (h[11], h[10], h[7], h[8]) != (
            report["entry"]["cs"], report["entry"]["ip"],
            report["stack"]["ss"], report["stack"]["sp"]):
        raise ValueError("independent entry/stack comparison failed")
    theirs = sorted(s * 16 + o for o, s in struct.iter_unpack(
        "<HH", exe[h[12]:h[12] + h[3] * 4]))
    if theirs != sorted(r["load_offset"] for r in report["relocations"]):
        raise ValueError("independent relocation comparison failed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path("GAME"))
    parser.add_argument("--out", type=Path, default=Path("reference/pc-unpacked/decoded"))
    parser.add_argument("--compare-dir", type=Path)
    args = parser.parse_args()
    try:
        from tools.source_guard import inside_source
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from source_guard import inside_source
    try:
        source = args.root.resolve()  # Case, symlink and ".." aliases of the source directory count as inside it.
        if inside_source(args.out, source.parent, (source.name,)):
            raise ValueError("outputs must be outside original reference directory")
        # Validate the entire batch before writing any output.
        batch = []
        for name in NAMES:
            decoded, report = unpack((args.root / f"{name}.EXE").read_bytes())
            if args.compare_dir:
                other = (args.compare_dir / f"{name}.EXE").read_bytes()
                compare_independent(decoded, report, other)
                report["independent_comparison"] = {
                    "status": "identical load image, relocation targets, entry and stack",
                    "exe_sha256": sha256(other)}
            batch.append((name, decoded, report))
        args.out.mkdir(parents=True, exist_ok=True)
        for name, decoded, report in batch:
            (args.out / f"{name}.bin").write_bytes(decoded)
            (args.out / f"{name}.json").write_text(json.dumps(report, indent=2) + "\n")
            print(f"{name}: {len(decoded)} decoded bytes, {len(report['relocations'])} relocations")
        return 0
    except (ValueError, OSError) as error:
        parser.exit(2, f"error: {error}\n")


if __name__ == "__main__":
    raise SystemExit(main())
