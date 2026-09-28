# Local Play status

The original PC executables own gameplay, mission logic, menus and disk saves.
Godot renders the supported high-resolution layers and plays event-driven audio.
The authored calibration range is separate. The whole remaster is unfinished.

## Verified flows (28 September 2026)

| Surface | Evidence | Limit |
|---|---|---|
| All eight scenarios | `artifacts/pc-all-scenarios-trace-01/report.json`: 54,657 original frames, 118 passing checks, byte-identical RAM/video/input records against `pc-all-scenarios-baseline-02` | Entry, four stations, pause/resume, sound toggle, cannon, coax, smoke, quit, debrief and return to menus; mission victories/defeats are not covered |
| All 32 scenario/station views | `artifacts/pc-all-scenario-frames-native-02/report.json`: 161 checks, zero errors, production Godot rendering of the recorded original packets | Rendering replay, not a second live execution |
| Actual combat loss, debrief, menu and reentry | `artifacts/pc-combat-loss-trace-01/report.json`: all 15,122 RAM/video/input records match the unmodified baseline; `pc-combat-loss-native-03/report.json`: 1,841 checks, 187 stages, zero errors | Original enemy damage ends Mossel Defense without a quit key or live RAM edits. Native production host reruns from the same neutral START boundary and fresh disk; other outcomes remain open |
| Campaign disk save and continue | `artifacts/pc-campaign-play-verification-01.json`: seven checks, two real public-Play launches, original Take R+R then cold-boot Continue | Test campaign PLAYQA, first mission only; no RAM snapshot restoration; full campaign outcome coverage remains open |
| Weapons and motor audio | `artifacts/pc-play-default-audio-native-01/report.json`: 1,712 native frames, 3,426 loop checks, zero errors | Observed original cannon, coax, smoke, impact, loader and motor routes; missing cues remain silent |
| Bearing speech | `artifacts/pc-full-bearings-native-01/report.json`: one original displayed 058 call starts its matching full-sentence take | All 360 bearing resources load and have wording QA; every bearing has not independently occurred in live combat |
| Smoke-exhaustion warnings | `artifacts/pc-warning-trace-03/comparison.json`: 1,060 original frames equal the baseline; `pc-warning-native-02/report.json`: 7,549 checks, zero errors | Two native generated warning starts, one muted consumption and no F5 catch-up, with Genesis cockpit and portrait active. The other seven new warning/outcome calls lack live occurrence proof |
| Shift+3 | `artifacts/pc-modifiers-trace-01/report.json`: all 530 RAM/video/input records equal the unmodified core | Original speed index cycles 0, 1, 2. Original scancode polling also selects AX. This side effect is preserved |
| Plain vehicles | `artifacts/pc-vehicle-flat-play-01/verification.json`: original 1,679-frame close approach, zero textured vehicle polygons | Replacement models are deferred |
| Adjustable audio mix | `artifacts/pc-audio-menu-native-04/menu-report.json`: all 15 checks pass using real macOS menu clicks; `pc-audio-mix-native-02/mix-report.json`: 1,020 original input/RAM/video records unchanged during nine mix changes | Native macOS verified; non-native menu layout rendered on macOS, other OS acceptance remains open; music is still unfinished |

## Presentation repairs

Rejected vehicle texture panels are disabled in Play. Original flat-colour
geometry remains. The commander station's silver rails now join continuously
around the heading display. Comparison of all 32 station images changed only
the eight commander surrounds, leaving other pixels identical. See
`artifacts/pc-commander-frame-join-01.json`.

Audio is enabled by default. `--no-audio` disables presentation audio. Original
F5 and pause still govern the original sound gate. All 360 bearing calls use
full-sentence generative TTS with digits spoken separately, including leading
zeroes. Both “nine” and “niner” are accepted. Nine damage reports also have
live evidence. Fifteen further source-verified subsystem/mobility takes
bring this bank to 24 damage reports; all load and start native sample players,
with individual live occurrence still unproven for those additions. Eight new
Gemini 3.8 warning/outcome calls cover fuel, heat, boundaries, water, slopes,
smoke availability and convoy destruction. Original portraits 0, 1 and 2 have
authored Orus, Iapetus and Algenib casting. Only smoke exhaustion has live
occurrence proof so far; the other seven have isolated source assignment and
native playback checks. No mixed gameplay recordings are used as live samples.

The app's Audio menu independently controls master, sound effects, crew voices,
and engine/turret volume. 100% preserves the existing authored mix. Off stops
that channel immediately; raising its level never replays an old one-shot or
spoken call. Active source-driven motor loops can resume. Original F5 and pause
remain authoritative. Choices persist in a separate Godot preference file and
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

## Open acceptance work

* Sustained live frame pacing is now close to target in the latest local probe.
  `pc-typography-sustained-01/comparison.json` covers 6,120 consecutive SIM frames
  over 103.38 seconds at 59.20 fps versus 59.47 advertised, with healthy audio.
  Every full packet, original one-frame request, final metadata and rendered
  image matches the preceding six-cycle route. Segment rates span 58.89 to 59.54.
  Earlier loaded-host runs measured substantially less, including 45.39 fps for
  that same route. Historical speed calibration, longer campaigns, other hardware
  and performance under varying load remain open. Exact instrument comparisons
  and bounded expected-glyph reuse reduce presentation work without skipping any
  current source pixel, changing emulated CPU speed or batching live input.
* Victories, additional defeats, campaign progression and longer-session outcomes.
* Remaining dialogue, radio/warnings, music and listening/mix review. Volume
  controls are implemented; a finished musical arrangement and mix are not.
* Remaining graphics families and transitions, preserving Genesis precedence and
  original PC visibility. Vehicle replacement is intentionally deferred.
* Portable packaging and community-release rights/provenance review. Work is
  local only; no publication or redistribution has been performed.

These are remaining outcomes of the active goal, not optional extras. Each
additional parity claim requires its own source comparison and runtime evidence.
