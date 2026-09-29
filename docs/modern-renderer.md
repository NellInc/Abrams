# Modern renderer: source-owned low-poly presentation

## Scope and current boundary

Modern is a Compatibility renderer presentation of a paired original draw pass. It adds no physics, targeting, collision, navigation, camera extrapolation, actor simulation, terrain displacement, lights, shadows, reflections, or positional audio. The existing PC simulation remains authoritative.

The runtime uses the generated catalogue's bounded triangle geometry directly, rather than loading a separate scene graph per actor. The catalogue and its GLB previews share the same generated geometry. `docs/modern-asset-register.md` records source identities and unresolved families. Availability requires the pinned original SIM/shape resources, structurally valid geometry, and the pinned illustrated tree. An unsupported backend or missing resource leaves Modern unavailable. Unsupported source palettes use the original source palette and geometry for that frame.

This is a conservative source-silhouette renderer. New rounded corners and tree alpha gaps can remove old filled pixels. New model geometry cannot extend beyond its original object's reconstructed visible silhouette. The original hidden actors stay hidden inside those gaps; sky and source terrain form the underpaint. Validated bitmap effects use the bounded authored-contour refinement described below, retaining all original hidden-actor coverage.

## Public integration API

`pc_draw_pass.gd` exposes:

* `load_modern_assets(root) -> bool`: verifies and preloads the optional local assets. Native use also performs an isolated GPU warmup before returning success.
* `modern_enabled`: selects the preloaded presentation when the next paired pass is applied. It does not advance the guest.
* `modern_status`, `modern_prewarmed`, `modern_frame_status`: resource, GPU warmup, and current-frame status.
* `modern_polygon_count`, `modern_triangle_count`, `modern_tree_count`, `modern_fallback_polygon_count`, `modern_running_gear_triangles`, `source_round_count`: emitted detail and explicit fallback coverage.
* `modern_assets.disk_io_count`: cumulative logical file probes, reads, hashes, and image loads. Frame mapping and mode switching do not call those operations.
* `modern_assets.max_anchor_error`: maximum accepted projected source-anchor error in the applied pass.

An empty or unavailable pass clears meshes, ownership, counters, and frame status immediately. Only immutable geometry, palette, and image resources persist. There is no actor-slot cache, retained transform, motion history, effect simulation, or sequence-dependent object identifier to survive a restore incorrectly.

## Per-frame algorithm

1. **Reconstruct original ownership.** `pc_modern_ownership.gd` renders the original painter sequence into a same-size, unlit, non-antialiased SubViewport. Each original object/context receives a pass-local ID equal to its array index plus one. Polygon fills, original one-pixel line strips, opaque bitmap runs, and observed round-command spans participate. Background is ID zero. No source actor is admitted merely because it appeared in the original draw queue.
2. **Retain source terrain as underpaint.** Catalogue entries classified as source surfaces keep their existing geometry and material treatment. Sky receives a restrained direction-linked daylight gradient; ground retains its authored daylight palette in Modern. This underpaint remains available through new model or foliage gaps.
3. **Reconstruct paired geometry.** Selected original primitive vertices supply the observed camera-space anchors. Each catalogue face maps refined local geometry through those anchors. An ordinary Euler rotation never substitutes for the original packed arithmetic. The source matrix's consequences are already present in the original camera vertices.
4. **Gate every actor fragment.** Refined geometry, trees, sprites, and unsupported actor fallbacks sample the original ownership texture. A fragment survives only when the ownership ID matches that exact same-pass object. Later original terrain, structures, actors, and opaque bitmap pixels therefore hide earlier actors even when conventional depth would disagree.
5. **Resolve self-occlusion.** The Modern shader enables depth within this ownership gate. Refined triangles and tree planes write their real reversed-Z depth. Painter-only source underpaint/fallback writes far depth zero. Cross-object visibility remains controlled by source ownership, while wheel cylinders and recessed surfaces can correctly occlude each other. Legacy rendering keeps its original depth-disabled shader.
6. **Preserve authoritative source commands.** The ownership blue channel marks round-command writes separately from model polygons. Exact captured span rectangles select direct palette indices. The per-object `draw_order` determines whether a later polygon or round write owns each pixel. This prevents newly refined geometry from painting over a later original command merely because it shares an object ID.

The SubViewport texture is a GPU dependency of the main material. Runtime frames do not read ownership back to the CPU. Native tests do read it back to verify encoding and ordering.

Working if: native tests observe the expected owner IDs, concealed objects contribute zero pixels, source command ordering survives, and a changed/restored pass displays on its first forced render with no stale mask.

## Projection and geometry fidelity

