# Local Play status

The original PC executables own gameplay, mission logic, menus and disk saves.
Godot renders the supported high-resolution layers and plays event-driven audio.
The authored calibration range is separate. The non-Modern completion pass has passed the local aggregate gate.
HEAT artwork is now restored; target-rate performance and release acceptance remain open.

## Verified flows (28 September 2026)

| Surface | Evidence | Limit |
|---|---|---|
| Held-input restoration | `artifacts/next-pass-20260928/held-native-root/report.json`: six same-timeline fresh-process cases and 18 supervisor checks; Godot shortcut 112 and live-scheduling 157 checks | Includes release/change, fire, steering, Shift+3, fast forward, undo and failed-load rollback. Focus signal delivery is tested synthetically; physical hardware is separate |
| Current host endurance | `artifacts/next-pass-20260928/host-endurance/report.json`: 70,553 frames, 2,822 checks, eight scenarios, 19 checkpoint cycles and cold campaign Continue | Adaptive original debrief loops cause run-to-run frame-count differences. No mission victory claim |
| Current native endurance | `artifacts/next-pass-20260928/native-endurance-final/endurance-report.json`: 11,107 checks, 3,600 paced frames, zero audio-consumer lag; 58.98 to 59.78 fps | Completed unattended after repairing a final screenshot test-harness stall. Bounded timing and consumer-state proof, not acoustic listening or indefinite memory acceptance |
| Earlier non-Modern endurance | `artifacts/finish-20260928/root-endurance-final/report.json`: 71,873 original frames, 2,839 checks, all eight scenarios, 32 stations, 19 checkpoint cycles and cold campaign Continue | Correctness under bounded routes; no mission victory or indefinite leak claim. Current-core root rerun |
| All eight scenarios | `artifacts/pc-all-scenarios-trace-01/report.json`: 54,657 original frames, 118 passing checks, byte-identical RAM/video/input records against `pc-all-scenarios-baseline-02` | Entry, four stations, pause/resume, sound toggle, cannon, coax, smoke, quit, debrief and return to menus; mission victories/defeats are not covered |
| All 32 scenario/station views | `artifacts/pc-all-scenario-frames-native-02/report.json`: 161 checks, zero errors, production Godot rendering of the recorded original packets | Rendering replay, not a second live execution |
| Actual combat loss, debrief, menu and reentry | `artifacts/pc-combat-loss-trace-01/report.json`: all 15,122 RAM/video/input records match the unmodified baseline; `pc-combat-loss-native-03/report.json`: 1,841 checks, 187 stages, zero errors | Original enemy damage ends Mossel Defense without a quit key or live RAM edits. Native production host reruns from the same neutral START boundary and fresh disk; other outcomes remain open |
| Campaign disk save and continue | `artifacts/pc-campaign-play-verification-01.json`: seven checks, two real public-Play launches, original Take R+R then cold-boot Continue | Test campaign PLAYQA, first mission only; no RAM snapshot restoration; full campaign outcome coverage remains open |
| Weapons and motor audio | `artifacts/pc-play-default-audio-native-01/report.json`: 1,712 native frames, 3,426 loop checks, zero errors | Observed original cannon, coax, smoke, impact, loader and motor routes; missing cues remain silent |
| Bearing speech | `artifacts/pc-full-bearings-native-01/report.json`: one original displayed 058 call starts its matching full-sentence take | All 360 bearing resources load and have wording QA; every bearing has not independently occurred in live combat |
| Smoke-exhaustion warnings | `artifacts/pc-warning-trace-03/comparison.json`: 1,060 original frames equal the baseline; `pc-warning-native-02/report.json`: 7,549 checks, zero errors | Two native generated warning starts, one muted consumption and no F5 catch-up, with Genesis cockpit and portrait active. The other seven new warning/outcome calls lack live occurrence proof |
| Radio arrival and retrieval | `artifacts/pc-radio-trace-01/comparison.json`: 3,716 original frames equal the baseline; `pc-radio-native-01/report.json`: 26,142 checks, zero errors | One attention sample, two generated voice starts and one muted retrieval; no F5 catch-up. All seven source captions have dry Gemini takes and wording QA; six lack live occurrence proof |
| Shift+3 | `artifacts/pc-modifiers-trace-01/report.json`: all 530 RAM/video/input records equal the unmodified core | Original speed index cycles 0, 1, 2. Original scancode polling also selects AX. This side effect is preserved |
| Plain vehicles | `artifacts/pc-vehicle-flat-play-01/verification.json`: original 1,679-frame close approach, zero textured vehicle polygons | Replacement models are deferred |
| Adjustable audio mix | `artifacts/pc-audio-menu-native-04/menu-report.json`: all 15 checks pass using real macOS menu clicks; `pc-audio-mix-native-02/mix-report.json`: 1,020 original input/RAM/video records unchanged during nine mix changes; current five-channel mix unit gate: 110 checks | Native macOS verified; non-native menu layout rendered on macOS, other OS acceptance remains open |
| Full checkpoints | `artifacts/finish-20260928/root-checkpoint-final/report.json`: 26/26 root checks pass, including uninterrupted-video/ownership comparison, observer-on/off native parity, cross-process continuation, campaign restoration and failed-load rollback | Validated host ownership persists; fresh scanlines rebuild masks. The first restored video transition is held. States remain pinned to core/game/platform |
| Live graphics and fast forward | `artifacts/pc-conveniences-native-02/conveniences-report.json`: 113 checks, zero errors; production menu callbacks, save/load and identical source RAM/video after 15 normal frames versus 1+2+4+8-frame requests | Bounded input route; no mission victory claim. Modern is deliberately unavailable |
| Graphics transition regression | `artifacts/finish-20260928/root-graphics-modes-report.json`: 10,253,369 root checks across 158 native frames, zero errors; authentic donor exclusions independently tested | All three live modes preserve their source boundaries. Both lower gunner consoles conservatively retain PC pixels in Genesis mode |
| New checkpoint core ordinary-run parity | `artifacts/pc-conveniences-parity-01/comparison.json`: 13 checks, all 3,716 paired original RAM/video/input records match the unmodified core | Ordinary radio route; checkpoint-specific continuation is covered separately |
| Additional speech, effects and frontend music | Native root gates: 165 remaining-audio checks and 47 music/transport checks, zero errors; original CPU oracles: 54 crew assignments and seven sound-request blocks | Source assignment and native player proof; every new cue has not occurred in a live mission, and independent listening acceptance remains open |

