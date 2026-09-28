# Original PC audio events

Tandem audio is now enabled by default (28 September 2026):

```sh
./Play.command
./Play.command --no-audio
```

The original PC executable requests every sound. Godot plays the project's
existing authored WAV samples and selected generated crew performances. It
neither records the emulator's mixed output nor runs the calibration-range
simulation. Original F5 sound-off and pause stop effects and voices. Closing the
viewer drains Godot playback and gracefully closes its own PC helper.

This is partial sound coverage. Engine/turret loops now follow their original
sound channels. Full-sentence generated takes cover all 360 incoming-hit
bearings, 24 damage reports and eight warning/outcome calls, triggered by fully
visible original messages.
Nine damage reports have live occurrence evidence; the 15 additions have original
isolated-routine, wording-QA and native-player coverage, not live occurrence proof.
The warning bank adds authored voices for original portraits 0, 1 and 2.
Smoke exhaustion has live source-parity, mute/restore and native-player proof;
the other seven calls have assignment-block, wording and native-player checks.
Their individual live occurrence remains unproven.
Bearings read each digit, with both nine and niner accepted. See
`voice-workflow.md` for generation and installed-master custody.
Radio, warning sounds, wider crew/readiness coverage, briefings and music remain.
Final mix and human listening approval are also open.

Current native default-audio receipt:
`artifacts/pc-play-default-audio-native-01/report.json`, 1,712 original frames,
3,426 loop checks, zero errors and child exit 0. Earlier opt-in descriptions below
are retained as historical evidence, rather than current launch instructions.

## Original code boundary

The supplied SIM.EXE is fingerprinted by `SimStateReader`. The pinned normal-CPU
observer reads these addresses in the original load segment, without modifying
registers, guest RAM, instructions, execution order or cycle counts:

| Relative CS:IP | Observation | Evidence |
|---|---|---|
| `0000:9107` | Original sound dispatcher | Reads driver type at main DS:35ac, then dispatches PC-speaker/Tandy event tables. Near-call argument is SS:SP+2. |
| `0000:8da3` | Original sound gate | Writes the argument to sound DS:0f48. F5 calls it at 1e78; pause at 407d, resume at 408f. |
| `0000:35ee` | Original reload completion | Reached only after reload state 2 counts down; original instruction clears main DS:79aa. Silent by itself; the visible-READY gate below can qualify a loader bark. |
| `0000:91d6` | Original engine sound parameter | Caller 787e supplies an original movement-derived parameter. Request evidence only; playback reads the running original sound channel. |

Main DS is load+19e0; sound DS is load+18b5. Gate value 1 and sound driver 0 or 1
are the only enabled combinations accepted. Other values remain silent.
Native event 25 carries six little-endian words: instruction IP, near-call
return IP, argument, driver type, current gate, and current reload state.
The gate event reflects its new argument, before the unchanged original executes
its store. The callback cannot return a replacement guest value.

`tools/pc_audio_events.py` qualifies requests by both sound ID and original
return IP. A known number from an unfamiliar callsite stays unmapped.

| Original request | Return IP | Remastered sample | Generated speech |
|---|---|---|---|
| 1, accepted main-gun shot | 33c4 | cannon | On the way! |
| 2, accepted coax shot | 32fa | machinegun | None |
| 3, accepted smoke | 7c07 | smoke | Smoke out. |
| 6 or 8, original impact dispatches | 6b25, 74e5, 7547 | impact | None |
| 14, original menu-selection dispatches | 15e4, 15ff, 1640, 814d, 81cf, 81f3 | switch | None |

The initial firing probe directly exercises cannon, coax and smoke. The later
native motor probe also exercises impact request 6 from return IP 74e5. Other
impact and menu mappings retain callsite evidence without live acoustic coverage. Unknown requests are retained in diagnostics and stay silent. No “Good
hit”, training-range completion, or ready-to-move line is borrowed for an
unrelated PC event. The bounded incoming-hit set now uses the original displayed
bearing with digit-wise pronunciation, including leading zeroes. See the
message-identity and source-frame gate below.

Main-gun routine 3376 checks subsystem condition, loading state and remaining
ammunition before reaching 33c1. Coax routine 3298 similarly checks ammunition
before 32f7. Smoke checks its subsystem and remaining charges before 7c04.
Consequently a key press alone never triggers remastered firing audio.

## Transport and playback

