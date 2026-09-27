/* Conservative static-plate provenance, host memory only.
 * Copyright (C) 2026 Nell Watson and contributors.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#ifndef ABRAMS_PLATE_OWNERSHIP_H
#define ABRAMS_PLATE_OWNERSHIP_H
#include <stdint.h>
#include <string.h>

struct AbramsPlateOwnership {
    // One common source byte per planar byte. Mixed origins are discarded
    // conservatively rather than attributed to whichever plate was newest.
    uint16_t origin[65536];
    uint32_t bits[65536];
    uint16_t latch_origin;
    uint32_t latch_bits;
    bool valid;

    void reset() {
        memset(origin, 0, sizeof(origin));
        memset(bits, 0, sizeof(bits));
        latch_origin = 0;
        latch_bits = 0;
        valid = true;
    }
    void read(uint32_t address) {
        if (address >= 65536) { valid = false; return; }
        latch_origin = origin[address];
        latch_bits = bits[address];
    }
    static void merge(uint16_t& tag, uint32_t& selected, uint16_t other, uint32_t mask) {
        if (!other || !mask) return;
        if (selected && tag != other) { tag = 0; selected = 0; return; }
        tag = other;
        selected |= mask;
    }
    void write(uint32_t address, uint8_t value, unsigned mode, unsigned operation,
               unsigned rotate, uint32_t bit_mask, uint32_t plane_mask,
               uint32_t enable_set_reset, uint32_t set_reset, uint16_t authored,
               uint32_t authored_bits = 0xffffffffu) {
        if (address >= 65536 || mode > 3 || operation > 3 || rotate > 7) { valid = false; return; }
        uint32_t preserve = 0xffffffffu, assign = 0;
        if (mode != 1) {
            uint8_t rotated = uint8_t((value >> rotate) | (unsigned(value) << ((8 - rotate) & 7)));
            uint32_t input = uint32_t(rotated) * 0x01010101u;
            uint32_t mask = bit_mask;
            if (mode == 0) input = (input & ~enable_set_reset) | (set_reset & enable_set_reset);
            else if (mode == 2) {
                input = 0;
                for (unsigned p = 0; p < 4; ++p) if (value & (1u << p)) input |= 0xffu << (p * 8);
            } else { mask &= input; input = set_reset; }
            if (operation == 1) mask &= ~input;
            else if (operation >= 2) mask &= input;
            preserve = ~mask;
            // A toggled bit no longer equals its original source plate colour.
            // New direct writes (including identical/black UI) discard tags.
            assign = operation == 3 ? 0 : mask;
        }
        uint16_t tag = 0;
        uint32_t selected = 0;
        merge(tag, selected, origin[address], bits[address] & ~plane_mask);
        merge(tag, selected, latch_origin, latch_bits & preserve & plane_mask);
        merge(tag, selected, authored, assign & plane_mask & authored_bits);
        origin[address] = tag;
        bits[address] = selected;
    }
    void retain(uint32_t address, uint16_t before_origin, uint32_t before_bits, uint8_t preserve) {
        if (address >= 65536) { valid = false; return; }
        uint32_t keep = uint32_t(preserve) * 0x01010101u, selected = 0;
        uint16_t tag = 0;
        merge(tag, selected, origin[address], bits[address] & ~keep);
        merge(tag, selected, before_origin, before_bits & keep);
        origin[address] = tag;
        bits[address] = selected;
    }
    uint8_t pixel(uint32_t address) const {
        if (!valid || address >= 65536 * 8) return 0;
        uint32_t at = address >> 3, mask = 0x80808080u >> (address & 7);
        uint16_t tag = origin[at];
        // Copies at a different x/y are retained internally but never mapped
        // to artwork at the wrong coordinate. 8192-byte original EGA pages.
        if ((bits[at] & mask) != mask || (tag & 8191u) != (at & 8191u) || (tag & 8191u) >= 8000) return 0;
        return uint8_t(tag >> 13);
    }
};
#endif
