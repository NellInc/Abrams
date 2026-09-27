from pathlib import Path
import struct
import unittest
from tools.pc_fonts import decode_font,text_pixels
from tools.pc_text_trace import TextRuns

ROOT=Path(__file__).resolve().parents[1]


class TextTests(unittest.TestCase):
    def setUp(self):
        self.observer=TextRuns(ROOT/'GAME')
        self.palette=[[i*7,i*11,i*13] for i in range(16)]

    def draw(self,text=b'READY ',caller=0x55DF,page=0,x=52,y=165,mode=0):
        ram=bytearray(640*1024);load=0x100;ds=(load+0x19E0)*16
        font=(ROOT/'GAME/6X6.FNT').read_bytes()
        for at,v in zip((0x364E,0x3662,0x3676,0x368A),font[:4]): ram[ds+at]=v
        struct.pack_into('<H',ram,ds+0x369E,0x7000)
        ram[0x70000:0x70000+len(font)-4]=font[4:]
        struct.pack_into('<HH',ram,ds+0x35B4,0x68,load+0x1388)
        struct.pack_into('<H',ram,ds+0x35A8,0xA000+page//16)
        for c in range(16): struct.pack_into('<H',ram,ds+0x48A6+2*c,c)
        ram[ds+0x3590:ds+0x3593]=bytes([14,0,mode]);ram[ds+0x6464]=3
        pointer=0x6472;ram[ds+pointer:ds+pointer+len(text)+1]=text+b'\0'
        regs={'cs':load+0xF8D,'ds':ds//16,'ss':ds//16,'sp':0xF000}
        struct.pack_into('<5H',ram,ds+regs['sp'],caller,load,pointer,x,y)
        self.observer.begin(bytes(ram),regs)
        w,h,ink=text_pixels(decode_font(font),text)
        pixels=bytes(14 if p else (3 if mode else 0) for p in ink)
        raw=struct.pack('<6H',x,y,w,h,page,caller)+pixels
        video=bytearray(320*200*4)
        for dy in range(h):
            for dx in range(w):
                at=((y+dy)*320+x+dx)*4;r,g,b=self.palette[pixels[dy*w+dx]]
                video[at:at+4]=bytes([b,g,r,255])
        return raw,bytes(video)

    def present(self,candidates,video,palette=None):
        return self.observer.present(candidates,video,320,200,self.palette if palette is None else palette)

    def test_requires_completed_glyphs_then_matching_scanout_and_RGB_frame(self):
        raw,video=self.draw()
        self.assertEqual(self.observer.scanout(0),())
        self.observer.finish(raw)
        self.assertEqual(self.observer.scanout(8192),())
        candidates=self.observer.scanout(0)
        self.assertEqual(self.present(candidates,bytes(len(video))),[])
        self.assertEqual(self.present(candidates,video)[0]['text'],'READY ')
        self.assertEqual(self.present(candidates,video)[0]['kind'],'weapon_status')
        self.assertEqual(self.observer.present(candidates,video,640,100,self.palette),[])
        self.assertEqual(self.present(candidates,video,[]),[])
        wrong=list(self.palette);wrong[14]=[1,2,3]
        self.assertEqual(self.present(candidates,video,wrong),[])

    def test_scanout_candidate_immutable_across_later_page_redraw(self):
        raw,video=self.draw();self.observer.finish(raw);old=self.observer.scanout(0)
        raw2,video2=self.draw(b'LOAD  ');self.observer.finish(raw2)
        self.assertEqual(self.present(old,video)[0]['text'],'READY ')
        self.assertEqual(self.present(old,video2),[])
        self.assertEqual(self.present(self.observer.scanout(0),video2)[0]['text'],'LOAD  ')

    def test_full_rectangle_rejects_overwrite_even_in_background_or_one_RGB_channel(self):
        raw,video=self.draw();self.observer.finish(raw);candidates=self.observer.scanout(0)
        for channel in range(3):
            changed=bytearray(video);changed[(165*320+52)*4+channel]^=1
            self.assertEqual(self.present(candidates,bytes(changed)),[])

    def test_transparent_text_checks_actual_background_and_requires_contrast(self):
        raw,video=self.draw(b'280',caller=0x3F58,x=184,y=112,mode=1)
        self.observer.finish(raw);candidates=self.observer.scanout(0)
        item=self.present(candidates,video)[0]
        self.assertEqual((item['text'],item['speaker'],item['kind']),('280',3,'crew_secondary'))
        palette=[[0,0,0] for _ in range(16)]
        self.assertEqual(self.present(candidates,bytes(len(video)),palette),[])

    def test_bad_glyph_return_does_not_retain_stale_label(self):
        raw,video=self.draw();self.observer.finish(raw)
        raw,_=self.draw(b'LOAD  ');raw=bytearray(raw)
        raw[12:]=bytes([7])*len(raw[12:]);self.observer.finish(bytes(raw))
        self.assertEqual(self.observer.scanout(0),())
        self.assertEqual(self.observer.counts['glyph_mismatches'],1)
        raw,_=self.draw();self.observer.finish(b'')
        self.assertEqual(self.observer.scanout(0),())

    def test_unsupported_blank_and_offscreen_runs_fail_closed(self):
        for text,x in [(b'      ',52),(b'READY ',319)]:
            self.draw(text,x=x);self.observer.finish(b'')
            self.assertEqual(self.observer.scanout(0),())
        self.assertEqual(self.observer.counts['unsupported_entries'],2)

    def test_wire_schema_and_unpaired_return_rejected(self):
        with self.assertRaisesRegex(ValueError,'without entry'): self.observer.finish(b'')
        with self.assertRaisesRegex(ValueError,'entry snapshot'): self.observer.begin(b'',{})
        raw,_=self.draw()
        bad=bytearray(raw);struct.pack_into('<H',bad,0,51)
        with self.assertRaisesRegex(ValueError,'entry/return differ'): self.observer.finish(bytes(bad))
        raw,_=self.draw()
        with self.assertRaisesRegex(ValueError,'pixels'): self.observer.finish(raw[:-1])


if __name__=='__main__': unittest.main()
