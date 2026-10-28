import ctypes as C
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
from tools.pc_audio_events import (AudioEvents, audio_status, SAMPLES,
                                   decode_ax_fire_context, receipt_ax_fire_context)
from tools.pc_render_trace import Collector
from tests import test_pc_session
from tests.test_pc_session import program_ram


class AudioTests(unittest.TestCase):
    def event(self, ip=0x9107, caller=0x33C4, value=1, backend=0, gate=1, reload=0):
        return struct.pack('<6H',ip,caller,value,backend,gate,reload)

    def test_original_dispatch_is_required_not_sound_id_alone(self):
        audio = AudioEvents()
        for (value,caller),(sample,voice) in SAMPLES.items():
            audio.observe(self.event(caller=caller,value=value))
            event, = audio.drain()
            self.assertEqual((event['sample'],event['voice']),(sample,voice))
            self.assertTrue(event['enabled'])
        audio.observe(self.event(caller=0))
        event, = audio.drain()
        self.assertIsNone(event['sample'])
        self.assertIsNone(event['voice'])
        self.assertEqual(audio.drain(),[])

    def test_sound_gate_and_unknown_backend_fail_closed(self):
        audio = AudioEvents()
        for backend,gate in [(0,0),(1,0),(2,1),(255,1),(0,2)]:
            audio.observe(self.event(backend=backend,gate=gate))
            self.assertFalse(audio.drain()[0]['enabled'])
        audio.observe(self.event(ip=0x8DA3, value=0))
        self.assertEqual(audio.drain()[0]['kind'],'gate')
        audio.observe(self.event(ip=0x8DA3, value=1, gate=0))
        self.assertTrue(audio.drain()[0]['enabled'])

    def test_reload_is_evidence_only_and_invalid_state_rejected(self):
        audio = AudioEvents()
        audio.observe(self.event(ip=0x35EE, reload=2))
        event, = audio.drain()
        self.assertEqual(event['kind'],'reload_complete')
        self.assertNotIn('voice',event)
        with self.assertRaisesRegex(ValueError,'loading state'): audio.observe(self.event(ip=0x35EE))
        with self.assertRaisesRegex(ValueError,'boundary'): audio.observe(b'')
        with self.assertRaisesRegex(ValueError,'boundary'): audio.observe(self.event(ip=123))

    def test_queue_overflow_never_silently_drops_requests(self):
        audio = AudioEvents(limit=2)
        audio.observe(self.event()); audio.observe(self.event())
        with self.assertRaisesRegex(ValueError,'overflow'): audio.observe(self.event())
        self.assertEqual(len(audio.drain()),2)
        audio.observe(self.event())
        self.assertEqual(len(audio.drain()),1)

    def test_audio_status_is_original_gate_and_program_bound(self):
        ram = program_ram()
        program = {'name':'SIM','load_segment':0x1ED}
        at = 0x1ED0+0x18B50+0xF48
        ram[at]=1
        self.assertTrue(audio_status(ram,program)['enabled'])
        ram[at]=0
        self.assertFalse(audio_status(ram,program)['enabled'])
        self.assertFalse(audio_status(ram,{'name':'END'})['active'])
        self.assertFalse(audio_status(ram,None)['active'])

    def test_session_batch_drain_has_monotone_ids_and_epoch_custody(self):
        core,session,_ = test_pc_session.SessionTests().make_session()
        session.before_frame()
        session.collector.audio = AudioEvents()
        run = core.run
        def emit(frames, keys):
            run(frames,keys)
            if session.collector: session.collector.audio.observe(self.event())
        core.run = emit
        session.step(3)
        self.assertEqual([e['id'] for e in session.audio_pending],[1,2,3])
        # Sampling graphics must not drain sound or cause it to repeat.
        session.sample(); session.sample()
        first = session.drain_audio()
        self.assertEqual([e['frame'] for e in first['events']],[1,2,3])
        self.assertEqual(session.drain_audio()['events'],[])
        session.step(1)
        core.ram = program_ram('END')
        session.step(1)
        end = session.drain_audio()
        self.assertEqual([e['id'] for e in end['events']],[4])
        self.assertFalse(end['active'])
        core.ram = program_ram('SIM')
        session.before_frame()
        session.collector.audio = AudioEvents()
        session.step(1)
        reentry = session.drain_audio()
        self.assertEqual(reentry['epoch'],2)
        self.assertEqual(reentry['events'][0]['id'],5)
        self.assertEqual(reentry['events'][0]['epoch'],2)
        session.close()