## Presentation repairs

Rejected vehicle texture panels are disabled in Play. Original flat-colour
geometry remains. The commander station's silver rails now join continuously
around the heading display. Comparison of all 32 station images changed only
the eight commander surrounds, leaving other pixels identical. See
`artifacts/pc-commander-frame-join-01.json`.

The Escort bridge approach no longer enlarges the original terrain checkerboard.
Seventeen raised-plateau/slope shapes now share the source-bound hill treatment,
with 32 exact Genesis face counterparts. All 3,716 original radio-route frames
still match after the change; the opaque HUD and untextured vehicles are preserved.
See `pc-hill-art-integration.md` for native image and source comparisons.

The driver portrait no longer waits for its caption before becoming remastered.
It now appears on the first complete original face frame and clears on original
erasure. `artifacts/pc-portrait-live-01/report.json` verifies all 146 transition
frames within the unchanged 3,716-frame source route; the former 18-frame delay
is removed. See `genesis-portrait-integration.md` for the before/after evidence.

Audio is enabled by default. `--no-audio` disables presentation audio. Original
F5 and pause still govern the original sound gate. All 360 bearing calls use
full-sentence generative TTS with digits spoken separately, including leading
zeroes. Both “nine” and “niner” are accepted. Nine damage reports also have
live evidence. Fifteen further source-verified subsystem/mobility takes
bring this bank to 24 damage reports; all load and start native sample players,
with individual live occurrence still unproven for those additions. Eight new
Gemini 3.8 warning/outcome calls cover fuel, heat, boundaries, water, slopes,
smoke availability and convoy destruction. Original portraits 0, 1 and 2 have
authored Orus, Iapetus and Algenib casting. Smoke exhaustion has live playback
and parity proof; the Escort radio route also captures original overheating and
steep-slope occurrences. Five other calls retain isolated source assignment and
native playback checks. Seven radio captions use dry Gemini 3.8 Charon takes,
with speech gated on the original displayed message and a separate attention
sample on arrival. No mixed gameplay recordings are used as live samples.

Fifty further distinct captions now have generated performances: 20 scenario
reports, 27 vehicle-class destruction reports and three original speed-setting
announcements. All fifty current takes use Gemini 3.8 with line-specific
performance direction. Selected takes passed blind wording QA,
including separately regenerated repairs. Five previously unmapped source sound
requests now have individually synthesized samples. Four authored sample-based
frontend arrangements use extracted Genesis percussion and new tonal instrument
samples; these are new scores, not recovered original arrangements.

