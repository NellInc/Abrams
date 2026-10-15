# PC executable evidence

## Decode and independently compare

All four supplied MZ executables use a 16-byte EXEPACK header and the same
277-byte decompressor/error-string block. The header signature is `52 42`.
The block's SHA-256 is
`a146eddf8f6523a9b05e070f126a755e5b5c4444181258faa3939010fd2d61b3`.

`tools/unpack_pc_executables.py` accepts this observed variant only. It preserves
the originals and writes unrelocated load-image bytes plus address/relocation
metadata under `reference/pc-unpacked/decoded/`. Unknown stubs, truncated runs,
unread-input overwrites, inconsistent prefixes and invalid relocations fail.

| Program | Decoded bytes | Relocations | Original entry CS:IP |
|---|---:|---:|---|
| START | 115216 | 575 | `0000:47e2` |
| BRIEF | 62896 | 362 | `0000:0ffa` |
| SIM | 129712 | 671 | `0000:91f8` |
| END | 89008 | 386 | `0000:1b36` |

These load-image bytes, relocation targets, entry points and stack values were
compared with David Fifield's independent [exepack 1.4.0 implementation](https://www.bamsoftware.com/software/exepack/).
Its source is CC0 and remains a local research dependency. The downloaded source
tarball SHA-256 is
`212f3ec55822dc67763ab79534e5c9cd5fc2cf127a557a983a6b95ae4ad89ecf`.
All four comparisons are identical. This is storage evidence, not a complete
gameplay-equivalence claim.

```sh
python3 tools/unpack_pc_executables.py \
  --compare-dir reference/pc-unpacked/independent
```

Addresses below refer to the decoded load image, excluding the MZ header.
Near pointers use the named program's data segment. They must not be confused
with offsets in the packed source files.

## Execute original instructions