Protocol 4 carries an `audio` envelope, now schema 3 for visible-readiness and crew-message events.
The native sound-event layout is unchanged. The tracing build manifest
advertises `audio_event_schema: 1`; the live host refuses an older local tracing
build with a rebuild instruction and also requires `text_event_schema: 2` and
`message_event_schema: 1`.
Protocol 2 remains the silent historical
static-view backend.

`PresentationSession` drains native requests after each original emulation
frame, stamps a monotone event ID and SIM epoch, and retains them through a
bounded step. `drain_audio()` consumes them exactly once. Reading a graphical
sample does not consume audio. Events survive a batch crossing a program change
as labelled diagnostic evidence; Godot suppresses events belonging to the old
SIM. Both native and session queues have explicit 4,096-event limits and raise
on overflow instead of silently losing commands.

The current audio gate is read at the fenced emulation boundary. It is separate
from potentially older, scanout-paired graphical RAM. Thus a pause can silence
playback without waiting for a new cockpit drawing. A departed SIM cannot keep
a remastered sound running merely because its last video frame is still visible.

Godot validates the entire packet before playing anything. It rejects gaps,
malformed fields, future events, regressing epochs and unsupported sample/voice
names. Replayed packets never replay a sound or reset the current gate. Playback
receipts are bounded to 64 entries, with lifetime counters.

Normal interactive requests advance one original frame at a time. Large
fast-forward research batches still deliver every event as data, but Godot
suppresses audio older than six emulated frames relative to the packet's end.
It does not play several seconds of historical combat simultaneously. This is
why the old `--capture` viewer sequence can report zero played cannon samples:
its fire request was processed during the following 300-frame diagnostic step.
The one-frame native test proves the interactive route separately.

Working if: accepted original requests play once, a rejected or muted shot
cannot produce a remastered firing sample, pause stops live playback, and all
compared RAM/video/input bytes remain equal to the unmodified core.

## Reproduction and evidence

```sh
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode baseline --profile audio \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-audio-baseline-02
python3 tools/capture_pc_render_trace.py --mode trace --profile audio \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-audio-trace-02
python3 tools/verify_pc_audio_trace.py \
  --trace artifacts/pc-audio-trace-02/report.json \
  --baseline artifacts/pc-audio-baseline-02/report.json \
  --output artifacts/pc-audio-comparison-02.json
./tools/godot.sh --script res://tests/test_pc_audio_bridge.gd -- \
  --output "$PWD/artifacts/pc-audio-native-01"
```

Capture output directories are fresh per run. The snapshot is a bounded mission
probe, not a campaign/save package. Disk-dependent lifecycle comparison uses the
separate neutral START snapshot and original filesystem overlays.

* `pc-audio-trace-01` / `pc-audio-baseline-01`: initial 2,091-frame exact RAM,
  video, input and stage-state comparison. All three firing kinds, original
  F5 gate and pause/resume observed. The second probe adds a repeat fire input
  during loading to test rejection explicitly.
* `pc-audio-comparison-02.json`: all 12 checks pass. The expanded 2,091-frame
  probe retains exact RAM/video/input parity and observes 113 events. Three
  accepted cannon requests match three consumed HEAT rounds; the additional
  fire input during loading is rejected without a new sound request.
* `pc-audio-native-01/report.json`: 1,050 actual original frames through the
  subprocess bridge and native Godot, 20 observed events. Two audible cannon
  requests, one coax and one smoke request started sample players; the third
  cannon request was muted. Four original gate changes, no errors, child exit 0.
  No mixed audio was recorded. This is machine playback proof, not human mix QA.
* `pc-audio-lifecycle-01/report.json`: 7,267 frames and 52 stages match the
  unmodified baseline, including original boot, mission, debrief and reentry.
* `pc-audio-unit-01.log`: 38 Godot checks cover real sample/voice loading,
  repeated delivery, original gates, stale batches, epoch transitions, malformed
  packets, missing events and native playback shutdown.
* `validation-20260927T095432Z/results.txt`: all 18 stages pass, including 143
  Python tests and source preservation, terminal exit 0.
* `pc-audio-viewer-01`: native existing viewer, nine valid pipe samples, clean
  exit. Its deliberately large diagnostic steps suppress stale firing audio.

