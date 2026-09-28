# Native Genesis effect resources

## Recovered source

The supplied Genesis ROM contains **64 masked bitmap effects**. This family is
software-rendered into the world surface; the sampled hardware sprite table has
only its off-screen dummy entry. Looking only for VDP sprites misses these assets.

The pinned ROM SHA-256 is
`ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.
Offsets below are specific to that ROM and are rejected for other input hashes.

* Directory: `0x431be`, 64 eight-byte descriptors: big-endian u16 width,
  u16 height and u32 ROM pointer.
* Pixel resource: `0x3c09e..0x431bd`, **28,960 bytes**, contiguous in directory
  order. Four pixels occupy one color word and one preservation-mask word.
  High nibble is the leftmost pixel; rows are consecutive.
* Original selector at `0x109c4` multiplies the bitmap index by eight, reads
  dimensions, subtracts half-width/height from the center and enters `0x5988`.
* The original blitter reads descriptor dimensions and pointer at `0x59a6`.
  Its aligned path at `0x5a72` computes `(destination & preserve) | color`.
  Each preservation nibble is either zero (opaque) or fifteen (unchanged).
  The decoder preserves this explicit mask, including support for opaque black.

The 64 dimensions, **every pixel index**, and all masks independently match
the decoded PC `EFFECTS.BMP`. Genesis is therefore an available native source for
this family, but it does not contain additional spatial detail in these frames.
The presentation palettes differ. This finding is specific to the recovered
effect table and does not generalize to cockpit or other Genesis artwork.

Extracts and receipts:
`local-art/genesis/source/effects-v1/effects.json`, 64 native-size RGBA PNGs,
and `contact-sheet.png`. Original resources and generated artwork stay separate.
Palette bank 3 from the native ordinary gunner capture was explicitly selected.
Other viewing modes/palette variants remain to be inventoried.

## Independent and native checks

`tools/genesis_effect_oracle.py` executes the unchanged original blitter in
Unicorn 2.1.4, M68000 mode. An isolated native-format backing surface exercises
all 64 images, eight horizontal nibble alignments, left/top/right/bottom clipping
and off-screen cases, against black, index-five and index-fifteen backgrounds.
It compares every resulting surface pixel with the independently decoded source:

* **2,688 cases; 13,762,560 pixels; zero mismatches.**
* Receipt: `artifacts/genesis-effects-research-01/blitter-oracle.json`.
* This is source/renderer evidence, not live animation-timing or simulation proof.
  No live core, guest instructions, ROM or save state were modified.

Native fire sequence: restore
`reference/genesis/instruments/gunner/reference.state`, hold A for ten Genesis
frames, then release. `reference/genesis/effects-fire-01/` retains 13 distinct
screens from 420 frames, full VDP memory, native states and hashed receipts.
The pinned core hash is
`4936447a9d1b85f45ef2b5d5e2b63e7a5e8f65c18ca5b42839cfc53645e55543`.

Two bounded visible-frame fixtures establish the palette and appearance:

| Frame | Bitmap | Top-left | Visible opaque pixels | Original sight covers |
|---|---|---|---|---|
| 24 | 52 | 152, 80 | 23 | 2 |
| 34 | 53 | 152, 83 | 20 | 4 |

The window nametable descriptors select palette bank 3 at every checked pixel.
All effect pixels match that palette, except the six separately checked black
sight pixels. Both complete frames reconstruct exactly from VDP memory:
**143,360 compared screen pixels, zero mismatches**. Reticle coverage here is
bounded visible-frame evidence, not a recovered Genesis drawing hook.
Receipts: `artifacts/genesis-effects-research-01/native-reconstruction/`.

Early research hypotheses are retained rather than relabelled as successes:
raw packed-PC searches failed because Genesis interleaves preservation words;
palette-bank-zero matching failed because the world uses bank three; the first
native test assumed a continuous horizontal sight line across the center and
failed at `(158,80)`. The actual sight has a gap. The corrected test accounts for
the observed strokes, and separately checks all remaining opaque effect pixels.
The first CPU-oracle invocation failed because its minimal environment lacked
Pillow. Moving presentation imports into the export function allowed the pure
decoder to run there without installing dependencies.

## Host capture correction

Repeated `ReferenceCore.restore()` previously kept the host's old frame counter
and cached image. That was broken provenance: a new receipt could report frames
since a previous restore, or expose a stale image before rendering a new frame.
Successful restore now clears those host observations and pressed input. A
rejected restore still raises and does not report a new observation epoch.

The independent button probes in `reference/genesis/effects-buttons-01/` predate
the correction. Their counter values accumulate across probes, even though each
probe restored the same source state and ran forty frames. Their sequence file
records the restores. The extra `work-ram.bin` files were written after their
receipts and are not hashed by those receipts; they are not used for source proof.

A fresh same-process double-restore experiment produces frame counts `[24,24]`,
identical complete capture file hashes, and unchanged screen/VDP bytes against
the earlier valid frame-24 capture. Receipt:
`artifacts/genesis-effects-research-01/repeated-restore/report.json`.

## High-resolution studies and remaining work

Built-in image generation produced three individual native-reference studies
for the bright burst, fading fragments and smoke-ring frames 15, 16 and 17.
They remain **unselected art candidates**, with original live effects unchanged.
The implementing assistant produced and visually reviewed these candidates;
that is self-review, not independent art acceptance.

`local-art/genesis/remastered/effects-v1/manifest.json` records paths, hashes,
source IDs, exact prompt files, alpha bounds and native-scale mask comparisons.
Two earlier three-cell atlases are retained: the first had coarse edges and
rock-like smoke; the revision still lost the native ring structure. The approach
then changed to one enlarged native reference per image, without feeding back
the rejected atlas. These individual studies have cleaner contours and retain
the inner smoke curl. Their native-scale mask overlap scores are approximately
0.72, 0.71 and 0.61; this is measured silhouette change, not a parity pass.

The smoke candidate's conspicuous preview speckles are very low-alpha residue:
there are no colored/white residue pixels above alpha 31/255, and proper
compositing is visually clean. Filtering and edge-touching components still need
checking before a runtime selection. The authored transparency is retained.

Next work is animation-family selection/timing recovery, a consistent authored
set for all required phases/detail levels, and PC-driven binding with verified
size, placement, clip, painter order and visibility. Do not infer timing from
the ordering of files, substitute Genesis gameplay, or mark the effect family
complete from these source extracts or art studies.

## Reproduction and gate

```sh
python3 tools/extract_genesis_effects.py \
  --capture reference/genesis/effects-fire-01/f0024 --palette-bank 3 \
  --output local-art/genesis/source/effects-fresh
.runtime/pc-analysis-venv/bin/python tools/genesis_effect_oracle.py \
  --output artifacts/genesis-effects-fresh/oracle.json
python3 -m unittest tests.test_genesis_effects tests.test_genesis_graphics -v
./tools/validate.sh
```

The focused gate passes 19 tests. The aggregate gate
`artifacts/validation-20260928T043521Z` exits zero: **36 stages and 254 Python
tests pass**, including original-reference preservation. No Godot runtime
graphics were changed in this pass. No push, publication or redistribution.
