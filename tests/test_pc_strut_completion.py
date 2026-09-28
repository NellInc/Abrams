"""Fail-closed custody for the one source-authored offscreen cupola strut."""
from collections import Counter,deque
import struct
import unittest
from tools.pc_strut_trace import StrutDraws


class StrutCompletionTests(unittest.TestCase):
    def fixture(self):
        draw=StrutDraws.__new__(StrutDraws)
        pixels=[0 if i%5==0 else 1 for i in range(168*7)]
        draw.sources=[{'width':168,'height':7,'pixels':pixels,'index':i} for i in range(6)]
        draw.plates={3:[0]*64000}
        for sy in range(7):
            for sx in range(161):draw.plates[3][(110+sy)*320+159+sx]=pixels[sy*168+sx]
        draw.pending=None;draw.counts=Counter();draw.draws=deque(maxlen=64)
        regs={'ds':0x1AE0,'cs':0x108D,'ss':0x9000,'sp':0x100}
        ram=bytearray(640*1024);ds=regs['ds']*16
        struct.pack_into('<H',ram,ds+0x798E,200);struct.pack_into('<H',ram,ds+210,100)
        plane=21*7
        struct.pack_into('<HHHBBH',ram,ds+100,0x7000,0,plane*4,168,7,8)
        for at,c in enumerate(pixels):
            byte=at//8;bit=128>>(at&7)
            ram[0x70000+(0 if c else plane*4)+byte]|=bit
        struct.pack_into('<HHHhh',ram,0x90100,0x0D92,0x100,100,159,110)
        struct.pack_into('<H',ram,ds+0x35A8,0xA000);ram[ds+0x359F]=15
        return draw,ram,regs

    def test_source_offscreen_path_claims_only_visible_opaque_pixels(self):
        draw,ram,regs=self.fixture();draw.begin(bytes(ram),regs,5)
        actual=bytes(draw.plates[3]);plate,mask=draw.finish(actual,0)
        self.assertEqual(plate,3)
        for at,c in enumerate(actual):self.assertEqual(bool(mask[at//8]&(128>>(at&7))),bool(c))
        self.assertEqual(draw.counts['verified_draws_index_5'],1)
        self.assertTrue(draw.draws[-1]['source_clipped_cupola'])

    def test_wrong_origin_or_caller_is_still_unsupported(self):
        for offset,value in [(0,0x0D91),(2,0x101),(6,160),(8,109)]:
            draw,ram,regs=self.fixture();struct.pack_into('<H',ram,0x90100+offset,value)
            draw.begin(bytes(ram),regs,5)
            self.assertIsNone(draw.finish(bytes(64000),0))
            self.assertEqual(draw.counts['unsupported_layout'],1)

    def test_ambiguous_plate_cannot_claim(self):
        draw,ram,regs=self.fixture();draw.plates[2]=draw.plates[3].copy()
        draw.begin(bytes(ram),regs,5)
        self.assertIsNone(draw.finish(bytes(64000),0))
        self.assertEqual(draw.counts['unmapped_source_placement'],1)

    def test_completed_changed_pixel_is_rejected(self):
        draw,ram,regs=self.fixture();draw.begin(bytes(ram),regs,5)
        actual=bytearray(draw.plates[3]);actual[110*320+160]^=1
        with self.assertRaisesRegex(ValueError,'completed'):draw.finish(bytes(actual),0)

    def test_clip_cannot_expose_transparent_or_offscreen_bits(self):
        draw,ram,regs=self.fixture();ds=regs['ds']*16
        ram[ds+0x359B]=1;struct.pack_into('<4h',ram,ds+0x3593,160,318,112,114)
        draw.begin(bytes(ram),regs,5);_,mask=draw.finish(bytes(draw.plates[3]),0)
        for at in range(64000):
            if mask[at//8]&(128>>(at&7)):
                self.assertTrue(160<=at%320<=318 and 112<=at//320<=114)
                self.assertEqual(draw.plates[3][at],1)


if __name__=='__main__':unittest.main()
