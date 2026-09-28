# Genesis-style high-resolution hills

## Presentation change

The default tandem view now resolves enlarged hillside checkerboards into their
continuous source colour, with restrained, authored surface detail. This covers
81 filled faces across PC shapes 2 through 33 and 55 through 71. The later
plateau extension is documented below. The original facets, silhouette,
triangle order, visibility, source material identities and gameplay remain under
the original executable's control. No new rocks, vegetation, lighting, collision
or geometry are introduced.

The implementing assistant generated, integrated and visually reviewed this
work. This is self-review; Nell's visual/motion acceptance remains open.

## Genesis visual evidence, PC geometry authority

Original Genesis captures are retained in `reference/genesis/terrain-turn-02/`.
From the preserved gunner snapshot, the sequence holds right for 160 frames,
then another five groups of 20 frames. The original bearing reads 042, 059, 078
and 101 at four inspected intermediate viewpoints. No guest-memory edits were
used to position the camera.

The frame at 220 reconstructs exactly from the captured VDP state: all 71,680
pixels match. Three hillside interior probes contain precisely equal numbers
of Genesis RGB (172,170,0) and (0,0,0). Their arithmetic RGB mean is (86,85,0).
This verifies the visible olive/black source pattern rather than inferring its
colour from the remastered PC screenshot. Evidence:

* `local-art/genesis/source/terrain-turn-02-220/extraction.json`
* `artifacts/pc-hill-art-01/genesis-face-colours.json`
* `tests/test_pc_hill_art.py`, complete VDP reconstruction and palette probes

PC `SHAPE.TBL` hash
`81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193`
pins the gameplay-owned geometry. Its parser independently verifies all 32
roots, 49 primitive/material pairs and the source vectors. Each selected face
uses material 17, 19, 26 or 28. Seventeen faces are vertical: source-vector cross
products verify whether each needs the world XZ or YZ texture plane. Other faces
use XY. The plane choice is fixed by source identity, so camera movement cannot
flip the texture projection. Raw coordinate units are not claimed to be metres.

Direct byte searches did not establish the Genesis vector-resource format.
No claim is made that Genesis and PC geometry is byte-identical; Genesis supplies
the observed presentation reference and the PC remains authoritative for shape,
placement and visibility. Source geometry receipts are retained in
`artifacts/pc-hill-art-01/source-faces.json`.

## Authored material and renderer

The built-in image tool received the selected original Genesis screen as a
hillside style reference. The prompt asks for restrained, low-contrast dry turf
and fine earth, without objects, relief shadows or a horizon. Only this selected
image was submitted, not the ROM, executable or workspace.

The returned image is 1254 by 1254, despite the prompt's requested 2048 square.
It is saved unchanged as `local-art/genesis/remastered/terrain-v1/hill.png`, SHA-256
`116177af6cbf7bed7ed484a9cc44267e239e6dfcba90d99ec41cf8895260d123`.
The exact prompt and source/output provenance sit beside it in `prompt.txt`
and `manifest.json`. The original tool output is retained separately.

The shader uses only the red channel as neutral detail. Measured mean is
118.11901436932915/255, so minor generated colour casts cannot tint the world.
The requested seamless pattern has measured opposite-edge mean differences of
8.216 and 7.609 bytes, not exact pixel-periodic edges. Filtered mipmapped repetition
and the low colour modulation were visually reviewed; mathematical seamlessness
is not claimed. The original generated pixels were not painted over.

For selected faces, the renderer averages the four source material-pattern
swatches from the chosen presentation palette. It then applies the existing
33-level, 0.75 through 1.25 detail ramp and Compatibility colour correction.
The neutral level is the rounded source RGB mean. Unselected surfaces retain
their original dither and exact neutral lookup. The lookup is cached by the
observed palette/materials and level count.

Texture coordinates derive from the original camera matrix and continuous world
position. The tile repeats every 768 raw units, with detail fading between 8192
and 32768 units. These are authored presentation settings, not gameplay rules.
Seventeen vertical faces use height in their coordinates to avoid streaking a
horizontal projection up a cliff. No effect sprite or dynamic actor qualifies.

Selection requires matching shape, root, primitive, fill and material identities,
static allocation, known ordinary palette and usable original camera. Both the
shape resource and authored image hashes are checked. Missing or unknown inputs
retain the preceding renderer. `--original-hills` keeps the old hill treatment
while retaining other remastered components; `--flat-world` also disables it.

## Native verification

