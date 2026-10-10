// Synchronous provenance claims for the threaded DOSBox Pure Web build.
// The main JS worker blocks while the original CPU pthread runs, so a Python
// or JS round-trip inside the callback can deadlock. Source pixels come from
// the visitor's verified original files; no catalog is compiled into the site.
#pragma once
#include <array>
#include <cstdint>
#include <cstring>
#include <utility>
#include <vector>

extern "C" bool abrams_trace_claim_strut(unsigned, unsigned, const uint8_t*, unsigned);
extern "C" bool abrams_trace_claim_motor_pool(unsigned);

class AbramsWebClaims {
    struct Bitmap { unsigned width, height; std::vector<uint8_t> pixels; };
    std::array<std::vector<uint8_t>, 5> plates;
    std::vector<Bitmap> struts;
    std::vector<std::pair<unsigned, uint8_t>> expected;
    std::array<uint8_t, 8000> mask = {};
    unsigned pending_page = 0, pending_plate = 0;
    bool pending = false;
    bool loaded = false;

    static unsigned word(const uint8_t* bytes, size_t at) {
        return unsigned(bytes[at]) | (unsigned(bytes[at + 1]) << 8);
    }
    static int signed_word(const uint8_t* bytes, size_t at) {
        return int(int16_t(word(bytes, at)));
    }
    static void append_word(std::vector<uint8_t>& target, unsigned value) {
        for (int i = 0; i < 4; ++i) target.push_back(uint8_t(value >> (8 * i)));
    }
    bool begin(const uint16_t* regs, const uint8_t* ram, unsigned index) {
        if (pending || !ram || index >= struts.size()) return false;
        const unsigned ds_seg = regs[9], cs_seg = regs[8];
        if (ds_seg < 0x19e0) return false;
        const unsigned load = ds_seg - 0x19e0, ds = ds_seg * 16;
        const unsigned stack = unsigned(regs[11]) * 16 + regs[7];
        if (load == 0 || cs_seg != load + 0xf8d || ds + 65536 > 640 * 1024 ||
            stack + 10 > 640 * 1024) return false;
        const unsigned descriptor = word(ram, stack + 4);
        const int x = signed_word(ram, stack + 6), y = signed_word(ram, stack + 8);
        const unsigned table = word(ram, ds + 0x798e);
        if (!table || table + 2 * struts.size() > 65536 ||
            word(ram, ds + table + index * 2) != descriptor) return false;
        const unsigned at = ds + descriptor;
        if (at + 10 > 640 * 1024) return false;
        const unsigned segment = word(ram, at), offset = word(ram, at + 2),
            mask_offset = word(ram, at + 4), width = ram[at + 6], height = ram[at + 7];
        const Bitmap& source = struts[index];
        if (!width || width % 8 || width != source.width || height != source.height) return false;
        const unsigned plane_size = width / 8 * height;
        const unsigned start = segment * 16 + offset, mask_start = segment * 16 + mask_offset;
        if (mask_start != start + plane_size * 4 || mask_start + plane_size > 640 * 1024)
            return false;
        for (unsigned pixel = 0; pixel < width * height; ++pixel) {
            const unsigned byte = pixel / 8, bit = 128u >> (pixel & 7);
            unsigned colour = 0;
            for (unsigned plane = 0; plane < 4; ++plane)
                if (ram[start + plane * plane_size + byte] & bit) colour |= 1u << plane;
            if (colour != source.pixels[pixel] ||
                bool(!(ram[mask_start + byte] & bit)) != bool(source.pixels[pixel])) return false;
        }
        const unsigned page_word = word(ram, ds + 0x35a8);
        const unsigned page = page_word == 0xa000 ? 0 : page_word == 0xa200 ? 8192 : 65536;
        const bool clipped_cupola = index == 5 && width == 168 && height == 7 &&
            x == 159 && y == 110 && word(ram, stack) == 0x0d92 &&
            word(ram, stack + 2) == load;
        if (((x < 0 || y < 0 || x + int(width) > 320 || y + int(height) > 200) &&
             !clipped_cupola) || page == 65536 || ram[ds + 0x359f] != 15) return true;

        std::vector<std::pair<unsigned, uint8_t>> occupied;
        for (unsigned sy = 0; sy < height; ++sy) for (unsigned sx = 0; sx < width; ++sx) {
            const uint8_t colour = source.pixels[sy * width + sx];
            const int px = x + int(sx), py = y + int(sy);
            if (colour && px >= 0 && px < 320 && py >= 0 && py < 200)
                occupied.emplace_back(unsigned(py * 320 + px), colour);
        }
        unsigned candidate = 0, count = 0;
        if (!occupied.empty()) for (unsigned plate = 0; plate < 4; ++plate) {
            bool match = true;
            for (const auto& pixel : occupied)
                if (plates[plate][pixel.first] != pixel.second) { match = false; break; }
            if (match) { candidate = plate + 1; ++count; }
        }
        if (count != 1) return true;
        int left = 0, right = 319, top = 0, bottom = 199;
        if (ram[ds + 0x359b]) {
            left = signed_word(ram, ds + 0x3593);
            right = signed_word(ram, ds + 0x3595);
            top = signed_word(ram, ds + 0x3597);
            bottom = signed_word(ram, ds + 0x3599);
        }
        if (left < 0 || right >= 320 || top < 0 || bottom >= 200 ||
            left > right || top > bottom) return false;
        expected.clear();
        mask.fill(0);
        for (const auto& pixel : occupied) {
            const unsigned px = pixel.first % 320, py = pixel.first / 320;
            if (int(px) < left || int(px) > right || int(py) < top || int(py) > bottom) continue;
            expected.push_back(pixel);
            mask[pixel.first / 8] |= uint8_t(128u >> (pixel.first & 7));
        }
        pending_page = page;
        pending_plate = candidate;
        pending = true;
        return true;
    }
    bool finish(const uint8_t* pixels, unsigned page, unsigned length) {
        if (!pixels || length != 64000 || (page != 0 && page != 8192)) return false;
        if (!pending) return true;
        pending = false;
        if (page != pending_page) return false;
        for (const auto& pixel : expected)
            if (pixels[pixel.first] != pixel.second) return false;
        if (!abrams_trace_claim_strut(page, pending_plate, mask.data(), mask.size())) return false;
        if (receipts.size() + 8008 > 1024 * 1024) return false;
        append_word(receipts, page);
        append_word(receipts, pending_plate);
        receipts.insert(receipts.end(), mask.begin(), mask.end());
        return true;
    }
public:
    std::vector<uint8_t> receipts;
    void reset() { pending = false; expected.clear(); receipts.clear(); }
    bool is_loaded() const { return loaded; }
    bool configure(const uint8_t* bytes, size_t size) {
        loaded = false;
        reset();
        if (!bytes || size < 8 + 5 * 64000 || size > 1024 * 1024 ||
            memcmp(bytes, "ABCL", 4) || word(bytes, 4) != 1) return false;
        const unsigned count = word(bytes, 6);
        if (!count || count > 256) return false;
        size_t at = 8;
        std::array<std::vector<uint8_t>, 5> source_plates;
        for (auto& plate : source_plates) {
            plate.assign(bytes + at, bytes + at + 64000);
            for (uint8_t colour : plate) if (colour > 15) return false;
            at += 64000;
        }
        std::vector<Bitmap> source_struts;
        for (unsigned index = 0; index < count; ++index) {
            if (at + 4 > size) return false;
            Bitmap bitmap;
            bitmap.width = word(bytes, at);
            bitmap.height = word(bytes, at + 2);
            at += 4;
            const size_t area = size_t(bitmap.width) * bitmap.height;
            if (!bitmap.width || bitmap.width > 320 || bitmap.width % 2 ||
                !bitmap.height || bitmap.height > 200 || area > size - at) return false;
            bitmap.pixels.assign(bytes + at, bytes + at + area);
            for (uint8_t colour : bitmap.pixels) if (colour > 15) return false;
            source_struts.push_back(std::move(bitmap));
            at += area;
        }
        if (at != size) return false;
        plates = std::move(source_plates);
        struts = std::move(source_struts);
        loaded = true;
        reset();
        return true;
    }
    bool observe(unsigned event, const uint16_t* regs, const uint8_t* data,
                 unsigned offset, unsigned length) {
        if (!loaded) return true;
        if (event == 29) return length == 640 * 1024 && begin(regs, data, offset);
        if (event == 30) return finish(data, offset, length);
        if (event == 32) {
            if (!data || length != 64000 || (offset != 0 && offset != 8192)) return false;
            if (memcmp(data, plates[4].data(), 64000)) return true;
            if (!abrams_trace_claim_motor_pool(offset) || receipts.size() + 8 > 1024 * 1024)
                return false;
            append_word(receipts, offset);
            append_word(receipts, 0);
        }
        return true;
    }
};
