# Modern source-bound asset register

## Scope and authority

Local authoring lane for the Modern implementation approved in the current task. The older plan-only language in the initial contprompt describes the earlier concept pass; it does not describe the current delegated authoring scope. This register covers geometry production and source identity. It makes no runtime, taste-approval, distribution-rights or finished-game acceptance claim.

The assets were produced by the same author who performed their mechanical review. The approved low-poly concept guides the broad facets, olive finish, continuous track bands and polygonal wheels. Every dimension comes from the local PC source geometry. No historical metre dimensions, guessed model identities, new terrain, cover or independent articulation were introduced.

## Deliverables and rebuild

* `tools/build_pc_modern_assets.py`: editable, deterministic procedural source, standard library only.
* `tests/test_pc_modern_assets.py`: independent geometric fixtures and separate local-corpus integration checks.
* `local-art/pc-modern/catalog.json`: runtime mesh contract and complete source registry.
* `local-art/pc-modern/models/NNN.glb`: editable geometry previews in original raw axes and units.
* `local-art/pc-modern/manifest.json`: source fingerprints, catalogue hash, counts and explicit completion categories.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/build_pc_modern_assets.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_pc_modern_assets -v
```

Outputs remain in ignored local-art. No original resources, executable bytes, scenarios or world placements are modified. The generator validates SIM.EXE, SHAPE.GI and SHAPE.TBL against the existing pinned source hashes. Sixteen scenario resource hashes record the inventory input; campaign changes may legitimately alter the SSS files, so these hashes are provenance rather than a runtime compatibility lock.

## Mesh contract, schema 1

Top level: `schema`, `authoring_revision`, `sources`, `classes`, `inventory`, `materials`, `models`, `coordinate_contract`, `visibility_contract`.

Each model is indexed by source `shape_index`. `class_roles` preserves every class-table primary, alternate and replacement association. `scenario_placements` counts the eight WLDs separately. `required` means present in those world files or referenced by the full class table, including player and special classes absent from SSS actor records.

`source_primitives` is a list of `{id, prefix_bytes, vertices}` in the exact decoded primitive order. The `id` is the absolute offset in decoded SHAPE.TBL. Vertices are produced by the existing `primitive_vertices` decoder, including signed arithmetic and packed-vector conversion. `selectors`, `roots`, `groups` and `opaque_commands` retain the source structure. `source_lines` retains line and degenerate polygon witnesses.

Each triangle contains:

```text
vertices: [[raw_x, raw_y, raw_z], ... exactly three]
color: [red, green, blue], integer 0..255
material: authored material name
source_primitive: decoded SHAPE.TBL primitive offset
source_groups: source group offsets containing that primitive
component: authored panel, bevel, band, wheel or hub identity
uv: optional three normalized [u,v] pairs on the two original tree planes
```

The pivot is always the original `[0,0,0]`. No recentering or camera-coordinate transformation occurs. Source z is original height. Static world x/y placement axes and vehicle orientation remain the existing source adapter's responsibility. `source_bounds`, `bounds` and `dimensions_raw` use source units, whose physical metre interpretation remains unestablished. GLBs deliberately retain the raw z-up convention instead of silently reinterpreting numbers as metres or rotating them into glTF's usual Y-up convention.

**A complete offline mesh is a definition union, never a visibility list.** The runtime must select triangles only through an actually drawn source primitive and its selected group/root. Runtime clipping must preserve original source coverage. Original lines, opaque commands, bitmap effects and underlay remain authoritative. No independent turret or wheel animation is inferred from source group names.

## Geometry and material method

1. Terrain, road, water and unknown static surfaces retain their exact original vertices and shape. Concave polygons use ear clipping rather than an area-enlarging fan. No terrain subdivision, smoothing, displacement, new banks or bridge approaches are introduced.
2. Convex planar vehicle and building faces receive constant-width inset bevels, measured from the shortest centroid-to-edge distance. Concave and nonplanar faces retain their original triangulation without false internal seams. Bridge decks and weapon-crew sheets keep their exact source planes. Named intact buildings receive near-square framed windows, entrance doors, plinths and eave bands inside rectangular source wall faces, without additional footprint or height. Source hull outside edges remain fixed; the separately documented turret and barrel corner cuts shrink only those components. Panel interiors move 2.5% toward the owning source part's vertex centroid (3.5% for the BRDM wheel faces overlapping the hull). The two farm buildings use their own original vertices rather than the enclosing courtyard group. This is source-local geometry within the original component coordinate bounds, with source-coverage clipping still required at runtime.
3. Tracked vehicle side faces become continuous perimeter bands around recessed side planes. Closed eight-sided wheel and hub solids fit inside the original face. APCs have shallow olive upper side panels, sitting outside wheel faces to prevent coplanar flicker. The complete source silhouette remains unchanged. Wheel fit reduces radius to retain the model's intended count instead of dropping end wheels on sloped corners. T-62 has five road wheels per side, M1 seven, M113 five; these are authored presentation details with no motion or physics meaning.
4. BTR-70 side faces receive source-bounded tyre and hub relief against an olive recess. BRDMs and the truck retain their original wheel polygons with charcoal rubber and inset hubs; no duplicate wheels are added to the BRDM hull. Wreck states retain their own distinct, smaller original bounds; they are never scaled copies of intact hulls.
5. Olive, charcoal running gear, highlighted hubs, stone/plaster and sparse glazing remain matte. Vehicles use baked object-local fill: `min(1, 0.73 + 0.27 * abs(normal.z) + 0.08 * abs(normal.x))` on unit face normals. Intact buildings use a brighter `0.83 + 0.17 * abs(normal.z) + 0.07 * abs(normal.x)` fill, capped at one, and individually authored roof colours. Weapon-crew sheets use explicit colour facets without additional darkening. Terrain colours are handled by the presentation shader; trees retain their earlier material values. This makes top planes readable without assuming source winding, sun direction or runtime illumination.
6. The material-only colour pass restores all 23 solid source-red accent faces across flags, weapon fittings and both Hind states, including their existing borders. Wreck shading is retained; the surviving base flag keeps its source red. Hatch rims, hubs and upward armour facets receive restrained baked highlights. Existing building, truck and Hind panes use blue-grey glass with two quiet facet tones. Working if: all 188 model records retain identical vertices, triangle order, motion metadata and source contracts, and source-red accents remain red in the native renderer.
7. Added wheels and hubs are closed solids. Original whole shapes may deliberately contain open bottoms, intersecting groups, lines and two-sided sheets. The tests do not mislabel all original models as watertight.

The Hind's two source states, shapes 163/164, now use olive-green and pale grey piebald paint with a blue underside, following Nell's photographic colour reference. Broad procedural patches use original object-local longitudinal/height coordinates; the blue hem follows the source tail's rising bottom. Glass, intakes and source-red accents retain their separate materials. The catalogue and GLB retain their shaded base colours; `pc_surface.gdshader` supplies the livery, and the native model-preview tool uses that same function and production colour texture. No image texture, extra geometry, light, animation or gameplay state is added. Working if: both Hind states show all three paint colours, camera movement/rebasing preserves the local pattern, and non-Hind and legacy-mode rendered pixels remain unchanged.

### Roster material highlights, authoring revision 7

* Bridges 0/1/45/46/108/114 have warmer concrete decks and cool steel-grey framework. The 86 existing two-point lines carry optional `source_lines[].color` metadata. Runtime binding checks the static shape, selected root, original primitive and source colours before replacing the line colour. Endpoints, line widths, source ownership and painter depth remain unchanged. Invisible bridge marker 167 is untouched.
* APCs and utility vehicles 129/131/133/135/137/139/141/143/159 carry `paint_style: two_tone_olive`. The shader paints broad, subdued regions across olive body facets using an oblique object-local projection. Running gear, windows, source-red details and canvas are excluded. The truck's khaki canvas and matching canvas edges are separate from its olive cab and dark grille.
* Wrecks use face-bound charcoal, dull exposed metal and surviving paint. Building remains use warm rubble, pale plaster and darker scorched facets. No additional debris or emissive fire is introduced.
* Building accents use selective door colours, lighter existing window surrounds and roof/eave edges. The farm's orange roof, green yard and the red roof ridge retain their previous colour values.
* Sagger/Spigot equipment is darker than the uniforms, with clearer webbing, collars, optics and skin facets. Original poses and separate round-form commands remain authoritative.
* Tanks receive only a small hatch lift and darker existing grilles. Their family palettes remain intact. The Hind livery, terrain and unresolved F-ST model are unchanged.

All 188 definitions retain the same triangle vertices, source contracts and geometry metadata; the mesh total remains 19,702 triangles. The preview helper renders procedural paint with the production shader functions and palette. GLBs contain base colours; the game and native previews include the procedural liveries. Working if: before/after native studies preserve runtime vertex buffers and coverage, legacy pixels stay identical, and restoring the prior catalogue then the current one restores exact rendered pixels.

### Crew heads, ruins and base recognition, authoring revision 8

The offline model sheets omitted the Sagger/Spigot heads because those are separate round commands, not triangles in the GLBs. The preview now includes those commands. In Modern gameplay, verified commands 30996/31422 receive a faceted helmet, brim, face and chinstrap inside the exact observed original raster spans. The original center, radius, clipping and painter ownership remain authoritative. No head is fabricated when the source command is absent or rejected. Other graphics modes retain their original head rendering. Offline sheets approximate the camera-facing circle for inspection; the native renderer tests use original CPU raster witnesses for both crews.

Destroyed structures 146/148/150/152/154/158 now contain irregular recessed masonry slabs, fracture sides, charcoal interiors, pale plaster and exposed brick. Pieces stay inside the original damaged model bounds and original source ownership. No rubble spills onto roads, alters collision or creates new cover.

Base shape 156 is a complete compound in the source geometry, although it occupies the class table's replacement field. Its source role is unchanged; its presentation now uses intact walls, green roofs, doors and windows rather than generic wreck paint. US base shapes 155/156 carry white Army stars; enemy HQ 153 carries red stars with gold borders. The compound roof marks and gable marks remain within existing faces, and their existing flags carry the corresponding Army emblems. These are identification markings, not new flagpoles or animated objects. Civilian buildings and communications stations receive no faction insignia.

Working if: both crews visibly retain a helmet and face within original head coverage; missing/rejected head commands remain absent; the six ruins have broken slab and dark interior components; base insignia appear in native views; unrelated model pixels and all legacy rendering remain unchanged; source bounds, roots, primitive identities and simulation files remain unchanged.

### American flag, authoring revision 9

The US compound's existing flag (shape 156, source primitive 28325) now carries the Stars and Stripes: thirteen alternating red/white stripes and fifty five-point white stars in nine alternating six/five-star rows on a blue canton. The original flag plane, size, pole and source ownership are retained. Disjoint coloured facets avoid coplanar overlays or a new texture. Roof and wall Army stars, Soviet markings and every other model are unchanged.

Working if: the flag has exactly thirteen stripe regions and fifty star regions, retains its original area and plane, renders red/white/blue in the native viewer, and all non-flag geometry and other models remain identical.

## Exact vegetation identity

Shape **103** is a crossed-polygon evergreen, with **147 original placements** across the eight scenarios. Its raw bounds are `[-160,-160,0]..[160,160,480]`.

| Source group | Primitive | Geometry |
| --- | --- | --- |
| 10533 | 10541 | Trunk quad in y=0, x ±32, z 0..128 |
| 10533 | 10549 | Crown triangle in y=0, base x ±160 at z128, apex z480 |
| 10556 | 10564 | Crown triangle in x=0, base y ±160 at z128, apex z480 |
| 10556 | 10571 | Trunk quad in x=0, y ±32, z 0..128 |

The model exports normalized UVs for each trunk/crown patch and `tree_trunk`/`tree_crown` tags. Illustrated sprite imagery is the root lane's responsibility. The geometry export contains the fixed UV template; root-owned `tree.png` and `tree.json` supply separately generated illustrated art and are preserved on rebuild. Integration must retain these fixed crossed planes and triangular crown coverage; a larger billboard quad would invent coverage. No other shape was classified as a tree by name or resemblance alone.

## Unresolved source programs and explicit limits

* **F-ST, shapes123/124:** source class name and forms are real. A real-world vehicle identity is unresolved. These receive conservative faceting only, with no invented future tank anatomy or guessed designation.
* **A10 and MIGS, shapes165/166:** class names reference simple cube programs, selectors word16, with bounds ±128 and ±32 respectively. Neither class appears in the eight SSS actor record arrays. Both remain `unresolved_placeholder`, with source cube surfaces only. No aircraft production model is claimed. The independent PC/Genesis correspondence in `docs/genesis-models-research.md` also reports matching source polygon definitions. This is evidence of stored source forms, not proof that a runtime special path never mutates them. The later bounded original-CPU investigation below supplies an ordinary allocation/render-selection witness, while shipped-mission visibility remains unverified.
* **Bridge class, shape167:** all three class records share a vertical source line, x=y=0, z0..702. The independently recovered Genesis program also draws no polygon. Actual static structures include separate polygon programs, notably108 and114. The generator preserves those source forms and does not fabricate a full bridge mesh from the actor marker.
* **Opaque-command programs145,153,156,161,162:** COM STAT, HQ, base replacement and the two weapons retain commands at their exact source offsets. Refined visible polygons are available, but these models remain `partial_opaque`. The later investigation below identifies these as visible round forms and supplies exact original-CPU raster and compiled-hook transport proof. The mesh-only status stays partial because triangle geometry alone cannot replace these source commands.
* **Shape111 and168..187:** source-command/sprite programs, retained in the registry with commands and selectors. The asset lane does not replace effect bitmaps.
* **Lines and degenerate polygons:** retained as source witnesses; no arbitrary-radius gun, antenna or rotor cylinder replaces a zero-thickness primitive. The source renderer must preserve these details. A closed production aircraft rotor or antenna rig is not claimed.
* **Static structures:** identification is by exact shape index and geometry, not invented place names. Where historical function remains unknown, the register uses `static_NNN` and preserves geometry.

## Mechanical evidence and remaining acceptance

Current combined asset/catalogue/round-form/render-trace/observer run: 56 tests pass (including isolated compiled native callback transport). Native Compatibility previews for T-62, M1, M113, BTR-70, building149 and HIND exited successfully and were visually inspected. The building preview led to the bounded facade refinement. Preview PNGs are in the ignored output directory. The first dummy-headless preview could not render and was stopped by the root only after Nell explicitly authorized its termination; its exit receipt was143. The replacement preview had both an in-script20-second deadline and a300-frame engine guard and exited0.

Independent tests cover concave triangulation area, collinear cleanup, closed beveled-cube topology, closed wheel/hub topology, complete wheel fit, malformed payload rejection and binary GLB structure/raw-coordinate preservation. Corpus tests cover all188 records, all31 class roles, all151 required distinct shapes, all6163 static placements, every face's original primitive/group attribution, finite coordinates, nondegenerate triangles, source-bound geometry, crossed-tree planes/UVs, explicit incomplete statuses and deterministic JSON/GLB output.

These checks prove mechanical authoring properties. They do not prove moving gameplay, target recognition, source occlusion, aiming, checkpoint restoration, rendering performance or visual acceptance. Those remain the root renderer/integration lane's gates. Status `authored_mesh` records produced geometry and does not mean a complete source program or finished gameplay validation.

## Class and variant register

| Class | Source name | Primary | Alternate | Replacement |
| --- | --- | --- | --- | --- |
| 0 | T-62 | 115 | 115 | 116 |
| 1 | T-64 | 117 | 117 | 118 |
| 2 | T-72 | 119 | 119 | 120 |
| 3 | T-80 | 121 | 121 | 122 |
| 4 | F-ST | 123 | 123 | 124 |
| 5 | M1-A1 | 125 | 125 | 126 |
| 6 | M60a3 | 127 | 127 | 128 |
| 7 | M113 | 129 | 129 | 130 |
| 8 | M2 | 131 | 131 | 132 |
| 9 | BMP-1 | 133 | 133 | 134 |
| 10 | BMP-2 | 135 | 135 | 136 |
| 11 | BTR-70 | 137 | 137 | 138 |
| 12 | ACRV-2 | 139 | 139 | 140 |
| 13 | BRDM-2 | 141 | 141 | 142 |
| 14 | BRDM-3 | 143 | 143 | 144 |
| 15 | SAGGER | 161 | 161 | None |
| 16 | SPIGOT | 162 | 162 | None |
| 17 | HIND | 163 | 164 | None |
| 18 | A10 | 165 | 165 | None |
| 19 | MIGS | 166 | 166 | None |
| 20 | COM STAT | 145 | 145 | 146 |
| 21 | Building | 147 | 147 | 148 |
| 22 | Building | 149 | 149 | 150 |
| 23 | Building | 151 | 151 | 152 |
| 24 | ENEMY HQ | 153 | 153 | 154 |
| 25 | Base | 155 | 155 | 156 |
| 26 | Farm | 157 | 157 | 158 |
| 27 | Truck | 159 | 159 | 160 |
| 28 | Bridge | 167 | 167 | None |
| 29 | Bridge | 167 | 167 | None |
| 30 | Bridge | 167 | 167 | None |

## Deduplicated shape register

Dimensions are raw source x × y × z extents. World counts are static placements; class-table roles remain separately above. Source-only includes unreferenced static variants and effect programs, which are registered without claiming scenario reachability.

| Shape | Source owner | Required | World count | Dimensions raw | Triangles | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | static_000 | source-only | 0 | 340 × 1023 × 341 | 3 | authored_mesh |
| 1 | static_001 | source-only | 0 | 1023 × 340 × 341 | 3 | authored_mesh |
| 2 | static_002 | yes | 8 | 4096 × 4096 × 512 | 4 | source_surface |
| 3 | static_003 | yes | 7 | 4096 × 4096 × 512 | 4 | source_surface |
| 4 | static_004 | source-only | 0 | 4096 × 4096 × 1024 | 6 | source_surface |
| 5 | static_005 | source-only | 0 | 4096 × 4096 × 1024 | 6 | source_surface |
| 6 | static_006 | yes | 41 | 4096 × 4096 × 1024 | 1 | source_surface |
| 7 | static_007 | yes | 41 | 4096 × 4096 × 1024 | 1 | source_surface |
| 8 | static_008 | yes | 41 | 4096 × 4096 × 1024 | 1 | source_surface |
| 9 | static_009 | yes | 41 | 4096 × 4096 × 1024 | 1 | source_surface |
| 10 | static_010 | yes | 87 | 4096 × 4096 × 512 | 1 | source_surface |
| 11 | static_011 | yes | 86 | 4096 × 4096 × 512 | 1 | source_surface |
| 12 | static_012 | yes | 87 | 4096 × 4096 × 512 | 1 | source_surface |
| 13 | static_013 | yes | 86 | 4096 × 4096 × 512 | 1 | source_surface |
| 14 | static_014 | yes | 25 | 4096 × 4096 × 1024 | 2 | source_surface |
| 15 | static_015 | yes | 68 | 4096 × 4096 × 0 | 2 | source_surface |
| 16 | static_016 | yes | 36 | 4096 × 4096 × 1024 | 2 | source_surface |
| 17 | static_017 | yes | 39 | 4096 × 4096 × 1024 | 2 | source_surface |
| 18 | static_018 | yes | 26 | 4096 × 4096 × 1024 | 2 | source_surface |
| 19 | static_019 | yes | 55 | 4096 × 4096 × 512 | 2 | source_surface |
| 20 | static_020 | yes | 50 | 4096 × 4096 × 512 | 2 | source_surface |
| 21 | static_021 | yes | 84 | 4096 × 4096 × 512 | 2 | source_surface |
| 22 | static_022 | yes | 77 | 4096 × 4096 × 512 | 2 | source_surface |
| 23 | static_023 | yes | 8 | 4096 × 4096 × 1024 | 8 | source_surface |
| 24 | static_024 | yes | 16 | 4096 × 4096 × 1024 | 10 | source_surface |
| 25 | static_025 | yes | 1 | 4096 × 4096 × 1024 | 2 | source_surface |
| 26 | static_026 | yes | 1 | 4096 × 4096 × 1024 | 2 | source_surface |
| 27 | static_027 | yes | 251 | 4096 × 4096 × 2048 | 2 | source_surface |
| 28 | static_028 | yes | 250 | 4096 × 4096 × 2048 | 2 | source_surface |
| 29 | static_029 | yes | 176 | 4096 × 4096 × 2048 | 2 | source_surface |
| 30 | static_030 | yes | 172 | 4096 × 4096 × 2048 | 2 | source_surface |
| 31 | static_031 | yes | 90 | 4096 × 4096 × 2048 | 1 | source_surface |
| 32 | static_032 | yes | 85 | 4096 × 4096 × 2048 | 1 | source_surface |
| 33 | static_033 | yes | 90 | 4096 × 4096 × 2048 | 1 | source_surface |
| 34 | static_034 | yes | 253 | 4096 × 1024 × 0 | 2 | source_surface |
| 35 | static_035 | yes | 93 | 2560 × 2560 × 0 | 2 | source_surface |
| 36 | static_036 | yes | 130 | 2560 × 2560 × 0 | 2 | source_surface |
| 37 | static_037 | yes | 126 | 2560 × 2560 × 0 | 2 | source_surface |
| 38 | static_038 | yes | 238 | 1024 × 4096 × 0 | 2 | source_surface |
| 39 | static_039 | yes | 96 | 2560 × 2560 × 0 | 2 | source_surface |
| 40 | static_040 | yes | 823 | 4096 × 4096 × 0 | 2 | source_surface |
| 41 | static_041 | yes | 25 | 4096 × 4096 × 0 | 1 | source_surface |
| 42 | static_042 | yes | 23 | 4096 × 4096 × 0 | 1 | source_surface |
| 43 | static_043 | yes | 33 | 4096 × 4096 × 0 | 1 | source_surface |
| 44 | static_044 | yes | 41 | 4096 × 4096 × 0 | 1 | source_surface |
| 45 | static_045 | yes | 5 | 1364 × 600 × 341 | 2 | authored_mesh |
| 46 | static_046 | yes | 8 | 600 × 1364 × 341 | 2 | authored_mesh |
| 47 | static_047 | yes | 13 | 1224 × 2560 × 650 | 86 | authored_mesh |
| 48 | static_048 | yes | 13 | 3584 × 3584 × 0 | 2 | source_surface |
| 49 | static_049 | yes | 78 | 2304 × 2304 × 0 | 2 | source_surface |
| 50 | static_050 | yes | 393 | 512 × 4096 × 0 | 2 | source_surface |
| 51 | static_051 | yes | 388 | 4096 × 512 × 0 | 2 | source_surface |
| 52 | static_052 | yes | 76 | 2304 × 2304 × 0 | 2 | source_surface |
| 53 | static_053 | yes | 48 | 2304 × 2304 × 0 | 2 | source_surface |
| 54 | static_054 | yes | 51 | 2304 × 2304 × 0 | 2 | source_surface |
| 55 | static_055 | yes | 260 | 4096 × 4096 × 0 | 2 | source_surface |
| 56 | static_056 | yes | 60 | 4096 × 4096 × 512 | 4 | source_surface |
| 57 | static_057 | yes | 3 | 4096 × 4096 × 512 | 6 | source_surface |
| 58 | static_058 | yes | 32 | 4096 × 4096 × 512 | 4 | source_surface |
| 59 | static_059 | yes | 24 | 4096 × 4096 × 512 | 6 | source_surface |
| 60 | static_060 | yes | 12 | 4096 × 4096 × 512 | 6 | source_surface |
| 61 | static_061 | yes | 7 | 4096 × 4096 × 512 | 6 | source_surface |
| 62 | static_062 | yes | 6 | 4096 × 4096 × 512 | 6 | source_surface |
| 63 | static_063 | source-only | 0 | 4096 × 4096 × 512 | 4 | source_surface |
| 64 | static_064 | yes | 3 | 4096 × 4096 × 512 | 1 | source_surface |
| 65 | static_065 | yes | 2 | 4096 × 4096 × 512 | 2 | source_surface |
| 66 | static_066 | yes | 3 | 4096 × 4096 × 512 | 1 | source_surface |
| 67 | static_067 | yes | 19 | 4096 × 4096 × 512 | 2 | source_surface |
| 68 | static_068 | yes | 19 | 4096 × 4096 × 1024 | 6 | source_surface |
| 69 | static_069 | yes | 2 | 4096 × 4096 × 512 | 1 | source_surface |
| 70 | static_070 | yes | 2 | 4096 × 4096 × 512 | 1 | source_surface |
| 71 | static_071 | yes | 2 | 4096 × 4096 × 512 | 2 | source_surface |
| 72 | static_072 | yes | 93 | 4096 × 4096 × 128 | 10 | source_surface |
| 73 | static_073 | yes | 43 | 4096 × 4096 × 128 | 4 | source_surface |
| 74 | static_074 | yes | 32 | 4096 × 4096 × 1024 | 6 | source_surface |
| 75 | static_075 | yes | 3 | 4096 × 4096 × 0 | 1 | source_surface |
| 76 | static_076 | yes | 3 | 4096 × 4096 × 0 | 1 | source_surface |
| 77 | static_077 | yes | 2 | 4096 × 4096 × 0 | 1 | source_surface |
| 78 | static_078 | yes | 2 | 4096 × 4096 × 0 | 1 | source_surface |
| 79 | static_079 | yes | 1 | 4096 × 4096 × 1024 | 4 | source_surface |
| 80 | static_080 | source-only | 0 | 4096 × 4096 × 256 | 4 | source_surface |
| 81 | static_081 | source-only | 0 | 4096 × 4096 × 256 | 4 | source_surface |
| 82 | static_082 | source-only | 0 | 4096 × 4096 × 512 | 3 | source_surface |
| 83 | static_083 | yes | 1 | 4096 × 4096 × 512 | 3 | source_surface |
| 84 | static_084 | yes | 2 | 4096 × 4096 × 512 | 3 | source_surface |
| 85 | static_085 | source-only | 0 | 4096 × 4096 × 1024 | 4 | source_surface |
| 86 | static_086 | source-only | 0 | 4096 × 4096 × 1024 | 4 | source_surface |
| 87 | static_087 | yes | 2 | 4096 × 4096 × 1024 | 4 | source_surface |
| 88 | static_088 | yes | 8 | 4096 × 4096 × 1024 | 4 | source_surface |
| 89 | static_089 | yes | 79 | 4096 × 4096 × 0 | 2 | source_surface |
| 90 | static_090 | yes | 8 | 4096 × 4096 × 512 | 3 | source_surface |
| 91 | static_091 | yes | 1 | 4096 × 4096 × 1024 | 5 | source_surface |
| 92 | static_092 | yes | 1 | 4096 × 4096 × 1024 | 5 | source_surface |
| 93 | static_093 | yes | 6 | 4096 × 4096 × 1024 | 4 | source_surface |
| 94 | static_094 | yes | 95 | 4096 × 4096 × 2048 | 1 | source_surface |
| 95 | static_095 | yes | 15 | 4096 × 4096 × 1024 | 6 | source_surface |
| 96 | static_096 | source-only | 0 | 4096 × 4096 × 1024 | 6 | source_surface |
| 97 | static_097 | source-only | 0 | 4096 × 4096 × 1024 | 3 | source_surface |
| 98 | static_098 | source-only | 0 | 4096 × 4096 × 1024 | 3 | source_surface |
| 99 | static_099 | yes | 4 | 4096 × 4096 × 1024 | 3 | source_surface |
| 100 | static_100 | yes | 10 | 4096 × 4096 × 1024 | 3 | source_surface |
| 101 | static_101 | yes | 2 | 4096 × 4096 × 1024 | 7 | source_surface |
| 102 | static_102 | yes | 6 | 4096 × 4096 × 1024 | 4 | source_surface |
| 103 | evergreen | yes | 147 | 320 × 320 × 480 | 6 | tree_sprite_template |
| 104 | static_104 | yes | 17 | 4096 × 4096 × 2048 | 1 | source_surface |
| 105 | static_105 | source-only | 0 | 4096 × 4096 × 0 | 1 | source_surface |
| 106 | static_106 | yes | 17 | 4096 × 4096 × 2048 | 1 | source_surface |
| 107 | static_107 | source-only | 0 | 4096 × 4096 × 0 | 1 | source_surface |
| 108 | static_108 | yes | 2 | 4096 × 600 × 488 | 4 | authored_mesh |
| 109 | static_109 | yes | 12 | 4096 × 4096 × 2048 | 1 | source_surface |
| 110 | static_110 | yes | 12 | 4096 × 4096 × 2048 | 1 | source_surface |
| 111 | static_111 | source-only | 0 | no vectors | 0 | source_command |
| 112 | static_112 | yes | 1 | 275 × 125 × 0 | 48 | source_surface |
| 113 | static_113 | yes | 1 | 275 × 50 × 0 | 32 | source_surface |
| 114 | static_114 | source-only | 0 | 4096 × 600 × 600 | 16 | authored_mesh |
| 115 | T-62 | yes | 0 | 116 × 332 × 91 | 977 | authored_mesh |
| 116 | T-62 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 117 | T-64 | yes | 0 | 116 × 332 × 121 | 1089 | authored_mesh |
| 118 | T-64 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 119 | T-72 | yes | 0 | 116 × 332 × 121 | 1089 | authored_mesh |
| 120 | T-72 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 121 | T-80 | yes | 0 | 76 × 220 × 80 | 1089 | authored_mesh |
| 122 | T-80 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 123 | F-ST | yes | 0 | 52 × 136 × 28 | 312 | conservative_refinement |
| 124 | F-ST | yes | 0 | 110 × 147 × 30 | 45 | conservative_refinement |
| 125 | M1-A1 | yes | 0 | 80 × 204 × 66 | 1242 | authored_mesh |
| 126 | M1-A1 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 127 | M60a3 | yes | 0 | 124 × 310 × 80 | 1130 | authored_mesh |
| 128 | M60a3 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 129 | M113 | yes | 0 | 76 × 130 × 52 | 795 | authored_mesh |
| 130 | M113 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 131 | M2 | yes | 0 | 76 × 150 × 52 | 986 | authored_mesh |
| 132 | M2 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 133 | BMP-1 | yes | 0 | 100 × 220 × 94 | 1032 | authored_mesh |
| 134 | BMP-1 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 135 | BMP-2 | yes | 0 | 64 × 146 × 62 | 1120 | authored_mesh |
| 136 | BMP-2 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 137 | BTR-70 | yes | 0 | 60 × 160 × 58 | 770 | authored_mesh |
| 138 | BTR-70 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 139 | ACRV-2 | yes | 0 | 60 × 142 × 66 | 1096 | authored_mesh |
| 140 | ACRV-2 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 141 | BRDM-2 | yes | 0 | 90 × 205 × 75 | 517 | authored_mesh |
| 142 | BRDM-2 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 143 | BRDM-3 | yes | 0 | 90 × 205 × 75 | 517 | authored_mesh |
| 144 | BRDM-3 | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 145 | COM STAT | yes | 0 | 360 × 209 × 130 | 213 | partial_opaque |
| 146 | COM STAT | yes | 0 | 360 × 209 × 100 | 344 | authored_mesh |
| 147 | Building | yes | 0 | 128 × 128 × 128 | 230 | authored_mesh |
| 148 | Building | yes | 0 | 110 × 147 × 30 | 187 | authored_mesh |
| 149 | Building | yes | 0 | 128 × 128 × 128 | 230 | authored_mesh |
| 150 | Building | yes | 0 | 110 × 147 × 30 | 177 | authored_mesh |
| 151 | Building | yes | 0 | 240 × 158 × 120 | 222 | authored_mesh |
| 152 | Building | yes | 0 | 110 × 147 × 30 | 207 | authored_mesh |
| 153 | ENEMY HQ | yes | 0 | 2612 × 2080 × 650 | 512 | partial_opaque |
| 154 | ENEMY HQ | yes | 0 | 2612 × 2080 × 200 | 646 | authored_mesh |
| 155 | Base | yes | 0 | 256 × 256 × 256 | 352 | authored_mesh |
| 156 | Base | yes | 0 | 2612 × 2560 × 650 | 2024 | partial_opaque |
| 157 | Farm | yes | 0 | 850 × 550 × 207 | 436 | authored_mesh |
| 158 | Farm | yes | 0 | 850 × 550 × 130 | 666 | authored_mesh |
| 159 | Truck | yes | 0 | 90 × 190 × 105 | 584 | authored_mesh |
| 160 | Truck | yes | 0 | 110 × 147 × 30 | 45 | authored_mesh |
| 161 | SAGGER | yes | 0 | 75 × 21 × 115 | 501 | partial_opaque |
| 162 | SPIGOT | yes | 0 | 75 × 21 × 115 | 501 | partial_opaque |
| 163 | HIND | yes | 0 | 400 × 728 × 220 | 344 | authored_mesh |
| 164 | HIND | yes | 0 | 580 × 720 × 220 | 344 | authored_mesh |
| 165 | A10 | yes | 0 | 256 × 256 × 256 | 12 | unresolved_placeholder |
| 166 | MIGS | yes | 0 | 64 × 64 × 64 | 12 | unresolved_placeholder |
| 167 | Bridge | yes | 0 | 0 × 0 × 702 | 0 | source_control_invisible |
| 168 | static_168 | source-only | 0 | no vectors | 0 | source_command |
| 169 | static_169 | source-only | 0 | no vectors | 0 | source_command |
| 170 | static_170 | source-only | 0 | no vectors | 0 | source_command |
| 171 | static_171 | source-only | 0 | no vectors | 0 | source_command |
| 172 | static_172 | source-only | 0 | no vectors | 0 | source_command |
| 173 | static_173 | source-only | 0 | no vectors | 0 | source_command |
| 174 | static_174 | source-only | 0 | no vectors | 0 | source_command |
| 175 | static_175 | source-only | 0 | no vectors | 0 | source_command |
| 176 | static_176 | source-only | 0 | no vectors | 0 | source_command |
| 177 | static_177 | source-only | 0 | no vectors | 0 | source_command |
| 178 | static_178 | source-only | 0 | no vectors | 0 | source_command |
| 179 | static_179 | source-only | 0 | no vectors | 0 | source_command |
| 180 | static_180 | source-only | 0 | no vectors | 0 | source_command |
| 181 | static_181 | source-only | 0 | no vectors | 0 | source_command |
| 182 | static_182 | source-only | 0 | no vectors | 0 | source_command |
| 183 | static_183 | source-only | 0 | no vectors | 0 | source_command |
| 184 | static_184 | source-only | 0 | no vectors | 0 | source_command |
| 185 | static_185 | source-only | 0 | no vectors | 0 | source_command |
| 186 | static_186 | source-only | 0 | no vectors | 0 | source_command |
| 187 | static_187 | source-only | 0 | no vectors | 0 | source_command |


## Bounded completion investigation, 28 September 2026

### Meaningful component authoring

T-62, T-64, T-72, T-80, M1 and M60 turret groups now truncate shared corners into broad continuous facets. Each old face owns its portion of the shared corner cap. Their existing group pivots, selection roots and component envelopes remain unchanged. These are low-poly source-local refinements rather than historical replacement anatomy. Their main guns now have octagonal cross-sections, preserving source barrel length, muzzle position, slanted breech and original open rear. Each original side owns half the adjacent diagonal facet; the muzzle fan shares the exact split rim without topology T-junctions. No antenna or line primitive was thickened.

Wheel front caps and hub front caps carry optional `motion: {kind: "wheel", center: [x,y,z], radius: number}`. Center and radius are original-local authored geometry values. Both use full roadwheel radius. Sidewalls and rear caps have no motion tag. The renderer owns source-position-anchored decorative markings, with no wheel travel/physics assertion.

### Visible round-form authoring identities

| Shape | Command offset | Four bytes | Raw center | Raw radius | Source color index |
| --- | --- | --- | --- | --- | --- |
| 145 COM STAT | 25372 | 1c1e001d | 200,24,100 | 30 | 0 |
| 153 HQ | 27185 | 2e64002f | 500,-440,350 | 100 | 0 |
| 156 Base replacement | 28333 | 2e64002f | 1000,-100,350 | 100 | 0 |
| 161 SAGGER | 30996 | aa0f02ab | 0,0,0 | 15 | 2 |
| 162 SPIGOT | 31422 | aa0f02ab | 0,0,0 | 15 | 2 |

These commands are genuinely visible geometry, not selection/control metadata. `visual_commands` exports exact command bytes, encoded sort vector, encoded center vertex, decoded center, radius and source color. Shape111 also has six round commands (raw sizes250/200/100, color1), retained without guessing a semantic sky-object identity. The polygon meshes remain `partial_opaque` in the mesh register; runtime source spans now supply the complementary visible forms without invented polygons.

Original `0b4d:31a6..324a` transforms the command center via `1a5c`, rejects the near plane, projects using original signed division, computes the unsigned projected radius from `(radius_byte << focal_shift) & 65535`, copies command color to DS:359D/359E, enables clipping DS:359B, and calls `0f8d:123e`. At raster entry SS:SP+0/+2 is far return `0b4d:3247`, +4 is projected radius word, +6/+8 are signed center x/y. Radius is first compared as signed: <=0 draws nothing, 1 takes the point path, positive values above102 clamp102. Nominal horizontal radius is r+floor(r/4). Actual coverage comes from the original integer scan tables and clipping, not an analytic ellipse. In particular full-width cap102 cases can emit no pixels because of original signed-byte comparisons at `1417..141b`; the oracle preserves this behavior.

### Stateless native transport and exact raster coverage

`abrams_trace.h` adds event46 at raster entry, event48 immediately before six span calls (`1446`, `1495`, `14c4`, `1573`, `15c2`, `15f1`) and point call `125f`, plus event47 at command return `0b4d:324a`. Entry snapshots are30bytes, spans18bytes; each is bounded, caller-validated and read-only. The original saved command DI and shape ES are recovered from exact stack depths20/20/16/18/18/14/14 respectively. Every span validates return3247 and original caller CS. There is no native pending field, so observer checkpoint ABI1 is unchanged.

Event46 is15 little-endian words: schema, command, owner, radius, centerx, centery, clipleft, cliptop, clipright, clipbottom, page, packedcolors, packedclip/fill, two command words. Event48 is9 words: schema, command, owner, y, left, width, page, patternA, patternB. Pattern words come from actual AX/DX; point color comes from DS:359D. `pc_render_trace.py` resolves the original dither pattern to exact palette-index runs `{y,left,right,color}` with right-exclusive edges, preserves source painter order, and rejects stale/malformed/unfinished attribution. Unsupported negative signed radius inputs retain their raw word and effective radius0.

`tools/modern_assets/opaque_probe.py` executed33 unmodified original projection cases for all11 commands, plus two bridge control modes. `round_span_probe.py` executed10 original raster cases: filled/outline, point radius1, zero/negative radius, cap102 visible clipping, source-empty cap102, lower/right clipping and fully offscreen. All6822 actual EGA-written pixels, including colors and absence of extra coverage, match the packet spans; all seven span/point sites are witnessed.

`native_round_hook.py` independently compiles the exact production header cheap-filter, round-form block and common command/return dispatch against read-only captured CPU state. The raster probe feeds715 actual original-instruction register/memory states through that compiled C++ code. All callback events, offsets, register arrays and snapshot bytes match; guest RAM and input registers are byte-identical before/after. Source-independent native tests also reject invalid caller IP/CS, segment, page, stack/shape bounds and odd scan row. This proves compiled callback transport; it does not claim a live DOSBox mission route reached an ellipse. Root's all-eight-scenario baseline comparison contained zero round forms and is a separate noninterference gate.

Final rebuilt core SHA256: `c35599ad83d01e4f1207191938102e837e1cd67d791b5f3c86ef7074a6ae190a`.
Production source/copied/manifest header SHA256: `81db86665acdbce88774104a9b0df535c9f271fca7e803ae5fde7c52870e1b2c`.
Builder manifest `round_form_event_schema:1` is required by the host loader. Core build exited0; no later native header changes or rebuilds occurred.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_pc_modern_assets tests.test_pc_vehicle_catalog tests.test_pc_round_form_trace tests.test_pc_render_trace tests.test_pc_observer_checkpoint -q
PYTHONPATH="$PWD/.runtime/pc-analysis-venv/lib/python3.14/site-packages" PYTHONDONTWRITEBYTECODE=1 python3 -m tools.modern_assets.round_span_probe --output-dir local-art/pc-modern
.runtime/pc-analysis-venv/bin/python3 -m tools.modern_assets.opaque_probe
```

