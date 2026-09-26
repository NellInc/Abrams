#!/usr/bin/env python3
"""Decode captured Genesis Plus GX VDP memory into editable PNG resources.

Exports lossless tiles, full nametable planes, palettes and linked sprites.
The bounded compositor validates zero-scroll, normal-intensity H40 captures.
It refuses to claim equivalence for unsupported scrolling or video modes.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
from PIL import Image, ImageChops, ImageDraw


def word(data: bytes, offset: int, endian: str) -> int:
    return struct.unpack_from("<H" if endian == "little" else ">H", data, offset)[0]


def color_rgb565(packed: int) -> tuple[int, int, int]:
    """Match core MAKE_PIXEL normal intensity and frontend RGB565 conversion."""
    r, g, b = [(packed >> shift & 7) * 2 for shift in (0, 3, 6)]
    pixel = r << 12 | (r >> 3) << 11 | g << 7 | (g >> 2) << 5 | b << 1 | b >> 3
    return ((pixel >> 11 & 31) * 255 // 31,
            (pixel >> 5 & 63) * 255 // 63, (pixel & 31) * 255 // 31)


def tile_indices(vram: bytes, index: int, endian: str) -> list[int]:
    if not 0 <= index < 2048 or len(vram) != 65536:
        raise ValueError("VRAM must contain 2048 complete 32-byte tiles")
    raw = vram[index * 32:(index + 1) * 32]
    if endian == "little":
        raw = bytes(value for i in range(0, 32, 2) for value in (raw[i + 1], raw[i]))
    return [n for value in raw for n in (value >> 4, value & 15)]


class VDP:
    def __init__(self, capture: Path):
        self.capture = capture
        self.receipt = json.loads((capture / "receipt.json").read_text())
        self.endian = self.receipt["host_byteorder"]
        if self.endian not in ("little", "big") or self.receipt["pixel_format"] != 2:
            raise ValueError("This decoder requires a native-endian RGB565 core capture")
        for filename, digest in self.receipt["files"].items():
            if hashlib.sha256((capture / filename).read_bytes()).hexdigest() != digest:
                raise ValueError(f"Capture integrity check failed: {filename}")
        self.vram = (capture / "vram.bin").read_bytes()
        self.cram = (capture / "cram.bin").read_bytes()
        self.vsram = (capture / "vsram.bin").read_bytes()
        self.reg = (capture / "reg.bin").read_bytes()
        if [len(x) for x in (self.vram, self.cram, self.vsram, self.reg)] != [65536, 128, 128, 32]:
            raise ValueError("Incorrect VDP memory extent")
        self.palette = [color_rgb565(word(self.cram, i * 2, self.endian)) for i in range(64)]
        self.tiles = [tile_indices(self.vram, i, self.endian) for i in range(2048)]
        self.cache = {}

    def tile(self, descriptor: int) -> Image.Image:
        # Priority does not change tile pixels; retained separately in layer masks.
        descriptor &= 0x7FFF
        if descriptor not in self.cache:
            index = descriptor & 0x7FF
            palette = (descriptor >> 13 & 3) * 16
            result = Image.new("RGBA", (8, 8))
            result.putdata([(*self.palette[palette + n], 255 if n else 0) for n in self.tiles[index]])
            if descriptor & 0x800:
                result = result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if descriptor & 0x1000:
                result = result.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            self.cache[descriptor] = result
        return self.cache[descriptor]

    def plane(self, base: int, width: int, height: int, priority=None) -> Image.Image:
        if base + width * height * 2 > 65536:
            raise ValueError("Nametable exceeds VRAM")
        result = Image.new("RGBA", (width * 8, height * 8))
        for y in range(height):
            for x in range(width):
                entry = word(self.vram, base + (y * width + x) * 2, self.endian)
                if priority is None or bool(entry & 0x8000) == priority:
                    result.paste(self.tile(entry), (x * 8, y * 8))
        return result

    def sprites(self):
        base = (self.reg[5] & 0x7E) << 9
        index, seen = 0, set()
        result = []
        while index not in seen and len(seen) < 80:
            seen.add(index)
            offset = base + index * 8
            y, size_link, attribute, x = [word(self.vram, offset + n, self.endian) for n in (0, 2, 4, 6)]
            width, height = ((size_link >> 10) & 3) + 1, ((size_link >> 8) & 3) + 1
            sprite = Image.new("RGBA", (width * 8, height * 8))
            for tx in range(width):
                for ty in range(height):
                    entry = (attribute & 0x6000) | ((attribute + tx * height + ty) & 0x7FF)
                    sprite.paste(self.tile(entry), (tx * 8, ty * 8))
            if attribute & 0x800:
                sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if attribute & 0x1000:
                sprite = sprite.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            result.append((sprite, {"index": index, "x": (x & 511) - 128,
                                   "y": (y & 511) - 128, "priority": bool(attribute & 0x8000),
                                   "first_tile": attribute & 2047, "palette": attribute >> 13 & 3,
                                   "width_tiles": width, "height_tiles": height}))
            index = size_link & 127
            if index == 0:
                break
        return result

    def export(self, output: Path):
        output.mkdir(parents=True, exist_ok=False)
        width = [32, 64, 0, 128][self.reg[16] & 3]
        height = [32, 64, 0, 128][self.reg[16] >> 4 & 3]
        if not width or not height:
            raise ValueError("Unsupported nametable dimensions")
        bases = {"plane-a": (self.reg[2] & 0x38) << 10,
                 "plane-b": (self.reg[4] & 7) << 13,
                 "window": (self.reg[3] & 0x3C) << 10}
        planes = {}
        for name, base in bases.items():
            w, h = (64, 32) if name == "window" else (width, height)
            planes[name] = self.plane(base, w, h)
            planes[name].save(output / f"{name}.png")
        for palette in range(4):
            atlas = Image.new("RGBA", (256, 512))
            for i in range(2048):
                atlas.paste(self.tile(i | palette << 13), (i % 32 * 8, i // 32 * 8))
            atlas.save(output / f"tiles-palette-{palette}.png")
        swatch = Image.new("RGB", (512, 128))
        draw = ImageDraw.Draw(swatch)
        for i, color in enumerate(self.palette):
            draw.rectangle((i % 16 * 32, i // 16 * 32, i % 16 * 32 + 31, i // 16 * 32 + 31), fill=color)
        swatch.save(output / "palette.png")
        (output / "palette.gpl").write_text("GIMP Palette\nName: Abrams Genesis captured palette\nColumns: 16\n#\n" + "\n".join(f"{r:3} {g:3} {b:3}\tIndex {i}" for i, (r, g, b) in enumerate(self.palette)) + "\n")
        sprites = self.sprites()
        (output / "sprites").mkdir()
        for sprite, meta in sprites:
            sprite.save(output / "sprites" / f"sprite-{meta['index']:02}.png")
        manifest = {"capture": str(self.capture), "rom_sha256": self.receipt["rom_sha256"],
                    "planes": bases, "palette_rgb": self.palette,
                    "sprites": [m for _, m in sprites], "compositor": "unsupported"}
        # For the sampled static artwork: H40, no interlace/shadow, no scrolling,
        # full-screen window. Refuse to extrapolate this into a general emulator.
        scroll = (self.reg[13] & 63) << 10
        compatible = (self.reg[12] & 15) == 1 and self.reg[17] == 0x80 and self.reg[16] == 1
        compatible = compatible and not any(self.vsram[:80]) and not any(self.vram[scroll:scroll + 896])
        if compatible:
            source = Image.open(self.capture / "screen.png").convert("RGB")
            composite = Image.new("RGBA", source.size, (*self.palette[self.reg[7] & 63], 255))
            sprite_layer = Image.new("RGBA", source.size)
            # Earlier linked sprites win overlap, independent of BG priority.
            sprite_priority = Image.new("L", source.size)
            for sprite, meta in reversed(sprites):
                sprite_layer.alpha_composite(sprite, (meta["x"], meta["y"]))
                mask = sprite.getchannel("A")
                sprite_priority.paste(255 if meta["priority"] else 0, (meta["x"], meta["y"]), mask)
            low_sprite = sprite_layer.copy()
            low_sprite.putalpha(ImageChops.subtract(sprite_layer.getchannel("A"), sprite_priority))
            high_sprite = sprite_layer.copy()
            high_sprite.putalpha(ImageChops.multiply(sprite_layer.getchannel("A"), sprite_priority))
            for priority in (False, True):
                for name in ("plane-b", "window"):
                    composite.alpha_composite(self.plane(bases[name], 64, 32, priority).crop((0, 0, *source.size)))
                composite.alpha_composite(high_sprite if priority else low_sprite)
            composite = composite.convert("RGB")
            composite.save(output / "reconstructed-screen.png")
            difference = ImageChops.difference(composite, source)
            mismatches = sum(a != b for a, b in zip(composite.getdata(), source.getdata()))
            difference.save(output / "reconstruction-difference.png")
            manifest["compositor"] = {"compared_pixels": source.width * source.height,
                                      "mismatched_pixels": mismatches,
                                      "exact": mismatches == 0}
        (output / "extraction.json").write_text(json.dumps(manifest, indent=2) + "\n")
        print(output, manifest["compositor"])
        return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    VDP(args.capture).export(args.output)


if __name__ == "__main__":
    main()
