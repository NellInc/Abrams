# PC-selected, Genesis-derived impact artwork

Current ordinary-palette coverage is now all 64 source-bound bitmaps through
20 authored donors. See [the complete atlas extension](pc-effect-art-completion.md)
for current evidence and remaining palette/live-sequence/human-review limits.
The sections below retain the earlier bounded checkpoint.


## Bounded result

Three high-resolution Genesis-derived images now replace nine verified PC
impact bitmaps in the default trace-backed Play view. The original PC executable
still selects the phase, distance/detail variant, origin, clip and draw order.
There is no presentation animation timer or gameplay-state write.

This work was implemented and visually reviewed by the same assistant. It is
self-review, not Nell's art acceptance or a finished effect-family claim.

| Original shape | Original bitmap IDs | Selected authored donor |
|---|---|---|
| 183 | 15, 33, 51 | `impact-15-native-candidate.png` |
| 184 | 16, 34, 52 | `impact-16-native-candidate.png` |
| 185 | 17, 35, 53 | `smoke-17-candidate-03.png` |

`SHAPE.TBL` defines selectors 16, 8 and 4 for each of these three shapes. Their
roots are 33696/33698/33700, 33722/33724/33726 and 33748/33750/33752. The source
test decodes and checks these commands directly. Source extraction, Genesis
palette evidence and the original M68000 blitter oracle are documented in
`genesis-effects-research.md`.

## Registration and fail-closed selection

`godot/scripts/pc_effect_art.gd` pins the extracted source catalog and all three
authored files by SHA-256. A replacement requires the ordinary PC palette,
observed sprite status, matching shape/root/bitmap identity, flags 8, and exact
source dimensions, pixel indices and preservation mask. An unknown palette or
source retains the existing original sprite renderer. `--original-effects`
explicitly disables the new art. Missing local assets also retain original art.

Original opaque bounds define the destination size and position. Using each
variant's bounds separately preserves its row padding instead of stretching all
images to their storage dimensions. Original camera and sprite clips intersect
before any triangles are emitted. Each replacement occupies the sprite's place
in the same ordered mesh as the original polygons, so later scenery still covers
it even when its reconstructed depth is farther away.

The shader samples the high-resolution image with linear filtering and an
alpha-0.5 cutout. It discards lower-alpha residue and applies the existing
Compatibility colour correction through a float lookup texture. The authored
transparency is a redraw: only bounds, clip and painter ordering are preserved,
not the original per-pixel silhouette. Native-scale mask overlaps of approximately
0.72/0.71/0.61 remain recorded in the art manifest. These are measured differences,
not proof of unchanged tactical readability. Thermal and unknown palettes fall
back; they have not received new authored variants.

## Evidence

* All nine bindings pass source-identity, unknown-palette, rejected-draw,
  nonfinite-position and missing-asset tests. Replaying 261 original render
  passes does not mutate their packets. The selected sequence is exactly
  51 at passes 165 through 167, 52 at 168 through 169 and 53 at 170 through 171, then absent.
* Native Compatibility runs at 4x and 5x cover 12,217,344 rendered pixels. Pixels
  outside each original bound remain unchanged, both painter orders pass,
  left/top and right/bottom clipping pass, unknown palettes match original output
  byte-for-byte, and missing frames clear the effect. Independent CPU bilinear
  sampling checks 27,521 opaque authored colours against GPU output, with a
  maximum difference of one byte per RGB channel. Receipts:
  `artifacts/pc-effect-art-native-02/report.json` and
  `artifacts/pc-effect-art-native-5x-01/report.json`.
* The existing native original-sprite regression still passes all 57,546 exact
  pixel checks: `artifacts/pc-effect-art-original-regression-01.log`.
* Actual Play captures with and without the new art stop at original sequence
  712, source bitmap 52. Capture metadata differs only in `effect_art`; the
  original framebuffer is identical. There are 552 changed presentation pixels,
  all inside the effect's bounds. Of 758,776 UI-owned pixels, four reticle-edge
  pixels differ: the existing fractional-scale sight covers 80% of those pixels
  and blends 20% of the changed scenery. Both old and new RGB values match the
  independently calculated blend exactly. No unexplained UI changes remain.
  Receipt: `artifacts/pc-effect-art-play-01/parity.json`; paired images are in
  that directory and `artifacts/pc-effect-art-play-original-01/`.
* A separate 1,020-frame native Play input replay compares remastered effects
  enabled and disabled. All requests and full bridge-packet hashes match at
  sequences 607 through 1626. Every boundary's full conventional-RAM and packed
  callback-video digests match: 668,467,200 RAM bytes and 261,120,000 video bytes
  per run. Final source frames and capture metadata also match. Receipt:
  `artifacts/pc-effect-art-replay-remastered-01/full-boundary-parity.json`.
  This is bounded source parity, not a whole-emulator-state or all-mission proof.
* Aggregate validation `artifacts/validation-20260928T050146Z` completed with
  terminal exit 0: 37 stages and 255 Python tests passed. The later test-only
  5x option was exercised by the completed native 5x run. No optional Impeccable
  executable was available; no dependency was installed for this Godot work.

The first headless test failed with `source animation sequence changed` because
Godot nested-array equality distinguished parsed float palette channels from
integer constants. Per-channel numeric comparison fixed the false rejection.
The failed output is retained in `artifacts/pc-effect-art-headless-01.log`;
`pc-effect-art-headless-02.log` completed with 648 checks and zero errors.
The final test after adding the native-scale argument completed with 649 checks
and zero errors in `artifacts/pc-effect-art-headless-final.log`.
The first naive UI comparison also failed on the four fractional sight pixels;
the corrected calculation explains them rather than silently excluding them.

## Reproduction

The native and source assets remain in ignored local directories. These tests
require those pinned files; they do not download or redistribute the originals.

```sh
python3 -m unittest tests.test_genesis_effects -v
./tools/godot.sh --headless --quit-after 1200 \
  --script res://tests/test_pc_effect_art.gd
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_effect_art.gd -- --native --native-scale 5 \
  --output "$PWD/artifacts/pc-effect-art-native-NEW"
./Play.command --trace --capture --capture-effect 52 \
  --window-size 1280x960 --frame-audit \
  --output "$PWD/artifacts/pc-effect-art-play-NEW"
# Repeat the capture with --original-effects for the source-art comparison.
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner --interactive-clock \
  --replay-controls --frame-audit \
  --output "$PWD/artifacts/pc-effect-art-replay-NEW"
# Repeat that replay with --original-effects; compare requests/sample_hashes.
./tools/validate.sh
```

The effect capture route supports bitmap 51, 52 or 53 and uses ordinary original
input pulses from `godot/tests/fixtures/pc_effect_steps.json`, followed by up to
300 single-frame observations. It fails if the requested original effect never
appears. It does not synthesize a phase or add a player control.

The other 55 bitmaps, palette/damage overlays, broader animation families,
full runtime visibility coverage and human art acceptance remain open. The
original executable, emulator and source reference files are unchanged. No
push, release, publication or redistribution is part of this checkpoint.
