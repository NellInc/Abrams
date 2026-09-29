---
status: implementing
stepsCompleted: []
verification_criteria:
  - "Original game state, inputs, timing and campaign writes remain unchanged on paired replay."
  - "Terrain geometry, cover, sightlines, camera and targeting remain PC-authoritative."
  - "All four presentation modes switch on the same source frame without restarting gameplay."
  - "Modern assets pass moving, aiming, occlusion, checkpoint and performance checks in production Play."
---

# Abrams: Modern presentation plan

## 1. Objective and authorization

Add an optional **Modern** graphics mode: refined low-poly Cold War vehicles and buildings, illustrated vegetation, restrained materials and lighting, and improved battlefield effects, driven by the original PC simulation. Preserve the restored interfaces, original-style typefaces, illustrated characters and dedication to David “Ming” Kenny.

Nell approved the revised low-poly concepts with “Good job, action it all please.” This releases the earlier implementation hold for the local Modern pass, its assets, integration, tests and refreshed local alpha. Preserve the original PC simulation, restored interfaces and old alpha. Publishing, pushing, purchases, Developer ID signing/notarization and unrelated process control remain separately gated.

Working if: the local implementation follows the approved low-poly direction, machine checks have recorded terminal results, and no remote release or original-game redistribution occurs.

### Art-direction correction, 28 September 2026

Nell rejected the realistic T-62 concept: models should remain “low-poly ish, just a lot more polys than the original image.” The current proposal uses broad deliberate facets, meaningful silhouette detail, simple running gear and restrained flat-shaded materials. Buildings receive matching low-poly refinement. High-resolution illustrated tree sprites are the recommended concept direction; the original encoding of each tree shape still needs confirmation before binding replacements.

The revised studies are in `local-art/modern-concepts-v2/`. They supersede the realistic studies in `local-art/modern-concepts-v1/` and were approved as the production direction. Generated station images are art-direction examples, not projection or placement references.

Working if: vehicle and building facets remain visible, foliage retains an illustrated sprite character, and source data rather than generated compositions determines runtime placement and visibility.

## 2. The governing design constraint: a flat battlefield

The open terrain determines distance judgment, exposure, navigation and aiming. Preserve that spatial design throughout modernization.

### Preserve exactly

* Original ground heights, slopes, crests, road routes/widths, banks, bridge approaches, building footprints and landmark positions.
* Original collision, traversability, line-of-sight and target-selection rules, all owned by the PC executable.
* Station viewpoint, projection, zoom, horizon and the complete 4:3 view. Fullscreen must not reveal additional battlefield area.
* Original occurrence, identity and visibility of vehicles, structures, wrecks and gameplay effects.

### Add richness through surfaces and light

* Soil, worn grass, gravel and road materials, with coherent scale and low-contrast large-area variation.
* Fine surface normals rather than displacement, parallax that implies height, or tessellated bumps.
* Subtle road-edge and wear treatment confined to the original road footprint.
* Simple olive paint, dark running gear and sparse glazing on deliberately faceted meshes. Avoid photographic panels, dense weathering and microdetail.
* Upgraded low-poly buildings within original footprints. Illustrated tree sprites at original placements, with source-matched coverage, clipping and occlusion; validate camera-facing or directional presentation against observed source views before selecting it.
* Soft contact with the ground, controlled ambient light and selective shadows that cannot reveal a concealed object.
* A restrained sky and distant colour treatment that preserve the source horizon and target contrast.
* Mipmaps, suitable texture filtering and distance-dependent detail reduction, specifically tested for shimmer while driving across flat ground.

### Exclude from the first pass

Invented hills, terrain smoothing that changes a crest, hedgerows, dense grass, extra trees/buildings, decorative barriers, new craters, distant mountains that imply traversable terrain, dynamic weather, visibility-reducing fog and cinematic camera motion. No displacement of the tank or gun camera for decorative suspension effects. New visual cover is unacceptable when the original simulation provides none.

Working if: a route and aiming comparison finds unchanged terrain outlines and sightlines, and no modern decoration resembles usable cover or hides an original target.

## 3. Starting point, checked against the current checkout

Baseline: local commit `b6e7f41701ff2acf2c25c0ab756d21dd1319e359`, private alpha `155022309658d78cab7c`.