Audio-only core used for the original pilot receipts (superseded by the
text-enabled pin in `pc-text-research.md`), SHA-256:
`3a9f0e56ef3f65bee62fb027fd5938ac2501906d91136107953d87884b9ddf5f`.
Observer header SHA-256:
`4c900d08085090914ea973917b7046d92e4b6df81284adc4fd608c617842f963`.
The unmodified baseline remains
`57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.
Original executable and asset bytes are unchanged. No new audio generation,
network calls, proprietary redistribution, publication or push was performed.

## Continuous engine and turret channels

`tools/pc_audio_loops.py` reads the original sound interpreter's live channel
records at the same fenced boundary as the sound gate. It does not infer motor
state from input keys, turret angle, vehicle speed or an invented acceleration
model. Restoring a mission snapshot therefore restores its already-running
engine sound without waiting for another start request.

Each channel record has 48 bytes. Offset 0 is the remaining interpreter timer,
2 its next program byte, 4 its base tone period, and 0a its amplitude. All four
conditions must qualify: a nonzero timer, a program cursor within the relevant
original loop, a nonzero period and nonzero amplitude. A different sound using
the same channel cannot acquire motor identity.

| Original driver | Record table in sound DS | Engine channel / program interval | Turret channel / program interval |
|---|---|---|---|
| PC speaker (0) | 0f76 | 3 / [0bd4, 0bfc) | 2 / [0c20, 0c84) |
| Tandy (1) | 1110 | 0 / [0628, 0650) | 1 / [0650, 06cc) |

The original dispatcher 9107 and interpreter 8f33 execute unmodified in
`tools/pc_audio_loop_oracle.py`. The isolated harness supplies only arguments,
stack, driver selection and the channel context normally set by the original
interrupt wrapper. Both driver paths pass 3,744 ticks each: engine start, idle,
parameter change, turret start, original release tail, engine stop and all 12
other tested sound requests. None of those unrelated requests masquerades as a
motor loop. This is isolated CPU evidence for Tandy; the live core probe uses
PC-speaker mode.

Godot plays the existing turbine sample and a new separate hydraulic/gear sample.
The turret source is original mathematical synthesis, two seconds of periodic
48 kHz mono 16-bit audio. Its waveform and periodic boundary are checked, and
its source hash is recorded in `provenance.json`. The rebuild preserved all 16
pre-existing effect and voice WAVs byte-for-byte.

Pitch follows the ratio of the original idle period to the current channel
period, with presentation limits of 0.25 to 4.0. Gain follows channel amplitude
relative to its driver-specific reference and the authored mix level. These are
new timbres and a modern mix, not an emulation of PC-speaker waveforms or its
single-voice arbitration. Original decisions, channel activation and release
remain authoritative. New samples, historical pacing and subjective mix approval
are distinct claims.

### Compressed loop endpoint repair

The existing shared engine player used `data.size()/2` as its loop endpoint.
Runtime inspection established that Godot imported both loops as QOA: 38,864
compressed bytes represented 96,000 sample frames. The old calculation looped
at frame 19,432 (about 0.405 seconds), truncating a two-second authored cycle.
The new turret player initially inherited that broken assumption.

Both players now use the imported duration multiplied by sample rate. Godot
[defines loop endpoints in samples and supports compressed WAV data](https://docs.godotengine.org/en/stable/classes/class_audiostreamwav.html#class-audiostreamwav-property-loop-end).
`pc-audio-loop-import-probe.log` retains the observed defect;
`pc-audio-loop-import-fixed.log` confirms both endpoints at 96,000. Regression
checks cover the actual compressed imported resources. The shared repair also
fixes the calibration range's engine loop; its full runtime gate still passes.

A separate diagnostic defect omitted muted loop stops because the player had
already been stopped before transitions were counted. Desired original channel
state now has its own bounded transition record. F5 and pause stops, as well as
resumes, appear in the native report.

### Motor evidence

* `pc-audio-loop-oracle-01.json`: both unchanged original interpreter paths,
  7,488 ticks total, all 14 case checks pass.
* `pc-audio-loop-synthesis-01.json`: all 16 earlier WAV hashes unchanged; the
  new turret sample hash is
  `d058da69d0eed464859d86db4bb2ff2af3ae038e8e8798ca15fb9ffe7646499e`.
* `pc-audio-comparison-03.json`: all 18 checks pass over 2,091 frames. RAM,
  video, input, decoded gameplay states and live sound-channel states are equal
  to the unmodified baseline. Turret rotation continues on key release; its
  stop command retains the original deceleration tail before going silent.
* `pc-audio-native-04/report.json`: 1,692 actual original frames, 3,386 channel
  activation/pitch comparisons, 130 sounding turret frames, 370 muted-loop
  observations and four distinct engine periods. Both loops use all 96,000
  frames. Two cannon, one machine-gun, one smoke and one impact sample played;
  one muted accepted cannon request stayed silent. Four original gate changes,
  correct F5/pause transition receipts, zero errors, clean child exit.
* Native runs 02 and 03 retain earlier activation evidence; run 02 predates the
  transition-log repair, and both predate the compressed endpoint repair.
* `validation-20260927T101153Z/results.txt`: all 18 stages pass, including 146
  Python tests, 52 Godot audio assertions and original-source preservation,
  terminal exit 0.

Reproduce the isolated interpreter check with the pinned analysis environment:

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_audio_loop_oracle.py \
  --output artifacts/pc-audio-loop-oracle-01.json
```

