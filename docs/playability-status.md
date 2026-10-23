# Playability status

The original PC executables own gameplay, mission logic, menus and disk saves.
Godot renders the supported high-resolution layers and plays event-driven audio.
The authored calibration range is separate. The non-Modern completion pass has passed the local aggregate gate.
HEAT artwork is now restored; target-rate performance and release acceptance remain open.

## Alpha 7, 23 October 2026

Runtime source `969eac16c98883f77441f8086acbc95eb0e442f6` supplies the full 57-model Tactical roster, animated tank-and-crew menu, revised HUD, independent 19-cue score, and stronger ending smoke and flames. Web, Windows and Linux use version `0.1.0-alpha.7`.

The native Windows/Linux builds passed portable-alpha run 40005475073. Their released archives were independently checked for CRC, every manifest hash and size, exact closure, all 1321 common frozen inputs, original-free boundaries and corresponding core source. Full interactive Windows/Linux graphics and audio remain unmeasured.

The Mac Alpha 7 candidate is Developer ID signed (build 592b1b9cf9ba8cd922c5, 87 targets), with 62 native frontdoor checks and 15 normal-viewer ending checks passing. **It is not yet notarized or installed.** Apple submission has not started because the established Keychain credential profile is unavailable. The existing 23 October Mac preview remains separately labelled and unchanged; it must not be described as Alpha 7 or notarized.

Original gameplay, timing and saves remain unchanged. Keep the previous app and profile backup for build-pinned state compatibility.

## Alpha 6 release, 16 October 2026

Public pre-release `v0.1.0-alpha.6`, built from `146bbfb`, carries:

* a notarized macOS ARM64 app: signed build 60b1fe1028a52fabbbc8, Apple
  submission c15859b3-4728-449a-a32b-b1495bf7fa10;
* native Windows and Linux x86_64 portable apps from portable-alpha run
  38835631121;
* the corresponding DOSBox Pure source for each platform.

What it adds:

* the authored intro shot (see `genesis-intro-integration.md`);
* the Calibration Range title tank and crew remade to match the box cover;
* setup windows that scale to the display without scrollbars.

Gameplay is unchanged. The macOS and Linux cores are byte-identical to Alpha 5's
(`37bff087…` and `1589d8d1…`), so Alpha 5 save states load on those platforms.
The CI-built Windows core differs in bytes (`00ce8483…`, against Alpha 5's
`df3bb6ce…`). Save restore pins the exact core, so Windows Alpha 5 save states
need Alpha 5.

Verified:

* the full gate on `146bbfb` (927 Python tests OK, 71 skipped; every Godot check);
* signed-app PC and Genesis import, prepare, and a cold-boot Tactical cupola
  capture;
* the scaled launcher window on screen;
* Gatekeeper on the copy extracted from the ZIP;
* Windows and Linux: 147 tests, setup smoke, recovery and the archive audit.

Not verified: full missions, Windows/Linux graphical playback and the scaled
setup window on those platforms, and the Modern/Tactical 60 fps target.

Working if: the release lists the three app ZIPs, three source archives and a
`SHA256SUMS.txt` whose hashes match GitHub's asset digests.

## Alpha 5 release, 15 October 2026

Public pre-release `v0.1.0-alpha.5` carries a notarized macOS ARM64 app (signed
build 0c4842b0d9a008c4f167, Apple submission eb640586-15a0-4e00-aa90-ab643dd0dc5d)
and native Windows/Linux x86_64 portable apps from portable-alpha run
38746120300, each with its corresponding DOSBox Pure source. It is the first
release built on the 15 October trace core (`37bff087…`), opens in Tactical
graphics with the Tactical HUD, and ships no decoded original data: PC- and
Genesis-derived files, including Modern's shape registry from the player's
`SHAPE.TBL`, are reproduced at import. Save states from earlier alphas do not
load. Verified: signed-app PC and Genesis import, prepare and a cold-boot
Tactical cupola capture (73 samples, exit 0); Gatekeeper from the extracted
ZIP; Windows/Linux original-free core, frozen setup and About checks. Not
verified: full missions on any platform, Windows/Linux graphical playback of this
build, and the Modern/Tactical 60 fps target.

Working if: the release lists the three app ZIPs, three source archives and a
`SHA256SUMS.txt` whose hashes match GitHub's asset digests.

## Earlier candidate, 30 September 2026