`artifacts/pc-hill-art-native-final/report.json` completed with zero errors and
4,571,057 checks. Across four original viewpoints at 4x and 5x, it examines
4,838,656 world pixels: 347,769 hill pixels change and all 4,490,887 pixels outside
visible hill faces remain exact. Six cases have visible changed hills. Two have
fully occluded hill draw calls, with zero presentation changes.

All 261 recorded passes keep identical vertices, triangle ordering, material
identities and source dictionaries. The gate independently tests 244 analytic
sloped-plane samples and 152 vertical-plane samples, including both texture axes,
translation, source-camera rotation and world-position rebasing. A 20,000-pixel
neutral test resolves the dither to exactly RGB (86,85,0), independent of pixel
phase. Both painter orders, including a farther polygon drawn later, pass.
Unknown/thermal palettes retain byte-identical fallback. Missing frames clear
the mesh and selected-hill count.

The actual Play A/B captures in `artifacts/pc-hill-art-play-*-final/` stop at the
same original impact boundary. Source framebuffer bytes and complete capture
metadata match except the two presentation counters: 7 versus 10 detailed
terrain polygons and 0 versus 3 hill polygons. All 53,733 changed composite
pixels lie in the hillside region, bounding rectangle (500,168) through
(1136,299). The implementing assistant inspected the final full cockpit capture.
Receipt: `artifacts/pc-hill-art-01/play-parity-final.json`.

A separate 1,020-frame replay compares the new treatment with `--original-hills`.
Requests, full source-packet hashes, full conventional-RAM hashes and packed
original-video hashes are identical at every boundary, sequences 607 through
1626. Each run audits 668,467,200 RAM bytes and 261,120,000 callback-video bytes.
Final source and composite frames also match because no selected hills are
visible at that last boundary. Receipt:
`artifacts/pc-hill-art-01/replay-parity-final.json`.

The final shared-shader impact regression passes 4,719,653 checks over 4,767,744
native pixels, with unchanged clipping/fallback and maximum authored-colour
error one byte per channel. The arbitrary-colour regression passes all 1,280
exact RGB checks. Logs and receipts are in `artifacts/pc-hill-effect-regression-final/`
and `artifacts/pc-hill-colour-regression-final.json`.

Aggregate `artifacts/validation-20260928T053853Z` completed with terminal exit 0:
38 stages and 257 Python tests pass, including reference-file preservation and
the new hill gate. The optional Impeccable executable was unavailable; no new
dependency was installed. Native Godot image checks supply rendered evidence.

These checks establish bounded rendering behavior. They do not establish every
camera/motion state, subjective target readability, all-mission parity or a
completed high-resolution world. The source's integer vertex rounding can still
produce small coordinate variation during movement.

## Failed checks and corrections

* The first source test expected 50 faces. The decoded table has 49; every
  individual root/primitive check already matched. The incorrect denominator
  was corrected to the source count.
* The first native run and first aggregate gate failed on a GDScript type
  inference error in the new test's `cover` dictionary. Its explicit type fixed
  compilation; these failed gates are not counted as passes.
* The next native run failed because it demanded visible changes in both views
  of pass 90. Inspection of the independently rendered ownership mask showed
  zero visible hill pixels and zero changed pixels. The final gate explicitly
  requires six visible cases and two fully occluded cases, rather than dropping
  the latter or treating draw-call presence as visibility.
* Source-vector inspection then found 17 vertical faces. The initial XY-only
  texture projection was incomplete. Fixed source-specific XZ/YZ projection and
  independent two-axis native probes were added before final acceptance. Earlier
  passing receipts remain intermediate evidence.

## Reproduction

```sh
python3 -m unittest tests.test_pc_hill_art -v
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_hill_art.gd -- --native \
  --output "$PWD/artifacts/pc-hill-art-native-NEW"
./Play.command --trace --capture --capture-effect 52 --window-size 1280x960 \
  --frame-audit --output "$PWD/artifacts/pc-hill-art-play-NEW"
# Repeat with --original-hills for the previous presentation.
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner --interactive-clock \
  --replay-controls --frame-audit \
  --output "$PWD/artifacts/pc-hill-art-replay-NEW"
# Repeat with --original-hills and compare requests/sample_hashes.
./tools/validate.sh
```

All original reference files, local extracts and rejected/earlier evidence are
preserved. Generated imagery and references remain local and ignored. No push,
publication, redistribution or finished-release claim is part of this work.


