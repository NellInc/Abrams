// Local WebAssembly feasibility frontend for the pinned DOSBox Pure libretro core.
// The original DOS game remains the sole gameplay authority. GPL-2.0-or-later.
#include "libretro-common/include/libretro.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <atomic>
#include <map>
#include <mutex>
#include <string>
#include <vector>
#include "claim_core.h"

extern "C" unsigned abrams_state_overlay_abi();
extern "C" bool abrams_state_flush_overlay();
extern "C" bool abrams_state_reload_overlay();
using AbramsTraceCallback = void (*)(uint32_t, const uint16_t*, const uint8_t*, uint32_t, uint32_t);
extern "C" void abrams_trace_configure(uint16_t, AbramsTraceCallback);
extern "C" void abrams_frontend_text_configure(AbramsTraceCallback);

namespace {
constexpr const char* kSaveDirectory = "/saves";
// A source-owned SIM draw can snapshot the 640 KiB RAM image more than 25
// times in one original frame. The former 16 MiB cap stopped ordinary play.
// Keep a finite bound; the observer consumes this packet inside its worker.
constexpr size_t kTraceLimit = 64 * 1024 * 1024;
std::map<std::string, std::string> defaults;
std::map<std::string, std::string> overrides = {
    {"dosbox_pure_conf", "inside"}, {"dosbox_pure_machine", "ega"},
    {"dosbox_pure_cpu_core", "normal"}, {"dosbox_pure_cpu_type", "386"},
    {"dosbox_pure_cycles", "3000"}, {"dosbox_pure_auto_mapping", "false"},
    {"dosbox_pure_voodoo", "off"}, {"dosbox_pure_voodoo_perf", "0"},
};
retro_keyboard_event_t keyboard = nullptr;
std::vector<retro_memory_descriptor> memory_maps;
bool pressed[512] = {};
bool active = false;
bool shutdown_requested = false;
std::vector<uint8_t> video;
std::vector<uint8_t> paired_ram(640 * 1024);
std::vector<uint8_t> trace_events;
std::mutex trace_lock;
bool trace_enabled = false;
bool trace_overflow = false;
unsigned trace_count = 0;
AbramsWebClaims claims;
bool claim_active = false;
std::atomic<bool> claim_fault{false};
unsigned video_width = 0, video_height = 0, video_pitch = 0;

void trace_word(uint32_t value, unsigned bytes) {
    for (unsigned index = 0; index < bytes; ++index)
        trace_events.push_back(static_cast<uint8_t>(value >> (index * 8)));
}

// Mirror the native callback in call order. Each record is event:u32,
// offset:u32, length:u32, twelve register words, then the original bytes.
void trace_callback(uint32_t event, const uint16_t* registers,
                    const uint8_t* data, uint32_t offset, uint32_t length) {
    constexpr size_t kHeader = 12 + 12 * 2;
    std::lock_guard<std::mutex> lock(trace_lock);
    if (trace_overflow) return;
    if (length > kTraceLimit - kHeader || trace_events.size() > kTraceLimit - kHeader - length ||
        (length && !data) || !registers) {
        trace_overflow = true;
        return;
    }
    trace_word(event, 4);
    trace_word(offset, 4);
    trace_word(length, 4);
    for (unsigned index = 0; index < 12; ++index) trace_word(registers[index], 2);
    if (length) trace_events.insert(trace_events.end(), data, data + length);
    ++trace_count;
    if (claim_active && !claims.observe(event, registers, data, offset, length))
        claim_fault.store(true);
}

bool environment(unsigned command, void* data) {
    if (command == RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY ||
        command == RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY) {
        *static_cast<const char**>(data) = kSaveDirectory;
        return true;
    }
    if (command == RETRO_ENVIRONMENT_GET_CAN_DUPE) {
        *static_cast<bool*>(data) = true;
        return true;
    }
    if (command == RETRO_ENVIRONMENT_SET_PIXEL_FORMAT)
        return *static_cast<unsigned*>(data) == RETRO_PIXEL_FORMAT_XRGB8888;
    if (command == RETRO_ENVIRONMENT_SET_KEYBOARD_CALLBACK) {
        keyboard = static_cast<retro_keyboard_callback*>(data)->callback;
        return true;
    }
    if (command == RETRO_ENVIRONMENT_SET_VARIABLES) {
        for (const auto* row = static_cast<const retro_variable*>(data); row->key; ++row) {
            std::string value = row->value ? row->value : "";
            auto separator = value.find("; ");
            if (separator != std::string::npos) value.erase(0, separator + 2);
            auto next = value.find('|');
            if (next != std::string::npos) value.erase(next);
            defaults[row->key] = value;
        }
        return true;
    }
    if (command == RETRO_ENVIRONMENT_GET_VARIABLE) {
        auto* row = static_cast<retro_variable*>(data);
        if (!row->key) return false;
        auto override_it = overrides.find(row->key);
        if (override_it != overrides.end()) {
            row->value = override_it->second.c_str();
            return true;
        }
        auto default_it = defaults.find(row->key);
        if (default_it == defaults.end()) return false;
        row->value = default_it->second.c_str();
        return true;
    }
    if (command == RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE) {
        *static_cast<bool*>(data) = false;
        return true;
    }
    if (command == RETRO_ENVIRONMENT_GET_THROTTLE_STATE) {
        auto* state = static_cast<retro_throttle_state*>(data);
        state->mode = RETRO_THROTTLE_FRAME_STEPPING;
        state->rate = 0.0f;
        return true;
    }
    if (command == RETRO_ENVIRONMENT_GET_LANGUAGE ||
        command == RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION) {
        *static_cast<unsigned*>(data) = 0;
        return true;
    }
    if (command == RETRO_ENVIRONMENT_SET_MEMORY_MAPS) {
        const auto* map = static_cast<const retro_memory_map*>(data);
        if (!map->descriptors || map->num_descriptors < 1 || map->num_descriptors > 8)
            return false;
        memory_maps.assign(map->descriptors, map->descriptors + map->num_descriptors);
        return true;
    }
    if (command == RETRO_ENVIRONMENT_SET_CONTROLLER_INFO ||
        command == RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY) return true;
    if (command == RETRO_ENVIRONMENT_SHUTDOWN) {
        shutdown_requested = true;
        return true;
    }
    return false;
}

void video_refresh(const void* pixels, unsigned width, unsigned height, size_t pitch) {
    if (!pixels || width < 1 || width > 2048 || height < 1 || height > 2048 ||
        pitch < width * 4 || pitch > 16384) return;
    video_width = width;
    video_height = height;
    video_pitch = static_cast<unsigned>(pitch);
    video.resize(pitch * height);
    std::memcpy(video.data(), pixels, video.size());
}

void audio_sample(int16_t, int16_t) {}
size_t audio_sample_batch(const int16_t*, size_t frames) { return frames; }
void input_poll() {}
int16_t input_state(unsigned port, unsigned device, unsigned index, unsigned key) {
    return port == 0 && device == RETRO_DEVICE_KEYBOARD && index == 0 &&
           key < 512 && pressed[key];
}

void fence() {
    retro_system_av_info info = {};
    retro_get_system_av_info(&info);
}

bool copy_paired_ram() {
    const retro_memory_descriptor *low = nullptr, *high = nullptr;
    for (const auto& descriptor : memory_maps) {
        const auto* item = &descriptor;
        if (item->start == 0) low = item;
        else if (item->start == 0x100000) high = item;
    }
    if (!low || !high || !low->ptr || !high->ptr ||
        low->len + high->len != paired_ram.size() ||
        static_cast<const uint8_t*>(low->ptr) !=
            static_cast<const uint8_t*>(high->ptr) + high->len ||
        low->offset || high->offset || low->select || high->select ||
        low->disconnect || high->disconnect) {
        std::fprintf(stderr, "Abrams web RAM map: count=%u low=%p len=%zu high=%p len=%zu\n",
                     static_cast<unsigned>(memory_maps.size()), low ? low->ptr : nullptr,
                     low ? low->len : 0, high ? high->ptr : nullptr,
                     high ? high->len : 0);
        return false;
    }
    std::memcpy(paired_ram.data(), high->ptr, high->len);
    std::memcpy(paired_ram.data() + high->len, low->ptr, low->len);
    return true;
}
}  // namespace