For fresh live captures, use the earlier baseline/trace `audio` commands with
new output directories, then compare them with `verify_pc_audio_trace.py`.
The native test now also checks continuous channels and full loop endpoints.
No native core changes were required for this extension; the pins above remain
current. No original instructions or files changed, and no mixed recordings or
external generation were used.

Working if: restored engine audio starts from the original occupied channel,
turret release follows its interpreter tail, mute silences still-active channels,
other sounds never claim motor identity, and imported loops cover all authored
sample frames rather than a compressed-byte approximation.

## Visible-text prerequisite

The subsequent text observer proves original READY, TRACK, LOAD and the empty
smoke warning against the actual displayed pixels. Details, native font recovery
and unchanged-core comparisons are in `pc-text-research.md`. This prerequisite
supplies the source-frame proof used by the bounded loader gate below. General
message occurrences, suffix grouping and radio timing remain separate work.


## Visible-READY loader call

The opt-in tandem audio pilot now reuses the existing generated loader “Up!”
performance. The selected dry master is the previously verified Gemini 3.1 Flash
TTS fallback, Fenrir voice, 24 kHz mono PCM, 0.92 seconds. Its installed SHA-256
is `d9d9c52d76624e8a3cb01c610bc42ca4e396424f7220d0d760a7ba494f6b9f2c`.
No sample or generation was changed for this integration.

`ReadinessBark` follows this bounded presentation contract:

1. Original `0000:35ee` must complete a real reload. Record the current monotone
   text-draw sequence as a barrier. The event alone remains silent.
2. A strictly newer original draw must produce the exact READY string at main
   DS:0aca, through the verified weapon-status caller 55df.
3. That run must pass the source-glyph, original-page, scanout-slot and complete
   RGB rectangle comparison from `pc-text-research.md`.
4. Within six emulated frames of completion, emit one `readiness_visible` event,
   carrying the completion frame, barrier, newer draw sequence and RGB hash.
5. Consume the pending completion. A new accepted cannon shot, departed SIM or
   timeout discards it. Returning to the gunner station much later cannot speak
   an old load. A muted completion or muted display boundary stays silent.

The six-frame window is a conservative presentation freshness limit. It writes
no gameplay timers. LOCKED, malfunction, absent/non-gunner readiness displays
and cases outside this bounded contract get no new loader bark. This is partial
readiness coverage, intentionally avoiding inferred dialogue.

Godot audio schema 2 validates the entire new event before any playback, including
known source addresses, strictly newer draw order, bounded delay and pixel hash.
The call uses only `voice_loaded`, with no invented sound effect. Existing
monotone IDs, epoch ownership, duplicate suppression, stale-batch suppression,
F5, pause, voice preferences and stream shutdown still apply.

Working if: old READY pixels never qualify a newly completed reload, each eligible
visible transition requests the generated voice once, and a muted or stale load
never becomes an audible catch-up call.

### Evidence

The implementing assistant also reviewed this integration.

* `pc-readiness-comparison-01.json`: all 23 checks pass over 2,091 frames against
  the untouched source baseline. RAM, video, inputs and original sound channels
  are identical. The three readiness events follow completion by exactly three
  source frames: 822 to 825, 1477 to 1480 and 1918 to 1921. The middle one remains
  muted. All three require a strictly newer original text draw.
