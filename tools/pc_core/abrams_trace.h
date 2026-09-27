/* Local, read-only Abrams renderer observation for DOSBox Pure.
 * Copyright (C) 2026 Nell Watson and contributors.
 * SPDX-License-Identifier: GPL-2.0-or-later
 * Included only by core_normal.cpp. No guest writes, cycle changes or skipped
 * instructions. Configure and consume only while the emulation worker is fenced.
 */
typedef void (*AbramsTraceCallback)(Bit32u, const Bit16u*, const Bit8u*, Bit32u, Bit32u);
static AbramsTraceCallback abrams_trace_callback = NULL;
static Bit16u abrams_trace_load = 0;
static Bit8u abrams_trace_snapshot[640 * 1024];

extern "C" __attribute__((visibility("default")))
void abrams_trace_configure(Bit16u load, AbramsTraceCallback callback) {
    abrams_trace_load = load;
    abrams_trace_callback = callback;
}

static INLINE void AbramsTraceInstruction() {
    if (!abrams_trace_callback || !abrams_trace_load) return;
    Bit32u ip = reg_eip;
    // Cheap filter before consulting segments on the normal instruction path.
    if (ip != 0x8ac4 && ip != 0x02c1 && ip != 0x29ad && ip != 0x0596 && ip != 0x2979 && ip != 0x0357) return;
    if (SegValue(ds) != abrams_trace_load + 0x19e0) return;
    Bit32u segment = SegValue(cs), event = 0, start = 0, length = 0;
    const Bit32u base = SegPhys(ds);
    if (base + 65536 > 640 * 1024) return;
    if (segment == abrams_trace_load) {
        if (ip == 0x8ac4 && mem_readw(base + 0x358c) == 0x012c) {
            event = 1; length = 640 * 1024;
        } else if (ip == 0x02c1) { event = 4; }
    } else if (segment == abrams_trace_load + 0x0b4d) {
        if (ip == 0x29ad) { event = 2; start = 0x1100; length = 0x0f00; }
        else if (ip == 0x0596) { event = 3; start = 0x1200; length = 0x2400; }
        else if (ip == 0x2979) { event = 5; start = 0x117d; length = 18; }
    } else if (segment == abrams_trace_load + 0x0f8d && ip == 0x0357) {
        event = 6; start = 0x1200; length = 0x2400;
    }
    if (!event) return;
    const Bit16u regs[12] = {reg_ax, reg_bx, reg_cx, reg_dx, reg_si, reg_di,
        reg_bp, reg_sp, SegValue(cs), SegValue(ds), SegValue(es), SegValue(ss)};
    if (length) MEM_BlockRead(event == 1 ? 0 : base + start, abrams_trace_snapshot, length);
    abrams_trace_callback(event, regs, abrams_trace_snapshot, start, length);
}
