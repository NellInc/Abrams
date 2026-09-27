# PC cockpit art preparation

## Native sources

`tools/extract_pc_ui.py` extends the existing PC resource/bitmap decoders.
It exports seven 320x200 packed-nibble plates directly from `FRAME`, `DRIVER.BIN`,
`AA.BIN`, `TC.BIN`, `GPS.BIN`, `STATUS.BIN` and `IDENTIFY`, plus all seven
`STRUTS.BMP` images. These are source samples, not crops of gameplay recordings.

Canonical local extraction: `local-art/pc-ui-v2/manifest.json`. The preceding
exploratory `pc-ui-v1` is preserved because it supplied the generated studies.
The observed palette is tied to the first render RAM hash in
`artifacts/pc-ui-controls-02/report.json`.

All 16,024 strut pixels and preservation-mask bits equal the original EGA
descriptors reached through `DS:798e`. The seven plates have structural format
evidence and visual agreement with their corresponding interface components.
The original extraction receipt predates the independent packed-driver and live
loader checks below; it is preserved unchanged rather than retrospectively
rewritten. Live loader coverage now includes all four station plates and STATUS.
FRAME and IDENTIFY have isolated packed-driver proof only.

```sh
python3 tools/extract_pc_ui.py \
  --capture artifacts/pc-ui-controls-02/first-render.bin \
  --trace artifacts/pc-ui-controls-02/report.json \
  --output local-art/pc-ui-new
python3 -m unittest tests.test_pc_ui_assets tests.test_pc_bitmaps -v
```

The focused seven-test run passes in `artifacts/pc-ui-assets-tests-01.log`.
The tool's full source/RAM verification passes in
`artifacts/pc-ui-assets-extraction-01.log`. Source files remain unchanged.

## High-resolution material studies

The built-in image-generation editor produced two local 1586x992 RGBA studies:

* `local-art/pc-ui-remastered/gunner-plate-v1.png`
* `local-art/pc-ui-remastered/gunner-plate-v2.png`

Inputs were the extracted PC `GPS.BIN` plate, an original PC frame identifying
the viewport, and the already-extracted Genesis gunner graphic as style reference.
The PC remains authoritative for camera, controls, information and layout.
Only those selected image references were submitted, never the ROM, executable
or other workspace data. Exact prompts are in `prompts.json`; measured sizes,
hashes and alpha bounds are in `manifest.json` alongside the studies.

The treatment retains the source's steel panels, blue padding, ammo pictograms
and restrained coloured instruments. Changing values, heading graphics and
world content are absent so they can remain live original data. These images
were generated and reviewed by the same assistant.

At the study stage neither image was installed in the tandem runtime. The first aperture was too
wide. The targeted revision corrected its horizontal position but made it too
short. Mapped into source coordinates, the second alpha bounds are approximately
`[32.28,19.96,287.72,93.55]`; the original camera rectangle is
`[32,13,287,109]` inclusive. Visual appeal is insufficient to waive that mismatch.

After two geometry failures, further equivalent prompting stopped. The next
integration step needs renderer-owned exact aperture and instrument geometry,
with generated imagery supplying materials inside that layout. Static artwork
also needs separation from original dynamic UI writes, so text, erasure regions,
damage and modal overlays cannot be hidden by a new plate.

Working if: high-resolution material/detail changes leave the original visible
camera region and every live instrument value intact, with original-frame
fallback whenever station or UI attribution is unavailable.

All extracts and derivatives remain local, ignored by Git and excluded from
normal exports. No redistribution rights or publication are established.

## Original packed-plate proof

`tools/pc_plate_oracle.py` executes the loaded `DS:35f0` driver, resolving to
`load+1388:2217`, and its `2206` helper in Unicorn 2.1.4. The complete observed
code span also matches original `SIM.EXE` bytes at file offset `15c86`.
No instruction is replaced. A bounded VGA mode-0 observer records all four planes;
interrupts and unsupported operations fail closed. Execution stops after the
epilogue, immediately before RETF, as in the earlier bitmap oracle.

