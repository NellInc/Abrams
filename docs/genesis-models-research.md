# Genesis model recovery and editable vehicle studies

## Scope and authority

The original PC executable remains the gameplay and visible-draw authority.
This work recovers Genesis authoring sources. It changes no live renderer,
emulator, input path, game binary or reference snapshot. Source exports and
derived media stay local and ignored; redistribution is not authorized.

The implementing assistant created and visually reviewed these studies. This
is self-review, not Nell's art acceptance. Bevels are an initial surface study;
detailed vehicle restoration and live integration remain unfinished.

## Recovered format

Pinned ROM SHA-256:
`ff83dc53b33252d42ac624e11a2ce717428b75f48f2e56a20b3d38f78e6ca4ea`.

The models are drawing bytecode, not contiguous conventional meshes. Original
lookup routine `0x3fba` selects the directory through `0x4dc94` and RAM word
`0xe588`. Bank zero begins at `0x4dc98`, with 188 four-byte entries. Each entry
contains a big-endian unsigned relative program offset and a second unsigned
word returned by `0x3fee`. The latter is recorded as `source_extent`; this work
does not assign physical units to it. Other directory banks are outside scope.

Class-associated indices 115 through 167 resolve to 53 programs. The extractor
follows the union of explicit jumps, conditional continuations and sorted
subprogram targets. It recovers 1,423 distinct commands and 34 distinct literal
vertex blocks. Nineteen replacement entries jump to the same complete model at
`0x56980`; they are not empty placeholders. Reachable command bytes, addresses,
conditions, source materials and all continuation targets remain in JSON.

Original VM dispatch is at `0xf50e`, with handler pointers at `0xf51a`.

| Command | Source interpretation / original handler |
|---|---|
| `04` | Vertex destination, count, matrix offset, then signed BE XYZ triples; `0xf63c` |
| `0c`, `10` through `40` | Vector accumulator, signed 16-bit arithmetic, copies and stack; `0xf6c2` onwards |
| `54` | Original projection range, preserved without authoring-time projection |
| `58`, `5c` | Facing definitions, retained as source triples and flag destinations |
| `60`, `64`, `68`, `6c`, `70`, `74` | Conditional continuations, stack return and relative jump; `0xfd00` onwards |
| `80`, `84`, `8c`, `90`, `94` | Line material, pen and conditional segments |
| `a0` through `c0` (supported polygon commands) | Material, vertex list and optional source facing flag |
| `cc` | Circle/special draw, preserved as an unmeshed command |
| `d8`, `e0`, `e4` | Actor transform, scaled matrix and procedural corner construction |
| `ec 08` | Source depth-sorted subprogram list; `0x10630` |
| `f0` | Original subprogram return |

Each sorted-group entry is a signed BE long relative offset, based immediately
after that long, followed by a BE word sort-vertex index. Word jump `74` also
uses its post-incremented operand pointer. This detail is checked by executing
the original instruction, rather than assuming same-register addressing order.
Unknown opcodes, truncated fields, invalid ranges, branches into operands and
excessive command traversal fail closed.

## Neutral geometry and PC correspondence

Authoring pose inputs are explicit: zero actor angles, the original diagonal
32766 identity matrix and source flag FC set to zero or one for the truck.
The extractor retains signed-word wrap and arithmetic shifts. Facing and
projection are not replaced by a new game renderer.

The truck, index 159, constructs its vertices arithmetically. Both FC paths are
exported: 52 defined workspace slots for FC=0, 69 for FC=1. Conditional polygons
whose vertices do not exist in a pose remain listed as unmeshed commands. The
low-detail export is therefore a definition union, not an asserted render.

`pc-correspondence.json` compares recovered Genesis positions `(x,y,z)` with
PC `(x,z,y)`, using the unchanged PC `SHAPE.TBL` and its independently recovered
primitive conversion. PC source hash:
`81cf10917d8647e8ac187e49887494992828277333f17d6c1926e59581f0a193`.

For 52 indices, all PC primitive-used coordinates and unique polygons have
Genesis counterparts, with no extra unique polygons. This includes 585 unique
PC polygons and one zero-polygon record, index 167. Matching polygons carry
Genesis material byte `16 + PC material`. Explicit PC-primitive-to-Genesis-
command links are exported. Cyclic/reversed winding and duplicate back-facing
definitions are accounted for; conditional visibility is not equated.

**The truck differs.** Neither recovered truck pose matches its PC polygon
coordinates. These differences remain visible in the correspondence report.
No automatic source substitution or global equivalence claim is supported.
Index 167's program draws no polygon; no bridge geometry is invented for it.

## Native material sources

Original ordinary-mode translation table `0xcc6` is selected by `0x4738` and
`0x10f62`; RAM `0xe54e` in the retained gunner research capture also points to it.
The fill routine at `0x4c7a` maps a material through that table, then loads its
two four-byte pattern rows from `0xbc6`. All 16 materials used by these exports
pass the original-instruction lookup check.

