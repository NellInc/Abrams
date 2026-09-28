/* Host-only EGA provenance checkpoint. Never serializes pointers or writes guest
 * state. Invoke only at the host's paused native frame fence, after attachment.
 * Copyright (C) 2026 Nell Watson and contributors.
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#ifndef ABRAMS_OBSERVER_CHECKPOINT_H
#define ABRAMS_OBSERVER_CHECKPOINT_H
#include <stddef.h>

// Explicit fields avoid structure padding and callback/function pointers. All
// ownership latches and in-flight bitmap contexts must follow the guest state.
#define ABRAMS_OBSERVER_FIELDS(F) \
    F(abrams_ownership.owners) F(abrams_ownership.latch) F(abrams_ownership.valid) \
    F(abrams_plates.origin) F(abrams_plates.bits) F(abrams_plates.latch_origin) \
    F(abrams_plates.latch_bits) F(abrams_plates.valid) \
    F(abrams_world_drawing) F(abrams_bitmap.preserve) F(abrams_bitmap_active) \
    F(abrams_bitmap_return_ip) F(abrams_bitmap_return_cs) \
    F(abrams_strut_active) F(abrams_strut_page) \
    F(abrams_driver_active) F(abrams_driver_page) F(abrams_driver_tag) \
    F(abrams_plate_id) F(abrams_plate_active) F(abrams_plate_return_ip) \
    F(abrams_plate_return_cs) F(abrams_plate_begin) F(abrams_plate_end) \
    F(abrams_plate_page) F(abrams_plate_copy_active) F(abrams_plate_copy_return_ip) \
    F(abrams_plate_copy_return_cs) F(abrams_plate_copy_source) F(abrams_plate_copy_dest)

static size_t AbramsObserverPayloadSize() {
    size_t size = 0;
#define ABRAMS_SIZE(field) size += sizeof(field);
    ABRAMS_OBSERVER_FIELDS(ABRAMS_SIZE)
#undef ABRAMS_SIZE
    return size;
}
// A complete readback of observed planar storage binds provenance to exactly
// the restored EGA bytes, including nondisplayed pages and the native latch.
static const size_t abrams_observer_vga_bytes = 65536 * 4;
static const size_t abrams_observer_header_bytes = 24;
extern "C" __attribute__((visibility("default")))
unsigned abrams_observer_checkpoint_abi() { return 1; }
extern "C" __attribute__((visibility("default")))
size_t abrams_observer_checkpoint_size() {
    return abrams_observer_header_bytes + abrams_observer_vga_bytes + AbramsObserverPayloadSize();
}

template <typename T> static bool AbramsObserverFieldValid(const Bit8u*, const T&) { return true; }
static bool AbramsObserverFieldValid(const Bit8u* raw, const bool&) { return *raw <= 1; }
static bool AbramsObserverFieldValid(const Bit8u* raw, const Bit32u& field) {
    Bit32u value; memcpy(&value, raw, sizeof(value));
    if (&field == &abrams_strut_page || &field == &abrams_driver_page ||
        &field == &abrams_plate_page || &field == &abrams_plate_copy_source ||
        &field == &abrams_plate_copy_dest) return value == 0 || value == 8192;
    if (&field == &abrams_plate_begin || &field == &abrams_plate_end) return value <= 65536;
    if (&field == &abrams_plate_id) return value <= 9;
    return true;
}

extern "C" __attribute__((visibility("default")))
bool abrams_observer_checkpoint_save(void* output, size_t size) {
    if (!output || size != abrams_observer_checkpoint_size() || !abrams_trace_callback ||
        abrams_strut_claiming || abrams_motor_pool_claiming || !vga.mem.linear) return false;
    Bit32u header[6] = {0x414f4253u, 1u, Bit32u(size), abrams_trace_load,
                       Bit32u(abrams_frontend_text_mode), vga.latch.d};
    Bit8u* raw = (Bit8u*)output;
    memcpy(raw, header, sizeof(header)); raw += sizeof(header);
    memcpy(raw, vga.mem.linear, abrams_observer_vga_bytes); raw += abrams_observer_vga_bytes;
#define ABRAMS_SAVE(field) memcpy(raw, &field, sizeof(field)); raw += sizeof(field);
    ABRAMS_OBSERVER_FIELDS(ABRAMS_SAVE)
#undef ABRAMS_SAVE
    return true;
}
extern "C" __attribute__((visibility("default")))
bool abrams_observer_checkpoint_load(const void* input, size_t size) {
    if (!input || size != abrams_observer_checkpoint_size() || !abrams_trace_callback || !vga.mem.linear) return false;
    const Bit8u* raw = (const Bit8u*)input;
    Bit32u header[6]; memcpy(header, raw, sizeof(header)); raw += sizeof(header);
    if (header[0] != 0x414f4253u || header[1] != 1 || header[2] != size ||
        header[3] != abrams_trace_load || header[4] != unsigned(abrams_frontend_text_mode) ||
        header[5] != vga.latch.d ||
        memcmp(raw, vga.mem.linear, abrams_observer_vga_bytes)) return false;
    raw += abrams_observer_vga_bytes;
    const Bit8u* payload = raw;
    // Reject malformed boolean representations before touching any observer.
#define ABRAMS_VALIDATE(field) if (!AbramsObserverFieldValid(raw, field)) return false; raw += sizeof(field);
    ABRAMS_OBSERVER_FIELDS(ABRAMS_VALIDATE)
#undef ABRAMS_VALIDATE
    raw = payload;
#define ABRAMS_LOAD(field) memcpy(&field, raw, sizeof(field)); raw += sizeof(field);
    ABRAMS_OBSERVER_FIELDS(ABRAMS_LOAD)
#undef ABRAMS_LOAD
    // Raster masks and Python draw candidates belong to completed framebuffer
    // slots. Rebuild them from fresh scanlines; do not reuse a displayed mask.
    memset(abrams_ui_rows, 0, sizeof(abrams_ui_rows));
    abrams_ui_valid = false;
    return true;
}
#undef ABRAMS_OBSERVER_FIELDS
#endif
