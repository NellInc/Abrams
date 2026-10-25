# Modern source-bound asset register

## Tactical wreck-wheel polish, authoring revision 22

All 57 Tactical states were reviewed in 114 hash-verified current GLB views.
All sixteen wreck states have refreshed geometry and textures through fifteen
unique Blender masters plus the existing, strictly verified BRDM wreck alias.
The other 41 entries, model files and outside-slot atlas pixels remain exact,
including intact vehicles, buildings/farm/cow, crews/heads, aircraft and bridges.

Round wheel fittings had protruded through flattened wreck tyres/roadwheels.
Closed rim profiles now have a seated rear, raised lip and recessed well, with
rims and hubs following each wheel's existing damage. The tilted loose-wheel
hub caps clear both wheel faces by .15 raw units instead of competing coplanarly.
Tyre shapes, axle positions, bolt stations, suspension, broken tracks, armour,
weapons and all other wreck parts remain exact in both game and master recipes.
Existing tyre silhouettes, source attribution and gameplay poses remain.

Three regressions reproduced the round/flattened mismatch, flat rim profiles and
coplanar loose-wheel caps. Four focused pre-bake checks pass, including existing
family-specific silhouette and matching track-station checks. The implementing
lead reviewed its own pilots, 32 fresh textured GLB views, all four native
comparison sheets and detail highlights.

86 asset tests and 868 native after-checks pass. All 96 selected-state views have
zero forbidden pixels and byte-exact Modern baselines. All 197 Godot source hashes
remain exact. Original gameplay, hit regions, commands, heads, linework and
visibility boundaries are unchanged. No live-mission or full 57-state native
matrix is claimed. The original 41 retained states are checked byte-for-byte.

Catalogue: 96,399,853 bytes; 303,694 body plus
4,448 head triangles; maximum complete model
8,158. The rims add 3,936 body triangles across
sixteen states. Existing 8192-triangle, 96 MiB catalogue, five-bank, four-sampler
and 503,316,477 decoded-texture-byte budgets remain intact.

Evidence: `artifacts/tactical-wreck-fit-polish-20261019/acceptance.json`,
`scope-proof.json`, `geometry-prebake.json`, `authored.diff` and
`wreck-wheel-highlights.png`. Local only; no PCK rebuild, commit, push or publication.

## Tactical façade and slate polish, authoring revision 21

All 57 Tactical states were reviewed in 114 hash-verified current GLB views.
Six architectural states have fresh Blender masters, GLBs and PBR map sets:
command station (145), building (151), enemy HQ (153), both base states (155/156)
and farm (157). The other 51 entries, model files and outside-slot atlas pixels
remain exact, including all vehicles, crews/heads, bridges and ruins. The
refreshed farm retains the exact cow geometry and placement.

Existing gutters and downpipes were buried in opaque plaster. A small coherent
façade setback now exposes them inside the original footprint, with window/door
joinery and reveals kept together. Existing decoration clearance is reused, so
original stars and their supporting wall planes are unchanged. Pipe straps
embed into the actual façade rather than ending in empty space. Five restrained
slate tones distinguish roof pieces, with courses parallel to the eaves and
lapped downslope on both pitches. The original roof planes and silhouette remain.
Flags, the red ridge and all source linework remain authoritative.

Three focused regressions cover buried drainage, uniform slate and sideways
roof courses observed in a fresh reverse view.
An initial bracket depth failed the new seating check and was corrected; failed
logs are retained. The first complete candidate was superseded after reverse-view
review exposed sideways courses; its bakes, receipts and renders remain preserved.
Five pre-bake checks pass. Independent before/after recipe
comparison confirms all seven other architectural states and all other family
source files remain exact. The corrected shape-151 course layout adds 114
triangles; the other five counts are unchanged and all models remain below 8,192.

83 asset tests and 326 native after-checks pass. All 36 selected-state views have
zero forbidden pixels and byte-exact Modern baselines. The implementing lead
reviewed its own drainage/roof pilots, twelve fresh textured GLB views, both native
comparison sheets and highlights. All 197 Godot source hashes remain exact.
Original gameplay, hit regions, commands, head bindings and visibility boundaries
are unchanged. No live-mission or full 57-state native matrix is claimed.

Catalogue: 95,200,533 bytes; 299,758 body plus 4,448 head triangles; maximum
complete model 8,158. Existing 8,192-triangle, 96 MiB catalogue,
five-bank, four-sampler and 503,316,477 decoded-texture-byte budgets remain.
Evidence: `artifacts/tactical-roster-detail-polish-20261019/acceptance.json`,
`scope-proof.json`, `geometry-prebake.json`, `authored.diff` and
`surface-highlights.png`. Local only; no PCK rebuild, commit, push or publication.

## Tactical remaining-surface polish, authoring revision 20

The remaining 45 Tactical states were reviewed in 90 exact-current-export views.
Six states have refreshed Blender/GLB/PBR assets: BTR-70, BRDM-2, BRDM-3,
truck and both Hind rotor states. Five unique masters were baked; the second
Hind state uses the existing strictly verified filled-geometry alias. The other
51 catalogue entries, model files and outside-slot atlas pixels remain exact,
including all twelve just-corrected tracked vehicles, buildings, farm/cow,
ruins, crews/heads and bridges.

BTR doors, BRDM side periscopes and truck bonnet vents now face outward on both
sides and follow their finished armour. BTR/BRDM headlamp apertures clear the
bow with short mounting feet seated into the hull. Hind fin paint faces outward;
wing camouflage partitions the actual upper facets, preserving their total area
and original source owners without adding a hovering second skin. Original
rotor linework and equipment poses are retained.

A truck vent fit check exposed overlap with the engine-bay shell. The first
incomplete bake and failed checks are preserved. An independent read-only facet
analysis supplied a geometry-derived height limit; the implementing lead applied
it and reran the full panel/skin intersection proof. Every vent triangle clears
both shells in game and master geometry, minimum .0211473 raw units. No source
owner or visibility boundary was broadened to conceal the defect.

80 focused Python tests and 326 native after-checks pass. All 36 selected-state
views have zero forbidden pixels and byte-exact Modern baselines. The implementing
lead reviewed its own final pilots, twelve actual textured GLB views, both native
comparison sheets and detail highlights. All 197 Godot source hashes remain exact.
Original gameplay, hit regions, commands, heads, linework and visibility boundaries
are unchanged. No live-mission or full 57-state native matrix is claimed.

The pack contains 299,644 body plus 4,448
head triangles, maximum complete model 8,158.
Catalogue size is 95,120,082 bytes. Existing budgets remain 8,192
triangles per model, 96 MiB catalogue, five banks, four samplers and 503,316,477
decoded texture bytes with mipmaps.

Evidence: `artifacts/tactical-remaining-surface-polish-20261019/acceptance.json`,
`scope-proof.json`, `truck-clearance.json`, `authored.diff` and
`surface-highlights.png`. Local only; no PCK rebuild, commit, push or publication.

## Tactical running-gear polish, authoring revision 19

All 57 states were reviewed in 114 exact-current-export views. Twelve tracked
models have fresh Blender masters, GLBs and five-channel source maps: T-62,
T-64, T-72, T-80, F-ST, M1A1, M60A3, M113, Bradley, BMP-1, BMP-2 and ACRV-2.
The other 45 catalogue entries, recorded model files and outside-slot atlas
pixels remain exact, including wrecks, wheeled vehicles, aircraft, all scene
construction, cow, crews/heads, and source bridge/rotor/antenna linework.

