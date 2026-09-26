# Deterministic range simulation contract

`godot/scripts/simulation.gd` is an original-authored calibration exercise. It does not recreate any original mission, damage model, enemy behaviour, scoring formula, or campaign. All four targets are stationary practice targets. Their abstract hit points and equal shell damage are calibration assumptions. Smoke emits an event and consumes a charge; there are no incoming weapons or smoke protection to simulate here.

## API and ownership

The class extends `RefCounted`, with no scene tree, `Input`, wall clock, physics engine, audio, or random-number source. Construction reads the checked-in JSON configuration. `reset(seed = 1988)` resets all runtime state; seed is recorded for reproducibility and currently has no behavioural effect. `tick(commands)` advances exactly 1/60 second and returns a fresh array of event dictionaries. Once won/lost, ticks return no events and do not mutate state. The caller decides when to pause by withholding ticks.

Public state: `pos: Vector2` (world x,z), `heading`, absolute `turret`, `elevation`, `speed`, `station` (0 gunner, 1 commander, 2 cupola, 3 driver), `control_hull`, `thermal`, `zoom_level` (0/1/2 for 1x/3x/10x), derived read-only `zoom` (`zoom_level > 0`), `weapon` (0 HEAT, 1 SABOT, 2 AX, 3 COAX), `ammo`, `reload_ticks`, `mg_cooldown_ticks`, `fuel`, `hull`, `smoke_count`, `elapsed_ticks`, `status`, `targets`, `selected_target`, `locked`. The renderer treats these as read-only. Positions and speeds are metres and metres/second. Heading zero points world -Z. Positive heading rotates left: forward vector is `(-sin(heading), -cos(heading))`.

Commands are a per-tick dictionary. Missing axes equal zero; missing one-shot actions equal false. The input layer supplies edge-triggered actions once, never every render frame.

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
| `select_target`, `lock_target` | Gunner only. Cycle eligible targets then none. Eligibility uses a provisional horizontal sight cone and manual-grounded maximum range. Lock follows selected target bearing and center-height elevation; death/range loss invalidates it. |
| `scan_bearing` | View-only command, deliberately ignored by simulation. UI maintains commander view offset0/90/180/270 relative to turret. |

Motion decelerates when throttle is released. Hull turning carries an unlocked turret. A locked turret stays aimed at its target. These are explicit remaster input choices; the original's accelerating spin and continued-motion keyboard behaviour are not reproduced. Movement clamps to the authored range bounds and stops at the edge.

Events include `fire`, `impact`, `hit`, `reload`, `smoke`, `voice`, `won`, `lost`. `position` is a Vector2 where supplied, `text` a display message, `cue` an audio identifier. Fire adds `weapon`; impact adds `target` index or -1, and `weapon`; hit adds `target` and `destroyed`. The tick's array is the sole event output; presentation must consume it once. Hitscan chooses the nearest alive target intersecting the shot line within weapon minimum/maximum range. Flat authored range geometry places the sight at 2.65m and target centers at 1.8m. At each target's forward distance `d`, shot height is `2.65 + tan(elevation) * d`; a hit requires horizontal error at most5.5m and vertical error at most1.8m. These forgiving target extents and the elevation rate/clamps are provisional, with no original ballistic parity claim. Elevation is radians, positive up, provisionally clamped to [-0.15,0.35]. No gravity or ground collision is simulated; miss impact height reports the ray endpoint and may lie below ground. `impact` adds `height` for presentation. `elevation_to(point)` provides the clamped target-center pitch used by lock. Hit events describe abstract practice-target damage.

## Evidence and provisional rules

`godot/data/range.json` labels its map and targets as newly authored. `godot/data/provisional_rules.json` distinguishes known manual evidence from unknown original values. Manual evidence covers station/control permissions, weapon ranges, nominal4-second main reload, total40 main rounds and80 MG rounds. The main-ammunition split, AX5-second reload, MG cadence, handling/fuel constants, target size/HP/damage, smoke count and selection cone are provisional. Damage effectiveness against actual original enemy classes is intentionally absent. See `docs/original-mechanics.md` for the source extraction.

Win: all four targets destroyed. Loss: fuel or hull reaches zero. No range enemy causes hull damage; the hull field is reserved for future authored exercises. Fuel exhaustion is reachable. The final tick may emit the final hit and win together. Once complete, reset is required to restart.

## Snapshots

`snapshot()` returns a deep, JSON-safe dictionary, version2 and authored-range ID included. Vector2 positions become two-number arrays. For exact replay serialisation use `var_to_bytes(snapshot)` and `bytes_to_var(bytes)` without object decoding. JSON is suitable for inspection/interchange; Godot JSON parse may shift doubles by one last-place unit even with `JSON.stringify(snapshot, "", true, true)`, so JSON is not an exact replay encoding. The target data and nested arrays have no shared references to live state.

`restore(dictionary)` validates the entire candidate before any mutation and returns false transactionally on malformed state. It validates required/exact top-level keys, types, finite bounded numbers, enum values, elevation limits, zoom-level/boolean consistency, integral resource counts, positions, canonical target identities and positions, alive/HP consistency, selection eligibility, and terminal-state consistency. Unknown schema/range values are rejected. Snapshots assume unchanged checked-in rules and range, not cross-version migration. Untrusted external code must not mutate public state or configuration dictionaries.

## Verification

Run from the repository root:

```sh
./tools/godot.sh --headless --script res://tests/test_simulation.gd
```

Tests cover repeated-run deterministic state/events; independent main/MG loading; ammunition/smoke conservation; station permissions and MG restrictions; invalid command axes; map boundary handling; target selection/lock invalidation; AX minimum range; exact and JSON-safe snapshot replay; deep-copy isolation; malformed transactional rejection; winning/losing transitions; terminal immutability; direct MG firing preserving selected main weapon; three-step gunner zoom; immediate stop; sight-axis station/mode permissions; elevation clamping, vertical misses and center-height hits. These tests establish this authored simulation contract, with no original-game parity claim.
