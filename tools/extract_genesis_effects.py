#!/usr/bin/env python3
"""Extract the pinned Genesis ROM's 64 masked software-rendered effects.

These are original resource pixels, not screenshot crops or hardware sprites.
The original PC executable continues to own selection, timing and visibility.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
ROM_HASH = "ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea"
TABLE = 0x431BE
COUNT = 64
DATA_START = 0x3C09E


def decode_effects(rom: bytes, table=TABLE, count=COUNT):
    """Decode BE width/height/pointer descriptors and color/preserve word pairs.

    ROM 109c4 selects an eight-byte descriptor. ROM 5988 reads it; 5a72
    combines each four-pixel color word with the destination AND mask word.
    Canonical source masks contain only whole opaque/preserved nibbles.
    """
    if not 1 <= count <= 256 or table < 0 or table + count * 8 > len(rom):
        raise ValueError("Invalid Genesis effect directory")
    images = []
    for index in range(count):
        width, height, offset = struct.unpack_from(">HHI", rom, table + index * 8)
        if not 1 <= width <= 320 or width % 4 or not 1 <= height <= 224:
            raise ValueError("Unsupported Genesis effect dimensions")
        size = width * height  # Four pixels per four-byte color/mask pair.
        if offset + size > len(rom):
            raise ValueError("Truncated Genesis effect pixels")
        pixels, opaque = [], []
        for at in range(offset, offset + size, 4):
            color, preserve = struct.unpack_from(">HH", rom, at)
            for shift in (12, 8, 4, 0):
                pixel, mask = color >> shift & 15, preserve >> shift & 15
                if mask not in (0, 15) or (mask and pixel):
                    raise ValueError("Unsupported partial or overlapping effect mask")
                pixels.append(pixel)
                opaque.append(mask == 0)
        images.append({"index": index, "width": width, "height": height,
                       "offset": offset, "byte_count": size,
                       "sha256": hashlib.sha256(rom[offset:offset + size]).hexdigest(),
                       "pixels": pixels, "opaque": opaque})
    return images


def export_effects(rom_path: Path, capture: Path, output: Path, palette_bank: int):
    # Keep the pure source decoder usable by the isolated CPU-oracle runtime.
    from PIL import Image, ImageDraw
    try:
        from tools.extract_genesis_vdp import VDP
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from extract_genesis_vdp import VDP

    rom = rom_path.read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_HASH:
        raise ValueError("Unrecognized Genesis ROM; offsets are version-specific")
    if not 0 <= palette_bank <= 3:
        raise ValueError("Palette bank must be 0 through 3")
    vdp = VDP(capture)
    if vdp.receipt["rom_sha256"] != ROM_HASH:
        raise ValueError("Palette capture belongs to a different ROM")
    images = decode_effects(rom)
    at = DATA_START
    for sprite in images:
        if sprite["offset"] != at:
            raise ValueError("Effect data is not the expected contiguous resource")
        at += sprite["byte_count"]
    if at != TABLE:
        raise ValueError("Effect resource does not terminate at its directory")
    output.mkdir(parents=True, exist_ok=False)
    palette = vdp.palette[palette_bank * 16:(palette_bank + 1) * 16]
    sheet = Image.new("RGB", (1024, 1024), "#293338")
    draw = ImageDraw.Draw(sheet)
    for sprite in images:
        width, height = sprite["width"], sprite["height"]
        im = Image.new("RGBA", (width, height))
        im.putdata([(*palette[color], 255 if opaque else 0)
                    for color, opaque in zip(sprite["pixels"], sprite["opaque"])])
        sprite["image"] = f"effect-{sprite['index']:02d}.png"
        im.save(output / sprite["image"])
        x, y = sprite["index"] % 8 * 128, sprite["index"] // 8 * 128
        draw.text((x + 3, y + 3), f"{sprite['index']:02d}  {width} x {height}", fill="white")
        scale = min(3, 120 // width, 108 // height)
        preview = im.resize((width * scale, height * scale), Image.Resampling.NEAREST)
        sheet.paste(preview, (x + 3, y + 18), preview)
    sheet.save(output / "contact-sheet.png")
    manifest = {"source": str(rom_path), "rom_sha256": ROM_HASH,
                "directory_offset": TABLE, "data_offset": DATA_START,
                "data_bytes": TABLE - DATA_START,
                "format": "BE u16 width, u16 height, u32 pointer; row-major color/preserve u16 pairs; high nibble left",
                "palette_capture": str(capture),
                "palette_receipt_sha256": hashlib.sha256((capture / "receipt.json").read_bytes()).hexdigest(),
                "palette_bank": palette_bank, "palette_rgb": palette,
                "scope": "Native ROM pixels and explicit masks. Palette bank is an explicit extraction choice; native appearance requires separate visible-frame verification. No animation-timing or distribution claim.",
                "images": images,
                "files": {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in sorted(output.iterdir()) if p.is_file()}}
    (output / "effects.json").write_text(json.dumps(manifest, indent=2) + "\n")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    parser.add_argument("--capture", type=Path, required=True)
    parser.add_argument("--palette-bank", type=int, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        from tools.source_guard import inside_source
    except ModuleNotFoundError as error:
        if error.name != 'tools': raise
        from source_guard import inside_source
    if inside_source(args.output, ROOT, ("GENESIS",)):
        parser.error("output must be outside GENESIS")
    manifest = export_effects(args.rom, args.capture, args.output, args.palette_bank)
    print(f"Extracted {len(manifest['images'])} original Genesis effects: {args.output}")


if __name__ == "__main__":
    main()