The first fit is an affine source-face frame constructed from three non-collinear original anchors. Every remaining anchor is checked against the observed camera vertices. The acceptance threshold is 0.25 original pixel before raster rounding.

Original vertices undergo independent integer rounding. A single rigid float fit can therefore disagree with a close-range face even when all source data are correct. For disagreements of at most two raw units, the renderer instead interpolates the original face triangulation piecewise. This reproduces each paired anchor and keeps shared interpolation boundaries continuous. Larger disagreement, degenerate geometry, a missing source primitive, an unsupported root, or unknown shape retains its source face. The threshold is never relaxed to hide drift.

Refined vertices retain actual camera depth and undergo the existing near-plane clipping. The owner pass clips the original geometry independently. Models use source-local raw axes and bounds; `DISPLAY_SCALE = 64` remains a display convention, not a claim about physical metres.

The illustrated tree uses source shape 103's existing crossed planes. Its crown primitives are 10549 and 10564; its trunk primitives are 10541 and 10571. There is no camera-facing billboard or expanded quad. The generated image remains unchanged, with alpha cutoff 0.85 and separate crown/trunk UV ranges. Both source polygons and texture alpha must permit a visible fragment. Original colored crown triangles are omitted once the image binding is valid.

## Exactness limits

Polygon ownership reuses the existing reconstructed camera-space source fills and line strips at the presentation resolution. It is a geometric, original-painter ownership proof. It is **not byte-exact reproduction of the original VGA scanline edge-inclusion and rounding rules**. The 0.25-pixel anchor tolerance is a transform criterion, not an exact native raster claim.

Original bitmap opaque runs and newly observed round-command spans do carry original pixel coverage directly. Unsupported opaque source commands remain the responsibility of the upstream original-frame fallback. They are not silently replaced by an invented shape.

New cutouts can reveal source terrain where the old opaque silhouette existed. They never reveal an originally concealed actor. This preserves source tactical ownership conservatively, but does not establish identical human spotting, range judgment, or target recognition. In-game visual acceptance remains necessary. Source fallback is counted and does not complete an unresolved asset family.

## Resource and shader warmup

The loader pins `SIM.EXE`, `SHAPE.GI`, and `SHAPE.TBL`. Scenario provenance hashes are recorded in the asset catalogue but are not treated as immutable runtime dependencies, since campaign data may legitimately change. Tree image hash, dimensions, metadata identity, and alpha cutoff are checked. A failed reload clears resources rather than retaining an earlier successful catalogue.

The loader creates palette textures and tree mipmaps once. It then draws the actual Modern and ownership shader programs into an isolated 4 by 4 RenderingServer viewport, forces GPU completion, and checks the readback dimensions. The temporary viewport, scenario, camera, and instance use server RIDs directly: production calls the loader synchronously in `SceneTree._initialize`, before its new nodes enter the tree. Warmup therefore must not depend on `Node.is_inside_tree`. All temporary RIDs are released after the GPU readback. This does not modify the active source mesh or advance a guest frame. Headless runs explicitly skip GPU warmup; they test loader and geometry logic only.

The warmup verifies submission of both programs, rather than asserting a future hardware driver's complete pipeline-cache behavior. Same-frame switching is measured by the integration tests separately from cold-load cost.

## Verification

Finite renderer gate:

```sh
./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_modern.gd
./tools/godot.sh --rendering-method gl_compatibility --quit-after 1200 --script res://tests/test_pc_modern.gd -- --native
./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_surfaces.gd
./tools/godot.sh --headless --quit-after 1200 --script res://tests/test_pc_sprites.gd
```

`test_pc_modern.gd` has a separate 120-second wall-clock failure exit. Captures use `force_draw` and `force_sync`; no unbounded `frame_post_draw` wait is required.

Coverage includes malformed/missing catalogues, unknown identities, unsupported source palettes, exact GPU owner-byte roundtrips across both ID channels, close clipping, deliberately oversized refinement, a farther later painter occluder, opaque and transparent bitmap pixels, same-frame movement and epoch reversal, actor disappearance, restore/rebase reconstruction, round-command order/rejection, an observed original-CPU ellipse fixture with 868 exact pixels, source-position-linked running gear with unchanged geometry and restore identity, illustrated alpha gaps over a hidden actor, and invariant asset-I/O counts through source/Modern comparisons. Native checks require actual refined pixels; complete actor disappearance cannot count as a successful changed image.

The suite also replays captured original production draw passes and writes close/middle comparisons of their observed T-62 camera geometry. Those translated closeups are diagnostics, not substitutes for a live close-range mission route. Production switching, checkpoint, worker restart, timing, and packaging remain the root integration suite's responsibility.