The app is named **M1 Abrams Battle Tank Fan Remaster**. Private alpha.3 is a
draft with native macOS ARM64, Windows x86_64 and Linux x86_64 candidates.
Windows/Linux native build, original-free core/checkpoint, frozen setup/About
and package-integrity gates passed. Actual PC-game playback on those two
platforms remains unverified. macOS is Developer ID signed; Apple notarization
was pending at that date. Alpha 4 for macOS has since been notarized and published
(3 October 2026); alpha.2 remains available for rollback.

Two newer local changes are awaiting rebuilt packages: exact text/bitmap CPU
optimizations and the box-art startup splash. The splash paints before asset
preloading, yields immediately to the first valid original frame, and retains
readable startup errors. It adds no game timer or minimum loading delay.

The audit-heavy moving performance probes did not establish an FPS improvement
or consistent 60 fps. The release-readiness pass will measure ordinary-like
playback in a coordinated quiet window. See [the pacing evidence](pc-pacing-research.md).
The earlier measurements below describe their dated candidates and test loads.

## Earlier standalone alpha (28 September 2026)

The Apple Silicon macOS app bundles Godot and Python/Pillow. It requires the
player's PC files, accepts Genesis optionally, and contains neither original
game. Fresh PC-only launch, optional Genesis import, profile-preserving upgrades,
checkpoint recovery and native fullscreen/focus/menu use have been exercised.
The app is ad-hoc signed and remains local. The public GitHub repository contains
source and selected gallery images; the latest application changes are still local.

The packaged runtime completed 1,801 seconds of normal-speed SIM play, all four
stations and 18 restores, with 271,348 checks and no errors. Full RAM auditing
was enabled: the 36 to 38 original replies/second measured in that run are not
an ordinary-play benchmark. Sustained unaudited performance still needs testing.
Receipts: `artifacts/alpha-readiness-20260928/ACCEPTANCE.md`.

New checkpoints preserve validated artwork ownership. Legacy same-core
checkpoints without that data retain a conservative PC-art fallback. See
[controls](play-controls.md) and [standalone installation](standalone-macos.md).

## Recorded checks (28 September 2026)

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
| Plain vehicles | `artifacts/pc-vehicle-flat-play-01/verification.json`: original 1,679-frame close approach, zero textured vehicle polygons | Historical non-Modern capture; optional low-poly Modern geometry is now implemented locally |
| Adjustable audio mix | `artifacts/pc-audio-menu-native-04/menu-report.json`: all 15 checks pass using real macOS menu clicks (a four-channel run that predates the Music channel and Restore default mix; the current `test_pc_audio_menu_native.gd` expects `music:70` and has no recorded receipt yet); `pc-audio-mix-native-02/mix-report.json`: 1,020 original input/RAM/video records unchanged during nine mix changes; current five-channel mix unit gate: 110 checks | Native macOS menu verified for the four earlier channels only; the five-channel native menu needs a `pc-audio-menu-native-05` rerun. The -04 fallback half built the bare `pc_audio_menu.gd`; the current test builds the production `pc_play_menu.gd` in-canvas menu (`prefer_global_menu=false`, configured as `pc_bridge_viewer.gd` does), so its layout checks will cover the shipped fallback once -05 is recorded. Other OS acceptance remains open |
| Full checkpoints | `artifacts/finish-20260928/root-checkpoint-final/report.json`: 26/26 root checks pass, including uninterrupted-video/ownership comparison, observer-on/off native parity, cross-process continuation, campaign restoration and failed-load rollback | Validated host ownership persists; fresh scanlines rebuild masks. The first restored video transition is held. States remain pinned to core/game/platform |
| Live graphics and fast forward | `artifacts/pc-conveniences-native-02/conveniences-report.json`: 113 checks, zero errors; production menu callbacks, save/load and identical source RAM/video after 15 normal frames versus 1+2+4+8-frame requests | Bounded input route; no mission victory claim. Modern was unavailable in that earlier capture |
| Graphics transition regression | `artifacts/finish-20260928/root-graphics-modes-report.json`: 10,253,369 root checks across 158 native frames, zero errors; authentic donor exclusions independently tested | All three live modes preserve their source boundaries. Both lower gunner consoles conservatively retain PC pixels in Genesis mode |
| New checkpoint core ordinary-run parity | `artifacts/pc-conveniences-parity-01/comparison.json`: 13 checks, all 3,716 paired original RAM/video/input records match the unmodified core | Ordinary radio route; checkpoint-specific continuation is covered separately |
| Additional speech, effects and frontend music | Native root gates: 165 remaining-audio checks and 47 music/transport checks, zero errors; original CPU oracles: 54 crew assignments and seven sound-request blocks | Source assignment and native player proof; every new cue has not occurred in a live mission, and independent listening acceptance remains open |

