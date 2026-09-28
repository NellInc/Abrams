import hashlib
import struct
import unittest
from tools.pc_reticle_target import TargetBoxRuns, lines, ink_pixels


class TargetBoxTests(unittest.TestCase):
    def setUp(self):
        self.observer=TargetBoxRuns();self.palette=[[i*7,i*11,i*13] for i in range(16)]

    def entry(self,page=0,color=0,selected=True):
        raw=bytearray(65536)
        raw[0x35AE]=16;raw[0x359B]=1;raw[0x359E]=color
        struct.pack_into('<H',raw,0x35A8,0xA000+page//16)
        struct.pack_into('<H',raw,0x79AF,int(selected))
        struct.pack_into('<4h',raw,0x3593,32,287,13,109)
        return raw

    def begin(self,raw):self.observer.begin(raw,{'cs':0x100,'ds':0x1AE0})

    def complete(self,raw,x=159,y=60,change=None,count=4):
        page=(struct.unpack_from('<H',raw,0x35A8)[0]-0xA000)*16;color=raw[0x359E]
        for i,line in enumerate(lines(x,y)[:count]):
            payload=bytearray(struct.pack('<4hBBH',*line,color,1,0xA000+page//16))
            if change is not None and i==0:payload[change]^=1
            self.observer.line(bytes(payload))
        pixels=bytearray((i%16 for i in range(256*97)))
        for px,py in ink_pixels(x,y):pixels[(py-13)*256+px-32]=color
        self.observer.finish(struct.pack('<5H',32,13,256,97,page)+pixels)
        video=bytearray(320*200*4)
        for py in range(13,110):
            for px in range(32,288):
                r,g,b=self.palette[pixels[(py-13)*256+px-32]]
                at=(py*320+px)*4;video[at:at+4]=bytes([b,g,r,255])
        return bytes(video)

    def test_geometry_and_clip_boundaries(self):
        self.assertEqual(len(ink_pixels(159,60)),40)
        for x,y in ((32,13),(287,109),(159,60),(27,60),(292,60),(159,8),(159,114),(-20,-20)):
            for color in (0,1):
                raw=self.entry(color*8192,color);self.begin(raw);video=self.complete(raw,x,y)
                candidate=self.observer.scanout(color*8192)
                self.assertEqual(bool(candidate),bool(ink_pixels(x,y)))
                if candidate:
                    packet=self.observer.present(candidate,video,320,200,self.palette)
                    self.assertEqual(packet['center'],[x,y]);self.assertEqual(packet['color'],color)
                    self.assertTrue(all(32<=px<=287 and 13<=py<=109 for px,py in ink_pixels(x,y)))

    def test_all_line_fields_and_incomplete_draw_reject(self):
        for i in range(12):
            raw=self.entry();self.begin(raw);self.complete(raw,change=i)
            self.assertIsNone(self.observer.scanout(0))
        raw=self.entry();self.begin(raw);self.complete(raw,count=3);self.assertIsNone(self.observer.scanout(0))

    def test_absent_selection_clears_only_future_scanout(self):
        raw=self.entry();self.begin(raw);video=self.complete(raw);old=self.observer.scanout(0)
        self.begin(self.entry(selected=False));self.observer.finish(b'')
        self.assertIsNone(self.observer.scanout(0))
        self.assertTrue(self.observer.present(old,video,320,200,self.palette))

    def test_context_rejection(self):
        for at in (0x35AE,0x359B,0x3593,0x3595,0x3597,0x3599,0x799D,0x79AF):
            raw=self.entry();raw[at]^=1;self.begin(raw);self.complete(raw)
            self.assertIsNone(self.observer.scanout(0),hex(at))
        raw=self.entry(color=2);self.begin(raw);self.complete(raw);self.assertIsNone(self.observer.scanout(0))

    def test_full_sight_rgb_must_survive(self):
        raw=self.entry();self.begin(raw);video=self.complete(raw);candidate=self.observer.scanout(0)
        for x,y in ((32,13),(287,109),(159,60),(154,55)):
            for c in range(3):
                bad=bytearray(video);bad[(y*320+x)*4+c]^=1
                self.assertFalse(self.observer.present(candidate,bad,320,200,self.palette))
        self.assertFalse(self.observer.present(candidate,video,640,100,self.palette))
        self.assertFalse(self.observer.present(candidate,video,320,200,None))

    def test_malformed_callbacks_raise(self):
        with self.assertRaises(ValueError):self.observer.begin(b'',{'cs':0,'ds':0})
        with self.assertRaises(ValueError):self.observer.line(bytes(12))
        with self.assertRaises(ValueError):self.observer.finish(b'')
        self.begin(self.entry())
        with self.assertRaises(ValueError):self.observer.line(b'')

    def test_collector_uses_presented_slot_and_hides_native_pixels(self):
        from tools.pc_render_trace import Collector
        import ctypes as C
        c=Collector(None,history_limit=2);raw=self.entry();self.begin(raw);video=self.complete(raw)
        c.target_box=self.observer
        def event(n,slot,data=b'',regs=None):
            buf=C.create_string_buffer(data);r=(C.c_uint16*12)(*(regs or [0]*12))
            c.observe(n,r,C.addressof(buf),slot,len(data))
            if c.error:raise c.error
        palette=bytes(v for rgb in self.palette for v in rgb+[0])
        event(10,0,palette);event(11,2);event(10,8192,palette);event(11,1)
        event(12,2,video,[320,200]+[0]*10)
        self.assertEqual(c.presented['target_box']['center'],[159,60])
        self.assertNotIn('_target_box_candidate',c.presented)
        event(12,1,video,[320,200]+[0]*10)
        self.assertFalse(c.presented['target_box'])