| Available foundation | Implication for Modern |
| --- | --- |
| Original executables run under the pinned traced core; the bridge forwards inputs and observes output. | Keep this architecture. Do not implement a second combat or vehicle simulation. |
| `pc_render_trace.py` pairs drawing passes with actual scanout and records selected objects, matrices and camera-space vertices. | Build Modern from that paired boundary, not from the newest available RAM snapshot. |
| `pc_draw_pass.gd` builds camera-relative geometry; `pc_surface.gdshader` deliberately disables depth testing to preserve source drawing order. | Modern needs a separate depth-aware renderer with an explicit original-visibility compositor. Enabling ordinary depth testing on the existing shader is insufficient. |
| The current Godot project uses Compatibility rendering. | Establish a measured renderer decision before adding advanced lighting dependencies. |
| The source class table has 31 records, including vehicles, aircraft, weapons and structures; variants share some identities. | Make a deduplicated asset register. Do not estimate this as 31 independent tanks. |
| World decoding includes streaming-origin changes; `DISPLAY_SCALE = 64` is an inspection convention. | Preserve rebasing and calibrate visible scale. Do not assume that current Godot units are metres. |
| The former pasted vehicle-surface studies were rejected. | Retain them as research only. Modern vehicles require proper geometry and UV/material work. |
| Save/load ownership, PC-only installation and instant three-mode switching already exist. | Extend their tests and interfaces rather than replace them. |

Relevant implementation: `tools/pc_render_trace.py`, `tools/pc_render_state.py`, `tools/pc_live_state.py`, `tools/pc_vehicle_catalog.py`, `godot/scripts/pc_camera.gd`, `pc_draw_pass.gd`, `pc_tandem_frame.gd`, `pc_bridge_viewer.gd`, `pc_play_menu.gd` and `pc_audio.gd`.

`godot/scripts/simulation.gd`, `vehicle.gd` and the editor's calibration range contain authored development behaviour. They are not the gameplay authority and must not become Modern's simulation.

## 4. Three risks to resolve before bulk artwork

1. **Attractive scenery changes the fight.** New geometry, vegetation, shadows or haze alter spotting and suggest false cover. Control: source terrain, an original-visibility mask/proxy, conservative lighting and moving target-readability comparisons.
2. **Models disagree with the original frame.** Raw state, stale actor slots or conventional Euler rotations produce sliding tanks, misplaced turrets or mismatched aim. Control: scanout-paired transforms, actor lifetime identities, source arithmetic witnesses and projection checks.
3. **Added detail conceals a timing problem.** A GPU upgrade cannot repair a slow bridge; expensive resources can stall switching and saves. Control: measure source cadence, distinct draw-pass cadence and display cadence separately; set budgets before scaling production.

Exact source-state parity is testable. Identical human perception is not: new materials and silhouettes change perceived clarity. Review spotting, range judgment and aim correspondence explicitly, alongside automated visibility checks.

## 5. Proposed architecture

```text
Original PC simulation and renderer
                 |
      Scanout-paired read-only packet
      + camera / source epoch / frame
      + selected objects / transforms / source visibility
      + existing authoritative UI and event data
                 |
      Existing presentation mode selector
         |        |          |          |
        EGA    Genesis    Upscaled     Modern
                                        |
                              Modern asset instances
                              Source terrain / camera
                              Simple restrained shading
                                        |
                              Original visibility gate
                                        |
                              Existing restored UI
```

### State and identity

* Reuse the existing packet and resource catalogues. Add only fields proved necessary by the prototype.
* Distinguish source frame, render pass and timeline epoch. Never combine a vehicle from one pass with a camera or UI mask from another.
* Static instances use the original world-entry identity. Dynamic actors need a validated class/scenario link plus allocation lifetime; a reusable pointer alone is unsafe.
* Reuse `pc_vehicle_catalog.verify_live` as research evidence for class linkage. Establish its production applicability before introducing a live actor adapter.
* Read articulation only where the original exposes it. Do not infer independent turret motion from a generic tank rig.
* Apply no Godot physics, collision, navigation, hit detection, damage or AI to gameplay actors.
* Reset presentation caches on restore, mission changes, worker restart, rebasing and lost attribution. Unknown/incomplete data falls back to the supported Upscaled/source rendering for that frame.

### Visibility and composition