class AxContextTests(unittest.TestCase):
    event = AudioTests.event
    context = struct.pack('<3H', 1, 2, 3)
    metadata = {'schema': 1, 'selection': 2, 'definition_class': 3}

    def collector(self, enabled=True):
        # Only callback-local audio state is needed; no original art fixtures.
        collector = Collector.__new__(Collector)
        collector.ax_fire_context, collector._ax_fire_context = enabled, None
        collector.audio, collector.error = AudioEvents(), None
        collector.text = SimpleNamespace(sequence=7)
        collector.loop_diagnostics = False
        collector.active, collector.current = None, None
        collector.observe_video = lambda *args: None
        return collector

    def send(self, collector, event, raw=None, regs=None, offset=0):
        collector.observe_packet(event, list(range(12)) if regs is None else regs,
                                 self.context if raw is None else raw, offset)

    def test_exact_context_only_and_strict_optional_metadata(self):
        self.assertEqual(decode_ax_fire_context(self.context), self.metadata)
        for raw in (b'', self.context[:-1], self.context+b'\0', struct.pack('<3H',2,2,3),
                    struct.pack('<3H',1,0,3), struct.pack('<3H',1,1,3), struct.pack('<3H',1,2,2)):
            self.assertIsNone(decode_ax_fire_context(raw))
        for context in (None, {}, dict(self.metadata, extra=0), dict(self.metadata, schema=True),
                        dict(self.metadata, selection=2.0), dict(self.metadata, definition_class=2)):
            audio = AudioEvents(); audio.observe(self.event(), ax_fire_context=context)
            self.assertNotIn('ax_fire_context', audio.drain()[0])
        audio = AudioEvents(); audio.observe(self.event(), ax_fire_context=self.metadata)
        event, = audio.drain()
        self.assertEqual(event.pop('ax_fire_context'), self.metadata)
        ordinary = AudioEvents(); ordinary.observe(self.event())
        self.assertEqual(event, ordinary.drain()[0])

    def test_optional_receipt_requires_exact_active_or_retained_hash(self):
        with tempfile.TemporaryDirectory(prefix='abrams-ax-receipt-') as temp:
            directory, digest = Path(temp), 'a'*64
            path = directory/'abrams-trace.json'
            self.assertFalse(receipt_ax_fire_context(digest, directory))
            for receipt in ({}, {'trace_sha256':digest}, {'trace_sha256':'b'*64,'ax_fire_context_schema':1},
                            *({'trace_sha256':digest,'ax_fire_context_schema':schema} for schema in (0,2,True,'1',1.0)), []):
                path.write_text(json.dumps(receipt))
                self.assertFalse(receipt_ax_fire_context(digest, directory))
            path.write_text('{bad json')
            self.assertFalse(receipt_ax_fire_context(digest, directory))
            retained = directory/'previous'/digest/'abrams-trace.json'
            retained.parent.mkdir(parents=True)
            retained.write_text(json.dumps({'trace_sha256':digest,'ax_fire_context_schema':1}))
            self.assertTrue(receipt_ax_fire_context(digest, directory))
            path.write_text(retained.read_text()); retained.unlink()
            self.assertTrue(receipt_ax_fire_context(digest, directory))
            self.assertFalse(receipt_ax_fire_context(None, directory))

    def test_context_pairs_once_with_same_twelve_registers_and_request(self):
        collector = self.collector()
        self.send(collector, 59)
        self.assertEqual(collector.audio.drain(), [])
        self.send(collector, 25, self.event())
        event, = collector.audio.drain()
        self.assertEqual(event['ax_fire_context'], self.metadata)
        self.assertEqual((event['sample'],event['voice']), ('cannon','on_the_way'))
        self.send(collector, 25, self.event())
        self.assertNotIn('ax_fire_context', collector.audio.drain()[0])
        for index in range(12):
            self.send(collector, 59)
            regs = list(range(12)); regs[index] += 1
            self.send(collector, 25, self.event(), regs)
            self.assertNotIn('ax_fire_context', collector.audio.drain()[0])
        for raw in (self.event(caller=0), self.event(value=15,caller=0x034F),
                    self.event(ip=0x8DA3), self.event(value=2,caller=0x32FA)):
            self.send(collector,59); self.send(collector,25,raw)
            self.assertNotIn('ax_fire_context', collector.audio.drain()[0])
        self.assertIsNone(collector.error)

    def test_interrupted_or_malformed_context_and_old_core_keep_cannon(self):
        for enabled, interrupt in ((False,None),(True,(56,b'',0)),(True,(10,b'',0)),
                                  (True,(59,b'bad',0)),(True,(59,self.context,1))):
            collector = self.collector(enabled)
            self.send(collector,59)
            if interrupt: self.send(collector,interrupt[0],interrupt[1],offset=interrupt[2])
            self.send(collector,25,self.event())
            event, = collector.audio.drain()
            self.assertNotIn('ax_fire_context',event)
            self.assertEqual((event['sample'],event['voice']),('cannon','on_the_way'))
            self.assertIsNone(collector.error)
        collector = self.collector()
        self.send(collector,59); self.send(collector,25,b'bad')
        self.assertIsNotNone(collector.error)
        self.assertIsNone(collector._ax_fire_context)
        self.assertEqual(collector.audio.drain(),[])
        self.send(collector,59); self.send(collector,25,self.event())
        self.assertNotIn('ax_fire_context',collector.audio.drain()[0])
        collector = self.collector(); self.send(collector,59)
        with patch('tools.pc_render_trace.C.string_at',side_effect=ValueError('copy failed')):
            collector.observe(25,(C.c_uint16*12)(*range(12)),None,0,12)
        self.assertIsNone(collector._ax_fire_context)
        self.assertIsInstance(collector.error,ValueError)

    def test_detach_and_reattach_clear_transient_context(self):
        collector = self.collector(); collector.callback = Mock()
        native = SimpleNamespace(abrams_trace_claim_strut=Mock(),abrams_trace_claim_motor_pool=Mock(),
                                 abrams_trace_configure=Mock())
        core = SimpleNamespace(pause_at_frame_end=Mock(),core=native,core_sha256='a'*64)
        self.send(collector,59)
        collector.detach(core)
        self.assertFalse(collector.ax_fire_context)
        self.assertIsNone(collector._ax_fire_context)
        with patch('tools.pc_render_trace.receipt_window_bundles',return_value=False), \
             patch('tools.pc_render_trace.receipt_ax_fire_context',return_value=True):
            collector.attach(core,0x1000)
        self.assertTrue(collector.ax_fire_context)
        self.send(collector,25,self.event())
        self.assertNotIn('ax_fire_context',collector.audio.drain()[0])
        self.send(collector,59)
        core.pause_at_frame_end.side_effect = ValueError('fence failed')
        with self.assertRaisesRegex(ValueError,'fence failed'): collector.detach(core)
        self.assertIsNone(collector._ax_fire_context)

    def test_context_never_adds_session_ids_or_replays_voice(self):
        core,session,_ = test_pc_session.SessionTests().make_session()
        session.before_frame()
        collector = self.collector(); session.collector.audio = collector.audio
        run = core.run
        def emit(frames,keys):
            run(frames,keys)
            self.send(collector,59); self.send(collector,25,self.event())
        core.run = emit
        session.step(3)
        events = session.drain_audio()['events']
        self.assertEqual([event['id'] for event in events],[1,2,3])
        self.assertEqual([event['voice'] for event in events],['on_the_way']*3)
        self.assertTrue(all(event['ax_fire_context']==self.metadata for event in events))
        self.assertEqual(session.drain_audio()['events'],[])
        session.close()