extern "C" {
int abrams_web_start(const char* content_path) {
    if (active || !content_path || shutdown_requested) return 0;
    FILE* file = std::fopen(content_path, "rb");
    if (!file) return 0;
    std::fclose(file);
    retro_set_environment(environment);
    retro_set_video_refresh(video_refresh);
    retro_set_audio_sample(audio_sample);
    retro_set_audio_sample_batch(audio_sample_batch);
    retro_set_input_poll(input_poll);
    retro_set_input_state(input_state);
    retro_init();
    const retro_game_info game = {content_path, nullptr, 0, nullptr};
    active = retro_load_game(&game);
    if (!active) {
        retro_deinit();
        return 0;
    }
    fence();
    return 1;
}

int abrams_web_step() {
    if (!active || shutdown_requested || claim_fault.load() || !copy_paired_ram()) return 0;
    {
        std::lock_guard<std::mutex> lock(trace_lock);
        trace_events.clear();
        trace_count = 0;
        trace_overflow = false;
        claims.receipts.clear();
    }
    retro_run();
    fence();
    return shutdown_requested || claim_fault.load() ? 0 : 1;
}

int abrams_web_key(unsigned key, int down) {
    if (!active || !keyboard || key >= 512) return 0;
    if (pressed[key] == !!down) return 1;
    pressed[key] = !!down;
    keyboard(!!down, key, key >= 32 && key < 127 ? key : 0, 0);
    return 1;
}

const uint8_t* abrams_web_video() { return video.empty() ? nullptr : video.data(); }
unsigned abrams_web_video_width() { return video_width; }
unsigned abrams_web_video_height() { return video_height; }
unsigned abrams_web_video_pitch() { return video_pitch; }
int abrams_web_trace_frontend() {
    if (!active) return 0;
    fence();
    {
        std::lock_guard<std::mutex> lock(trace_lock);
        trace_events.clear();
        trace_count = 0;
        trace_overflow = false;
    }
    abrams_frontend_text_configure(trace_callback);
    trace_enabled = true;
    claim_active = false;
    return 1;
}
int abrams_web_set_claim_catalog(const uint8_t* source, unsigned size) {
    if (!active || trace_enabled) return 0;
    return claims.configure(source, size) ? 1 : 0;
}
int abrams_web_trace_sim(unsigned load_segment) {
    if (!active || load_segment < 16 || load_segment > 0xffff) return 0;
    fence();
    {
        std::lock_guard<std::mutex> lock(trace_lock);
        trace_events.clear();
        trace_count = 0;
        trace_overflow = false;
    }
    abrams_trace_configure(static_cast<uint16_t>(load_segment), trace_callback);
    trace_enabled = true;
    claims.reset();
    claim_active = claims.is_loaded();
    return 1;
}
void abrams_web_trace_stop() {
    if (!trace_enabled) return;
    fence();
    abrams_trace_configure(0, nullptr);
    trace_enabled = false;
    claim_active = false;
    {
        std::lock_guard<std::mutex> lock(trace_lock);
        trace_events.clear();
        trace_count = 0;
        trace_overflow = false;
    }
}
const uint8_t* abrams_web_trace_events() { return trace_events.empty() ? nullptr : trace_events.data(); }
unsigned abrams_web_trace_size() { return static_cast<unsigned>(trace_events.size()); }
unsigned abrams_web_trace_count() { return trace_count; }
int abrams_web_trace_overflow() { return trace_overflow ? 1 : 0; }
int abrams_web_claim_fault() { return claim_fault.load() ? 1 : 0; }
const uint8_t* abrams_web_claim_receipts() { return claims.receipts.empty() ? nullptr : claims.receipts.data(); }
unsigned abrams_web_claim_receipts_size() { return static_cast<unsigned>(claims.receipts.size()); }
const uint8_t* abrams_web_paired_ram() { return paired_ram.data(); }
unsigned abrams_web_paired_ram_size() { return static_cast<unsigned>(paired_ram.size()); }
unsigned abrams_web_state_size() {
    if (!active) return 0;
    fence();
    size_t size = retro_serialize_size();
    return size > 0 && size <= 128 * 1024 * 1024 ? static_cast<unsigned>(size) : 0;
}
int abrams_web_save_state(void* target, unsigned size) {
    return active && target && size == abrams_web_state_size() &&
           retro_serialize(target, size);
}
int abrams_web_flush_overlay() {
    if (!active) return 0;
    fence();
    return abrams_state_overlay_abi() == 1 && abrams_state_flush_overlay();
}
int abrams_web_restore_state(const void* state, unsigned size) {
    if (!active || !state || !size || size > 128 * 1024 * 1024) return 0;
    fence();
    if (abrams_state_overlay_abi() != 1 || !abrams_state_reload_overlay()) return 0;
    if (!retro_unserialize(state, size)) return 0;
    fence();
    video.clear();
    video_width = video_height = video_pitch = 0;
    return copy_paired_ram();
}
const uint8_t* abrams_web_ram_now() {
    if (!active) return nullptr;
    fence();
    return copy_paired_ram() ? paired_ram.data() : nullptr;
}
}