`artifacts/pc-plate-oracle-01.json` passes all seven extracted plates across both
EGA pages and 1-, 20- and 200-row chunks: 42 cases, 2,688,000 rendered pixels and
11,010,048 planar bytes including untouched memory. Non-canonical source pointers,
saved registers, stack and restored VGA mode/plane mask are checked separately.
This isolated test does not execute file I/O.

The live core now observes `0f8d:1170` (filename), `123a` (actual decoded buffer
and driver arguments), and the success/failure returns `1226`/`1238`. Events
20 through 23 are bounded host copies. `pc_plate_trace.py` compares each buffer
against a fixed local source catalog, checks contiguous rows and constant page,
and issues a receipt only after a complete successful load. Unknown filenames
never become host paths or verified assets. Partial snapshot attachments remain
unattributed. Receipt history is bounded.

`pc-plate-controls-01` verifies all four stations, and `pc-plate-modal-02` adds
STATUS.BIN through the original D damage-screen command. Each successful plate
arrives as ten exact 3,200-byte chunks. The first modal probe ended during the
return-to-gunner drawing work; the second adds neutral frames and captures its
completed plate. No original menu or station logic is reimplemented.

## Surviving-plate provenance

The separate `abrams_plate_ownership.h` stores the original plate ID, source byte
coordinate and qualifying bits for each EGA planar byte. It begins empty.
Initially, only observed, content-checked original packed-driver writes assigned
plate IDs. The source-verified strut extension below adds completed bitmap writes.
Direct instrument writes clear them even when the new colour is identical or
black. Latch copies, masks, raster operations and transparent bitmap preservation
carry or conservatively discard provenance. XOR changes discard the changed bit.
Conflicting old-origin bits are dropped while incoming known bits are retained
(the first implementation dropped both, corrected below). Copies to another coordinate never qualify as art at
the destination coordinate. Every visible pixel requires all four plane bits to
agree. This mask deliberately makes no completeness claim.

Event 24 follows the original scanlines and completed triple-buffer slot, beside
the original UI mask. The host rejects non-UI claims, invalid IDs and slot changes.
It exposes `presentation.plate_overlay` as optional metadata; older consumers and
the default source-cockpit view remain compatible.

* `pc-plate-bit-oracle-02.json`: compiled C++ against an independent per-bit model,
  4,096 operations, 131,072 checked plane bits and 14 explicit ID/page cases.
* `pc-plate-pixels-02.json`: all 482,370 attributed pixels across 30 captured
  samples equal the original source plate at the exact source coordinate and
  observed palette, including station changes, bitmap effects and the damage screen.
* `pc-plate-ownership-comparison-02.json`: all 1,533 full-RAM, framebuffer and
  input records, plus stage states, equal the unmodified source baseline.
* `pc-plate-lifecycle-03/report.json`: all 7,267 shared-neutral-boot RAM/video/input
  records, 52 stage states and original program boundaries equal the unmodified
  baseline across quit, debrief, menus and reentry. Both SIM epochs are retained.

That milestone's core was `890f45a517b0e88b52278e24087ff236333c27f1f2684957cc3d386f7effec19`;
its trace header is `066aafc1430979a04770b3e2666b9f0a1fcceb127e408be9d94d6e7152efae31`.
The plate header is `5996b49c83e12819e28f3e0ed339d84ab4c537a24010f9868ab2d542db227922`.
The build receipt is `artifacts/pc-plate-core-build-03.log`; the unmodified baseline
pin and original VGA ownership header remain unchanged.

### Original dissolve copy and first-entry regression