class NativeAxContextTests(unittest.TestCase):
    """Compile the exact production helper and audio block against stub RAM."""
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='abrams-ax-native-')
        directory = Path(cls.temp.name)
        header = (Path(__file__).resolve().parents[1]/'tools/pc_core/abrams_trace.h').read_text()
        helper = header.split('// AX fire context: begin.',1)[1].split('// AX fire context: end.',1)[0]
        start = header.index('    if (segment == abrams_trace_load &&\n        (ip == 0x9107')
        block = header[start:header.index('    if (segment == abrams_trace_load + 0x0f8d && ip == 0x1a7c)',start)]
        (directory/'test.cpp').write_text('''
#include <stdint.h>
#include <string.h>
typedef uint8_t Bit8u; typedef uint16_t Bit16u; typedef uint32_t Bit32u;
static Bit8u guest[640*1024], sent_bytes[2][12];
static Bit16u sent_regs[2][12], abrams_trace_load = 0x1000;
static Bit32u count, sent_event[2], sent_size[2], sent_offset[2], highest;
static bool outside;
static Bit8u mem_readb(Bit32u at) {
    if (at >= sizeof(guest)) { outside = true; return 0; }
    if (at + 1 > highest) highest = at + 1;
    return guest[at];
}
static Bit16u mem_readw(Bit32u at) { return mem_readb(at) | Bit16u(mem_readb(at + 1)) << 8; }
static void record(Bit32u event, const Bit16u* regs, const Bit8u* bytes, Bit32u offset, Bit32u size) {
    if (count >= 2 || size > 12) { outside = true; return; }
    sent_event[count]=event; sent_size[count]=size; sent_offset[count]=offset;
    memcpy(sent_regs[count],regs,24); if (size) memcpy(sent_bytes[count],bytes,size); ++count;
}
static void (*abrams_trace_callback)(Bit32u,const Bit16u*,const Bit8u*,Bit32u,Bit32u) = record;
''' + helper + '''
#define SegValue(which) seg_##which
#define SegPhys(which) (Bit32u(SegValue(which)) * 16u)
static void sound(Bit16u ip, Bit32u base, const Bit16u* input) {
    Bit16u reg_ax=input[0],reg_bx=input[1],reg_cx=input[2],reg_dx=input[3],reg_si=input[4],reg_di=input[5];
    Bit16u reg_bp=input[6],reg_sp=input[7],seg_cs=input[8],seg_ds=input[9],seg_es=input[10],seg_ss=input[11];
    Bit32u segment=seg_cs;
''' + block + '''
}
extern "C" Bit8u* ram() { return guest; }
extern "C" void invoke(Bit16u ip, Bit32u base, const Bit16u* regs) {
    count=highest=0; outside=false; sound(ip,base,regs);
}
extern "C" void qualify(Bit16u ip, Bit32u base, const Bit16u* regs, const Bit16u* values) {
    count=highest=0; outside=false; AbramsTraceAxFireContext(ip,base,regs,values);
}
extern "C" Bit32u events() { return count; }
extern "C" Bit32u event(Bit32u i) { return sent_event[i]; }
extern "C" Bit32u offset(Bit32u i) { return sent_offset[i]; }
extern "C" Bit32u size(Bit32u i) { return sent_size[i]; }
extern "C" Bit8u* bytes(Bit32u i) { return sent_bytes[i]; }
extern "C" Bit16u* registers(Bit32u i) { return sent_regs[i]; }
extern "C" bool out_of_range() { return outside; }
''')
        binary = directory/('test.dll' if sys.platform=='win32' else 'test.so')
        subprocess.run(['c++','-std=c++11','-shared','-fPIC',str(directory/'test.cpp'),'-o',str(binary)],check=True)
        cls.lib = C.CDLL(str(binary))
        cls.lib.ram.restype = C.POINTER(C.c_uint8 * (640*1024))
        cls.lib.invoke.argtypes = [C.c_uint16,C.c_uint32,C.POINTER(C.c_uint16)]
        cls.lib.qualify.argtypes = cls.lib.invoke.argtypes + [C.POINTER(C.c_uint16)]
        cls.lib.bytes.restype = C.POINTER(C.c_uint8)
        cls.lib.registers.restype = C.POINTER(C.c_uint16 * 12)
        cls.lib.out_of_range.restype = C.c_bool

    @classmethod
    def tearDownClass(cls):
        if sys.platform=='win32':
            import _ctypes
            handle=cls.lib._handle; cls.lib=None; _ctypes.FreeLibrary(handle)
        cls.temp.cleanup()

    def setUp(self):
        self.base, self.stack = 0x29E00, 0x90100
        self.ram = bytearray(640*1024)
        struct.pack_into('<HH',self.ram,self.stack,0x33C4,1)
        self.ram[0x28B50+0xF48] = 1
        self.ram[self.base+0x79A9] = 2
        struct.pack_into('<H',self.ram,self.base+0x79A7,0x6000)
        struct.pack_into('<H',self.ram,self.base+0x79C0,0x6000)
        self.ram[self.base+0x6002] = 3
        self.regs = (C.c_uint16*12)(1,2,3,4,5,6,7,0x100,0x1000,0x29E0,0,0x9000)

    def invoke(self, ip=0x9107):
        self.lib.ram().contents[:] = self.ram
        before = bytes(self.regs)
        self.lib.invoke(ip,self.base,self.regs)
        self.assertFalse(self.lib.out_of_range())
        self.assertEqual(bytes(self.lib.ram().contents),bytes(self.ram),'native hook changed RAM')
        self.assertEqual(bytes(self.regs),before,'native hook changed registers')
        result=[]
        for index in range(self.lib.events()):
            self.assertEqual(list(self.lib.registers(index).contents),list(self.regs))
            self.assertEqual(self.lib.offset(index),0)
            result.append((self.lib.event(index),C.string_at(self.lib.bytes(index),self.lib.size(index))))
        return result

    def test_exact_ax_context_precedes_unchanged_twelve_byte_request(self):
        self.assertEqual(self.invoke(),[(59,struct.pack('<3H',1,2,3)),(25,struct.pack('<6H',0x9107,0x33C4,1,0,1,0))])
        self.assertEqual(SAMPLES[(15,0x034F)],('pc_request_15',None))

    def test_heat_sabot_inconsistent_definitions_and_other_requests_keep_only25(self):
        original = self.ram.copy()
        for address,value,word in ((0x79A9,0,False),(0x79A9,1,False),(0x79A9,255,False),
                                   (0x79C0,0x6001,True),(0x6002,2,False),(0x79A7,0,True),
                                   (0x79A7,65534,True),(0x79A7,65535,True)):
            with self.subTest(address=address,value=value):
                self.ram = original.copy()
                if word: struct.pack_into('<H',self.ram,self.base+address,value)
                else: self.ram[self.base+address]=value
                events = self.invoke()
                self.assertEqual(events,[(25,struct.pack('<6H',0x9107,0x33C4,1,0,1,0))])
        for ip,caller,value in ((0x9107,0x33C5,1),(0x9107,0x33C4,2),(0x9107,0x034F,15),
                                (0x8DA3,0x33C4,1),(0x91D6,0x33C4,1),(0x35EE,0x33C4,1)):
            self.ram=original.copy(); struct.pack_into('<HH',self.ram,self.stack,caller,value)
            self.assertEqual(self.invoke(ip),[(25,struct.pack('<6H',ip,caller,0 if ip==0x35EE else value,0,1,0))])

    def test_context_helper_guards_segment_and_definition_reads(self):
        self.lib.ram().contents[:] = self.ram
        values = (C.c_uint16*6)(0x9107,0x33C4,1,0,1,0)
        for base in (640*1024-65535,640*1024,0xFFFFFFFF):
            self.lib.qualify(0x9107,base,self.regs,values)
            self.assertEqual(self.lib.events(),0)
            self.assertFalse(self.lib.out_of_range())
        # Last legal class byte stays inside both DS and conventional RAM.
        self.base=640*1024-65536
        struct.pack_into('<H',self.ram,self.base+0x79A7,65533)
        struct.pack_into('<H',self.ram,self.base+0x79C0,65533)
        self.ram[self.base+0x79A9]=2; self.ram[-1]=3
        self.lib.ram().contents[:]=self.ram
        self.lib.qualify(0x9107,self.base,self.regs,values)
        self.assertEqual(self.lib.events(),1)
        self.assertFalse(self.lib.out_of_range())


if __name__ == '__main__': unittest.main()