Receipts: `local-art/pc-modern/opaque-command-proof.json`, `round-span-proof.json`, `round-form-fixture.json` and `trace-core-build.log`. The fixture includes immutable source fingerprints, captured-memory fingerprint, camera and palette, and is explicitly an isolated synthetic pose in disposable original CPU RAM. No original file or live guest state was changed.

### Final ambiguous-family dispositions

* **167 bridge marker:** high confidence source-control invisible. Its sole primitive33262 has prefix `[130,255,2]`; `0b4d:0553..0574` unconditionally skips color255 before projection. Both static/dynamic CPU paths execute the skip and never enter projection/raster. `source_control_invisible` replaces the earlier `source_line` classification. Actual static bridge structures108/114 retain their own meshes.
* **165 A10 /166 MIGS:** high confidence executable source cubes, shipped-mission visibility unverified. Read-only witness `artifacts/modern-pass-20260928/aircraft-research/REPORT.md` and `probe.json` execute full original actor allocation, subtype handling and ordinary mesh branch `0b4d:2867..28e7`; no source-shape writes occur, and original vertex reader returns all eight cube corners. This lane independently reran that probe successfully. Preserve ±128/±32 cubes; no aircraft anatomy or permanent-dormancy assertion is justified. Registry `unresolved_placeholder` records the unestablished production-aircraft identity, not a claim that the cubes are unreachable.
* **145/153/156/161/162:** high confidence visible round commands plus known polygon geometry. These are hybrid source-authoritative assets, with exact recorded spans supported; their mesh-only partial status is deliberately retained.
* **F-ST123/124:** conservative source form, real-world identity remains unknown. No additional identity claim was introduced.