`tools/pc_bearing_oracle.py` uses [Unicorn's CPU emulation API](https://www.unicorn-engine.org/docs/tutorial.html),
pinned to version 2.1.4. It first executes each original decompression stub from
the packed EXE at load segment `1000`. Every resulting byte is compared with
the independent decode after applying the original relocation table. The
restored entry, stack and PSP segments are also checked. All four pass.

The oracle then executes two original SIM routines for every possible unsigned
byte input. It supplies RAM, registers, an isolated stack and the C runtime's
stack lower bound. The original stack-allocation helper and long-multiply helper
execute normally. No original instruction is patched, intercepted or replaced;
unexpected interrupts and failure to return within the limit fail the check.

```sh
python3 -m venv .runtime/pc-analysis-venv
.runtime/pc-analysis-venv/bin/python -m pip install 'unicorn==2.1.4'
.runtime/pc-analysis-venv/bin/python tools/pc_bearing_oracle.py \
  --check-fixture godot/tests/fixtures/pc_bearings.json
./tools/godot.sh --headless --script res://tests/test_pc_rules.gd
```

The committed fixture contains numerical outputs and provenance, no original
executable bytes. The normal validation gate compares the Godot port against
this fixture. The separate oracle command above re-executes the original code;
a fixture-only test must not be described as a fresh original execution.

This environment emulates isolated computation. DOS, graphics devices, elapsed
time, event cadence and whole missions remain outside its scope.

## Bearing conversion and hit-call formatting

SIM's data segment is load-relative `19e0`. The string at DS:`095d` reads
`We've been hit! Bearing `.

* Routine `0000:56ea` multiplies the unsigned input byte by 360, shifts the
  product right eight bits, subtracts the result from 360, and maps 360 to zero.
* Routine `0000:3d0e` uses that conversion, then calls `0000:527c` with width
  three and padding character `30` (ASCII zero). It copies the resulting
  NUL-terminated string to DS:`6472` for the hit-call.
* The formatter and conversion were both executed for all 256 inputs. The
  resulting three digits always agree with the numerical routine.

Examples: internal 0 gives `000`, 1 gives `359`, 57 gives `280`, 64 gives `270`,
192 gives `090`, 224 gives `045`, and 255 gives `002`.

`godot/scripts/pc_rules.gd` matches every result. It is deliberately separate
from the provisional range's floating-point angle convention. The full PC
movement/orientation pipeline must be recovered before connecting them.

The TTS normalizer is checked against all 256 original strings. It preserves
the caption and performs each digit separately, including the leading zeroes.
For example, `Bearing 045` becomes `Bearing zero four five`. This pass does not
invent an incoming-hit event in the authored range or generate 256 new samples.

## Further static leads, with limits

Both START and BRIEF contain an eight-entry near-pointer title table. The
decoded tables are START DS:`24da` (DS=`1505`) and BRIEF DS:`080a` (DS=`0c71`).
Their indexed order is Nuremburg Highway, Mass Destruction, The Road to Bonn,
Hannover Push, Convoy, The Mossel Intercept, The Mossel Defense, Siegen
Infiltration. BRIEF `0000:0230` indexes the table using the first byte read
from `shell`. This establishes the title lookup, not campaign order.

SIM `0000:7d52` transfers the fourth handoff byte to DS:`8d74`; `0000:7de6`
adds ASCII zero and writes it into `snario ` before the resource-loader call.
The handoff begins at physical `0000:0510`. The relationship between a campaign
slot, the shell first byte and the resource index still needs tracing. Do not
mark scenario/title correspondence or objective execution proven from this lead.

SIM `0000:7fb0` opens `sim.arm` and reads four 16-bit fields. It checks the sum
of the first three against 40. Its fallback at `0000:8005` writes values
`[20, 10, 10, 1]`. Field names, malformed-file handling and subsequent selection
behaviour remain to be traced before changing the range's loadout.

## Original display correction

The original was launched with `ABRAMS.COM EGA` and DOSBox-X 2024.07.01 configured
as `machine=ega`. Its OpenGL window showed an incorrect blue cast. A raw
320x200 framebuffer capture retained normal grayscale, red, yellow and blue
colors: `artifacts/pc-ega/title-raw.png`.

Switching Video > Output > Surface in the running emulator removed the cast.
The displayed menu then showed green terrain, gray road/frame, brown hills and
cyan sky. Nell confirmed the correction. The launch configuration now saves
`output=surface` in `.runtime/dosbox-x.conf`. The original files were unchanged.
This local remedy is verified; the underlying OpenGL implementation defect has
not been diagnosed. The misleading colors must not guide remastered artwork.

Working if: subsequent launches retain Surface output, the raw and displayed
palette agree, and the source fingerprint verification remains unchanged.

## REA SIM pilot, 12 October 2026

Nell authorized REA setup and a bounded SIM pilot, retaining unchanged original
game files. REA 6.4.0 is installed under `.runtime/rea`; only its Codex MCP
registration was added. Existing Ghidra 12.1.4 and the full Homebrew JDK
21.0.12.1 are reused. Other client settings, Hopper and optional global workflow
instructions were left alone. The unrelated Codex configuration's parsed-content
digest is unchanged. These are local research dependencies, outside packaging.

The target is the read-only `.runtime/rea-pilot/SIM.EXE` copy of the independently
unpacked MZ, SHA-256
`ea79caf48cc5740b8a18d3733f845167aefbc924a8fb61ecb5fe6b0b9434a988`.
All four independently unpacked programs were freshly compared with the packed
sources. REA independently verifies the SIM loaded image at segment `1000`,
including its 3,072-byte header, 129,712-byte module and 671 relocations.
Its addresses are linear loaded-image coordinates: `0x156ea` is load-relative
`0000:56ea`, and its corresponding unpacked MZ file offset is 25,322.

**Known-routine check:** all 62 bearing-routine bytes returned by REA agree with
the unpacked MZ. A fresh execution of the existing original-CPU bearing oracle
matches the committed fixture for all 256 numeric and zero-padded bark inputs.
The recovered expression is `(360 - ((input_byte * 360) >> 8)) % 360`.
The sandboxed oracle attempt returned without a receipt or output file; only
the successful native-permission run is counted as execution evidence.

**New boundary candidate:** original startup reaches `0000:7d22`, which calls
the main loop at `0000:0e54`. Its repeating sequence starts at `0000:0e5c`:

1. Call `0000:0bd4`, whose dispatch sequence is `2026`, `2d2e`, `7228`, `24ee`.
2. At `0000:0e5f`, call the station-specific world/UI renderer `0000:0be6`.
3. Call `0000:3c02`, followed by the graphics-wrapper calls, then return to
   `0000:0e5c`.

Four isolated original-instruction witnesses use unchanged historical driver,
gunner, commander and cupola RAM captures. Each executes the entire dispatcher
in the observed order and reaches `0000:0e5f` with balanced stack and no
unsupported interrupt or device access. The captures are stationary; these
witnesses use synthetic register/stack context and do not model asynchronous
interrupts, DOS services or elapsed time. They establish an update-dispatcher
completion point before station rendering, **not global tick atomicity or a
live sampling-hook contract**. Camera and scanout pairing remain separate;
the current runtime hooks and bridge are unchanged.

Ghidra's C output is navigational evidence. Some functions contain implausible
inferred locals, including return addresses appearing as local-variable
assignments in `2026`. [Inference] The original custom stack helper `9440` is
a likely contributor; its precise effect on the decompiler was not isolated.
Use instructions and original execution to resolve those cases; do not port
its C verbatim.

Complete local responses, Evidence IDs, original-file fingerprints, setup and
CPU witnesses are retained in `artifacts/rea-pilot-20261012/`. Reproduction uses
`.runtime/rea/node_modules/.bin/rea`, with `GHIDRA_INSTALL_DIR` pointing to the
existing installation and `JAVA_HOME` to the admitted full JDK. Both live MCP
tool discovery (170 advertised tools) and actual native analysis succeeded.
The analysis target was closed and the owned MCP process exited normally.

Working if: all 68 supplied game files retain their before/after fingerprints,
the known bearing bytes and fresh oracle agree, and any future hook proposal
retains the boundary's isolated-execution limitations until live trace evidence
establishes its actual sampling contract.

## Live boundary traces, 12 October 2026

Nell authorized read-only live traces during movement and station changes.
**Verdict: reject load-relative `0000:0e5f` as an atomic whole-scene sampling
boundary.** It is a post-dispatch/pre-render observation point, with current
player/control fields mixed with older renderer state. The live evidence now
supersedes the stationary pilot's unverified whole-scene sampling question.

The task-local probe and analysis were authored in this session. A private
APFS-cloned copy of the pinned, already-patched DOSBox Pure source adds a
separate, disabled-by-default callback before `0e5c`, `0e5f`, `0e62` and `0e65`.
It copies conventional RAM and registers, without writing guest memory,
altering registers, consuming guest cycles or reading VGA latches. Host checks
validate the active SIM PSP/MCB, CS/DS, original main-loop bytes and existing
SIM fingerprints. This task does not modify the shared source, core pins,
production headers or bridge. Private build and harness:
`.runtime/rea-live-boundary-20261012/`; evidence:
`artifacts/rea-live-boundary-20261012/`.

Three fresh native processes replay the same 1,737 frames from the pinned
source-baseline mission-entry state: probe enabled, probe disabled, and the
unchanged shipping trace core. Every frame agrees exactly in conventional
RAM, video-boundary RAM, software framebuffer bytes and decoded diagnostic
fields. Original input remains in the read-only game ZIP, with separate new
save directories. All 68 original files and all 374 inventoried protected
game/core/source/header files retain their fingerprints.

The enabled run records 1,878 live instruction samples: 470 before update,
470 at the candidate, 469 after rendering and 469 after sound. All observed
phase transitions follow the main-loop sequence with balanced stack. The
candidate includes 243 moving samples, all four stations, three northward
world-window rebases, braking and turret rotation. Player world coordinates
remain continuous; allocated static-object positions match the source WLD at
every observed phase. Forty-four saved full-RAM witnesses were independently
re-read and agree with their recorded hashes and decoding.

Two concrete failures of whole-scene atomicity:

* **Movement:** at candidate sample 301 (frame 335, driver), the player is at
  local `[2048,2592,40]`, speed 64, while the cached camera is still at
  `[2048,2528,40]`. Sample 302, after rendering, refreshes the camera to the
  player's position. Player fields remain unchanged across that render call.
* **Station change plus rebase:** sample 389 (frame 461) has entered commander
  station and rebased the window from `[15,31]` to `[15,30]`. The player is at
  local `[2048,55,50]`, world `[79872,139209,50]`. The cached camera still holds
  `[2048,4080,40]`; interpreting it with the new origin yields
  `[79872,135184,40]`. After-render sample 390 refreshes it correctly. Dynamic
  pool slot 1, pointer `70d8`, also changes world Y from 139280 to 139209 during
  this render call. Its identity as a turret is **unverified**; the observed
  position change alone establishes that dispatcher completion does not
  finish every scene-object update. Both samples retain full-RAM witnesses.

Across the 469 complete candidate/render pairs, cached camera fields change
319 times and the decoded dynamic pool changes 41 times. The sampled
player/station/control scalars remain unchanged across rendering. This supports
tick-marked logic diagnostics in this bounded route; it does not establish a
universal atomic logic-state contract. Keep existing geometry-pass and
buffer/scanout attribution for presentation. Do not construct a current whole
scene from the candidate snapshot, or infer that `0e62` is a safe replacement.

The receipt is `artifacts/rea-live-boundary-20261012/report.json`. Coverage is
one live mission, EGA, normal CPU and fixed 3,000-cycle configuration. It does
not prove all missions, campaign completion, other backends, wall-clock timing,
complete serialized-state equality or audible-output parity. No sampling hook
was integrated into the remaster. Local only.

Working if: enabled/disabled/shipping RAM and framebuffer traces agree,
original and shared-core fingerprints remain unchanged, and the captured
mixed-age camera/object counterexamples prevent whole-scene use of `0e5f`.

## Later loop boundaries, 12 October 2026

Nell authorized further read-only live tracing at `0000:0e62` and later loop
boundaries. **`0e62` is the earliest tested post-render point for the current
iteration where the last completed world draw's camera, origin and participating
object poses agree with the RAM sample. `0e85` is the recommended post-iteration diagnostic
marker**, after both graphics wrappers return and their arguments are removed.
These are bounded findings, with separate original draw-pass and scanout
attribution still required. No runtime sampling contract was integrated.

The temporary probe and reduction are authored in this session. They reuse the
existing `Collector` to compare actual original world-draw entry snapshots and
completed passes, rather than infer a camera from hull or turret angles. The
private build and harness are in `.runtime/rea-later-boundary-20261012/`; the
native source only gains the task-local conventional-RAM/register copy hook.
Original main-loop instruction bytes, including both relocated far calls,
active SIM PSP/MCB, CS/DS and executable fingerprints are checked throughout.

The finite route has 1,920 frames: movement, all four stations while moving,
three world-window rebases, braking, turret rotation and one ordinary original
HEAT firing input to exercise object/effect lifecycle changes. Three fresh
processes, observers enabled, observers disabled and unchanged shipping core,
agree exactly at every frame in conventional RAM, video-boundary RAM,
framebuffer bytes and decoded diagnostics. All 68 originals and all 374
protected game/core/source/header files remain byte-identical.

There are 4,254 instruction samples and 531 complete observed loop iterations.
The order and stack balance agree with the original main-loop instructions;
the two call-return markers account for still-pushed arguments:

| Load-relative boundary | Observed position in loop | Attributed samples |
| --- | --- | ---: |
| `0000:0e62` | After station/world/UI rendering, before `3c02` | 531 |
| `0000:0e65` | After `3c02`, before graphics-wrapper arguments | 531 |
| `0000:0e6e` | Wrapper `0f8d:034f` returned, 2 argument bytes remain | 531 |
| `0000:0e71` | First wrapper's arguments removed | 531 |
| `0000:0e82` | Wrapper `0f8d:0353` returned, 8 argument bytes remain | 531 |
| `0000:0e85` | Second wrapper's arguments removed, before loop jump | 531 |
| `0000:0e5c` | Next iteration, before the update dispatcher | 531 |

Every attributed sample in this table has a supported camera, no active world
draw, and zero differences from the latest completed pass's camera, origin or
queued/drawn object positions and orientations. Camera position also agrees
with the sampled player position. The decoded player/control fields, camera
and allocated-pool poses stay unchanged from `0e62` through `0e85` in all 531
complete iterations. Later boundaries offer a cleaner iteration-end marker,
without improving these measured scene fields. Full data-segment bytes still
change across calls, including stack/scratch state; this is no claim that every
gameplay variable is frozen. Entry into the observation interval leaves one
unattributed startup sample at several boundaries, which is excluded from
pass-coherence claims.

`0e5c` also agrees with the previous iteration's last completed pass, before
the new update dispatcher runs. Thus "earliest" above is scoped to the current
iteration's post-render state. Between `0e5f` and `0e62`, 490 iterations complete
one world pass and 41 complete two. Five additional passes complete within the
update dispatcher. There is no one-pass-per-iteration assumption, and the
original last-pass identity stays unchanged from `0e62` through `0e85` in all
531 complete observed iterations.

Two limits prevent promoting this into a single universal scene snapshot:

* The **entire allocated pool** differs from draw-entry state in 49 post-render
  samples: 48 orientation-only differences and one membership change. Every
  differing record is absent from both the original draw queue and observed
  object-root participation. Allocation establishes no visibility. Preserve
  the original participation set and frozen pass data when rendering.
* The **displayed framebuffer** belongs to an older pass than the latest
  completed pass in 1,643 of 1,915 attributed presentations. Five startup
  presentations lack an observed pass. A coherent latest-pass sample therefore
  cannot replace the existing framebuffer-slot/scanout pairing.

The observer validates 43,592 original vertex-cache comparisons over 577
completed world passes. All 178 saved full-RAM witnesses match their recorded
hashes and decoding; source-WLD static placement agrees at all 4,254 boundaries.
The receipt, per-boundary metrics, field-stability comparisons, full-pool
counterexamples and presentation-lag witness are in
`artifacts/rea-later-boundary-20261012/report.json`.

Recommendation for a future diagnostic hook: use `0e85` as the iteration-end
marker, guarded by active fingerprinted SIM and an observed completed pass in
the current observer epoch. Keep camera/world geometry attached to its original
pass and presented buffer. This pass makes no production hook, bridge, gameplay
or packaging change. Coverage remains one mission, EGA, normal CPU and the
3,000-cycle setting; campaign endings, other backends/modes, full serialized
state, audible output and wall-clock timing equivalence remain unproven.
Local only.

Working if: exact observer-on/off/shipping parity and protected fingerprints
hold, the scoped `0e62`/`0e85` field comparisons remain explicit, and neither
allocated-pool contents nor the newest pass replace original display attribution.

## Loop-end diagnostic integration, 12 October 2026

The approved `0000:0e85` candidate is now an opt-in diagnostic in the local trace
core and bridge host (`--loop-diagnostics`). It uses existing native callback
event 56 and a fenced host-only enable flag. The original instructions still
execute normally, with no guest RAM, registers, VGA latches or cycle changes.
The separately decoded latest loop sample never feeds Godot rendering or replaces
VGA-paired state. Original draw-pass/page/scanout/framebuffer-slot custody remains
unchanged. See `pc-live-bridge.md` for the payload and lifecycle contract.

Built from an isolated copy of the pinned DOSBox Pure source, then activated
locally after exact three-way 1920-frame parity: new core enabled, new core
disabled, and previous trace core. Conventional RAM, video-boundary RAM,
framebuffer, existing session packets and audio-event packets all agree. Each
run retains 577 completed original passes and 43,592 original vertex checks;
1643 presented frames correctly retain an older pass. The hook observes 532
loop ends, including one startup observation with null completed-pass identity.
The other 531 have matching original draw camera and world origin at observation.
The camera diagnostic's metadata explicitly names the loop boundary.

Native core SHA-256 for that pass (since superseded; the active pin is in
`.runtime/pc-core/abrams-trace.json`):
`ef889734270d4106aa13ef28a8234a20dd1381c15067521f5776a53413761d88`.
The original 68 game inputs and shared dependency source stay unchanged;
only the local trace library/manifest and the approved observer source change.
No upload, deployment or publication is part of this integration. The earlier
whole-pool, multi-pass, video-timing and coverage limits continue to apply.
Detailed local receipts: `artifacts/rea-loop-diagnostic-20261012/`.

Working if: the opt-in host exposes guarded `0e85` observations separately,
enabled/disabled/previous-core records agree, and every presented world still
comes from its original draw-pass and buffer/scanout attribution.

## Mission and campaign outcome pilot, 12 October 2026

Nell authorized ordinary-control mission-victory and campaign-progression tests,
with read-only `0000:0e85` diagnostics and unchanged original game inputs.
Task-local REA SIM/END responses and native receipts are retained in
`artifacts/rea-victory-pilot-20261012/`. No guest memory, objective flags, campaign
records or enemy positions are authored by the pilot. Neutral START initialization
is separate from original disk-save/cold-Continue evidence.

### Original outcome contract

REA traces SIM `1b5c`/`1bc4`, quit menu `169c`, handoff `1956`, and END
`04ec`/`06aa`/`0c08`. DS:`7782` points to a twelve-byte objective: type at +0,
reference at +1, required at +3, progress at +5, completion flag at +7, and
completion/incomplete message indexes at +8/+10. Destroy-objective progress
counts qualifying destroyed records. Escort progress counts losses; its completion
requires the original destination test, so a rising escort count proves no victory.

The quit menu checks nearby hostiles before checking objective completion.
SIM `1454` examines active original records, the original affiliation/path fields
and original distance below `12000` raw units. This is a hostile-proximity gate,
not a friendly-base destination requirement. A completed objective can therefore
still offer only “Continue the Battle” or “Abandon the M1”. The completed branch
offers “Return To Base” once the earlier hostile/mobility gates permit it. The mobility test at
`7182` requires nonzero fuel and every CC4/CC6/CC8 condition at least ten.
Choosing abandonment or merely advancing the campaign never proves victory.

SIM writes original `SIM.OUT`: three outcome bytes followed by 31 kill counters.
END updates the original campaign record to fifty bytes: score, mission count,
career status, eight mission markers, fourteen category totals and the original
name/tail. Its save path increments the mission count even for some incomplete
exits. Genuine campaign acceptance therefore requires the actual objective flag,
surviving completed-mission exit, original debrief/save, and a fresh-process
Continue from those disk bytes, each verified separately.

### Damaged-panel observer repair

A real smoke/combat route exposed an observer defect at frame 10331. A destroyed
GPS black-panel call shared original rectangle routine `0b4d:33fb`; the old
event-13 world-phase classifier trusted a stale DS:`358c` callback marker and
misclassified the subsequent driver plate as world drawing. The unchanged
ownership guard correctly rejected 18,860 plate-4 pixels. The host classifier now
also checks the original SS:BP return CS/IP: only world-background callers
`0b4d:040e`/`04ce` can begin world phase. Damaged-panel caller `0000:0c75` remains
UI work. No original instructions, rendering calls or validation guards change.

The exact neutral-START input replay through the formerly failing frame has
identical full conventional RAM and framebuffer bytes across the old/new observer,
with the corrected guard passing. Existing render/session/UI/plate tests: 43 pass.
`panel-fix-parity.json` records the comparison. The trace core pin at the time of this pass was
`bd3877f73c1505bc9d6883fbcbd9d860f71f7d56ee51d50a21887da3b5723191`;
the previous core/header/manifest are retained task-locally.

### Victory-route diagnostic parity

A recorded ordinary-control Road to Bonn scenario destroys three BRDM-2s, two
T-64s and the primary bridge. At original frame 26423, the guarded `0e85`
objective is `1/1`, completed, with destroyed-exit zero. This proves a surviving
objective victory at that point. Its later withdrawal loses the tank, so this
scenario does not prove a completed exit or campaign save.

The exact 646 input steps were replayed enabled and disabled from the same
neutral START state: 26,183 frames each. Full conventional RAM, video-boundary
RAM, framebuffer, existing session/presentation packets and audio-event packets
are identical on every frame. Both retain 5,133 original passes, 583,388 checked
vertices and 17,245 presentations of a legitimately older pass. The enabled run
observes 5,114 original loop ends; disabled observes none. Original frame/goal
bytes and final RAM agree. `victory-parity.json` retains the terminal comparison.

The earlier camera-match finding was bounded to its original short route. On this
combat route two loop observations have a null decoded camera while the previous
completed draw still has its camera; all world origins agree. The first replay's
overstrong camera-equality research assertion failed and is retained separately.
The corrected comparison measures those nullable cases without weakening any
production guard. They reinforce the existing contract: latest diagnostic state
never replaces the original displayed pass or its camera.

The original can retain a TADS name/range after its target box disappears or a
target becomes unavailable. The campaign pilot checks the original
box, visible contrast and actual LOCKED state before treating that caption as
an actionable target. A color-zero box over the destroyed black gunner sight
is a real drawing primitive but supplies no player-visible aim coordinates.
A stale caption, allocated actor or unsuccessful lock never supplies hidden aim.
Where original equipment damage prevents locking, manual aim uses only the
original on-screen box/reticle and ordinary hull/turret controls.

### Original campaign persistence, independently of victory

The damaged Road to Bonn campaign run uses the original “Abandon the M1” choice.
Original END explicitly reports that the primary goal was not achieved, with
four BRDM-2 kills, one HIND kill and score 55. The observed 34-byte SIM.OUT
begins `01 01 00`: abandonment, required one, progress zero. No victory is
claimed for this run. END nevertheless writes the original fifty-byte PLAYQA.TC:
score 55, mission count one, career status zero and scenario-two played marker one.
The original R&R choice returns to START. After normal core closure the same
disk overlay retains that campaign record, SHELL and SIM.ARM; END has consumed
SIM.OUT. No record bytes are edited, and no midmission or winning state is restored.

Cold Continue is independently verified in a fresh native process, with no RAM
restore, using that same original disk overlay. Original START loads the unchanged
PLAYQA.TC and enters mission two, **Siegen Infiltration**, scenario seven, with
required two, progress zero, completion zero and a healthy tank. The campaign
record still has score 55, count one, status zero and the scenario-two played
marker. Its exact SHA-256 remains
`8887f448fe314b30b67ec6c1e250b8b6f26c8c0298bf66c9d65959ceee3e7a0e`.
`campaign-cold-continue-proof.json` binds those observations to the disk receipt.

The resumed Siegen attempt engages an originally visible, locked T-64 and BRDM-2
using SABOT and HEAT, with original destruction messages and matching counters.
Further attacks reduce overall integrity to ten and destroy the ballistic computer
and turret motors; the objective remains `0/2`. The original hostile quit branch
offers abandonment, and END explicitly reports that none of the mission goals
were met. Its observed SIM.OUT begins `01 02 00`, with one T-64 and one BRDM-2
kill. Original END awards eighteen points and saves total score 73, count two,
status zero and played markers for scenarios two and seven. Original R&R returns
to START and the core closes normally. The second mission therefore supplies
another original failure/save witness, not a victorious campaign handoff.

This demonstrates why the played marker and campaign advancement must remain
separate from mission-victory classification. A victorious campaign return-to-base
handoff has not been demonstrated by these runs. The independently proven
scenario objective victory and failed-campaign persistence are distinct receipts.

### Phases 1 to 5 continuation, bounded campaign attempts

The continuation retains its baseline and complete ordinary-input records under
`artifacts/rea-victory-pilot-20261012/phases-1-to-5/`. The original 68 GAME files,
reference ZIP, native core and protected observer headers match all 81 baseline
hashes. Saves are isolated overlays; earlier pilot saves remain intact. No enemy
poses, guest edits or midmission restores are used for tactical decisions.

The task-local contact controller cancels remaining batches on a newly presented
hit warning or a condition decrease. Actual movement and turn contacts demonstrate
ordinary keypad-5 settling and cancelled queued inputs. A scan exposed a real mode
dependency: keypad 5 in turret-control mode does not stop hull steering. The helper
now selects hull-control mode through ordinary C before settling. A later destroyed
tank retains frozen nonzero velocity, so the final helper also distinguishes original
terminal destruction from a failed movement stop. Three actual-RAM predicate checks
pass; that final terminal branch has not been freshly native-replayed. Controller
implementation and these checks were performed in this chat.

The two initially bounded combat attempts end with objective progress zero: the
first uses original abandonment and saves score 60 with career status zero; the
second loses its tank and saves score 55 with status two. Nell then explicitly
authorizes one further revised attempt. Its recorded opening reproduces the second
run's complete 640 KiB RAM exactly at frame 20459, using ordinary controls from
neutral START rather than restoring a combat state.

The revised attempt preloads AX and engages the originally selected, visible Bridge
at 3547 metres. Original static tables separate a 50-percent range-hit gate from
the Bridge's 25-percent AX destruction gate. These are separate random tests,
not a 50-percent chance of destruction. The seventh bridge shot completes the
objective while integrity is three and the destroyed-exit flag is zero. Withdrawal
then loses the tank. The original 34-byte SIM.OUT begins `02 01 01`: destroyed exit,
required one, achieved one. END explicitly reports "Primary goal achieved" and
awards 360 points, but saves a fifty-byte PLAYQA.TC with mission count one and
career status two. Its SHA-256 is
`fbf93181947f9993b9ff2ae59f3b70b42aab80e55cdc681e702148e1f19006db`.
This is an achieved objective with a destroyed career, not a surviving victorious
return-to-base save.

After normal closure, a separate fresh native process uses a byte-identical copy
of that original disk overlay, with no RAM restore. Ordinary START Continue reports
"NO ACTIVE PLAYERS TO CHOOSE FROM". The campaign record remains byte-identical.
`third-original-outcome-witness.json` and `cold-destroyed-career-proof.json` bind
the live objective, original handoff, durable record and cold rejection separately.

The third run checks 5604 loop diagnostics, 5650 original draw passes and 626595
vertices with no collector error. Diagnostics remain separate from the submitted
draw/page/slot/scanout pairing. The prepared full-frame enabled/off replay retains
its surviving-victory requirements and has not been run as a substitute on a
failed career. Phases 4 and 5 therefore remain incomplete. All three authorized
combat attempts are exhausted; another requires fresh authorization and revised
escape tactics, rather than repeating the same stationary combat approach.

A fresh REA analysis refresh opens the unchanged SIM artifact but both requested
function dossiers fail during Ghidra headless startup. Those failures are retained
under `rea-contract-review/`; the earlier REA evidence and unchanged disassembly
remain the source references. This analysis refresh failure is separate from the
observed gameplay losses.

Working if: actual objective completion, original mission exit and durable campaign
progression are distinguished; the diagnostic remains separate from original
draw/page/scanout pairing; and all original input hashes remain unchanged.

### Escape-controller revision and fourth campaign attempt

The fourth combat attempt is separately authorized and isolated under
`artifacts/rea-victory-pilot-20261012/escape-revision-attempt-04/`. The task-local
controller replaces automatic contact braking with a host execution freeze:
remaining input batches are cancelled immediately, latched controls are preserved,
and an explicit resume is required. Ordinary keypad 5 remains available for
intentional stops. Native evidence covers ten contacts with exact freeze frames,
no automatically injected keys, and explicit forward and reverse escape resumes.
This implementation and these checks were performed in this chat.

The covered approach retains an operational engine but loses the main gun.
Original own-system descriptor `DS:0c92 + 3*3` reports condition two for Main Gun;
the original damage screen and gunner MALFUNCTION accompany that observation.
No winning objective is produced. Original abandonment saves SIM.OUT `01 01 00`,
then a fifty-byte PLAYQA.TC with score zero, count one, status zero and scenario
two marked played. Its SHA-256 is
`fc8105d9a7d05d7b81c91c0a5f69315abf316d1a19e95f811026fee4ed6a63ae`.
Fresh-process original Continue, with no RAM restore, accepts the unchanged file
and opens "NUREMBURG HIGHWAY", "MISSION #2". The cold process closes in BRIEF;
this is progression after failure, not victorious campaign acceptance.

The actual observer completes 2148 diagnostics, 2214 original draw passes and
146119 checked vertices without error. Loop diagnostics remain separate from
original draw/page/slot/scanout attribution. One unfiltered state print exposes
allocated actor records accidentally; `observation-boundary-note.json` records
the incident. Subsequent movement retains the already chosen static-map corridor,
and the sight scan follows the original visible hit bearing. Those actor records
are not used for tactical routing, target selection or aiming.

A concrete replay portability defect is discovered: the then-pinned native (save format 8)
`DBPSerialize_DOS` omits `dos.date` (`.runtime/dosbox-pure-source/src/dos/dos.cpp`,
1379 to 1421), while BIOS initializes it from host local date (`src/ints/bios.cpp`,
520 to 549). Original START calls date/time, seeds its PRNG, then selects modulo
eight at `0000:2fd1` to `2fe7`. Matching restored RAM does not cover this host-owned
DOS date. Live initialization precedes local midnight; two later on/off pairs
match each other through all 16217 frames but select scenario seven instead of
the live scenario two and fail the actual-outcome gate.

The recorder is corrected to await a complete 34-byte SIM.OUT rather than retain
an early empty record. Initialization then uses the exact original checkpoint,
mirrors the live pre-route serialization call, and guards process-local UTC to
the original October 12 date. The machine clock and guest memory are unchanged.
A menu-only discriminator matches all 31 actual RAM, video-RAM and framebuffer
milestones through BRIEF at frame 3274. Corrected full on/off replay then matches
all 16217 frames in RAM, video RAM, framebuffer, existing presentation and audio,
including exact original draw/slot/scanout pairing. The enabled run contains
2148 attributed diagnostics, the disabled run zero; both check 2214 passes and
146119 vertices. Their 7967 older presented draws retain original attribution.
All 244 actual live milestones and sealed saved-file contents match. The 81
protected hashes, including 68 original GAME files, remain unchanged. Complete
native runs and the comparison exit zero. Failed-recorder logs remain retained.
Successful-campaign parity remains unavailable because no accepted winning route
exists. Cross-day checkpoint fidelity was then a separate limit. The 13 October 2026
calendar repair (save format 9, core `b859afb1…`; see WORK_LEDGER) stores the DOS
date in new checkpoints. Legacy format-8 states still restore with the boot date.

Working if: execution freezes preserve chosen escape controls, actual initialization
is reproduced before replay claims, original draw/scanout pairing remains intact,
and a continued failed career never closes the victorious-save gate.

### Bounded rehearsal and withheld campaign combat

The subsequent authorization allows one rehearsal and a campaign combat attempt
only after a passing rehearsal. Evidence is isolated under
`artifacts/rea-victory-pilot-20261012/rehearsal-conditional-20261013/`. The revised
opening avoids the previous hill overshoot and reaches the northbound corridor
at full condition. It subsequently suffers incoming damage: integrity 100 to
88 at frame 10653, then 63 at frame 10933. Own-system descriptors show Main Gun
condition one and Thermal Equipment condition one; mobility remains 100/100/100.
The second hit freezes execution and cancels a twelve-frame camera command after
four frames. This fails the required integrity threshold of 80 before the
pre-bridge staging point. No second combat SIM is launched.

Original abandonment produces thirty-four-byte SIM.OUT beginning `01 01 00`,
with zero kill counters. END saves an active fifty-byte PLAYQA.TC, score zero,
count one and status zero. Its SHA-256 remains
`fc8105d9a7d05d7b81c91c0a5f69315abf316d1a19e95f811026fee4ed6a63ae`.
Cleanup accidentally selects Continue rather than R&R, loading original BRIEF
for "THE MOSSEL INTERCEPT", "MISSION #2". The host closes normally there without
starting that battle. The artifact label `rehearsal-final-start` records BRIEF;
`status.json` explicitly retains and explains the mismatch. A fresh victorious
cold Continue and successful-route parity are not performed because the campaign
combat authorization gate never passes.

The task-local helper adds only own-system condition reporting, implemented and
checked in this chat. Native checks cover 1609 loop diagnostics, 1679 original
draw passes and 101674 vertices without collector error. Diagnostic state does
not replace original draw/page/slot/scanout attribution. All 81 protected hashes,
including the 68 original game inputs, remain unchanged. Earlier save seals are
also checked. Process-local `Etc/GMT+12` reproduces the October 12 initialization
date with the exact original pre-career checkpoint; machine clock, guest date
and game inputs remain untouched.

The manual's Enter target command is verified against `0000:1edf` to `1f30`,
which calls `35f4` to cycle eligible candidates. L at `1f9e` to `1f52` invokes
`3646`: it retains an existing selection or searches candidates for the nearest
reticle match, then executes lock handling. Enter is useful for explicit cycling;
L is also a valid acquisition path. The static distinction does not prove that
using Enter earlier would prevent this failure. No HIND identification or combat
shot is obtained in this rehearsal; the incoming attacker's identity remains
unverified. A further tactical rehearsal requires fresh authorization.

Working if: the integrity gate holds before another combat attempt, cleanup
errors are visible rather than relabelled, original files and pass attribution
remain intact, and a static control finding is not counted as runtime success.