Artifacts are written to `artifacts/pc-modern-renderer/`, including source/Modern replay pairs, T-62 close/middle views, ownership diagnostics, and a tree over a deliberately concealed actor. These images were produced by the implementation under review; machine assertions accompany them rather than a self-awarded appearance score.

## Running-gear phase and remaining acceptance work

Wheel geometry stays fixed, with subtle spoke/hub markings and track-band markings driven solely by the paired actor's absolute `world_position_raw` coordinate combination `x + sqrt(2) * y`. Only a matching dynamic pointer and shape can supply that anchor. Camera, source yaw, epoch, sequence, and wall-clock time contribute nothing. Static objects remain unanimated. Translation changes the phase; reversing to the same source position restores it exactly, including after serialization or a world-window rebase.

This is a position-anchored visual displacement cue, not a physical odometer or tangential wheel-travel calculation. The irrational axis weighting avoids exact cancellation for opposite-sign integer-grid x/y displacement. Correct accumulated wheel travel over arbitrary turning paths would require additional authoritative travel history; the renderer does not invent such history. Markings remain inside the unchanged wheel/track geometry and original ownership envelope.

The Compatibility gate does not constitute a Forward+ comparison. There are no new dynamic shadows, volumetrics, debris, muzzle events, or sampled audio in this renderer. Existing source-triggered effects and audio remain in their established paths. Final mission-route, appearance, listening, long-session, and display-tier acceptance must be reported with their actual results rather than inferred from this bounded renderer test.

## Recorded renderer result

The final bounded Compatibility renderer run passed **142,033 native checks**. The corresponding headless suite passed **91 checks**. Existing legacy color verification passed **1,280 exact RGB checks with zero failures**; existing sprite verification passed **seven native pixel checks**. Headless source-surface and sprite suites also passed. `git diff --check` reported no whitespace errors on the integrated tree at handover.

These results cover the renderer implementation and the source-derived ellipse fixture, with the scope limits above. They do not substitute for root-owned production, performance, packaging, long-session, or human acceptance evidence.

The synchronous-startup regression is additionally covered by `test_pc_modern_startup.gd`, which passed natively with `entered_before_load=false` and `prewarmed=true`. After that correction, the real production ScenarioFrames command with `--boot --play --trace --capture --no-audio --graphics modern` passed **195 checks across all 32 station/scenario views with zero errors**. Its report and native captures are in `artifacts/modern-pass-20260928/startup-repair-scenario-frames/`.

Modern source fallback and terrain faces resolve original 2x2 material dither to the existing mean-color lookup, including unclassified hill faces. This removes enlarged checkerboards without changing source silhouettes or ownership. The mean texture is bound even with no recognized hill. Unsupported palettes retain the original dither path; direct bitmap palette entries and explicit observed round-span colors remain unchanged. `quiet_source_dither` supplies native assertions for these boundaries; the follow-up headless check verifies the texture binding.

## Exact-packet mesh reuse

`pc_draw_pass` retains a single deep-copied paired packet and the current mesh, including the ownership mesh. A hit requires full recursive packet-content equality, matching presentation mode/palette, asset loader revision and texture/configuration references, Compatibility method, and viewport dimensions. It never uses sequence, pointer, or page identity alone. Mode changes and asset loads invalidate immediately. Empty or unavailable passes clear the slot; unsupported Modern palettes are not cached. A different restored packet rebuilds deterministically. Loaded model geometry is immutable between `load_assets`, `configure`, or `load_tree` revision changes.

Cumulative `mesh_build_count` and `mesh_reuse_count` expose the optimization. A hit retains all matching frame counters and source geometry; it does not skip guest frames or original UI work. The later one-shot ownership optimization retains the identical completed mask on a hit. Tests cover independent equal packets, same-identity and in-place mutations, restore, palette/mode/viewport/resource changes, and empty/unavailable data. Performance benefit requires a fresh production profile and is not inferred from the unit hit count.

After the quiet-ground and exact-packet reuse changes, the bounded native renderer gate passed **142,053 checks**, the headless gate passed **105 checks**, source-surface headless checks passed, and `git diff --check` passed. The added native mean-color oracle initially rounded half-byte means incorrectly; its expected value now follows the existing integer lookup quantization. Native bitmap, round-command, unsupported-palette, and ownership checks passed unchanged. Root-owned production visual and timing rechecks are still required for this follow-up.

## CPU build instrumentation

