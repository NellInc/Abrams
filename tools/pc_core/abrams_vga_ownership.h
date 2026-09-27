/* Read-only provenance companion to original EGA writes, never guest memory.
 * Copyright (C) 2026 Nell Watson and contributors.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#ifndef ABRAMS_VGA_OWNERSHIP_H
#define ABRAMS_VGA_OWNERSHIP_H
#include <stdint.h>
#include <string.h>

struct AbramsVgaOwnership {
    uint32_t owners[65536];
    uint32_t latch;
    bool valid;

    void reset() {
        memset(owners, 255, sizeof(owners));
        latch = 0xffffffffu;
        valid = true;
    }
    void read(uint32_t address) {
        if (address >= 65536) { valid = false; return; }
        latch = owners[address];
    }
    void write(uint32_t address, uint8_t value, unsigned mode, unsigned operation,
               unsigned rotate, uint32_t bit_mask, uint32_t plane_mask,
               uint32_t enable_set_reset, uint32_t set_reset, bool ui) {
        if (address >= 65536 || mode > 3 || operation > 3 || rotate > 7) {
            valid = false;
            return;
        }
        uint32_t result = latch;
        if (mode != 1) {
            uint8_t rotated = uint8_t((value >> rotate) | (unsigned(value) << ((8 - rotate) & 7)));
            uint32_t input = uint32_t(rotated) * 0x01010101u;
            uint32_t mask = bit_mask;
            if (mode == 0) input = (input & ~enable_set_reset) | (set_reset & enable_set_reset);
            else if (mode == 2) {
                input = 0;
                for (unsigned p = 0; p < 4; ++p)
                    if (value & (1u << p)) input |= 0xffu << (p * 8);
            } else {
                mask &= input;
                input = set_reset;
            }
            // AND's zero and OR's one define bits; the other input preserves
            // the latch, including its provenance. XOR also depends on it.
            if (operation == 1) mask &= ~input;
            else if (operation >= 2) mask &= input;
            if (operation == 3) result = latch | (ui ? mask : 0);
            else result = (latch & ~mask) | (ui ? mask : 0);
        }
        owners[address] = (owners[address] & ~plane_mask) | (result & plane_mask);
    }
    uint8_t pixel(uint32_t address) const {
        if (address >= 65536 * 8) return 255;
        uint32_t tag = owners[address >> 3];
        uint8_t any_plane = uint8_t(tag | (tag >> 8) | (tag >> 16) | (tag >> 24));
        return (any_plane & (128u >> (address & 7))) ? 255 : 0;
    }
};

// The original bitmap driver implements transparent ORs in the CPU, outside
// the VGA raster-op register. Retain destination provenance under its explicit
// preservation mask, including edge bytes, rather than mistaking a CPU copy for
// newly authored UI. The mask is sampled at the original blit entry.
struct AbramsBitmapOwnership {
    uint8_t preserve[65536];
    bool prepare(const uint8_t* mask, unsigned width, unsigned height,
                 int x, int y, int left, int top, int right, int bottom,
                 unsigned page) {
        if (!width || width > 248 || width % 8 || !height || height > 200 ||
            page > 65536 - 8000 || left < 0 || top < 0 || right >= 320 ||
            bottom >= 200 || left > right || top > bottom) return false;
        memset(preserve, 255, sizeof(preserve));
        for (unsigned sy = 0; sy < height; ++sy) {
            int dy = y + int(sy);
            if (dy < top || dy > bottom) continue;
            for (unsigned sx = 0; sx < width; ++sx) {
                int dx = x + int(sx);
                if (dx < left || dx > right) continue;
                if (!(mask[sy * (width / 8) + sx / 8] & (128u >> (sx & 7))))
                    preserve[page + dy * 40 + dx / 8] &= uint8_t(~(128u >> (dx & 7)));
            }
        }
        return true;
    }
    uint32_t retain(uint32_t address, uint32_t before, uint32_t after) const {
        if (address >= 65536) return before;
        uint32_t keep = uint32_t(preserve[address]) * 0x01010101u;
        return (before & keep) | (after & ~keep);
    }
};
#endif