The original draw queue alone does not prove that an actor is visible through intervening geometry. Prototype an object-ID/coverage buffer and source-derived occlusion proxies from the paired draw pass. Use them to constrain Modern output, preserving original painter-order exceptions where ordinary depth would disagree.

New meshes must fit the source placement and aiming envelope. Do not hard-code invented hitboxes to make the modern mesh easier to hit. Where a refined low-poly mesh and the original target extent conflict, adjust the visual fit and document the compromise before accepting that class.

Concealed actors cannot contribute visible geometry, shadows, reflections, exhaust or new positional audio. Invalid attribution clears output immediately. Any smoothing/extrapolation of camera or target positions is excluded from the initial slice; investigate it separately only if measured source cadence makes it necessary and matched aiming can be demonstrated.

### Renderer decision

**Start the first playable slice on the existing Compatibility backend.** Use simple diffuse materials, conservative lights and simple shadows; preserve deliberate planar shading. Run a bounded comparison with Forward+ only if the accepted visual slice demonstrates a concrete need for its features.

Forward+ is a candidate if its additional features materially improve the agreed look and it passes legacy colour, UI, timing and packaging tests. Advanced volumetric effects are not a requirement for making this flat battlefield convincing. Godot documents the relevant feature and cost differences in its [renderer overview](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

The game must switch presentation modes within one already-initialized engine backend. Do not attempt to change the GPU renderer through Cmd+G. Any backend selection belongs to launch configuration. A Forward+ build must preserve the other three modes within that backend; a separate Compatibility fallback remains available if needed.

## 6. Delivery sequence

### Phase 0: baseline and finite scope

**Work**

* Retain the working alpha and profile backups.
* Measure ordinary, unaudited playback separately from the slower full-RAM-audit tests.
* Record original step rate, unique completed draw-pass rate, display frame times, input latency, bridge cost, CPU/GPU cost and memory.
* Capture repeatable views/routes for flat open terrain, roads, bridge approaches, source hills, structures, near/far actors, all stations, zoom and source-supported alternate display modes.
* Register every source asset family and variant, including shared shapes, replacements and unknown mappings. Each gets a source identity, reference, runtime binding and completion status.

**Exit:** a reproducible baseline, asset register and agreed performance budget. Fix blocking baseline timing defects before bulk Modern production. No inference that a repeated framebuffer represents a new original drawing update.

### Phase 1: geometry, scale and visibility prototype

**Work**

* Use plain diagnostic meshes first, in production Play.
* Bind one T-62 to an actual original actor and verify its origin, scale, facing, source lifetime and camera relationship.
* Check world-window rebasing, close clipping, partial concealment, disappearance, destruction and reappearance after restore.
* Prove the visibility/compositor approach on overlapping vehicles, a road, a structure and a crest before enabling finished lighting.
* Compare Compatibility and Forward+ without changing gameplay or taking either as the default prematurely.

**Exit:** source anchor projections within a proposed 0.25 original-pixel tolerance before raster rounding; no forbidden visibility; no actor-slot reuse ghosts; identical original packets/state on paired input routes. Tolerances are for transform accuracy, not permission to enlarge distant targets.

### Phase 2: one finished battlefield slice

**Work**

* Finish the T-62 as the first enemy reference, then an M1 and M113 to exercise different silhouettes and running gear.
* Build deliberately low-poly hull/turret/barrel/track meshes with meaningful extra geometry, broad readable facets, simple materials and minimal wear. Simple continuous track belts and polygonal wheels establish the initial detail level. Do not reuse the rejected flat vehicle panels or the photorealistic concept style.
* Add one restrained set of flat-ground and road materials, one upgraded low-poly source structure, one source-bound illustrated tree sprite, a simple sky and a fixed lighting setup. Test sprite coverage and viewing angles alongside model silhouettes.
* Review front, rear, side and oblique silhouettes at near/middle/far distances and in the gunner's actual zooms.
* Test driving, stopping, turning, aiming, firing, occlusion and wreck transitions in original mission routes. Turntables supplement these tests; they do not replace them.

**Exit:** a playable same-frame EGA/Genesis/Upscaled/Modern comparison, measured performance and Nell's approval of the visual direction. This is the first substantial taste decision; approve it before multiplying the style across the roster.

### Phase 3: complete actors and structures

Produce in batches, each accepted in-game before the next expands the register:

| Batch | Source coverage |
| --- | --- |
| Core tracked vehicles | T-62, M1-A1, M113, then T-64, T-72, T-80, M60a3, M2, BMP-1 and BMP-2. |
| Remaining ground classes | BTR-70, ACRV-2, BRDM-2, BRDM-3, truck and source `F-ST`; resolve ambiguous labels before choosing real-world designs. |
| Aircraft and weapons | HIND and its alternate representation, A10, MIGS, SAGGER and SPIGOT, using only observed source behaviours. |
| Structures and outcomes | Communications station, three building classes, headquarters, base, farm and every applicable replacement/wreck state. |
| World structures | Source-driven roads, bridge geometry and static scenery. Three class-table bridge entries share shape 167; do not assume they require three distinct meshes or that this entry alone describes the rendered bridges. |

The original source controls variant changes and destruction timing. Wreck details remain visual and do not add collision or cover. No modern-era upgrades to the vehicles.

**Exit:** every reachable registered class/state has an accepted binding, with eight-direction and three-distance image checks plus relevant live-route evidence. Missing/unknown variants remain explicit; fallback alone does not complete a required family.

### Phase 4: world materials across all eight scenarios

* Apply the approved ground/road treatment to the original map surfaces.
* Retain authored source slopes and landmark placement without adding procedural topography.
* Rebuild eligible structures and existing vegetation within original footprints and visibility constraints.
* Tune material repetition and grazing-angle shimmer on long moving routes. Reduce distant detail before adding blur.
* Check bridge decks, banks, contacts, building bases and ground intersections from all relevant stations.
* Review thermal/alternate source palettes for target legibility without inventing a new sensor simulation or identifying hidden classes.

**Exit:** all eight scenarios retain their original spatial layout, navigable routes and occlusion boundaries; no false cover, floating actors or road seams on the recorded routes.

### Phase 5: animation, effects and sound finishing

* Animate tracks/wheels from verified source movement. Decorative motion must not move the hull, sight or targeting reference independently.
* Improve muzzle flashes, impacts, explosions and source-triggered smoke. Retain event start/stop, coverage and concealment boundaries. No new ballistic simulation or persistent debris barriers.
* Keep camera shake and motion blur out of the aiming view by default. Keep the reticle and instruments outside scene post-processing.
* Reuse the current sampled audio and voice bank. Add/replace individual samples only where the Modern scene exposes a concrete quality problem; no gameplay recordings as live samples.
* Preserve original audio gates and event identities. Spatialization must not reveal additional actors or extend their audible range.
* Retake flat or mismatched speech selectively using the established directed generative workflow; do not regenerate the whole bank gratuitously.

**Exit:** event timing, mute/pause/fast-forward and restore checks pass, alongside moving-scene and listening review. Effects never obscure more of the tactical scene merely for spectacle.

### Phase 6: interfaces, switching and persistence

* Reuse the polished Upscaled cockpits, gauges, office, portraits, newspapers, lettering and memorial intro in Modern v1. Match scene colour around them without processing their text through bloom, fog or tone mapping.
* Keep existing layouts and controls. No new cockpit freelook, HUD information, auto-aim, wider FOV or extra map intelligence.
* Preload the active Modern resources and prewarm shaders before enabling its menu item. Toggling does no asset I/O and advances no source frame.
* Extend the cycle to EGA → Genesis → Upscaled → Modern where all are available. Aim for new Modern battlefield assets to work with the PC import alone, subject to their provenance and actual dependencies. Inherited Genesis-based frontend artwork remains behind the existing optional import. Test both configurations explicitly.
* Reconstruct Modern state from validated source/checkpoint data. Prefer deterministic visual animation phases or bounded presentation reset to serializing an independent scene simulation.
* Test save/load/undo with held steering/fire/modifiers, worker restart, repeated mode changes, fast forward, focus loss and fullscreen.

**Exit:** next-presented-frame switching, intact saves and no stale portraits, actor duplicates, residual particles, repeated sounds or altered controls. Upscaled remains the default until a separate decision changes it.

Fully 3D crew, a walkable office, rebuilt cinematic scenes and photorealistic portrait replacements are outside this first Modern pass. They would replace an already approved illustrated style and require their own brief.

### Phase 7: performance, acceptance and packaging

* Profile the assembled roster and all eight scenario entries at the normal source clock. Never alter guest CPU settings or skip source frames to meet a graphics benchmark.
* Test the current 1280×960 view and 1440p/4K displays with a native 4:3 viewport. Measure the actual viewport separately from the desktop resolution.
* Tune mesh LOD, texture residency, material reuse, shadow budgets, instance reuse and shader prewarming before adding advanced effects.
* Run current aggregate/parity tests, all-mode transition fixtures and at least a two-hour bounded Modern session, including repeated checkpoints and streaming boundaries.
* Check the packaged app on a clean profile, upgrade an existing profile, verify rollback, and test PC-only/Genesis-enabled/Modern-resource-missing paths.
* Retain PC-file requirement, optional Genesis handling, original-game exclusions and file-size guards. Model/texture provenance and third-party notices accompany the build. Signing, other-platform ports and publication remain separately authorized release work.

**Exit:** a locally reproducible Modern alpha with all required families accounted for, explicit remaining human mission/appearance/listening checks, and no claim that bounded replay alone proves every campaign outcome.

## 7. Asset pipeline and starting budgets

Use Blender authoring and explicit glTF/GLB exports, then Godot import. Keep native source files, exports, textures and provenance distinguishable. Players should not need Blender. This follows Godot's [documented glTF workflow](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

Each asset records source class/shape and variant, model bounds, pivots, source-to-model transform, material slots, LODs, articulation mapping, file hashes and licensing/source notes. Source-table fidelity governs dimensions and placement; historical references inform details rather than silently replacing the original proportions.

Initial authoring targets, to refine from the slice:

* Start with a few hundred to roughly 2,000 triangles for a major vehicle, guided by silhouette and deliberate facets. This is a provisional authoring budget, not a measured count from a generated image. Use cheaper distance representations only where they preserve the source target envelope.
* Flat palette materials or small shared atlases for vehicles/buildings. High-resolution illustrated tree sprites with mipmaps and clean alpha edges; avoid photorealistic surface sets.
* Shared materials for common tracks, tyres, glass and ground families.
* No landscape displacement. Avoid many transparent layers over the flat battlefield.
* Review silhouette-sensitive LOD manually. Godot provides [automatic mesh LOD](https://docs.godotengine.org/en/stable/tutorials/3d/mesh_lod.html) and [authored visibility ranges](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html), but neither may override source visibility or extend detection range.

Proposed primary acceptance target on the current M1 Max: sustain the original approximately 59.92-step/second clock and a 60 Hz presentation at the agreed baseline resolution, with steady-state p95 frame time ≤20 ms and p99 ≤33 ms. Hot switching should appear on the next presented frame with zero source advancement. High-detail 4K is a measured quality tier, not an assumed guarantee. Freeze practical CPU/GPU/memory budgets after Phase 2; investigate any monotonic memory growth during the long run.

## 8. Required comparison matrix

| Dimension | Required cases |
| --- | --- |
| Spatial design | Open flat ground, road edges, source slopes/crests, bridge approaches, structure overlaps and world rebasing. |
| Targets | Front/rear/side/oblique, near/middle/far, partial cover, overlapping actors, allocation reuse and source replacement states. |
| View | Four stations, original zooms and supported alternate displays, near clipping, resize and fullscreen. |
| Time | Cold boot, pause, source frame held, movement, firing, fast forward, checkpoint/undo and worker restart. |
| Modes | Same captured boundary through every available mode, repeated switches, invalid/missing assets and PC-only profiles. |
| Parity | Identical inputs, guest RAM/video, original events and campaign disk results on paired routes. Compare the original framebuffer, not Modern's deliberately changed pixels. |
| Perception | Target recognition, visible-versus-hittable fit, distance judgment, ground contact, motion clarity and audio mix. |
| Packaging | Clean installation, existing profile, no originals bundled, correct notices, preserved rollback and complete asset manifests. |

Working if: each applicable row has an actual result for the candidate; a showcase screenshot or passing model-import test cannot stand in for driving, aiming or source parity.

## 9. Scope decisions and first execution packet

Recommended defaults:

* Refined low-poly Cold War vehicles and buildings, illustrated tree sprites, quiet ground materials, and the restored frontend and typography.
* Preserve the flat terrain and existing spatial composition.
* T-62 first, then M1 and M113, in a real mission route.
* Compatibility-first prototype; renderer migration only after the comparison gate.
* No new engine, gameplay system, vegetation-scattering framework or whole-world procedural rebuild.
* One visual-direction approval after the complete slice, followed by final appearance/listening acceptance. Routine production and machine verification should not require repeated approvals.

Implementation is authorized. Prototype and asset authoring proceed in separate local lanes; integration remains gated by the source-alignment and visibility tests. The approved concepts settle the broad art direction. Actual in-game appearance, aiming feel and listening still require final human acceptance, without blocking independently executable machine work.

Estimate the remaining production effort from the measured time needed to finish, bind and verify those first three vehicles. Do not extrapolate from image-generation speed or import success alone. The dominant work is source-aligned integration and whole-roster acceptance.


## 10. Execution ledger, 28 September 2026

Candidate branch: `codex/modern-lowpoly`, based on the baseline above. No push is authorized.

* Baseline native production run: 1,200 single-frame samples, 59.153 effective source steps/second, exit 0. Evidence: `artifacts/modern-pass-20260928/baseline/pacing.json`. This is source cadence, not a display-latency measurement.
* Geometry register and deterministic generator cover 188 shape records, 31 class records and all eight source worlds. The register distinguishes authored geometry, actual source control geometry and unresolved visible commands. A fallback is not completion.
* Modern mode, optional-Genesis handling and same-frame cached-pass replay are integrated locally. First native convenience run passed 158 checks. Final-candidate rerun and aggregate acceptance remain pending.
* Rebuilt read-only trace core `c35599ad83d01e4f1207191938102e837e1cd67d791b5f3c86ef7074a6ae190a`: all eight scenario routes ran 54,657 original frames with 118 passing checks and byte-identical RAM/video/input against the independent baseline. Six held-input cases and 18 supervisor restore/failure cases also passed. These route endpoints contain no ellipse commands, so separate exact CPU/compiled-hook witnesses cover that boundary.
* A10/MIGS are genuine source cube meshes selected by executed ordinary actor allocation/render paths. Preserve those shapes rather than inventing aircraft silhouettes; shipped-mission occurrence remains unverified.
* Source ownership is reconstructed in a GPU viewport with original painter ordering. This proves the tested geometric envelope, not byte-exact VGA edge coverage. Native tests must show refined pixels as well as exclusion of concealed actors.
* The original evergreen uses two crossed crown planes and two trunk planes. The authored illustration maps to those source planes. No additional trees or camera-facing rotation are introduced.
* A failed headless preview process (PID 92945) was stopped only after Nell's explicit approval. New image tests use bounded deadlines and explicit rendering synchronization.

### Deviations

* Native source-shaped meshes are generated deterministically in Python and exported as GLB rather than requiring Blender. This preserves exact source coordinates and gives a reproducible editable authoring pipeline without another application dependency.
* The first runtime uses Compatibility with per-source-triangle anchor mapping and source-owner gating. Ordinary depth rendering would override the original painter-order exceptions. No Forward+ comparison is warranted unless a required effect demonstrates a need.
* Visibility ownership and refined geometry must share the current draw pass. Source circle/ellipse commands discovered during the asset audit require a read-only observation hook and source-CPU witnesses before the associated classes can be accepted.

### Remaining acceptance

Completed machine gates now cover close-range anchor mapping and ellipse witnesses, complete source-family dispositions, all 32 scenario/station views, all-mode and PC-only controls, held-input checkpoint parity, six native display transitions, and aggregate validation. Remaining: moving route/display-tier timing, the packaged two-hour soak, final packaged playback and documentation. The 59.92-step/second and 60 Hz presentation target is not yet met by the foreground diagnostics. Human mission completion, aiming feel and final appearance/listening acceptance remain distinct from machine checks.

### First-run import repair

The first Modern app candidate (`837898ec37d20ff33330`) crashed in Godot 4.7.2 while importing multiple fonts, before the soak started. `packaged-godot-import.log` records the worker-thread `propagate_notification` failure and SIGSEGV. The project now sets `editor/import/use_multiple_threads=false`; gameplay threading and source timing are unchanged. This is consistent with the upstream [multiple-font import race](https://github.com/godotengine/godot/issues/111039), rather than proof of an identical stack. A fresh app/profile import and full packaged run are required to accept the repair.

Working if: fresh profiles complete font import without engine errors, and the final packaged soak uses the repaired project unchanged.

### Integrated candidate, 29 September 2026

* Root native renderer: 142,090 checks passed after exact-packet reuse, scalar reuse and one-shot ownership. Root 32 source views: 195 checks, zero errors; the enlarged hill checkerboard is gone. Six native resize/fullscreen transitions passed at one unchanged source frame.
* Root all-mode controls: 161 checks with Genesis, 149 with PC-only. Short soak: 16,824 checks, 24 restores, all four stations, 48.911 measured normal seconds including 12.237 Modern seconds.
* Final aggregate after serial import repair: 472 Python tests and all Godot stages, `VALIDATION_COMPLETE artifacts/validation-20260928T231957Z`.
* The first app is diagnostic-only after its font-import crash. Repaired build `dd5771388f93645169ee` is in `artifacts/modern-pass-20260928/Abrams Modern Alpha v2/Abrams.app`. Both clean versioned installations imported successfully with the bundled engine after serializing first-run imports. Neither original game is bundled.
* Four real legacy campaign/checkpoint files stayed byte-identical through old/new provisioning in a disposable profile. Older app/build directories remain preserved.
* The first repaired-app soak attempt correctly rejected missing native focus and credited zero measured time. The fresh `packaged-modern-two-hour-v3` run completed; its final result and immutable-candidate limitation are recorded below.
* Timing diagnostics distinguish original steps, distinct original drawings, and actual GPU-presented frames. Occluded runs do not establish display performance. A fully focused V-sync-disabled diagnostic reached 53.364 original steps/second, display p95 25.984 ms and p99 32.207 ms. The production V-sync policy is unchanged; this diagnostic is not acceptance of the 60 Hz target.

### Performance priority and silent testing, 29 September 2026

Nell reports that Modern performance is poor and asks that sound remain off while she sleeps. The running immutable v2 soak was muted through the native Audio menu, with Master volume (0%) verified. Further native tests use the Dummy audio driver; consumer-state tests remain enabled. No acoustic listening acceptance is claimed. Performance repair takes priority over calling Modern finished. Original simulation steps, input order, source camera and checkpoint semantics must remain unchanged.

Working if: test launches are silent, current source steps and display intervals are measured separately, and performance improvements have exact presentation and gameplay regression evidence.

### Baseline stability result and environment beautification

The immutable repaired v2 app completed its native soak: 1,304,340 checks, zero errors, 240 restores, 7,204.293 measured Modern seconds and 7,572.039 total normal seconds. Final receipt: `artifacts/modern-pass-20260928/packaged-modern-two-hour-v3/soak-report.json`. Static memory rose from 118,445,073 to 120,874,007 bytes, with a 121,993,873-byte maximum. This proves the older v2 candidate's stability only. Its Modern normal delivery was 31.88 replies/second, which confirms the performance complaint. The later presentation optimizations require their own checks.

Nell additionally requested texture/colour variation for buildings, hills and water. Scope: restrained Modern-only plaster/stone grain, roof toning, broad terrain colour patches and calm water variation; preserve every original surface, silhouette and visibility rule, with no photographic vehicle textures, added terrain geometry, shadows or speculative simulation. Existing pinned, mipmapped terrain textures are reused, with no new download or generation dependency.

Working if: native screenshots show the surface treatments, vehicle and unsupported-sensor output remains unchanged, original source anchors and ownership tests pass, and timing is measured with the new materials enabled.

### Environment pass, final local validation

The Modern surface pass is implemented and visually checked: fine plaster/stone grain, restrained clay roofs, broad terrain colour patches and subdued water ripples. No vehicle texture or geometry/visibility change was introduced. Root checks: 154,494 native renderer checks; 1,260 native compositor checks; 18 environment material checks; 195 checks across 32 actual source scenario/station frames; aggregate `VALIDATION_COMPLETE artifacts/validation-20260929T021804Z` (472 Python tests and all Godot stages).

Repeated source images now reuse PNG decoding and cockpit composition. Visible-object motion dependencies exclude off-screen actors from mesh invalidation. Production-owned world/cockpit render targets rest on exact unchanged input and refresh on changed data, modes, resize and fallback. Frontend animation and arbitrary mutable texture inputs continue rendering. Native hidden-node sentinels prove retained pixels and immediate recovery. The dispatch-deadline hypothesis was measured and rejected, leaving original scheduling untouched.

Focused stationary timing improved from 35.75 to 43.22 original replies/second. The corrected moving-input diagnostic (`beauty-moving-focus-gated`) delivered 2,040 single-frame requests over two route cycles, maintained native focus for all replies, observed all four stations and 299 positions, and averaged 39.53 source replies/second. Display mean/p95/p99: 21.53/46.52/52.89 ms. Its earlier focus-lost run is explicitly non-accepting. The target-rate performance gate remains open. This environment pass does not declare the complete modernization programme finished.

### Model artistic refinement, 29 September 2026

Nell's latest “Proceed please” authorizes the quoted model-refinement pass. Local authoring and validation only; no push, publication, new aircraft gameplay or changes to original simulation, visibility, dimensions, trees or terrain. Keep native tests silent with the Dummy audio driver.

Authoring revision 3 adds restrained tank roof hatches, rear-deck grilles, recessed muzzle bores, olive APC upper sides, matching cockpit glazing for both original Hind states and better-proportioned building openings. Slimmer bevels remove the broad picture-frame treatment. Native inspection exposed an existing farm-annex centroid defect; the annex now recesses toward its own source-derived interior. Earlier previews also caught turret facet noise and coplanar APC wheel/skin overlap, both repaired before acceptance.

The independent geometry suite has 20 passing checks, including closed reliefs, bounded costs, grille clearance, Hind-state correspondence and the annex regression. Native renderer: 157,006 checks passed. Environment/model studies: 35 checks, zero errors, including unchanged vehicle pixels when environment variation is toggled. All 32 actual scenario/station frames passed 195 checks. The Hind model studies use repositioned source faces, not evidence of a Hind encounter in those 32 mission frames.

The foreground moving diagnostic completed 2,040 samples at 39.698 original replies/second. Final focus/route receipt, aggregate validation and fresh package checks are recorded in the model-refinement report once complete. Original source timing is unchanged; the 60 Hz performance target remains open.

Working if: the integrated assets pass source ownership and native model/mission-frame checks, testing remains silent, a fresh local alpha contains the exact validated catalogue and excludes originals, and remaining performance/human-play acceptance is stated separately.


### Full-roster model polish, 29 September 2026

Nell's “Another pass please, on all models” authorizes local authoring across the full roster, with the previous simulation, source-visibility and silent-testing boundaries retained. No push or publication is authorized.

Authoring revision 4 touches all 57 authored polygon definitions: constant-width bevels, restrained per-type paint/material separation, truck cab details, Hind engine intakes, original BRDM wheel refinement, quieter wreck facets and more distinct buildings. Flat roofs retain stone/concrete; original pitched civilian roofs may receive clay. Bridge decks and weapon-crew sheets preserve their exact source planes. Trees, terrain, unresolved aircraft cubes and all source identity fields remain unchanged. The complete catalogue has 18,792 triangles, 542 fewer than revision 3.

The same author implemented and visually inspected the pass. Regression tests caught the revision assertion that still expected 3; it now expects 4 and includes six additional geometric/roster cases. Native close-ups exposed coplanar truck glazing and BRDM wheel/body faces; source-derived cab centring and separated inward wheel planes repair them. The BRDMs no longer receive a second set of wheel relief on their hull.

Root verification: 26 geometry tests, 157,242 native renderer checks, 295 checks over 57 source-root model studies plus hill/water references, and 195 checks across 32 actual mission/station frames. All pass. The material study separately captured upper/front and lower/rear diagnostic poses; it does not establish normal mission encounters. Aggregate `VALIDATION_COMPLETE artifacts/validation-20260929T092350Z`: 482 Python tests and every Godot stage passed.

The focused, two-cycle moving probe completed all 2,040 samples across four stations: 46.045 source replies/second, display mean 20.797 ms, p95 49.853 ms and p99 51.307 ms. Source throughput is higher than the prior measured route, but display p95 remains worse and machine-load differences prevent attributing that change solely to the smaller catalogue. The 60 Hz target is still open. Audio used the Dummy driver throughout. Fresh-package results are retained in the ignored `model-polish-2/report.json` receipt; older apps remain immutable.

Working if: the exact revision-4 catalogue is in the new local alpha, both fresh PC-only and optional-Genesis profiles pass packaged save/load/undo and mode/fast-forward parity checks, original game files stay outside the bundle, and performance limits remain explicit.
