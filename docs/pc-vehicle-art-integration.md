# Genesis-derived vehicle surfaces

## Source and scope

The original PC executable still selects each actor, detail level, visible face,
transform, material and painter order. The recovered Genesis geometry supplies
the visual reference. This pass adds authored running gear to the T-62 and M1A1,
and running gear plus side-armour detail to the M113. It does not install the
separate Blender model unions as gameplay actors.

The six selected side faces have exact topology and material correspondence
between the pinned PC SHAPE.TBL and recovered Genesis model programs:

| Model | PC shape / root | Original side primitives | Authored panel |
|---|---|---|---|
| T-62 | 115 / 13289 | 13323, 13333 | 2046 x 768 |
| M1A1 | 125 / 17420 | 17464, 17490 | 2103 x 748 |
| M113 | 129 / 19158 | 19188, 19198 | 2048 x 768 |

The original PC shape file SHA256 is
`81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193`.
The Genesis ROM SHA256 is
`ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.
`tests/test_pc_vehicle_art.py` decodes the source files independently and checks
the runtime's ordered coordinates, primitive identities and Genesis counterpart.

The built-in image generator received three native-rendered side views of the
recovered Genesis model studies. It received no ROM, executable or workspace
archive. The PNGs, exact tool prompts, reference hashes, original generation
paths and manifest are retained under
`local-art/genesis/remastered/vehicles-v1/`. All three original generated PNGs
remain unchanged. The earlier T-62 prompt draft is retained separately from the
exact tool prompt. Wheels, links and armour seams are authored interpretations
within the source silhouette, not detail recovered from the original polygons.

## Presentation binding

`pc_vehicle_art.gd` checks the source file, donor hashes/dimensions, original
palette, model/root, primitive, fill mode, material pair and vertex count.
Unknown identities, missing or changed assets, unsupported palettes and failed
loads retain the previous presentation. `--original-vehicles` selects the
previous vehicle presentation without disabling the other remastered families.

Source Y/Z coordinates are paired with the captured camera vertices in their
original order. No approximate inverse of the PC's integer transform is used.
Near-plane clipping interpolates optional UVs at exactly the same intersections
as the original presentation triangles. Triangle positions and order do not
change. Each panel is fitted uniformly to its face bounds, retaining circular
wheel proportions; any remaining area retains the original face colour.

The engine packs the unchanged images into one local runtime texture, with
64-pixel transparent gutters. UVs may use those gutters where a uniformly fitted
panel is narrower than its source face. Sampling never enters another image.
Generated low-alpha residue does not create geometry or transparency. Alpha
modulates surface detail only, and the shader never discards a vehicle fragment.
The existing PC face remains opaque and continues to occlude earlier polygons.
Texture detail fades between source depths 1024 and 4096. This changes no source
LOD, silhouette, visibility, collision or targeting input.

## Model colours

The existing world-palette study deliberately mapped PC colour 3 to Genesis
bank-3 entry 13, a dark road grey (32,32,32). Applying that road mapping to these
vehicles was wrong. The recovered Genesis models use material 19 and bank-3
entry 3, (65,68,65). The six panels and seven other verified dark-grey faces on
these three models now use that model-specific shade. Original outline colours
remain unchanged, including the M1A1 rear's different outline and fill.

The panel's grayscale contrast modulates that source shade through a compensated
65-level colour table. A neutral panel and the seven untextured faces reproduce
the exact Genesis RGB. `--pc-colours` retains the original PC grey (85,85,85).
This is a bounded correction for these three models, not a claim that every
remaining object's palette has been restored.

## Evidence and limits

* `artifacts/pc-vehicle-art-native-02/report.json`: native Godot Compatibility,
  **19,783,292 checks, zero errors**, terminal exit 0. It compares **23,378,944
  rendered pixels**, including **18,707,238 unchanged pixels outside selected
  visible faces**. All six side faces are tested at 4x/5x and with a near-plane
  crossing. Separate ray/plane calculations check perspective UVs. Both painter
  orders and unknown-palette fallback are exercised. Seven other dark faces
  each pass native PC/Genesis colour checks, including 280,000 exact RGB probes.
* All **261 recorded original passes** retain their mesh positions, material
  identities, unselected UVs and source packets; 848 selected face occurrences
  are exercised. Three recorded viewpoints supplement the isolated face tests.
  Two contain small distant vehicle faces; one is completely occluded. The
  close-up panel images are explicitly synthetic authoring views, not claimed
  reachable gameplay camera positions.
* `artifacts/validation-20260928T074431Z`: complete aggregate terminal exit 0,
  **40 stages and 273 Python tests pass**, including original-file preservation.
* `artifacts/pc-vehicle-hill-regression-01/report.json` and
  `pc-vehicle-effect-regression-01/report.json`: shared-shader native regression
  runs pass **4,571,057** and **4,719,653** checks respectively, both exit 0.
* `artifacts/pc-vehicle-art-replay-parity-01.json`: two actual interactive-input
  runs have identical requests, all **1,020 complete source packet hashes**, RAM
  digests and packed-video digests at sequences 607 through 1626. Each run audits
  668,467,200 RAM bytes and 261,120,000 video bytes. Both processes exit 0.
  The final view contains no selected vehicle faces, so its unchanged composite
  is source-noninterference evidence, not evidence of visible texture quality.
  The audit-enabled runs measured 31.10 and 34.40 fps; these are not historical
  CPU calibration or sustained unaudited performance results.
* `artifacts/pc-vehicle-art-play-remastered-01/`: actual public `Play.command`
  capture at sequence 606, terminal exit 0, visually inspected. All pre-existing
  capture metadata matches `pc-cockpit-current-review-01`. The new counter selects
  one vehicle face; exactly 30 composite pixels change in its distant 6x5 area.
  The rest of the world and cockpit are unchanged. The comparison receipt is
  `artifacts/pc-vehicle-art-play-parity-01.json`.

The same assistant generated, implemented and visually reviewed this work.
This is self-review, not Nell's artistic acceptance. Full vehicle restoration
still requires remaining surfaces, other types and LODs, damaged variants,
source-driven movement/animation review and representative close-range gameplay.
No claim of all-mission, campaign, timing or save parity follows from these tests.

## Retained intermediate failures

The first Python test supplied a catalog dictionary where the existing source
comparison function expected its model list. The first GDScript test had an
inferred Dictionary type error. Both tests were repaired. The next headless
check incorrectly required fitted UVs to remain inside the PNG itself, although
the intentionally allocated transparent gutter is part of its sampling region.
It now verifies the complete isolated region, still rejecting neighbouring rows.

Native-01 passed geometry/visibility checks but rendered the incorrect road grey.
Visual review exposed that palette error. Native-02 supersedes it after the
source-colour correction and independent exact RGB tests. Earlier evidence is
retained without being relabelled as final acceptance.

## Reproduction

```sh
python3 -m unittest tests.test_pc_vehicle_art -v
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_vehicle_art.gd -- --native \
  --output "$PWD/artifacts/pc-vehicle-art-native-NEW"
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner --interactive-clock \
  --replay-controls --frame-audit \
  --output "$PWD/artifacts/pc-vehicle-art-replay-NEW"
# Repeat with --original-vehicles; compare requests and complete sample_hashes.
./tools/validate.sh
```

Original sources, extracts and generated imagery remain local and ignored.
Optional Impeccable is unavailable; no dependency was installed. Native visual
and functional checks were run. No push, publication or redistribution occurred.
