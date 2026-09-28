# Source-selected systems lamps

The twelve systems now have scalable lamps in both the commander miniature and
STATUS page. Their positions, current colour and visibility come from the
completed PC image. The Genesis commander and CHECK DAMAGE captures supply the
flat rectangular illuminated-cell style. The existing restrained cockpit bevel
is used without glow, new symbols or inferred component values.

## Finite variant inventory

| Surface | Required variants | Implemented and checked | Remaining evidence |
|---|---:|---|---|
| Commander system lamps | 12 placements times 3 colours | All 36, source instructions and constructed native rendering | Live yellow/red occurrence, independent visual acceptance |
| STATUS system lamps | 12 placements times 3 colours | All 36, source instructions and constructed native rendering | Live yellow/red occurrence, independent visual acceptance |
| Existing temperature lamps | 2 placements times green/yellow/red/blink-off | Existing 8 retained; gauge regression passes | Broader live overheat/damage reachability |
| Existing speed/fuel strips | 40 gunner counts, 40 commander counts, 29 fuel counts | Existing 109 count states retained | Other palette modes remain original |
| STATUS damaged schematic | Four observed source overlay choices, 16 binary combinations | Original fallback retained; all five DAMAGE resources decoded and loaded pixels/masks verified | Genesis damaged donors, authored artwork, original draw/combination visibility and native binding |

The twelve systems are GPS, smoke dischargers, coax, main gun, ballistic computer,
thermal equipment, radio, Halon, turret motors, left tread, right tread and engine.
Black is not an accepted systems-lamp state. The temperature blink-off state is
separate. Unknown content stays original and does not count as completed art.

Working if: each accepted lamp matches its entire current dynamic rectangle and
surrounding original plate provenance; one changed pixel, missing ownership bit,
unknown colour or destroyed guard keeps that lamp original, and the next frame
cannot reuse the prior accepted state.

## Original authority

`GAME/SIM.EXE`, SHA256
`9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099`:

* `6cc6..6d16` maps system states 0/1/2 to palette indices 8/10/6 in mode 16,
  and 12/13/14 in the alternate mode. The live remaster remains mode-16 gated.
* `6d18..6d8b` draws twelve 3x1 commander rectangles: x208 and x284,
  y172 plus twice the row. The six rows in each column retain original order.
* STATUS fragment `6e01..6e2c` calls the same classifier and draws 10x6 cells:
  x11 and x301, y109 plus thirteen times the row.
* STATUS `6f49`, `6f7a`, `6faa`, `6fda` calls four DAMAGE.BMP overlays at
  (188,54), (206,38), (203,83), (251,50). Their resource dimensions are
  24x35, 64x12, 72x16, 56x34. A fifth 24x12 resource exists; its use is not
  established by these calls. No replacement diagram donor was selected.

The pristine Genesis source is
`local-art/genesis/source/systems-status-original.png`; its exact VDP receipt is
`local-art/genesis/source/systems-status-receipt.json`. The current capture does
not inventory Genesis damage states. A ROM descriptor search did not locate the
four matching PC-sized resources; that is not proof that counterparts are absent.
The PC damage extracts are verification oracles, not selected remaster donors.

## Proof and retained failures

All receipts below are under `artifacts/finish-20260928/`.

* `status-lamps-oracle.json`: 198 original-instruction cases, 227 checked
  instruction locations, 51,904,512 full VGA-plane bytes compared, including
  untouched pixels. Commander executes its whole routine; STATUS enters the
  bounded lamp fragment with isolated original stack locals. Both palette
  branches and both pages are covered. No live guest memory is written.
* `status-lamps-native-02/report.json`: 46,187 checks, zero errors, 69,888,000
  whole-frame comparisons. Recorded `pc-cockpit-trace-05` supplies actual visible
  green lamps in all 24 placements. Constructed original-instruction-backed
  fixtures cover green/yellow/red at 4x and 6x; changes stay in source cells.
* Headless systems tests pass 416 checks. `gauges-regression.log` passes 14,939
  checks, including the existing 1,332-case gauge oracle.
* `status-source/inventory.json`: all five PC resources match loaded original
  EGA pixels and transparency masks exactly. Original resources are untouched;
  extracted PNGs remain in the ignored artifacts directory.
* `status-lamps-native.log` is a retained failed run. The old trace-01 fixture
  had not actually entered STATUS when its stage label said damage-settled.
  Pixel/provenance checks correctly rejected it. The existing verified trace-05
  contains the actual modal, so no guard was relaxed to pass the test.

The author inspected the rendered lamps produced in this session. This is
self-review, not Nell's independent aesthetic acceptance. These checks do not
close the damaged-schematic family or claim all damage transitions occur live.

## Completed damage continuation (28 September)

The earlier four-overlay inventory above was incomplete. The final source call
at `6fff`, omitted by the first bounded excerpt, draws DAMAGE index4 (24x12) at
(146,65), when system3 (main gun) is state2. All five choices yield32 binary
combinations. The other four test source bytes cb6/cb8/cb7/cb9 against source red
index6 in mode16 (14 in the alternate palette).

All five Genesis counterparts are now recovered. Original routine `98ce..992a`
selects descriptors `9ad4,9ac4,9acc,9adc,9abc`, map chain indices49,50,52,51,48.
Original map renderer `5f10` and unchanged decompressor `9afe` establish tile
placements and resources. `tools/pc_instrument_genesis_damage.py` executes that
decoder on a read-only authenticated ROM and uses authenticated native VDP
palette/tile data from `reference/genesis/graphics-status-action-01/status`.
The exact extracts and receipts are in
`local-art/genesis/source/status-damage-v1/`.

