import struct
import unittest
from pathlib import Path
from tools.extract_pc_ui import PLATES, screen_pixels, loaded_struts
from tools.inspect_scenarios import decode_resource
from tools.pc_bitmaps import decode_bitmaps

ROOT = Path(__file__).resolve().parents[1]


class UiAssetTests(unittest.TestCase):
    def test_screen_nibbles_and_strict_size(self):
        self.assertEqual(screen_pixels(bytes([0xA5]) * 32000), [10,5] * 32000)
        for length in (0,31999,32001):
            with self.assertRaises(ValueError): screen_pixels(bytes(length))

    @unittest.skipUnless(all((ROOT/'GAME'/name).is_file() for name in PLATES+('STRUTS.BMP',)), 'Requires separately supplied original PC files')
    def test_supplied_plates_and_strut_directory(self):
        for name in PLATES:
            with self.subTest(name=name):
                self.assertEqual(len(screen_pixels(decode_resource((ROOT/'GAME'/name).read_bytes()))),64000)
        sources = decode_bitmaps(decode_resource((ROOT/'GAME/STRUTS.BMP').read_bytes()))
        self.assertEqual(len(sources),7)
        self.assertEqual(sum(p['width']*p['height'] for p in sources),16024)

    def test_loaded_strut_pixels_and_mask_are_verified(self):
        ram = bytearray(65536)
        struct.pack_into('<H',ram,0x798e,200)
        struct.pack_into('<H',ram,200,100)
        struct.pack_into('<HHHBBH',ram,100,16,0,4,8,1,8)
        ram[256:261] = bytes([0x80,0x40,0x20,0x10,0x0f])
        source = {'index':0,'width':8,'height':1,'pixels':[1,2,4,8,0,0,0,0]}
        self.assertEqual(loaded_struts(ram,0,[source])[0]['descriptor'],100)
        ram[260] = 0x0e
        with self.assertRaisesRegex(ValueError,'mask differs'): loaded_struts(ram,0,[source])
        ram[256] = 0
        with self.assertRaisesRegex(ValueError,'bitmap'): loaded_struts(ram,0,[source])


if __name__ == '__main__': unittest.main()
