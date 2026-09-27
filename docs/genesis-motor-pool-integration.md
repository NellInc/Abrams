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

`--original-text` disables these replacements. Clipboard border and clip
contours are still source-resolution, and remain open in the whole-graphics
register. This milestone does not complete every motor-pool state or all UI art.

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
