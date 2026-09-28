"""Exercise the actual native observer ABI, using isolated guest storage."""
import ctypes as C
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ObserverCheckpointTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='abrams-observer-check-')
        directory = Path(cls.temp.name)
        # Use the exact observer declarations from the production translation
        # unit. The VGA stub makes any accidental guest write directly visible.
        trace = (ROOT/'tools/pc_core/abrams_trace.h').read_text()
        declarations = trace[trace.index('typedef void (*AbramsTraceCallback)'):trace.index('static bool AbramsKnownTextCaller')]
        (directory/'test.cpp').write_text('''
#include <stdint.h>
#include "abrams_vga_ownership.h"
#include "abrams_plate_ownership.h"
typedef uint8_t Bit8u;
typedef uint16_t Bit16u;
typedef uint32_t Bit32u;
static Bit8u guest[65536*4];
static struct { struct { Bit8u* linear; } mem; struct { Bit32u d; } latch; } vga;
''' + declarations + '''
#include "abrams_observer_checkpoint.h"
static void callback(Bit32u,const Bit16u*,const Bit8u*,Bit32u,Bit32u) {}
extern "C" void seed(unsigned value) {
    vga.mem.linear=guest; vga.latch.d=0x12345678;
    memset(guest,42,sizeof(guest));
    abrams_trace_callback=callback; abrams_trace_load=0x1000;
    abrams_frontend_text_mode=false;
    abrams_ownership.reset(); abrams_plates.reset();
    abrams_plates.origin[24]=(1u<<13)|24; abrams_plates.bits[24]=value;
    abrams_plates.latch_origin=abrams_plates.origin[24]; abrams_plates.latch_bits=value;
    abrams_bitmap_active=true; abrams_bitmap_return_ip=17; abrams_bitmap_return_cs=18;
    abrams_bitmap.preserve[24]=value&255; abrams_world_drawing=true;
}
extern "C" void change_guest() { guest[123]^=1; }
extern "C" void change_context() { abrams_trace_load^=1; }
extern "C" void change_latch() { vga.latch.d^=1; }
extern "C" unsigned guest_value() { return guest[123]; }
''')
        binary = directory/'test.dylib'
        subprocess.run(['c++','-std=c++11','-shared','-fPIC','-I',str(ROOT/'tools/pc_core'),
                        str(directory/'test.cpp'),'-o',str(binary)],check=True)
        cls.lib = C.CDLL(str(binary))
        cls.lib.abrams_observer_checkpoint_size.restype = C.c_size_t
        for name in ('save','load'):
            fn = getattr(cls.lib,'abrams_observer_checkpoint_'+name)
            fn.argtypes, fn.restype = [C.c_void_p,C.c_size_t],C.c_bool
        cls.size = cls.lib.abrams_observer_checkpoint_size()

    @classmethod
    def tearDownClass(cls): cls.temp.cleanup()

    def save(self):
        raw = C.create_string_buffer(self.size)
        self.assertTrue(self.lib.abrams_observer_checkpoint_save(raw,self.size))
        return raw.raw

    def load(self,raw):
        return self.lib.abrams_observer_checkpoint_load(C.create_string_buffer(raw),len(raw))

    def test_exact_host_roundtrip_and_guest_unchanged(self):
        self.lib.seed(0xffffffff)
        original = self.save()
        self.lib.seed(0)
        self.assertNotEqual(original,self.save())
        self.assertTrue(self.load(original))
        self.assertEqual(original,self.save())
        self.assertEqual(self.lib.guest_value(),42)

    def test_rejected_state_never_partially_updates_observer(self):
        for mutation in ('change_guest','change_context','change_latch'):
            self.lib.seed(0xffffffff); original=self.save()
            self.lib.seed(0); getattr(self.lib,mutation)(); before=self.save()
            self.assertFalse(self.load(original),mutation)
            self.assertEqual(before,self.save())
        self.lib.seed(0xffffffff); original=self.save()
        for raw in (original[:-1],b'\x00'+original[1:],original[:4]+b'\x02'+original[5:]):
            self.assertFalse(self.load(raw))
            self.assertEqual(original,self.save())

    def test_invalid_copy_address_rejected_before_any_host_mutation(self):
        self.lib.seed(0xffffffff); original=self.save()
        # Copy destination is the final scalar in the explicit field list.
        corrupt=original[:-4]+b'\xff'*4
        self.lib.seed(0); before=self.save()
        self.assertFalse(self.load(corrupt))
        self.assertEqual(before,self.save())

    def test_invalid_boolean_rejected_before_any_host_mutation(self):
        self.lib.seed(0xffffffff); original=self.save()
        # Explicit wire fields: header + planar bytes + owners + owner latch.
        offset=24+65536*4+65536*4+4
        corrupt=original[:offset]+b'\x02'+original[offset+1:]
        self.lib.seed(0); before=self.save()
        self.assertFalse(self.load(corrupt))
        self.assertEqual(before,self.save())


if __name__=='__main__': unittest.main()