Editable MTL colours use the explicit gunner capture's palette bank 3 and the
mean of those two original pattern rows. Packed patterns and palette indices
remain in the manifest. This is a continuous-colour authoring interpretation.
Thermal, alternate palette modes and visible vehicle-frame colour acceptance
remain separate work; the generic native material lookup alone cannot prove them.

## Local outputs

* `reference/genesis/models-source-v2/`: 53 full program JSONs, 54 OBJ pose
  exports, source materials, complete catalog and PC correspondence. OBJ includes
  only polygon/line-used vertices; normals and sort references stay in JSON.
* `local-art/genesis/vehicles-source-fitted-v1/`: T-62 (115), M1-A1 (125) and M113
  (129) glTF studies, paired previews and an editable Blender master containing
  both source and refined versions. Names/indices were checked directly in the
  unpacked PC class table at data `0x19e00 + 0x510`, stride 30, and `SHAPE.GI`.
* `artifacts/genesis-model-research-01/`: research probes, isolated CPU receipts
  and build/test logs. The two raw RAM byte orders are read-only research aids.

The earlier source-v1 export is retained as intermediate evidence. Source-v2
adds explicit PC polygon links and excludes unused reference vectors from OBJ
bounds. The five pre-existing, untracked PC vehicle-study files are untouched.
The new tools have no import dependency on those files.

Blender studies use four-segment bevels of 0.45 original coordinate units,
0.3-unit line radius and 64 source units per authoring unit. This authoring scale
does not establish metres. Source VM sort blocks remain separate components;
their names do not assert moving joints. Coincident opposite-facing definitions
are recorded and deduplicated only for the editable mesh. Preview materials are
double-sided because the mesh is a source-definition union. These studies must
not be installed as whole visible actors without the original PC visibility gate.

The three glTFs contain 477, 632 and 281 triangles respectively. Original colour
values feed the materials through sRGB-to-linear conversion. Mild rough-surface
lighting and bevels are authored; no modern proportions or additional vehicle
parts were invented in this pass.

## Verification and retained failure

* Python format/export/correspondence tests: 12 pass.
* `artifacts/genesis-model-research-01/oracle-02.json`: original M68000 code,
  read/execute-only ROM; all 188 directory pointers and extents, 54 neutral poses,
  528 construction commands, 221,184 complete workspace bytes, 62 control-flow
  cases, 1,166 clipped polygon cases, 94 clipped line cases, 26 equal-depth sorted
  subprogram lists and 16 material lookups match. Zero mismatches, terminal exit 0.
* `artifacts/genesis-vehicle-studies-native-02/report.json`: actual Godot glTF
  import and nine native views, 580,234 checks, zero errors, terminal exit 0.
  All 48,616 sampled owned pixels show model materials; all 527,384 sampled
  outside pixels retain the background. Measured maximum axis expansion is
  0.288 raw units, within the declared 0.45-unit study envelope. These are sampled
  preview-ownership checks, not gameplay silhouettes or tactical visibility.

The first CPU exploration assumed every prelude command advanced linearly.
The truck's original conditional branch disproved that assumption; the final
extractor follows the actual branch and exports both paths. The original probe
failure is not a decoder acceptance result.

The first native study check failed all nine views because an arbitrary
60-colour threshold rejected the original small palette. Whole captures showed
visible models with 19 to 33 sampled colours. Replaced that flawed criterion
with independent unshaded geometry-ownership captures, source material presence
and unchanged outside samples. No artwork was changed to inflate colour counts.
Native-01 remains a failed run. Native-02 is the corrected final check.

## Reproduction

```sh
python3 -m unittest tests.test_genesis_models -v
python3 tools/extract_genesis_models.py \
  --capture reference/genesis/instruments/gunner --compare-pc GAME/SHAPE.TBL \
  --output reference/genesis/models-source-NEW
.runtime/pc-analysis-venv/bin/python tools/genesis_model_oracle.py \
  --output artifacts/genesis-model-oracle-NEW.json
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
  --python tools/build_genesis_vehicle_studies.py -- \
  --source "$PWD/reference/genesis/models-source-v2" \
  --output "$PWD/local-art/genesis/vehicles-source-fitted-NEW"
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_genesis_vehicle_studies.gd -- --native \
  --output "$PWD/artifacts/genesis-vehicle-studies-native-NEW"
./tools/validate.sh
```

Use `--assets` on the Godot test to select another generated study directory.
The builder records `source` relative to the repository; the Godot test also
accepts older absolute paths and falls back to
`reference/genesis/models-source-v2` when the recorded directory is gone, with
the pinned hashes still authenticating every source file.
Original ROM/captures, Pillow, Blender and the existing Unicorn environment are
local prerequisites. No new dependencies were installed.

## Next integration boundary

Continue detailed Genesis-first surfaces and parts, while retaining source
silhouettes and material identities. Use the new polygon links to bind only
original PC-selected faces in their original draw order. Verify source clips,
occlusion, palette fallbacks, source-fixed detail and pixel ownership before
enabling anything live. Truck correspondence, animation, circles, remaining
classes/variants and human art acceptance are open. Whole-goal audio, pacing,
mission/campaign/save parity and release-candidate requirements remain open too.
