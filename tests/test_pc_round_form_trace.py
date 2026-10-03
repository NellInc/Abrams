"""Round-form attribution, exact span colors and conservative lifecycle tests."""
import ctypes as C
from pathlib import Path
import struct
import unittest
from types import SimpleNamespace
from tools.pc_render_trace import Collector

ROOT=Path(__file__).resolve().parents[1]

class RoundFormTraceTests(unittest.TestCase):
    def collector(self):
        c=Collector(None,history_limit=2)
        c.active={'sequence':1,'page_offset':0,'objects':[],'unsupported':[]}
        c.current={'pointer':100,'shape_index':145,'root':25233,'primitive_ids':[],
                   'polygons':[],'round_forms':[],'draw_order':[]}
        c.active['objects'].append(c.current)
        return c
    def event(self,c,event,raw=b'',offset=25372):
        regs=[0]*12;regs[5]=offset
        registers=(C.c_uint16*12)(*regs);data=C.create_string_buffer(raw)
        c.observe(event,registers,C.addressof(data),offset,len(raw))
        if c.error:raise c.error
    def begin(self,c,radius=15):
        self.event(c,8,bytes.fromhex('1c1e001d'))
        fields=[1,25372,100,radius,160,100,32,13,287,109,0,0,0x101,0x1e1c,0x1d00]
        self.event(c,46,struct.pack('<15H',*fields))
    def span(self,c,y=100,left=150,width=20,patterns=(2,2),**overrides):
        v=[1,25372,100,y,left,width,0,*patterns]
        for i,value in overrides.items():v[int(i)]=value
        self.event(c,48,struct.pack('<9H',*(x&65535 for x in v)))

    def test_order_clipping_solid_color_and_return(self):
        c=self.collector();c.current['draw_order']=[{'kind':'polygon','index':0}]
        self.begin(c);self.span(c,left=280,width=20)
        self.event(c,47)
        form=c.current['round_forms'][0]
        self.assertEqual(form['status'],'observed')
        self.assertEqual(form['spans'],[{'y':100,'left':280,'right':288,'color':2}])
        self.assertEqual(c.current['draw_order'],[{'kind':'polygon','index':0},{'kind':'round_form','index':0}])
        self.event(c,4,offset=0)
        self.assertEqual(c.passes[-1]['objects'][0]['round_forms'][0]['status'],'observed')
        self.assertEqual(c.passes[-1]['unsupported'],[])

    def test_actual_call_pattern_words_become_exact_palette_runs(self):
        c=self.collector();self.begin(c)
        self.span(c,y=99,left=40,width=4,patterns=(0x0304,0x0506))
        self.span(c,y=100,left=40,width=4,patterns=(0x0304,0x0506))
        self.assertEqual([s['color'] for s in c.current['round_forms'][0]['spans']],[3,4,3,4,5,6,5,6])
        self.assertTrue(all(s['right']==s['left']+1 for s in c.current['round_forms'][0]['spans']))

    def test_near_plane_rejection_is_distinct_from_incomplete(self):
        c=self.collector();self.event(c,8,bytes.fromhex('1c1e001d'));self.event(c,47)
        self.assertEqual(c.current['round_forms'][0]['status'],'rejected-before-raster')
        self.assertEqual(c.current['draw_order'],[])
        c=self.collector();self.begin(c);self.event(c,4,offset=0)
        self.assertEqual(c.passes[-1]['unsupported'],[{'kind':'incomplete_round_form','pointer':100}])

    def test_radius_cap_and_offscreen_spans(self):
        c=self.collector();self.begin(c,128)
        form=c.current['round_forms'][0]
        self.assertEqual((form['radius_raw'],form['radius'],form['horizontal_radius']),(128,102,127))
        self.span(c,y=110);self.span(c,left=-100,width=10)
        self.assertEqual(form['spans'],[])
        c=self.collector();self.begin(c,65535)
        self.assertEqual(c.current['round_forms'][0]['radius'],0)

    def test_malformed_or_stale_callbacks_fail_closed(self):
        for case in ('missing','owner','page','command','after_return','nested','width','length'):
            c=self.collector()
            with self.subTest(case=case),self.assertRaises(ValueError):
                if case=='missing':self.event(c,47);continue
                self.begin(c)
                if case=='owner':self.span(c,**{'2':101})
                elif case=='page':self.span(c,**{'6':8192})
                elif case=='command':self.event(c,48,b'\0'*18,offset=25373)
                elif case=='after_return':self.event(c,47);self.span(c)
                elif case=='nested':self.event(c,8,bytes.fromhex('1c1e001d'))
                elif case=='width':self.span(c,width=321)
                else:self.event(c,48,b'\0')
            self.assertIsNone(c.active);self.assertIsNone(c.current)

    def test_detach_clears_pending_and_native_hook_is_stateless(self):
        c=self.collector();self.begin(c)
        c.detach(SimpleNamespace(pause_at_frame_end=lambda:None,core=SimpleNamespace(abrams_trace_configure=lambda *a:None)))
        self.assertIsNone(c.current);self.assertIsNone(c.active)
        header=(ROOT/'tools/pc_core/abrams_trace.h').read_text()
        self.assertIn('mem_readw(stack+depth) != 0x3247',header)
        self.assertIn('mem_readw(stack+depth+2) != abrams_trace_load+0x0b4d',header)
        self.assertIn('abrams_trace_callback(48,regs,abrams_trace_snapshot,command,18)',header)
        self.assertNotIn('static bool abrams_round',header)
        self.assertIn("'round_form_event_schema': 1",(ROOT/'tools/build_pc_trace_core.py').read_text())
        self.assertIn('manifest.get("round_form_event_schema") != 1',(ROOT/'tools/pc_bridge_host.py').read_text())
    def test_patched_upstream_sources_keep_lf_bytes_on_every_platform(self):
        # Default write_text would emit CRLF on Windows and split the patched-source hashes by platform.
        import ast
        tree=ast.parse((ROOT/'tools/build_pc_trace_core.py').read_text())
        writes=[n for n in ast.walk(tree) if isinstance(n,ast.Call) and getattr(n.func,'attr',None)=='write_text'
                and n.args and isinstance(n.args[0],ast.Name) and n.args[0].id in ('changed','after')]
        self.assertEqual(len(writes),2)
        for n in writes:
            self.assertIn(("newline","\n"),[(k.arg,getattr(k.value,'value',None)) for k in n.keywords])


class NativeRoundHookTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tools.modern_assets.native_round_hook import NativeRoundHook
        cls.native=NativeRoundHook()
    @classmethod
    def tearDownClass(cls):cls.native.close()
    def fixture(self,ip=0x123e):
        load=0x1000;ds=load+0x19e0;ram=bytearray(640*1024)
        depth={0x123e:0,0x1446:20,0x1495:20,0x14c4:16,0x1573:18,0x15c2:18,0x15f1:14,0x125f:14}[ip]
        regs=[0x302,150,20,0x504,155,25372,200,0xe000,load+0xf8d,ds,0x5000,ds]
        def put(at,value):struct.pack_into('<H',ram,at,value)
        stack=ds*16+regs[7];base=ds*16
        for offset,value in ((0x12cc,100),(0x35a8,0xa000),(0x3593,32),(0x3595,287),(0x3597,13),(0x3599,109),(0x359b,0x101),(0x359d,0x202)):
            put(base+offset,value)
        for offset,value in ((0,0x3247),(2,load+0xb4d),(4,15),(6,160),(8,100)):
            put(stack+depth+offset,value)
        if depth:put(stack+depth-6,25372);put(stack+depth-8,0x5000)
        ram[0x50000+25372:0x50000+25376]=bytes.fromhex('1c1e001d')
        if ip==0x125f:regs[5]=100
        return ram,regs,load,ip,stack,depth
    def test_compiled_entry_and_every_span_site_capture_exact_words(self):
        for ip in (0x123e,0x1446,0x1495,0x14c4,0x1573,0x15c2,0x15f1,0x125f):
            ram,regs,load,ip,_,_=self.fixture(ip)
            events=self.native.observe(bytes(ram),regs,load,ip)
            self.assertEqual(len(events),1)
            event,actual,raw,offset=events[0]
            self.assertEqual(actual,regs);self.assertEqual(offset,25372)
            words=list(struct.unpack('<'+'H'*(len(raw)//2),raw))
            expected=([1,25372,100,15,160,100,32,13,287,109,0,0x202,0x101,0x1e1c,0x1d00] if ip==0x123e else
                      [1,25372,100,100,155 if ip==0x125f else 150,1 if ip==0x125f else 20,0,
                       2 if ip==0x125f else 0x302,2 if ip==0x125f else (0x504 if ip in (0x1495,0x15c2) else 0x302)])
            self.assertEqual(words,expected);self.assertEqual(event,46 if ip==0x123e else 48)
    def test_compiled_guards_reject_invalid_caller_segments_page_and_bounds(self):
        for case in ('caller_ip','caller_cs','ds','cs','ip','page','stack_wrap','shape_wrap','odd_row'):
            with self.subTest(case=case):
                ram,r,load,ip,stack,depth=self.fixture(0x1495)
                if case=='caller_ip':struct.pack_into('<H',ram,stack+depth,0x3248)
                if case=='caller_cs':struct.pack_into('<H',ram,stack+depth+2,load+0xb4e)
                if case=='ds':r[9]+=1
                if case=='cs':r[8]+=1
                if case=='ip':ip=0x1496
                if case=='page':struct.pack_into('<H',ram,r[9]*16+0x35a8,0xa100)
                if case=='stack_wrap':r[7]=65530
                if case=='shape_wrap':struct.pack_into('<H',ram,stack+depth-6,65535)
                if case=='odd_row':r[6]=201
                self.assertEqual(self.native.observe(bytes(ram),r,load,ip),[])
    def test_compiled_command_and_return_have_no_cross_call_pending_state(self):
        ram,r,load,_,_,_=self.fixture();r[8]=load+0xb4d
        entry=self.native.observe(bytes(ram),r,load,0x31a6)
        self.assertEqual((entry[0][0],entry[0][2]),(8,bytes.fromhex('1c1e001d')))
        returned=self.native.observe(bytes(ram),r,load,0x324a)
        self.assertEqual((returned[0][0],returned[0][2]),(47,b''))
        # Attribution lifecycle belongs to Collector, native observer is stateless.
        self.assertEqual(returned,self.native.observe(bytes(ram),r,load,0x324a))

if __name__=='__main__':unittest.main()
