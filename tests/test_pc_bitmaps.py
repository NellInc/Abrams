import struct
import unittest
from pathlib import Path
from tools.pc_bitmaps import decode_bitmaps, read_ega_bitmap
from tools.inspect_scenarios import decode_resource


class BitmapTests(unittest.TestCase):
    def test_nibbles_and_separate_dimension_arrays(self):
        images = decode_bitmaps(struct.pack('<5H', 2, 1, 2, 1, 1) + bytes.fromhex('12 34 50'))
        self.assertEqual([p['pixels'] for p in images], [[1, 2], [3, 4, 5, 0]])
        self.assertEqual([p['width'] for p in images], [2, 4])

    def test_rejects_truncation_invalid_dimensions_and_tail(self):
        for raw in (b'', struct.pack('<H', 257), struct.pack('<3H', 1, 0, 1),
                    struct.pack('<3H', 1, 1, 1), struct.pack('<3H', 1, 1, 1) + b'\0\0'):
            with self.subTest(raw=raw), self.assertRaises(ValueError): decode_bitmaps(raw)

    def test_planar_pixels_and_explicit_mask(self):
        ram = bytearray(512)
        struct.pack_into('<HHHBBH', ram, 100, 16, 0, 4, 8, 1, 8)
        ram[256:261] = bytes([0x80, 0x40, 0x20, 0x10, 0x0e])
        p = read_ega_bitmap(ram, 0, 100)
        self.assertEqual(p['pixels'], [1, 2, 4, 8, 0, 0, 0, 0])
        # Zero can be opaque in loaded memory. Never derive alpha from colour.
        self.assertEqual(p['opaque'], [True, True, True, True, False, False, False, True])
        struct.pack_into('<H', ram, 104, 5)
        with self.assertRaisesRegex(ValueError, 'layout'): read_ega_bitmap(ram, 0, 100)

    def test_entire_supplied_effects_resource(self):
        images = decode_bitmaps(decode_resource(Path('GAME/EFFECTS.BMP').read_bytes()))
        self.assertEqual(len(images), 64)
        self.assertEqual([(p['width'], p['height']) for p in images[51:54]], [(8, 7), (16, 7), (16, 8)])


if __name__ == '__main__': unittest.main()
