import ctypes as C
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

from tools.pc_render_trace import Collector
import json
from tools.pc_trace_windows import (MAGIC, RAM_BYTES, build_window_bundles, event_ram, expand_window_bundle,
                                    is_window_bundle, pack_window_bundle, receipt_window_bundles,
                                    sim_event_windows, window_bundle_schemas)

ROOT = Path(__file__).resolve().parents[1]


def bundle(*windows):
    header = MAGIC + struct.pack('<H', len(windows))
    header += b''.join(struct.pack('<II', base, len(data)) for base, data in windows)
    return header + b''.join(data for _, data in windows)


class WindowBundleTests(unittest.TestCase):
    def test_expansion_places_each_window_at_its_base_and_zeroes_the_rest(self):
        ram = expand_window_bundle(bundle((0x1000, b'abc'), (RAM_BYTES - 2, b'yz')))
        self.assertIsInstance(ram, bytes)
        self.assertEqual(len(ram), RAM_BYTES)
        self.assertEqual(ram[0x1000:0x1003], b'abc')
        self.assertEqual(ram[-2:], b'yz')
        self.assertEqual(ram.count(0), RAM_BYTES - 5)

    def test_identical_overlap_is_one_snapshot_and_differing_overlap_is_rejected(self):
        self.assertEqual(expand_window_bundle(bundle((16, b'abcd'), (18, b'cdef')))[16:22], b'abcdef')
        with self.assertRaisesRegex(ValueError, 'overlapping'):
            expand_window_bundle(bundle((16, b'abcd'), (18, b'xd')))

    def test_malformed_bundles_fail_instead_of_reading_partial_ram(self):
        good = bundle((16, b'abcd'))
        for raw, message in [
                (good[:-1], 'truncated native RAM window bytes'),
                (good + b'\0', 'trailing'),
                (good[:9], 'truncated native RAM window header'),
                (MAGIC + b'\0', 'invalid'),
                (b'AWB2' + good[4:], 'invalid'),
                (bundle(), 'count'),
                (bundle(*[(i * 8, b'x') for i in range(9)]), 'count'),
                (bundle((RAM_BYTES - 1, b'ab')), 'outside 640 KiB'),
                (MAGIC + struct.pack('<HII', 1, 16, 0), 'outside 640 KiB'),
                (MAGIC + struct.pack('<HII', 1, 0xFFFFFFFF, 1) + b'x', 'outside 640 KiB')]:
            with self.assertRaisesRegex(ValueError, message):
                expand_window_bundle(raw)

    def test_a_full_snapshot_is_never_mistaken_for_a_bundle(self):
        ram = MAGIC + bytes(RAM_BYTES - 4)
        self.assertFalse(is_window_bundle(ram))
        self.assertTrue(is_window_bundle(bundle((0, b'x'))))
        self.assertTrue(is_window_bundle(memoryview(bundle((0, b'x')))))

    def test_reference_encoder_clips_to_ram_and_round_trips(self):
        ram = bytes(range(256)) * (RAM_BYTES // 256)
        raw = pack_window_bundle(ram, [(0x200, 16), (RAM_BYTES - 4, 64), (RAM_BYTES, 8), (5, 0)])
        self.assertEqual(struct.unpack_from('<H', raw, 4)[0], 2)
        expanded = expand_window_bundle(raw)
        self.assertEqual(expanded[0x200:0x210], ram[0x200:0x210])
        self.assertEqual(expanded[-4:], ram[-4:])
        with self.assertRaises(ValueError): pack_window_bundle(ram[:-1], [(0, 1)])

    def test_sim_windows_follow_the_reader_contract(self):
        ram = bytearray(RAM_BYTES); regs = {'ds': 0x1AE0, 'ss': 0x9000, 'sp': 0x100}; ds = 0x1AE00
        for at, value in zip((0x364E, 0x3662, 0x368A), (6, 6, 96)): ram[ds + at] = value
        struct.pack_into('<H', ram, ds + 0x369E, 0x7000)
        self.assertEqual(sim_event_windows(26, ram, regs), [(ds, 65536), (0x90100, 10), (0x70000, 576)])
        struct.pack_into('<H', ram, ds + 0x369E, 0)
        self.assertEqual(sim_event_windows(26, ram, regs), [(ds, 65536), (0x90100, 10)])
        self.assertEqual(sim_event_windows(28, ram, regs), [(ds, 65536), (0x90100, 10)])
        struct.pack_into('<H', ram, 0x90104, 100)
        struct.pack_into('<HHHBB', ram, ds + 100, 0x7000, 0x10, 0x1F0, 16, 15)
        self.assertEqual(sim_event_windows(29, ram, regs)[2:], [(ds + 100, 10), (0x70010, 5 * 2 * 15)])
        with self.assertRaises(ValueError): sim_event_windows(27, ram, regs)

    def test_receipts_and_web_build_info_declare_the_packet_format(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            bundled = {'trace_sha256': 'a' * 64, 'text_event_schema': 3, 'message_event_schema': 2, 'strut_event_schema': 2}
            (directory / 'abrams-trace.json').write_text(json.dumps(bundled))
            self.assertTrue(receipt_window_bundles('a' * 64, directory))
            # Another core's receipt, or none at all, never admits bundles.
            self.assertFalse(receipt_window_bundles('b' * 64, directory))
            self.assertFalse(receipt_window_bundles(None, directory))
            retained = directory / 'previous' / ('b' * 64)
            retained.mkdir(parents=True)
            (retained / 'abrams-trace.json').write_text(json.dumps(dict(
                bundled, trace_sha256='b' * 64, text_event_schema=2, message_event_schema=1, strut_event_schema=1)))
            self.assertFalse(receipt_window_bundles('b' * 64, directory))
            (directory / 'abrams-trace.json').write_text(json.dumps(dict(bundled, strut_event_schema=1)))
            with self.assertRaisesRegex(ValueError, 'Rebuild'): receipt_window_bundles('a' * 64, directory)
        self.assertFalse(build_window_bundles({'schema': 1, 'wasm_sha256': 'c' * 64}))
        self.assertTrue(build_window_bundles({'text_event_schema': 3, 'message_event_schema': 2, 'strut_event_schema': 2}))
        with self.assertRaisesRegex(ValueError, 'Rebuild'): build_window_bundles({'text_event_schema': 3})

    def test_event_ram_expands_only_declared_bundles(self):
        raw = bundle((16, b'abcd'))
        self.assertEqual(event_ram(raw, True)[16:20], b'abcd')
        full = bytes(RAM_BYTES)
        self.assertIs(event_ram(full, False), full)
        with self.assertRaises(ValueError): event_ram(raw, False)
        with self.assertRaises(ValueError): event_ram(full, True)

    def test_native_and_web_builders_declare_the_header_format(self):
        import importlib.util
        from tools import build_pc_trace_core
        from tools.pc_trace_windows import FULL_RAM_SCHEMAS, WINDOW_BUNDLE_SCHEMAS
        spec = importlib.util.spec_from_file_location('abrams_web_build_core', ROOT / 'web-prototype/build_core.py')
        web = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(web)
        self.assertEqual((web.FULL_RAM_SCHEMAS, web.WINDOW_BUNDLE_SCHEMAS), (FULL_RAM_SCHEMAS, WINDOW_BUNDLE_SCHEMAS))
        header = (ROOT / 'tools/pc_core/abrams_trace.h').read_text()
        self.assertTrue(web.WINDOW_MARKER.search(header))
        self.assertEqual(build_pc_trace_core.WINDOW_BUNDLE_SCHEMAS, WINDOW_BUNDLE_SCHEMAS)
        builder = (ROOT / 'tools/build_pc_trace_core.py').read_text()
        self.assertIn("'text_event_schema': WINDOW_BUNDLE_SCHEMAS[0], 'message_event_schema': WINDOW_BUNDLE_SCHEMAS[1], "
                      "'strut_event_schema': WINDOW_BUNDLE_SCHEMAS[2]", builder)
        # Frontend event 26 keeps its full snapshot; SIM 26/28/29 send bundles.
        self.assertIn('abrams_trace_callback(26,regs,abrams_trace_snapshot,i,sizeof(abrams_trace_snapshot));', header)
        for call in ('AbramsTraceSendWindows(26, regs, 0);', 'AbramsTraceSendWindows(28, regs, ip);',
                     'AbramsTraceSendWindows(29, regs, index);'):
            self.assertEqual(header.count(call), 1, call)

    def test_manifest_schemas_gate_bundles_as_one_triple(self):
        full = {'text_event_schema': 2, 'message_event_schema': 1, 'strut_event_schema': 1}
        self.assertFalse(window_bundle_schemas(full))
        self.assertTrue(window_bundle_schemas({'text_event_schema': 3, 'message_event_schema': 2,
                                               'strut_event_schema': 2}))
        for mixed in (dict(full, text_event_schema=3), dict(full, strut_event_schema=2), {}):
            with self.assertRaisesRegex(ValueError, 'Rebuild'):
                window_bundle_schemas(mixed)


class NativeEncoderTests(unittest.TestCase):
    """Compile the production AWB1 encoder against stub guest RAM and compare
    every byte with the Python reference encoder."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='abrams-awb1-')
        directory = Path(cls.temp.name)
        trace = (ROOT/'tools/pc_core/abrams_trace.h').read_text()
        windows = trace[trace.index('// AWB1 SIM RAM window bundle: begin.'):trace.index('// AWB1 SIM RAM window bundle: end.')]
        (directory/'test.cpp').write_text('''
#include <stdint.h>
#include <string.h>
typedef uint8_t Bit8u;
typedef uint16_t Bit16u;
typedef uint32_t Bit32u;
typedef void (*AbramsTraceCallback)(Bit32u, const Bit16u*, const Bit8u*, Bit32u, Bit32u);
static Bit8u guest[640*1024];
static Bit32u highest = 0;  // one past the highest guest byte read
static void touch(Bit32u end) { if (end > highest) highest = end; }
static Bit16u mem_readw(Bit32u at) { touch(at + 2); return Bit16u(guest[at] | guest[at + 1] << 8); }
static Bit8u mem_readb(Bit32u at) { touch(at + 1); return guest[at]; }
static void MEM_BlockRead(Bit32u at, void* out, Bit32u bytes) { touch(at + bytes); memcpy(out, guest + at, bytes); }
static const Bit8u* sent; static Bit32u sent_size, sent_offset, sent_event;
static void record(Bit32u event, const Bit16u*, const Bit8u* data, Bit32u offset, Bit32u size) {
    sent_event = event; sent = data; sent_offset = offset; sent_size = size;
}
static AbramsTraceCallback abrams_trace_callback = record;
''' + windows + '''
extern "C" Bit8u* ram() { return guest; }
extern "C" Bit32u send(Bit32u event, const Bit16u* regs, Bit32u offset, Bit8u* out, Bit32u capacity) {
    highest = 0; sent = 0; sent_size = 0xffffffffu;
    AbramsTraceSendWindows(event, regs, offset);
    if (sent_event != event || sent_offset != offset || sent_size > capacity || (sent_size && !sent)) return 0xffffffffu;
    if (sent_size) memcpy(out, sent, sent_size);
    return sent_size;
}
extern "C" Bit32u highest_read() { return highest; }
extern "C" Bit32u capacity() { return sizeof(abrams_trace_windows); }
''')
        binary = directory/('test' + ('.dll' if sys.platform == 'win32' else '.so'))
        subprocess.run(['c++', '-std=c++11', '-shared', '-fPIC', str(directory/'test.cpp'), '-o', str(binary)], check=True)
        cls.lib = C.CDLL(str(binary))
        cls.lib.ram.restype = C.POINTER(C.c_uint8 * RAM_BYTES)
        cls.lib.send.argtypes = [C.c_uint32, C.POINTER(C.c_uint16), C.c_uint32, C.c_void_p, C.c_uint32]
        for name in ('send', 'highest_read', 'capacity'): getattr(cls.lib, name).restype = C.c_uint32
        cls.out = C.create_string_buffer(cls.lib.capacity())

    @classmethod
    def tearDownClass(cls):
        if sys.platform == 'win32':
            import _ctypes
            handle = cls.lib._handle
            cls.lib = None
            _ctypes.FreeLibrary(handle)
        cls.temp.cleanup()

    def native(self, event, ram, regs, offset=7):
        self.lib.ram().contents[:] = ram
        names = ('ax', 'bx', 'cx', 'dx', 'si', 'di', 'bp', 'sp', 'cs', 'ds', 'es', 'ss')
        values = (C.c_uint16 * 12)(*[regs.get(name, 0) for name in names])
        size = self.lib.send(event, values, offset, self.out, len(self.out))
        self.assertNotEqual(size, 0xFFFFFFFF, 'native encoder sent an inconsistent packet')
        self.assertLessEqual(self.lib.highest_read(), RAM_BYTES, 'native encoder read past 640 KiB')
        return self.out.raw[:size]

    def assert_equivalent(self, event, ram, regs, windows=None):
        expected = pack_window_bundle(bytes(ram), sim_event_windows(event, bytes(ram), regs))
        actual = self.native(event, ram, regs)
        self.assertEqual(actual, expected)
        if windows is not None:
            self.assertEqual(struct.unpack_from('<H', actual, 4)[0], windows)
        # The guest is never written, and the bundle expands to its exact windows.
        self.assertEqual(bytes(self.lib.ram().contents), bytes(ram))
        expanded = expand_window_bundle(actual)
        count, = struct.unpack_from('<H', actual, 4)
        for index in range(count):
            base, length = struct.unpack_from('<II', actual, 6 + 8 * index)
            self.assertEqual(expanded[base:base + length], bytes(ram[base:base + length]))
        return actual

    def state(self, seed, ds=0x1AE0, ss=0x9000, sp=0x100):
        ram = bytearray(random.Random(seed).randbytes(RAM_BYTES))
        return ram, {'ds': ds, 'ss': ss, 'sp': sp, 'cs': ds - 0x19E0, 'ax': 1, 'bp': 2}

    def font(self, ram, ds, width, height, count, segment):
        base = ds * 16
        ram[base + 0x364E], ram[base + 0x3662], ram[base + 0x368A] = width, height, count
        struct.pack_into('<H', ram, base + 0x369E, segment)

    def descriptor(self, ram, regs, offset, segment, plane, width, height):
        stack, base = regs['ss'] * 16 + regs['sp'], regs['ds'] * 16
        struct.pack_into('<H', ram, stack + 4, offset)
        if base + offset + 10 <= RAM_BYTES:
            struct.pack_into('<HHHBB', ram, base + offset, segment, plane, 0x1F0, width, height)

    def test_text_entry_bundles_match_the_reference_encoder(self):
        for name, font, windows in (
                ('nominal 6x6', (6, 6, 96, 0x7000), 3),
                ('no loaded font', (6, 6, 96, 0), 2),
                ('empty glyph table', (6, 6, 0, 0x7000), 2),
                ('glyphs clipped at 640 KiB', (255, 255, 255, 0x9F00), 3),
                ('glyphs above 640 KiB', (8, 8, 96, 0xA000), 2),
                ('largest glyph table', (255, 255, 255, 0x0001), 3)):
            with self.subTest(name):
                ram, regs = self.state(len(name))
                self.font(ram, regs['ds'], *font)
                self.assert_equivalent(26, ram, regs, windows)

    def test_message_bundles_match_the_reference_encoder_including_stack_clipping(self):
        for name, ss, sp, windows in (('nominal', 0x9000, 0x100, 2), ('stack straddles 640 KiB', 0x9FFF, 0xC, 2),
                                      ('stack above 640 KiB', 0xA000, 0x10, 1), ('stack inside DS', 0x1AE0, 0xFFF0, 2)):
            with self.subTest(name):
                ram, regs = self.state(len(name), ss=ss, sp=sp)
                self.assert_equivalent(28, ram, regs, windows)

    def test_strut_bundles_match_the_reference_encoder(self):
        for name, args, windows in (
                ('nominal strut', (100, 0x7000, 0x10, 16, 15), 4),
                ('cupola strut', (0x200, 0x6000, 0x20, 168, 7), 4),
                ('strut clipped at 640 KiB', (100, 0x9F00, 0x0F00, 255, 255), 4),
                ('strut above 640 KiB', (100, 0xA000, 0, 16, 15), 3),
                ('narrow strut has no planes', (100, 0x7000, 0x10, 7, 15), 3),
                ('descriptor beyond 640 KiB', (0xFFFF, 0x7000, 0x10, 16, 15), 2)):
            with self.subTest(name):
                ds = 0x9000 if name == 'descriptor beyond 640 KiB' else 0x1AE0
                ram, regs = self.state(len(name), ds=ds, ss=0x8000)
                self.descriptor(ram, regs, *args)
                self.assert_equivalent(29, ram, regs, windows)

    def test_offsets_pass_through_and_other_events_send_nothing(self):
        ram, regs = self.state(1)
        self.font(ram, regs['ds'], 6, 6, 96, 0x7000)
        values = (C.c_uint16 * 12)(*[0, 0, 0, 0, 0, 0, 0, regs['sp'], 0, regs['ds'], 0, regs['ss']])
        self.lib.ram().contents[:] = ram
        self.assertEqual(self.lib.send(27, values, 5, self.out, len(self.out)), 0)
        self.assertGreater(self.lib.send(28, values, 0x3d0c, self.out, len(self.out)), 0)

    def test_bundles_are_far_smaller_than_the_snapshot_they_replace(self):
        ram, regs = self.state(2)
        self.font(ram, regs['ds'], 6, 6, 96, 0x7000)
        self.assertLess(len(self.native(26, ram, regs)), RAM_BYTES // 9)


class WebClaimBundleTests(unittest.TestCase):
    """Compile web-prototype/claim_core.h in both declared packet formats and
    require identical strut claims from a full snapshot and its bundle."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='abrams-awb1-claims-')
        directory = Path(cls.temp.name)
        (directory/'test.cpp').write_text('''
#include "claim_core.h"
extern "C" bool abrams_trace_claim_strut(unsigned, unsigned, const uint8_t*, unsigned) { return true; }
extern "C" bool abrams_trace_claim_motor_pool(unsigned) { return true; }
static AbramsWebClaims claims;
extern "C" bool configure(const uint8_t* bytes, unsigned size) { return claims.configure(bytes, size); }
extern "C" int strut(const uint16_t* regs, const uint8_t* ram, unsigned length, const uint8_t* pixels) {
    claims.reset();
    if (!claims.observe(29, regs, ram, 0, length)) return -1;
    if (!claims.observe(30, regs, pixels, 0, 64000)) return -2;
    return int(claims.receipts.size());
}
extern "C" const uint8_t* receipts() { return claims.receipts.data(); }
''')
        cls.libs = {}
        for bundles in (False, True):
            binary = directory/(f'claims{int(bundles)}' + ('.dll' if sys.platform == 'win32' else '.so'))
            subprocess.run(['c++', '-std=c++11', '-shared', '-fPIC', f'-DABRAMS_TRACE_WINDOW_BUNDLES={int(bundles)}',
                            '-I', str(ROOT/'web-prototype'), str(directory/'test.cpp'), '-o', str(binary)], check=True)
            lib = C.CDLL(str(binary))
            lib.configure.argtypes = [C.c_char_p, C.c_uint]
            lib.configure.restype = C.c_bool
            lib.strut.argtypes = [C.POINTER(C.c_uint16), C.c_char_p, C.c_uint, C.c_char_p]
            lib.strut.restype = C.c_int
            lib.receipts.restype = C.POINTER(C.c_uint8)
            cls.libs[bundles] = lib
        colours = bytes(range(1, 9))
        plates = [bytearray(64000) for _ in range(5)]
        plates[2][10 * 320 + 10:10 * 320 + 18] = colours
        catalog = b'ABCL' + struct.pack('<HH', 1, 1) + b''.join(plates) + struct.pack('<HH', 8, 1) + colours
        for lib in cls.libs.values(): assert lib.configure(catalog, len(catalog))
        ram = bytearray(random.Random(30).randbytes(RAM_BYTES))
        load, ds_seg, ss, sp = 0x1000, 0x29E0, 0x8000, 0x100
        ds, stack = ds_seg * 16, ss * 16 + sp
        struct.pack_into('<HHHHH', ram, stack, 0x1234, load, 0x100, 10, 10)
        struct.pack_into('<H', ram, ds + 0x798E, 0x200)
        struct.pack_into('<H', ram, ds + 0x200, 0x100)
        struct.pack_into('<HHHBB', ram, ds + 0x100, 0x4000, 0, 4, 8, 1)
        for plane in range(4):
            ram[0x40000 + plane] = sum(128 >> x for x, c in enumerate(colours) if c >> plane & 1)
        ram[0x40004] = 0
        struct.pack_into('<H', ram, ds + 0x35A8, 0xA000)
        ram[ds + 0x359F], ram[ds + 0x359B] = 15, 0
        cls.ram = bytes(ram)
        cls.regs = {'cs': load + 0xF8D, 'ds': ds_seg, 'ss': ss, 'sp': sp}
        cls.pixels = bytes(plates[2])

    @classmethod
    def tearDownClass(cls):
        if sys.platform == 'win32':
            import _ctypes
            for lib in cls.libs.values(): _ctypes.FreeLibrary(lib._handle)
            cls.libs = None
        cls.temp.cleanup()

    def claim(self, bundles, raw):
        names = ('ax', 'bx', 'cx', 'dx', 'si', 'di', 'bp', 'sp', 'cs', 'ds', 'es', 'ss')
        regs = (C.c_uint16 * 12)(*[self.regs.get(name, 0) for name in names])
        lib = self.libs[bundles]
        size = lib.strut(regs, raw, len(raw), self.pixels)
        return size if size <= 0 else bytes(lib.receipts()[:size])

    def test_a_bundle_claims_exactly_what_its_full_snapshot_claims(self):
        full = self.claim(False, self.ram)
        self.assertIsInstance(full, bytes)
        self.assertEqual(struct.unpack_from('<II', full), (0, 3))
        windows = sim_event_windows(29, self.ram, self.regs)
        self.assertEqual(self.claim(True, pack_window_bundle(self.ram, windows)), full)

    def test_each_build_refuses_the_other_format_and_malformed_bundles(self):
        raw = pack_window_bundle(self.ram, sim_event_windows(29, self.ram, self.regs))
        self.assertEqual(self.claim(False, raw), -1)
        self.assertEqual(self.claim(True, self.ram), -1)
        for broken in (raw[:-1], raw + b'\0', b'AWB2' + raw[4:], raw[:6] + b'\xff' * 8 + raw[14:]):
            self.assertEqual(self.claim(True, broken), -1)

    def test_a_bundle_without_the_strut_window_fails_closed(self):
        windows = sim_event_windows(29, self.ram, self.regs)[:3]
        self.assertEqual(self.claim(True, pack_window_bundle(self.ram, windows)), -1)


class CollectorBundleTests(unittest.TestCase):
    def setUp(self):
        self.collector = Collector(None, history_limit=2, window_bundles=True)
        self.seen = []
        self.collector.text.begin = lambda ram, regs: self.seen.append((26, ram))
        self.collector.text.messages.observe = lambda ram, regs, ip: self.seen.append((28, ram))
        self.collector.struts.begin = lambda ram, regs, index: self.seen.append((29, ram))

    def send(self, event, raw):
        data = C.create_string_buffer(raw, len(raw))
        self.collector.observe(event, (C.c_uint16 * 12)(*[0] * 12), C.addressof(data), 0, len(raw))

    def test_native_and_replayed_bundles_reach_readers_as_exact_640k_bytes(self):
        raw = bundle((0x1AE00, b'DS'), (0x70000, b'glyphs'))
        self.send(26, raw)
        self.collector.observe_packet(28, [0] * 12, raw, 0)
        self.collector.observe_packet(29, [0] * 12, memoryview(raw), 0)
        self.assertIsNone(self.collector.error)
        self.assertEqual([event for event, _ in self.seen], [26, 28, 29])
        for _, ram in self.seen:
            self.assertIsInstance(ram, bytes)
            self.assertEqual(len(ram), RAM_BYTES)
            self.assertEqual((ram[0x1AE00:0x1AE02], ram[0x70000:0x70006]), (b'DS', b'glyphs'))

    def test_full_snapshots_pass_through_unchanged_from_a_full_snapshot_core(self):
        self.collector.window_bundles = False
        full = MAGIC + bytes(RAM_BYTES - 4)
        self.collector.observe_packet(26, [0] * 12, full, 0)
        self.assertIs(self.seen[0][1], full)

    def test_the_declared_packet_format_is_enforced_both_ways(self):
        for bundles, raw, message in ((False, bundle((0x1AE00, b'DS')), 'full-snapshot trace core'),
                                      (True, bytes(RAM_BYTES), 'lacks its RAM window bundle'),
                                      (True, b'', 'lacks its RAM window bundle')):
            for event in (26, 28, 29):
                with self.subTest(bundles=bundles, event=event, size=len(raw)):
                    collector = Collector(None, history_limit=2, window_bundles=bundles)
                    collector.observe_packet(event, [0] * 12, raw, 0)
                    self.assertRegex(str(collector.error), message)
        self.assertFalse(Collector(None, history_limit=2).window_bundles)

    def test_malformed_bundle_is_a_collector_error_not_a_partial_read(self):
        self.send(26, bundle((16, b'abcd'))[:-1])
        self.assertEqual(self.seen, [])
        self.assertRegex(str(self.collector.error), 'truncated native RAM window bytes')

    def test_other_events_are_never_expanded(self):
        # Event 30 carries a 64,000-byte framebuffer, not a RAM window bundle.
        self.collector.struts.finish = lambda raw, page: self.seen.append((30, raw))
        raw = bundle((0, b'x'))
        self.collector.observe_packet(30, [0] * 12, raw, 0)
        self.assertIs(self.seen[0][1], raw)


if __name__ == '__main__':
    unittest.main()