## Artistic refinement, authoring revision 3

This pass refines the existing source-bound models. Tanks receive recessed octagonal roof hatches, rear-deck louvres placed behind the original turret envelope and dark recessed muzzle bores. APC upper hulls retain olive armour above their running gear. Both original Hind rotor states share framed front and side cockpit glazing plus cabin windows; their original rotor lines remain unchanged. Building openings use source-unit proportions, with restrained doors, plinths and eave bands. F-ST and the unconfirmed A10/MIGS cube entries remain byte-identical to revision 2, as do trees and source terrain surfaces. No photographic vehicle texture or external stowage is introduced.

Details are attributed to the owning original primitive and move strictly inward from its surface. Vehicle badges retain closed topology. Buried backs of facade/glazing details are omitted to control cost. The catalogue contains 19,334 triangles, compared with 15,782 previously; each refined tank remains below 1,500. These are total offline definition counts, not simultaneous draw counts.

The source asset author also inspected this pass. Reproducible native before/after sheets are produced by `godot/tests/preview_pc_modern_assets.gd` with `--before CATALOG --after CATALOG --output DIRECTORY`. It requires a native renderer and has a wall-clock deadline. Captures include both front/rear viewpoints for 21 models. Production renderer studies and actual scenario packets are checked separately. Evidence is under `artifacts/modern-pass-20260928/model-refinement/`.

