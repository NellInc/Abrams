# Deterministic range simulation contract

`godot/scripts/simulation.gd` is an original-authored calibration exercise. It does not recreate any original mission, damage model, enemy behaviour, scoring formula, or campaign. All four targets are stationary practice targets. Their abstract hit points and equal shell damage are calibration assumptions. Smoke emits an event and consumes a charge; there are no incoming weapons or smoke protection to simulate here.

Ordinary Play exposes this exercise as **Extras > Practice Range**. The tank-cover
main menu shares its presentation scene, in an isolated viewport owned by the
original-game viewer. Settings and artwork comparison share that frontend; no
original guest frames or checkpoints run while it is open. The editor's default
scene remains a direct practice-range development entry point.

## API and ownership

The class extends `RefCounted`, with no scene tree, `Input`, wall clock, physics engine, audio, or random-number source. Construction reads the checked-in JSON configuration. `reset(seed = 1988)` resets all runtime state; seed is recorded for reproducibility and currently has no behavioural effect. `tick(commands)` advances exactly 1/60 second and returns a fresh array of event dictionaries. Once won/lost, ticks return no events and do not mutate state. The caller decides when to pause by withholding ticks.

Public state: `pos: Vector2` (world x,z), `heading`, absolute `turret`, `elevation`, `speed`, `station` (0 gunner, 1 commander, 2 cupola, 3 driver), `control_hull`, `thermal`, `zoom_level` (0/1/2 for 1x/3x/10x), derived read-only `zoom` (`zoom_level > 0`), `weapon` (0 HEAT, 1 SABOT, 2 AX, 3 COAX), `ammo`, `reload_ticks`, `mg_cooldown_ticks`, `fuel`, `hull`, `smoke_count`, `elapsed_ticks`, `status`, `targets`, `selected_target`, `locked`. The renderer treats these as read-only. Positions and speeds are metres and metres/second. Heading zero points world -Z. Positive heading rotates left: forward vector is `(-sin(heading), -cos(heading))`.

Commands are a per-tick dictionary. Missing axes equal zero; missing one-shot actions equal false. The input layer supplies one-shot actions edge-triggered, once per key press, never every render frame; Space queues `fire` once, so holding it does not re-fire when the reload ends. `machinegun` is the one deliberately level-triggered action: `main.gd` sends it every physics tick while M is held, and `mg_cooldown_ticks` sets the cadence.

| Command | Contract |
| --- | --- |
| `throttle`, `steer` | Finite axes clamped to [-1,1], active in hull mode outside cupola. |
| `turret_axis`, `sight_axis` | Finite axes active in turret mode at all stations. Sight axis raises/lowers elevation, positive upward. Either manual aim axis releases lock. |
| `stop` | Keypad5 zeroes speed and suppresses movement/steering for that tick outside cupola; explicit authored-range immediate-stop behaviour. |
| `station` | Integer0..3. Invalid enums ignored. |
| `toggle_control`, `align_turret` | All stations. Alignment releases lock. |
| `toggle_thermal`, `radio` | Gunner and commander. |
| `toggle_zoom` | Gunner only, cycles `zoom_level` 0,1,2,0 for 1x,3x,10x. Commander Z is a presentation-owned map toggle and does not change simulation zoom. |
| `select_weapon`, `fire`, `smoke` | Gunner only. `select_weapon` accepts0..3 internally; UI exposes main shells0..2. |
| `machinegun` | Gunner M fires COAX directly, without changing selected main weapon or its independent reload timer. `fire` and `machinegun` may both fire in one tick when each weapon is ready. |
| `select_target`, `lock_target` | Gunner only. Cycle eligible targets then none. Eligibility uses a provisional sight cone, `selection_half_angle` (0.35 rad) both horizontally around turret bearing and vertically around elevation from each target's center-height pitch, plus the manual-grounded maximum range. Because the upper elevation clamp is also 0.35 rad and target pitches are slightly negative, no target is selectable with the sight at maximum elevation. Lock follows selected target bearing and center-height elevation; death/range loss invalidates it. |
| `scan_bearing` | View-only command, deliberately ignored by simulation. UI maintains commander view offset0/90/180/270 relative to turret. |

Motion decelerates when throttle is released. Hull turning carries an unlocked turret. A locked turret stays aimed at its target. These are explicit remaster input choices; the original's accelerating spin and continued-motion keyboard behaviour are not reproduced. Movement clamps to the authored range bounds and stops at the edge.

Events include `fire`, `impact`, `hit`, `reload`, `smoke`, `voice`, `won`, `lost`. `position` is a Vector2 where supplied, `text` a display message, `cue` an audio identifier. Fire adds `weapon`; impact adds `target` index or -1, and `weapon`; hit adds `target` and `destroyed`. The tick's array is the sole event output; presentation must consume it once. Hitscan chooses the nearest alive target intersecting the shot line within weapon minimum/maximum range. Flat authored range geometry places the sight at 2.65m and target centers at 1.8m. At each target's forward distance `d`, shot height is `2.65 + tan(elevation) * d`; a hit requires horizontal error at most5.5m and vertical error at most1.8m. These forgiving target extents and the elevation rate/clamps are provisional, with no original ballistic parity claim. Elevation is radians, positive up, provisionally clamped to [-0.15,0.35]. No gravity or ground collision is simulated; miss impact height reports the ray endpoint and may lie below ground. `impact` adds `height` for presentation. `elevation_to(point)` provides the clamped target-center pitch used by lock. Hit events describe abstract practice-target damage.

