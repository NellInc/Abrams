import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from PIL import Image

from tools.extract_genesis_vdp import VDP, color_rgb565, tile_indices, word

ROOT = Path(__file__).resolve().parents[1]
ROM_HASH = "ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea"


def synthetic_capture(directory):
    vram, cram, reg = bytearray(65536), bytearray(128), bytearray(32)
    # Packed native little-endian colors; a deliberately asymmetric tile.
    for i in range(64):
        struct.pack_into("<H", cram, i * 2, i % 8)
    for y in range(8):
        canonical = bytes([0x12, 0x34, 0x56, 0x70]) if y == 0 else bytes(4)
        vram[32 + y * 4:36 + y * 4] = bytes([canonical[1], canonical[0], canonical[3], canonical[2]])
    reg[3], reg[4], reg[5], reg[12], reg[13], reg[16], reg[17] = 0x34, 7, 0x64, 0x81, 0x33, 1, 0x80
    files = {"vram.bin": bytes(vram), "cram.bin": bytes(cram),
             "vsram.bin": bytes(128), "reg.bin": bytes(reg)}
    for name, raw in files.items():
        (directory / name).write_bytes(raw)
    Image.new("RGB", (320, 224)).save(directory / "screen.png")
    receipt = {"host_byteorder": "little", "pixel_format": 2, "rom_sha256": "synthetic",
               "files": {name: hashlib.sha256(raw).hexdigest() for name, raw in files.items()}}
    (directory / "receipt.json").write_text(json.dumps(receipt))


class SyntheticGraphicsTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        synthetic_capture(self.root)
        self.vdp = VDP(self.root)

    def tearDown(self):
        self.temp.cleanup()

    def test_native_words_and_palette(self):
        self.assertEqual(word(bytes([0x34, 0x12]), 0, "little"), 0x1234)
        self.assertEqual(word(bytes([0x12, 0x34]), 0, "big"), 0x1234)
        self.assertEqual(color_rgb565(0), (0, 0, 0))
        self.assertEqual(color_rgb565(7), (238, 0, 0))
        self.assertEqual(color_rgb565(7 << 3), (0, 238, 0))
        self.assertEqual(color_rgb565(7 << 6), (0, 0, 238))

    def test_tile_nibble_order_both_endians(self):
        self.assertEqual(self.vdp.tiles[1][:8], [1, 2, 3, 4, 5, 6, 7, 0])
        raw = bytearray(self.vdp.vram)
        raw[32:36] = bytes([0x12, 0x34, 0x56, 0x70])
        self.assertEqual(tile_indices(bytes(raw), 1, "big")[:8], [1, 2, 3, 4, 5, 6, 7, 0])

    def test_tile_flips_and_transparency(self):
        source = self.vdp.tile(1)
        self.assertEqual(source.getpixel((7, 0))[3], 0)
        self.assertEqual(source.getpixel((0, 0))[3], 255)
        self.assertEqual(self.vdp.tile(1 | 0x800).getpixel((7, 0)), source.getpixel((0, 0)))
        self.assertEqual(self.vdp.tile(1 | 0x1000).getpixel((0, 7)), source.getpixel((0, 0)))
        self.assertEqual(self.vdp.tile(1 | 0x1800).getpixel((7, 7)), source.getpixel((0, 0)))

    def test_nametable_priority(self):
        raw = bytearray(self.vdp.vram)
        struct.pack_into("<H", raw, 0xE000, 0x8001)
        self.vdp.vram = bytes(raw)
        self.assertEqual(self.vdp.plane(0xE000, 1, 1, False).getbbox(), None)
        self.assertIsNotNone(self.vdp.plane(0xE000, 1, 1, True).getbbox())

    def test_bounds(self):
        with self.assertRaises(ValueError):
            tile_indices(bytes(65536), 2048, "little")
        with self.assertRaises(ValueError):
            tile_indices(bytes(31), 0, "little")
        with self.assertRaises(ValueError):
            self.vdp.plane(65534, 2, 1)

    def test_integrity_receipt(self):
        (self.root / "vram.bin").write_bytes(bytes(65536))
        with self.assertRaisesRegex(ValueError, "integrity"):
            VDP(self.root)

    def test_exact_blank_composite_and_no_overwrite(self):
        output = self.root / "decoded"
        report = self.vdp.export(output)
        self.assertEqual(report["compositor"], {"compared_pixels": 71680, "mismatched_pixels": 0, "exact": True})
        with Image.open(output / "tiles-palette-0.png") as atlas:
            self.assertEqual(atlas.size, (256, 512))
        with self.assertRaises(FileExistsError):
            self.vdp.export(output)

    def test_unsupported_scrolling_is_not_reported_exact(self):
        raw = bytearray(self.vdp.vsram)
        raw[0] = 1
        self.vdp.vsram = bytes(raw)
        self.assertEqual(self.vdp.export(self.root / "scroll")["compositor"], "unsupported")


class LocalOriginalGraphicsTests(unittest.TestCase):
    @unittest.skipUnless((ROOT / "reference/genesis/mission/brief2").exists(), "Requires local reference captures")
    def test_ten_original_captures_reconstruct_exactly(self):
        captures = ["mission/brief2", "mission/action", "boot/title", "navigation/title_wait",
                    "navigation/start_1", "instruments/gunner", "title-clean/f440",
                    "station-stable/commander", "station-stable/driver", "driver-held-input/driver"]
        with tempfile.TemporaryDirectory() as temp:
            for i, name in enumerate(captures):
                with self.subTest(capture=name):
                    vdp = VDP(ROOT / "reference/genesis" / name)
                    self.assertEqual(vdp.receipt["rom_sha256"], ROM_HASH)
                    result = vdp.export(Path(temp) / str(i))
                    self.assertTrue(result["compositor"]["exact"])
                    self.assertEqual(result["compositor"]["mismatched_pixels"], 0)

    @unittest.skipUnless((ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md").exists(), "Requires user's ROM")
    def test_original_rom_unchanged_and_header_checksum(self):
        raw = (ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md").read_bytes()
        self.assertEqual(hashlib.sha256(raw).hexdigest(), ROM_HASH)
        self.assertEqual(len(raw), 524288)
        total = sum(struct.unpack(">" + "H" * ((len(raw) - 512) // 2), raw[512:])) & 65535
        self.assertEqual(total, struct.unpack_from(">H", raw, 0x18E)[0])


if __name__ == "__main__":
    unittest.main()