## Raised plateau and adjoining slope extension (28 September 2026)

Review of the native radio route exposed coarse green checkerboards on the
Escort bridge approach. The initial 2..33 hill mapping omitted the raised terrain
family at 55..71. The world mesh was active; this was its deliberately retained
original material pattern, rather than the cockpit mask copying the ground.
Only 24 of 9,840 pixels in a sampled ground rectangle carried UI ownership (the
reticle). The earlier radio ledger's cause remained unverified until this check.

All 17 source shapes and 32 filled faces now use the same restrained terrain
treatment. Independent parsing verifies roots, primitive/material pairs and raw
vertices. Fifteen additional vertical faces get a source-fixed XZ/YZ projection,
bringing the full mapping to 81 faces and 32 vertical planes. The three close
plateau tops in the reported view are source shapes 59, 60 and 62. This adds no
new geometry, filtering of visibility, tactical information, or vehicle texture.

The already-recovered Genesis drawing VM also contains all 17 counterparts.
Existing command decoding, neutral construction and polygon-union helpers find
all 32 exact face cycles under Genesis XYZ to PC XZY conversion, without missing
or additional faces. Every linked Genesis material ID equals PC material+16.
The source test verifies these correspondences independently of the GDScript
lookup. This is static source correspondence, not a new Genesis gameplay run.
`artifacts/pc-embankment-work-01/correspondence.json` retains the primitive links.
An initial exploratory helper call omitted the neutral vertices when assembling
the comparison input and raised `KeyError: vertices`; merging both documented
helper outputs corrected that research script. No production parser was changed.

Existing generated hill imagery is reused unchanged. No image edit, new bitmap,
shader change, vehicle panel or new artistic object was introduced. Unknown
source identities, thermal palettes and missing assets retain the previous
fallback; `--original-hills` still disables the whole hill/plateau treatment.

The native hill test adds two original Escort viewpoints at 4x and 5x. Together
with its earlier views it checks 6,874,880 pixels, with 956,145 hill pixels changed
and all 5,918,735 pixels outside visible selected faces exact. Ten cases show
visible remastered terrain and two are fully occluded. All 5,999,173 checks pass,
including the prior geometry/order, exact mean-colour, two-axis vertical anchoring,
unknown-palette and painter-order regressions. Native receipt:
`artifacts/pc-embankment-native-01/report.json`.

```sh
python3 -m unittest tests.test_pc_hill_art -v
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_hill_art.gd -- --native \
  --radio-fixture "$PWD/artifacts/pc-radio-trace-01/report.json" \
  --output "$PWD/artifacts/pc-embankment-native-new"
```

The production viewer then reran the complete 3,716-frame radio route after the
mapping change. `pc-radio-native-02/report.json` again passes all 26,142 checks,
with native and child exit 0. Every paired original RAM/video boundary and every
audio request still matches the untouched-PC comparison. Final full source
presentation, state and audio metadata equal the earlier native capture. Only
the terrain counters differ, with 11 rather than one selected hill/plateau faces.
Vehicles still have zero textured polygons.

The before/after composite comparison changes 234,616 pixels in the first radio
view, all inside the gunner viewport. The other two radio views and final frame
also change only within that viewport. An initial check incorrectly required
all source-mask UI pixels to stay opaque: 40 pixels at existing antialiased
reticle edges (four in the final frame) blend with the changed ground. Their
coordinates and analytic fractional coverage were checked against the unchanged
eight-stroke source geometry and existing shader. All opaque source HUD pixels
remain identical in those two mask-verified captures. No reticle code or
production ownership guard was changed to pass this check. The original failed
receipt is retained. Final comparison uses any-channel RGB differences rather
than lossy grayscale difference: all 12 checks pass at
`artifacts/pc-embankment-work-01/live-comparison-v3.json`.

The implementing assistant reviewed the full new cockpit capture and the
isolated source-owned terrain view. This is self-review, with human visual and
motion acceptance still open. `npx --offline --no-install impeccable detect
godot/scripts` exited 0 with no diagnostic output; no GDScript-specific lint
coverage is inferred from that empty result. No package was installed.

`validation-20260928T120651Z` passes all 42 stages, terminal exit 0, including
298 Python tests, source preservation and all original audio, type, instrument,
terrain, reticle and scheduling gates. Native/aggregate logs contain no script,
parse or engine errors. This closes the observed plateau-dither gap, while other
unmapped world families and whole-game presentation acceptance remain open.
