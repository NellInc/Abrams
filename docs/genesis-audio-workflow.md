# Genesis audio assets

## Authority and delivery

Nell authorized Genesis sounds and music as presentation references, then clarified
that reusable samples should be extracted instead of recording mixed gameplay.
The current delivery uses direct ROM extraction. PC gameplay, event triggers and
timing remain definitive. Original speech is being replaced with generative TTS,
covered separately in `voice-workflow.md`.

Working if: the extraction tool runs without an emulator or audio mixer, and each
native sample's bytes equal its documented ROM slice.

`local-audio/genesis-native-v1/` contains:

* Ten PCM samples: eight sound-dispatch entries and two music sample entries.
* A two-byte initialization-silence placeholder, kept separately identified.
* Unsigned 8-bit mono `.u8` files and WAV wrappers with identical sample payloads.
* Twenty-five original 38-byte FM patches across five banks, with register JSON.
* Four original music containers with 6, 4, 5 and 5 track headers respectively.
* Sound/music directories, three default PSG patches and the native synthesized
  effects block, retained byte-for-byte.
* A manifest with ROM offsets, lengths, file hashes, dispatch IDs and boundaries.

`local-audio/Abrams-native-audio-v1.zip` packages those assets and this guide.
It excludes the ROM, emulator, saved states and mixed playback recordings.

## Recovered structures

The supplied ROM SHA-256 is
`ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.
The extractor rejects other revisions before writing output. No source file is
modified. These facts come from the supplied program's disassembly:

| ROM address | Evidence |
|---|---|
| `0x12D92` | Dispatches six-byte entries from `0x5DE20`: type 0 calls code, type 1 starts a sequence, type 2 queues PCM. |
| `0x12E0C` | Reads a big-endian four-byte sample length, then passes length, address and ROM bank to the Z80 mailbox. |
| `0x5A954` | Z80 driver copied by the loader at `0x4B74`. Its playback loop copies sample bytes to YM2612 register `0x2A`. |
| `0x12B76` | Sequence sample command selects one of two pointers at `0x5DE92`. |
| `0x120E8` | Song ID indexes twelve-byte records at `0x5B066`, selecting instrument and track banks. |
| `0x12ECA` | Copies a leading track count followed by 38-byte initial track states. |
| `0x12398` | Selects 38-byte FM patches; subsequent writes establish the register mapping. |

The 19-entry sound table ends immediately before the two-entry music sample table.
All eleven referenced sample payloads fit their original 32 KiB bank and 16-bit
length counter. The music containers retain their native pointers and commands;
no MIDI conversion or reconstructed arrangement is claimed.

The decoded FM JSON describes base registers. Sequence-level pitch, velocity,
envelopes, channel assignment and special channel-3 behavior still need a complete
music interpreter. The raw patches preserve every field, including those not yet
assigned a semantic name. Synthesized FM/PSG sounds are patch/sequence assets;
they do not inherently exist as stored PCM waveforms.

## Sample rate and preservation

The Z80 initializes Timer A high/low registers to `0xFE` and `0x01`, giving
`0x3F9`. The nominal NTSC cadence derived from the timer is:

```
53,693,175 / (7 * 144 * (1024 - 0x3F9)) = 7,609.576955782313 samples/second
```

WAV headers use the nearest integral rate, 7,610 Hz. No sample values are changed
and no interpolation, normalization, trimming or filtering is performed. Raw
`.u8` files remain authoritative. This nominal preview cadence does not reproduce
interrupt/bus stalls or the analog output of the original hardware.

The clock and timer interpretation were checked against the reference core's
[system constants](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/core/system.h),
[sound clock setup](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/core/sound/sound.c)
and [YM2612 timer implementation](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/core/sound/ym2612.c).
The actual samples and tables come from Nell's local ROM, not a downloaded rip.

## Reproduction and verification

```sh
python3 tools/extract_genesis_samples.py \
  --output local-audio/genesis-native-new
python3 -m unittest discover -s tests -p test_genesis_samples.py -v
```

Tests compare all native file bytes against the ROM, reopen every WAV and compare
its data payload, verify track pointers and hashes, reject malformed lengths and
unsupported ROMs, and check that existing output cannot be overwritten.

Sample IDs are preserved without guessing semantic names. Listening identification,
complete sequence interpretation, finished music arrangements and higher-fidelity
replacement effects remain open. Native references stay outside Godot exports
until identities, suitability and distribution decisions are resolved.

## Earlier comparison recordings

The seven mixed captures in `local-audio/genesis/` remain untouched as historical
comparison material. They are superseded as the asset source and are excluded from
the native sample pack. Their capture tool and integrity tests remain available;
they do not satisfy the sample-extraction request on their own.

All Genesis-derived assets remain local and Git-ignored. No redistribution rights
were established. No ROM, sample bank or original game audio has been uploaded.
