# Finite local endurance acceptance

Run against a built, stable trace core, with no concurrent performance probes.
Every invocation needs a new output directory. The gates use isolated original
save overlays and never write `GAME/` or `GENESIS/`.

```sh
python3 tools/verify_pc_endurance.py --output artifacts/endurance-host-NEW
./tools/godot.sh --script res://tests/test_pc_endurance.gd -- --boot --play --capture --frame-audit --output "$PWD/artifacts/endurance-native-NEW"
./tools/godot.sh --script res://tests/test_pc_play_resize.gd -- --boot --play --capture --frame-audit --output "$PWD/artifacts/endurance-resize-NEW"
```

The host gate visits all eight original scenarios and all four stations, pauses,
resumes, toggles original sound, fires the existing weapon route, quits and
returns through original debriefs. Nineteen checkpoint cycles compare fifteen
one-frame requests with 1+2+4+8-frame requests using full paired RAM/video hashes
and complete decoded state. Seven original information screens have exact pixel
witnesses. A separate campaign profile uses original Take R+R, closes the host,
and enters Continue from a new cold boot. No mission victory is attempted.

The native gate uses the production viewer, shortcuts and transport for three
checkpoint cycles plus three 1,200-frame paced segments. It records frame rate,
inter-packet p50/p95/max, Godot static memory and audio-consumer lag relative to
the current original envelope. This last metric verifies event consumption;
it does not measure speaker latency or replace listening review. The host gate
records native host/worker resident memory and request timings. Bulk-step audio
age is reported separately from real-time playback.

Resize acceptance requires the requested mode and dimensions to remain stable
for 750 milliseconds, with a ten-second deadline. This avoids treating twenty
unthrottled redraws as completion of a macOS fullscreen transition. Exact fitted
viewport pixels, black letterboxes and unchanged guest state remain required.

Completion requires zero process errors, explicit terminal completion lines,
passing JSON reports and unchanged original source hashes. A finite measured
performance sample is not an indefinite leak test. Rate and memory observations
have no invented historical or hardware-independent performance thresholds.
Checkpoint replay compares the trace core to itself; independent unmodified-core
RAM/video parity remains a separate gate. Acoustic drift, long campaign outcomes,
other hardware and other operating systems remain outside this gate.

## Eight-mission campaign lifecycle tour

```sh
python3 tools/verify_pc_endurance.py --campaign-tour --output artifacts/campaign-tour-NEW
```

This opt-in route uses an isolated career and ordinary incomplete mission exits.
It checks eight distinct original scenario indexes, original END debriefs,
seven R&R saves followed by fresh-process Continue, and the eighth mission's
terminal career status. Each closed overlay retains the exact fifty-byte
original career record, accumulating played markers and count. A final cold
Continue must show the original no-active-player response without changing
that record. No RAM checkpoint is restored or career data authored.

END increments the mission count and played marker even for incomplete exits.
Its terminal status 3 therefore establishes a completed administrative tour,
without establishing objective victories or a surviving victorious handoff.
Those outcomes and independent unmodified-core parity remain separate gates.
The original outcome contract is in `pc-executable-research.md`.

Working if: a native run reaches all eight distinct missions, validates every
closed record and cold continuation, observes the terminal original response,
leaves original inputs unchanged, and never labels played markers as victories.

Native evidence, 25 October 2026: the first full tour passes 956 checks with
zero failures in 96.51 seconds. Its observed scenario order is 6, 0, 5, 1, 4, 7,
2, 3. Independent rereading of all eight raw records confirms exact counts,
marker accumulation, identity and the final closed-overlay bytes. Original
screens show the Paris-loss newspaper and then reject cold Continue with
"NO ACTIVE PLAYERS TO CHOOSE FROM". This closes the incomplete-exit campaign
lifecycle, not a victorious career. Evidence:
`artifacts/finish-abrams-20261025/campaign-tour-01/`.

## Held-control checkpoint gate

```sh
python3 tools/verify_pc_held_inputs.py --output artifacts/held-inputs-NEW
./tools/godot.sh --headless --script res://tests/test_pc_play_shortcuts.gd
./tools/godot.sh --headless --script res://tests/test_pc_live_scheduling.gd
```

Six native probes serialize the same timeline used for uninterrupted continuation,
then repeat it in a fresh process: fire release, simultaneous movement/fire,
opposite steering, Shift+3, one-frame make/break, and release after an eight-frame
batch. Current RAM and held-key sets match at every observed frame. Fresh video
is compared after the existing first-returned-frame priming boundary. Eighteen
supervisor checks cover held keys in the save and recovery slot, load/undo,
container rejection, native-load rollback and a fresh supervisor.

The Godot checks cover both platform shortcut chords and release orders, unrelated
held movement/fire, failed loads, changed controls during pending restoration,
Window focus signals and an in-flight fast-forward batch. They do not establish
physical keyboard/gamepad delivery on other platforms, every internal keyboard
controller phase, or acoustic output quality.