The app's Audio menu independently controls master, sound effects, crew voices,
engine/turret and music volume. 100% preserves the existing gameplay mix; the
new Music channel defaults to 70%. Off stops
that channel immediately; raising its level never replays an old one-shot or
spoken call. Active source-driven motor loops can resume. Original F5 and pause
remain authoritative for gameplay. Frontend music follows Music/Master settings
on source-verified intro, menu, briefing and debrief screens; simulation and
unknown screens stay musically quiet. Choices persist in a separate Godot preference file and
do not touch original campaign saves. See `pc-audio-mix.md`.

## Controls and saves

Original arrows, keypad, alphabetic keys, digits, F1–F12, Enter, Escape, Space,
Tab, Backspace and Shift/Ctrl/Alt are forwarded. Top-row digits and keypad keys
remain distinct. Shift+3 reaches the original system-speed control.

Normal `Play.command` retains its disk overlay in
`artifacts/pc-boot-viewer/saves`. Preserve this folder when clearing diagnostic
output. `./Play.command --saves /absolute/path` selects a separate local profile.
An exclusive session lock prevents two bridge windows writing the same overlay.
The lock releases after the original core flushes on shutdown. Original `GAME/`
and `GENESIS/` directories cannot be selected as save destinations.

Launch/bridge errors now remain visible in the game window until it is closed.
Diagnostic captures still exit nonzero on failures.

The new Session menu provides five numbered checkpoints and Undo last load.
Checkpoints restore the native machine and campaign overlay together. Atomic
archives retain overwritten versions; invalid/incompatible states are rejected
before replacing the live session. Fast forward requests 2, 4 or 8 original
frames at a time, with presentation sound muted and no stale speech catch-up.
The original CPU/game-speed settings remain untouched.

Play also accepts Cmd+S / Cmd+L for quick save/load in slot 1, Cmd+Shift+L for
Undo last load, and Cmd+G to cycle graphics. Other platforms use Ctrl+Alt in
place of Cmd. Shortcut chords are withheld from the source game, including
trailing key releases, and show brief feedback without reserving a function key.

Graphics switches the cached current frame among exact PC EGA, verified native
Genesis donors and Upscaled artwork. Assets are preloaded. Genesis is explicitly
partial, with original PC pixels in unmatched fields; Modern is disabled.
See [play controls](play-controls.md) and [mode coverage](graphics-modes.md).

Local packaging now has deterministic source-review and private playable-kit
builders, dependency checks and an external persistent-profile launcher. Neither
kit is approved for publication. The private kit requires installed Godot,
Python/Pillow and its included owner-supplied inputs. See
[packaging](packaging.md) and [rights review](release-rights.md).

## Open acceptance work

* Target-rate performance remains open. Current ordinary playback measured
  45.86 fps across 1,200 original frames, versus 37.60 fps before this pass.
  Component timing fell from 4.87 to 4.16 ms for the full compositor. Exact
  packed-byte orientation proof and same-call decoded-mask reuse preserve the
  source predicates. Desktop contention varied, so the observed rate difference
  is not a controlled hardware-independent speedup. The final unattended native
  endurance rerun measured 58.98 to 59.78 fps, averaging 59.4976 fps; sustained
  rate under load remains unproven. See `artifacts/next-pass-20260928/` for current
  profiles and endurance receipts. Earlier 53.58 and 59.20-fps captures describe
  different candidates/load conditions and do not establish current target-rate
  acceptance. Original game CPU settings and step counts remain unchanged.
* Victories, additional defeats, campaign progression and longer-session outcomes.
* Wider individual dialogue/SFX occurrence coverage and independent listening/mix
  review. Frontend paragraphs have no new narration; they lack a complete source
  utterance/interruption identity. Sample-based arrangements and five-channel
  mixing are now implemented.
* Unrecognized transition fallbacks, preserving
  Genesis precedence and original PC visibility. The finite non-Modern register
  is in `graphics-coverage.md`. Vehicle replacement and Modern are deferred.
* Supported-platform standalone installers and community-release clearance.
  A rights/provenance inventory now records the unresolved permissions and
  licence decisions. Work is local only; nothing has been published.

These are remaining outcomes of the active goal, not optional extras. Each
additional parity claim requires its own source comparison and runtime evidence.