The first actual cold-boot viewer (`pc-gunner-material-viewer-01`) correctly
fell back to original materials. Its CPU-assembled dissolve erased our initial
plate provenance. The original dispatch `0f8d:1a7c`, through `DS:3604`, resolves
to `load+1388:1ff3`. That code reads each source plane, assembles a colour in the
CPU, refreshes the destination latch, then writes one mode-2 pixel. The observer
now carries the source's qualifying bits through that specific, bounded path.
It does not infer provenance from matching colours or alter the transition.

`pc_dissolve_oracle.py` independently executes the unchanged driver in both page
directions. The first attempt did not reach the return within its initial bound;
the longer bounded run then disproved the assumed complete-page copy. A diagnostic
found exactly four mismatched plane bytes and 63,999 pixel writes. Disassembly
confirms that returning to LFSR seed `f9ff` ends the loop before drawing the seed.
Because its low bits select mask `80`, **physical pixel (312,199) remains from the
destination page**. The original quirk is preserved. The corrected expectation
passes all 128,000 output pixels and 524,288 plane bytes, including untouched
memory, in `pc-dissolve-oracle-04.json`. Earlier failing logs are retained.

`pc-gunner-material-viewer-02` now cold-boots through the real Godot pipe and
displays the new materials on first mission entry, with clean exit. Its 26-sample
receipt confirms both world and gunner-material composition. The captured
33,620 plate-provenance pixels independently match the original source in
`plate-pixel-proof.json`. The final side-by-side capture was visually inspected.

## Local material pilot

`./PC\ Bridge.command --gunner-art` loads the preserved `gunner-plate-v2.png`
study locally. It replaces only surviving GPS.BIN material pixels above source
row 123, outside the original camera rectangle. The lower instrument panel is
entirely original. Original writes retain the reticle, bearing scale, values,
messages and modal overlays. The image's incorrect aperture does not define the
sight opening. Palette changes, absent/malformed provenance, unsupported source
fingerprints or missing local art disable the pilot. It is opt-in, with the
default source-resolution interface retained for comparison.

The first native pilot test correctly failed because no real fixture enabled the
art. Godot JSON parses numbers as floats and nested array equality distinguished
the recorded palette from the identical integer constant. Component-wise numeric
validation fixes that gate without accepting changed colours. The failing capture
and diagnostic are retained as `pc-plate-art-native-01` and `pc-plate-art-probe.gd`.
Synthetic tests now round-trip through the JSON wire representation.
The final native run, `artifacts/pc-plate-art-native-03`, passes 2,771,432 exact
RGB checks and changes 172,484 source-pixel samples across the captured gunner
frames. Synthetic testing covers every 1280x800 output pixel, including genuine
sub-source-pixel detail, alpha holes, other plate IDs and the original aperture.
Recorded tests check every protected source-pixel centre. The gunner and damage
captures were visually inspected: the new surround is visible, while the lower
instruments and complete damage screen remain original. The transition between
new materials and the old lower panel is visibly unfinished, as expected for this
restricted pilot.
The complete 17-stage local gate passes in
`artifacts/validation-20260927T093036Z/results.txt`, including 137 Python tests,
unchanged original files, Godot parsing/runtime, simulation and audio gates.
No optional Impeccable linter is configured for this GDScript project; none was installed.

Working if: high-resolution material detail appears only in proven gunner plate
pixels, every protected original pixel matches its paired frame, and unsupported
states show original materials rather than a stale or inferred station.

That gunner-only milestone left fonts, instrument graphics, the other stations
and world-asset replacement open. The following pass extends station materials;
full instrument and world-asset restoration still remain.
The author both implemented and reviewed this work; native rendering and original
replay checks are separate evidence from visual judgment.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_plate_oracle.py \
  --capture artifacts/pc-ui-controls-02/first-render.bin \
  --output artifacts/pc-plate-oracle-new.json
python3 tools/capture_pc_render_trace.py --mode trace --profile plates \
  --capture-ui --capture-sprites \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-plate-capture-new
