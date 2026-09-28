/* Local, read-only Abrams renderer observation for DOSBox Pure.
 * Copyright (C) 2026 Nell Watson and contributors.
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Included only by core_normal.cpp. No guest writes, cycle changes or skipped
 * instructions. Configure and consume only while the emulation worker is fenced.
 */
#include "render.h"
#include "vga.h"
#include "abrams_vga_ownership.h"
#include "abrams_plate_ownership.h"
typedef void (*AbramsTraceCallback)(Bit32u, const Bit16u*, const Bit8u*, Bit32u, Bit32u);
static AbramsTraceCallback abrams_trace_callback = NULL;
static Bit16u abrams_trace_load = 0;
static Bit8u abrams_trace_snapshot[640 * 1024];
static AbramsVgaOwnership abrams_ownership;
static bool abrams_world_drawing = false;
static Bit8u abrams_ui_mask[320 * 200];
static bool abrams_ui_rows[200];
static bool abrams_ui_valid = false;
static AbramsBitmapOwnership abrams_bitmap;
static bool abrams_bitmap_active = false;
static Bit16u abrams_bitmap_return_ip, abrams_bitmap_return_cs;
static bool abrams_strut_active = false, abrams_strut_claiming = false;
static unsigned abrams_strut_page = 0;
static AbramsPlateOwnership abrams_plates;
static Bit8u abrams_plate_mask[320 * 200];
static Bit8u abrams_driver_mask[320 * 200 * 3];
static bool abrams_driver_active = false;
static unsigned abrams_driver_page = 0;
static Bit32u abrams_driver_tag = 0;
static unsigned abrams_plate_id = 0;
static bool abrams_motor_pool_claiming = false;
static bool abrams_plate_active = false;
static Bit16u abrams_plate_return_ip, abrams_plate_return_cs;
static Bit32u abrams_plate_begin, abrams_plate_end, abrams_plate_page;
static bool abrams_plate_copy_active = false;
static Bit16u abrams_plate_copy_return_ip, abrams_plate_copy_return_cs;
static Bit32u abrams_plate_copy_source, abrams_plate_copy_dest;
static bool abrams_orientation_active = false;
static Bit16u abrams_orientation_rect[5];
static bool abrams_reticle_active = false;
static unsigned abrams_reticle_page = 0;
static bool abrams_target_active = false;
static unsigned abrams_target_page = 0;
static bool abrams_text_active = false;
static bool abrams_frontend_text_mode = false;
static Bit16u abrams_text_rect[6];

static bool AbramsKnownTextCaller(Bit16u caller) {
    const Bit16u calls[] = {0x144b,0x3f1d,0x3f58,0x400d,0x4053,0x5345,0x5359,0x5379,0x538d,0x5456,0x546a,0x5483,0x54a0,0x551c,0x55b9,0x55df,0x5764,0x57a2,0x58cd,0x595a,0x59a8,0x59d4,0x62ed,0x6333,0x6347,0x635b,0x63f5,0x6409,0x641d,0x67c4,0x680d,0x6836,0x6dfe,0x6e70,0x6e93,0x6eb6,0x6ed9,0x6efc,0x6f1f,0x7f01,0x7f50,0x7fa7,0x809e,0x80b2,0x831c,0x8330,0x8349,0x88cf,0x88e2};
    for (unsigned i = 0; i < sizeof(calls)/sizeof(calls[0]); ++i)
        if (calls[i] == caller) return true;
    return false;
}

extern "C" __attribute__((visibility("default")))
void abrams_trace_configure(Bit16u load, AbramsTraceCallback callback) {
    abrams_frontend_text_mode = false;
    abrams_trace_load = load;
    abrams_trace_callback = callback;
    abrams_world_drawing = false;
    abrams_bitmap_active = false;
    abrams_strut_active = abrams_strut_claiming = false;
    abrams_plate_active = false;
    abrams_driver_active = false;
    abrams_plate_id = 0;
    abrams_motor_pool_claiming = false;
    abrams_plate_copy_active = false;
    abrams_text_active = false;
    abrams_orientation_active = false;
    abrams_reticle_active = false;
    abrams_target_active = false;
    abrams_ownership.reset();
    abrams_plates.reset();
}

// Claim only host provenance, during the verified original bitmap's return.
// No guest memory, register, VGA latch, instruction or timing value is writable.
extern "C" __attribute__((visibility("default")))
bool abrams_trace_claim_strut(unsigned page, unsigned plate, const Bit8u* mask, unsigned length) {
    if (!abrams_strut_claiming || page != abrams_strut_page || length != 8000 || !mask) return false;
    for (unsigned at = 0; at < 8000; ++at) for (unsigned bit = 0; bit < 8; ++bit)
        if ((mask[at] & (128u >> bit)) && !abrams_ownership.pixel((page + at)*8 + bit)) return false;
    return abrams_plates.claim_bitmap(page, plate, mask);
}

extern "C" __attribute__((visibility("default")))
bool abrams_trace_claim_motor_pool(unsigned page) {
    if (!abrams_motor_pool_claiming || page != abrams_plate_page) return false;
    return abrams_plates.claim_motor_pool(page);
}