Set `draw_view.profile_builds=true` to receive `last_apply_timings_usec` after each solid `apply_pass`. Fields are `total`, `cache_check`, `ownership`, `mapping`, `upload`, and boolean `reused`. Ownership includes source-mask geometry construction and resource submission; mapping includes model/tree mapping; upload covers main mesh/material construction and submission. Remaining total includes palette work, source fallback construction, sorting, append operations, and snapshot copying. These are CPU durations, not GPU completion timings. Disabled instrumentation avoids clock reads.

Affine source-face scalar invariants are computed once per fit, preserving the prior per-vertex arithmetic order and piecewise fallback. Facet color lookup is performed once per facet. Sorting and source visibility are unchanged. An exact-result test compares the optimized transform against the prior expression. Ownership uses `UPDATE_ONCE` on every prepared packet, including viewport resize. Reused packets retain the completed full-resolution mask without redrawing it. The native retained-mask test requires identical scene and mask bytes across three cache hits, hides the ownership geometry without requesting an update to prove no redraw occurs, and verifies changed/restored packet updates.


The affine/facet CPU changes and one-shot ownership gate passed **142,090 native checks**, **133 headless checks**, source-surface checks, and whitespace validation. All **22 retained native PNGs were byte-identical** to their pre-optimization captures (`artifacts/pc-modern-renderer/pre-cpu-opt-image-hashes.json`). The retained-mask test proves no redraw with a deliberately hidden ownership mesh across three cache hits, then verifies changed-packet and restored-packet images. An initial test incorrectly expected the node's update-mode getter to reflect rendering-server consumption; the [engine getter](https://raw.githubusercontent.com/godotengine/godot/master/scene/main/viewport.cpp) returns the configured property, so rendered sentinel evidence replaced that assertion. Production timing still requires the root's focused profile.

## Surface variation and repeated-frame work

