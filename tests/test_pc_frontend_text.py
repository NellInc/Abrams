import ctypes as C
import hashlib
from pathlib import Path
import struct
import unittest
from tools.pc_frontend_text import FrontendSources,FrontendText,PROFILES,visible_runs
from tools.pc_fonts import decode_font,text_pixels
from tools.pc_text_trace import TextRuns
from tools.unpack_pc_executables import unpack
from tests.test_pc_session import program_ram
ROOT=Path(__file__).resolve().parents[1]

class FrontendTextTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.sources=FrontendSources()

    def snapshot(self,name='START',words=b'NAME: NELL',x=30,y=30):
        p=self.sources.profiles[name];load=0x1ed;ram=program_ram(name);ds=(load+p['ds'])*16
        for at,code in p['anchors']:ram[load*16+at:load*16+at+len(code)]=code
        font=(ROOT/'GAME/8X8.FNT').read_bytes();fg=p['foreground']
        for at,v in zip((0xbe,0xd2,0xe6,0xfa),font[:4]):ram[ds+fg+at]=v
        struct.pack_into('<H',ram,ds+fg+0x10e,0x7000);ram[0x70000:0x70000+len(font)-4]=font[4:]
        struct.pack_into('<HH',ram,ds+fg+0x24,p['driver_ip'],load+p['driver'])
        struct.pack_into('<H',ram,ds+fg+0x18,0xa000)
        for i in range(16):struct.pack_into('<H',ram,ds+fg+0x1316+2*i,i)
        ram[ds+fg:ds+fg+3]=bytes([1,4,0]);pointer=0xe000
        ram[ds+pointer:ds+pointer+len(words)+1]=words+b'\0'
        regs={'cs':load+p['wrapper'],'ds':load+p['ds'],'ss':load+p['ds'],'sp':0xf000}
        caller=min(p['callers']);struct.pack_into('<5H',ram,ds+0xf000,caller,load,pointer,x,y)
        return bytes(ram),regs,p,caller,font

    def test_all_original_call_sites_driver_and_profile_fields(self):
        for name,n in [('START',46),('BRIEF',5),('END',17)]:
            p=self.sources.profiles[name];d,meta=unpack((ROOT/'GAME'/(name+'.EXE')).read_bytes())
            expected=[i+5 for i in range(p['wrapper']*16) if d[i:i+5]==struct.pack('<BHH',0x9a,p['entry'],p['wrapper'])]
            self.assertEqual(sorted(p['callers']),expected);self.assertEqual(len(expected),n)
            at=p['wrapper']*16+p['entry'];code=d[at:at+80];fg=p['foreground']
            self.assertEqual(code[-1],0xcb)
            for index,value in [(14,fg+1),(22,fg+0x1316),(30,fg),(38,fg+0x1316),(50,fg+0x18),(64,fg+0x24),(69,fg+0xbe)]:
                self.assertEqual(struct.unpack_from('<H',code,index)[0],value,(name,index))
            for offset,anchor in p['anchors']:self.assertEqual(d[offset:offset+len(anchor)],anchor)

    def test_every_profile_matches_only_active_original_and_verified_font(self):
        for name in PROFILES:
            ram,regs,p,caller,font=self.snapshot(name)
            match=self.sources.match(ram,regs);self.assertEqual(match[0]['name'],name)
            t=TextRuns(ROOT/'GAME',p);t.begin(ram,regs)
            w,h,ink=text_pixels(decode_font(font),b'NAME: NELL')
            pixels=bytes(1 if b else 4 for b in ink)
            packet=struct.pack('<6H',30,30,w,h,0,caller)+pixels
            t.finish(packet)
            self.assertEqual(t.scanout(0)[0][0]['text'],'NAME: NELL')
            self.assertEqual(t.scanout(0)[0][0]['kind'],'frontend')
            self.assertIsNone(t.scanout(0)[0][0]['speaker'])
            changed=bytearray(ram);changed[0x1ed0+p['anchors'][0][0]]^=1
            self.assertIsNone(self.sources.match(changed,regs))
            changed=bytearray(ram);changed[0x1dc8:0x1dd0]=b'OTHER\0\0\0'
            self.assertIsNone(self.sources.match(changed,regs))
            changed=bytearray(ram);struct.pack_into('<H',changed,regs['ss']*16+regs['sp'],0xffff)
            self.assertIsNone(self.sources.match(changed,regs))
            # A tampered in-guest font is rejected at entry, so even the genuine
            # returned glyph pixels cannot publish the label.
            changed=bytearray(ram);changed[0x70000]^=1
            t.begin(bytes(changed),regs)
            self.assertIsNone(t.pending[1])
            self.assertEqual(t.counts['unsupported_entries'],1)
            self.assertEqual(t.counts['unsupported: loaded font differs from supplied native resources'],1)
            t.finish(packet)
            self.assertEqual(t.scanout(0),())

    def test_source_profile_pins_and_native_config_agree(self):
        source=(ROOT/'tools/pc_core/abrams_trace.h').read_text()
        for name,values in PROFILES.items():
            ds,wrapper,ip,driver,driver_ip,fg,pin=values
            self.assertEqual(hashlib.sha256((ROOT/'GAME'/(name+'.EXE')).read_bytes()).hexdigest(),pin)
            self.assertIn('{0x%04x,0x%04x,0x%04x,0x%04x,"%s"}'%(ds,wrapper,ip,fg,name),source)

    def test_original_highlights_copies_and_cursor_cells(self):
        ram,regs,p,caller,font=self.snapshot(words=b'NO YES')
        t=TextRuns(ROOT/'GAME',p);t.begin(ram,regs)
        w,h,ink=text_pixels(decode_font(font),b'NO YES')
        pixels=bytes(1 if b else 4 for b in ink)
        t.finish(struct.pack('<6H',30,30,w,h,0,caller)+pixels)
        palette=[[i*13,i*11,i*7] for i in range(16)]
        video=bytearray(320*200*4)
        for y in range(h):
            for x in range(w):
                # Original highlight inverts colours after the string return.
                rgb=palette[4 if ink[y*w+x] else 1];at=((30+y)*320+30+x)*4
                video[at:at+4]=bytes(rgb[::-1]+[255])
        candidates=t.scanout(0)
        runs=visible_runs(candidates,video,320,200,palette)
        self.assertEqual([r['text'] for r in runs],['NO YES'])
        self.assertEqual(runs[0]['foreground'],4)
        self.assertEqual(runs[0]['uniform_background_rgb'],palette[1])
        self.assertEqual(len(visible_runs(candidates+candidates,video,320,200,palette)),1)
        # A third-colour pointer overlapping O must preserve that entire cell,
        # while intact neighbours remain eligible; do not paint over the cursor.
        video[(30*320+38)*4:(30*320+38)*4+3]=b'\x01\x02\x03'
        runs=visible_runs(candidates,video,320,200,palette)
        self.assertEqual([r['text'] for r in runs],['N','YES'])
        self.assertFalse(any(r['rect'][0]<=38<r['rect'][0]+r['rect'][2] for r in runs))
        self.assertEqual(visible_runs(candidates,video,640,100,palette),[])

    def test_cursor_requires_loaded_source_and_every_opaque_presented_pixel(self):
        ram,regs,_,_,_=self.snapshot();ram=bytearray(ram);ds=regs['ds']*16
        descriptor=0xd000
        struct.pack_into('<H',ram,ds+0x9a64,descriptor)
        struct.pack_into('<hh',ram,ds+0x04c4,60,120)
        struct.pack_into('<HHHBBH',ram,ds+descriptor,0x6000,0x100,0x178,16,15,0)
        pixels=self.sources.cursor['pixels']
        for y in range(15):
            for x in range(16):
                c=pixels[y*16+x];bit=128>>(x%8);at=y*2+x//8
                for plane in range(4):
                    if c&(1<<plane):ram[0x60100+plane*30+at]|=bit
                if not c:ram[0x60178+at]|=bit
        palette=[[i*13,i*11,i*7] for i in range(16)]
        video=bytearray(320*200*4)
        for i,c in enumerate(pixels):
            if c:
                at=((120+i//16)*320+60+i%16)*4
                video[at:at+4]=bytes(palette[c][::-1]+[255])
        cursor=self.sources.visible_cursor(ram,video,palette)
        self.assertEqual(cursor['rect'],[60,120,16,15])
        pixel=next(i for i,c in enumerate(pixels) if c)
        at=((120+pixel//16)*320+60+pixel%16)*4
        changed=bytearray(video);changed[at]^=1
        self.assertIsNone(self.sources.visible_cursor(ram,changed,palette))
        changed=bytearray(ram);changed[0x60100]^=1
        self.assertIsNone(self.sources.visible_cursor(changed,video,palette))

if __name__=='__main__':unittest.main()
