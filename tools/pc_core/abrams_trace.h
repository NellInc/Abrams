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
static AbramsPlateOwnership abrams_plates;
static Bit8u abrams_plate_mask[320 * 200];
static unsigned abrams_plate_id = 0;
static bool abrams_plate_active = false;
static Bit16u abrams_plate_return_ip, abrams_plate_return_cs;
static Bit32u abrams_plate_begin, abrams_plate_end, abrams_plate_page;
static bool abrams_plate_copy_active = false;
static Bit16u abrams_plate_copy_return_ip, abrams_plate_copy_return_cs;
static Bit32u abrams_plate_copy_source, abrams_plate_copy_dest;

extern "C" __attribute__((visibility("default")))
void abrams_trace_configure(Bit16u load, AbramsTraceCallback callback) {
    abrams_trace_load = load;
    abrams_trace_callback = callback;
    abrams_world_drawing = false;
    abrams_bitmap_active = false;
    abrams_plate_active = false;
    abrams_plate_id = 0;
    abrams_plate_copy_active = false;
    abrams_ownership.reset();
    abrams_plates.reset();
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
    Bit16u plate_before = address < 65536 ? abrams_plates.origin[address] : 0;
    Bit32u plate_bits_before = address < 65536 ? abrams_plates.bits[address] : 0;
    Bit16u authored = 0;
    Bit32u authored_bits = 0xffffffffu;
    if (abrams_plate_active && abrams_plate_id && SegValue(cs) == abrams_trace_load + 0x1388) {
        if (address < abrams_plate_begin || address >= abrams_plate_end ||
            vga.config.write_mode != 0 || vga.config.raster_op != 0 || vga.config.data_rotate != 0 ||
            vga.config.full_bit_mask != 0xffffffffu || vga.config.full_not_enable_set_reset != 0xffffffffu) {
            abrams_plates.valid = false;
        } else authored = Bit16u((abrams_plate_id << 13) | (address - abrams_plate_page));
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
        abrams_plate_mask[row * 320 + x] = abrams_plates.pixel((address + x) & wrap_mask);
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
    abrams_trace_callback(24, regs, plates_complete ? abrams_plate_mask : NULL, slot,
        plates_complete ? sizeof(abrams_plate_mask) : 0);
    abrams_trace_callback(11, regs, NULL, slot, 0);
}
extern "C" void AbramsTraceVideoPresent(Bit32u slot, const Bit8u* pixels, Bit32u width, Bit32u height) {
    if (!abrams_trace_callback) return;
    const Bit16u regs[12] = {(Bit16u)width, (Bit16u)height};
    abrams_trace_callback(12, regs, pixels, slot, width * height * 4);
}

static INLINE void AbramsTraceInstruction() {
    if (!abrams_trace_callback || !abrams_trace_load) return;
    Bit32u ip = reg_eip;
    if (abrams_bitmap_active && ip == abrams_bitmap_return_ip && SegValue(cs) == abrams_bitmap_return_cs)
        abrams_bitmap_active = false;
    if (abrams_plate_active && ip == abrams_plate_return_ip && SegValue(cs) == abrams_plate_return_cs)
        abrams_plate_active = false;
    if (abrams_plate_copy_active && ip == abrams_plate_copy_return_ip && SegValue(cs) == abrams_plate_copy_return_cs)
        abrams_plate_copy_active = false;
    // Cheap filter before consulting segments on the normal instruction path.
    if (ip != 0x8ac4 && ip != 0x02c1 && ip != 0x29ad && ip != 0x0596 && ip != 0x2979 && ip != 0x0357
        && ip != 0x28d0 && ip != 0x31a6 && ip != 0x59e4 && ip != 0x340b
        && ip != 0x3707 && ip != 0x36c8 && ip != 0x8b49 && ip != 0x28e4 && ip != 0x0347
        && ip != 0x1170 && ip != 0x123a && ip != 0x1226 && ip != 0x1238 && ip != 0x1a7c) return;
    if (SegValue(ds) != abrams_trace_load + 0x19e0) return;
    Bit32u segment = SegValue(cs), event = 0, start = 0, length = 0;
    const Bit32u base = SegPhys(ds);
    if (base + 65536 > 640 * 1024) return;
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
            const char* names[] = {"GPS.BIN", "TC.BIN", "AA.BIN", "DRIVER.BIN", "STATUS.BIN", "IDENTIFY", "FRAME"};
            char upper[13];
            for (unsigned i = 0; i <= n; ++i) {
                unsigned c = abrams_trace_snapshot[i];
                upper[i] = char(c >= 'a' && c <= 'z' ? c - 'a' + 'A' : c);
            }
            abrams_plate_id = 0;
            for (unsigned i = 0; i < 7; ++i) if (!strcmp(upper, names[i])) abrams_plate_id = i + 1;
        } else if (ip == 0x123a) {
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