The T-62 front idler no longer intersects its adjacent road wheel or carries
sprocket teeth. Its road-wheel span is tightened while retaining the existing
front-three-close, wider-rear-gap order described by the
[Army recognition manual](https://www.trngcmd.marines.mil/Portals/207/Docs/MCIS/ITEP/RITC-East/FM%20100-2-3.pdf).
Raw coordinates remain authored visual proportions, not physical measurements.
All twelve models now have closed dished smooth idlers, distinct integral-tooth
drive rims and recessed hubs. End-wheel centres/radii meet the actual track-loop
shoulders; both sides clear every adjacent road wheel by more than .25 raw units.
The drive master retains the exact game tooth stations, avoiding a different
baked silhouette. Existing drivetrain handedness and all weapon poses remain.

34 focused Python tests and 670 native after-checks pass. All 74 selected-state
views have zero forbidden pixels and byte-exact Modern baselines. New regression
checks cover wheel clearance, T-62 gap order, closed end-wheel topology, smooth
idlers, exact game/master teeth and chamfered-track fitting. The implementing lead
reviewed its own five final pilots, 24 fresh GLB views, three native comparison
sheets and additional T-62 side views. One test assertion message typo was fixed;
the original failed log is retained. All 197 Godot source hashes remain exact.
Original gameplay, hit regions, commands, linework and visibility boundaries are
unchanged. No live-mission or full 57-state native matrix is claimed.

The pack contains 299,524 body triangles plus 4,448 command-head triangles,
maximum complete model 8,158. Catalogue size is 95,073,533 bytes. The unchanged
budgets remain 8,192 triangles per model, 96 MiB catalogue, five banks, four
samplers and 503,316,477 decoded texture bytes with mipmaps.

Evidence: `artifacts/tactical-running-gear-polish-20261019/acceptance.json`,
`scope-proof.json`, `geometry-prebake.json`, `references.json`, `authored.diff`
and `native-wheel-highlights.png`. Local only; no PCK rebuild, commit, push or
publication.

## Tactical fitting quality pass, authoring revision 18

All 57 states were reviewed in 114 exact-current-GLB-verified views. Ten states
have fresh Blender masters, GLBs and five-channel source maps: T-62, T-64, T-72,
T-80, M60A3, M113, Bradley, ACRV-2 and the two cottage states (147/149). The other
47 entries, recorded model files and outside-slot atlas pixels remain exact.

Searchlight and sight assemblies now clear their actual finished turret casting.
Guards follow the relocated housings; searchlight stems and paired snorkel stays
and retaining bands attach to that skin. M113, Bradley and ACRV weapon pedestals
reach their supporting surfaces; the M60 sloping mount has a connected foot.
Weapons and aim are unchanged. Both game and baking masters use the same game-skin
seats. Cottage window reveals face into their openings, correcting 48 of 64
misoriented reveal triangles per cottage without changing their silhouette.

31 focused Python tests and 553 native after-checks pass. All 61 selected-state
views have zero forbidden pixels and byte-exact Modern baselines. The implementing
lead reviewed its own four Blender pilots, 20 final GLB views and three native
comparison sheets. All 197 Godot source hashes remain exact. Original gameplay,
hit regions, source groups, commands, linework and visibility boundaries are
unchanged. No live-mission or full 57-state native matrix is claimed.

The pack contains 298,436 body triangles plus 4,448 command-head triangles,
maximum complete model 8,190. Catalogue size is 94,715,182 bytes. Existing caps
remain: 8,192 triangles, 96 MiB catalogue, five texture banks, four samplers and
503,316,477 decoded texture bytes with mipmaps.

Evidence: `artifacts/tactical-fitting-quality-pass-20261018/acceptance.json`,
`scope-proof.json`, `baseline-export-provenance.json`, `authored.diff` and
`export-highlights.png`. Completed 2026-10-19, local only; no PCK rebuild, commit,
push or publication.

## Tactical service and construction polish, authoring revision 17

The remaining 55 states were re-reviewed in 110 two-angle GLB views. Existing
captures were reused only after their exact current exported GLB hashes were
verified. Eighteen states have fresh Blender masters, GLBs and five-channel source
maps: nine armoured vehicles and nine building/farm states. The other 39 model
entries, their recorded asset files and outside-slot atlas pixels remain exact,
including the polished BMP launchers, crews/heads, bridge linework and truck.

Five tank families have fitted individual service-case lids, hinge pins and
latches. Nine armoured vehicles have recessed engine-grille beds, painted slats
and appropriate surrounds. The M1 uses its existing deck surround, retaining the
unchanged 8,192-triangle limit with an 8,190-triangle complete model.

Building façades, glazing and exterior roof skins now face outward; opening
reveals face into their recesses. Exact source eave elevations and cleaned gable
polygons remove reversed end slivers and restore omitted end triangles. Large
base 156 drops redundant flat-wall subdivisions to retain the existing geometry
cap. Roof-tile stations on 153/156/157, base 156 rafter tails and ruined-farm 158
foundation courses now match between game and baking masters, removing false
baked construction joints. Original flag, star and red roof-signal facets remain
source-authoritative. Cow geometry and all crew/head commands remain exact.

The complete pack has 298,108 body triangles plus 4,448 command-head triangles;
maximum complete model 8,190. Catalogue size is 94,587,389 bytes, below the
unchanged 96 MiB cap. Five texture banks, four samplers and 503,316,477 decoded
texture bytes with mipmaps are unchanged. All 197 Godot source hashes are exact.
Original gameplay, hit regions, source registry, roots, commands, line programs
and visibility boundaries are unchanged.

28 focused Python tests and 996 native after-checks pass. All 110 selected-state
views have zero forbidden pixels and byte-exact Modern baselines. The implementing
lead reviewed its own 36 final GLB views and five native comparison sheets.
Earlier checks exposed reversed gable slivers and a restored-geometry cap excess;
both were repaired without weakening the checks. The comparison-sheet selector
was corrected to use existing control-tank angles. No live mission, full 57-state
native matrix, new head-contract or simulation gate is claimed.

Evidence: `artifacts/tactical-roster-service-polish-20261018/acceptance.json`,
`scope-proof.json`, `baseline-export-provenance.json`, `authored.diff` and
`quality-highlights.png`. Local only; no PCK rebuild, commit, push or publication.

## Tactical launcher and attachment polish, authoring revision 16

All 57 current states were reviewed in 114 actual GLB views. Seven states were
refined through six fresh Blender masters and the proven Hind 164 alias. The
other 50 catalogue entries, their model-directory files and all atlas pixels
outside the selected slots remain byte-exact.

BMP-1 now has a channel-section launch rail, supporting shoes and pivot, a
stepped missile body, narrow nose probe and four closed swept fins. BMP-2 has a
separate pedestal, cross-axis pivot, cradle, clamped cylindrical canister, end
collars and recessed protective seals. All these parts retain original ATGM
group 3, with round sections built after the turret plan-view correction.
These remain visual approximations inside the original pose and source bounds.
The rail-launched Sagger identity is supported by the
[Army museum description](https://www.army.mil/article/220341); the distinct
BMP-2 roof-mounted ATGM is described in the
[November/December 1983 Infantry issue](https://www.benning.army.mil/infantry/magazine/issues/1983/NOV-DEC/pdfs/NOV-DEC1983.pdf).
No missile simulation, aim, firing behaviour or ammunition changes are made.

BTR/BRDM wiper arms and blades now derive their anchors from the actual finished
windscreen surfaces. Hind left cabin glazing/frame winding faces out, and its
closed undercarriage doors and seams follow the rounded fuselage skin. The
original line-only main rotor and antenna programs remain untouched.

The complete pack has 296,620 body triangles plus 4,448 command-head triangles;
maximum complete model 8,178, below the unchanged 8,192 cap. Catalogue size is
94,283,653 bytes, below the unchanged 96 MiB cap. Five banks, four samplers and
503,316,477 decoded texture bytes with mipmaps are unchanged. All 197 Godot
source-file hashes remain exact. Six masters have fresh albedo, tangent-normal,
AO, roughness and metallic maps, with existing atlas slots retained.

25 focused Python tests and 381 native after-checks pass. All 42 selected-state
views have zero forbidden pixels and byte-exact Modern baselines. The implementing
lead reviewed its own 14 final GLB views and two native comparison sheets.
Pre-bake wiper-coordinate and overly strict skin-contact checks were corrected;
rejected/superseded evidence is retained separately. No live mission, full-roster
native matrix, new head-contract or simulation gate is claimed.

Evidence: `artifacts/tactical-attachment-polish-20261018/acceptance.json`,
`scope-proof.json`, `authored.diff` and `bmp-launcher-comparison.png`.
Local only. No PCK rebuild, commit, push or publication by this pass.

## Tactical family and collapse quality pass, authoring revision 15

The full 57-state roster was reviewed in 114 actual GLB views. This pass refines
24 states with 23 fresh Blender/GLB/map masters and one verified BRDM alias;
33 catalogue entries and all atlas pixels outside the selected slots stay exact.
The polished truck, farm, cow, cabin, aircraft and command-bound crews are among
the retained models.

Wrecks now retain more of their intact vehicle-family identity: angular Abrams
cheeks/bustle, different Soviet and M60 cast profiles, F-ST pod remnants, M113
cargo-hatch returns, an angular Bradley turret, and distinct BMP turret/gun
remnants. Damaged wheels have smoother circumferences and family-specific sizes.
Game/master wreck track-shoe stations now match, removing false baked joints.
Five former wreck aliases are distinct masters. Fifteen wreck masters fit the
existing sixteen-slot atlas; the two remaining whole-pack aliases are Hind 164
and BRDM 144. Current authoring metadata supersedes obsolete alias claims while
retaining historical scoped patch records.

Five carriers have driver-hatch vision coamings/glass, rear hinge knuckles and
service latches fitted to their actual hull/access-panel geometry. Collapsed
buildings 148/150/152 have short chipped slabs, staggered breaks and varied yaw,
15 grounded masonry fragments, fallen timber and tile fans. Their original
mound poses, floor ownership and source bounds remain authoritative.

The complete pack has 294,840 body triangles plus 4,448 command-head triangles.
Its maximum complete model remains 8,178, below the unchanged 8,192 cap.
Catalogue size is 93,714,174 bytes, below the unchanged 96 MiB cap. Five texture
banks, four samplers and 503,316,477 decoded texture bytes including mipmaps
remain unchanged. No runtime/gameplay source, source registry, original command,
line, hit region, collider or simulation entity is changed by this pass.

23 Python tests and 1,304 native after-checks pass. All 144 selected-state views
have zero forbidden pixels, with 144 byte-exact Modern baseline captures. All
Godot source hashes remain exact. The implementing lead reviewed its own 48 final
GLB views and four native before/after sheets. The first ruin pilot had overly
regular slab rows; rejected output is preserved separately, and the accepted
recipe varies spacing and orientation. These are model/source-packet studies;
no live-mission, full 57-state native matrix or new head-contract run is claimed.
The crew entries, head geometry, maps and runtime remain exact.

Local only. No PCK rebuild, commit, push or publication by this pass.
Evidence: `artifacts/tactical-model-quality-pass-20261018/acceptance.json`,
`scope-proof.json`, `audit.json`, `authored.diff` and `review/roster-01.png`
through `review/roster-04.png`.


## Remaining Tactical roster finishing, authoring revision 14

All 55 remaining authored states now have fresh surface finishing: 48 unique
Blender masters and seven verified exact-geometry aliases. The recently finished
truck 159 and ruined farm 158 retain exact catalogue entries and atlas pixels.

Tracked armour uses matching game/master track-shoe stations, removing baked
false joints. BTR/BRDM tyres have broader rubber chevrons, smoother circumference
and matching six-nut hubs; front/side glass bake rays face outward. Armour paint,
cloth, skin and masonry have quieter variation, localized contact dust and edge
wear. Wreck oxidation follows damaged edges with soot in lower bays. Hind baking
masters have smoother fuselage and canopy shading. Existing crew poses and real
command-bound heads remain intact.

Hangar cladding uses broader ribbed sheets. Ruined roofs 146/154 have fractured,
staggered breaches; collapsed buildings 148/150/152 have grounded masonry and
irregular broken slabs inside their original floor ownership. Farm 157 has muted
grass and trampled paths toward its trough and cow. Bridge wear stays on original
deck planes; original gaps, flags, lines and source-only surfaces are retained.

The complete pack has 277,805 body triangles plus 4,448 command-head triangles.
Its largest model is 8,178, below the unchanged 8,192 limit. Catalogue size is
87,956,917 bytes, below the unchanged 96 MiB cap. Five banks, four samplers and
503,316,477 decoded texture bytes including mipmaps remain unchanged.

21 Python tests and 3,093 native after-checks pass. All 332 multiview studies have
zero forbidden pixels; those 332 Modern PNGs plus both complete-crew Modern PNGs
remain byte-exact. Both head contracts retain zero concealed-actor leaks and a
1,924-pixel negative-control response. Six relevant runtime/gameplay
source hashes remain exact. The implementing lead reviewed its own 110 exported
GLB renders and all ten native before/after sheets. These are source-packet model
studies, not a live-mission or full-simulation gate.

Pilot review exposed multi-object UV re-unwrapping after baking. Mesh selection
is now isolated, and saved body/head UVs match their bake receipt exactly. An
artifact preflight initially applied the textured-UV gate to the two deliberately
source-rendered flags. It was corrected to match existing pinned runtime
exclusions; flags, geometry, UVs and the strict body/head threshold are unchanged.
Rejected outputs and failed logs remain separate from accepted evidence.

Local only. No PCK rebuild, commit, push or publication by this pass.
Evidence: `artifacts/tactical-roster-polish-20261018/acceptance.json`,
`scope-proof.json`, `glb-visual-review.json` and `review/roster-01.png` through
`review/roster-10.png`.


## Truck and ruined farm finishing, authoring revision 13

The truck's radiator now has a real recessed cavity, open throat, inset slats
and chamfered apron edges. Its engine-bay front cap no longer fills the grille
opening. Smooth 48-segment game tyres receive broad rubber chevron tread from
64-segment baking masters. Both meshes have the same six wheel nuts, removing
false baked rim marks caused by the previous six/eight mismatch. Paint wear is
restrained, with dust concentrated around wheel arches and lower contact areas.

Ruined-farm rubble now has unequal counts, sizes, orientations and broken
profiles in each collapse cluster. Fallen roof sections have chipped outlines;
the standing roof's breached edges are staggered and fractured. All 466 roof
fracture triangles match between game and bake master. Ground dust uses the same
source-unit collapse centres as the rubble, with low-contrast irregular edges.
Every new yard fragment remains owned by original primitive 29245. No new actor,
collider, visibility owner or simulation entity is introduced.

Fresh editable Blender models, textured GLBs and five-map bake sets are installed.
Truck: 7,600 triangles. Ruined farm: 7,776. The unchanged limit is 8,192 per model.
Catalogue: 86,432,229 bytes, below the unchanged 96 MiB cap. The 55 other entries,
nine untouched bank maps and all pixels outside the two selected atlas slots
remain exact. Five banks and four texture samplers remain unchanged.

Eight focused Python tests and 109 native checks pass. Twelve views have zero
forbidden-coverage pixels, with twelve byte-exact Modern baseline captures.
Runtime/gameplay source hashes remain unchanged. The implementing lead reviewed
its own actual GLBs, tyre close-up and native captures. Early pale dust and
wheel-nut mismatch previews were corrected before installation. Sandbox startup
failures are retained separately from successful native/baking logs.

Local only. No PCK rebuild, commit, push or publication by this pass.
Evidence: `artifacts/tactical-truck-farm-polish-20261018/acceptance.json`,
`scope-proof.json`, `geometry-proof.json` and `native-before-after.png`.


## Tactical truck and ruined farmyard, authoring revision 12

Truck 159 now has an enclosed engine bay, upright split windscreen, rounded cab
shoulders, rolled mudguards and connected front wings. A full-width radiator
apron supports recessed circular lamps beside its framed grille. The original
seven body, screen, bonnet, tailgate, canvas and wheel visibility groups remain
independent. A glass-face winding error caught in the exported model was fixed
before installation; all eight glass-triangle texture samples retain blue glass.

Destroyed farm 158 has eight masonry collapse fans, 47 broken masonry chunks,
four fallen tiled roof sections and snapped rafters, with sparse pieces extending
into the yard. Every new fragment belongs to original yard primitive 29245.
The intact farm and cow remain exact. Original ruined-roof tile/hole topology is
retained. Reduced foundation segmentation and charred-frame cross-sections make
room for debris inside the existing budget. No actor, collider or simulation
entity is added.

Both editable Blender masters, GLBs and five-map bake sets are fresh. Truck has
5,820 runtime triangles; ruined farm has 7,990, below the unchanged 8,192 limit.
The catalogue is 85,946,167 bytes, below the unchanged 96 MiB cap. The 55 other
entries, nine untouched bank maps and pixels outside the two selected atlas
slots remain exact. Five banks and four samplers remain unchanged.

Eight focused Python tests and 109 native checks pass. Twelve fixed views have
zero forbidden-coverage pixels; all twelve Modern baseline PNGs remain byte-exact.
The implementing lead reviewed its own actual textured exports and native views.
This pass is local only, with no PCK rebuild, commit, push or publication.
Evidence: `artifacts/tactical-truck-farmyard-20261017/acceptance.json`,
`scope-proof.json`, `glass-bake-proof.json` and `native-before-after.png`.


## Modelled Tactical crew heads, authoring revision 11

Sagger and Spigot now contain actual textured 3D heads in their editable Blender
files and GLBs, as well as the Tactical renderer. Each named head mesh includes
a domed helmet, rolled rim, shaped jaw/cheeks, nose, ears, eyes and chinstrap.
This supersedes the earlier 2D-only head review, which left the exported models
headless. Each head has 2,224 triangles; each complete crew totals 5,128.

Head geometry is separate from source-polygon body geometry. It is admitted only
for the registry-pinned original root and independently observed head command,
with valid clipped spans and a safe presentation depth. Missing, unsupported or
ambiguous commands retain incumbent rendering. Its natural silhouette stays
inside original head ownership. Cutouts expose terrain without revealing actors
concealed by the original head mask. Modern retains its existing head path.

Both crew bake sets are fresh. Deletion-only finishing removed an oversized rear
backing; a documented subpixel iris-UV repair preserves all baked maps and keeps
the strict float32 UV threshold. Receipts retain the actual original bake producer
and derived-finishing hashes. Head maps share the existing crew atlas slots with
padded body/head regions. Five banks, four samplers and 503,316,477 decoded texture
bytes including mipmaps remain unchanged. Body geometry, all 55 other entries,
12 non-scene maps and scene pixels outside the two selected tiles stay exact.
The catalogue is 85,833,523 bytes, below the unchanged 96 MiB cap; the maximum
complete model remains below the unchanged 8,192-triangle limit.

Four focused Python tests and 267 native checks pass, including the current
159-check scene phase in 105.49 seconds under its unchanged 120-second guard.
Both real heads render; forbidden head changes and concealed-actor leaks are zero.
The concealed-actor negative control changes 1,924 pixels per crew when the
original head command is removed. Six original/Modern PNGs, including both
complete crews, remain byte-exact. A JSON numeric-array equality bug discovered
during loading was reproduced and corrected with numeric pin/root validation.
The implementing lead inspected its own actual GLB and native renders, with an
independent read-only review of the command/visibility contract.

Evidence: `artifacts/tactical-modelled-heads-20261017/acceptance.json`, native
captures, actual GLB preview and finishing receipts. Original simulation and hit
regions are unchanged. Status: local only; no PCK update, commit, push or
publication by this pass. No new full-roster view-matrix acceptance is claimed.

Working if: both standalone models visibly contain real heads, Tactical displays
them only under the original head command/ownership, cutouts reveal no concealed
actor, rejected packets retain exact fallback, and Modern restores identical pixels.


## Cow and crew refinement, authoring revision 10

A focused follow-up revises farm 157, Sagger 161 and Spigot 162. The cow now has
a continuous barrel, brisket and belly, a connected downturned face and muzzle,
tapered jointed legs, staggered stance and grounded split hooves. Broad piebald
patches follow the skin. Existing farm building and yard geometry stays exact;
the animal remains static decoration owned by original yard primitive 28751.

Crew limbs now follow joint-aligned cross-sections, with shaped shoulders,
knees, wrists, ankles and boots. Equipment gains stand-off carrying grips,
case catches, adjustment controls and recessed ocular glass/rims. The original
angular poses and strict source silhouettes remain; these are source-bound
refinements, with no claim of exact launcher-variant reconstruction. Original
round heads remain independently source-rendered. No actor, collision, animation,
weapon rule, hit region or gameplay behaviour changes.

All three editable Blender/GLB/five-channel sets were freshly baked. Runtime
triangle counts are 7,862 for the farm and 2,904 for each crew. A recorded offline
UV adjustment moves 24 tiny nostril-cap corners by at most 0.0165 source texels,
inside existing padding, preserving geometry and all five maps exactly. Runtime
UV checks remain strict. All 54 other catalogue entries, 12 non-scene maps and
scene-bank pixels outside the three selected tiles remain exact.

The installed catalogue is 83,920,408 bytes with 271,640 definition triangles.
The maximum state remains 8,178 triangles. The 8,192 per-model cap, 96 MiB
catalogue cap, five banks, four samplers and decoded texture allocation are
unchanged. This pass changes no runtime visibility or gameplay policy.

Four focused Python tests and 224 native checks pass under the unchanged
120-second guard. All 18 comparison Modern PNGs are byte-exact, with zero
forbidden Tactical pixels. Both crews pass corrected foreground-depth witnesses
with 32,371 actual interior samples each and zero submission-order mismatches;
depth-disabled negative controls change 1,242/828 pixels. Original head pixels,
head removal and unsupported-primitive fallback remain exact. This closes the
affected crew contracts without relabelling the older full-scene timeout as a pass.
The implementing lead inspected its own native before/after captures. Source
poses and edge-on coverage remain intentionally constrained by the original.

Evidence: `artifacts/tactical-cow-crews-refinement-20261017/acceptance.json`,
`scope-proof.json`, `comparison.json` and native captures. Status: local only.
No installed/browser PCK update, commit, push or publication belongs to this pass.

Working if: the cow has a coherent cattle profile, crew joints and controls read
more clearly, source-owned coverage and original heads stay exact, and switching
back to Modern restores identical pixels.


### Complete crew head review

Nell correctly identified that the revision-10 body/equipment studies had no
heads. Those fixture packets omitted the independent original round commands;
the standalone body GLBs also omit that source-rendered layer. Complete native
Tactical studies now include the original-CPU witnessed head spans for both
crews. Both helmet and face are visible with zero lost/outside head pixels;
22 focused native checks pass. The installed renderer and asset pack required
no change. This corrects the preview/review omission, not a demonstrated missing
head in live gameplay. The implementing lead inspected its own complete captures.
Evidence: `artifacts/tactical-crew-head-review-20261017/acceptance.json` and
`complete-crews.png`. These are source-witness model studies, not mission captures.


## Complete Tactical refinement, authoring revision 9

The farm now includes a static piebald cow, a trough and a braced gate. The cow
has a shaped torso, neck, muzzle, jointed legs, cloven hooves, ears, eyes, udder
and tail. It belongs exclusively to the original yard primitive 28751. The
destroyed farm has broken yard fittings and no animal remains. These additions
create no actor, collision, animation or simulation behaviour.

All 57 authored states receive geometry and material refinements. Buildings gain
roof closures, rafter ends, chimney/flashing details and fractured lintels.
Vehicles gain source-owned towing hardware, optics guards, boarding fittings,
wipers, hinges and restrained mechanical details appropriate to their existing
forms. Hind nacelles gain collars and heat shields; wrecks expose connected
mechanical structure. Bridge decks and hangar sheets gain construction joints
without changing their original surface coverage or lines.

Sagger and Spigot now have closed, shallow volumetric torsos, limbs, hands,
boots and bevelled equipment, with geometric cloth folds, webbing and pockets.
Their crossing arms sit ahead of the jacket on the usual viewing side. Each
crew uses 2,604 runtime triangles and a 7,632-triangle baking master. The
original independent round head command, pose, primitive admission and strict
source silhouette remain authoritative. Equipment is a conservative interpretation
inside the supplied source envelopes; no new missile or tripod silhouette is
invented. Ordinary opaque depth resolves the volumes, while flat bridges keep
their original painter policy. Pooled instances restore the appropriate policy.

All 50 unique Blender/GLB/master-map sets were freshly baked for revision 9;
seven aliases remain source-proven. Final crew-facing and projection corrections
are recorded as two scoped patches, retaining the other 55 entries, 12 other-bank
maps and every scene-map pixel outside the two crew slots exactly. Crew material
maps bake from the exact runtime shell, with a larger high-master normal cage
to prevent black projection misses. Earlier receipts retain their actual producer
hashes; full packing continues to reject stale receipts.

The installed catalogue is 83,749,195 bytes with 271,204 definition triangles.
The maximum individual model has 8,178 triangles, below the unchanged 8,192
limit. The 96 MiB catalogue cap, five existing banks, four samplers and
503,316,477-byte decoded texture allocation including mipmaps remain unchanged.
Original input inventory, hit regions, simulation, Modern catalogue/common
shader, source draw path and the inherited native deadline are preserved.

Working if: the cow reads as a constructed animal inside the original yard;
every authored state retains source custody; crew interiors have valid baked
material and depth-tested overlap; protected heads, flags and visibility remain
exact; and Modern restores without a pixel change.

Verification keeps the inherited 120-second guard. The required runner enumerates
all three scene-format rejection cases, each starting from a valid full roster;
the partial case also checks repeated pair fallback. Checked compact-JSON token
edits/model slices avoid repeated full fixture serialization. Native shard 0 has
mandatory scene and common/view phases, with distinct receipts. Their union
repeats three admission checks and one crew-to-vehicle pooled occluder witness.
The default combined test remains available. Crew depth-order interiors exclude
the actual captured empty frame, including its grey Compatibility clear colour.

Completed: 59 asset Python tests, 10 runner tests, 1,071,530 headless geometry/
binding checks, maps/size rejection, all three scene-format cases and schema-2
compatibility. The installed pack's 344-view equivalent matrix retains exact
Modern pixels; all 57 Tactical states change, with zero protected-pixel leaks.
It combines 115 final-pack captures and 229 byte-equivalent retained views;
all 103 rerendered peer views remain exact. Final native scene/common phases
initially passed 155/691 checks, alongside 646 in shard 5. A subsequent witness
review found that grey clear pixels were counted as foreground. The corrected
first crew has 38,548 actual interior samples and zero ordering mismatches, but
the complete corrected scene follow-up has twice hit the unchanged deadline
under severe CPU contention. This final follow-up remains pending a quieter
resource window; no aggregate green is claimed for it. Models/maps are installed
and their runtime hashes are verified. No foreign job was interrupted.

Evidence and final validation are recorded in
`artifacts/tactical-roster-refinement-20261017/acceptance.json`. The implementing
lead reviewed its own and delegated native captures. Status: local only. This
pass does not update installed/browser PCKs or publish the pack.


## Architecture, ruins and crew construction, authoring revisions 7 and 8

Nell approved the matching ruined cabin, the remaining buildings and destroyed
states, crew detailing and visibility-constrained grounding. Thirteen additional
architecture states now have source-owned construction: recessed openings and
sash joinery, masonry foundations, lapped slate/clay courses, rainwater fittings,
breached walls, exposed rafters and collapsed plaster/timber/tile fragments.
Cottage 149 shares the accepted 147 recipe with its own original primitive IDs.
Collapsed 148/150/152 retain their different low source envelope and pivot.

The rendered review caught lost landmark identity in the first candidate.
The final recipe retains the original headquarters/base stars, both exact
passthrough flags, communications flags, 151's red ridge and 157's green yard.
The communications building retains cool slate; the farm retains ochre clay
and its slate annex. All 15 changed states have fresh 2048-square master maps
and use their existing 1024-square scene slots. The accepted 147 geometry/maps,
34 vehicle states and seven bridges retain their exact catalogue entries.

Both crews receive tailored cloth planes, collars, webbing, pockets, cuffs,
hands, boots and restrained equipment detail. Their eleven nonempty original
painter sheets remain planar partitions with identical coverage and source
order. Original poses, angular outer outlines and separate head commands are
preserved. These are detailed sheet crews, with no claim of new volumetric
anatomy or historically exact launcher mechanisms inferred from source labels.

A six-percent lower-body/footing tint supplements baked AO on admitted vehicle
and building pixels. Whole-model authored height is carried in UV2.y for rigid,
affine and piecewise meshes, independently of camera-fit coefficients. Bounds
exclude passthrough flags. Aircraft and flat crew/bridge meshes are neutral;
zero-height bounds fail closed. The existing ownership discard is unchanged.
There is no projected ground shadow, terrain spill, extra sampler or guest-state
read. Modern, source hit regions, simulation and original inputs are unchanged.

The final catalogue is 77,069,055 bytes and 250,108 definition triangles. The
roster-only JSON admission cap is now 96 MiB; original 32 MiB readers, 57-state/five-
bank admission and 8,192-triangle per-model limits remain intact. The largest
new runtime model is 8,074 triangles. Texture dimensions/allocation are unchanged.
Native memory and timing are measured separately from browser/WASM suitability.

Scoped packing verifies the complete prior bundle and fresh selected receipts,
then replaces only those entries/tiles. Recipe provenance remains mixed and
explicit: architecture 8, crews 7, accepted cabin 6 and retained states 5. Full
`--pack` still rejects stale receipts. A pre-bake float32 atlas-area check now
repairs near-collinear insignia UV slivers inside texture padding; source
geometry stays exact and the runtime UV guard is retained.

Working if: all scene states admit with exact source custody; landmark colours,
flags and head commands remain visible; crew painter composites match both
orders; grounding changes no exterior/coverage pixels; Modern restores exactly;
and the unchanged native deadline and bounded catalogue rejection pass.

Accepted locally: 66 Python tests, 988,804 full headless geometry/binding checks,
and the catalogue-size/scene-mutation/compatibility partitions pass. All six
native partitions finish under the unchanged 120-second guard, covering 344 views
and 4,010 checks with zero forbidden pixels. All 344 Modern images are byte-exact
against the preceding accepted matrix; 54 unchanged bridge/aircraft Tactical
images are also byte-exact. Four ordered crew composites have zero mismatches
across 5,477 overlap pixels each. Flag pixels remain exact at near/far scales.
Grounding on/off studies change no exterior or coverage pixels and remain
neutral for aircraft/flat crews. Texture allocation remains 503,316,477 bytes
including mipmaps. Representative synchronized Tactical renderer samples are
0.98 to 2.70 ms on this Mac; native process maximum RSS is 2.68 to 3.65 GB. These are
native diagnostic measurements, not browser/WASM or general gameplay benchmarks.

The implementing lead reviewed its own and delegated native captures. Evidence:
`artifacts/tactical-scene-finish-20261017/acceptance.json`, `scope-proof.json`,
`source-invariants.json`, `python.log`, `headless-{0,5,6,7}.log`, the six
`native-*.log`/reports, `after-views.log` and `scene-before-after.png`. Status:
local only. No installed/browser PCK update, commit, push or publication.

## Cabin 147 rebuild, authoring revision 6

Nell rejected the cube-like cabin in her 17 October screenshot. Shape 147 now
has a pitched roof with individual overlapping clay tiles and ridge caps,
rendered walls with actual window openings, deep jambs, timber-framed four-pane
glazing, projecting sills/drips, attic louvres, a panelled timber door with latch
and hinges, entrance steps, two-course stonework, eaves, gutters and downpipes.
The first native review caught aliasing on narrow door-plank UV islands; the
final continuous panelled leaf reads cleanly at Tactical scale.

This is a source-attributed geometry rebuild, replacing the previous 230
triangles with 6,116 runtime triangles inside the unchanged 8,192 limit and
original source envelope. The five source primitives, root/group identity,
original hit region and gameplay remain authoritative. Rigid group fitting
works from one observed original wall. Runtime shaders, masks and Modern were
not changed. Fresh albedo, normal, AO, roughness and metallic masters are baked
at 2048 square and packed into the cabin's existing 1024-square scene-bank tile.
The editable Blender master, GLB and maps are installed in the local pack.

`--patch-cabin` verifies the existing complete pack and a fresh shape-147 receipt
before replacing that model and its three runtime-map tile regions. The other
56 catalogue entries, every other bank and every pixel outside this tile remain
exact. Mixed recipe provenance is explicit in `authoring.json.scoped_patches`;
full `--pack` retains its strict fresh-bake requirements rather than relabelling
older bakes as current. No extra texture allocation or runtime sampler is added.

Working if: source-envelope/attribution tests pass, cabin windows have actual
recess depth and the roof has real pitch, the native door reads without grille
aliasing, all protected source pixels remain protected, and the other 56 states,
Modern and original game inputs remain unchanged.


Accepted locally: the final native partition covers 54 views, including all six
standard cabin poses, with zero forbidden pixels. All 54 Modern images and the
48 unaffected Tactical images are byte-identical to revision 5. Four matching-
camera studies and one single-observed-wall study pass 14 checks. Final native
runs passed in 40.71/14.58 seconds; the unchanged 120-second guard remains active.
Final headless admission/mapping passed 731,764 checks. The initial 64-test Python
suite passed; the final door/pack was then rechecked with five focused tests
after the pack write finished. An overlapping provisional pack result was
discarded. Original input inventory and renderer/catalogue/deadline hashes remain
unchanged. The implementing chat reviewed its own actual native captures.

Evidence: `artifacts/tactical-cabin-20261017/acceptance.json`, `scope-proof.json`,
`headless-final.log`, `native.log`, `after-views.log`, `python-final-stable.log`,
`cabin.png` and `cabin-before-after.png`. Status: local only. No installed-app or
browser PCK update, commit, push or publication belongs to this pass.

## Complete Tactical scene polish, authoring revision 5

Nell extended this pass to buildings, bridges and weapon crews as well as the
34 vehicle states. The complete optional pack now contains 57 authored geometry
states: the vehicle roster, bridge/structure shapes 0/1/45/46/47/108/114,
architecture 145 through 158, and crews 161/162. All receive newly baked albedo,
tangent normal, ambient occlusion, roughness and metallic maps. Fifty unique
editable Blender/GLB/master-map sets and seven verified aliases supply the pack.
Existing textured terrain and illustrated foliage retain their original paths;
unresolved A-10/MiG cubes remain explicit placeholders, with no invented aircraft.
The full 188-definition disposition is in the local model inventory.

The new offline material programme distinguishes painted equipment, exposed
metal, contact-worn tracks, rubber, woven canvas/webbing, timber, plaster,
coursed brick, roof tiles/slate, skin/leather, glazing and heat-damaged wreckage.
Generated coordinates normalize dust height across differently sized models.
Rain streaks are restricted to side-facing surfaces; paint microrelief and
roughness variation are restrained. Signal/flag colours bypass weathering.
Legacy red source roles on vehicle gun/rack sheets become painted equipment;
real scene signals retain their colours. New master welds and existing master
fasteners bake into the runtime maps without adding frame-time geometry.
Metallic baking follows the linked high-master socket, including dielectric dust.

The vehicle silhouettes and original static topology remain source-attributed.
Original partial-opaque status and round commands remain explicit. Both small
flag planes (153/27177 and 156/28325) stay in the incumbent authored renderer:
subpixel/collinear stars never enter the texture UV compiler. Their original
source writes receive protected byte 64, so another HQ part cannot paint over
them. Pinned bridge line metadata is rejoined from the incumbent registry.

Schema 3 requires exactly 57 models and five fixed banks:

| Bank | Runtime dimensions | Tile |
|---|---|---|
| M1/T-62 | 2048 x 1024 | 1024 square |
| intact vehicles | 4096 x 4096 | 1024 square |
| wreck families | 2048 x 2048 | 512 square |
| architecture/crews | 4096 x 4096 | 1024 square |
| bridges | 2048 x 1024 | 512 square |

Each bank supplies albedo, normal and packed AO/roughness/metallic. The shader
still uses four samplers. Valid schema-2 vehicle packs retain their exact 34/3
contract. Any invalid complete pack clears all candidate state before loading
the independently validated legacy M1/T-62 pair. The legacy pair's catalogue
and map files remain untouched; its tiles inside the new complete pack have
the refreshed finish. The complete catalogue is 54,628,578 bytes and contains
179,158 definition triangles, inside the unchanged 64 MiB/8,192-per-model limits.

Static models keep strict original-owner coverage. Vehicle silhouettes retain
the accepted earlier-background rule. Coplanar bridges and crews submit per
observed primitive into an ordered flat variant, with fully opaque output,
depth testing disabled and source-layer render priority. Flat-object admission
is all-or-nothing: an unsupported primitive or priority overflow selects the
complete incumbent painter path. Original line and head/round pixels remain
protected independently. Modern, simulation, hit regions and input are unchanged.

Working if: every admitted state binds its bank on group and face paths; all
scene and vehicle native views pass; isolated crew-face composites reproduce
both original primitive orders; observed heads and original flags remain exact;
malformed scene/UV/status data fail closed; schema-2 and pair fallback remain
valid; protected masks, Modern images and original inputs remain unchanged.


Accepted locally on 17 October 2026. The exact native union contains 344 distinct
views across all 57 states, with zero forbidden pixels. All 206 historical
vehicle Modern screenshots remain byte-identical, plus twelve repeated original
rotor-image comparisons. Twelve unmasked coverage studies have zero missing
eligible pixels and zero protected-pixel leaks. Both rotor states retain all
873/1,198 original line pixels. Four near/far flag studies retain 174/2,146 and
163/2,025 protected pixels with zero changes. Four native crew composites,
including reversed primitive order, each exercise 5,477 overlapping face pixels
with zero painter-order mismatches. Unsupported faces and priority overflow
retain the exact common-renderer fallback; observed head pixels remain exact.

The eight headless partitions passed 708,413 checks. The six native partitions
passed 3,992 GPU/pixel checks, all under the unchanged 120-second deadline
(54.03 to 106.90 seconds). Backend-independent schema/mapping assertions remain
in the required headless gate instead of being replayed in every native run.
The expanded two-partition attempt exceeded that guard after 51 views and is
retained as a failed, incomplete run. Two earlier combined format attempts also
exceeded it. The initial crew witness incorrectly counted viewport clear colour
as geometry; the corrected oracle captures the actual empty viewport and keeps
its overlap/order assertions. No deadline or acceptance criterion was weakened.

The final pack passed 53 asset tests and 10 validator tests; the updated
six-partition validator passed its ten tests again. Runtime manifest hashes,
all 50 finish receipts and their current builder hashes match. The original
reference inventory, Modern catalogue, common surface shader, legacy pair
catalogue/maps and deadline implementation retain their prior bytes. Decoded
new-pack texture allocation is 480 MiB including mipmaps on this native backend.
The implementing chat reviewed the actual native images; independent contract
advice was read-only and did not replace that verification.

Evidence: `artifacts/tactical-scene-polish-20261017/acceptance.json`,
`aggregation.json`, `format-acceptance.json`, all six `accepted-native-*.log`
files, `all-models.png`, `showcase.png` and `vehicles-before-after.png`.
Editable deliverables comprise 50 Blender masters, 57 expanded GLBs and 250
master maps. These are source-packet presentation studies, not a new live-game
or browser certification. No installed-app update, commit, push or publication
was performed. Status: local only.

## Complete Tactical vehicle roster

Nell extended the approved pair quality to the rest of the renderable vehicle
roster on 17 October 2026. The complete optional bundle is
`local-art/pc-tactical-roster-v1/`: 34 shapes, including sixteen intact ground
vehicles, sixteen wreck states and both original Hind rotor states. The accepted
M1A1/T-62 catalogue triangles, UVs and three map files are copied exactly.

`tools/build_pc_tactical_roster.py` coordinates the existing Blender authoring
helpers and five bounded geometry modules: tanks, tracked carriers, wheeled
vehicles, wrecks and Hind. Historical tank families have their own castings,
wheel sizes/spacing, hull profiles, engine arrangements and sight/cupola details.
Carriers use their distinct troop compartments, doors, hatches and armament
assemblies. Scouts have compound amphibious bows and crew glazing; the generic
6x6 truck has separate cab, bonnet, chassis, load bed and bowed canvas. Collapsed
wreck families have torn sheets, damaged running gear and open engine/interior
bays. F-ST and the game's BRDM-3 label retain source-defined equipment without
inventing a historical identity. The Hind has tandem curved canopies, rounded
fuselage sections, turbines, tail and source-owned stores. Its two line-only
rotor states remain the original engine's exact lines, with no new animation.

Original A-10/MiG shapes 165/166 are unresolved source placeholders without
usable aircraft geometry. They and weapon crews 161/162 are outside this vehicle
bundle and retain incumbent rendering. These are game-space renditions inside
original source envelopes, not dimensionally exact museum reconstructions.
Original hit regions remain unchanged. The detailed silhouette can extend
beyond the old raster outline over empty space and earlier terrain; other
original targets, later occluders and protected commands retain their pixels.

Each unique new model has an editable per-model `vehicle.blend`, standard GLB
and baked master maps. Intact maps are 2048 square, wreck maps 1024 square.
Exactly identical damaged families and Hind 164 share bakes only after ordered
source vertex/winding, owner group/root membership and authored positions,
triangulation/materials/UV basis are verified. Aliases are expanded into their
own source-attributed catalogue entries and GLB metadata during the build.
The alias evidence is in `authoring.json`; runtime has no alias chains.

Schema 2 admits an exact complete roster with three fixed texture banks:

| Bank | Runtime maps | Per-model tile |
|---|---|---|
| accepted pair | 2048 x 1024 | 1024 square |
| new intact | 4096 x 4096 | 1024 square |
| wreck families | 2048 x 2048 | 512 square |

Each bank contains sRGB albedo, linear tangent normal and linear packed
AO/roughness/metallic. The existing four-sampler material selects the shape's
bank on both group and per-face paths, including recycled instances. Assets
load only at preload/reload, with mipmaps generated once. Failed complete-bundle
admission clears all candidate state before independently validating the legacy
pair; failure of both retains incumbent rendering. The complete authored JSON
has a dedicated 64 MiB bounded allowance, while original registry reads retain their
32 MiB cap. The private runtime allowlist includes only the complete catalogue,
manifest and nine maps; editable masters and proof receipts stay local.

```sh
blender --background --factory-startup --python tools/build_pc_tactical_roster.py -- --resume
python3 tools/build_pc_tactical_roster.py --pack
```

Working if: the manifest admits exactly the 34 approved shapes and three fixed
banks; all filled owners have valid GPU meshes, absent groups stay absent,
pooled group/face draws bind the right bank, original line and round-command
pixels retain precedence, and Modern and original inputs remain unchanged.

The optional vehicle mask uses original queue IDs before terrain underpaint
reordering. Blue byte 8 guards every nonterrain object's ordinary source fill,
edge and bitmap pixels, including unsupported objects. Byte 0 remains empty
space or ordinary terrain, byte 64 marks independently observed two-point line
primitives from admitted models, and byte 255 marks round-command writes.
Compatibility encoding uses the established colour compensation. Default
ownership callers, Modern and disabled-detail fallback retain their old masks.

The dedicated vehicle shader accepts its own byte-8 pixels or earlier byte-0
background coverage. Every other classification is rejected. This removes the
old silhouette's self-trimming while protecting all other original target
pixels, later source owners, rotor lines and round writes. Later ordinary writes
still supersede earlier lines in original command order. No extra sampler,
viewport, authored-triangle CPU traversal or gameplay readback is introduced.
The common surface/water shader remains unchanged.

This is a pixel-local rendering contract. Original queue/group admission and
source-fitted poses remain unchanged. A queued model's expanded outline can
occupy previously empty pixels, including beyond an occluder's old footprint;
overlapping authored-only extensions use native mesh depth. Original targeting,
hit regions, damage, movement and input remain authoritative. This supersedes
the strict old-raster boundary recorded in the earlier acceptance sections.

Working if: the native unmasked-geometry reference has no missing eligible
pixels; later occluders and other original targets receive zero vehicle
coverage; bytes 0/8/64/255, owner 256, both actor queue orders, original rotors,
round commands, viewport clipping, cache hits and exact Modern/fallback image
and mask restoration pass.

### Visibility correction local acceptance, 17 October 2026

The implementing chat also inspected the native before/after and complete
34-state contact sheet. A read-only independent advisor reviewed the pixel-local
contract before implementation. The BRDM witness restores all 1,657 previously
trimmed coverage pixels. Twelve explicit white-coverage GPU comparisons have
zero missing eligible pixels and zero protected-source leaks, including earlier
and later terrain/targets, both same-shape queue orders, owner 256 and near/
viewport clipping. Original rotor sets retain all 873/1,198 pixels.

Both native partitions passed, with 685,591 and 685,652 checks in 60.52/48.88
seconds under the unchanged 120-second guard. Their exact union covers 206
views across all 34 states, with zero forbidden pixels. All 206 Modern PNGs
are byte-identical to the prior accepted quality pass. Cache, readiness fallback
and resize also restore exact image and mask bytes. Headless common/format
partition 0 passed 684,536 checks; 60 Python asset/validation-runner tests passed.
All original inputs, authored assets, accepted pair and common surface/water
shader remain unchanged. Initial fixture-only failures remain in the evidence;
the corrected full native partition runs all focused cases successfully.

Evidence: `artifacts/tactical-visibility-20261017/acceptance.json`,
`aggregation.json`, `native-1/visibility.json`, both native logs,
`brdm-before-after.png` and `fleet-mask-correction.png`. Status: local only.
No installed-app update, commit, push or publication was performed.

### Initial full roster local acceptance, 17 October 2026

The complete catalogue contains 170,430 triangles across 34 vehicle/state
models, with 1,902 to 7,814 per model. Its JSON is 51,132,383 bytes, inside the
64 MiB authored-catalogue allowance. Twenty-five new unique Blender master/bake
sets and seven proved aliases extend the two accepted models. Alias GLBs carry
the target shape's own metadata; source identity always comes from that target's
pinned registry entry.

Evidence in `artifacts/tactical-roster-20261017/`:

* `python-final.log`: 49 authoring/integration tests passed, including all 34
  bounds/filled-owner checks, wheel stations, aliases and exact accepted pair
  triangles/UVs/map bytes.
* `accepted-headless.log`: 680,246 checks, zero errors. Malformed, missing,
  duplicate and unexpected models, unknown banks, corrupt/missing maps,
  oversized JSON and full-roster-to-pair reloads fail closed.
* `verified-native.log`: 682,193 checks, zero errors. `verified-native/report.json`
  covers 206 front/rear/flank/quarter/near/far renderer studies over all 34
  states, zero owner escape, unchanged packets and exact Modern restoration.
  The GPU position check retains the two accepted models as independent CPU/GPU
  branch witnesses, with maximum error below 0.000551 original pixel.
* `verified-native/rotor-163.json` and `rotor-164.json`: all 873 and 1,198 black
  rotor-line pixels retained, zero loss, exact sampled marker byte 64. Native
  fixtures also verify later same-owner fill, other-owner fill and round-byte
  255 writes supersede the line marker, and Modern restores exactly.
* `source-pins.log`: all 68 original inputs unchanged. The incumbent Modern
  builder/catalogue, common surface/water shader and accepted pair catalogue
  retain their start-of-task hashes. `acceptance.json` records those hashes.

File-format rejection fixtures belong to the required headless tier. Native
checks reuse the admitted geometry and focus on GPU/pixel behavior instead of
repeating the large JSON fixtures. The existing 120-second verification
wall-clock bound remains enabled.

Decoded RGB maps with mipmaps occupy 276,824,061 bytes (approximately 264 MiB).
The native test records whole-renderer driver texture/video totals separately
in `allocation.json`. Its measured peak RSS includes test data and loader
checks, and does not establish steady-state game memory or mission FPS.
All work remains local; the installed app and public releases are unchanged.

## Tactical proportion quality pass, 17 October 2026

Nell identified the Bradley as too squat. The review of this chat's preceding
roster found eleven models with concrete silhouette/proportion corrections.
Bradley and M113 now have taller troop-body proportions, smaller circular road
wheels and full-height rear ramps. Bradley also has a substantial twin-TOW
housing with recessed apertures, firing ports and troop vision blocks. Its
height/width ratio moves from 0.67 to 0.93, consistent with the common proportions
in [BAE's Bradley sheet](https://www.baesystems.com/dam/jcr:d7fa3a19-f2a3-4aa1-8d77-f4e99835c2bc/DIGITAL_BAE_Print_USL_Landscape_Bradley%20A2%20ODS.pdf).
Later ODS/ERA/APS equipment is outside the game's early vehicle treatment.

M60's tall casting and enclosed cupola now read correctly over a narrower hull,
with circular wheels, five return rollers and toolboxes seated on the fenders.
BTR and BRDM bodies are less broad, with round tyres and correctly seated
fenders. Original BTR line-only armament still meets its mantlet. BRDM has a longer boat
hull, independently spaced round wheels and an open rack supporting its
source-pinned roof equipment. An initial inset of that thin equipment produced
visible mask slicing; its exact original placement is retained in the final art. BMP1/2 retain
low hulls and distinct single/two-man turrets; their ATGM assemblies sit close
to the roof. T64/72/80 keep their low silhouettes, with corrected gun overhang,
return-roller spacing and smooth master castings baked into the normal maps.

| Model | Prior height/width | Revised height/width |
|---|---:|---:|
| Bradley | 0.67 | 0.93 |
| M113 | 0.67 | 0.93 |
| M60A3 | 0.64 | 0.89 |
| BTR70 | 0.66 | 0.80 |
| BRDM2/source BRDM3 | 0.83 | 1.04 |

These are authored overall bounds, including source-defined roof equipment.
Original ceiling/ground planes and strict owner coverage remain authoritative.
Rebuilt horizontal dimensions and running gear establish the corrected ratios.
Original hit regions can still extend beyond the inset visible body. The
accepted M1A1/T62 pair, ACRV, F-ST, truck, Hind and collapsed wrecks retain their
preceding runtime geometry and maps. `quality-notes.md` and `dimensions.json`
in `artifacts/tactical-quality-20261017/` record the finite per-model disposition,
reference basis and exact before/after bounds. Authoring revision is now 4.

### Quality pass acceptance

`artifacts/tactical-quality-20261017/acceptance.json` records 171,594 triangles
and a 52,205,640-byte catalogue over the same 34 states. Eleven models changed;
the other 23 catalogue entries, including the accepted pair, remain exact.
The original 68 input files, incumbent Modern builder/catalogue, common
surface/water shader and accepted pair maps retain their preceding hashes.

* `python.log`: 50 asset/authoring tests passed, including the new proportions,
  round-wheel and source-pinned roof-equipment checks.
* `validation-runner-tests.log`: all 10 gate-registration/receipt tests passed.
* `format-0.log` through `format-5.log`: every format case passed. The common
  admission/group/mapping and legacy-pair tier has 684,536 checks; isolated
  missing, duplicate, unexpected-shape and unknown-bank reloads have 21 each;
  corrupt/missing maps and oversized JSON have 23. Each malformed-model case
  starts from a fresh valid full roster, then verifies atomic pair fallback.
* `native-0.log`/`native-1.log`: 685,591/685,573 checks, zero errors. The aggregate
  `native/report.json` has exactly 206 distinct expected views across all 34
  states, zero owner escape, unchanged packets and exact Modern restoration.
  Both rotor states retain all 873/1,198 measured source-line pixels.
* `bradley-before-after.png` uses identical cameras and row crops. The side,
  front and quarter fleet contact sheets show every corrected class.

Earlier unpartitioned native and combined-format attempts exceeded the existing
120-second deadline and remain recorded as failed attempts. An independent
read-only fixture review identified repeated large-JSON work. The standard
validator now registers six fixed headless cases and two complete native view
partitions. Every original check remains present, and the inherited deadline is
unchanged. The final format cases took 31.55 to 56.19 seconds; native parts took
107.15 and 78.22 seconds. These are verification runtimes on this workstation,
with no claim about mission FPS or steady-state game memory.

Working if: the validator lists all six format cases and both native partitions,
all expected case markers have terminal successful receipts under 120 seconds,
and their native report union is exactly the 206 expected views.

At that checkpoint the original owner mask still trimmed small tyre/fitting
edges in some quarter views. The subsequent visibility-mask correction above
releases that old outline over empty space and earlier terrain. Tyre geometry
and original targeting limits remain unchanged. All changes remain local, with
no installed-app update or public release.

## Optional Blender Tactical vehicle pair

The first bespoke Tactical pair is M1A1 (source shape 125) and T-62 (115).
`tools/build_pc_tactical_vehicles.py` authors the source-paired geometry in
Blender, builds higher-detail masters, unwraps the game meshes and bakes colour,
tangent normals, ambient occlusion, roughness and metallic maps. Fine fasteners
belong to the baked master rather than the gameplay triangle stream. The original
source owner mask remains the outer visibility limit. Revision 2 replaces the
old face outlines with independent visual proportions: sloped hulls, compound
turret profiles, separate track shoes, exposed wheels, cupolas and fittings.
Relative forms and proportions are guided by the
[GDLS M1A1 specifications](https://international.gdls.com/english/products/ABRAMS/M1A1.pdf)
and [Tucson museum T-62 references](https://www.tucsonmilitaryvehicle.org/exhibit/t-62-main-battle-tank/),
with the Bovington photograph used for cast turret and running-gear form.
Source units are still not reinterpreted as physical metres.
Reference photographs guide form and are not copied into texture pixels.

The editable project and standard glTF exports live under
`local-art/pc-tactical-vehicles-v1/`. These Blender exports use raw source units
divided by 64 and glTF's ordinary Y-up convention. The incumbent catalogue and
its raw-z-up GLB exports are unchanged. Two 2048-square master texture sets are
packed into three 2048 by 1024 runtime atlases: sRGB albedo, linear OpenGL tangent
normals, and linear R=AO/G=roughness/B=metallic. UV V is explicitly converted to
PNG coordinates. The private runtime allowlist includes only the catalogue,
manifest and three atlases, keeping the editable masters local.

`pc_tactical_vehicle_assets.gd` validates the complete pinned incumbent registry,
joins just the approved pair and rejects an incomplete pair or mismatched map.
`pc_tactical_vehicle_view.gd` retains immutable meshes per original source group
and per face. A complete hull, turret or gun is admitted independently only when
an actually observed filled face supplies a near-rigid affine pose and that pose
matches every observed vertex in its own group within the existing 0.25 source
pixel tolerance. Candidate order is fixed by source area, never queue order.
Axis scale ratios and normalized cross-axis dot products must stay within two
percent. Piecewise face fits are never extrapolated to an entire part. A failed
group retains the earlier per-face GPU path; an absent group has no inferred
pose. Successful groups suppress their incumbent filled faces before source
fallback emission. Original lines and round writes are retained. This avoids
CPU triangle expansion. A separate four-sampler shader
keeps the Compatibility battlefield shader within its sampler limit, and rejects
every fragment owned by another source object or an observed round command.
No new simulation, visibility, turret state or shadow is introduced.
Original hit regions and projectile rules stay unchanged. The visual body can
be inset from those hit regions; this does not establish pixel-for-pixel aiming
equivalence. The strict owner mask can also trim an outward fitting in some
views. These are deliberate limits of the gameplay-preserving visual layer.

Authoring commands, from the checkout root:

```sh
blender --background --factory-startup --python tools/build_pc_tactical_vehicles.py -- --output local-art/pc-tactical-vehicles-v1
python3 tools/build_pc_tactical_vehicles.py --pack
```

The optional `test_pc_tactical_vehicles.gd` gate checks schema rejection, UVs,
actual GPU positions against the CPU source-fit equations, source ownership,
round writes, independent actors, pooled-face clearing and exact Modern mode
restoration. Its native images are renderer studies, not mission captures. It
also records uncached CPU application cost and an ABBA synchronized-renderer
timing comparison, neither of which establishes gameplay FPS.

### Revision 2 local acceptance, 17 October 2026

Nell requested more realistic silhouettes and proportions while preserving the
original gameplay. The pair was rebuilt around independent hull, turret, gun
and roof-gun geometry. Runtime counts are 7,122 T-62 and 7,814 M1A1 triangles,
below the existing 8,192-per-model loader cap. Fine fasteners and top track pads
are baked from the masters. The coarse roof-gun sheets are replaced, and a
validated authored empty face no longer restores an obsolete incumbent plane.

The final native gate passed 59,634 checks with zero errors across fourteen
model views, near/edge clipping, two actors, later occluders, round writes,
missing/inconsistent groups, independent group movement and anchor switching.
All fourteen Modern images are pixel-identical to the previous accepted baseline.
Every model view reported zero outside-owner pixels. Actual GPU readback checked
66,315 vertices per case, including 44,808 group-mesh vertices and a 35-face
piecewise fallback case. Maximum projected error was below 0.000551 original
pixels. Replaying the original gunner capture admitted eight independently
observed groups across two T-62 actors, with maximum group anchor error below
0.073 original pixels.

Uncached model-study CPU medians were 32.52/2.96 ms for incumbent/new T-62 and
41.13/3.99 ms for incumbent/new M1A1. These are application timings, not gameplay
FPS or a renderer-speedup claim. Final native receipts, PNGs and JSON are in
`artifacts/tactical-proportions-20261017/accepted/`; the Blender geometry studies
and diagnostic failures remain alongside them. The same author produced and
reviewed this work. The original visibility mask remains a visible constraint
on outward fittings. No exact visual-hitbox equivalence or full-mission parity
claim is made.

The final source kit passed 210 tests with 22 skips and 551 files; the three
final authoring checks passed. The original-game viewer completed 36 samples
into SIM's gunner view using the existing mission snapshot, reported 14,681
presentation triangles and no source fallback faces, and emitted its capture
receipt without script or shader errors. This was a fresh viewer process, not
a cold original-game boot. All 68 pinned original inputs, the incumbent
catalogue and its builder remain unchanged. Runtime manifests and the Blender
builder fingerprint match the delivered local assets. No standalone app or
published build was updated.

Working if: the four parts follow their independently validated original poses,
missing groups remain absent, a bad group uses face fallback without stale
incumbent sheets, all native checks pass, and source-mask and Modern-mode
comparisons retain the results above.

### Revision 1 local acceptance, 17 October 2026

The authored pair contains 3,312 T-62 and 3,496 M1A1 runtime triangles. The
Blender masters and the mechanical review were produced in this session by the
same author. Native Compatibility validation on Apple M1 Max passed 27,410
checks across fourteen model views. An additional near-plane, viewport-edge
and ownership run passed 27,301 checks. Both runs reported zero errors; all
fourteen views reported zero outside-owner pixels. GPU position readback covered
8,446 corners in each affine and perturbed case, including 35 piecewise faces;
maximum source-screen error was below 0.000575 original pixels. Modern images
restored exactly after switching out of Tactical.

The original-game viewer also completed a captured gunner approach using the
existing mission snapshot. Its two observed T-62 actors use the new meshes;
the large foreground M113 remains an incumbent asset. This is startup and
integration evidence, not a full mission or cold original-game boot. Evidence
is in `artifacts/tactical-vehicles-20261017/accepted/`, `bounds/` and
`original-approach/`. Uncached model-study CPU application medians changed from
25.4 to 2.35 ms for T-62 and 29.8 to 2.59 ms for M1A1. These timings are not
gameplay FPS. Synchronized-renderer ABBA measurements were noisy and do not
establish a renderer speedup.

The two final Python authoring checks passed, incumbent Modern passed 17,124
headless checks, and source mapping reuse passed 119,322 checks. The clean-source
kit passed 210 tests with 22 skips and 551 files. All 68 original input pins,
the incumbent catalogue and its builder remain unchanged. The broader graphics
mode gate is incomplete: its pre-existing cockpit report references missing
`ui-baseline-frame-00029-mask.png`, causing a null-image error at
`test_pc_graphics_modes.gd:70`. Its stalled task-owned process was stopped;
no fixture was fabricated or re-pinned. The focused native mode-restoration
checks above passed independently. No standalone app or published build was
updated; these outputs are local only.

Working if: the optional pair loads atomically, its native gate reports zero
errors and zero outside-owner pixels, GPU coordinate error stays within the
source-fit tolerance, and other modes retain their incumbent geometry.

## Scope and authority

The sections below describe the incumbent Modern catalogue. The optional
Tactical pair's later authoring and runtime evidence are recorded above.

Local authoring lane for the Modern implementation approved in the current task. The older plan-only language in the initial contprompt describes the earlier concept pass; it does not describe the current delegated authoring scope. This register covers geometry production and source identity. It makes no runtime, taste-approval, distribution-rights or finished-game acceptance claim.

The assets were produced by the same author who performed their mechanical review. The approved low-poly concept guides the broad facets, olive finish, continuous track bands and polygonal wheels. Every dimension comes from the local PC source geometry. No historical metre dimensions, guessed model identities, new terrain, cover or independent articulation were introduced.

## Deliverables and rebuild

* `tools/build_pc_modern_assets.py`: editable, deterministic procedural source, standard library only.
* `tests/test_pc_modern_assets.py`: independent geometric fixtures and separate local-corpus integration checks.
* `local-art/pc-modern/catalog.json`: runtime mesh contract. It carries the authored meshes and no SHAPE.TBL decode.
* `local-art/pc-modern/source-shapes.json`: the source shape registry, a pure decode of the player's own SHAPE.TBL (`source_registry()`). It is never published; the Web edition derives it in the browser and the native import derives it on the player's machine.
* `local-art/pc-modern/models/NNN.glb`: editable geometry previews in original raw axes and units.
* `local-art/pc-modern/manifest.json`: source fingerprints, catalogue hash, counts and explicit completion categories.

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/build_pc_modern_assets.py
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest tests.test_pc_modern_assets -v
```

Outputs remain in ignored local-art. No original resources, executable bytes, scenarios or world placements are modified. The generator validates SIM.EXE, SHAPE.GI and SHAPE.TBL against the existing pinned source hashes. Sixteen scenario resource hashes record the inventory input; campaign changes may legitimately alter the SSS files, so these hashes are provenance rather than a runtime compatibility lock.

## Mesh contract, schema 1

Top level: `schema`, `authoring_revision`, `sources`, `classes`, `inventory`, `materials`, `models`, `coordinate_contract`, `visibility_contract`, `source_registry` (the registry pin, below).

Each model is indexed by source `shape_index`. `class_roles` preserves every class-table primary, alternate and replacement association. `scenario_placements` counts the eight WLDs separately. `required` means present in those world files or referenced by the full class table, including player and special classes absent from SSS actor records.

`source_primitives` is a list of `{id, prefix_bytes, vertices}` in the exact decoded primitive order. The `id` is the absolute offset in decoded SHAPE.TBL. Vertices are produced by the existing `primitive_vertices` decoder, including signed arithmetic and packed-vector conversion. `selectors`, `roots`, `groups` and `opaque_commands` retain the source structure. `source_lines` retains line and degenerate polygon witnesses.

Since 2026-10-15 these six source fields (`selectors`, `roots`, `groups`, `source_primitives`, `opaque_commands`, `visual_commands`) are written to `source-shapes.json`, one entry per `shape_index`, and not to `catalog.json`. In the catalogue, each `source_lines` entry keeps only `source_primitive`, `source_groups` and an authored bridge `color`; its `vertices` (the cleaned primitive polygon) and `prefix_bytes` come back from the registry primitive. Class rows omit the raw SIM.EXE `raw_hex` table bytes, which no runtime reads. `catalog.json` pins the registry's SHA-256 under `source_registry`. `load_catalog()` (Python) and `load_catalogue()` (Godot) merge the two by `shape_index` and reject a missing, unpinned or foreign registry. They also reject a catalogue that still carries source fields. The in-memory `build()` result is unchanged, and `export()` refuses to write unless the stripped fields equal `source_registry()` of the local SHAPE.TBL. Authored triangles, including the triangulated `source_surface` faces of unrefined shapes, stay in the catalogue.

Working if: `tests.test_pc_modern_assets` proves split, merge and build are equivalent and that the published catalogue has no decoded key; `web-prototype/derived_art.mjs` reproduces `source-shapes.json` byte for byte; and `test_pc_modern.gd` rejects an unpinned, foreign or absent registry.

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

At authoring revision 9 the catalogue contains 188 models and 23,720 triangles in total (`local-art/pc-modern/manifest.json`, catalogue SHA-256 `438dfe23…`). The 19,702 figures above are the revision 5 and 7 totals. The revision 8 total was not separately recorded.

Working if: a rebuilt revision-9 catalogue reports 23,720 triangles, unless an authoring change is recorded here with its new total.

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

Event46 is15 little-endian words: schema, command, owner, radius, centerx, centery, clipleft, cliptop, clipright, clipbottom, page, packedcolors (DS:359D low byte, DS:359E high byte; `pc_render_trace.py` publishes round-form `colors` as [359E, 359D], the same order as polygon `colors`), packedclip/fill, two command words. Event48 is9 words: schema, command, owner, y, left, width, page, patternA, patternB. Pattern words come from actual AX/DX; point color comes from DS:359D. `pc_render_trace.py` resolves the original dither pattern to exact palette-index runs with right-exclusive edges: `{y,left,right,color}` for solid or equal-parity rows, and `{y,left,right,colors:[even-x colour, odd-x colour]}` (absolute screen x parity) for alternating dithers, which `pc_modern_source_commands.gd` `round_runs()` expands per pixel. It preserves source painter order and rejects stale/malformed/unfinished attribution. Unsupported negative signed radius inputs retain their raw word and effective radius0.

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


## User-identified vehicle silhouettes and formed feet, revision 28

Nell identifies F-ST 123/124 as Object 477A Molot. Its authored art now follows
that identity, superseding the anonymous artistic treatment above. This records
user-directed visual identity; it adds no executable provenance claim. Original
source labels, transforms and ownership are unchanged. M2 131 receives the compact
Bradley turret and twin TOW enclosure requested by Nell.

BRDM 141/143 uses the supplied 9P148 reference: five enclosed canisters on a central
pedestal and the auxiliary wheels stowed behind smooth lower side panels. Wreck
142 and its exact alias 144 follow that launcher arrangement. Crew 161/162 boots
now have formed toes, insteps, arches and heels in the editable Blender sculpt.
Eight masters produce nine revised states; all 48 other states remain exact.

Working if: these authored identities are visible in the editable masters and
installed GLBs while original labels, source commands and untouched art stay exact.


## Military vehicle camouflage, authoring revision 29

All 34 vehicle states receive new baked albedo through 32 editable Blender
masters. The existing BRDM-wreck and Hind aliases keep their donor bake basis.
NATO-style and Eastern-style woodland palettes distinguish vehicle families;
scorched surviving wreck plates retain family paint. The Hind underside, glazing,
rubber, tracks, bare metal, signals and woven truck cover keep their material
identities. Patterns are procedural and object-anchored, with no copied photographic
texture or external mesh.

All catalogue model entries, exported vertex attributes and indices, UVs and
non-colour maps remain exact. All 23 nonvehicle states are retained. Actual
colour-refresh provenance and the previous non-colour bake recipe are recorded
per master in `albedo_refresh`; existing surface maps have not been relabelled as
new bakes. Evidence: `artifacts/tactical-camouflage-20261020-r6/acceptance.json`.

Working if: the complete installed vehicle roster shows the new camouflage while
source commands, geometry, material separation and untouched assets remain intact.


## Further vehicle and formed-foot refinement, authoring revision 30

Eight Blender masters now produce nine revised states: Molot 123/124, Bradley
131, BRDM 141/143, wreck 142 and its alias 144, and operators 161/162. Molot has
a wider low turret shoulder, seated race, stepped central weapon hood, heavier
gun root and seven fuller road wheels. Bradley has a formed tapered mantlet,
seated turret and hatch collars, chamfered twin TOW case and connected pivots.
BRDM has five longer closed canisters with dust covers, retaining bands and
fitted saddles on a seated central pedestal. Its belly wheels remain stowed.
Both operators have lower toe boxes, raised narrow arches, fitted insteps and
distinct heels in the editable Blender sculpt. Matching wrecks retain family
features. Existing camouflage and original source ownership remain in place.

All eight masters have fresh full-resolution PBR bakes. The scoped installation
changes 83 files; 48 other states and every outside-slot pixel across 15 maps
remain exact. Eighteen focused Python checks pass. The implementing author
reviewed 18 Blender views and 42 native vehicle views, with 382 native checks
passing and no forbidden pixels. The original 68 inputs and 160 runtime source
pins remain exact. No package or publication is included.

Full runtime acceptance remains incomplete. Headless admission completes
1,223,094 checks without content errors but fails its unchanged 120-second
watchdog. The complete native crew scene also exceeds its unchanged external
120-second limit. These failed runs are retained and are not counted as passes.
Evidence and the local delivery receipt are under
`artifacts/tactical-model-refinement-20261020-r7/acceptance.json`.

Working if: the revised Blender masters and installed models show the requested
formed components, retained source and atlas invariants stay exact, and complete
runtime sign-off is withheld until both outstanding checks finish naturally
within their unchanged deadlines.


## Operator tailoring and normal-projection refinement, authoring revision 31

Sagger 161 and Spigot 162 receive a further Blender sculpt and retopology pass.
Slimmer arms, shaped grips and fitted cuffs meet their held controls. The head
sits further over the jacket neck, with a standing collar and folded leaves.
Twin pockets follow the curved cloth; the placket, belt loops and buckle have
formed relief. The control case has chamfered edges, with the manual stick and
optical housing remaining distinct. Boot toe-cap creases are sculpted into the
continuous leather last, retaining the formed toe, instep, arch and heel.

A close-up exposed a normal-projection artifact at the sleeve/jacket gap. A true
2048px pilot isolated the normal map as its cause and verified the tighter
0.012 Blender-unit crew-body cage with no black interior misses. The body max
ray distance is 0.04. Independent heads and all other families retain their prior
projection. Both operators have fresh five-channel bakes at 2048px body, 512px
head and 12 samples, with editable masters and packed GLBs. Normal maps remain
active. The final combined triangle totals are 7,999 and 8,091, below 8,192.

The scoped install changes 32 files. All 55 other states and every outside-slot
pixel across 15 maps remain exact. Thirteen focused Python tests and 69 native
crew assertions pass. The earlier open timing checks now also pass with the
updated pack: 1,225,006 headless admission checks in 38.6 seconds, and the complete
113-check native scene in 40.8 seconds. Both return naturally inside unchanged
120-second wall-clock guards. The source test assertions and runtime remain
unchanged; an iteration-count auto-quit is omitted from these bounded diagnostic
runs because it previously exited before async completion markers.

The author inspected its own ten final baked Blender views. Native fixed head
anchors are binding witnesses rather than complete mission-pose screenshots.
Evidence: `artifacts/tactical-crew-refinement-20261021-r8/acceptance.json`. Local
only, with no package rebuild or publication.

Working if: both installed operators show fitted clothing and continuous boots
with active normal maps, independent original head commands and all source
envelopes remain intact, 55 retained states stay exact, and the focused and
complete admission/scene checks finish naturally inside their existing limits.


## Formed operator grips and proportions, authoring revision 32

Sagger 161 and Spigot 162 receive explicit curved fingers, individual fingertips,
and mirrored opposed thumbs. The formed grip meshes remain outside the body
voxel-remesh step. Their closed, consistently wound topology retains the original
torso owner. Smaller heads and helmets stay seated on the inclined neck with
independent original round-command bindings. Directional elbow, waist and knee
folds replace the prior general cloth rippling. Formed toes, insteps, raised
arches and distinct heels remain intact.

The initial finger normal bake showed dark projection slivers. Each palm, finger
and thumb now projects from its matched master, with shared knuckle vertices.
Twelve grip parts use a 0.002 cage and 0.008 max ray distance. The remaining body
retains its 0.012 cage and 0.04 max ray distance. Independent heads retain their
prior recipe. Full-shell contact AO and active normal maps remain present.
Both editable masters and GLBs have fresh five-channel bakes at 2048px body,
512px head and 12 samples. Combined triangle totals are 8,033 and 8,125.

The scoped installation changes 32 files. All 55 other states and outside-slot
pixels across 15 maps remain exact. Fourteen focused Python tests pass. Original
complete headless admission passes 1,227,614 checks in 21.9 seconds, and
the complete native scene passes 113 checks in 30.5 seconds, naturally within
unchanged 120-second guards. Original source inputs, runtime and all 108 incumbent
Python test methods remain exact; one grip regression is added.

The implementing author inspected its own ten actual baked Blender views.
Evidence: `artifacts/tactical-crew-refinement-20261021-r9/acceptance.json`.
Local only, without package rebuild or publication.

Working if: both grips retain separated fingers and opposed thumbs without dark
projection slivers, head commands and original source envelopes stay intact,
55 other states remain exact, and the original admission and complete native
scene assertions finish naturally within their unchanged deadlines.


## Natural operator body, boots and grips, authoring revision 34

Both Sagger 161 and Spigot 162 now include the previously pending body/boot pass.
A higher waist and compact pelvis leave clearer leg length, with fitted pockets
and belt details. Softer shoulder and knee volumes meet tapered limbs. Boots
are about 15.74 rather than 18.27 raw units long, with rounded asymmetric toes,
a narrower heel, closer ankle, restrained arch and planted toe/heel contacts.

The new grips have tapered palms, graded finger lengths and radii, eight-sided
game digits, shaped opposed thumbs and articulated fingertips returning to the
held control face. Closed planar caps allocate more of the existing triangle
budget to finger curvature. Original head geometry and command bindings remain
exact. The final body-plus-head totals are 8,073 and 8,165, both below 8,192.

Both editable Blender masters and GLBs have fresh full five-channel bakes at
2048px body, 512px head and 12 samples. Active normal maps retain matched per-grip
projection, while contact AO uses the complete shell. No partial R10 channels
or disabled normal links are installed. The author reviewed its own ten actual
baked Blender views, including hand and boot close-ups.

Seventeen focused Python checks pass. Complete original headless admission
passes 1,228,006 checks in 101.0 seconds; the complete native scene
passes 113 checks in 43.2 seconds. Both return naturally within unchanged
120-second guards. The scoped install changes 26 files. All 55 other states,
every outside-slot pixel across 15 maps, original inputs and runtime pins remain
exact. All 111 immediate-baseline test methods remain exact, with one fingertip
regression added. The cumulative R9 disposition retains 107 methods exactly,
updates two R10 body-design expectations, and adds three focused regressions.
Six freshly baked head maps match the prior bytes exactly and need no copy;
actual recursive before/after differences authenticate all 26 installed deltas.

Nell explicitly directed proceeding with available space. This two-model phase
uses a 16GiB launch reserve and 12GiB running floor; the 4GiB RSS/output caps,
full quality and authoring/runtime time limits remain. No master, rollback or
unique evidence was deleted. This verified R11 delivery supersedes the prior
R10/R11 disk-blocked working status. Local only, without package rebuild or
publication. Evidence: `artifacts/tactical-crew-refinement-20261021-r11/acceptance.json`.

Working if: both installed operators show joined proportional anatomy, rounded
fitted boots and curled individual fingers, independent heads and original owners
remain intact, 55 other states remain exact, and original admission/scene checks
finish naturally inside their unchanged deadlines and revised disk reserve.


## Fuller Sagger/Spigot anatomy, Blender revision 35

Both operators receive fuller thighs, knees and calves, with a continuous taper
into wider boot shafts. The sculpt increases calf radii by roughly 25 to 30
percent and gives the thighs fuller width and depth. Rounded toe boxes and fuller heels/instep transitions retain planted
contacts and the existing foot length. The new palms carry more metacarpal volume;
thicker fingers taper gently to broad pads, and fuller opposed thumbs keep the
control grip readable. Individual graded fingers and original hand ownership
remain intact. Body/head totals are 8,064/8,156, within 8,192 each.

Both editable Blender masters and exports have fresh full five-channel bakes at
2048px body, 512px head and 12 samples, with matched grip normal projection and
full-shell contact AO active. The implementing author reviewed its own ten actual
PBR views. A concave source-boundary opening found in the rear view was
corrected by keeping seam Z fixed and projecting newly sliced seam vertices.
Normal and AO maps stay active. This remains a stylized, source-bound game pose.

The scoped install changes 26 authenticated files. All 55 other states,
outside-slot pixels across 15 maps, 68 original inputs, 382 runtime pins and the
independent head geometry remain exact. All 112 immediate-baseline test methods
are unchanged; one regression protects fleshy digit/palm and calf volume,
plus entering-ray coverage at the source thigh seam in both low and master meshes.
Eighteen focused tests pass. Original admission passes 1,227,806
checks in 31.91s; the complete native scene passes
113 in 41.11s, naturally inside unchanged 120s guards.

The existing 4GiB RSS/output caps, 16GiB launch/12GiB running disk reserve and
1800s authoring limits are retained. No prior master, rollback or evidence is
removed. Local only: no PCK rebuild, commit, push or publication. Evidence:
`artifacts/tactical-crew-refinement-20261021-r12/acceptance.json`.

Working if: both operators visibly show fuller hands and legs with fitting boots,
original source/head contracts and all other states remain exact, and the final
full-quality Blender bakes and original complete admission/scene checks pass.


## Photograph-referenced ground crews, Blender revision 36

Nell explicitly selected the real firing setup. This supersedes revision 35's
upright per-face crew silhouette for Sagger 161 and Spigot 162 only. The new
kneeling crews have joined clothed anatomy, full thighs and calves, shaped
boots and closed graded fingers with opposed thumbs. The grounded Sagger
controller carries a joystick and tall periscope, beside a separate finned
missile on its case lid. Spigot has a horizontal container, guidance housing,
attached ocular and three grounded tripod feet. The controller and tripod
clear the boots. Both full five-channel bakes retain 2048 px body, 512 px head
and 12 samples. Complete body/head totals are 6,630 and 6,332, below 8,192.
The implementing lead authored and inspected ten actual PBR Blender views.

References retained with source metadata: US DoD DD-ST-85-01240 and 01242,
14 November 1984, public domain per their Commons pages; Dmitry Shutov/Mil.ru,
12 May 2021, CC BY 4.0. The 2021 photograph informs equipment and firing posture,
not era-exact uniform reproduction. Unmodified photographs are packed as
non-rendering references in the shared editable sculpt, with no photographic
pixels incorporated into the model textures.

Only these two Modern models advertise the optional ground-atgm-v1 pose.
A single admitted rigid transform drives body and attached head, real depth,
and the replacement ownership mask at the original painter slot. Any missing
or inconsistent source/head witness selects the complete incumbent path.
The original normalized head geometry and command identity remain exact.
A pose-only dynamic Q14-context candidate handles independently rounded
original anchors, rechecking every vertex under unchanged 2.0001 raw / .25 pixel
limits; malformed, reflected, sheared or inconsistent context fails closed.
Classic, gameplay, registry, roots, bounds and original input bytes remain.

Eighteen focused Python checks pass. The complete asset admission gate passes
1,215,064 checks; the adapted native scene gate passes 51; the
focused native pose gate passes 236, including near-plane
crossing, bidirectional mask coverage, vacated upright pixels, real-depth
negative control, mode/cache restoration and later-occluder protection.
Nine Python expectations and the obsolete upright scene branches are explicitly
dispositioned, rather than reported unchanged. 104 incumbent Python methods
remain exact. A genuine unmodified scenario 3 packet admits one of two Sagger
candidates; the other has no visible head span. Fourteen negative context
mutations reject. In that capture, foreground terrain hides the lower pose; the old upright
head pixels correctly vacate while all noncrew coverage remains exact. This
is admission and occlusion evidence, not a visible live-mission crew demonstration.

The scoped install changes 28 authenticated files. All 55 other catalogue entries,
outside-slot pixels across 15 maps, 68 original inputs, 377 untouched runtime pins
and all 869 backup pins remain exact. Existing 16 GiB start / 12 GiB running disk
reserves, 4 GiB RSS/output caps, 1800 s authoring and 120 s runtime guards remain.
No prior master or rollback was deleted. Local only, without PCK rebuild,
commit, push or publication. Evidence:
`artifacts/tactical-crew-refinement-20261021-r13/acceptance.json`.

Working if: both correct low firing setups appear in the actual Blender and
native model studies, their masks contain no upright ghost silhouette, rejected
witnesses and original foreground remain authoritative, and unrelated states
and source data stay exact.


## Ground-crew finishing polish, Blender revision 37

The approved kneeling Sagger and Spigot firing setups remain. Leather/cloth and
sole material changes now follow actual cut planes, removing the sawtooth rims
from centroid-coloured triangles. The folded rear calf also has a straight
shaft boundary and a correctly leather-coloured heel. Small sewn cuffs surround the sleeve/wrist
joints. The Spigot near hand and Sagger far hand are reseated on their controls;
all four index-to-control vertex distances are below .5 raw units, with the
closed graded fingers and opposed thumbs preserved.

Controller, missile-case and guidance-housing edges have small physical bevels.
Sagger fins have tapered profiles; Spigot container bands have chamfered edges.
Microscopic hinge relief belongs to the bake master; small game sockets use
an efficient eight-sided profile. The first pilot failed the unchanged 85 percent
interior-texel coverage check. Its full assets and views remain under the R14
pilot directory. The corrected geometry passes that check without a threshold,
map-resolution, sample-count or normal/AO reduction. A native pilot also
caught one ownership pixel at a redundant forearm subdivision. Belt-only
material cuts now stay within the belt region; the runtime and zero-mismatch
coverage assertion remain unchanged. The failed assets and reports are retained.

Both editable masters, GLBs and five-channel maps are freshly baked at 2048 px
body, 512 px head and 12 samples. Complete body/head totals are 7,866 and
7,614, within 8,192 each. The implementing lead inspected its own ten
actual PBR views, including unobstructed boot profiles and control close-ups.
Twenty focused Python tests pass. All 113 immediate-baseline Python methods and
all 416 runtime pins remain exact; two new regressions cover rim/cuff geometry,
hand contact and shaped equipment profiles. Fresh installed-art gates pass
48 pose-admission checks, 236 native-pose
checks, 1,225,044 format-shard-0 asset-admission checks and 51 native-scene
checks. The retained genuine R13 source packet is exercised against these new
assets, preserving its noncrew foreground and correctly vacating the old head.
This does not claim a visible live-mission crew demonstration.

The scoped install changes 28 authenticated files. All 55
other entries, every outside-slot pixel across 15 maps, 68 original inputs and
the raw head geometry/pose remain exact. Existing 4 GiB RSS/output caps,
16 GiB start / 12 GiB running disk reserve, 1800 s authoring and 120 s runtime guards
remain. R13 masters and all 913 preimages are retained. Local only, without
package rebuild, commit, push or publication. Evidence:
`artifacts/tactical-crew-refinement-20261021-r14/acceptance.json`.

Working if: the final Blender close-ups show clean boot rims, seated cuffs and
control grips, finer launcher profiles, unchanged firing/head poses and source
data, while unrelated assets remain exact and full-quality native checks pass.


## Kneeling crew anatomy refinement, Blender revision 38

Sagger and Spigot retain their approved ground-supported equipment and rigid
head pose. The clothed pelvis and tunic are rebalanced, shoulder/elbow masses
reduced, and the forward shin's authored centreline increased from about 9 to
14 raw units. The raised knee remains distinct from the weight-bearing rear
knee, which now reaches -89.878 against the -90 ground plane. The rear boot
is rebuilt around the horizontal calf: lowered toe, lifted heel and a folded
ankle, replacing the upright duplicate front boot. The front shoe has a softer
toe box, shallower arch and less blocky heel.

Palms gain depth, opposed thumbs are less erect, and each curled finger ends
in a shallow rounded pad. All twelve closed palm/digit parts remain, with
consistent winding and four distinct graded fingers per hand. All four grips
remain within the existing .7-raw-unit control-contact limit. Pockets now fit
the revised tunic surface explicitly, excluding neighbouring sleeves.

Twenty-one focused Python checks pass. Two previous rear-boot expectations
were revised because they required an upright shaft and grounded rear heel;
the new checks require the intended raised heel and grounded toe. All 113
other immediate-baseline methods remain exact. A new regression checks closed
rounded hand pads, cushioned palms and the grounded rear knee. The first
anatomy trial and its three test failures remain in the R15 evidence: two old
rear-heel expectations and the real pocket-fit defect corrected in source.

Fresh Blender masters, GLBs and all five channels retain 2048 px body / 512 px
head and 12 samples. Body/head totals are 7,730 and 7,480, within
8,192 each. Albedo and normal interior-texel coverage passes the unchanged
85 percent floor, with zero black interior misses. The lead inspected its own
ten final PBR views, including both boot profiles and control close-ups.
Installed-art gates pass 48 headless pose checks,
236 native pose checks, 1,223,972
format-shard-0 admission checks and 51 native-scene checks.
The twelve native pose studies have zero ownership mismatches, stale pixels
or unexplained mask pixels. The retained genuine gameplay packet preserves
all noncrew foreground and vacates the old upright head; its lower crew is
occluded, so this is not a visible live-mission crew demonstration.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs, raw head/pose, launcher geometry and 416 runtime pins remain exact.
The scoped install contains 29 authenticated deltas;
R14 masters and all 913 preimages are retained. Existing 4 GiB RSS/output,
16 GiB start / 12 GiB running disk and 1800 s authoring / 120 s runtime guards
remain unchanged. Local only, without package rebuild, commit or publication.
Evidence: `artifacts/tactical-crew-refinement-20261021-r15/acceptance.json`.
The supplemental kneeling anatomy photograph and inspection record are linked
in `references/kneeling-anatomy.json`; its pixels are not used in textures.

Working if: side/rear Blender views show continuous folded calves and ankles,
weight-bearing knees, proportioned trousers and rounded working grips, while
source data, launchers, runtime and unrelated assets remain unchanged.


## Kneeling crew proportion polish, Blender revision 39

Sagger and Spigot receive a bounded anatomy pass over revision 38. Lower,
flattened shoulder masses merge into a sloping tunic transition; waist and
seat volumes are fuller. Thighs and calves gain proximal fullness rather
than uniform cylindrical thickness. Leg joint centres and the approved
grounded-knee, folded-ankle firing setups are retained. The front boot gains
rounded toe/heel end stations, and the rear boot has a smoother
instep transition and narrower rounded toe. Four distinct finger curls vary
across each grip, and opposed thumbs gain closed rounded terminal pads.
Pocket faces now follow the curved tunic in the clear medial chest region.
This corrects the old fit query mistaking upper arms for jacket and the
flat faces cutting through the tunic. Both rejected trials are retained
under `pilots/`.

All 116 incumbent test methods remain unchanged. One regression now checks
pocket ray ambiguity and face-interior clearance; 22 focused Python checks
pass. Both fresh editable Blender masters retain 2048 px body / 512 px head,
12 samples and all five channels. Body/head totals are 7,892 and
7,644, below 8,192 each. The unchanged interior-texel check exceeds
85 percent on albedo/normal maps with zero black misses. The lead authored
this pass and inspected its own ten actual baked PBR views against revision
38 and the retained equipment photographs.

Installed-art gates pass 48 headless pose checks,
236 native pose checks, 1,225,252
format-shard-0 checks and 51 native-scene checks. Twelve
native pose cases have zero ownership mismatch, stale or unexplained mask
pixels. The retained genuine gameplay packet preserves noncrew foreground
and vacates the old upright head. Its lower crew is occluded, so it does
not demonstrate a visible live-mission crew.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs, independent raw head/pose, launcher geometry and 416 runtime pins
remain exact. All 913 R15 preimages are authenticated and retained. The
scoped install contains 28 exact deltas. Existing memory,
output, time and disk guards remain unchanged. Local only, without package
rebuild, commit or publication.
Evidence: `artifacts/tactical-crew-refinement-20261021-r16/acceptance.json`.

Working if: side/rear views show sloping shoulders, contoured clothed limbs,
rounded boot ends and differentiated working grips, while source, head,
equipment, runtime and unrelated assets stay unchanged.


## Crew head proportion polish, Blender revision 40

Sagger and Spigot receive a head-only pass over the accepted revision 39
bodies. Helmet lateral width is reduced by 12.5 percent while its
front-to-back clearance and command depth contract are retained. The chin
and lower jaw gain depth and breadth; the occiput tapers into a continuous
nape. Thin, elongated cupped ears replace the raised oval volumes, with a
rolled helix and inset concha. The neck root, eye/iris geometry, complete
body meshes, launchers and rigid firing poses remain exact.
A normal-map-off diagnostic identified cross-surface projection seams.
One inward cheek-strap winding is corrected. The complete head donor and
receiver retain global UV padding, with shorter head-only normal rays
(.006 cage/.018 maximum ray distance). Contact AO and non-head bakes are
unchanged. Rejected donor-isolation trials and their artifacts are retained.

All 117 incumbent test methods remain unchanged. One new regression
reproduced the inward strap before repair; 23 focused Python checks pass. Both fresh editable Blender masters retain 2048 px body / 512 px head,
12 samples and all five channels. Body/head totals are 7,636 and
7,388, below 8,192 each. The unchanged body interior-texel check
exceeds 85 percent on albedo/normal maps with zero black misses. The lead
authored this pass and inspected its own thirteen actual baked PBR views,
including front/profile/rear head closeups. Earlier diagnostic profiles are
retained and are not the installed result. The retained real Spigot photo
supports the equipment/posture reference; its obscured face does not supply
head-anatomy evidence. No reference pixels enter the textures.

Installed-art gates pass 48 headless pose checks,
236 native pose checks, 1,225,252
format-shard-0 checks and 51 native-scene checks. Twelve
native pose cases have zero ownership mismatch, stale or unexplained mask
pixels. The retained genuine gameplay packet preserves noncrew foreground
and vacates the old upright head. Its lower crew is occluded, so it does
not demonstrate a visible live-mission crew.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs and 416 runtime pins remain exact. The accepted body sculpt cache,
its authoring scene and body recipe are retained unchanged; the canonical
updated complete models are the two roster vehicle.blend files. All 913
preimages are authenticated and retained. The scoped install contains
28 exact deltas. Existing memory, output, time and disk
guards remain unchanged. Local only, without package rebuild or publication.
Evidence: `artifacts/tactical-crew-refinement-20261022-r17/acceptance.json`.

Working if: head closeups show a fitted helmet, elongated cupped ears and a
continuous jaw/nape transition, while eye-to-sight contact, body, equipment,
runtime and unrelated assets remain unchanged.


## Crew jaw and neck proportion correction, Blender revision 41

Nell rejected the revision 40 head proportions. Revision 41 narrows the
head and helmet around unchanged eye landmarks, lowers the crown, raises
the mouth and chin, and replaces horizontal jaw rings with an ascending
mandible. The fitted neck enters behind the chin with a visible throat
recess. Three transition rings soften the chin underside. The posterior
jaw deformation is monotonic; the former reversal that compressed the
lower occiput into a shelf is removed. The lowest three neck insertion
rings, eyes, body geometry, launchers and rigid firing poses remain exact.

Reference inspection used the public Anatomy For Sculptors head/skull
illustration at https://anatomy4sculptors.com/product/head-anatomy-course/
and Jilai's SSh-68 photograph at
https://commons.wikimedia.org/wiki/File:SSh-68.jpg (CC BY 4.0).
The reference images supplied visual guidance only; none of their pixels
enter the models or textures. The previously retained real firing-setup
references remain unchanged.

The lead authored and reviewed this work. A read-only independent advisor
rejected an intermediate profile and identified the heavy chin/throat
connector and folded occiput rows. Root reproduced the geometric fault,
implemented the correction and inspected the final actual baked views.
The result remains a stylized low-poly model with close-up faceting and
fine normal-map seams. Source inspection confirms flat shading is retained
through the bake, matching the unchanged runtime tangent-frame contract.
No seam-free or photorealistic result is claimed.

All 118 incumbent test methods remain exact. A new jaw-angle regression
fails revision 40 and passes this correction; 24 focused installed Python
checks pass. Both fresh editable masters retain 2048 px body / 512 px head,
12 samples, all five channels, the existing head-normal projection and
complete-shell contact AO. Triangle totals are 7,920 and
7,672, both within 8,192. Body interior-texel coverage remains above
85 percent; head and body checks find no black albedo/normal interior misses.

The four inherited 120-second runtime gates pass 48
headless pose checks, 236 native pose checks,
1,225,252 format-shard-0 checks and 51
native-scene checks. The initial native-pose attempt timed out at 120
seconds after nine cases. Its logs and partial images remain intact. A
single retry, after normal timing in the separate native-scene gate,
completed in 97.383 seconds with the same
120-second limit. Twelve synthetic native pose cases have no ownership
mismatch, stale or unexplained mask pixels. The retained genuine gameplay
packet preserves noncrew foreground but occludes the lower crew; it does
not prove a visible live-mission crew.

All 55 unrelated entries, outside-slot pixels across 15 maps, 68 original
inputs and 416 runtime pins remain exact. All 913 preimages and rejected
prototype evidence are retained. The scoped install contains
28 exact deltas. Existing time, memory, output and disk
guards remain; authoring additionally checks the live shared disk forecast
and a 512 MiB next-write allowance. Local only, no package rebuild or
publication. Evidence:
`artifacts/tactical-crew-refinement-20261022-r18/acceptance.json`.

Working if: front and profile views show a balanced head, ascending jaw and
clear throat recess without a lower-skull shelf, while sight contact,
jacket insertion, body, equipment and unrelated assets remain unchanged.


## Crew collar and head bake finishing, Blender revision 42

Nell requested completion of the Sagger/Spigot polish. Both editable masters
now have a fitted, closed cloth collar and a curved rear jaw/neck transition.
Eye positions, firing poses, body geometry, hands, boots and launchers remain
exact. The independent head UV layout splits larger tangent-frame bends;
only hidden closure disks are down-weighted. The visible underside brim and
helmet top cap retain their charts.

The first split-UV trial improved the grid-like seams but introduced black
marks. Root reproduced 281 unpainted head-triangle samples, including eight
skin triangles and the helmet top cap. Independent read-only advice identified
zero pixel-centre coverage on the implicated tiny charts. Whole-chart minimum
footprints before packing removed the marks. Four barycentric samples on every
head triangle now have no black albedo/roughness misses at either the 512 px
master size or the actual 232 px packed-head size. Earlier interior-only
sampling missed this defect; a new regression covers those small triangles.

The lead authored and personally reviewed all 13 final baked views. Both
models retain stylized low-poly silhouettes and fine close-up shading seams;
this is no claim of photorealism or literal perfection. The collar covers the
ragged insertion strip, and the rear neck transition is less abrupt.

The 26 focused installed checks pass; all 119 incumbent methods remain exact.
The new collar and subpixel-bake regressions are additive. Fresh body2048/head512
five-channel bakes retain 12 samples, full-shell AO and existing normal rays.
Triangle totals are 8,080 and 7,832, below the 8,192 cap.
An initial headless gate timed out under host contention. Its evidence is
retained; one retry followed a normal-timing native scene result.
Runtime checks pass 48, 236,
1,225,252 and 51 assertions within the unchanged
120-second guards. Native pose fixtures have no ownership-mask mismatch.
The retained genuine gameplay capture is partially occluded and does not
establish a visible live-mission crew.

All 55 unrelated entries, 15 outside-slot atlas regions, 68 original inputs
and 416 runtime pins remain exact. All 913 fresh preimages and rejected
candidate evidence remain retained, including the first prototype abort
and geometry-test failures. Those failures were repaired, never removed.
Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-crew-refinement-20261023-r19/acceptance.json`.

Working if: the collar closes the exposed join, the rear neck is continuous,
and head maps have no unpainted subpixel islands while original ownership,
firing setups and unrelated roster assets stay intact.


## Crew head proportions, Blender revision 43

Nell requested a slightly larger head on the Sagger and Spigot crews. Both
skulls now have approximately eight percent more height and depth. Facial
width increases about eight percent and the fitted helmet width about ten
percent. The deformation fades smoothly into the unchanged collar. Eyes,
irises and their end caps remain exact, preserving the approved sight contact.
Body geometry, hands, boots, launchers and firing poses remain exact.

The lead authored this pass and personally inspected all 13 final baked
Blender views. The models retain the intended low-poly style. Full-resolution
body2048/head512 five-channel bakes retain 12 samples, full-shell contact AO
and the existing normal projection settings. Four samples per head triangle
show no black albedo or roughness misses at 512 px and 232 px packed sizes.
Triangle totals remain 8,080 and 7,832, below the 8,192 cap.

All 26 focused tests pass, with all 121 incumbent test methods unchanged.
The four runtime gates pass 48, 236,
1,225,252 and 51 assertions within the
unchanged 120-second limits. Native pose fixtures have no ownership-mask
mismatch. The inherited gameplay capture remains partially occluded and does
not establish a visible live-mission crew.

All 55 unrelated roster entries, 15 outside-slot atlas regions, 68 original
inputs and 416 runtime pins remain exact. All 913 fresh preimages are retained.
Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-crew-refinement-20261023-r20/acceptance.json`.

Working if: full-body and profile views show larger, fitted heads while the
closed neck join, eye-to-sight contact and all non-head geometry stay intact.


## Whole-roster and menu polish, Blender revision 44

Reviewed paired views of all 57 roster states, the menu Abrams and both crew,
and the grass/shrub masters. The lead authored this pass and personally
reviewed its final images. Six roster states were refined; 51 remain exact.

The truck canopy now sags gently between its retained support bows, with
shaped skirts and closed ends. Five building states (145, 146, 154, 155,
158) have corrected non-metallic roof bakes. The three surviving ruin roofs
also have correctly oriented overlapping tile courses and narrower joints.
All 19,024 sampled roof interiors have zero metalness. Full 2048 px,
five-channel, 12-sample bakes retain normal projection and full-shell AO.
Both menu crew have softer neck and elbow transitions. Armour, faces,
helmets, gloves and pose contacts are retained; the maximum deformation
remains below one centimetre. Editable Blender masters are installed.

All 124 asset tests pass. Native checks pass: simulation 1,265, foliage 17,
complete-roster admission with format shard 0 1,226,248, scene 51, and
view shard 0 671. The menu also passes wide/compact rendering, reduced
motion, menu actions and range lifecycle. These are the named scoped gates,
not a claim that every rejection or view shard was rerun.

All 928 fresh backup pins verify, together with the separately reconstructed
and geometry-authenticated truck-source preimage. The 51 retained states,
15 outside-slot atlas regions, original GAME manifest, source registry and
121 incumbent test methods remain exact. Failed pilots and two incomplete
test-supervisor runs remain recorded; the Python launch-identity fault was
reproduced and repaired before the successful suite. Resource guards were
retained. Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-all-model-refinement-20261023-r21/acceptance.json`.

Working if: all models have a fresh review disposition, the truck and roofs
render cleanly, menu crew joints are softer, and original source ownership,
pose contacts and every untouched asset stay intact.


## Whole-roster review and crew refinement, Blender revision 45

Reviewed all 57 current roster states, foliage, the menu Abrams and both menu
crew. This is a self-review of work authored by this chat. Fifty-five roster
states are retained byte-exact; Sagger and Spigot have fuller shoulder/collar
transitions, cheeks, lower jaws, palms and articulated fingers. The approved
kneeling poses, launchers and knee contact heights remain exact. Boot recipes
are unchanged; shared-body remeshing changes some tessellation while silhouette
bounds stay within 0.01 source units. Eyes follow the cheek surface by less
than 0.00011 normalized head units in depth, retaining size and orientation.

The floating menu barrel is repaired as one overlapping receiver/barrel/cradle
assembly on a visible roof pedestal. An initial native close-up caught the
pedestal crowding the loader's braced hand; its final position clears both
hands. Wide/compact menu views and three complete-assembly angles verify the
connection. Both crew have fitted helmet assemblies, slimmer sleeves, fuller
palms and staggered finger lengths. The unchanged one-centimetre Blender
replacement limit remains enforced, with maximum displacement 0.0095001m.

Editable Blender masters and the matching runtime assets are installed.
All 13 final crew PBR views were inspected. Five-channel body2048/head512
bakes retain 12 samples, existing normal projection and full-shell AO.
Triangle totals are 8,074 and 7,826, below the 8,192 cap.
UV interior and four-samples-per-head-triangle checks show no black misses.

All 124 asset tests pass, unchanged from the fresh preimage. Three focused
native assertions protect gun continuity and hand clearance; the simulation
check passes 1,268 assertions. Pose admission/native,
world admission, full roster admission with format shard0, native scene and
view shard0 pass 48, 257,
17, 1,226,212,
51 and 671 checks.
The native pose test now ends raw-schema parsing before compiled assets load,
and uses one production renderer load for admission and pixels. Two earlier
runs reached the unchanged 4GiB bound; their uninstrumented logs do not locate
the precise allocation. A bounded read-only second opinion supported the
test-lifetime repair. All schema, mutation, protected-pixel, stale-silhouette, depth-negative and
immutability checks remain exact, including restoration of published poses
after the optional synthetic smoke.
The final phase-instrumented gate passes within the original memory and time
limits. A focused diagnostic reproduced one background boundary pixel at (411,355)
in the Sagger rear view. Actual appearance is black there; the production
shader clips it correctly. The prior test implemented its one-pixel boundary
allowance in only one direction. The corrected check permits at most one
background-only gap per view, touching both silhouette boundaries, and adds
strict masked-coverage equality to the eligible triangle intersection. All
12 fixtures have zero leaked or missing eligible rendered pixels; boundary
disagreement counts are retained separately. These are scoped
checks, without a new claim of visible live-mission footage or every shard.
The native menu also passes reduced motion, actions and range lifecycle.

All 929 fresh preimages, 68 original inputs, the source
registry and all 15 outside-slot atlas regions verify. The launch sequencing
incident is retained: an early shell precheck did not gate two successful
jobs. Remaining Blender supervisors were corrected to fail closed before
launch; memory, disk, thread, output and time bounds remained in force.
No foreign process was controlled. Cleanup pass6 removed zero bytes.
Local only: no package rebuild, commit, push or publication.
Evidence: `artifacts/tactical-all-model-refinement-20261023-r22/acceptance.json`.

Working if: crew proportions and hands read naturally, knee/boot/grip contacts
remain coherent, the menu weapon has a visible continuous mount, and retained
assets and original ownership remain intact.


## Base and truck proportion correction, Blender revision 46

Nell rejected Base155 and Truck159 in the previous roster review. This pass
corrects those two assets; it is a self-review of work authored by this chat.
The base now reads as two storeys, with a normal-height door, two window rows
and a sealed recessed flat roof. Its footprint and original stars are exact.
The truck body is 25 percent narrower; its canvas crown is lowered from 69.6
to 46.5 source units, just above the cab. All six wheel Y/Z profiles and ground
contacts are exact. The fittings follow the complete width adjustment.
M35 photo references and attribution are retained in the phase references.

Both editable Blender masters and matching runtime exports are installed.
Five-channel 2048 px bakes retain 12 samples. Eight final Blender PBR views
and eight native GLB views were inspected. The production renderer also
passes admission (1,223,508 checks), truck view
partition 3 (617) and base view partition
5 (626). Four production close-ups were
inspected; the base close-ups intentionally extend outside the test viewport.
These are scoped gates, without a claim that every mission or partition ran.

Sixteen focused asset checks pass. Initial test-class selection errors were
corrected, and one truck fitting assertion now converts the narrowed width
back to the original scale, preserving its relative-clearance threshold.
The failed intermediate logs are retained. Nine geometry expectations were
updated, two proportion regressions added, and 115 incumbent methods remain
unchanged. The full 126-test suite was not rerun.

All 897 fresh backups authenticate, with 866 protected live files, 68 original
inputs, 55 peer model entries and all 15 outside-slot atlas maps unchanged.
No menu or crew assets changed. All jobs completed within the existing
resource guards. No cleanup, package rebuild, commit, push or publication.
Local only. Evidence: `artifacts/tactical-base-truck-refinement-20261023-r23/acceptance.json`.

Working if: the door and windows read at human scale, the truck cover sits
close to the cab, wheels remain round, and source ownership stays intact.


## Whole-roster polish, Blender revision 47

All 57 roster states were reviewed from front and reverse, together with the
menu tank, both menu crew and foliage. This is self-review of this chat's work.
Bradley131 now has seated commander/gunner roof optics and the early-M2 side
and rear port arrangement. The other 56 roster entries are retained, including
the corrected base, truck and grounded Sagger/Spigot crews.

Both menu crew have lower sleeve roots, untwisted sleeve sections and slimmer
cuffs. An intermediate chest change intersected the collar and was rejected;
the final version preserves the previous chest, heads, grips and pose anchors.
The menu tank and its continuous weapon mount are unchanged. Editable Blender
masters and matching runtime assets are installed. Bradley retains five-channel
2048 px, 12-sample bakes and 7,452 triangles. Menu refinement stays below 1 cm.

Five focused asset tests pass. All 130 incumbent test/helper methods are exact,
with one added Bradley regression; the full 127-test suite was not rerun.
Full roster admission passes 1,224,048 checks, native view partition5 passes
626, and the final menu simulation passes 1,268. Final native menu checks pass
wide/compact views, two pixel-identical frozen intervals, actions and range
lifecycle. The failed intermediate and diagnostic corrections remain recorded.

All 918 fresh backups and 68 original inputs authenticate. The 56 peer model
entries, 15 outside-slot atlas regions and menu armour/gun batches are exact.
Four concurrent audio-owned files were preserved and excluded from unchanged
claims. No cleanup or package rebuild. Local only, with no R24 commit, push or
publication. Evidence: `artifacts/tactical-all-model-refinement-20261023-r24/acceptance.json`.

Working if: crew shoulders flow into the shirt, sleeves follow the bent arms,
Bradley optics read clearly, and retained contacts and source ownership hold.

R24 closeout also registers the existing ground-crew test in the headless and
native gate tiers, with its exact success receipt and source-kit dependency.
All 10 gate-coverage tests pass; the aggregate validation gate was not rerun.


## Whole-roster polish, Blender revision 48 (R25)

All 57 roster models were reviewed in both directions using hash-bound current
asset renders and retained unchanged. The corrected base, truck, Bradley and
grounded Sagger/Spigot crews remain intact. This is self-review of this chat's
work, including the menu tank and both crew.

Both menu shirts now join torso and sleeves through shared armhole vertices,
with consistent winding across shoulders and bent elbows. Heads, necklines,
gloves, grip contacts and poses remain exact. The loader gun has a rounded
muzzle lip and recessed bore; its receiver, mount and barrel extents are
preserved. The tank hull and main gun are unchanged. The editable Blender
master and all 42 authored runtime batches are installed; maximum refinement
displacement is 0.00950014 m.

All 1,276 simulation/presentation checks pass, including joined-shirt topology
and the open muzzle. Native wide/compact menu checks pass, with 18 captured
views, two pixel-identical reduced-motion intervals, actions and range
lifecycle. Final shoulder, hand and muzzle close-ups were inspected. Failed
intermediates remain retained: inconsistent garment winding was corrected,
and the tiny-lip test uses uniform centimetre scaling to avoid Godot's
absolute intersection epsilon while preserving every segment and expected hit.

Preservation checks authenticate nine allowed-file backups, 68 original GAME
inputs and all 474 roster files. Incumbent test lines remain exact. The roster
was retained without a rebake; the aggregate validation gate and all-mission
runtime were not rerun. No cleanup, package rebuild, commit, push or publication.
Local only. Evidence: `artifacts/tactical-all-model-refinement-20261023-r25/acceptance.json`.

Working if: both shoulders flow continuously into their sleeves, the loader
muzzle reads as recessed, and retained contacts and original inputs stay exact.

Concurrent audio and Tactical HUD edits were preserved and classified separately
in the R25 closeout. Native evidence covers the model candidate at capture time;
validation of later audio/HUD work remains with its owning chats.


## Convoy truck polish, roster finish revision 48 (R26)

The convoy truck now has a broader, longer bonnet and grille, an aft-set
rounded-corner cab with framed glazing, visible supported steps at both doors
and a rolled rear canvas entry flap over an open cargo aperture. The tailgate
remains closed for transport. M35 reference photographs informed the geometry.
Ten annular tyres provide rear dual wheels; vented steel dishes are recessed,
with separate front spindle and rear hub profiles. Front-axle dust follows the
new wheel position.

The editable Blender master, GLB, five 2048 px maps and matching atlas tile are
installed. The 12-sample bake recipe is retained. Runtime geometry is 8,150
triangles, within 8,192 and the original source bounds/groups. All other 56
roster entries and all 15 outside-slot atlas regions remain exact. All 57 roster
states, the menu tank and both crew were visually reviewed from hash-bound
current-asset images. This is self-review; retained models were not rebaked.

Six source checks and two baked-asset checks pass. Finished Blender and native
GLB views pass; production native partition 3 passes 617 checks. Positive
full-roster admission/mapping and pair-format rejection pass 1,225,308 checks.
Two earlier admission runs timed out under the unchanged 120 s guard. A copy
with only 11 timestamp prints passes in 49.20 s within the same time/memory
limits; stripping those prints restores the original test exactly. No assertion
or production runtime changed. The exact timeout cause remains unproven.
Other format shards, the full repository gate and all-mission runtime were not
rerun. All intermediates and failures are retained.

Preservation verifies 33 scoped backups, 879 protected live files and all 68
original inputs; 21 concurrent owner-classified deltas remain untouched. No
cleanup or package rebuild. Local only, excluded from the separate soundtrack
app/Web release; no R26 commit, push or publication. Evidence:
`artifacts/tactical-all-model-refinement-20261023-r26/acceptance.json`.

Working if: broad nose, steps, rear opening and dished dual wheels read clearly
from front/rear views while retained models and original source custody hold.


## Main-menu motion, R27

The Blender-authored cover now has runtime track/wheel skinning, small suspension
motion, independent crew breathing/head movement and restrained turret tracking.
The ground passes beneath the tank, smoke undulates, and the camera translates
with the hull at the unchanged forward offset and orientation. Crew grip/hatch
contacts and headlight attachments are retained. All 42 authored batches match;
no Blender or roster asset bytes changed.

1,668 simulation/presentation checks, 63 route-unit checks, 151 native lifecycle
and 299 preview checks pass. Reduced Motion is pixel-identical; hidden menus
stop motion; practice restores the static rigs; the original guest stays frozen.
Wide/compact frames and crew close-ups were self-reviewed. One combined native
recording timed out; separated checks pass under the original 120 s/4 GiB guards.
The failed recording and a prelaunch command typo are preserved.

Preview: `artifacts/menu-motion-20261023-r27/menu-animation.mp4` (6 s, 24 fps).
Evidence: the same directory's `acceptance.json`. Local only; no package,
publication or notarization. Web runtime and the aggregate gate were not rerun.

Working if: body travel, tracks, crew, smoke and camera form one continuous
menu scene while authored geometry and reduced-motion behaviour stay intact.


## Object 477A and convoy-truck refinement, R28

Shapes 123/159 receive the user-requested reference polish. Molot has fuller
recessed seven-station wheels, a raised bevelled periscope, seated smoke clusters,
protected headlamps and connected turret fittings. Truck retains its broad nose,
steps and dished dual wheels, with rolled bonnet shoulders, three bound crates,
a mostly closed ajar rear flap and formed front/red-amber rear signal lenses.
Editable Blender masters match the installed five-channel 2,048 px, 12-sample bakes.
Runtime geometry: 7,648/8,166 triangles, below 8,192 with original owners/bounds.

11 source and 4 baked tests pass; final headless admission/mapping/pair rejection
passes 1,230,784 checks. Native partitions 3 and 4 each pass 617 checks under the
original 120-second/4 GiB limits; partition 3 includes both changed models. The
admission copy adds only 11 timestamp prints, with exact restoration verified.
Other partitions/format shards, all-mission runtime and the aggregate gate were
not rerun. Self-review covers 11 selected final PBR/GLB/Tactical frames; it is not
independent aesthetic approval. The rejected flap-projection and reversed-rim
candidates are retained alongside their corrected bakes and regression checks.

55 other catalog entries and 15 outside-tile atlas maps remain exact. 43 scoped
backups and all 68 original inputs verify; concurrent cover/vehicle motion edits
are preserved. No cleanup, package rebuild or publication. Evidence:
`artifacts/molot-truck-refinement-20261023-r28/acceptance.json`. Local only.

Working if: source-bound silhouettes retain custody while the revised wheel/sight
and truck bonnet, cargo slit and lamps remain readable in the installed renderer.


## Whole-roster polish and inset truck lamps, finish revision 50 (R29)

All 57 states were self-reviewed in 114 fresh opposed native GLB views. The
55 retained states remain exact. Molot 123 has deeper recessed wheel discs,
three-ring seated hub castings and recessed bolt circles. Truck 159 has painted
vent returns, a softly curved narrow rear entry flap and symmetrically inset
headlamp/indicator assemblies. The grille aperture is narrower, with the same
11 bars; the outer bonnet, radiator apron and cab retain their full width.
Runtime geometry is 7,928/8,190 triangles, within 8,192 and original bounds/groups.
Editable Blender masters and five-channel 2,048 px, 12-sample bakes are installed.

Four menu-crew cloth batches receive local shoulder relaxation within the
existing 1 cm source envelope. All 42 batch contracts and 16 noncrew batches
remain exact. Checked grip/contact displacement from the previous sculpt is
below 0.000007775 m across 11,703 vertices. Approved menu-motion sources and
reduced-motion RGBA are unchanged.

11 source and four baked tests pass. Final headless admission/mapping/pair
rejection passes 1,231,984 checks; native partition 3 passes 617. The unchanged
menu rig/artwork retains its 1,668 simulation and 151 native lifecycle checks.
The first headless attempt timed out; the final new-candidate natural-boundary
run passes under the same 120-second/4 GiB guards. Test-only timestamp/reporting
helpers preserve assertions and ordering; production runtime is unchanged.
Overlapping, incomplete, failed and interrupted trials remain outside acceptance.
Other format/native shards, all-mission runtime and the full gate were not rerun.

49 exact backups, 1,043 accounted pins, 55 retained entries, 15 outside-tile atlas
maps and 68 original inputs verify. This chat authored and self-reviewed the
selected Blender/GLB/Tactical frames, without independent aesthetic approval.
Evidence: `artifacts/roster-polish-20261023-r29/acceptance.json`. No cleanup,
R29 package rebuild or publication. These model changes are local only.

Working if: front/rear truck construction and Molot running gear read cleanly
in the installed renderer while all retained artwork and menu-motion contracts
remain exact.