The roster highlight pass is presentation-only. Verified bridge line records use the existing source-line geometry and far painter depth with a dedicated palette lookup (kind 15). APC/utility hull paint uses kind 20.5 and original object-local UV2 coordinates; it is excluded from building grain and running-gear markings. Paint derivatives are evaluated before source-ownership discards, avoiding unstable boundary pixels. Both treatments obey the existing source-ownership mask, and unrecognised identities or sensor palettes retain the original fallback. See [the asset register](modern-asset-register.md#roster-material-highlights-authoring-revision-7) for the affected models and materials.

Verified Sagger/Spigot head commands use kind 23 for a small procedural helmet/face treatment. UV2 follows the captured screen center and radii, while geometry remains the exact original raster spans. The round-command ownership channel, clipping and painter depth remain unchanged. Unsupported palettes and unknown command identities keep the original colour. The offline mesh preview includes a labelled authoring approximation of the separate head command; it is not a runtime visibility fixture. Ruins and base markings use source-attributed catalogue geometry, with unchanged simulation footprints and source visibility boundaries.

Modern buildings use restrained plaster/stone grain over individually authored wall and roof colours. The farm's ochre roof and green courtyard, the red-ridged building, slate roofs and pale façades retain their colours when surface variation is disabled. The roof classification excludes ground aprons and bridges. Modern grass, hill faces and the farm courtyard use subtle procedural coarseness, with no sampled grass or hill image. Broad world-anchored colour variation gives the terrain gentle tonal shifts; fine grain fades with its projected pixel footprint to avoid distant shimmer. The verified hill faces using source grass material 19 receive a fresher green ramp. Other hill materials, including the earth variants, retain their colours. The road treatment is unchanged. Water detail is restricted to the pinned original river roots and primitive IDs, including the original coast outline. It adds calm, distance-filtered ripple shading on the existing opaque plane. Building, road and water treatments retain their existing image-based detail; other graphics modes retain their original terrain rendering. Vehicles, silhouettes, hit detection, source heights and sensor fallback palettes are unchanged. The terrain material test substitutes sentinel grass/hill images and requires identical Modern terrain pixels, then changes and restores the source origin to check deterministic grain placement.

The Play viewer retains one exact successful cockpit composition. Source pixels, complete presentation metadata (apart from unused scanout delivery counters), program, mode, layout and world texture must match. Checkpoint restoration, graphics switching and asset loading invalidate it. Every original reply still reaches input, audio and world processing. Identical source PNG bytes reuse the decoded image and source texture; hidden research labels are no longer laid out during Play. The mesh cache ignores only top-level delivery sequence, RAM-audit digest and EGA storage-page identity, while comparing all camera, geometry, painter ownership and palette data, plus the absolute running-gear phase of each visible object. Off-screen actors continue to simulate without forcing unchanged visible meshes to rebuild.

Play also retains the rendered world texture on exact mesh-cache hits. The final cockpit texture rests only when its input is that production-owned source viewport and its complete composition key matches. Arbitrary mutable textures and animated frontend screens continue to redraw. A new source packet, mode change, resize or fallback requests a fresh render. Native hidden-geometry sentinels verify actual retained pixels, rather than relying on the viewport's update-mode getter.

Final surface validation passed 154,494 native renderer checks, 1,260 native compositor checks, 18 material-study checks, and all 32 scenario/station views (195 checks). Material studies separately require identical geometry and zero altered T-62 pixels when surface variation is toggled. Aggregate validation completed at `artifacts/validation-20260929T021804Z`, including 472 Python tests. Native launches used the Dummy audio driver throughout this pass.

The focused 1,200-frame stationary run improved from 35.75 to 43.22 original replies/second across the presentation optimizations. A subsequent two-cycle, 2,040-frame moving route averaged 39.53 replies/second, observed all four stations and 299 distinct original positions, and retained actual focus for every measured reply. Every request advanced exactly one original frame. Its display mean/p95/p99 were 21.53/46.52/52.89 ms. These results are below the 59.92-source-step and 60 Hz display targets, so Modern remains experimental. A suspected dispatch-clock error was measured and rejected; the original scheduler was left unchanged. The earlier moving diagnostic lost focus and is not used as acceptance evidence. Timing receipts are under `artifacts/modern-pass-20260928/profile-retained-composite` and `beauty-moving-focus-gated`.

## Sky, water, foliage and armour polish

The daylight background now has a blue-to-pale-horizon gradient and quiet cloud
banks evaluated from the original camera direction. Only the observed sky
background material qualifies. Original horizon geometry, ground and actor
coverage remain unchanged. Clouds are static in source-world angular space:
turning changes the view, translation does not move them, and restoring the
same packet restores exactly the same image.

Water keeps its original opaque planes, river outline and depth. Existing
filtered ripples gain a restrained blue-green tint, broad glints and a
sky-coloured grazing-angle sheen. There is no reflection pass, displacement,
transparency, clock animation or new bank geometry. Fine detail still fades
with distance and projected footprint.

Illustrated trees keep their existing images, alpha cutoff and crossed planes.
Material colour lifts dark crown facets and trunk highlights. A small per-tree
tint is tied to source placement, rather than the camera or reusable object
slot. Grass uses a fresher green, separated from olive vehicle paint. Roads
retain their coarse relief with a warm charcoal balance instead of green.
These adjustments apply only to verified terrain surfaces in Modern.

The exposed cupola and driver armour receive matching olive paint in Modern
only, including the driver view's moving turret and barrel.
Its ink, shaded facets and source-owned silhouette remain intact. Measured
fastener, hinge and latch contours retain neutral metal. The registered donor's
ink edges delimit the hardware at native texel resolution, avoiding the pale
halos and rectangular patches left by the initial coarse masks. The mask is
prepared once in each opaque donor texture's alpha channel; the shader restores
opacity before compositing. RGB artwork is unchanged and no extra texture
sampler or per-pixel fixture loop is needed. EGA, Genesis and Upscaled keep their
previous presentation. The driver instrument housing and live readouts retain
their existing colours. The upper sky is bluer, preserving the pale horizon.

Working if: matched native comparisons preserve all donor RGB bytes, hardware
contours, live cells and non-Modern frames; driver paint follows both signed
turret offsets; terrain geometry and actor colours remain identical. Evidence:
`artifacts/modern-palette-balance-20260929/`.

### High-resolution effect contour repair

The 20 existing authored effect donors were already high resolution. Modern's
original per-pixel ownership mask was cutting their contours back into coarse
source-pixel steps. For an exactly validated effect binding, ownership now
combines the original opaque pixels with the authored alpha cutout inside the
original bitmap bounds and clip, at the same painter position. Later original
objects still cover the effect. Retaining the original mask prevents a hole in
the redraw from revealing an actor that the original effect hid.

This deliberate, bounded silhouette refinement applies to all 64 effect bitmap
bindings. It changes neither source phase/LOD selection nor event duration.
Unknown bindings and palettes keep the original sprite. No new donor was
necessary. The shared path covers projectile effects without guessing which
source bitmap corresponds to a particular weapon from its appearance.

Working if: native sky/water/tree tests preserve geometry and source packets;
legacy pixels match the preceding shaders; all 64 effect bindings render their
authored contours with later-occluder and original-coverage protection; cache
reuse remains active; restored frames are byte-identical; all four stations
across all eight captured scenarios render without warnings. Local evidence:
`artifacts/modern-environment-polish-20260929/`.
