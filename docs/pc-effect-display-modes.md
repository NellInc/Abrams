# Source-verified effect display modes

## Finding

The recorded normal, thermal-on, thermal-off and STATUS damage contexts all use
**the same 16 RGB palette entries**. Treating thermal as an unknown palette was
an incorrect documentation assumption. The existing exact-palette effect gate
already accepts these modes. No greyscale effect shader is justified by the
original source, so none is introduced.

| Captured context | Frame / draw sequence | Original background indices | Reticle | UI ownership |
|---|---|---|---|---|
| Selected gunner, normal | 395 / 98 | 5, 8 | Black (0) | Partial |
| Thermal enabled | 674 / 165 | 0, 3 | White (1) | Partial |
| Thermal disabled | 767 / 188 | 5, 8 | Black (0) | Partial |
| STATUS damage screen | 1727 / 374 | Previous paired world | Hidden | All 64,000 pixels |

The first three are from
`artifacts/finish-20260928/target-live-trace-02/report.json`.
The STATUS frame is from `artifacts/pc-cockpit-trace-05/report.json`; it has
57,627 verified STATUS.BIN plate pixels, so the conclusion does not rely on a
stage name. Source images, masks and reports are hashed by
`tools/audit_pc_effect_modes.py`. Presentation palette and draw palette must
agree exactly. A different palette or ownership claim fails the audit.

## Original source

Authority is the pinned local `GAME/SIM.EXE`, SHA256
`9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099`.
The audited load-relative code spans are:

* `0b4d:28d0..28e4`: a bitmap shape command selects its second byte and calls
  the original bitmap projection routine.
* `0b4d:437c..4401`: original near rejection and integer projection, then direct
  dispatch of that same bitmap index to `0000:8b08`.
* `0000:8b08..8b56`: loaded bitmap descriptor, half-size registration, clip flag
  and the original EGA bitmap wrapper at `0f8d:0347`.

These paths contain no thermal greyscale conversion. The existing loaded-source
pixel/mask identity gates still apply in every mode, and unknown descriptors or
changed source content retain original rendering. Original bitmap-blitter
pixel evidence is documented in `pc-sprites-research.md`.

`pc_colour.gd` compensates the native Compatibility renderer's RGB transfer
curve. It is a display correction, not a thermal or damage-color rule. Using it
to invent one would change source behavior. Thermal instead submits different
world color/material indices; the captured sky/ground transition above proves
that distinction for these frames.

## Acceptance evidence

`godot/tests/test_pc_effect_modes.gd` constructs explicit isolated bitmap
fixtures in the captured contexts. It does not claim those 64 effects occurred
in the live capture. All bindings pass the exact source/known-palette gate.
Native rendering compares authored colors and cutout transparency against the
actual captured normal/thermal backgrounds. Source packet values remain
unchanged, effect pixels stay within original bounds, and returning from thermal
uses the same known-palette binding.

A separate native compositor fixture puts an active authored effect behind the
actual STATUS ownership mask. Every output pixel must equal the recorded
STATUS screen. This prevents a supposed damage-mode remaster from exposing a
world effect through a full-screen original interface.

Receipts under `artifacts/finish-20260928/`:

* `effect-mode-fixtures.json`: four hashed source contexts and source-code spans.
* `effects-modes-headless/report.json`: 271 checks, zero errors.
* `effects-modes-native/report.json`: 19,930,986 checks, zero errors;
  19,326,976 rendered pixels and 301,890 independent color/cutout samples,
  maximum RGB error one byte. Includes 256,000 exact STATUS compositor pixels.
* `effects-modes-python.log`: five source-mode and inventory tests pass.

The implementing assistant authored these tests and reviewed their images;
this is self-review. No new live thermal effect occurrence or all-campaign timing
proof is claimed. Unknown RGB palette families retain source rendering. No
unsupported family is labelled a known mode merely because it resembles one.

Working if: these four source contexts retain their original palette semantics,
thermal fixtures keep verified authored colors, STATUS hides the complete world,
and arbitrary changed palettes still fall back.
