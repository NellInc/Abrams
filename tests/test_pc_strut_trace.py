from collections import Counter,deque
import struct
import unittest
from tools.pc_strut_trace import StrutDraws


class StrutTests(unittest.TestCase):
    def setup_draw(self):
        draw=StrutDraws.__new__(StrutDraws)
        draw.sources=[{'width':8,'height':1,'pixels':[1,2,4,8,0,0,0,0],'index':0}]
        draw.plates={4:[0]*64000};draw.plates[4][20*320+10:20*320+14]=[1,2,4,8]
        draw.pending=None;draw.counts=Counter();draw.draws=deque(maxlen=64)
        regs={'ds':0x1AE0,'cs':0x108D,'ss':0x9000,'sp':0x100}
        ram=bytearray(640*1024);ds=regs['ds']*16
        struct.pack_into('<H',ram,ds+0x798E,200)
        struct.pack_into('<H',ram,ds+200,100)
        struct.pack_into('<HHHBBH',ram,ds+100,0x7000,0,4,8,1,8)
        ram[0x70000:0x70005]=bytes([0x80,0x40,0x20,0x10,0x0f])
        struct.pack_into('<HHHhh',ram,0x90100,123,0x100,100,10,20)
        struct.pack_into('<H',ram,ds+0x35A8,0xA000);ram[ds+0x359F]=15
        return draw,ram,regs

    def test_source_draw_and_completed_pixels_required_before_claim(self):
        draw,ram,regs=self.setup_draw();draw.begin(bytes(ram),regs,0)
        pixels=bytearray(64000);pixels[20*320+10:20*320+14]=[1,2,4,8]
        plate,mask=draw.finish(bytes(pixels),0)
        self.assertEqual(plate,4)
        self.assertEqual(sum(v.bit_count() for v in mask),4)
        self.assertEqual(mask[(20*320+10)//8],0x3c)
        self.assertIsNone(draw.pending)
        self.assertEqual(draw.counts['verified_pixels'],4)
        self.assertEqual(draw.draws[0]['origin'],[10,20])

    def test_completed_source_colour_mismatch_fails_without_claim(self):
        draw,ram,regs=self.setup_draw();draw.begin(bytes(ram),regs,0)
        with self.assertRaisesRegex(ValueError,'completed'):draw.finish(bytes(64000),0)
        self.assertIsNone(draw.pending)

    def test_mutated_bitmap_mask_or_descriptor_is_rejected(self):
        for at in (0x70000,0x70004,0x90104):
            draw,ram,regs=self.setup_draw();ram[at]^=1
            with self.assertRaises(ValueError):draw.begin(bytes(ram),regs,0)

    def test_clipping_and_transparent_pixels_never_claim_neighbours(self):
        draw,ram,regs=self.setup_draw();ds=regs['ds']*16
        ram[ds+0x359B]=1;struct.pack_into('<4h',ram,ds+0x3593,11,12,20,20)
        draw.begin(bytes(ram),regs,0)
        pixels=bytearray([15]*64000);pixels[20*320+11:20*320+13]=[2,4]
        _,mask=draw.finish(bytes(pixels),0)
        self.assertEqual(sum(v.bit_count() for v in mask),2)
        self.assertEqual(mask[(20*320+11)//8],0x18)

    def test_unknown_source_placement_or_ambiguous_plate_is_silent(self):
        for ambiguous in (False,True):
            draw,ram,regs=self.setup_draw()
            if ambiguous:draw.plates[1]=draw.plates[4].copy()
            else:draw.plates[4][20*320+10]=15
            draw.begin(bytes(ram),regs,0)
            self.assertIsNone(draw.finish(bytes(64000),0))
            self.assertEqual(draw.counts['unmapped_source_placement'],1)

    def test_partial_plane_mode_and_wrong_return_page_fail_closed(self):
        draw,ram,regs=self.setup_draw();ram[regs['ds']*16+0x359F]=7
        draw.begin(bytes(ram),regs,0);self.assertIsNone(draw.finish(bytes(64000),0))
        draw,ram,regs=self.setup_draw();draw.begin(bytes(ram),regs,0)
        with self.assertRaisesRegex(ValueError,'page'):draw.finish(bytes(64000),8192)


if __name__=='__main__':unittest.main()