The combat-loss (1,841), smoke-warning (7,549) and radio (26,142) native check
totals above counted one constant-true `vehicle_art` check per frame. Since
15 October 2026 those tests count it once per run (`rejected vehicle panels never
attached (N frames)`), so a rerun reports smaller totals for the same evidence.
Re-quote all three from the next `VALIDATE_LIVE=1 ./tools/validate.sh` run.

## Presentation repairs

Rejected vehicle texture panels are disabled in Play. Original flat-colour
geometry remains in the legacy modes. Modern adds source-bound low-poly detail. The commander station's silver rails now join continuously
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
full-sentence generative TTS. Nine damage reports also have
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
Backspace and Shift/Ctrl/Alt are forwarded. Top-row digits and keypad keys
remain distinct. Shift+3 reaches the original system-speed control. Tab is
reserved for the remaster's 8x fast-forward toggle in Play (see
[play controls](play-controls.md)), so the original never sees it there, including
at its any-key prompts; only non-Play diagnostic runs (`PC Bridge.command` without
`--play`) forward Tab.

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
before replacing the live session. Fast forward (Tab or Session > Fast forward)
toggles between normal speed and 8 original frames per request, with presentation
sound muted and no stale speech catch-up.
The original CPU/game-speed settings remain untouched.

Play also accepts Cmd+S / Cmd+L for quick save/load in slot 1 (a quick save onto
an occupied slot 1 asks for a second press within four seconds), Cmd+Shift+L for
Undo last load, and Cmd+G to cycle graphics. Other platforms, and the browser on
every platform, use Ctrl+Alt in place of Cmd. On Windows layouts where AltGr types
a character for S, L or G, those chords are ignored; the Session menu remains
available. Shortcut chords are withheld from the source game, including
trailing key releases, and show brief feedback without reserving a function key.

Graphics switches the cached current frame among six modes: exact PC EGA,
palette-preserving EGA Upscaled, verified native Genesis donors, Genesis Upscaled
artwork, and the source-bound low-poly Modern and Tactical modes under local
acceptance testing. HUD Style (Restored or Tactical) is independent. Assets are
preloaded. Genesis is explicitly partial, with original PC pixels in unmatched
fields, and needs the capture-derived native pack that only an equipped checkout
carries. Native apps built after 15 October 2026 and the Web edition show original
PC pixels where that pack would supply Genesis graphics mode, the Genesis map frame
and the motor-pool clipboard. That fallback is accepted (Claude's call on 15 October
2026, under Nell's "Fix everything according to your best judgment"): the captured
screens come from the Genesis emulator and cannot be redistributed, and the PC
pixels are the original game's own presentation.
See [play controls](play-controls.md) and [mode coverage](graphics-modes.md).

The current tester package is the standalone app described above. Legacy
source-review/private developer kits remain available for development; their
installed-runtime requirements and included PC inputs do not apply to the app.
See [packaging](packaging.md) and [rights review](release-rights.md).

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
  is in `graphics-coverage.md`. Modern geometry and its separate validation are documented in `modern-renderer.md` and `modern-asset-register.md`.
* Intel Mac support, target-platform gameplay checks, notarization of future
  macOS builds and public community-release clearance. The Apple Silicon alpha and gallery are
  distributed through the public [GitHub repository](https://github.com/NellInc/Abrams/releases).

Each additional parity claim requires its own source comparison and runtime evidence.


## GitHub alpha candidate, 29 September 2026

Version 0.1.0-alpha.2 integrates Modern, all current first-person refinements,
exact geometry/cockpit-proof performance reuse, and a native setup/About interface.
The release requires separately imported PC files, with optional Genesis.
Neither original game is bundled. The repository was private at the time; it is now public.

The corrected moving native route measured 38.77 fps before and 40.12 after,
with identical requested inputs and final rendered output. All 32 station/scenario
screens match the preceding alpha exactly. This does not meet consistent 60 fps;
Modern stays experimental. See [pacing evidence](pc-pacing-research.md).