python3 tools/verify_pc_plate_overlay.py \
  --report artifacts/pc-plate-capture-new/report.json \
  --output artifacts/pc-plate-pixels-new.json
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_plate_art.gd -- \
  --native --fixture "$PWD/artifacts/pc-plate-capture-new/report.json" \
  --art "$PWD/local-art/pc-ui-remastered/gunner-plate-v2.png" \
  --output "$PWD/artifacts/pc-plate-art-native-new"
```

## Four-station material pass and verified struts, 2026-09-27

`./PC\ Bridge.command --cockpit-art` includes the existing gunner donor and three
new built-in imagegen outputs under `local-art/pc-ui-remastered/cockpit-set-v1/`:

| Donor | Pixels | SHA-256 |
| --- | --- | --- |
| `commander-plate-v1.png` | 1586x992 | `aae126a4360e182b958032421dc8ba23580e7b606cff7a19d2156c74529b2730` |
| `driver-plate-v1.png` | 1586x992 | `76fe8726c928f7497a5ea1ad1af9020a024560a5d4d560b55f4a08bf94796f62` |
| `cupola-plate-v1.png` | 1585x992 | `ece03c2b9e098d9eafc4f21950dc7902a0a2b37f0dd82e621091fc1da7775e1e` |

Each prompt used its extracted PC plate, corresponding Genesis station image
for style/context, and the prior gunner study for visual consistency. Only these
selected image references were sent to the built-in editor. Full prompts,
reference hashes and output hashes accompany the assets in `prompts.json` and
`manifest.json`. No binary, ROM, proprietary code or recorded gameplay was sent.
The same assistant generated, integrated and visually reviewed the artwork.
Human art approval remains open.

### Original geometry and information

Material selection follows actual per-pixel source IDs, including mixed station
transitions. It never uses an F-key request or a decoded station name as proof of
what is on screen. Exact PC plate fingerprints and the observed palette are
required. Missing images, unsupported fingerprints and malformed provenance
retain the original; STATUS and unsupported plates receive no new station art.

Original UI and source-coordinate masks determine every edge, aperture and world
occlusion. Piecewise vertical donor UV anchors align driver/cupola features with
those masks; they cannot move the original camera or enlarge a visible region.
Original text, instrument writes, erasures and modal overlays revoke static art
provenance. Additional protected rectangles retain baked semantic details:

* Commander: left map `[15,62,161,160]`, lower-left instruments
  `[0,166,170,200]`, entire right instrument panel `[190,66,305,195]`.
* Driver: instrument strip `[53,187,267,200]`.
* Gunner: the earlier outside-camera, above-row-123 restriction is unchanged.

Coordinates are half-open source-pixel bounds. The generated commander donor's
small status markings remain behind the protected original panel. Original
numerals, gauges and selected flat/dithered fragments remain visibly low resolution.
The pass restores materials; it does not finish instruments, typography or every
procedural trim. The default viewer still provides original-cockpit comparison.

Working if: artwork appears only on attributed original source pixels, all
protected pixels match the paired original frame, and changing station or opening
a modal never leaves a stale material over original information or scenery.

### Two real attribution defects resolved

The first native integration was patchy. An observer merge discarded both old
and incoming origins on conflict. During plate A-to-B loads, this permanently
lost the first newly written B plane. The correction retains only the incoming
explicitly known bits, discards conflicting old bits, and still requires all
four planes at the same original coordinate before any visible pixel qualifies.
The independent per-bit oracle passes, including five new plate-transition cases.

Original STRUTS bitmap redraws also cleared static plate attribution. Native
events 29/30 now bracket only an actually dispatched member of original DS:798e's
seven-entry table. `pc_strut_trace.py` verifies the loaded descriptor, dimensions,
all bitmap pixels and transparency against the original STRUTS resource. Its
actual placement must match exactly one original plate at every opaque source
pixel, including pixels outside the current clip. A completed-driver callback
then independently checks every eligible pixel's final EGA colour.

Only after those checks can an 8,000-byte opaque-bit mask update host provenance.
The native claim is callable only during that completion callback, on its exact
page, and only for already established UI pixels. Plane memory is read directly
without changing guest VGA latches. No guest memory, registers, instructions or
timers are written. Unmapped, ambiguous or unsupported placements stay original.
This attribution starts from the executed source bitmap; matching screenshot
colours alone never establishes ownership.

### Verification receipts

* `pc-cockpit-comparison-03.json`: all 2,214 RAM/video/input frames and 21 stage
  states equal `pc-cockpit-baseline-02`. All four station plates and STATUS occur.
  Of 620 strut draws, 414 verify 551,098 opaque pixel instances; 136 unmapped and
  70 unsupported-layout draws receive no claim.
* `pc-cockpit-pixel-proof-03.json`: all 641,384 attributed pixels across the 21
  captured frames equal the original plate at the original coordinate.
* `pc-cockpit-bit-oracle-02.json`: 4,096 operations, 131,072 plane bits,
  12,025 nonzero claims and 20 explicit page/plate/bitmap cases pass.
* `pc-cockpit-art-native-04/report.json`: 2,102,889 checks, zero errors. The native
  synthetic gate checks every 1280x800 output pixel, sub-source-pixel detail,
  transparency, original scenery and instrument protection. Real paired fixtures
  check every protected source-pixel centre across station/damage transitions.
* `pc-cockpit-gunner-native-01/report.json`: existing gunner regression passes
  2,309,888 exact RGB checks with 58,084 changed source samples and zero errors.
* `pc-cockpit-lifecycle-01/report.json`: all eleven checks pass, including 7,267
  matching RAM/video/input frames, 52 stage states, program boundaries and reentry.
* `validation-20260927T120418Z/results.txt`: all nineteen local stages pass,
  including 188 Python tests and 150 Godot audio assertions.
* Live viewer `pc-cockpit-viewer-commander-01` cold-boots the original menus and
  mission, ending at commander with plate ID 2. The driver/cupola snapshot viewers
  end at the corresponding original stations and IDs 4/3. All compose the world,
  exit cleanly, and have visually inspected side-by-side PNGs.

The first cockpit route incorrectly requested D from gunner, so it never reached
STATUS. It was repaired to return to commander first; the failed receipt remains.
The first full gate also correctly flagged its old expectation of 14 explicit
oracle cases after six cases were added. Updating that count to 20 leaves all
actual assertions intact. Failed logs and the patchy first native capture remain.

These are bounded observation and presentation checks. The mission snapshot does
not establish filesystem-dependent debrief outcomes; the separate neutral-START
lifecycle route covers bounded quit/reentry. Full mission/campaign coverage,
physical-time pacing, final visual approval, source/licensing and release remain
open. No optional Impeccable linter is configured or installed.

### First four-station build pins (superseded below)

* Core: `6586d7351ee9d77dc3b3a3c9a562f13f532118608ce5c08732a93d69fd8613c0`
* Trace header: `2f2b8d6daa5a2c4944730cb6ff8dc534e9f09656023a6276eed514e178e037bb`
* Plate header: `486b9e5f21fd587c0ce47d17ae072fbc8860d36e29bc5f29ff926e1895453e76`
* Untouched baseline: `57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`

The live host requires `strut_event_schema: 1` from the local build manifest.
Original VGA ownership and upstream source pins remain unchanged. Earlier pins
above identify historical receipts. The following correction supersedes this build.

```sh
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode trace --profile cockpit \
  --capture-ui --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-cockpit-new
