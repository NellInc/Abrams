#!/usr/bin/env python3
"""Read-only, bounded inspection of the supplied DOS resource bytes.

No original program is executed. Names of unknown fields deliberately express
storage, not guessed gameplay semantics. All offsets are zero-based.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import struct
from pathlib import Path

MAX_DECODED_SIZE = 16 * 1024 * 1024


def decode_resource(data: bytes, max_output: int = MAX_DECODED_SIZE) -> bytes:
    """Decode observed type-2 resources, rejecting malformed/unsupported input.

    Header: 02 + u32le output length. LZW: LSB-first, 9..12 bits, codes
    0..255 literals, 256 reset, 257 first dictionary code. Reset pads to an
    eight-code block boundary relative to the current width's starting point.
    """
    if len(data) < 5 or data[0] != 2:
        raise ValueError("expected type-2 resource header")
    expected = int.from_bytes(data[1:5], "little")
    if expected > max_output:
        raise ValueError("declared output exceeds safety limit")
    payload = data[5:]
    output = bytearray()
    dictionary = {i: bytes([i]) for i in range(256)}
    next_code, width, bitpos, block_start = 257, 9, 0, 0
    previous = b""
    while len(output) < expected:
        if bitpos + width > len(payload) * 8:
            raise ValueError("truncated code stream")
        code = (int.from_bytes(payload[bitpos // 8:bitpos // 8 + 3], "little")
                >> (bitpos % 8)) & ((1 << width) - 1)
        bitpos += width
        if code == 256:
            block_bits = 8 * width
            bitpos = block_start + ((bitpos - block_start + block_bits - 1)
                                    // block_bits) * block_bits
            block_start = bitpos
            dictionary = {i: bytes([i]) for i in range(256)}
            next_code, width, previous = 257, 9, b""
            continue
        if code in dictionary:
            entry = dictionary[code]
        elif code == next_code and previous:
            entry = previous + previous[:1]
        else:
            raise ValueError(f"invalid dictionary code {code} at payload bit {bitpos - width}")
        if len(output) + len(entry) > expected:
            raise ValueError("decoded output exceeds declared length")
        output.extend(entry)
        if previous and next_code < 4096:
            dictionary[next_code] = previous + entry[:1]
            next_code += 1
        previous = entry
        if next_code == 1 << width and width < 12:
            width += 1
            block_start = bitpos
    if len(payload) * 8 - bitpos > 7:
        raise ValueError("unexpected trailing resource bytes")
    return bytes(output)


def ascii_runs(data: bytes, minimum: int = 8) -> list[dict]:
    if minimum < 1:
        raise ValueError("minimum must be positive")
    return [{"offset": m.start(), "offset_hex": hex(m.start()),
             "text": m.group().decode("ascii")}
            for m in re.finditer(rb"[ -~]{" + str(minimum).encode() + rb",}", data)]



def parse_world(data: bytes) -> dict:
    """Decode the 64x64 static-object directory used by SIM 0b4d:2bd0.

    The high bit selects a packed nibble position; otherwise three i16 words
    follow. Shape 127 is an unused slot. Units, materials and visibility are
    deliberately not inferred from these storage/placement facts.
    """
    if len(data) < 8192:
        raise ValueError("world directory truncated")
    pointers = struct.unpack("<4096H", data[:8192])
    cursor = 8192
    records = []
    for index, pointer in enumerate(pointers):
        if not pointer:
            continue
        if pointer != cursor or cursor >= len(data):
            raise ValueError("world pointer does not match sequential record boundary")
        count = data[cursor]
        if not 1 <= count <= 4:
            raise ValueError("empty or truncated world list")
        cursor += 1
        row, column = divmod(index, 64)
        entries = []
        for _ in range(count):
            if cursor >= len(data):
                raise ValueError("truncated world entry")
            flags = data[cursor]
            compact = bool(flags & 128)
            end = cursor + (2 if compact else 7)
            if end > len(data):
                raise ValueError("truncated world position")
            if compact:
                position = data[cursor + 1]
                x, y, z = (position >> 4) * 256, (position & 15) * 256, 0
                world = [column * 4096 + x, (row + 1) * 4096 - y, z]
            else:
                x, y, z = struct.unpack_from("<3h", data, cursor + 1)
                world = [column * 4096 + 2048 + x, row * 4096 + 2048 - y, z]
            entries.append({"offset": cursor, "shape_index": flags & 127,
                            "compact": compact, "unused": flags & 127 == 127,
                            "world_position_raw": world})
            cursor = end
        records.append({"directory_index": index, "directory_offset": index * 2,
                        "row": row, "column": column,
                        "offset": pointer, "count": count, "entries": entries})
    if cursor != len(data):
        raise ValueError("unreferenced world tail")
    return {"directory_entries": 4096, "rows": 64, "columns": 64,
            "cell_size_raw": 4096, "records": records,
            "axes": ["east", "south", "original_height"],
            "evidence": "SIM 0b4d:2af2/2bd0 placement semantics; physical units and visibility unresolved"}


def parse_scenario(data: bytes) -> dict:
    """Expose repeated byte fields without claiming object types or units."""
    if len(data) < 30:
        raise ValueError("scenario header truncated")
    count = int.from_bytes(data[28:30], "little")
    end = 30 + count * 42
    if end + 2 > len(data):
        raise ValueError("scenario record array truncated")
    records = []
    for index in range(count):
        start = 30 + index * 42
        raw = data[start:start + 42]
        records.append({"index": index, "offset": start, "hex": raw.hex(" "),
                        "word_0": int.from_bytes(raw[:2], "little"),
                        "byte_22": raw[22], "byte_23": raw[23],
                        "byte_30": raw[30], "byte_31": raw[31]})
    message_count = int.from_bytes(data[end:end + 2], "little")
    text_start = end + 2 + message_count * 3 + 2
    if text_start > len(data):
        raise ValueError("scenario message directory truncated")
    text_size = int.from_bytes(data[text_start - 2:text_start], "little")
    if text_start + text_size > len(data):
        raise ValueError("scenario message strings truncated")
    messages = []
    for index in range(message_count):
        entry = end + 2 + index * 3
        relative = int.from_bytes(data[entry + 1:entry + 3], "little")
        if relative >= text_size:
            raise ValueError("scenario message offset outside string block")
        offset = text_start + relative
        stop = data.find(b"\0", offset, text_start + text_size)
        if stop < 0:
            raise ValueError("unterminated scenario message")
        try:
            text = data[offset:stop].decode("ascii")
        except UnicodeDecodeError as error:
            raise ValueError("non-ASCII scenario message") from error
        messages.append({"index": index, "directory_offset": entry,
                         "flag_byte": data[entry], "offset": offset, "text": text})
    return {"record_count_offset": 28, "record_count": count, "record_stride": 42,
            "records": records, "message_directory_offset": end,
            "messages": messages, "unparsed_tail_offset": text_start + text_size,
            "unparsed_tail_size": len(data) - text_start - text_size,
            "evidence": "record and message boundaries verified; record semantics unverified"}


def parse_shape_table(data: bytes) -> dict:
    if len(data) < 4:
        raise ValueError("shape table truncated")
    first = int.from_bytes(data[:2], "little")
    if first < 4 or first % 2 or first > len(data):
        raise ValueError("invalid shape directory boundary")
    words = struct.unpack("<" + "H" * (first // 2), data[:first])
    if words[-1] != 65535:
        raise ValueError("missing shape directory sentinel")
    offsets = words[:-1]
    if (offsets[0] != first or any(a >= b for a, b in zip(offsets, offsets[1:]))
            or offsets[-1] >= len(data)):
        raise ValueError("invalid shape offsets")
    ends = (*offsets[1:], len(data))
    return {"count": len(offsets), "sentinel_offset": first - 2,
            "records": [{"index": i, "offset": a, "size": b - a}
                        for i, (a, b) in enumerate(zip(offsets, ends))],
            "evidence": "monotone u16 offsets and sentinel observed; shape record contents unparsed"}


def inspect_file(path: Path) -> dict:
    data = path.read_bytes()
    result = {"file": path.name, "size": len(data),
              "sha256": hashlib.sha256(data).hexdigest(),
              "header_hex": data[:32].hex(" "), "evidence": "observed bytes"}
    if data[:1] == b"\x02":
        decoded = decode_resource(data)
        result.update({"format": "type-2 LZW", "decoded_size": len(decoded),
                       "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
                       "decoded_prefix_hex": decoded[:128].hex(" "),
                       "decoded_ascii": ascii_runs(decoded),
                       "decoded_u16le_prefix": list(struct.unpack(
                           "<" + "H" * (min(len(decoded), 128) // 2),
                           decoded[:min(len(decoded), 128) // 2 * 2]))})
        if path.suffix == ".WLD":
            result["world"] = parse_world(decoded)
        elif path.suffix == ".SSS":
            result["scenario"] = parse_scenario(decoded)
        elif path.name == "SHAPE.TBL":
            result["shape_table"] = parse_shape_table(decoded)
    elif data[:2] == b"MZ":
        if len(data) < 28:
            raise ValueError("truncated MZ header")
        result.update({"format": "DOS MZ", "ascii": ascii_runs(data, 12),
                       "header_u16le": list(struct.unpack("<14H", data[:28]))})
    else:
        result.update({"format": "unclassified", "ascii": ascii_runs(data)})
        if len(data) <= 128 and len(data) % 2 == 0:
            result["u16le"] = list(struct.unpack("<" + "H" * (len(data) // 2), data))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--game", type=Path, default=Path("GAME"))
    parser.add_argument("--output", type=Path, default=Path("reference/reports/scenarios.json"))
    parser.add_argument("--extract", action="store_true", help="write decoded bytes beside report")
    args = parser.parse_args()
    names = sorted({p.name for pattern in ("SNARIO*.SSS", "SNARIO*.WLD", "SHAPE.*", "SIM.ARM", "SIM.EXE", "BRIEF.EXE")
                    for p in args.game.glob(pattern)})
    if not names:
        parser.error("no matching reference files")
    # Resolve every input and output before writing. Never overwrite original data.
    try:
        from tools.source_guard import inside_source
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from source_guard import inside_source
    game = args.game.resolve()  # Case, symlink and ".." aliases of the game directory count as inside it.
    if inside_source(args.output, game.parent, (game.name,)):
        parser.error("report output must be outside GAME")
    reports = [inspect_file(args.game / name) for name in names]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"schema": 2, "files": reports}, indent=2) + "\n")
    if args.extract:
        for name in names:
            data = (args.game / name).read_bytes()
            if data[:1] == b"\x02":
                (args.output.parent / (name + ".decoded")).write_bytes(decode_resource(data))
    print(f"Inspected {len(reports)} files; report: {args.output}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
