# Genesis artwork extraction and remastering

## Authority and scope

Nell supplied the ROM and requested local graphic extraction and faithful
high-resolution remastering. Her subsequent clarification makes the **PC version
definitive for gameplay**. Genesis provides visual inspiration only. No Genesis
gameplay rule has been adopted in the simulation.

Working if: simulation rules cite PC evidence, and a Genesis-only behaviour is
never treated as a parity oracle without an explicit decision.

The ROM, memory dumps, extracted graphics, generated derivatives and comparison
images remain local and ignored by Git. This work grants no redistribution rights.
The built-in image-generation tool received only the selected image references
for the requested remastering. No ROM, executable or full workspace was uploaded.

## Source receipt

* File: `GENESIS/M-1 Abrams Battle Tank (USA, Europe).md`
* Format: uninterleaved big-endian Sega Genesis cartridge image. `.md` here means
  Mega Drive ROM, not Markdown.
* Size: 524,288 bytes.
* Header: `ABRAMS BATTLE TANK`, `GM MK-1402 -01`, `(C)SEGA 1991.2`.
* SHA-256: `ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.
* Header checksum and independently calculated word sum both equal `0x727b`.
* The file was read without modification; its digest is checked by the test suite.

This identifies the supplied bytes; it does not establish ownership or a complete
historical provenance for the dump.

## Why capture VDP memory

The ROM has no ordinary directory of PNG files. Its graphics become 8x8, 4-bit
tiles, palette entries and nametable descriptors when the game loads them into
the Genesis video hardware. The original program performs any unpacking and
assembly. Capturing those buffers avoids guessing compression and palette matches.

`tools/genesis_capture.py` is a small headless libretro host. It runs the supplied
game locally, records controller sequences and saves:

* `screen.png`: original rendered 320x224 frame;
* `vram.bin`: 65,536 bytes of pattern/nametable memory;
* `cram.bin`, `vsram.bin`, `reg.bin`: palette, scrolling and VDP registers;
* `reference.state`: a resumable original-game state;
* `receipt.json`: ROM/core hashes, pixel format, byte order, options and file hashes.

The downloaded local reference core is Genesis Plus GX, SHA-256
`4936447a9d1b85f45ef2b5d5e2b63e7a5e8f65c18ca5b42839cfc53645e55543`.
It is kept in `.runtime/genesis/`, excluded from the project distribution.

Primary technical sources:

* [Genesis Plus GX libretro implementation](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/libretro/libretro.c)
* [VDP storage and color packing](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/core/vdp_ctrl.c)
* [Tile rendering and RGB conversion](https://github.com/ekeeke/Genesis-Plus-GX/blob/master/core/vdp_render.c)
* [libretro ABI](https://github.com/libretro/libretro-common/blob/master/include/libretro.h)
* [Official macOS arm64 core download directory](https://buildbot.libretro.com/nightly/apple/osx/arm64/latest/)

Relevant source snapshots are local in `.runtime/genesis/source/`. The frontend
uses this core's exported memory symbols; it is not a generic API for every core.
CRAM is packed native-endian `BBBGGGRRR`, rather than the Genesis bus word layout.
VRAM bytes are swapped within each 16-bit word on the tested little-endian build.
These details are tested instead of inferred from a plausible-looking palette.

## Extraction and verification

`tools/extract_genesis_vdp.py` produces:

* all 2,048 tiles under each of the four 16-color palettes;
* both background nametable planes and the window plane as RGBA PNGs;
* linked hardware sprites with coordinates and descriptors;
* a PNG palette and image-editor-compatible GIMP `.gpl` palette;
* a reconstruction PNG, difference PNG and exact pixel-comparison count.

The compositor deliberately supports the observed zero-scroll, H40,
normal-intensity, full-window, 64x32 nametable configuration. It reports
unsupported configurations instead of pretending they match. Sprite-limit and
mid-frame palette effects are not generalized from this sample.

Ten distinct captures reconstruct exactly: briefing, motor pool, firing title,
information screen, title menu, clean title, gunner, commander, cupola and driver.
Each comparison covers 71,680 pixels. Their total is 716,800 compared pixels with
zero differences. These checks establish the captured scenes' decoding, not
exhaustive extraction of every ROM asset or gameplay parity.

Reproduction examples, from the project root:

```sh
python3 tools/genesis_capture.py --output reference/genesis/new-boot \
  --sequence '120:boot,240:title,240:credits,1+start,120:menu'
python3 tools/extract_genesis_vdp.py \
  reference/genesis/title-clean/f440 reference/genesis/new-title-extraction
python3 -m unittest discover -s tests -p test_genesis_graphics.py -v
```

Capture directories are never overwritten. Each session's `sequence.json`
records its inputs and any restored state. Some gameplay input polls miss
one-frame taps, so later station captures use ten-frame presses and release gaps.
Early exploratory folder names are attempted destinations, not verified station
identities. Use the observed identity table in the local asset manifest.

## Image-software deliverables

`local-art/genesis/source/` contains lossless native-size extracts and
`source-manifest.json`, including source hashes and exact crop rectangles.
`briefing-original.ora` is an OpenRaster file with separate office and Wilson
layers at their original positions. It excludes the dialogue box.

`local-art/genesis/remastered/` contains:

| Asset | File | Measured pixels |
|---|---|---|
| Colonel Wilson, alpha cutout | `wilson-v1.png` | 1293x1217 |
| Empty briefing office | `office-background-v1.png` | 1586x992 |
| Title illustration | `title-v1.png` | 1586x992 |
| Motor pool, interface removed | `motor-pool-v1.png` | 1586x992 |

These are built-in image-generation edits of the extracted reference images.
They are new high-resolution interpretations, distinct from exact extracts.
The source framing is retained by the Godot preview. Generated dimensions differ
slightly from the requested 8:5 and 136:128 ratios; the preview applies the original
ratios. No claim of 4K output is made.

`prompts.json` records the exact prompts, input roles, paths and tool choice.
`remaster-manifest.json` records measured dimensions, hashes and alpha status.
`briefing-remastered.svg` is an editable, self-contained two-layer composition
with the unmodified generated PNGs embedded, positioned to the original layout.
Its office and officer remain separate image objects.

The artwork direction keeps hard contours, flat illustrated shading, familiar
silhouettes and limited grey/olive palettes. The motor-pool menu was removed
deliberately so Godot can render PC ammunition and governor controls separately.
The small area it covered is an inferred reconstruction. Fine insignia, hands,
equipment details and inferred occluded content remain authored interpretations.

Nell approved the first Wilson and office images with “These look great, good
job!” The title and motor pool continue that treatment. The remasterer reviewed
its own generated work in the Godot preview; that is not independent art review.

## Preview and remaining work

Run `Art Review.command`, or choose **ORIGINAL / REMASTER ART** from the local
Godot menu. Left/right or buttons select a scene; Tab compares original and
remaster; Escape returns to the garage. Artwork is loaded from the ignored local
folder at runtime, so it is never silently bundled into a source-only export.

Verified: native Godot capture of all three scenes in both modes at 1440x810 and
1920x1080, alpha-composited briefing, source framing and readable review controls. The optional Impeccable
frontend linter is unavailable; no dependency was installed for this native
Godot surface. The screen capture is the visual validation evidence.

Remaining: other dialogue/portrait animation frames, vehicle-recognition artwork,
all menu/information states, high-resolution cockpit panels, and consistent
in-world geometry. The low-polygon playfield is rendered by the original program;
a framebuffer extract does not recover the underlying model or world semantics.
PC instrument information and controls must survive any visual redesign.