Working if: source envelopes and primitive ownership tests pass, both Hind states retain their original rotor lines, rear grilles remain outside the turret footprint, APC skins have no coplanar wheel overlap, and native views show the details without changing source terrain or simulation.


## Full-roster polish, authoring revision 4

All 57 authored polygon definitions receive this pass, including intact vehicles, wrecks, bridges, military and civilian buildings, both Hind states and the two weapon-crew sheets. Colour separation now distinguishes tyre rubber, olive armour, canvas, equipment steel, plaster and stone. Wrecks retain their original damaged geometry with quieter, varied facets. The truck has framed cab glazing, headlights and a grille; both Hinds have restrained engine vents and upper intakes. F-ST receives only anonymous facet/material refinement.

Constant-width bevels remove uneven border thickness on long faces. Bridge decks remain exactly planar; broken spans retain their original gaps. Flat building roofs retain a concrete/stone finish, while clay is restricted to original pitched roof planes. Native inspection caught and repaired coplanar truck glazing and BRDM wheel/body faces. The BRDMs use their original wheel polygons rather than duplicate running gear.

The complete catalogue now contains 18,792 triangles, 542 fewer than revision 3. All source primitives, bounds, roots, selectors, lines and opaque commands remain identical. Trees, terrain and unresolved aircraft placeholders are unchanged. No photographic vehicle textures, new collision geometry or simulation edits were made.

