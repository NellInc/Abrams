#!/usr/bin/env python3
"""Extract this supplied ROM's native PCM, FM patches and music containers.

No emulator, mixer, gameplay recording, filtering or resampling is involved.
This bounded decoder rejects other ROM revisions. See genesis-audio-workflow.md
for the disassembled loader addresses that establish these structures.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
ROM_HASH = "ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea"
SFX_TABLE, SFX_COUNT = 0x5DE20, 19
SONG_TABLE, SONG_COUNT = 0x5B066, 4
PCM_TABLE = 0x5DE92
FM_BANKS = ((0x5AB1A, 6), (0x5ABFE, 4), (0x5AC96, 5), (0x5AD54, 5), (0x5AE12, 5))
# Z80 sets Timer A to 0x3f9. YM2612 timer ticks at master / (7*144).
# WAV needs an integer rate. Raw .u8 bytes remain the authoritative samples.
NTSC_NOMINAL_RATE = 53693175 / (7 * 144 * (1024 - 0x3F9))
WAV_RATE = round(NTSC_NOMINAL_RATE)


def take(rom, offset, size):
    if offset < 0 or size < 0 or offset + size > len(rom):
        raise ValueError("Asset extends outside the ROM")
    return rom[offset:offset + size]


def sample_bytes(rom, header):
    length, = struct.unpack(">I", take(rom, header, 4))
    if not 0 < length <= 65535:
        raise ValueError("Sample length does not fit the observed 16-bit driver counter")
    if ((header + 4) & 0x7FFF) + length > 0x8000:
        raise ValueError("Sample crosses the observed fixed 32 KiB Z80 ROM bank")
    return take(rom, header + 4, length)


def fm_patch(raw):
    if len(raw) != 38:
        raise ValueError("FM patches are 38 bytes")
    registers = {"22": raw[0], "B0": raw[2], "B4": raw[3]}
    for operator in range(4):
        for j, base in enumerate((0x30, 0x40, 0x50, 0x60, 0x70, 0x80)):
            registers[f"{base + operator * 4:02X}"] = raw[4 + operator * 6 + j]
        registers[f"{0x90 + operator * 4:02X}"] = 0
    return {"channel_relative_registers": registers, "algorithm": raw[2] & 7,
            "feedback": (raw[2] >> 3) & 7, "channel3_mode": raw[1],
            "channel3_frequency_bytes": raw[28:36].hex(), "key_on_operator_mask": raw[36],
            "driver_parameter_37": raw[37],
            "note": "Base instrument settings; channel, note frequency and dynamic levels are applied by the sequencer"}


def read_directory(rom):
    effects, samples = [], {}
    for i in range(SFX_COUNT):
        kind, pointer = struct.unpack(">HI", take(rom, SFX_TABLE + i * 6, 6))
        if kind not in (0, 1, 2) or pointer >= len(rom):
            raise ValueError("Invalid sound dispatch entry")
        effects.append({"id": i, "type": ("code", "sequence", "pcm")[kind], "pointer": pointer})
        if kind == 2:
            samples[pointer] = {"name": f"sfx-{i:02d}", "source_table_entry": SFX_TABLE + i * 6}
    for i in range(2):
        pointer, = struct.unpack(">I", take(rom, PCM_TABLE + i * 4, 4))
        samples[pointer] = {"name": f"music-sample-{i:02d}", "source_table_entry": PCM_TABLE + i * 4}
    samples[0x5DE9A] = {"name": "startup-silence", "source_code_reference": 0x121FC}
    return effects, samples


def extract(rom_path, output):
    rom = rom_path.read_bytes()
    if hashlib.sha256(rom).hexdigest() != ROM_HASH:
        raise ValueError("Unsupported ROM revision; no files extracted")
    effects, samples = read_directory(rom)
    # Validate every sample before creating the output directory.
    for address in samples:
        sample_bytes(rom, address)
    output.mkdir(parents=True, exist_ok=False)
    for subdir in ("samples", "fm-patches", "music", "native"):
        (output / subdir).mkdir()
    files = {}

    def save(name, raw, offset=None):
        (output / name).write_bytes(raw)
        files[name] = {"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}
        if offset is not None:
            if raw != take(rom, offset, len(raw)):
                raise ValueError("Native extract differs from source bytes")
            files[name]["rom_offset"] = offset

    extracted_samples = []
    for header, details in sorted(samples.items()):
        raw = sample_bytes(rom, header)
        name = details["name"]
        save(f"samples/{name}.u8", raw, header + 4)
        wav_name = f"samples/{name}.wav"
        with wave.open(str(output / wav_name), "wb") as writer:
            writer.setparams((1, 1, WAV_RATE, 0, "NONE", "not compressed"))
            writer.writeframes(raw)
        # Assert that wrapping the asset in WAV did not alter a single sample.
        with wave.open(str(output / wav_name), "rb") as reader:
            if reader.readframes(reader.getnframes()) != raw:
                raise ValueError("WAV sample payload changed")
        wrapped = (output / wav_name).read_bytes()
        files[wav_name] = {"bytes": len(wrapped), "sha256": hashlib.sha256(wrapped).hexdigest()}
        extracted_samples.append({**details, "header_offset": header, "data_offset": header + 4,
                                  "sample_count": len(raw), "encoding": "unsigned 8-bit mono PCM",
                                  "wav_rate": WAV_RATE, "nominal_ntsc_rate": NTSC_NOMINAL_RATE,
                                  "preview_duration_seconds": len(raw) / WAV_RATE,
                                  "identity": "source ID only, listening identification pending"})

    banks = []
    for bank, (offset, count) in enumerate(FM_BANKS):
        save(f"native/fm-bank-{bank:02d}.bin", take(rom, offset, count * 38), offset)
        patches = []
        for index in range(count):
            start = offset + index * 38
            raw = take(rom, start, 38)
            save(f"fm-patches/bank-{bank:02d}-patch-{index:02d}.bin", raw, start)
            patches.append({"index": index, "rom_offset": start, **fm_patch(raw)})
        save(f"fm-patches/bank-{bank:02d}.json", (json.dumps(patches, indent=2) + "\n").encode())
        banks.append({"bank": bank, "rom_offset": offset, "patch_count": count})

    songs = []
    entries = [struct.unpack(">III", take(rom, SONG_TABLE + i * 12, 12)) for i in range(SONG_COUNT)]
    for i, (fm, psg, start) in enumerate(entries):
        end = entries[i + 1][2] if i + 1 < len(entries) else 0x5DB56
        count, = struct.unpack(">H", take(rom, start, 2))
        if not 1 <= count <= 10 or start + 2 + count * 38 >= end:
            raise ValueError("Invalid music track header")
        tracks = []
        for index in range(count):
            header = take(rom, start + 2 + index * 38, 38)
            initial, current = struct.unpack_from(">II", header)
            if not start + 2 + count * 38 <= initial < end or current != initial:
                raise ValueError("Music track pointer is outside its native container")
            tracks.append({"index": index, "sequence_pointer": initial, "header_hex": header.hex()})
        save(f"music/song-{i:02d}.bin", take(rom, start, end - start), start)
        songs.append({"id": i, "rom_offset": start, "end_exclusive": end,
                      "fm_bank_pointer": fm, "psg_bank_pointer": psg, "tracks": tracks,
                      "format": "Original driver container; commands and timing not converted to MIDI"})
    for name, start, size in (("sound-dispatch", SFX_TABLE, SFX_COUNT * 6),
                              ("song-directory", SONG_TABLE, SONG_COUNT * 12),
                              ("music-sample-directory", PCM_TABLE, 8),
                              ("default-psg-patches", 0x5AED0, 18),
                              ("synthesized-effects", 0x5DB56, SFX_TABLE - 0x5DB56)):
        save(f"native/{name}.bin", take(rom, start, size), start)
    manifest = {"source_rom": rom_path.name, "rom_sha256": ROM_HASH,
                "method": "Direct byte extraction from referenced ROM tables; no recording",
                "sample_rate_note": "WAV uses rounded nominal NTSC Timer A rate; scheduling stalls and analog hardware response are not reproduced",
                "samples": extracted_samples, "effects": effects, "fm_banks": banks,
                "songs": songs, "files": files}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"Extracted {len(samples) - 1} non-placeholder PCM assets, one silence placeholder, "
          f"{sum(n for _, n in FM_BANKS)} FM patches and {len(songs)} native music containers")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rom", type=Path, default=ROOT / "GENESIS/M-1 Abrams Battle Tank (USA, Europe).md")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    extract(args.rom, args.output)


if __name__ == "__main__":
    main()