## Evidence and provisional rules

`godot/data/range.json` labels its map and targets as newly authored. `godot/data/provisional_rules.json` distinguishes known manual evidence from unknown original values. Manual evidence covers station/control permissions, weapon ranges, nominal4-second main reload, total40 main rounds and80 MG rounds. The main-ammunition split, AX5-second reload, MG cadence, handling/fuel constants, target size/HP/damage, smoke count and selection cone are provisional. Damage effectiveness against actual original enemy classes is intentionally absent. See `docs/original-mechanics.md` for the source extraction.

Win: all four targets destroyed. Loss: fuel or hull reaches zero. No range enemy causes hull damage; the hull field is reserved for future authored exercises. Fuel exhaustion is reachable. The final tick may emit the final hit and win together. Once complete, reset is required to restart.

## Snapshots

`snapshot()` returns a deep, JSON-safe dictionary, version2 and authored-range ID included. Vector2 positions become two-number arrays. For exact replay serialisation use `var_to_bytes(snapshot)` and `bytes_to_var(bytes)` without object decoding. JSON is suitable for inspection/interchange; Godot JSON parse may shift doubles by one last-place unit even with `JSON.stringify(snapshot, "", true, true)`, so JSON is not an exact replay encoding. The target data and nested arrays have no shared references to live state.

`restore(dictionary)` validates the entire candidate before any mutation and returns false transactionally on malformed state. It validates required/exact top-level keys, types, finite bounded numbers, enum values, elevation limits, zoom-level/boolean consistency, integral resource counts, positions, canonical target identities and positions, alive/HP consistency, selection eligibility, and terminal-state consistency. Unknown schema/range values are rejected. Snapshots assume unchanged checked-in rules and range, not cross-version migration. Untrusted external code must not mutate public state or configuration dictionaries.

## Cover presentation

The calibration menu uses `cover_scene.gd` and the authored `vehicle.gd` model to
recreate the restored cover's low, three-quarter composition. The hero model has
chamfered armour edges, a recessed gun bore, welds, fasteners, tow eyes and crew
equipment details. Practice targets retain the cheaper geometry path. The set
uses layered procedural smoke, earth, track dust and practical headlight spill;
it requires no additional downloaded textures or renderer change.

The crew refinement uses smooth torso meshes, continuous tapered sleeves with
compression folds, individually curled glove fingers and opposed thumbs,
folded collars, shaped faces and shallow contoured goggles. Fitted CVC helmet
shells replace the overlapping domes; the loader's cloth cover has modelled
panel seams. These remain original procedural geometry, batched by material.

The anatomy pass sculpts the nose, lips, cheekbones, sockets and jaw into one
continuous face mesh, with smooth normals and restrained skin-tone variation.
Both heads share that cached mesh. Necks flare into the shirt and tuck beneath
the jaw. Tapered glove fingers close around separate spade handles; the loader's
palms rest on the raised hatch. Detailed crews are built only for the menu hero,
so hidden practice-target crews do not pay for the additional geometry.
The loader's corrected pose hinges forward from the hips, with lowered shoulders,
bent elbows and a shorter reach from collar to head. His smaller collar, fitted
chin straps and recessed eyes complete the pose; the commander is unchanged.

The finish pass refines the crew's contour rings before smooth-normal generation,
rounding helmet crowns, sleeve bends, necks and glove tips while retaining the
joint positions and hard armour edges. Helmet rims and scrim seams use continuous
tubes fitted to the shell. Fabric and skin carry restrained procedural normal
relief, faded below pixel size; gloves have a separate, lower roughness finish.

The tailoring pass replaces swollen capsule cuffs with narrow folded bands and
fitted glove cuffs. Collar leaves have thin rounded edges and inset stitching;
elbow compression folds follow the bend. The loader's button placket samples the
shirt mesh's contour subdivisions. The commander has flat, stitched vest webbing;
both helmets have fitted chin webbing and slimmer curved microphone booms.
Rounded smoked goggle frames and temple straps retain the original two-lens shape.
Crew joint positions, faces and cover composition are unchanged by this pass.

The final craft pass shapes an open neck hem and opaque interior cloth lining,
then roots one continuous, thin folded collar around it. Separate collar-leaf
patches were removed. Slimmer sleeve caps roll into the upper arms; the neck base
is concealed inside the shirt. The shared face mesh has denser vertical sampling,
a broader lower jaw, curved lip contours, a philtrum and restrained nostril and
mouth-cavity colour. The exact crew joint dictionaries and gaze vectors remain
unchanged, as do the cover camera, lighting and armour geometry.

