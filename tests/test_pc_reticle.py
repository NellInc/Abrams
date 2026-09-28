from pathlib import Path
import struct
import unittest
from tools.pc_reticle import ReticleRuns,lines,ink_pixels
from tools.unpack_pc_executables import unpack

ROOT=Path(__file__).resolve().parents[1]


class ReticleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        raw,_=unpack((ROOT/'GAME/SIM.EXE').read_bytes())
        cls.table=raw[0x19E00+0xBBA:0x19E00+0xBFA]

    def setUp(self):
        self.observer=ReticleRuns();self.palette=[[i*7,i*11,i*13] for i in range(16)]

    def entry(self,page=0,color=0):
        raw=bytearray(65536);raw[0xBBA:0xBFA]=self.table
        raw[0x35AE]=16;raw[0x359B]=1;raw[0x359E]=color
        struct.pack_into('<H',raw,0x35A8,0xA000+page//16)
        struct.pack_into('<4h',raw,0x3593,32,287,13,109)
        return raw

    def begin(self,raw,center=60):
        self.observer.begin(raw,{'cs':0x100,'ds':0x1AE0,'ax':center&65535})

    def complete(self,raw,center=60,changes=None,count=8):
        page=(struct.unpack_from('<H',raw,0x35A8)[0]-0xA000)*16;color=raw[0x359E]
        for i,line in enumerate(lines(center)[:count]):
            payload=bytearray(struct.pack('<4hBBH',*line,color,1,0xA000+page//16))
            if changes is not None and i==0: payload[changes]^=1
            self.observer.line(bytes(payload))
        pixels=bytearray((i%16 for i in range(51*97)))
        for x,y in ink_pixels(center): pixels[(y-13)*51+x-134]=color
        self.observer.finish(struct.pack('<5H',134,13,51,97,page)+pixels)
        video=bytearray(320*200*4)
        for y in range(13,110):
            for x in range(134,185):
                r,g,b=self.palette[pixels[(y-13)*51+x-134]];at=(y*320+x)*4
                video[at:at+4]=bytes([b,g,r,255])
        return bytes(video)

    def test_original_endpoint_conventions(self):
        ink=set(ink_pixels(60))
        self.assertEqual(len(ink),106)
        self.assertIn((159,40),ink);self.assertIn((159,56),ink)
        self.assertNotIn((159,57),ink);self.assertNotIn((159,63),ink)
        self.assertIn((159,64),ink);self.assertIn((163,40),ink)
        self.assertIn((134,57),ink);self.assertNotIn((134,56),ink)
        for center in range(-40,160):
            self.assertTrue(all(134<=x<=184 and 13<=y<=109 for x,y in ink_pixels(center)))

    def test_both_colors_pages_and_clipping(self):
        for page,color in ((0,0),(8192,1)):
            for center in (-10,0,13,35,60,86,109,125,140):
                raw=self.entry(page,color);self.begin(raw,center);video=self.complete(raw,center)
                item=self.observer.scanout(page)
                if not ink_pixels(center): self.assertIsNone(item);continue
                result=self.observer.present(item,video,320,200,self.palette)
                self.assertEqual(result['center_y'],center);self.assertEqual(result['color'],color)
                self.assertEqual(result['page_offset'],page)

    def test_all_line_fields_and_incomplete_draw_rejected(self):
        raw=self.entry()
        for i in range(12):
            self.begin(raw);self.complete(raw,changes=i);self.assertIsNone(self.observer.scanout(0),i)
        self.begin(raw);self.complete(raw,count=7);self.assertIsNone(self.observer.scanout(0))

    def test_source_context_rejected(self):
        for at in (0xBBA,0x35AE,0x359B,0x3593,0x3595,0x3597,0x3599,0x799D):
            raw=self.entry();raw[at]^=1;self.begin(raw);self.complete(raw)
            self.assertIsNone(self.observer.scanout(0),at)
        raw=self.entry(color=2);self.begin(raw);self.complete(raw);self.assertIsNone(self.observer.scanout(0))

    def test_entire_visible_rectangle_must_match(self):
        raw=self.entry();self.begin(raw);video=self.complete(raw);item=self.observer.scanout(0)
        for x,y in ((134,13),(184,109),(159,60),(159,40)):
            for channel in range(3):
                bad=bytearray(video);bad[(y*320+x)*4+channel]^=1
                self.assertEqual(self.observer.present(item,bad,320,200,self.palette),{})
        self.assertEqual(self.observer.present(item,video,640,100,self.palette),{})
        self.assertEqual(self.observer.present(item,video,320,200,None),{})

    def test_page_invalidation_preserves_already_scanned_candidate(self):
        raw=self.entry();self.begin(raw);video=self.complete(raw);old=self.observer.scanout(0)
        self.begin(raw);self.observer.finish(b'');self.assertIsNone(self.observer.scanout(0))
        self.assertTrue(self.observer.present(old,video,320,200,self.palette))
        raw=self.entry(8192,1);self.begin(raw);self.complete(raw)
        self.assertIsNotNone(self.observer.scanout(8192));self.assertIsNone(self.observer.scanout(0))

    def test_malformed_callbacks_raise(self):
        with self.assertRaises(ValueError): self.observer.line(b'')
        with self.assertRaises(ValueError): self.observer.finish(b'')
        raw=self.entry();self.begin(raw)
        with self.assertRaises(ValueError): self.begin(raw)
        with self.assertRaises(ValueError): self.observer.line(b'')
