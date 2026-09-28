# Genesis motor pool in the original PC flow

## Visual authority

The selected background is `local-art/genesis/remastered/motor-pool-v2.png`,
1586 by 992 pixels, SHA-256
`3fb46798b867ca528f96e8bc0a70d6f3a9e7a1016ca87f3e8549562469019c76`.
The built-in image tool redrew the existing Genesis-derived v1 and original
Genesis crop with smooth ink contours and restrained cel shading. Composition,
vehicles, crew, drums and palette remain anchored to those references. No PC
art was given to the generator. Exact prompt and input/output paths are in the
adjacent `motor-pool-v2-prompt.json`; v1 remains available for comparison.

`Play.command` uses the background in the original PC arming flow. The gallery
also uses v2. The PC executable still selects ammunition, toggles the governor,
handles focus/keys and starts the mission. No replacement menu logic was added.

## Read-only binding

The original `ATBASE.BIN` has SHA-256
`7a2b2e763b37623f423c7f332c2a34d4bb810f5a457a3d8f55aec27e9262ac03`.
Its decoded 320 by 200 indices are recognition data, never a visual donor.
Reproduce the local recognition catalog with:

```sh
python3 tools/build_pc_frontend_catalog.py --motor-pool --output local-art/pc-motor-pool-v1
```

Use a fresh output directory; the extractor never overwrites an existing one.
The pinned catalog hash is
`a34ebc4d9a81d48c58c34024845b03c2362555f2d818040578cceeed3e3f5c7e`.

The loader starts before the first safe frame-boundary observer attachment.
At its pinned `0f8d:123a` dispatch, the observer can recover the original
`ATBASE.BIN` filename only from the intact caller frame and `11e6` return site.
At the successful `1226` return, before the caller draws the menu, it reads all
64,000 original indices directly from backing VGA planes without touching guest
latches. The host requires exact equality with the original resource. Only
during that synchronous callback can it establish full-background provenance.
Subsequent writes, including identical-colour UI writes, remove those tags.

Internal tag domain 9 maps to additive transport plate ID 8. Internal domain 8
remains reserved for the driver's moving assembly. All seven previous transport
IDs retain their meanings. The authored tag is now 32-bit, avoiding truncation.

The Godot gate additionally requires SIM, the pinned source/art/catalog,
canonical palette, correctly sized masks, original UI ownership, the claimed
pixel count and exact source RGB at every claimed coordinate. Unknown pixels
remain transparent to the existing compositor. Missing evidence clears stale
art. The menu's irregular outline needs no guessed rectangular cutout.

Working if: later menu writes stay visible, unsupported frames retain their
original content, and every replaced pixel has an exact original-source receipt.

## Scalable arming text

Seven complete source-font runs cover SELECT, ARMING MIX, HEAT/SABOT/AX counts,
GOVERNOR and BEGIN. The original 6X6.FNT bits, foreground/background and original
UI ownership must all match. Digits come from the displayed two-cell numeric
fields. The font shares O/0 and I/1 glyphs, so unrestricted character recognition
is deliberately excluded; a numeric alphabet is used only inside the original
numeric fields. Incorrect/partial glyphs retain their original pixels.

`--original-text` disables these replacements and retains the original clipboard.

The remastered panel displays `GOVERNOR OFF` with a word space. Its ON/OFF
values share a right edge, using the panel's spare character cell without
condensing the original-style glyphs. The exact original label and rectangle
remain attached to the presentation run. This spacing is applied only after
the entire original clipboard has passed its existing verification; original
text mode and original game controls remain unchanged.

## Genesis arming-panel frame

Completed, independently verified clipboard frames now use a scalable dark
panel with the Genesis menu's white rim, grey header and inverted selection.
The exact Genesis source supplies the sampled palette. The PC still owns the
seven text rectangles, values and focus. No new controls or allocation rules
are introduced. The old clip area reveals the registered Genesis background.

`pc_arming_panel_art.gd` first matches every static visible pixel of CLIP.BMP,
every transparent background attribution and all seven complete source-font
runs. Partial drawing, unsupported glyphs or one changed rim pixel retains the
original panel. Pixel (312,199) is sometimes overwritten by the original;
its purpose is untraced, so it is always copied verbatim, never guessed away.

The 88x113 original clipboard sprite is independently verified against 9,944
loaded original EGA pixels and 9,944 preservation bits at physical offset
274592 in `pc-motor-pool-loader-diagnostic-01/boot-21.bin`. The source SHA is
`496e4349840d934c42da24fc929b25869a0db050dd6a66ac68a9349af6b7e6ce`.
Generate the recognition-only catalog using `build_pc_frontend_catalog.py
--arming-panel`; its pinned SHA is
`0189ac8eab74a8bfd9f1d267cebba18cba502df005faf4ae9c28408a5788fb03`.