The existing Camera Motion setting also freezes the cover's particle systems,
sky clock and firelight variation. Entering the range hides the cover and stops
its particles; returning restores the atmosphere. These are presentation-only
changes. The title's particle budget is below 10,000.

Verified on 17 October 2026: 1,227 simulation/presentation checks passed; native
GPU captures at 1920×1080 and 1152×648 passed menu actions, range entry/return,
particle suspension and pixel-identical reduced-motion frames. The existing
runtime smoke test passed movement, all four stations, targeting, effects, save
and navigation. Captures and the native verification script are in
`artifacts/cover-polish-20261017/final/`. No release bundle was rebuilt or deployed.
The subsequent crew pass repeated the 1,227 checks and native verification;
its full scene, crew close-up, compact capture and logs are retained in
`artifacts/cover-crew-20261017/final/`.
The final anatomy pass also passed 1,227 checks and native lifecycle verification.
Face, neck, grip and hatch-contact close-ups were visually inspected under the
existing menu lighting. Those captures and verification logs are retained in
`artifacts/cover-anatomy-20261017/final/`. Delivery remains local only.
The loader-only correction passed the same 1,227 checks and final native lifecycle
verification; captures are in `artifacts/cover-loader-20261017/final/`. An earlier
candidate failed the frozen-frame pixel comparison once; its log is retained in
`artifacts/cover-loader-20261017/review/native.log`. The final candidate passed;
this pass does not establish the cause of the earlier mismatch.

The normals/material pass passed 1,227 focused checks and inspected every crew
mesh normal: 62,490 vertices, zero non-finite or non-unit normals. Final native
captures cover both menu sizes, faces, grips and hatch contact; menu actions and
range lifecycle passed. Captures and logs are in
`artifacts/cover-normals-20261017/final/`. The capture script now uses the existing
occlusion-safe SubViewport/explicit-draw pattern from the native instrument tests;
one earlier window-based run timed out awaiting `frame_post_draw`.

The strict frozen-frame check remains intermittent: the final run differed at
5 of 2,073,600 pixels, by one red-channel level. An earlier pair differed at 167
pixels, by at most two levels. A bounded probe found an initial mismatch followed
by identical frames, with the sampled scene state unchanged. Comparing automatic
and realtime sky modes did not reproduce it, so no speculative sky or particle
fix was applied. This residual check is not reported as passing. Its image pairs,
amplified differences and probe logs are retained. The visual finish is local
only; no release bundle was rebuilt.

The tailoring pass passed 1,227 focused checks and the mesh inspection found
zero invalid normals across 69,600 crew vertices (134,980 triangles in 40 batches).
Native wide/compact and detail captures were inspected; menu actions, range
entry/return and particle suspension passed. Final captures and logs are in
`artifacts/cover-tailoring-20261017/final/`. The strict frozen-frame check failed:
354 of 2,073,600 pixels differed by at most two colour-channel levels. The earlier
candidate passed it, which does not resolve its previously documented
intermittency. No freeze-related runtime code was changed. Delivery is local only.

Final craft verification passed all 1,227 focused checks and native menu/range
lifecycle checks. Inspection found zero invalid normals across 84,189 crew vertices
(164,012 triangles, 42 batches). Wide/compact, face, neckline, grip and hatch-contact
captures are retained in `artifacts/cover-final-craft-20261017/final/`.

The native harness now forces and synchronizes every requested settling draw,
rather than counting process ticks followed by a single forced draw. Both strict
frozen-frame intervals passed byte-for-byte in the review and final runs, with
no tolerance or image substitution. The earlier mismatch evidence is retained;
these results establish the corrected harness outcome without claiming an
engine-internal cause for the earlier transient differences. No freeze-related
runtime code was changed. Delivery remains local only, with no bundle rebuild.

Working if: the cover retains its composition, the range returns to daylight,
and reduced-motion menu frames remain pixel-identical on the native renderer.

## Verification

Run from the repository root:

```sh
./tools/godot.sh --headless --script res://tests/test_simulation.gd
```

Tests cover repeated-run deterministic state/events; independent main/MG loading; main gun and MG firing in the same tick; the `reload` event on reload completion; hull turning carrying an unlocked turret, lock holding the target bearing, and alignment releasing lock; `scan_bearing` having no simulation effect; radio and thermal at gunner and commander only; the vertical selection cone; ammunition/smoke conservation; station permissions and MG restrictions; invalid command axes; map boundary handling; target selection/lock invalidation; AX minimum range; exact and JSON-safe snapshot replay; deep-copy isolation; malformed and wrong-type transactional rejection; winning/losing transitions; terminal immutability; direct MG firing preserving selected main weapon; three-step gunner zoom; immediate stop; sight-axis station/mode permissions; elevation clamping, vertical misses and center-height hits; and the range presentation helpers (commander-only scan offset, map projection, reload-bar span, and capture output anchoring that refuses `godot/` and the original sources). These tests establish this authored simulation contract, with no original-game parity claim.
