import ctypes as C
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from tools.verify_pc_ui_ownership import verify

ROOT = Path(__file__).resolve().parents[1]


class UiOwnershipTests(unittest.TestCase):
    def test_native_observer_against_bitwise_reference(self):
        result = verify()
        self.assertEqual(result['operations'], 4096)
        self.assertEqual(result['plane_bits_checked'], 131072)
        self.assertEqual(result['pixel_unions_checked'], 32768)
        self.assertEqual(result['bitmap_cases'], 16)
        self.assertEqual(result['bitmap_pixels_checked'], 2048000)


class FrameMaskHookTests(unittest.TestCase):
    """Compile the production VGA/raster/frame hooks against a stub VGA."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='abrams-frame-masks-')
        directory = Path(cls.temp.name)
        trace = (ROOT/'tools/pc_core/abrams_trace.h').read_text()
        declarations = trace[trace.index('typedef void (*AbramsTraceCallback)'):trace.index('static bool AbramsKnownTextCaller')]
        hooks = trace[trace.index('// START/BRIEF/END consume no EGA ownership'):trace.index('// Separate original-program text path.')]
        (directory/'test.cpp').write_text('''
#include <stdint.h>
#include <string.h>
#include "abrams_vga_ownership.h"
#include "abrams_plate_ownership.h"
typedef uint8_t Bit8u;
typedef uint16_t Bit16u;
typedef uint32_t Bit32u;
enum { M_EGA = 1, M_VGA = 2 };
static Bit8u guest[65536*4];
static struct { int mode;
    struct { Bit32u write_mode, raster_op, data_rotate, full_bit_mask, full_map_mask,
             full_not_enable_set_reset, full_set_reset; } config;
    struct { Bit8u* linear; } mem; struct { Bit32u d; } latch; } vga;
static struct { struct { Bit8u rgb[64]; } pal; } render;
static Bit16u stub_cs;
#define SegValue(segment) stub_cs
''' + declarations + hooks + '''
static Bit32u events[64], lengths[64], count;
static void callback(Bit32u event,const Bit16u*,const Bit8u* data,Bit32u,Bit32u length) {
    if (count < 64) { events[count] = event; lengths[count] = data ? length : 0; ++count; }
}
extern "C" void setup(bool frontend) {
    vga.mem.linear = guest; vga.mode = M_EGA;
    vga.config.full_bit_mask = vga.config.full_map_mask = 0xffffffffu;
    vga.config.full_not_enable_set_reset = 0xffffffffu;
    abrams_trace_callback = callback; abrams_trace_load = 0x1000;
    abrams_frontend_text_mode = frontend; abrams_world_drawing = true;
    abrams_ownership.reset(); abrams_plates.reset(); count = 0;
}
extern "C" void driver_pixel() { abrams_plates.origin[0] = 8u << 13; abrams_plates.bits[0] = 0xffffffffu; }
extern "C" void write(Bit32u address, Bit8u value) { AbramsTraceVgaWrite(address, value); }
extern "C" Bit32u owner(Bit32u address) { return abrams_ownership.owners[address]; }
extern "C" void frame(Bit32u slot) {
    AbramsTraceScanout(0);
    for (Bit32u row = 0; row < 200; ++row) AbramsTraceRasterLine(row * 320, row, 320, 0x7ffff);
    AbramsTraceVideoComplete(slot);
}
extern "C" bool row_rasterized(Bit32u row) { return abrams_ui_rows[row]; }
extern "C" Bit32u event_count() { return count; }
extern "C" Bit32u event_at(Bit32u i) { return events[i]; }
extern "C" Bit32u length_at(Bit32u i) { return lengths[i]; }
''')
        binary = directory/('test' + ('.dll' if sys.platform == 'win32' else '.so'))
        subprocess.run(['c++','-std=c++11','-shared','-fPIC','-I',str(ROOT/'tools/pc_core'),
                        str(directory/'test.cpp'),'-o',str(binary)],check=True)
        cls.lib = C.CDLL(str(binary))
        for name in ('owner','event_count','event_at','length_at'):
            getattr(cls.lib,name).restype = C.c_uint32
        cls.lib.row_rasterized.restype = C.c_bool
        cls.lib.setup.argtypes = [C.c_bool]

    @classmethod
    def tearDownClass(cls):
        if sys.platform == 'win32':
            import _ctypes
            handle = cls.lib._handle
            cls.lib = None
            _ctypes.FreeLibrary(handle)
        cls.temp.cleanup()

    def packets(self):
        return [(self.lib.event_at(i), self.lib.length_at(i)) for i in range(self.lib.event_count())]

    def test_frontend_mode_skips_ega_provenance_and_masks(self):
        self.lib.setup(True)
        self.lib.write(7, 255)
        self.assertEqual(self.lib.owner(7), 0xffffffff)
        self.lib.frame(1)
        self.assertFalse(self.lib.row_rasterized(0))
        # Scanout and slot pairing remain; no 19/31/24 masks are copied.
        self.assertEqual(self.packets(), [(10, 64), (11, 0)])

    def test_sim_mode_sends_masks_and_driver_mask_only_when_drawn(self):
        self.lib.setup(False)
        self.lib.write(7, 255)
        self.assertNotEqual(self.lib.owner(7), 0xffffffff)
        self.lib.frame(2)
        self.assertEqual(self.packets(), [(10, 64), (19, 64000), (31, 0), (24, 64000), (11, 0)])
        self.lib.setup(False)
        self.lib.driver_pixel()
        self.lib.frame(0)
        self.assertEqual(self.packets(), [(10, 64), (19, 64000), (31, 192000), (24, 64000), (11, 0)])
        # The flag is per frame: the next frame without the pixel sends none.
        self.lib.setup(False)
        self.lib.frame(0)
        self.assertEqual(self.packets()[2], (31, 0))


class StrutArmHookTests(unittest.TestCase):
    """Compile the production bitmap/strut-table entry against stub guest RAM."""

    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='abrams-strut-arm-')
        directory = Path(cls.temp.name)
        trace = (ROOT/'tools/pc_core/abrams_trace.h').read_text()
        declarations = trace[trace.index('typedef void (*AbramsTraceCallback)'):trace.index('static bool AbramsKnownTextCaller')]
        start = trace.index('    if (segment == abrams_trace_load + 0x0f8d && ip == 0x0347) {')
        entry = trace[start:trace.index('    if (segment == abrams_trace_load) {', start)]
        # The event-29 site emits through the AWB1 window encoder.
        windows = trace[trace.index('// AWB1 SIM RAM window bundle: begin.'):trace.index('// AWB1 SIM RAM window bundle: end.')]
        (directory/'test.cpp').write_text('''
#include <stdint.h>
#include <string.h>
#include "abrams_vga_ownership.h"
#include "abrams_plate_ownership.h"
typedef uint8_t Bit8u;
typedef int16_t Bit16s;
typedef uint16_t Bit16u;
typedef uint32_t Bit32u;
static Bit8u guest[640*1024];
static Bit16u reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di, reg_bp, reg_sp;
static Bit16u mem_readw(Bit32u at) { return Bit16u(guest[at] | guest[at + 1] << 8); }
static Bit8u mem_readb(Bit32u at) { return guest[at]; }
static void MEM_BlockRead(Bit32u at, void* out, Bit32u bytes) { memcpy(out, guest + at, bytes); }
#define SegPhys(segment) 0x30000u
#define SegValue(segment) Bit16u(0)
''' + declarations + windows + '''
static Bit32u events, last_index;
static void callback(Bit32u event, const Bit16u*, const Bit8u*, Bit32u offset, Bit32u) {
    if (event == 29) { ++events; last_index = offset; }
}
static void word(Bit32u at, Bit16u value) { guest[at] = Bit8u(value); guest[at + 1] = Bit8u(value >> 8); }
static void entry(Bit32u base, Bit32u segment, Bit32u ip) {
''' + entry + '''}
extern "C" void draw(Bit16u page_register, bool driver) {
    const Bit32u base = 0x20000;
    memset(guest, 0, sizeof(guest)); events = 0; last_index = 99;
    abrams_trace_callback = callback; abrams_trace_load = 0x1000;
    abrams_ownership.reset(); abrams_bitmap_active = abrams_strut_active = false;
    abrams_strut_page = 0; abrams_driver_active = driver;
    word(base + 0x35bc, 0x4512); word(base + 0x35be, 0x1f8d);   // original bitmap routine
    word(base + 0x35a8, page_register);
    reg_sp = 0x100; word(0x30100, 0x1234); word(0x30104, 0x0100); word(0x30106, 10); word(0x30108, 10);
    word(base + 0x100, 0x4000); word(base + 0x104, 0); guest[base + 0x106] = 8; guest[base + 0x107] = 1;
    guest[0x40000] = 0x0f;
    word(base + 0x798e, 0x200); word(base + 0x202, 0x0100);    // strut table entry 1
    entry(base, 0x1f8d, 0x0347);
}
extern "C" Bit32u strut_events() { return events; }
extern "C" Bit32u strut_index() { return last_index; }
extern "C" bool strut_active() { return abrams_strut_active; }
extern "C" Bit32u strut_page() { return abrams_strut_page; }
extern "C" bool bitmap_active() { return abrams_bitmap_active; }
extern "C" bool ownership_valid() { return abrams_ownership.valid; }
''')
        binary = directory/('test' + ('.dll' if sys.platform == 'win32' else '.so'))
        subprocess.run(['c++','-std=c++11','-shared','-fPIC','-I',str(ROOT/'tools/pc_core'),
                        str(directory/'test.cpp'),'-o',str(binary)],check=True)
        cls.lib = C.CDLL(str(binary))
        for name in ('strut_events','strut_index','strut_page'):
            getattr(cls.lib,name).restype = C.c_uint32
        for name in ('strut_active','bitmap_active','ownership_valid'):
            getattr(cls.lib,name).restype = C.c_bool
        cls.lib.draw.argtypes = [C.c_uint16, C.c_bool]

    @classmethod
    def tearDownClass(cls):
        if sys.platform == 'win32':
            import _ctypes
            handle = cls.lib._handle
            cls.lib = None
            _ctypes.FreeLibrary(handle)
        cls.temp.cleanup()

    def test_display_pages_arm_the_strut_claim(self):
        for register, page in ((0xa000, 0), (0xa200, 8192)):
            with self.subTest(page=page):
                self.lib.draw(register, False)
                self.assertEqual((self.lib.strut_events(), self.lib.strut_index()), (1, 1))
                self.assertTrue(self.lib.strut_active())
                self.assertEqual(self.lib.strut_page(), page)
                self.assertTrue(self.lib.bitmap_active())

    def test_other_pages_keep_bitmap_ownership_without_strut_claim(self):
        # Only checkpointable display pages arm; others emit no 29/30 and the
        # draw keeps ordinary bitmap ownership (no observer-wide invalidation).
        self.lib.draw(0xa100, False)
        self.assertEqual(self.lib.strut_events(), 0)
        self.assertFalse(self.lib.strut_active())
        self.assertEqual(self.lib.strut_page(), 0)
        self.assertTrue(self.lib.bitmap_active())
        self.assertTrue(self.lib.ownership_valid())

    def test_driver_station_draw_never_arms(self):
        self.lib.draw(0xa000, True)
        self.assertEqual(self.lib.strut_events(), 0)
        self.assertFalse(self.lib.strut_active())


class WorldBackgroundCallerHookTests(unittest.TestCase):
    """Compile the production 340b/36c8/3707 dispatch against captured-shape RAM.

    The destroyed-GPS black panel calls 340b after the world pass. Only the two
    world-background callers may report event 13 (which drops the completed
    pass); any other caller is payload-free event 57 and its 36c8/3707 calls
    report nothing. The hook's own instance keeps abrams_world_drawing private.
    """
    LOAD = 0x1000

    @classmethod
    def setUpClass(cls):
        from tools.modern_assets.native_round_hook import NativeRoundHook
        cls.native = NativeRoundHook()

    @classmethod
    def tearDownClass(cls):
        cls.native.close()

    def observe(self, ip, caller_ip=0x040e, caller_cs=None, marker=0x012c, segment=None):
        load = self.LOAD; ds = load + 0x19e0; bp = 0xe000
        ram = bytearray(640 * 1024)
        base = ds * 16; stack = ds * 16 + bp
        struct.pack_into('<H', ram, base + 0x358c, marker)
        ram[base + 0x35a0:base + 0x35aa] = bytes(range(1, 9)) + b'\x00\xa0'
        struct.pack_into('<HH', ram, stack + 2, caller_ip, load + 0x0b4d if caller_cs is None else caller_cs)
        ram[stack + 12:stack + 16] = b'\x05\x00\x08\x00'
        regs = [0, 0, 0, 2, 0, 0, bp, 0xd000, load + 0x0b4d if segment is None else segment, ds, ds, ds]
        return self.native.observe(bytes(ram), regs, load, ip)

    def test_only_world_callers_start_a_background_redraw(self):
        world = bytes(range(1, 9)) + b'\x00\xa0'
        # A completed world pass, then the panel's 340b: event 57, no payload,
        # and its fills report nothing.
        self.assertEqual([(e[0], e[2], e[3]) for e in self.observe(0x340b)], [(13, world, 0x35a0)])
        self.assertEqual(self.observe(0x02c1, segment=self.LOAD)[0][0], 4)
        self.assertEqual([(e[0], e[2], e[3]) for e in self.observe(0x340b, caller_ip=0x0c75)], [(57, b'', 0)])
        self.assertEqual(self.observe(0x36c8), [])
        self.assertEqual(self.observe(0x3707), [])
        # A world caller during the panel window would still be a redraw;
        # a non-world one right after it clears world drawing again.
        self.assertEqual([e[0] for e in self.observe(0x340b, caller_ip=0x04ce)], [13])
        self.assertEqual([e[0] for e in self.observe(0x36c8)], [16])
        self.assertEqual([(e[0], e[2]) for e in self.observe(0x3707)], [(15, b'\x05\x00\x08\x00')])
        for case in ({'caller_ip': 0x0c75}, {'caller_cs': self.LOAD}, {'marker': 0}):
            with self.subTest(**case):
                self.assertEqual([(e[0], e[2]) for e in self.observe(0x340b, **case)], [(57, b'')])
                self.assertEqual(self.observe(0x36c8) + self.observe(0x3707), [])
        # Frame end also closes world drawing for stray background fills.
        self.observe(0x340b)
        self.observe(0x02c1, segment=self.LOAD)
        self.assertEqual(self.observe(0x36c8), [])


if __name__ == '__main__': unittest.main()
