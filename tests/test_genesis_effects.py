import hashlib
from pathlib import Path
import struct
import tempfile
import unittest

from PIL import Image

from tools.extract_genesis_effects import COUNT, DATA_START, ROM_HASH, TABLE, decode_effects, export_effects
from tools.extract_genesis_vdp import VDP, word
from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps
from tools.inspect_shapes import inspect_shapes

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md"


class GenesisEffectDecoderTests(unittest.TestCase):
    def test_explicit_mask_includes_opaque_black_and_preserved_background(self):
        raw = struct.pack(">HHIHH", 4, 1, 8, 0x0120, 0x000F)
        effect, = decode_effects(raw, table=0, count=1)
        self.assertEqual(effect["pixels"], [0, 1, 2, 0])
        self.assertEqual(effect["opaque"], [True, True, True, False])

    def test_malformed_resources_fail_closed(self):
        cases = [b"", struct.pack(">HHI", 3, 1, 8),
                 struct.pack(">HHI", 4, 0, 8),
                 struct.pack(">HHI", 4, 1, 0xFFFF),
                 struct.pack(">HHIHH", 4, 1, 8, 0, 0x1000),
                 struct.pack(">HHIHH", 4, 1, 8, 0x1000, 0xF000)]
        for raw in cases:
            with self.subTest(raw=raw.hex()), self.assertRaises(ValueError):
                decode_effects(raw, table=0, count=1)
        for table, count in [(-1, 1), (0, 0), (0, 257)]:
            with self.assertRaises(ValueError):
                decode_effects(bytes(64), table=table, count=count)


@unittest.skipUnless(ROM.exists(), "Requires the user's local Genesis ROM")
class LocalGenesisEffectsTests(unittest.TestCase):
    def test_pc_shape_roots_define_the_nine_bound_detail_variants(self):
        shapes = inspect_shapes(decode_resource((ROOT / "GAME/SHAPE.TBL").read_bytes()))["shapes"]
        for phase in range(3):
            source = shapes[183 + phase]
            self.assertEqual(source["index"], 183 + phase)
            self.assertEqual([s["word"] for s in source["selectors"]], [16, 8, 4])
            self.assertEqual([s["target"] for s in source["selectors"]], [33696 + phase * 26 + lod * 2 for lod in range(3)])
            self.assertEqual([s["hex"] for s in source["opaque_commands"]], [f"80 {15 + phase + lod * 18:02x}" for lod in range(3)])

    def test_pinned_directory_and_complete_pc_pixel_correspondence(self):
        rom = ROM.read_bytes()
        self.assertEqual(hashlib.sha256(rom).hexdigest(), ROM_HASH)
        effects = decode_effects(rom)
        pc = decode_bitmaps(decode_resource((ROOT / "GAME/EFFECTS.BMP").read_bytes()))
        self.assertEqual(len(effects), COUNT)
        at = DATA_START
        for source, original in zip(effects, pc):
            self.assertEqual(source["offset"], at)
            at += source["byte_count"]
            for field in ("index", "width", "height", "pixels"):
                self.assertEqual(source[field], original[field])
            self.assertEqual(source["opaque"], [c != 0 for c in original["pixels"]])
        self.assertEqual(at, TABLE)
        self.assertEqual(sum(len(s["pixels"]) for s in effects), 28960)

    @unittest.skipUnless((ROOT / "reference/genesis/effects-fire-01/f0024").exists(), "Requires native fire capture")
    def test_native_effect_pixels_palette_and_original_reticle_occlusion(self):
        effects = decode_effects(ROM.read_bytes())
        cases = [("f0024", 52, 152, 80, 23, 2), ("f0034", 53, 152, 83, 20, 4)]
        with tempfile.TemporaryDirectory() as temp:
            for frame, index, x, y, visible_count, covered_count in cases:
                vdp = VDP(ROOT / "reference/genesis/effects-fire-01" / frame)
                self.assertEqual(vdp.receipt["rom_sha256"], ROM_HASH)
                self.assertEqual(vdp.export(Path(temp) / frame)["compositor"]["mismatched_pixels"], 0)
                screen = Image.open(vdp.capture / "screen.png").convert("RGB")
                effect, visible, covered = effects[index], 0, 0
                for j, (color, opaque) in enumerate(zip(effect["pixels"], effect["opaque"])):
                    if not opaque:
                        continue
                    px, py = x + j % effect["width"], y + j // effect["width"]
                    # Native window plane owns these world pixels, using bank 3.
                    descriptor = word(vdp.vram, 0xF000 + (py // 8 * 64 + px // 8) * 2, vdp.endian)
                    self.assertEqual(descriptor >> 13 & 3, 3)
                    # Observed black original sight strokes cover these pixels.
                    # This is visible-frame evidence, not a recovered draw hook.
                    reticle = px == 160 and 84 <= py <= 100 or py == 80 and 136 <= px <= 156
                    expected = (0, 0, 0) if reticle else vdp.palette[48 + color]
                    self.assertEqual(screen.getpixel((px, py)), expected, (frame, px, py))
                    covered += int(reticle)
                    visible += int(not reticle)
                self.assertEqual((visible, covered), (visible_count, covered_count))

    @unittest.skipUnless((ROOT / "reference/genesis/effects-fire-01/f0024").exists(), "Requires native palette capture")
    def test_export_preserves_source_and_does_not_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / "effects"
            capture = ROOT / "reference/genesis/effects-fire-01/f0024"
            manifest = export_effects(ROM, capture, output, 3)
            self.assertEqual(manifest["data_bytes"], 28960)
            self.assertEqual(len(manifest["images"]), 64)
            for sprite in manifest["images"]:
                with Image.open(output / sprite["image"]) as image:
                    self.assertEqual(image.size, (sprite["width"], sprite["height"]))
                    self.assertEqual(list(image.getchannel("A").getdata()), [255 if x else 0 for x in sprite["opaque"]])
            with self.assertRaises(FileExistsError):
                export_effects(ROM, capture, output, 3)


if __name__ == "__main__":
    unittest.main()