Working if: original arrow-key allocations and focus remain unchanged, complete
panels use Genesis styling, and unverified drawing retains the real PC pixels.

## Arming-panel evidence

* `pc-genesis-arming-allocations-parity-01.json`: all 7,630 full RAM/video/input
  records, 74 stage states and program boundaries equal the original baseline.
  Ordinary keys increase AX, decrease SABOT, increase HEAT and return to BEGIN.
  Original mission-entry ammunition is COAX 80, HEAT 11, SABOT 5, AX 19.
* `pc-genesis-arming-allocations-plate-proof-01.json`: 1,647,444 attributed
  source pixels verified across 38 captured plate-bearing frames.
* `pc-genesis-arming-allocations-native-01/report.json`: 95,050 checks, zero
  errors, 27 motor-pool samples. Native pixel probes verify the panel palette,
  source-derived focus colours, restored clip background and protected pixels.
  The corresponding headless allocation gate passes 378 checks.
* `pc-genesis-arming-launcher-parity-01.json`: actual Play capture retains the
  original-art comparator's exact source PNG, state, program, presentation and
  sample count. The remastered capture contains the Genesis panel and all seven
  text runs. The displayed image and selected allocation images were inspected.
* `validation-20260927T194023Z`: all 26 stages pass, including 208 Python tests
  and original-file preservation. The separate native office regression passes
  8,148,962 checks, zero errors, after adding the shared frontend child.

The initial headless/native panel runs each failed two synthetic assertions:
the test changed a background pixel without removing its ATBASE tag. The fixed
test models an actual later UI write by clearing its tag and updating the count.
Those failed receipts remain; only the subsequent runs above are green gates.
This implementation and its visual review are by the same assistant. The
optional Impeccable tool is unavailable; no dependency was installed.
Other menu/settings transitions and the whole graphics programme remain open.

## Evidence

* `pc-motor-pool-trace-03/report.json`: 7,267 full RAM/video/input records and
  52 stages identical to `pc-motor-pool-baseline-01`, from a shared neutral
  original START snapshot. Program boundaries and stage states match, including
  original mission exit, debrief, reentry and second mission.
* Both lifecycle epochs contain exact complete ATBASE readbacks. Five sampled
  motor-pool frames retain 62,855 or 55,427 proven background pixels as the
  clipboard appears. `pc-motor-pool-plate-proof-03.json` checks 428,072 attributed
  pixels across all 16 captured plate-bearing stages.
* `pc-motor-pool-native-01/report.json`: 581,353 checks, zero errors. Every
  protected output pixel remains original; independent bilinear probes confirm
  the selected Genesis donor. Includes partial clipboard and reentry.
* `pc-motor-pool-native-02/report.json`: 431,597 checks, zero errors, with
  scalable text enabled and all pixels outside verified text/art regions retained.
* `pc-motor-pool-controls-baseline-01/report.json`: a second, 7,366-frame,
  58-stage route matches the trace after normal arrow-key selection, governor
  toggle and return to BEGIN. `pc-motor-pool-controls-native-01/report.json`
  passes 1,046,842 checks, including selected/unselected governor ON/OFF and BEGIN.
* `pc-genesis-motor-pool-live-01`: actual launcher capture, 55,427 restored source
  pixels and seven verified text runs. The `--original-art` comparator has
  identical terminal state, program, presentation, sample count and source PNG.
* `pc-motor-pool-driver-proof-01.json`: unchanged 1,257-frame driver route,
  527 original routine bytes and 218,484 moving-assembly pixels, preserving
  centred and both-direction offsets. `pc-motor-pool-old-plate-compatibility-01`
  verifies the earlier seven-ID report remains readable.
* `validation-20260927T191709Z`: all 26 source/test stages completed successfully,
  including 207 Python tests, frontend gates, original-file preservation and
  audio/runtime checks. Native image tests above are separate from headless tests.
* Final focused checks after the no-background fast path: 158 motor-pool and
  109 office checks pass. Native office regression passes 6,825,954 checks;
  native cockpit/status regression passes 12,371,690 checks. The optional
  Impeccable command is absent locally; no dependency was installed. Native
  Godot rendering and source-pixel checks supply the applicable visual evidence.

Artifact paths above are under `artifacts/`. They establish bounded observer and
presentation parity, not every mission or finished-remaster equivalence.
The selected trace core is
`a786e388386fe50b42c2ec21393e3ba42d7fa1b59232a016a3811292af2bb090`;
unmodified source baseline is
`57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.

Capture the real launcher flow locally:

```sh
./Play.command --capture --capture-motor-pool --output "$PWD/artifacts/pool-review"
```

Original files, derivatives and runtime captures remain ignored/local.
No community upload, redistribution licence or publication is implied.
