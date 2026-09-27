#!/usr/bin/env python3
"""Check conservative native plate tags against independent per-bit origins."""
import ctypes as C
import hashlib
import json
from pathlib import Path
import random
import subprocess
import tempfile

HEADER = Path(__file__).resolve().parent / 'pc_core/abrams_plate_ownership.h'


def verify():
    wrapper = '''#include "abrams_plate_ownership.h"
static AbramsPlateOwnership s;
extern "C" bool claim(unsigned page,unsigned plate,const uint8_t* mask) { return s.claim_bitmap(page,plate,mask); }
extern "C" void reset() { s.reset(); }
extern "C" void read_address(unsigned a) { s.read(a); }
extern "C" unsigned origin(unsigned a) { return s.origin[a]; }
extern "C" unsigned bits(unsigned a) { return s.bits[a]; }
extern "C" unsigned pixel(unsigned a) { return s.pixel(a); }
extern "C" bool valid() { return s.valid; }
extern "C" void write_address(unsigned a,unsigned v,unsigned m,unsigned op,unsigned r,
 unsigned mask,unsigned planes,unsigned enabled,unsigned sr,unsigned tag) {
 s.write(a,v,m,op,r,mask,planes,enabled,sr,tag);
}
extern "C" void retain(unsigned a,unsigned tag,unsigned bits,unsigned mask) { s.retain(a,tag,bits,mask); }
extern "C" void copy_pixel(unsigned src,unsigned dest,unsigned mask) {
 s.read(dest);
 s.write(dest,0,2,0,0,mask,0xffffffff,0,0,s.origin[src],s.bits[src]);
}
'''
    with tempfile.TemporaryDirectory(prefix='abrams-plate-tags-') as temp:
        cpp, binary = Path(temp)/'check.cpp', Path(temp)/'check.dylib'
        cpp.write_text(wrapper)
        subprocess.run(['c++','-std=c++11','-O2','-shared','-fPIC','-I',str(HEADER.parent),str(cpp),'-o',str(binary)],check=True)
        lib = C.CDLL(str(binary))
        lib.write_address.argtypes = [C.c_uint] * 10
        lib.origin.restype = C.c_uint
        lib.bits.restype, lib.valid.restype = C.c_uint, C.c_bool
        lib.retain.argtypes = [C.c_uint] * 4
        lib.copy_pixel.argtypes = [C.c_uint] * 3
        lib.claim.argtypes=[C.c_uint,C.c_uint,C.POINTER(C.c_uint8)]
        lib.claim.restype=C.c_bool
        lib.reset()
        # Independent model keeps each of 32 plane bits separately. The C++
        # representation may drop mixed origins, but must never claim a wrong one.
        model = [[0] * 32 for _ in range(8)]
        rng = random.Random(0xAB15)
        cases = claimed = 0
        expand = lambda v: sum(255 << (8*p) for p in range(4) if v & (1 << p))
        for mode in range(4):
            for operation in range(4):
                for rotate in range(8):
                    for _ in range(32):
                        source, dest = rng.randrange(8), rng.randrange(8)
                        value, mask = rng.randrange(256), rng.randrange(256)
                        planes, enabled, sr = (rng.randrange(16) for _ in range(3))
                        authored = (rng.randrange(8) << 13) | dest
                        if authored < 8192: authored = 0
                        expected = list(model[dest])
                        for p in range(4):
                            for bit in range(8):
                                index = p * 8 + bit
                                if not planes & (1 << p): continue
                                tag = model[source][index]
                                if mode != 1:
                                    host = bool(value & (1 << ((bit + rotate) % 8)))
                                    if mode == 0: data = bool(sr & (1 << p)) if enabled & (1 << p) else host
                                    elif mode == 2: data = bool(value & (1 << p))
                                    else: data = bool(sr & (1 << p))
                                    selected = bool(mask & (1 << bit)) and (mode != 3 or host)
                                    if selected:
                                        if operation == 0 or (operation == 1 and not data) or (operation == 2 and data): tag = authored
                                        elif operation == 3 and data: tag = 0
                                expected[index] = tag
                        lib.read_address(source)
                        lib.write_address(dest,value,mode,operation,rotate,mask*0x01010101,
                                          expand(planes),expand(enabled),expand(sr),authored)
                        tag, bits = lib.origin(dest), lib.bits(dest)
                        for bit in range(32):
                            if bits & (1 << bit):
                                if not tag or tag != expected[bit]: raise ValueError('native plate bit claims incorrect origin')
                                claimed += 1
                        model[dest] = expected
                        cases += 1
        if claimed < 1000 or not lib.valid(): raise ValueError('observer lost useful coverage or validity')
        # Concrete complete-plane writes, all seven IDs, both pages, copy,
        # changed coordinate, identical-colour UI, XOR and transparent bitmap.
        explicit = 0
        for plate in range(1,8):
            for page in (0,8192):
                lib.reset()
                at, tag = page + 123, (plate << 13) | 123
                for plane in range(4):
                    lib.read_address(at)
                    lib.write_address(at,0,0,0,0,0xffffffff,255 << (8*plane),0,0,tag)
                for bit in range(8):
                    if lib.pixel(at*8+bit) != plate: raise ValueError('complete plate pixel unavailable')
                before_tag, before_bits = lib.origin(at), lib.bits(at)
                lib.read_address(at)
                lib.write_address(at,0,0,0,0,0x80808080,0xffffffff,0,0,0)
                if lib.pixel(at*8) != 0 or lib.pixel(at*8+1) != plate:
                    raise ValueError('identical black UI write did not remove plate provenance')
                lib.retain(at,before_tag,before_bits,0x80)
                if lib.pixel(at*8) != plate: raise ValueError('CPU bitmap transparency failed to retain plate')
                lib.read_address(at)
                lib.write_address(at,0xff,0,3,0,0x80808080,0xffffffff,0,0,0)
                if lib.pixel(at*8) != 0: raise ValueError('XOR-inverted plate remained replaceable')
                other = (8192-page) + 123
                lib.read_address(at)
                lib.write_address(other,0,1,0,0,0,0xffffffff,0,0,0)
                if lib.pixel(other*8+1) != plate or lib.pixel(other*8) != 0:
                    raise ValueError('page-copy provenance mismatch')
                # CPU dissolve copies selected source bits after reading the
                # destination latch. Unknown source bits must remain unknown.
                lib.read_address(other)
                lib.write_address(other,0,0,0,0,0xffffffff,0xffffffff,0,0,0)
                for bit in range(8): lib.copy_pixel(at,other,0x80808080 >> bit)
                if lib.pixel(other*8+1) != plate or lib.pixel(other*8) != 0:
                    raise ValueError('CPU dissolve copied nonexistent source provenance')
                lib.read_address(at)
                lib.write_address(other+1,0,1,0,0,0,0xffffffff,0,0,0)
                if any(lib.pixel((other+1)*8+b) for b in range(8)):
                    raise ValueError('shifted copy mapped artwork to wrong coordinate')
                explicit += 1
        # Loading a new plate over another must retain the first newly written
        # plane. Dropping both conflicting sources loses that plane forever.
        lib.reset()
        at=123
        for plate in (2,4,3,1,5):
            for plane in range(4):
                lib.read_address(at)
                lib.write_address(at,0,0,0,0,0xffffffff,255 << (8*plane),0,0,(plate << 13)|at)
                if plane < 3 and any(lib.pixel(at*8+b) for b in range(8)):
                    raise ValueError('partial new plate qualified before all four planes')
            if any(lib.pixel(at*8+b)!=plate for b in range(8)):
                raise ValueError('first plane lost when a different plate replaces old origins')
            explicit+=1
        # Completed opaque bitmap writes claim only their exact selected bits.
        lib.reset();mask=(C.c_uint8*8000)();mask[123]=0x90
        if not lib.claim(8192,4,mask):raise ValueError('valid bitmap claim refused')
        for bit in range(8):
            if lib.pixel((8192+123)*8+bit)!=(4 if bit in (0,3) else 0):
                raise ValueError('bitmap claim escaped its opaque bits')
        if lib.claim(1,4,mask) or lib.claim(0,5,mask) or lib.claim(0,4,None):
            raise ValueError('unsupported bitmap claim accepted')
        explicit+=1
        # Moving roof writes retain their own signed offset through planar
        # changes; provenance never adopts another roof position's offset.
        lib.reset()
        for offset in (-161,0,83):
            tag=((offset+16384)<<17)|(8<<13)|123
            for plane in range(4):
                lib.read_address(123)
                lib.write_address(123,0,0,0,0,0xffffffff,255<<(plane*8),0,0,tag)
                if plane<3 and any(lib.pixel(123*8+b) for b in range(8)):
                    raise ValueError('partial moving roof position qualified')
            if lib.origin(123)!=tag or any(lib.pixel(123*8+b)!=8 for b in range(8)):
                raise ValueError('moving roof provenance lost position or domain')
            explicit+=1
        lib.read_address(65536)
        if lib.valid() or lib.pixel(0): raise ValueError('invalid memory read did not disable plate mask')
    return {'operations':cases, 'plane_bits_checked':cases*32, 'nonzero_claims_checked':claimed,
            'explicit_page_plate_cases':explicit, 'header_sha256':hashlib.sha256(HEADER.read_bytes()).hexdigest()}


if __name__ == '__main__': print(json.dumps(verify(),indent=2))
