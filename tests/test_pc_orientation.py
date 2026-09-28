from pathlib import Path
import struct
import unittest
from tools.pc_orientation import OrientationRuns,diagram,QUAD_CALLERS,EDGE_CALLERS
from tools.unpack_pc_executables import unpack

ROOT=Path(__file__).resolve().parents[1]


class OrientationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source,_=unpack((ROOT/'GAME/SIM.EXE').read_bytes())
        cls.table=source[0x19E00+0x1D9C:0x19E00+0x1D9C+640]

    def setUp(self):
        self.observer=OrientationRuns()
        self.palette=[[i*7,i*11,i*13] for i in range(16)]

    def entry(self,station=0,page=0,heading=19,relative=81):
        raw=bytearray(65536);raw[0x1D9C:0x1D9C+640]=self.table
        raw[0x799D]=station;raw[0x35AE]=16;raw[0x359C]=1
        struct.pack_into('<HH',raw,0x7999,0x8100,0x8000)
        struct.pack_into('<H',raw,0x35A8,0xA000+page//16)
        raw[0x801A]=heading;raw[0x810B]=relative
        raw[0xCB6:0xCBA]=bytes([6,10,2,8])
        x,y=(128,137) if station==0 else(216,83)
        struct.pack_into('<4h',raw,0x3593,x,x+61,y,y+43)
        return raw

    def callbacks(self,raw):
        geometry=diagram(raw,0);page=struct.unpack_from('<H',raw,0x35A8)[0]
        quads=[];lines=[]
        for i,q in enumerate(geometry['quads']):
            xy=[p[0] for p in q['points']]+[p[1] for p in q['points']]
            quads.append(struct.pack('<4B3H8h6i',0,raw[0x359C],0,1 if i<2 else 2,page,int(i==2),QUAD_CALLERS[i],*xy,*q['basis']))
        for caller,points in zip(geometry['grid_callers'],geometry['grid']):
            lines.append(struct.pack('<H4hBBH',caller,*points,8,0,page))
        points=geometry['quads'][2]['points']
        for i,(caller,color) in enumerate(zip(EDGE_CALLERS,[2,8,10,6])):
            lines.append(struct.pack('<H4hBBH',caller,*(points[i]+points[(i+1)%4]),color,0,page))
        return quads,lines

    def finish(self,raw,quads=None,lines=None):
        default_q,default_l=self.callbacks(raw)
        for q in default_q if quads is None else quads:self.observer.quad(q)
        for line in default_l if lines is None else lines:self.observer.line(line)
        geometry=diagram(raw,0);x,y,w,h=geometry['rect']
        page=(struct.unpack_from('<H',raw,0x35A8)[0]-0xA000)*16
        # Contract-only patterned readback. The separate CPU oracle supplies real raster bytes.
        pixels=bytes((i%16 for i in range(w*h)))
        self.observer.finish(struct.pack('<5H',x,y,w,h,page)+pixels)
        video=bytearray(320*200*4)
        for dy in range(h):
            for dx in range(w):
                at=((y+dy)*320+x+dx)*4;r,g,b=self.palette[pixels[dy*w+dx]]
                video[at:at+4]=bytes([b,g,r,255])
        return bytes(video)

    def begin(self,raw): self.observer.begin(raw,{'cs':0x100,'ds':0x1AE0})
    def present(self,candidate,video): return self.observer.present(candidate,video,320,200,self.palette)

    def test_completed_source_geometry_full_RGB_and_page_required(self):
        for station,page in ((0,0),(1,8192)):
            raw=self.entry(station,page);self.begin(raw)
            self.assertIsNone(self.observer.scanout(page))
            video=self.finish(raw);candidate=self.observer.scanout(page)
            self.assertEqual(self.present(candidate,video)['station'],station)
            self.assertEqual(self.present(candidate,bytes(len(video))),{})
            self.assertEqual(self.observer.present(candidate,video,640,100,self.palette),{})
            self.assertEqual(self.observer.present(candidate,video,320,200,[]),{})
            x,y,w,h=candidate[0]['rect']
            for px,py in ((x,y),(x+w-1,y+h-1),(x+w//2,y+h//2)):
                for channel in range(3):
                    changed=bytearray(video);changed[(py*320+px)*4+channel]^=1
                    self.assertEqual(self.present(candidate,changed),{})

    def test_rejected_redraw_invalidates_page_but_not_old_scanout(self):
        raw=self.entry();self.begin(raw);video=self.finish(raw);old=self.observer.scanout(0)
        self.begin(raw);self.observer.finish(b'')
        self.assertIsNone(self.observer.scanout(0))
        self.assertTrue(self.present(old,video))
        raw=self.entry(heading=97);self.begin(raw);self.finish(raw)
        self.assertNotEqual(old[0]['quads'],self.observer.scanout(0)[0]['quads'])
        self.assertTrue(self.present(old,video))

    def test_each_quad_field_and_line_call_colour_endpoints_fail_closed(self):
        raw=self.entry();quads,lines=self.callbacks(raw)
        for i in range(50):
            self.begin(raw);bad=bytearray(quads[2]);bad[i]^=1
            self.finish(raw,quads=quads[:2]+[bytes(bad)]+quads[3:])
            self.assertIsNone(self.observer.scanout(0),i)
        for i in range(14):
            self.begin(raw);bad=bytearray(lines[0]);bad[i]^=1
            self.finish(raw,lines=[bytes(bad)]+lines[1:])
            self.assertIsNone(self.observer.scanout(0),i)
        self.begin(raw);self.finish(raw,quads=quads[:3]);self.assertIsNone(self.observer.scanout(0))
        self.begin(raw);self.finish(raw,lines=lines[::-1]);self.assertIsNone(self.observer.scanout(0))

    def test_entry_modes_hash_and_protocol_reject(self):
        for offset,value in [(0x35AE,4),(0x799D,4),(0x3593,0),(0x359C,3),(0xC9D,4),(0xCB6,16),(0x1D9C,7)]:
            raw=self.entry();raw[offset]=value;self.begin(raw);self.observer.finish(b'')
            self.assertIsNone(self.observer.scanout(0))
        with self.assertRaises(ValueError): self.begin(b'')
        with self.assertRaises(ValueError): self.observer.finish(b'')
        with self.assertRaises(ValueError): self.observer.quad(bytes(50))
        self.begin(self.entry())
        with self.assertRaises(ValueError): self.begin(self.entry())
        self.observer.finish(b'')

    def test_source_hook_instruction_bytes_and_readonly_backing_planes(self):
        source,_=unpack((ROOT/'GAME/SIM.EXE').read_bytes())
        for at in (0x6040,): self.assertEqual(source[at],0xE8)
        for at in (0x5F81,0x567F,0x56A5,0x56DD,*EDGE_CALLERS): self.assertEqual(source[at],0x9A)
        self.assertEqual(source[0x62A6:0x62AB],bytes.fromhex('c6 06 92 35 00'))
        header=(ROOT/'tools/pc_core/abrams_trace.h').read_text()
        block=header[header.index('    if (segment == abrams_trace_load && (ip == 0x6040'):header.index('    if (segment == abrams_trace_load && (ip == 0x5ba1')]
        self.assertIn('vga.mem.linear[at*4+p]',block)
        for forbidden in ('mem_write','MEM_BlockWrite','CPU_Cycles','reg_ax ='): self.assertNotIn(forbidden,block)


if __name__=='__main__': unittest.main()
