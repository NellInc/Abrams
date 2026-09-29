"""Compile exact production observer blocks against read-only captured CPU state.

This isolates new callback transport from DOSBox scheduling. It does not claim
live gameplay reached these instructions. No Unicorn dependency is needed here.
"""
import ctypes as C
import hashlib
from pathlib import Path
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[2]
CALLBACK=C.CFUNCTYPE(None,C.c_uint32,C.POINTER(C.c_uint16),C.POINTER(C.c_uint8),C.c_uint32,C.c_uint32)

class NativeRoundHook:
    def __init__(self):
        header=(ROOT/'tools/pc_core/abrams_trace.h').read_text()
        self.header_sha256=hashlib.sha256(header.encode()).hexdigest()
        first=header[header.index('    // Cheap filter before'):header.index('    // Map calls only:')]
        last=header[header.rindex('    if (segment == abrams_trace_load) {'):header.index('\n#include "abrams_observer_checkpoint.h"')]
        prefix='''#include <stdint.h>
#include <cstring>
typedef uint8_t Bit8u; typedef uint16_t Bit16u; typedef uint32_t Bit32u;
typedef void (*AbramsTraceCallback)(Bit32u,const Bit16u*,const Bit8u*,Bit32u,Bit32u);
static const Bit8u* memory;
static Bit16u r[12],abrams_trace_load;
static Bit32u reg_eip;
static Bit8u abrams_trace_snapshot[640*1024];
static bool abrams_world_drawing;
static AbramsTraceCallback abrams_trace_callback;
static struct { struct { Bit8u rgb[64]; } pal; } render;
enum {cs=8,ds=9,es=10,ss=11};
#define SegValue(s) r[s]
#define SegPhys(s) (Bit32u(r[s])*16u)
#define reg_ax r[0]
#define reg_bx r[1]
#define reg_cx r[2]
#define reg_dx r[3]
#define reg_si r[4]
#define reg_di r[5]
#define reg_bp r[6]
#define reg_sp r[7]
static Bit8u mem_readb(Bit32u a) {return memory[a];}
static Bit16u mem_readw(Bit32u a) {return memory[a]|(memory[a+1]<<8);}
static void MEM_BlockRead(Bit32u a,void* p,unsigned n) {memcpy(p,memory+a,n);}
static void instruction() {
    if (!abrams_trace_callback || !abrams_trace_load) return;
    Bit32u ip=reg_eip;
'''
        suffix='''
extern "C" void observe(const Bit8u* ram,const Bit16u* registers,Bit16u load,Bit32u ip,AbramsTraceCallback cb) {
    memory=ram;memcpy(r,registers,sizeof(r));abrams_trace_load=load;reg_eip=ip;abrams_trace_callback=cb;
    instruction();
}
'''
        self.temp=tempfile.TemporaryDirectory(prefix='abrams-round-hook-')
        directory=Path(self.temp.name);(directory/'hook.cpp').write_text(prefix+first+last+suffix)
        subprocess.run(['c++','-std=c++11','-shared','-fPIC',str(directory/'hook.cpp'),'-o',str(directory/'hook.dylib')],check=True)
        self.lib=C.CDLL(str(directory/'hook.dylib'))
        self.lib.observe.argtypes=[C.c_void_p,C.POINTER(C.c_uint16),C.c_uint16,C.c_uint32,CALLBACK]
        self.lib.observe.restype=None
        self.calls=0
    def observe(self,memory,registers,load,ip):
        if len(memory)!=640*1024 or len(registers)!=12:raise ValueError('complete original CPU snapshot required')
        buffer=C.create_string_buffer(memory);regs=(C.c_uint16*12)(*registers);events=[]
        @CALLBACK
        def callback(event,r,p,offset,length):
            events.append((event,list(r[:12]),C.string_at(p,length),offset))
        self.lib.observe(buffer,regs,load,ip,callback)
        if buffer.raw[:-1]!=memory or list(regs)!=registers:raise ValueError('observer mutated original CPU snapshot')
        self.calls+=1
        return events
    def close(self):self.temp.cleanup()