* `pc-readiness-native-02/report.json`: actual one-frame PC pipe and native Godot
  playback, 1,712 original frames. Three paired READY receipts, two generated
  loader voice starts, one silent load, 3,426 loop checks, unchanged effect/gate
  counts, zero errors and child exit 0. Native completion-to-ready frames are
  1115 to 1118, 1528 to 1531 and 1934 to 1937.
* The first native test stopped at frame 1934, precisely the final reload
  completion. It correctly produced no final bark yet, so its expectation of
  three receipts failed. The retained `pc-readiness-native-01` report shows that
  failure. The test was extended by 20 input-free frames through the actual
  display update; the timing gate itself was unchanged.
* `pc-readiness-lifecycle-01/report.json`: all 11 lifecycle checks pass, 7,267
  compared RAM/video/input frames, all 52 stage states and program boundaries
  identical to the original baseline.
* `validation-20260927T105237Z/results.txt`: all 18 stages pass, including 165
  Python tests and 77 Godot audio assertions. Unit coverage includes old/absent
  draws, duplicate delivery, mute at either boundary, interrupted loads, timeouts,
  SIM exit, bad source addresses/hash/order and real voice-stream activation.

The timing proof is against the paired original source framebuffer delivered to
Godot. Monitor/compositor and audio-device latency have not been measured. Human
performance/mix approval and complete original dialogue coverage remain open.
No new external calls, recordings, publication or push occurred.

```sh
python3 tools/verify_pc_readiness.py \
  --trace artifacts/pc-readiness-trace-01/report.json \
  --baseline artifacts/pc-audio-baseline-03/report.json \
  --output artifacts/pc-readiness-comparison-02.json
./tools/godot.sh --script res://tests/test_pc_audio_bridge.gd -- \
  --output "$PWD/artifacts/pc-readiness-native-03"
```


## Fully displayed original crew messages, 2026-09-27

Original message assignment and visible text drawing are separate boundaries.
A read-only native event 28 observes the completed setters at main CS:3d0c,
3d6a, 3d8e, 3db0 and 3dd2. Its payload is the same twelve-register snapshot and
640 KiB conventional RAM used by the existing text observer. Original near-call
code, registers, RAM and timing remain unchanged. Local disassembly is retained
as `artifacts/pc-message-original-disassembly-01.txt`.

Main DS:094c holds the crew prefix pointer, 646a the optional suffix pointer,
and 6464 the portrait index. Every assignment receives a new identity, including
repeated identical reports. Each subsequently verified text draw can bind only
to the exact current pointer, bytes, portrait and part of that assignment.
The frozen scanout candidates retain that identity. A public `messages` item
requires every part in one presented frame, matching page, style, portrait and
adjacent source rectangles. Queued words alone never appear in the public packet.
Working if: different assignments cannot combine prefix/suffix parts, and hidden
queued text never produces a presentation message or voice.

`CrewBarks` consumes each newly displayed crew identity once per SIM epoch.
Only portrait 3, exact catalogue text, and source assignment 3d6a (hit bearing)
or 3dd2 (damage) qualify. The derived `crew_visible` event carries the identity,
original IP, caption, and each part's original rectangle, draw sequence, pointer
and pixel hash. Numeric captions stay original. New text replaces any playing
voice; no spoken backlog is queued. Muted appearances are consumed silently,
old page contents never replay, and the existing six-frame delivery freshness,
original sound gate and program-epoch safeguards still apply. Godot validates
the complete schema-3 envelope before playback, including the voice/caption
catalogue and both visible source parts.

Fourteen dry Gemini 3.8 Flash TTS masters are installed in the opt-in audio pilot:
five observed bearings (043, 041, 137, 140, 040) and nine system-damage reports.
Orus is an authored casting choice for original portrait index 3; the character's
named role has not been recovered. Full performances speak each bearing digit,
including zeroes. `pc_crew_provenance.json` retains WAV hashes, scripts, model,
voice, duration and automated QA evidence. Human listening/mix approval remains
open. Details are in [the voice workflow](voice-workflow.md).

### Evidence and limits

* `pc-crew-comparison-01.json`: all 14 checks pass. All 8,576 original RAM, video,
  input and queued-dialogue records equal the untouched source baseline.
  Seventeen assignments produce sixteen fully visible reports and exactly
  sixteen voice events from fourteen distinct clips. The 041 report occurs at
  three different original assignments. Assignment 15, “COAX machine gun
  destroyed”, never completely appears and never speaks.