The same author implemented and visually inspected this pass. The native preview utility now produces front/rear before-and-after sheets for all 57 definitions and five roster overviews. The production-renderer material study covers those 57 definitions plus hill and water references; it uses diagnostic poses and selected source roots, separately from actual mission-frame tests. Local evidence: `artifacts/modern-pass-20260928/model-polish-2/`.

Working if: all 57 definitions bind in the production renderer, source-plane and primitive-ownership checks pass, non-environment models remain untextured, and final native views show stable glazing and running gear.


## Landmark colours and weapon crews, authoring revision 5

The farm regains its warm ochre roof, green courtyard, pale gables and contrasting dark siding. Its annex has a slate roof. Flags are excluded from façade openings; the hangar door sits ahead of its recessed wall to avoid depth flicker. The gabled building regains its distinctive red ridge over dark roof slopes. Other buildings use separate warm plaster, cool limestone and painted-concrete palettes; headquarters and communication flags retain their red accents. These colours are baked into the catalogue and GLBs, so disabling surface variation no longer removes them. The renderer supplies only restrained surface grain, with no blanket brown roof tint.

Sagger and Spigot retain the original two-sided sheet geometry and poses, with brighter uniform facets, straps, chest pocket, belt, cuffs, hands, boots and framed equipment panels. The two palettes are subtly distinct. Colour regions partition the source polygons without overlapping layers, new coverage or invented body thickness. Their separate circular head commands remain source-rendered. The refined sheet fragments follow the observed original primitive painter slots inside the existing per-object ownership mask, avoiding depth flicker where flat arms cross the torso.

This pass changes eight intact building definitions and the two weapon crews. The catalogue contains 19,702 triangles in total. All source primitives, bounds, lines, selectors, roots, placements and round commands are unchanged, as are vehicles, wrecks, bridges, terrain and trees. Evidence is retained in `artifacts/modern-colour-crew-20260929/`. The implementing author also inspected the native before/after and production-renderer studies.

Working if: the farm remains orange-roofed and green-courted with surface variation disabled; crew patches preserve source area and planes; source painter-order reversal and restoration produce deterministic native pixels; later original objects still occlude the crew.