extern "C" void AbramsTraceVgaRead(Bit32u address) {
    if (abrams_trace_callback && vga.mode == M_EGA) {
        abrams_ownership.read(address);
        abrams_plates.read(address);
    }
}
extern "C" void AbramsTraceVgaWrite(Bit32u address, Bit8u value) {
    if (!abrams_trace_callback || vga.mode != M_EGA) return;
    Bit32u before = address < 65536 ? abrams_ownership.owners[address] : 0xffffffffu;
    Bit32u plate_before = address < 65536 ? abrams_plates.origin[address] : 0;
    Bit32u plate_bits_before = address < 65536 ? abrams_plates.bits[address] : 0;
    Bit32u authored = 0;
    Bit32u authored_bits = 0xffffffffu;
    if (abrams_plate_active && abrams_plate_id && SegValue(cs) == abrams_trace_load + 0x1388) {
        if (address < abrams_plate_begin || address >= abrams_plate_end ||
            vga.config.write_mode != 0 || vga.config.raster_op != 0 || vga.config.data_rotate != 0 ||
            vga.config.full_bit_mask != 0xffffffffu || vga.config.full_not_enable_set_reset != 0xffffffffu) {
            abrams_plates.valid = false;
        } else authored = Bit32u((abrams_plate_id << 13) | (address - abrams_plate_page));
    }
    if (abrams_plate_copy_active && SegValue(cs) == abrams_trace_load + 0x1388) {
        if (address < abrams_plate_copy_dest || address >= abrams_plate_copy_dest + 8000 ||
            vga.config.write_mode != 2 || vga.config.raster_op != 0 ||
            vga.config.full_map_mask != 0xffffffffu) {
            abrams_plates.valid = false;
        } else {
            // The pinned dissolve routine assembles all four source plane bits
            // in the CPU, then reads the destination latch and writes mode 2.
            Bit32u source = abrams_plate_copy_source + address - abrams_plate_copy_dest;
            authored = abrams_plates.origin[source];
            authored_bits = abrams_plates.bits[source];
        }
    }
    // The original driver's turret-relative roof routine contains only its
    // two lower struts, bitmap, rectangle, roof polygons and boundary lines.
    // Stamp actual writes, preserving all four-plane and transparent-bit rules.
    if (abrams_driver_active && address >= abrams_driver_page && address < abrams_driver_page + 8000)
        authored = abrams_driver_tag | (address - abrams_driver_page);
    abrams_ownership.write(address, value, vga.config.write_mode, vga.config.raster_op,
        vga.config.data_rotate, vga.config.full_bit_mask, vga.config.full_map_mask,
        ~vga.config.full_not_enable_set_reset, vga.config.full_set_reset, !abrams_world_drawing);
    abrams_plates.write(address, value, vga.config.write_mode, vga.config.raster_op,
        vga.config.data_rotate, vga.config.full_bit_mask, vga.config.full_map_mask,
        ~vga.config.full_not_enable_set_reset, vga.config.full_set_reset, authored, authored_bits);
    if (abrams_bitmap_active && address < 65536) {
        abrams_ownership.owners[address] = abrams_bitmap.retain(address, before, abrams_ownership.owners[address]);
        abrams_plates.retain(address, plate_before, plate_bits_before, abrams_bitmap.preserve[address]);
    }
}
extern "C" void AbramsTraceRasterLine(Bit32u address, Bit32u row, Bit32u width, Bit32u wrap_mask) {
    if (!abrams_trace_callback) return;
    if (width != 320 || row >= 200 || vga.mode != M_EGA) { abrams_ui_valid = false; return; }
    for (Bit32u x = 0; x < 320; ++x) {
        abrams_ui_mask[row * 320 + x] = abrams_ownership.pixel((address + x) & wrap_mask);
        Bit32u at = (address + x) & wrap_mask, pixel = row * 320 + x;
        unsigned id = abrams_plates.pixel(at);
        // Internal domain 8 belongs to the moving driver assembly. ATBASE
        // uses domain 9 and transport plate ID 8, preserving every old ID.
        abrams_plate_mask[pixel] = id <= 7 ? Bit8u(id) : (id == 9 ? 8 : 0);
        Bit32u offset = id == 8 ? (abrams_plates.origin[at >> 3] >> 17) : 0;
        abrams_driver_mask[pixel*3] = Bit8u(offset);
        abrams_driver_mask[pixel*3+1] = Bit8u(offset >> 8);
        abrams_driver_mask[pixel*3+2] = id == 8 ? 255 : 0;
    }
    abrams_ui_rows[row] = true;
}

// These calls only annotate host framebuffer slots. They never alter VGA state.
extern "C" void AbramsTraceScanout(Bit32u page) {
    if (!abrams_trace_callback) return;
    const Bit16u regs[12] = {};
    memset(abrams_ui_rows, 0, sizeof(abrams_ui_rows));
    abrams_ui_valid = true;
    abrams_trace_callback(10, regs, (const Bit8u*)render.pal.rgb, page, 16 * 4);
}
extern "C" void AbramsTraceVideoComplete(Bit32u slot) {
    if (!abrams_trace_callback) return;
    const Bit16u regs[12] = {};
    bool complete = abrams_ui_valid && abrams_ownership.valid;
    for (unsigned y = 0; y < 200; ++y) complete = complete && abrams_ui_rows[y];
    abrams_trace_callback(19, regs, complete ? abrams_ui_mask : NULL, slot, complete ? sizeof(abrams_ui_mask) : 0);
    bool plates_complete = complete && abrams_plates.valid;
    abrams_trace_callback(31, regs, plates_complete ? abrams_driver_mask : NULL, slot,
        plates_complete ? sizeof(abrams_driver_mask) : 0);
    abrams_trace_callback(24, regs, plates_complete ? abrams_plate_mask : NULL, slot,
        plates_complete ? sizeof(abrams_plate_mask) : 0);
    abrams_trace_callback(11, regs, NULL, slot, 0);
}
extern "C" void AbramsTraceVideoPresent(Bit32u slot, const Bit8u* pixels, Bit32u width, Bit32u height) {
    if (!abrams_trace_callback) return;
    const Bit16u regs[12] = {(Bit16u)width, (Bit16u)height};
    abrams_trace_callback(12, regs, pixels, slot, width * height * 4);
}

// Separate original-program text path. Arm before boot, since EXEC/unpacking
// and the first prompt can occur inside one frame. Python independently pins
// the full wrapper/driver and every original caller before accepting a glyph.
extern "C" __attribute__((visibility("default")))
void abrams_frontend_text_configure(AbramsTraceCallback callback) {
    abrams_trace_configure(0, callback);
    abrams_frontend_text_mode = true;
}

struct AbramsFrontendProfile { Bit16u ds, wrapper, entry, foreground; const char* name; };
static const AbramsFrontendProfile abrams_frontend_profiles[] = {
    {0x1505,0x0760,0x0212,0x2648,"START"},
    {0x0c71,0x03c7,0x0212,0x0894,"BRIEF"},
    {0x0d22,0x0477,0x020e,0x637c,"END"}
};
static Bit16u abrams_frontend_return_cs, abrams_frontend_return_ip;