* `pc-crew-crop-verification-01.json`: all 28 prefix/suffix rectangles from fourteen
  independently saved source PNGs match their runtime RGB hashes. The incoming
  043 source frame was also visually inspected.
* `pc-crew-native-01/report.json`: actual native Godot and original-PC child,
  8,576 frames, sixteen once-only AudioStreamPlayer starts using the fourteen
  generated streams, matching the parity-tested source-frame receipts. Original
  END transition, zero errors, child exit 0. No gameplay audio was recorded.
* `pc-crew-lifecycle-01/report.json`: all eleven lifecycle checks pass, including
  7,267 identical RAM/video/input frames, 52 stage states and program boundaries.
* `validation-20260927T112933Z/results.txt`: all eighteen stages pass, 181 Python
  tests and 150 Godot audio assertions. A subsequent number-classification QA
  test is covered by `pc-crew-python-final-01.log`: all 182 Python tests pass.
* `pc-crew-regression-native-01/report.json`: existing native 1,712-frame
  firing, loader, motor, F5 and pause route passes with 3,426 loop checks, three
  readiness receipts (two audible), zero errors and child exit 0.

The implementing assistant reviewed these changes and reran the actual checks.
The dialogue route's RAM-only mission snapshot is not proof of matching
filesystem-dependent debrief outcomes. The separate neutral-START lifecycle
fixture covers bounded quit/reentry, not all mission outcomes. Radio queue/open
IPs 3c90, 3cd4 and 3f73 are observed by the hook, but this route queued no radio
messages despite ordinary R-key pulses. Live radio speech remains unimplemented.
The text gate omitted 133 calls under its existing colors-or-blank-run rejection;
this evidence does not distinguish those two reasons. Physical audio/display
latency, full bearing coverage and complete dialogue coverage remain open.

The crew-message milestone used core SHA-256:
`9c63ca3140bc5063767da0a5b3e8ec9a6e4a5cd92d18d445b699b39739dbaaee`.
Trace header:
`97798516834b2cfd97f00458f6fbf5743df17e593d569964f15cc3f7ef63a2b8`.
Unmodified source baseline:
`57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.
The subsequent source-verified cockpit strut extension is recorded in
[the cockpit art workflow](pc-ui-art-workflow.md). The expanded live typography
observer's current pins are in [the text research](pc-text-research.md#current-observer-pins-and-reproduction).

```sh
python3 tools/capture_pc_dialogue.py --mode trace \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-crew-trace-new
python3 tools/verify_pc_dialogue.py \
  --trace artifacts/pc-crew-trace-new/report.json \
  --baseline artifacts/pc-dialogue-baseline-01/report.json \
  --output artifacts/pc-crew-comparison-new.json
./tools/godot.sh --script res://tests/test_pc_crew_bridge.gd -- \
  --reference "$PWD/artifacts/pc-crew-trace-new/report.json" \
  --output "$PWD/artifacts/pc-crew-native-new"
```

## Warning/outcome speech extension, 28 September 2026

Eight full-sentence performances now supplement the bearing and damage banks.
Original single-part setter completion 3d8e and two-part 3dd2, portrait indices
0/1/2 and exact catalogue pointer variants are checked in Python and Godot.
The new oracle executes nine caller-selected assignment blocks, without altering
live RAM or skipping original instructions. This proves assignment contents;
trigger eligibility and live occurrence are separate evidence.

The native smoke-exhaustion route covers 1,060 source frames, all byte-identical
to the untouched baseline. It displays three distinct original empty-mortar
assignments: audible, muted, audible. Native Godot starts the two selected dry
streams, consumes the muted assignment, and stays silent for all 98 observed
frames between sound restoration and the fresh warning. All three current
message RGB hashes match and the Genesis cockpit, portrait and scalable type
are active. Receipt `pc-warning-native-02/report.json` records 7,549 checks;
native process and original child exit 0. No gameplay mix was recorded.

Generation uses Gemini 3.8 Flash TTS. The source catalogue now totals 392
message performances. The warning masters, blind wording comparison, narrow
M1/M one recognition-format correction and reproducible source/native checks
are documented in [the voice workflow](voice-workflow.md#source-warnings-and-outcome-calls-28-september-2026).
Other warnings' live occurrences, radio, remaining dialogue, music and listening
acceptance remain open.
