#!/usr/bin/env python3
"""Check the actual C++ ownership observer against an independent bitwise model.

This verifies provenance arithmetic, not the original game's phase boundaries.
"""
import ctypes as C
import hashlib
import json
from pathlib import Path
import random
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HEADER = ROOT / 'tools/pc_core/abrams_vga_ownership.h'


def verify():
    wrapper = '''#include "abrams_vga_ownership.h"
static AbramsVgaOwnership state;
static AbramsBitmapOwnership bitmap;
extern "C" void reset() { state.reset(); }
extern "C" void read_address(unsigned a) { state.read(a); }
extern "C" unsigned tags(unsigned a) { return state.owners[a]; }
extern "C" unsigned pixel(unsigned a) { return state.pixel(a); }
extern "C" bool valid() { return state.valid; }
extern "C" void write_address(unsigned a, unsigned value, unsigned mode, unsigned operation,
 unsigned rotate, unsigned mask, unsigned planes, unsigned enabled, unsigned sr, bool ui) {
 state.write(a, value, mode, operation, rotate, mask, planes, enabled, sr, ui);
}
extern "C" bool prepare(const unsigned char* mask, unsigned w, unsigned h,
 int x, int y, int left, int top, int right, int bottom, unsigned page) {
 return bitmap.prepare(mask, w, h, x, y, left, top, right, bottom, page);
}
extern "C" unsigned retain(unsigned a, unsigned before, unsigned after) {
 return bitmap.retain(a, before, after);
}
'''
    with tempfile.TemporaryDirectory(prefix='abrams-ui-ownership-') as tmp:
        source, binary = Path(tmp)/'check.cpp', Path(tmp)/'check.dylib'
        source.write_text(wrapper)
        subprocess.run(['c++', '-std=c++11', '-O2', '-shared', '-fPIC', '-I', str(HEADER.parent),
                        str(source), '-o', str(binary)], check=True)
        lib = C.CDLL(str(binary))
        lib.write_address.argtypes = [C.c_uint] * 9 + [C.c_bool]
        lib.tags.restype, lib.valid.restype = C.c_uint, C.c_bool
        lib.prepare.argtypes = [C.c_void_p, C.c_uint, C.c_uint] + [C.c_int] * 6 + [C.c_uint]
        lib.prepare.restype, lib.retain.restype = C.c_bool, C.c_uint
        lib.retain.argtypes = [C.c_uint] * 3
        lib.reset()
        model = [0xffffffff] * 8
        rng = random.Random(0xAB12)
        cases = 0
        # Every mode/operation/rotation/UI combination, plus deterministic values,
        # masks, partial-plane selection, address copying and mixed provenance.
        for mode in range(4):
            for operation in range(4):
                for rotate in range(8):
                    for ui in (False, True):
                        for _ in range(16):
                            source, dest = rng.randrange(8), rng.randrange(8)
                            value, mask = rng.randrange(256), rng.randrange(256)
                            planes, enabled, sr = (rng.randrange(16) for _ in range(3))
                            expand = lambda v: sum((255 << (8*p)) for p in range(4) if v & (1 << p))
                            latch, old = model[source], model[dest]
                            expected = 0
                            for plane in range(4):
                                for bit in range(8):
                                    index = plane * 8 + bit
                                    tag = bool(old & (1 << index))
                                    if planes & (1 << plane):
                                        tag = bool(latch & (1 << index))
                                        if mode != 1:
                                            host = bool(value & (1 << ((bit + rotate) % 8)))
                                            if mode == 0: data = bool(sr & (1 << plane)) if enabled & (1 << plane) else host
                                            elif mode == 2: data = bool(value & (1 << plane))
                                            else: data = bool(sr & (1 << plane))
                                            selected = bool(mask & (1 << bit)) and (mode != 3 or host)
                                            if selected:
                                                if operation == 0 or (operation == 1 and not data) or (operation == 2 and data): tag = ui
                                                elif operation == 3 and data: tag = tag or ui
                                    if tag: expected |= 1 << index
                            lib.read_address(source)
                            lib.write_address(dest, value, mode, operation, rotate, mask * 0x01010101,
                                              expand(planes), expand(enabled), expand(sr), ui)
                            actual = lib.tags(dest)
                            if actual != expected: raise ValueError(f'ownership mismatch in case {cases}: {actual:x} != {expected:x}')
                            model[dest] = expected
                            for x in range(8):
                                want = 255 if any(expected & (1 << (p*8+7-x)) for p in range(4)) else 0
                                if lib.pixel(dest*8+x) != want: raise ValueError('pixel ownership union differs')
                            cases += 1
        if not lib.valid(): raise ValueError('valid operations invalidated the observer')
        lib.write_address(65536, 0, 0, 0, 0, 0, 0, 0, 0, False)
        if lib.valid(): raise ValueError('out-of-range write did not invalidate observation')
        lib.reset()
        lib.read_address(65536)
        if lib.valid(): raise ValueError('out-of-range latch read did not invalidate observation')
        bitmap_cases = bitmap_pixels = 0
        for page in (0, 8192):
            for x, y in [(128,50),(129,51),(28,10),(280,100),(100,8),(128,105),(-80,40),(300,40)]:
                width, height = 32, 16
                raw = bytes(rng.randrange(256) for _ in range(width * height // 8))
                data = C.create_string_buffer(raw)
                if not lib.prepare(data, width, height, x, y, 32, 13, 287, 109, page):
                    raise ValueError('valid bitmap rejected')
                # CPU-transparent ORs retain old ownership even though the VGA
                # write receives a new, fully assembled byte. Verify all pixels,
                # both drawing pages, edge bytes and the untouched other page.
                for destination in (0, 8192):
                    for at in range(8000):
                        before, after = rng.getrandbits(32), rng.getrandbits(32)
                        actual = lib.retain(destination + at, before, after)
                        for bit in range(8):
                            dx, dy = (at % 40) * 8 + bit, at // 40
                            sx, sy = dx - x, dy - y
                            opaque = (destination == page and 32 <= dx <= 287 and 13 <= dy <= 109
                                      and 0 <= sx < width and 0 <= sy < height
                                      and not (raw[sy * (width // 8) + sx // 8] & (128 >> (sx % 8))))
                            mask = 0x80808080 >> bit
                            if actual & mask != (after if opaque else before) & mask:
                                raise ValueError('CPU bitmap transparency provenance differs')
                            bitmap_pixels += 1
                bitmap_cases += 1
        for width, height, page in [(0,16,0),(7,16,0),(256,16,0),(8,201,0),(8,16,0xffffffff)]:
            if lib.prepare(data, width, height, 0, 0, 0, 0, 319, 199, page):
                raise ValueError('invalid bitmap observation accepted')
    return {'operations': cases, 'plane_bits_checked': cases * 32,
            'pixel_unions_checked': cases * 8, 'bitmap_cases': bitmap_cases,
            'bitmap_pixels_checked': bitmap_pixels, 'header_sha256': hashlib.sha256(HEADER.read_bytes()).hexdigest()}


if __name__ == '__main__': print(json.dumps(verify(), indent=2))