static INLINE void AbramsTraceFrontendInstruction() {
    Bit32u ip = reg_eip;
    if (ip != 0x0212 && ip != 0x0261 && ip != 0x020e && ip != 0x025d) return;
    const Bit16u regs[12] = {reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,
        reg_bp,reg_sp,SegValue(cs),SegValue(ds),SegValue(es),SegValue(ss)};
    if (abrams_text_active && SegValue(cs)==abrams_frontend_return_cs && ip==abrams_frontend_return_ip) {
        unsigned x=abrams_text_rect[0],y=abrams_text_rect[1],w=abrams_text_rect[2],h=abrams_text_rect[3],page=abrams_text_rect[4];
        for (unsigned i=0;i<6;++i) {
            abrams_trace_snapshot[2*i]=Bit8u(abrams_text_rect[i]);
            abrams_trace_snapshot[2*i+1]=Bit8u(abrams_text_rect[i]>>8);
        }
        for (unsigned dy=0;dy<h;++dy) for (unsigned dx=0;dx<w;++dx) {
            unsigned at=page+(y+dy)*40+(x+dx)/8,colour=0;
            for (unsigned plane=0;plane<4;++plane)
                if (vga.mem.linear[at*4+plane] & (128u>>((x+dx)&7))) colour|=1u<<plane;
            abrams_trace_snapshot[12+dy*w+dx]=Bit8u(colour);
        }
        abrams_trace_callback(27,regs,abrams_trace_snapshot,0,12+w*h);
        abrams_text_active=false;
        return;
    }
    if (ip!=0x0212 && ip!=0x020e) return;
    for (unsigned i=0;i<3;++i) {
        const AbramsFrontendProfile& p=abrams_frontend_profiles[i];
        if (ip!=p.entry || SegValue(cs)<p.wrapper+16) continue;
        unsigned load=SegValue(cs)-p.wrapper,psp=mem_readw(0xb30),base=SegPhys(ds),stack=SegPhys(ss)+reg_sp;
        if (psp!=load-16 || !psp || SegValue(ds)!=load+p.ds || base+65536>640*1024 || stack+10>640*1024) continue;
        unsigned mcb=(psp-1)*16;
        if ((mem_readb(mcb)!='M' && mem_readb(mcb)!='Z') || mem_readw(mcb+1)!=psp || mem_readw(psp*16)!=0x20cd) continue;
        bool named=true;
        for (unsigned c=0;c<8;++c) {
            unsigned n=c<strlen(p.name)?p.name[c]:0;
            if (mem_readb(mcb+8+c)!=n) named=false;
        }
        if (!named || mem_readw(stack+2)!=load) continue;
        MEM_BlockRead(0,abrams_trace_snapshot,sizeof(abrams_trace_snapshot));
        abrams_trace_callback(26,regs,abrams_trace_snapshot,i,sizeof(abrams_trace_snapshot));
        unsigned pointer=mem_readw(stack+4),n=0;
        while (n<320 && pointer+n<65536 && mem_readb(base+pointer+n)) ++n;
        unsigned x=mem_readw(stack+6),y=mem_readw(stack+8);
        unsigned cell=mem_readb(base+p.foreground+0xbe),h=mem_readb(base+p.foreground+0xd2),w=n*cell;
        unsigned page=mem_readw(base+p.foreground+0x18);
        if (abrams_text_active || !n || n==320 || pointer+n>=65536 || !cell || cell>16 || !h || h>32 ||
            x+w>320 || y+h>200 || (page!=0xa000 && page!=0xa200) || vga.mode!=M_EGA) {
            abrams_trace_callback(27,regs,NULL,0,0);abrams_text_active=false;return;
        }
        abrams_text_rect[0]=x;abrams_text_rect[1]=y;abrams_text_rect[2]=w;abrams_text_rect[3]=h;
        abrams_text_rect[4]=(page-0xa000)*16;abrams_text_rect[5]=mem_readw(stack);
        abrams_frontend_return_cs=SegValue(cs);abrams_frontend_return_ip=p.entry+79;
        abrams_text_active=true;
        return;
    }
}