python3 tools/verify_pc_plate_overlay.py \
  --report artifacts/pc-cockpit-new/report.json \
  --output artifacts/pc-cockpit-pixel-proof-new.json
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_cockpit_art.gd -- \
  --native --fixture "$PWD/artifacts/pc-cockpit-new/report.json" \
  --art-dir "$PWD/local-art/pc-ui-remastered/cockpit-set-v1" \
  --output "$PWD/artifacts/pc-cockpit-native-new"
./PC\ Bridge.command --cockpit-art --audio
```

## Alignment and Genesis colour correction after user review

Nell correctly identified the first pass's EGA-looking world and inconsistent
gunner/driver overlays. The earlier original-world colour fidelity gate verified
the diagnostic renderer; it did not establish finished remastered scenery.

### Driver assembly: original moving geometry

The driver's overhead gun assembly is redrawn procedurally and moves horizontally
with the turret. It cannot be restored coherently through a stationary plate mask.
The original main-CS routine `5b98..5da6` contains two lower strut draws followed
by the turret-relative overhead assembly. `pc-driver-assembly-code-proof-02.json`
checks all 527 loaded bytes against the unpacked executable with its ten actual
DOS segment relocations applied. The first raw-file substring attempt failed
because packed/relocated loaded code is not an unrelocated byte substring.

The observer marks only actual original VGA writes during `5ba1..5da3`: the
two lower struts, assembly bitmap, its upper rectangle, two roof polygons and
four boundary lines. Lower struts carry zero offset; the moving overhead pieces
adopt the original computed offset at `5c50`.
Its horizontal offset is read from the original computed centre at SS:BP-2.
A separate provenance domain retains that signed offset alongside each byte's
qualifying plane bits. Conflicting offsets discard old bits, and all four planes
must agree. The existing transparent-bitmap preservation rules still apply.
Scanline sampling exports a separate RGB mask: low/high offset bytes and a 255
ownership flag. Unclaimed pixels have three zero bytes. This remains independent
of source-plate IDs, which still mean exact source-coordinate plate provenance.

The host pairs this mask with the completed original framebuffer slot, requires
original UI ownership, and fingerprints the original SIM. Godot repeats those
checks before sampling the existing driver donor at its original moving offset.
No decoded current station, guessed screenshot colour or current input is used
to position this layer. Missing or invalid metadata disables it. Original view
occlusion, instruments, timing, guest memory and executable instructions remain
unchanged. Working if: driver material moves with the original assembly, both
turn directions and A realignment follow the original, and no world/UI pixel
outside the original assembly's writes changes.

### Gunner fit and actual Genesis sources

Gunner donor Y anchors now map the generated aperture `[20,94]` onto the original
PC sight rows `[13,110]`, while retaining the exact original visibility mask and
row-123 instrument boundary. Explicit nearest-texel centres resolve a native
CPU/GPU rounding disagreement found by the high-resolution synthetic test.
The earlier failed native receipt remains `pc-gunner-alignment-native-02`.

`pc_genesis_style.gd` reads the actual ignored Genesis CRAM extraction at
`reference/genesis/extracted/gunner/palette.gpl`, verified by SHA-256
`aabb29495777c4cd15b2a7f0c7ca89d67e4a2fda70b6bb0d2411c0c8b5206169`.
The visual mapping uses bank-3 swatches, including its dark road and turquoise
sky. This mapping is an authored presentation choice, not a recovered Genesis
gameplay rule. It changes only the Godot world material lookup; original PC
palette data, draw commands, shapes, painter order and cockpit information stay
untouched. Unknown original palettes or missing/mismatched extraction files
retain PC colours. The native swatch check verifies RGB (32,32,32) for the road
and unchanged geometry. Genesis itself has flat-shaded scenery in these source
frames. This colour pass does not provide new high-resolution terrain or vehicles.

The bridge now defaults to the four-station material/Genesis-colour pass.
`--original-art` restores the PC diagnostic; `--pc-colours` retains cockpit art
with PC world colours. Wireframe and the explicitly selected gunner-only pilot
remain available. Original menus and unimplemented graphics continue to use their
original frames. No asset is added to distribution or uploaded by this correction.

### Revised native observer pins

* Core at this cockpit milestone: `f7452d08d9fb1bdf3f7cf73ddc1870bbe8c62192b01c8251d38a0e90a990baa3`
* Trace header: `b7e1ef36182ae8f9928e3eefa218bede5012553abc49cacb5d94f0fb8401e006`
* Plate header: `3720a03996d3e22c6c756365da122e11d9d72c2fbfd35c7a09c25e6b465da00e`

The host requires `driver_overlay_schema: 1`. The baseline remains unchanged.
The independent ownership oracle now covers 23 explicit cases, including three
signed-offset changes in the moving-assembly domain. The first driver route
turned the hull and kept the roof centred; the corrected route explicitly uses
C for turret control. Its receipt covers original offsets 0, ±3 and ±6 pixels.
Larger synthetic offsets are tested separately; complete turret-motion coverage
and complete visual restoration remain open.


### Final revised verification

* `pc-driver-assembly-proof-03.json`, produced by the reproducible
  `tools/verify_pc_driver_overlay.py`: 1,257 matching original RAM/video/input
  frames, 19 matching stage states, 527 matching relocated routine bytes and
  218,484 assembly pixel instances within the original drawing bounds and UI mask.
* `pc-cockpit-comparison-05.json`: all 2,214 frame records and 21 station/damage
  states equal the untouched source baseline with the final observer.
* `pc-cockpit-pixel-proof-05.json`: all 625,322 attributed static plate pixel
  instances equal the original source at the original coordinate.
* `pc-driver-assembly-native-03/report.json`: 4,813,947 native compositor checks
  pass across the moving-driver route. `pc-cockpit-art-native-06/report.json`
  passes 5,144,109 checks across station changes and the STATUS modal. Both
  reports have zero failures and include protected original-pixel checks.
* `pc-driver-assembly-lifecycle-02/report.json`: all eleven checks pass, including
  7,267 matching frames, 52 stage states and original program/reentry boundaries.
* `pc-gunner-alignment-native-03/report.json`: 2,309,888 exact RGB checks pass,
  including the corrected donor-row quantization and all protected original pixels.
* `pc-genesis-style-native-02.log`: actual native Genesis road swatch, unchanged
  geometry and source-data immutability pass. The first test fixture lacked two
  required camera fields; its engine error was correctly rejected by the full gate.
* `validation-20260927T124323Z/results.txt`: all twenty stages pass, including
  189 Python tests and 150 Godot audio assertions. A prior synthetic-test parse
  error is retained in `pc-driver-assembly-native-01`; the integer annotation
  repair passes before subsequent native runs.
* `pc-default-remaster-viewer-01`: real cold boot now enables the new driver
  material, moving assembly and Genesis colours without a presentation flag.
  `pc-original-art-viewer-01` verifies their explicit diagnostic opt-out.
  `pc-driver-aligned-viewer-02` and `pc-gunner-aligned-viewer-02` are the final
  visually inspected native side-by-side captures. All children exit cleanly.

The driver test checks original offsets in both directions; synthetic offset
checks cover -37, 0 and +51 pixels. All source-image checks remain separate from
human visual acceptance. Lower driver struts now use their own actual original
writes, removing the remaining pixelated material joins in the first correction.
Original instruments, source-resolution silhouette edges and the unfinished
world graphics remain visible and intentional boundaries of this pass.

```sh
python3 tools/capture_pc_render_trace.py --mode trace --profile driver \
  --capture-ui --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-driver-new
python3 tools/capture_pc_render_trace.py --mode baseline --profile driver \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-driver-baseline-new
python3 tools/verify_pc_driver_overlay.py \
  --trace artifacts/pc-driver-new/report.json \
  --baseline artifacts/pc-driver-baseline-new/report.json \
  --output artifacts/pc-driver-proof-new.json
```

The later [live typography pass](pc-text-research.md#scalable-live-typography-2026-09-27)
expands source string observation and adds independently pixel-verified scalable
letters. Its current observer pins and fresh lifecycle comparisons supersede
the core pin for the cockpit milestone above. Plate/driver attribution is
unchanged.