Five built-in imagegen redraws, one per exact Genesis patch, are bound at those
original placements through the existing STATUS donor transform. The original
Genesis changed-pixel support mask restricts each authored patch to actual
damage, with linear boundary coverage; unrelated neighbouring contours remain
pristine. A first rectangular binding was rejected during self-review because
of seams. No original flat vehicle model or texture was edited.

`pc_instrument_damage_art.gd` authenticates its manifest, source files, all five
patch dimensions/hashes and five source-support masks. Every frame requires all
184x63 source pixels and provenance bytes to match one of32 original composites,
plus full UI ownership. Only the source-shaped M1A1 caption is refined for pristine state0. It draws nothing for unknown content,
missing ownership, changed palette, absent sources or stale/fallback frames.
Working if: each32-state source fixture selects only its matching state; any
source/tag/ownership corruption and the next fallback immediately clear it.

Proof: `status-damage-oracle-02/report.json` has64 unchanged original bitmap-driver
cases, all32 combinations on both pages,1,113 checked executed instruction
locations and16,777,216 complete plane bytes. These are isolated fixtures with
full-screen clip bounds, stopping before RETF. They do not prove full-modal
timing or naturally occurring live damage. The earlier full-function attempt
hit a Unicorn far-transfer failure; the failure remains recorded. The final
source fixture uses the original custom display palette, not standard EGA.

`status-damage-native-04/report.json`:96 native renders at1280x800,1728x1080 and
1920x1200;737 checks, zero errors,166,215,680 frame pixels compared, with exact
unchanged exterior regions and visible replacement for every damaged state.
Native-02 was an invalid-palette diagnostic and was normally quit via the
verified owned NSRunningApplication PID, not a passing receipt. Native-03
validated geometry but its rectangular seams were rejected. Native-04 is the
selected source-support binding. Rendered assets were evaluated by their author;
this is self-review, not independent aesthetic acceptance.

## Remaining warning/state-symbol inventory

Within the original cockpit/status instrument routines, finite families are:

| Family | Source authority | State support |
|---|---|---|
| Target-lock lamp | `59d7..5a0d`, source db0 | Red/off,13x11 at271,180; now scalable, both exact states only |
| Temperature warning | `5a14..5a70`, `684f..6892` | Two placements, green/yellow/red/blink-off,8 variants |
| System lamps | `6cc6..6e2c` |24 placements x3 colours,72 variants |
| Ammunition selection backing | `582a..590d` | Three selected colours and unselected black; source-filled rectangles and scalable text retain original selection |
| Ammunition/smoke counters, display identifier | `590e..59d6` | Source integer/text content via original font draw observer |
| READY/TRACK/LOAD and warning sentences | `54b6` and crew/radio string calls | Original string content/colour and visible glyph ownership; no additional invented icon |
| Static instrument symbols | GPS.BIN nine exact cells | Nine Genesis-derived illustrations; original plate ownership required |
| Orientation/damage edges | `600c..62a6` | Source-observed grid, hull/turret geometry and edge colours; see orientation proof |
| Sight/selection box | Original sight and `66a9..6760` | Two source colours, exact current source geometry, original clipping |
| STATUS schematic | `6f22..7006` | Five overlays,32 combinations, as above |

The new lock lamp reuses the established vector/code-native lamp renderer.
`target-lock-oracle.json` executes8 unchanged source-fragment fixtures covering
both pages/palette branches,145 instruction locations and2,097,152 whole-plane
bytes. `target-lock-headless.log` passes16 checks including rejection of invented
green/yellow/white states. Gauge regression `gauges-final-02.log` passes15,218
checks against the1,332-case existing oracle. Other display palettes intentionally
keep original graphics. These finite instrument families do not claim coverage
of every non-cockpit screen or naturally occurring gameplay transition.


### STATUS caption reuse

The STATUS Genesis label at(123,19,26,5) is pixel-mask identical to the
information-page overhead M1A1 caption. `status-caption-source.json` records all
130 source mask bits and the authenticated source image hash. The existing
`overhead-m1a1-caption-v1.ttf` (SHA256
`321aaa970f3255c1e232ba7c252aa1d0bcdd6dabf66ba07d4fd90cc47c2d1170`)
is reused without a new face. It is a single glyph mapped to A, containing the
whole source-shaped caption. Existing `pc_outline_fonts.draw_text` places it at
the exact transformed source rectangle. A clean donor-blue strip covers only the
old caption area. The same32-state exact RGB/provenance gate governs the caption,
including pristine state0; source-unrecognized diagrams still remain original.


Final combined caption/damage acceptance: `status-damage-native-06/report.json`
passes899 checks,96 renders,166,215,680 frame pixels at4x/5.4x/6x, with323
headless/integrated predicates included. All32 original source combinations bind
through the actual tandem child; wrong palette/fallback clear each. Partial UI
ownership also rejects. All actual changed PC damage pixels lie within the drawn
182x63 schematic; the184-wide validation box includes its untouched guard.
`status-damage-oracle-03` makes the fixture seed reproducible directly from
original STATUS.BIN; all64 state/tag outputs equal the accepted02 fixture set.

`target-lock-native/report.json` passes83 checks, covering all temperature and
lock/off fixtures at4x and6x through actual tandem composition. The new lock
source accepts red/off only; no green/yellow/white invented state is accepted.
The earlier native05 caption run stalled waiting for frame_post_draw on an
occluded macOS window and was normally quit via exact owned PID2206. The final
capture uses the established force_draw/force_sync pattern plus a120-second
normal-exit watchdog, so that display condition cannot leave an indefinite test.
All owned native processes completed or were normally closed before handoff.