static INLINE void AbramsTraceInstruction() {
    if (abrams_trace_callback && abrams_frontend_text_mode) { AbramsTraceFrontendInstruction(); return; }
    if (!abrams_trace_callback || !abrams_trace_load) return;
    Bit32u ip = reg_eip;
    if (abrams_bitmap_active && ip == abrams_bitmap_return_ip && SegValue(cs) == abrams_bitmap_return_cs) {
        if (abrams_strut_active) {
            // Read backing planes directly, preserving guest VGA latches.
            for (unsigned at = 0; at < 64000; ++at) {
                unsigned address = abrams_strut_page + at/8, colour = 0;
                for (unsigned p = 0; p < 4; ++p)
                    if (vga.mem.linear[address*4+p] & (128u >> (at&7))) colour |= 1u << p;
                abrams_trace_snapshot[at] = Bit8u(colour);
            }
            const Bit16u regs[12] = {};
            abrams_strut_claiming = true;
            abrams_trace_callback(30, regs, abrams_trace_snapshot, abrams_strut_page, 64000);
            abrams_strut_claiming = false;
        }
        abrams_strut_active = false;
        abrams_bitmap_active = false;
    }
    if (abrams_plate_active && ip == abrams_plate_return_ip && SegValue(cs) == abrams_plate_return_cs)
        abrams_plate_active = false;
    if (abrams_plate_copy_active && ip == abrams_plate_copy_return_ip && SegValue(cs) == abrams_plate_copy_return_cs)
        abrams_plate_copy_active = false;
    // Cheap filter before consulting segments on the normal instruction path.
    if (ip != 0x8ac4 && ip != 0x02c1 && ip != 0x29ad && ip != 0x0596 && ip != 0x2979 && ip != 0x0357
        && ip != 0x28d0 && ip != 0x31a6 && ip != 0x59e4 && ip != 0x340b
        && ip != 0x3707 && ip != 0x36c8 && ip != 0x8b49 && ip != 0x28e4 && ip != 0x0347
        && ip != 0x1170 && ip != 0x123a && ip != 0x1226 && ip != 0x1238 && ip != 0x1a7c
        && ip != 0x9107 && ip != 0x8da3 && ip != 0x35ee && ip != 0x91d6
        && ip != 0x020a && ip != 0x0259
        && ip != 0x3d0c && ip != 0x3d6a && ip != 0x3d8e && ip != 0x3db0 && ip != 0x3dd2
        && ip != 0x3c90 && ip != 0x3cd4 && ip != 0x3f73
        && ip != 0x6040 && ip != 0x5f81 && ip != 0x62a6
        && ip != 0x567f && ip != 0x56a5 && ip != 0x56dd
        && ip != 0x5fa5 && ip != 0x5fc3 && ip != 0x5fe1 && ip != 0x5fff
        && ip != 0x66a9 && ip != 0x66db && ip != 0x66f9 && ip != 0x6717 && ip != 0x6735 && ip != 0x6760
        && ip != 0x65f1 && ip != 0x6620 && ip != 0x6631
        && ip != 0x0f73 && ip != 0x1011 && ip != 0x102c && ip != 0x1052
        && ip != 0x1197 && ip != 0x11ae && ip != 0x1263 && ip != 0x1279 && ip != 0x1285
        && ip != 0x5ba1 && ip != 0x5c50 && ip != 0x5da3) return;
    if (SegValue(ds) != abrams_trace_load + 0x19e0) return;
    Bit32u segment = SegValue(cs), event = 0, start = 0, length = 0;
    const Bit32u base = SegPhys(ds);
    if (base + 65536 > 640 * 1024) return;
    // Map calls only: observed visible primitive arguments and completed page
    // pixels. No object coordinates or scenario-memory reconstruction is exposed.
    // Stateless return hooks introduce no checkpoint lifetime or guest writes.
    if (segment == abrams_trace_load && (ip == 0x0f73 || ip == 0x1011 || ip == 0x102c ||
        ip == 0x1052 || ip == 0x1197 || ip == 0x11ae || ip == 0x1263 || ip == 0x1279 || ip == 0x1285)) {
        const Bit16u regs[12] = {reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,
            reg_bp,reg_sp,SegValue(cs),SegValue(ds),SegValue(es),SegValue(ss)};
        unsigned page = mem_readw(base+0x35a8);
        if (page != 0xa000 && page != 0xa200) return;
        page = (page-0xa000)*16;
        if (ip == 0x0f73) {
            abrams_trace_snapshot[0]=Bit8u(page);abrams_trace_snapshot[1]=Bit8u(page>>8);
            abrams_trace_snapshot[2]=mem_readb(base+0x359e);
            // The clear colour is assigned just after this observation point.
            abrams_trace_snapshot[2]=mem_readb(base+0x777a);
            abrams_trace_snapshot[3]=mem_readb(base+0x799d);
            abrams_trace_snapshot[4]=mem_readb(base+0x799f);
            abrams_trace_snapshot[5]=mem_readb(base+0x35ae);
            abrams_trace_callback(43,regs,abrams_trace_snapshot,ip,6);
        } else if (ip == 0x1052 || ip == 0x11ae || ip == 0x1285) {
            const unsigned rect[5]={16,63,144,96,page};
            for (unsigned i=0;i<5;++i) {
                abrams_trace_snapshot[2*i]=Bit8u(rect[i]);abrams_trace_snapshot[2*i+1]=Bit8u(rect[i]>>8);
            }
            for (unsigned y=0;y<96;++y) for (unsigned x=0;x<144;++x) {
                unsigned at=page+(63+y)*40+(16+x)/8,color=0;
                for (unsigned plane=0;plane<4;++plane)
                    if (vga.mem.linear[at*4+plane] & (128u>>((16+x)&7))) color|=1u<<plane;
                abrams_trace_snapshot[10+y*144+x]=Bit8u(color);
            }
            abrams_trace_callback(45,regs,abrams_trace_snapshot,ip,10+144*96);
        } else {
            unsigned stack=SegPhys(ss)+reg_sp;
            if (stack+8>640*1024) return;
            abrams_trace_snapshot[0]=Bit8u(ip);abrams_trace_snapshot[1]=Bit8u(ip>>8);
            MEM_BlockRead(stack,abrams_trace_snapshot+2,8);
            if (ip == 0x1197) MEM_BlockRead(stack,abrams_trace_snapshot+6,4);
            abrams_trace_snapshot[10]=ip==0x1197?mem_readb(stack+4):mem_readb(base+0x359e);
            abrams_trace_snapshot[11]=mem_readb(base+0x359b);
            abrams_trace_snapshot[12]=Bit8u(page);abrams_trace_snapshot[13]=Bit8u(page>>8);
            abrams_trace_snapshot[14]=mem_readb(base+0x799d);
            abrams_trace_snapshot[15]=mem_readb(base+0x799f);
            abrams_trace_callback(44,regs,abrams_trace_snapshot,ip,16);
        }
        return;
    }
    if (segment == abrams_trace_load && (ip == 0x66a9 || (abrams_target_active &&
        (ip == 0x66db || ip == 0x66f9 || ip == 0x6717 || ip == 0x6735 || ip == 0x6760)))) {
        const Bit16u regs[12] = {reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,
            reg_bp,reg_sp,SegValue(cs),SegValue(ds),SegValue(es),SegValue(ss)};
        if (ip == 0x66a9) {
            MEM_BlockRead(base,abrams_trace_snapshot,65536);
            abrams_trace_callback(40,regs,abrams_trace_snapshot,0,65536);
            unsigned page=mem_readw(base+0x35a8);
            if ((page!=0xa000 && page!=0xa200) || vga.mode!=M_EGA) {
                abrams_trace_callback(42,regs,NULL,0,0);abrams_target_active=false;return;
            }
            abrams_target_page=(page-0xa000)*16;abrams_target_active=true;
        } else if (ip != 0x6760) {
            unsigned stack=SegPhys(ss)+reg_sp;
            if (stack+8>640*1024) {
                abrams_trace_callback(42,regs,NULL,0,0);abrams_target_active=false;return;
            }
            MEM_BlockRead(stack,abrams_trace_snapshot,8);
            abrams_trace_snapshot[8]=mem_readb(base+0x359e);
            abrams_trace_snapshot[9]=mem_readb(base+0x359b);
            MEM_BlockRead(base+0x35a8,abrams_trace_snapshot+10,2);
            abrams_trace_callback(41,regs,abrams_trace_snapshot,0,12);
        } else {
            // Finish after all original gunner cosmetics and instruments. Comparing
            // the whole visible sight rejects later occlusion and stale pages.
            const Bit16u rect[5]={32,13,256,97,Bit16u(abrams_target_page)};
            for (unsigned i=0;i<5;++i) {
                abrams_trace_snapshot[2*i]=Bit8u(rect[i]);abrams_trace_snapshot[2*i+1]=Bit8u(rect[i]>>8);
            }
            for (unsigned y=0;y<97;++y) for (unsigned x=0;x<256;++x) {
                unsigned at=abrams_target_page+(13+y)*40+(32+x)/8, color=0;
                for (unsigned p=0;p<4;++p)
                    if (vga.mem.linear[at*4+p] & (128u>>((32+x)&7))) color|=1u<<p;
                abrams_trace_snapshot[10+y*256+x]=Bit8u(color);
            }
            abrams_trace_callback(42,regs,abrams_trace_snapshot,0,10+256*97);abrams_target_active=false;
        }
        return;
    }
    if (segment == abrams_trace_load && (ip == 0x65f1 ||
        (abrams_reticle_active && (ip == 0x6620 || ip == 0x6631)))) {
        const Bit16u regs[12] = {reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,
            reg_bp,reg_sp,SegValue(cs),SegValue(ds),SegValue(es),SegValue(ss)};
        if (ip == 0x65f1) {
            MEM_BlockRead(base,abrams_trace_snapshot,65536);
            abrams_trace_callback(37,regs,abrams_trace_snapshot,0,65536);
            unsigned page=mem_readw(base+0x35a8);
            if ((page!=0xa000 && page!=0xa200) || vga.mode!=M_EGA) {
                abrams_trace_callback(39,regs,NULL,0,0);abrams_reticle_active=false;return;
            }
            abrams_reticle_page=(page-0xa000)*16;abrams_reticle_active=true;
        } else if (ip == 0x6620) {
            unsigned stack=SegPhys(ss)+reg_sp;
            if (stack+8>640*1024) {
                abrams_trace_callback(39,regs,NULL,0,0);abrams_reticle_active=false;return;
            }
            MEM_BlockRead(stack,abrams_trace_snapshot,8);
            abrams_trace_snapshot[8]=mem_readb(base+0x359e);
            abrams_trace_snapshot[9]=mem_readb(base+0x359b);
            MEM_BlockRead(base+0x35a8,abrams_trace_snapshot+10,2);
            abrams_trace_callback(38,regs,abrams_trace_snapshot,0,12);
        } else {
            const Bit16u rect[5]={134,13,51,97,Bit16u(abrams_reticle_page)};
            for (unsigned i=0;i<5;++i) {
                abrams_trace_snapshot[2*i]=Bit8u(rect[i]);abrams_trace_snapshot[2*i+1]=Bit8u(rect[i]>>8);
            }
            // Read host backing planes, never guest VGA latches.
            for (unsigned y=0;y<97;++y) for (unsigned x=0;x<51;++x) {
                unsigned at=abrams_reticle_page+(13+y)*40+(134+x)/8, color=0;
                for (unsigned p=0;p<4;++p)
                    if (vga.mem.linear[at*4+p] & (128u>>((134+x)&7))) color|=1u<<p;
                abrams_trace_snapshot[10+y*51+x]=Bit8u(color);
            }
            abrams_trace_callback(39,regs,abrams_trace_snapshot,0,10+51*97);abrams_reticle_active=false;
        }
        return;
    }
    if (segment == abrams_trace_load && (ip == 0x6040 || (abrams_orientation_active &&
        (ip == 0x5f81 || ip == 0x62a6 || ip == 0x567f || ip == 0x56a5 || ip == 0x56dd ||
         ip == 0x5fa5 || ip == 0x5fc3 || ip == 0x5fe1 || ip == 0x5fff)))) {
        const Bit16u regs[12] = {reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,
            reg_bp,reg_sp,SegValue(cs),SegValue(ds),SegValue(es),SegValue(ss)};
        if (ip == 0x6040) {
            MEM_BlockRead(base,abrams_trace_snapshot,65536);
            abrams_trace_callback(33,regs,abrams_trace_snapshot,0,65536);
            unsigned station=mem_readb(base+0x799d), page=mem_readw(base+0x35a8);
            if (station>1 || (page!=0xa000 && page!=0xa200) || vga.mode!=M_EGA) {
                abrams_trace_callback(35,regs,NULL,0,0);abrams_orientation_active=false;return;
            }
            abrams_orientation_rect[0]=station==0 ? 128 : 216;
            abrams_orientation_rect[1]=station==0 ? 137 : 83;
            abrams_orientation_rect[2]=62;abrams_orientation_rect[3]=44;
            abrams_orientation_rect[4]=(page-0xa000)*16;
            abrams_orientation_active=true;
        } else if (ip == 0x62a6) {
            unsigned x=abrams_orientation_rect[0], y=abrams_orientation_rect[1], page=abrams_orientation_rect[4];
            for (unsigned i=0;i<5;++i) {
                abrams_trace_snapshot[2*i]=Bit8u(abrams_orientation_rect[i]);
                abrams_trace_snapshot[2*i+1]=Bit8u(abrams_orientation_rect[i]>>8);
            }
            // Host backing planes only; guest reads would mutate VGA latches.
            for (unsigned dy=0;dy<44;++dy) for (unsigned dx=0;dx<62;++dx) {
                unsigned at=page+(y+dy)*40+(x+dx)/8, color=0;
                for (unsigned p=0;p<4;++p)
                    if (vga.mem.linear[at*4+p] & (128u>>((x+dx)&7))) color|=1u<<p;
                abrams_trace_snapshot[10+dy*62+dx]=Bit8u(color);
            }
            abrams_trace_callback(35,regs,abrams_trace_snapshot,0,10+62*44);
            abrams_orientation_active=false;
        } else {
            unsigned stack=SegPhys(ss)+(ip==0x5f81 ? reg_bp : reg_sp);
            if (stack+8>640*1024) {
                abrams_trace_callback(35,regs,NULL,0,0);abrams_orientation_active=false;return;
            }
            if (ip==0x5f81) {
                MEM_BlockRead(base+0x359b,abrams_trace_snapshot,4);
                MEM_BlockRead(base+0x35a8,abrams_trace_snapshot+4,2);
                MEM_BlockRead(stack+4,abrams_trace_snapshot+6,2);
                MEM_BlockRead(stack+2,abrams_trace_snapshot+8,2);
                MEM_BlockRead(base+0x6486,abrams_trace_snapshot+10,40);
                abrams_trace_callback(34,regs,abrams_trace_snapshot,0,50);
            } else {
                abrams_trace_snapshot[0]=Bit8u(ip);abrams_trace_snapshot[1]=Bit8u(ip>>8);
                MEM_BlockRead(stack,abrams_trace_snapshot+2,8);
                abrams_trace_snapshot[10]=mem_readb(base+0x359e);
                abrams_trace_snapshot[11]=mem_readb(base+0x359b);
                MEM_BlockRead(base+0x35a8,abrams_trace_snapshot+12,2);
                abrams_trace_callback(36,regs,abrams_trace_snapshot,0,14);
            }
        }
        return;
    }
    if (segment == abrams_trace_load && (ip == 0x5ba1 || ip == 0x5c50 || ip == 0x5da3)) {
        abrams_driver_active = false;
        if (ip != 0x5da3 && reg_bp >= 2 && SegPhys(ss) + reg_bp < 640 * 1024) {
            // Lower struts are fixed to the hull; the roof then adopts its
            // original turret-relative centre before its first drawing call.
            int offset = ip == 0x5ba1 ? 0 : (Bit16s)mem_readw(SegPhys(ss) + reg_bp - 2) - 160;
            unsigned page = (mem_readw(base + 0x35a8) - 0xa000u) * 16u;
            if (offset >= -16384 && offset < 16384 && (page == 0 || page == 8192)) {
                abrams_driver_page = page;
                abrams_driver_tag = (Bit32u(offset + 16384) << 17) | (8u << 13);
                abrams_driver_active = true;
            }
        }
        return;
    }
    if (segment == abrams_trace_load && (ip == 0x3d0c || ip == 0x3d6a || ip == 0x3d8e ||
        ip == 0x3db0 || ip == 0x3dd2 || ip == 0x3c90 || ip == 0x3cd4 || ip == 0x3f73)) {
        // Completed crew assignment, queued radio assignment, or the original
        // radio-open store. Observation never implies that the words are visible.
        const Bit16u regs[12] = {reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di,
            reg_bp, reg_sp, SegValue(cs), SegValue(ds), SegValue(es), SegValue(ss)};
        MEM_BlockRead(0, abrams_trace_snapshot, sizeof(abrams_trace_snapshot));
        abrams_trace_callback(28, regs, abrams_trace_snapshot, ip, sizeof(abrams_trace_snapshot));
        return;
    }
    if (segment == abrams_trace_load + 0x0f8d && (ip == 0x020a || ip == 0x0259)) {
        const Bit16u regs[12] = {reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di,
            reg_bp, reg_sp, SegValue(cs), SegValue(ds), SegValue(es), SegValue(ss)};
        if (ip == 0x020a) {
            Bit32u stack = SegPhys(ss) + reg_sp;
            if (stack + 10 > 640 * 1024 || mem_readw(stack + 2) != abrams_trace_load) return;
            Bit32u caller = mem_readw(stack);
            if (!AbramsKnownTextCaller(Bit16u(caller))) return;
            MEM_BlockRead(0, abrams_trace_snapshot, sizeof(abrams_trace_snapshot));
            abrams_trace_callback(26, regs, abrams_trace_snapshot, 0, sizeof(abrams_trace_snapshot));
            Bit32u pointer = mem_readw(stack + 4), n = 0;
            for (; n < 320 && pointer + n < 65536 && mem_readb(base + pointer + n); ++n) {}
            Bit32u x = mem_readw(stack + 6), y = mem_readw(stack + 8);
            Bit32u cell = mem_readb(base + 0x364e), height = mem_readb(base + 0x3662);
            Bit32u page = mem_readw(base + 0x35a8), width = n * cell;
            if (abrams_text_active || !n || n == 320 || pointer + n >= 65536 ||
                !cell || cell > 16 || !height || height > 32 || x + width > 320 || y + height > 200 ||
                (page != 0xa000 && page != 0xa200) || vga.mode != M_EGA) {
                abrams_trace_callback(27, regs, NULL, 0, 0);
                abrams_text_active = false;
                return;
            }
            abrams_text_rect[0] = Bit16u(x); abrams_text_rect[1] = Bit16u(y);
            abrams_text_rect[2] = Bit16u(width); abrams_text_rect[3] = Bit16u(height);
            abrams_text_rect[4] = Bit16u((page - 0xa000u) * 16u); abrams_text_rect[5] = Bit16u(caller);
            abrams_text_active = true;
        } else if (abrams_text_active) {
            // Inspect host plane storage directly. Guest mem_readb(A000:...) would
            // change VGA latches; this observation must leave them untouched.
            unsigned x = abrams_text_rect[0], y = abrams_text_rect[1];
            unsigned width = abrams_text_rect[2], height = abrams_text_rect[3], page = abrams_text_rect[4];
            for (unsigned i = 0; i < 6; ++i) {
                abrams_trace_snapshot[2*i] = Bit8u(abrams_text_rect[i]);
                abrams_trace_snapshot[2*i+1] = Bit8u(abrams_text_rect[i] >> 8);
            }
            for (unsigned dy = 0; dy < height; ++dy) for (unsigned dx = 0; dx < width; ++dx) {
                unsigned at = page + (y + dy) * 40 + (x + dx) / 8, color = 0;
                for (unsigned p = 0; p < 4; ++p)
                    if (vga.mem.linear[at*4+p] & (128u >> ((x + dx) & 7))) color |= 1u << p;
                abrams_trace_snapshot[12 + dy*width + dx] = Bit8u(color);
            }
            abrams_trace_callback(27, regs, abrams_trace_snapshot, 0, 12 + width*height);
            abrams_text_active = false;
        }
        return;
    }
    if (segment == abrams_trace_load &&
        (ip == 0x9107 || ip == 0x8da3 || ip == 0x35ee || ip == 0x91d6)) {
        // Actual original sound requests, gate changes and reload completion.
        // Six LE words. Read the near-call stack before the original prologue;
        // no callback can supply a return value or change guest execution.
        const Bit16u regs[12] = {reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di,
            reg_bp, reg_sp, SegValue(cs), SegValue(ds), SegValue(es), SegValue(ss)};
        Bit32u stack = SegPhys(ss) + reg_sp;
        Bit32u sound = 16u * (abrams_trace_load + 0x18b5) + 0x0f48;
        if (stack + 4 > 640 * 1024 || sound >= 640 * 1024) {
            abrams_trace_callback(25, regs, NULL, 0, 0); return;
        }
        Bit16u values[6] = {Bit16u(ip), mem_readw(stack),
            Bit16u(ip == 0x35ee ? 0 : mem_readw(stack + 2)),
            mem_readb(base + 0x35ac), mem_readb(sound), mem_readb(base + 0x79aa)};
        Bit8u bytes[12];
        for (unsigned i = 0; i < 6; ++i) { bytes[i*2] = Bit8u(values[i]); bytes[i*2+1] = Bit8u(values[i] >> 8); }
        abrams_trace_callback(25, regs, bytes, 0, 12);
        return;
    }
    if (segment == abrams_trace_load + 0x0f8d && ip == 0x1a7c) {
        Bit32u stack = SegPhys(ss) + reg_sp;
        Bit32u source = mem_readw(base + 0x35a2), dest = mem_readw(base + 0x35a4);
        if (abrams_plate_copy_active || stack + 4 > 640 * 1024 ||
            (source != 0xa000 && source != 0xa200) || (dest != 0xa000 && dest != 0xa200) || source == dest ||
            mem_readw(base + 0x3604) + 16u * mem_readw(base + 0x3606) !=
                16u * (abrams_trace_load + 0x1388) + 0x1ff3) {
            abrams_plates.valid = false;
        } else {
            abrams_plate_copy_source = (source - 0xa000u) * 16u;
            abrams_plate_copy_dest = (dest - 0xa000u) * 16u;
            abrams_plate_copy_return_ip = mem_readw(stack);
            abrams_plate_copy_return_cs = mem_readw(stack + 2);
            abrams_plate_copy_active = true;
        }
        return;
    }
    if (segment == abrams_trace_load + 0x0f8d &&
        (ip == 0x1170 || ip == 0x123a || ip == 0x1226 || ip == 0x1238)) {
        const Bit16u regs[12] = {reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di,
            reg_bp, reg_sp, SegValue(cs), SegValue(ds), SegValue(es), SegValue(ss)};
        Bit32u stack = SegPhys(ss) + reg_sp;
        if (stack + 14 > 640 * 1024) {
            abrams_trace_callback(23, regs, NULL, 1, 0); return;
        }
        if (ip == 0x1170) {
            // Filename argument before the original prologue. Never host I/O.
            Bit32u name = mem_readw(stack + 4), n = 0;
            for (; n < 13 && name + n < 65536; ++n) {
                abrams_trace_snapshot[n] = mem_readb(base + name + n);
                if (!abrams_trace_snapshot[n]) break;
            }
            if (n == 13 || name + n >= 65536) {
                abrams_trace_callback(23, regs, NULL, 2, 0); return;
            }
            abrams_trace_callback(20, regs, abrams_trace_snapshot, name, n + 1);
            // IDs are presentation metadata only, independently byte-verified
            // by the host before it accepts the frame. Never open these paths.
            const char* names[] = {"GPS.BIN", "TC.BIN", "AA.BIN", "DRIVER.BIN", "STATUS.BIN", "IDENTIFY", "FRAME", "ATBASE.BIN"};
            char upper[13];
            for (unsigned i = 0; i <= n; ++i) {
                unsigned c = abrams_trace_snapshot[i];
                upper[i] = char(c >= 'a' && c <= 'z' ? c - 'a' + 'A' : c);
            }
            abrams_plate_id = 0;
            for (unsigned i = 0; i < 8; ++i) if (!strcmp(upper, names[i])) abrams_plate_id = i == 7 ? 9 : i + 1;
        } else if (ip == 0x123a) {
            // A frame-boundary attachment can enter during ATBASE's first
            // strip. Recover its live filename only through the pinned
            // loader call site and intact caller frame; no heuristic scan.
            if (!abrams_plate_id && mem_readw(stack) == 0x11e6 &&
                mem_readw(stack+2) == segment && SegPhys(ss)+reg_bp+8 < 640*1024) {
                unsigned name = mem_readw(SegPhys(ss)+reg_bp+6);
                const char* expected = "ATBASE.BIN";
                bool equal = name+11 <= 65536;
                for (unsigned i=0; equal && i<11; ++i) {
                    unsigned c=mem_readb(base+name+i);
                    if (c>='a' && c<='z') c-=32;
                    if (c != (unsigned char)expected[i]) equal=false;
                }
                if (equal) abrams_plate_id=9;
            }
            // Original buffer, count, x/y and page at the packed-driver dispatch.
            // Wire header: six little-endian words, then exactly count bytes.
            Bit32u count = mem_readw(stack + 8);
            Bit32u source = mem_readw(stack + 4) + 16u * mem_readw(stack + 6);
            if (!count || count > 32000 || source + count > 640 * 1024 ||
                mem_readw(base + 0x35f0) + 16u * mem_readw(base + 0x35f2) !=
                    16u * (abrams_trace_load + 0x1388) + 0x2217) {
                abrams_trace_callback(23, regs, NULL, 3, 0); return;
            }
            MEM_BlockRead(stack + 4, abrams_trace_snapshot, 10);
            Bit16u page = mem_readw(base + 0x35a8);
            abrams_trace_snapshot[10] = Bit8u(page);
            abrams_trace_snapshot[11] = Bit8u(page >> 8);
            MEM_BlockRead(source, abrams_trace_snapshot + 12, count);
            abrams_trace_callback(21, regs, abrams_trace_snapshot, 0, count + 12);
            Bit32u x = mem_readw(stack + 10), y = mem_readw(stack + 12);
            if (abrams_plate_active || x != 0 || count % 160 || y * 160 + count > 32000 ||
                (page != 0xa000 && page != 0xa200)) {
                abrams_plates.valid = false;
            } else {
                abrams_plate_page = (page - 0xa000u) * 16u;
                abrams_plate_begin = abrams_plate_page + y * 40;
                abrams_plate_end = abrams_plate_begin + count / 4;
                abrams_plate_return_ip = mem_readw(stack);
                abrams_plate_return_cs = mem_readw(stack + 2);
                abrams_plate_active = true;
            }
        } else {
            if (ip == 0x1226 && reg_ax == 1 && abrams_plate_id == 9 &&
                (abrams_plate_page == 0 || abrams_plate_page == 8192)) {
                // Success before RETF, hence before the caller draws menus.
                // Direct backing-plane reads preserve every guest VGA latch.
                for (unsigned at=0; at<64000; ++at) {
                    unsigned address=abrams_plate_page+at/8, colour=0;
                    for (unsigned p=0; p<4; ++p)
                        if (vga.mem.linear[address*4+p] & (128u>>(at&7))) colour|=1u<<p;
                    abrams_trace_snapshot[at]=Bit8u(colour);
                }
                abrams_motor_pool_claiming=true;
                abrams_trace_callback(32,regs,abrams_trace_snapshot,abrams_plate_page,64000);
                abrams_motor_pool_claiming=false;
            }
            abrams_trace_callback(22, regs, NULL, 0, 0);
            abrams_plate_id = 0;
        }
        return;
    }
    if (segment == abrams_trace_load + 0x0f8d && ip == 0x0347) {
        Bit32u stack = SegPhys(ss) + reg_sp;
        if (abrams_bitmap_active || stack + 10 > 640 * 1024 ||
            mem_readw(base + 0x35bc) + 16u * mem_readw(base + 0x35be) !=
                16u * (abrams_trace_load + 0x0f8d) + 0x4512) {
            abrams_ownership.valid = false;
            return;
        }
        Bit32u descriptor = base + mem_readw(stack + 4);
        if (descriptor + 8 > 640 * 1024) { abrams_ownership.valid = false; return; }
        Bit32u width = mem_readb(descriptor + 6), height = mem_readb(descriptor + 7);
        Bit32u mask = mem_readw(descriptor) * 16u + mem_readw(descriptor + 4);
        Bit32u bytes = (width / 8) * height;
        Bit32u page = (mem_readw(base + 0x35a8) - 0xa000u) * 16u;
        Bit8u bits[6200];
        if (bytes > sizeof(bits) || mask + bytes > 640 * 1024) { abrams_ownership.valid = false; return; }
        MEM_BlockRead(mask, bits, bytes);
        bool clipped = mem_readb(base + 0x359b) != 0;
        if (!abrams_bitmap.prepare(bits, width, height, (Bit16s)mem_readw(stack + 6), (Bit16s)mem_readw(stack + 8),
            clipped ? mem_readw(base + 0x3593) : 0, clipped ? mem_readw(base + 0x3597) : 0,
            clipped ? mem_readw(base + 0x3595) : 319, clipped ? mem_readw(base + 0x3599) : 199, page)) {
            abrams_ownership.valid = false;
            return;
        }
        abrams_bitmap_return_ip = mem_readw(stack);
        abrams_bitmap_return_cs = mem_readw(stack + 2);
        abrams_bitmap_active = true;
        abrams_strut_active = false;
        unsigned table = mem_readw(base + 0x798e);
        if (!abrams_driver_active && table && table + 14 <= 65536) for (unsigned index = 0; index < 7; ++index) {
            if (base + mem_readw(base + table + index*2) != descriptor) continue;
            const Bit16u regs[12] = {reg_ax,reg_bx,reg_cx,reg_dx,reg_si,reg_di,reg_bp,reg_sp,
                SegValue(cs),SegValue(ds),SegValue(es),SegValue(ss)};
            abrams_strut_page = page;
            abrams_strut_active = true;
            MEM_BlockRead(0, abrams_trace_snapshot, sizeof(abrams_trace_snapshot));
            abrams_trace_callback(29, regs, abrams_trace_snapshot, index, sizeof(abrams_trace_snapshot));
            break;
        }
        return;
    }
    if (segment == abrams_trace_load) {
        if (ip == 0x8ac4 && mem_readw(base + 0x358c) == 0x012c) {
            event = 1; length = 640 * 1024;
        } else if (ip == 0x02c1) { event = 4; }
        else if (ip == 0x8b49) { event = 17; length = 640 * 1024; }
    } else if (segment == abrams_trace_load + 0x0b4d) {
        if (ip == 0x29ad) { event = 2; start = 0x1100; length = 0x0f00; }
        else if (ip == 0x0596) { event = 3; start = 0x1200; length = 0x2400; }
        else if (ip == 0x2979) { event = 5; start = 0x117d; length = 18; }
        else if (ip == 0x28d0) { event = 7; start = reg_di; length = 2; }
        else if (ip == 0x31a6) { event = 8; start = reg_di; length = 4; }
        else if (ip == 0x340b) { event = 13; start = 0x35a0; length = 10; }
        else if (ip == 0x3707) { event = 15; start = reg_bp + 12; length = 4; }
        else if (ip == 0x36c8) { event = 16; }
        else if (ip == 0x28e4) { event = 18; }
    } else if (segment == abrams_trace_load + 0x0f8d) {
        if (ip == 0x0357) { event = 6; start = 0x1200; length = 0x2400; }
        else if (ip == 0x59e4) { event = 9; start = 0x35a0; length = 10; }
    }
    if (!event) return;
    if (event == 13) abrams_world_drawing = mem_readw(base + 0x358c) == 0x012c;
    else if (event == 4) abrams_world_drawing = false;
    const Bit16u regs[12] = {reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di,
        reg_bp, reg_sp, SegValue(cs), SegValue(ds), SegValue(es), SegValue(ss)};
    if (event == 1) abrams_trace_callback(14, regs, (const Bit8u*)render.pal.rgb, 0, 16 * 4);
    if (length) MEM_BlockRead((event == 1 || event == 17) ? 0 : (event == 15 ? SegPhys(ss) : ((event == 7 || event == 8) ? SegPhys(es) : base)) + start, abrams_trace_snapshot, length);
    abrams_trace_callback(event, regs, abrams_trace_snapshot, start, length);
}

#include "abrams_observer_checkpoint.h"
