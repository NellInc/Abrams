import hashlib
from pathlib import Path
import struct
import unittest
from tools.pc_fonts import decode_font, loaded_font, rendered_glyph, text_pixels

ROOT=Path(__file__).resolve().parents[1]


class FontTests(unittest.TestCase):
    def test_header_and_MSB_row_layout(self):
        raw=bytes([3,2,65,2,0xA0,0x40,0xE0,0x80])
        font=decode_font(raw)
        self.assertEqual(font['glyphs'],[[1,0,1,0,1,0],[1,1,1,1,0,0]])
        self.assertEqual(font['sha256'],hashlib.sha256(raw).hexdigest())
        self.assertEqual(text_pixels(font,b'AB'),(6,2,bytes([1,0,1,1,1,1,0,1,0,1,0,0])))
        self.assertIsNone(rendered_glyph(font,64))
        self.assertIsNone(rendered_glyph(font,67))

    def test_wide_row_stride_and_strict_header(self):
        self.assertEqual(decode_font(bytes([9,1,65,1,128,128]))['glyphs'],[[1,0,0,0,0,0,0,0,1]])
        for raw in (b'',b'abc',bytes([0,2,32,1]),bytes([17,1,32,1]),bytes([1,33,32,1]),
                    bytes([1,1,255,2,128,128]),bytes([1,1,32,0]),bytes([1,1,32,1]),bytes([1,1,32,1,0,0])):
            with self.subTest(raw=raw),self.assertRaises(ValueError): decode_font(raw)

    def test_original_signed_rejection_in_supplied_font(self):
        font=decode_font((ROOT/'GAME/8X8.FNT').read_bytes())
        self.assertEqual((font['first'],font['count']),(32,105))
        for code in range(256):
            self.assertEqual(rendered_glyph(font,code) is not None,32<=code<128,code)
        for text in (b'',b'\0',b'A\0B',b'\x80',b'\x1f','AB'):
            with self.subTest(text=text),self.assertRaises(ValueError): text_pixels(font,text)
        with self.assertRaises(ValueError): rendered_glyph(font,256)

    def test_loaded_font_identity_and_aliases(self):
        raw=(ROOT/'GAME/6X6.FNT').read_bytes();ram=bytearray(640*1024);ds=4096
        for at,v in zip((0x364E,0x3662,0x3676,0x368A),raw[:4]): ram[ds+at]=v
        struct.pack_into('<H',ram,ds+0x369E,0x7000)
        ram[0x70000:0x70000+len(raw)-4]=raw[4:]
        catalog={'6X6.FNT':raw,'VM.FNT':raw}
        self.assertEqual(loaded_font(ram,ds,catalog)['sources'],['6X6.FNT','VM.FNT'])
        ram[0x70000]^=1
        with self.assertRaisesRegex(ValueError,'differs'): loaded_font(ram,ds,catalog)
        struct.pack_into('<H',ram,ds+0x369E,0xFFFF)
        with self.assertRaisesRegex(ValueError,'outside'): loaded_font(ram,ds,catalog)
        self.assertEqual((decode_font((ROOT/'GAME/8X6.FNT').read_bytes())['width'],
                          decode_font((ROOT/'GAME/8X6.FNT').read_bytes())['height']),(8,8))

    def test_printable_genesis_stencil_matches_original_pc_face(self):
        from tools.extract_genesis_vdp import VDP
        capture=VDP(ROOT/'reference/genesis/graphics-ammo-pages-01/ax')
        font=decode_font((ROOT/'GAME/STENCIL.FNT').read_bytes())
        # Contiguous native font bank, not OCR or a visually similar font.
        # DEL (127) differs and is deliberately excluded from restored text.
        for code in range(32,127):
            actual=[int(bool(pixel)) for pixel in capture.tiles[1504+code-32]]
            self.assertEqual(actual,rendered_glyph(font,code),code)


if __name__=='__main__': unittest.main()
