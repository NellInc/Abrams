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
| Shift+3 | `artifacts/pc-modifiers-trace-01/report.json`: all 530 RAM/video/input records equal the unmodified core | Original speed index cycles 0, 1, 2. Original scancode polling also selects AX. This side effect is preserved |
| Plain vehicles | `artifacts/pc-vehicle-flat-play-01/verification.json`: original 1,679-frame close approach, zero textured vehicle polygons | Replacement models are deferred |

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
with individual live occurrence still unproven for those additions. No mixed
gameplay recordings are used as live samples.

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

* Sustained live frame pacing. Recent 600-frame native probes measured 23.68,
  53.41 and 48.10 original frames per second across the performance investigation.
  A final 1,200-frame stationary probe reached 59.03 against the core's 59.47 fps
  target; the matched 1,020-frame moving/control replay reached 57.93 fps with
  every paired RAM/video hash unchanged. These short runs do not establish long-session speed.
  Exact-byte font caching and bulk mask validation reduce read-only overhead;
  emulated CPU rate, frame count, input policy and synchronization remain unchanged.
* Victories, additional defeats, campaign progression and longer-session outcomes.
* Remaining dialogue, radio/warnings, music, mix controls and listening review.
* Remaining graphics families and transitions, preserving Genesis precedence and
  original PC visibility. Vehicle replacement is intentionally deferred.
* Portable packaging and community-release rights/provenance review. Work is
  local only; no publication or redistribution has been performed.

These are remaining outcomes of the active goal, not optional extras. Each
additional parity claim requires its own source comparison and runtime evidence.
