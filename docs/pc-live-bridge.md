# Original PC to Godot bridge research

The original PC executable is the intended gameplay authority. Godot consumes
read-only snapshots and supplies presentation. The authored calibration range
remains separate and is never instantiated by this bridge.

## What runs locally

`PC Bridge.command` now cold-boots the original game in the pinned source-built
tracing core. `--boot` also selects this explicitly. START owns menus, BRIEF owns
briefings, SIM owns the motor pool and battle, and END owns debriefing. All input
still goes to the original. Mission quit, debrief, return to menus and reentry
have been exercised without restarting the helper.

The native view places the original framebuffer beside scanout-paired Godot
solid geometry, EGA materials, live vehicles and bitmap effects under the
original cockpit/HUD. Menus and briefings retain the entire original framebuffer.
The cockpit and menus remain source-resolution artwork. Add `--wire` for the
wireframe diagnostic. See [UI research](pc-ui-research.md),
[scanout research](pc-render-sync-research.md) and
[surface research](pc-surfaces-research.md) for presentation evidence and limits.

Arrows, numeric keypad, alphabetic keys, digits, F1 through F12, Enter, Escape,
Space, Tab and Backspace retain their original key identities. In particular,
top-row 5 is distinct from keypad 5, so name entry does not become tank braking.
Use keypad 5 to stop/brake, C for control mode, Space to fire, F1 through F4 for
stations, Q for the original mission-quit dialog and Enter to select. Original
up/right and keypad 8/6 produced identical decoded states and framebuffers in a
bounded driver probe. This is not a complete keyboard-layout test.

Closing the window asks only its own helper to exit and waits for its exit. It
does not signal the separately running DOSBox-X app. The authored range remains
separate and is never instantiated by this bridge. Real-time pacing and final
high-resolution presentation remain open.

`--trace` retains the original mission-snapshot probe. `--reference` explicitly
selects the historical nightly/static-wire backend. These are diagnostics.
Their RAM-only snapshots must not be used to establish end-to-end disk-dependent
mission or campaign fidelity; see the filesystem finding below.

Working if: menus, battle and debriefing remain original executable states,
Godot geometry is discarded on program changes, a second SIM entry receives a
fresh rendering epoch, and no authored simulation participates.

## Program lifecycle and protocol 4

`tools/pc_session.py` reads the pinned core's DOS SDA current PSP at physical
`0xb30`, validates its allocated MCB and PSP signature, and reads the MCB program
name. The source basis is `dos_inc.h` (`DOS_SDA_SEG=0xb2`, current PSP offset
`0x10`) and `dos_execute.cpp` (`DOS_UpdatePSPName`). An executable byte search
alone is insufficient: freed SIM code can remain in conventional RAM.

Only active SIM with the correct executable anchors and load address can attach
the read-only drawing observer. Each program transition detaches the native
callback and discards the old collector. Reentry creates a new collector and
increments `render_epoch`. Detach now passes a null callback; a zero load segment
alone stopped instruction hooks but left VGA callbacks installed.

Protocol 4 adds `program`, nullable `state`, `render_epoch` and startup identity.
Program/state are read from the same `last_video_ram` boundary as the submitted
framebuffer. No supported draw or initialized SIM state means full original
framebuffer fallback. Loaded SHAPE.TBL bytes must match the source before a SIM
state can be reported; a mismatch during an observed draw is an error. Original
modal writes remain protected by the scanline UI mask, including the fully
opaque 64,000-pixel Q dialog.

## Filesystem finding and comparison boundary

The old mission snapshot contains SIM for scenario resource 6, but the unchanged
content ZIP contains a SHELL file starting with 1. The source boot's disk overlay
contains SHELL starting with 6. Restoring only RAM into an empty overlay caused
END to summarize Mass Destruction and omit the expected Wilson debrief. Repeating
the same quit inputs with the source snapshot's disk overlay restored the Wilson
debrief (`artifacts/pc-quit-overlay-probe-01`). A snapshot's disk state is part of
its fidelity contract. No original game rule was patched to compensate.

The default cold-boot path keeps the game's own disk writes in the same overlay
through START, BRIEF, SIM and END. Full saved-session packaging must pair RAM and
filesystem snapshots before it is offered as a remaster feature. Historical
within-mission control receipts remain bounded to their documented scope.

Independent cold boots are not byte-identical starting states: the first
comparison differed in all 6,664 RAM records and 85 video records, although all
sampled SIM states matched. The pinned core reads host time in `cmos.cpp`.
No particular byte difference was masked or excused. The definitive comparison
instead restores one neutral START snapshot before user input, with no disk
overlay files, then executes the original menu/mission path on both cores.
This establishes observer non-interference from that shared boundary; it does
not establish historical-machine timing or power-on determinism.

## Local dependency and file custody

* Historical reference core: DOSBox Pure, downloaded from the official [libretro buildbot](https://buildbot.libretro.com/nightly/apple/osx/arm64/latest/dosbox_pure_libretro.dylib.zip).
  The tested ARM64 dylib SHA-256 is
  `f21c70074c8432a634d82e9daa187a9424c629d9d503270a7a663d0751ebc3d8`.
  The host refuses other binaries. The nightly URL can change; it is not a
  reproducible version identifier. Dependency redistribution/build licensing is
  still a release task. [DOSBox Pure source](https://github.com/schellingb/dosbox-pure).
* Local library: `.runtime/pc-core/dosbox_pure_libretro.dylib`.
* Content: `.runtime/pc-core/abrams-ref.zip`, 68 unchanged GAME files plus an
  authored `dosbox.conf`. Its current SHA-256 is
  `c1821239d91a23883a44c4484ca13091479bf0c75347f01b8cb7b3a089565d05`.
* The conf selects EGA, normal 386 core, 16 MB, fixed 3000 cycles, and launches
  `ABRAMS.COM EGA`. These are probe settings, not a calibrated historical PC.
* Game writes go to a separate DOSBox Pure save overlay, never the source GAME
  directory. The bridge does not record mixed audio.
* Startup state: `reference/pc-live/mission-entry/reference.state`, captured after
  the original briefing and motor pool. Its hash is
  `4b579ff364ce73caaef98166f8d1cdfe15a9fca9b5342d34cec7b73bcb2c4700`.
  It and all memory/framebuffer dumps remain ignored local proprietary material.

The input path to that state was NO joystick, original credits, Scenario,
The Mossel Defense, day, novice, Begin, briefing and the motor pool's existing
10 HEAT / 6 SABOT / 18 AX / governor-off loadout. START wrote `SHELL` first byte
6 to the overlay; SIM loaded `snario6`. This verifies that single correspondence,
not every scenario title/index or campaign transition.

## Snapshot and input contract

`tools/pc_reference_core.py` hosts the libretro ABI. Ordinary memory-size/data
calls are unavailable in this core, so it consumes the core's memory descriptors.
The descriptors reorder DOS OS and game RAM; the host verifies contiguous
pointers and reconstructs physical conventional RAM in the correct order.

The emulation thread is running when `retro_run` returns. For this fingerprinted
core, `retro_get_system_av_info` finishes the outstanding VGA frame and leaves
the worker paused. Every RAM read is fenced. The bridge snapshots RAM immediately
before the final `retro_run` in a requested batch, pairing it with that call's
already-completed framebuffer. The core's frame-stepping throttle mode disables
its frontend-rate frame skipping. These details come from inspection of
[the core's threading implementation](https://github.com/schellingb/dosbox-pure/blob/main/dosbox_pure_libretro.cpp).

This is a VGA boundary, not proof of an atomic game-logic tick. Original drawing
can lag updates to simulation variables. The bridge preserves this distinction.
The older research `dump()` files deliberately record *current* RAM, one VGA
frame ahead of their screenshot. Their receipts say so. The live protocol uses
the paired `last_video_ram` instead.

The native framebuffer cache is not restored by the tested state load. One
explicit neutral priming frame is advanced after restore, then the first paired
sample is taken. The live host therefore reports two startup frames after its
restore; the replay test primes once before collecting its first sample.

Keyboard callbacks and keyboard polling must both reflect held keys. The first
probe incorrectly returned zero for every polled key; that was repaired and a
120-poll hold regression test was added. Neutral-key snapshots are the current
restore contract. Restoring a recorded held-key snapshot is rejected.

`tools/pc_bridge_host.py` accepts only bounded `step` commands and `quit` over
inherited stdin/stdout pipes. It exposes no network listener, memory-write
operation, arbitrary file operation or replacement simulation. Core logs use
stderr. Godot uses [nonblocking process pipes](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-execute-with-pipe)
with one request outstanding. Interactive real-time pacing has not been
calibrated against the standalone original; this remains a research view.

## Read-only fields with evidence

`tools/pc_live_state.py` accepts only the fingerprinted supplied SIM.EXE. It
derives three nonrelocated code anchors locally, rejects ambiguous images, and
uses the live load segment plus SIM's `19e0` data-segment offset.

| Field | DS-relative source | Evidence and limit |
|---|---|---|
| Player body pointer | `799b` | Allocated at code `1d36..1d84`; changed movement/heading observed live. |
| Turret pointer | `7999` | Allocated from body at `1d78`; relative rotation observed after C and keypad 6. |
| Local position | signed words at body `+4`, `+6`, `+8` | Schema 2 corrects schema 1's unsigned interpretation. These are streaming-local coordinates. |
| Continuous position | local coordinates plus bytes `886a`, `776c` | Original window origin and shift routines verified. See `pc-world-research.md`; physical units remain unverified. |
| Object pools | `7ace` static / `709e` dynamic | Active allocations and their source shape IDs/positions; allocation does not establish visibility. |
| Hull heading | body byte `+1a` | Original driver/gunner display reads it; stable original heading 100 matched raw 185. |
| Relative turret | turret byte `+0b` | Gunner display `5767..5778` adds it to hull byte before the original bearing conversion. |
| Station | byte `799d` | F1..F4 dispatch at `1e4e..1e66`; gunner and driver verified live. |
| Speed | body signed word `+24` | Driver display `67c7..6801` calculates truncation toward zero of `raw * 100 / 76`; raw 66 matched displayed 86. |
| Fuel display | word `79a2` | Driver display at `6810..6831`, initial 100 matched. Consumption formula is not recovered here. |
| Ammo | signed words `79b4..79ba` | COAX, HEAT, SABOT, AX; initial 80/10/6/18 matches instruments. `3376..33bd` decrements selected main ammo; firing consumed one HEAT. |
| Selected weapon | byte `79a9` | Used to index main ammo at `339b`; 0..2 are HEAT/SABOT/AX, transient 255 is COAX. More selection paths need live coverage. |

The bearing conversion is independently checked against all 256 original CPU
outputs. These fields do not establish damage, visibility, enemy actor semantics,
hit probabilities, ballistics, reload timing, score or campaign fidelity.

## Current lifecycle verification

* `artifacts/pc-lifecycle-baseline-02/report.json` and
  `artifacts/pc-lifecycle-trace-02/report.json`: **7,267 identical full 640 KiB RAM,
  framebuffer and input records**, 52 identical stage states and identical
  program boundaries. Both complete START, BRIEF, SIM, END, START, BRIEF, SIM.
  A fresh second rendering epoch, no SIM state in other programs, zero unsupported
  commands at sampled draws and the fully opaque quit dialog are checked.
* Shared neutral START state SHA-256:
  `874330f12864965bbfdb5a57f52759bc8cadc78e2c90dc0a2dace3a840d09f53`.
  It was captured after 240 startup frames. Both comparison runs then restore it,
  prime one native framebuffer frame and collect their first paired frame.
* `artifacts/pc-session-native-02/report.json`: actual cold boot through Godot's
  process pipe, **52 stages, 3,328,000 exact RGB checks, nine paired worlds**, zero
  failures and helper exit zero. Original menu/modal pixels and world-texture
  samples are checked separately. Captures include the correct Mossel summary
  and the second mission. This does not assert world raster parity.
* `artifacts/pc-lifecycle-*-01` and `artifacts/pc-session-native-01.log` preserve
  the initial failures: the RAM-only fixture skipped Wilson's debrief, so the
  first cold-boot input script lacked a screen-advance and never reentered SIM.
  The corrected fixture includes that original screen; no original flow changed.
* `artifacts/pc-arrow-identity-01/report.json`: up/right versus keypad 8/6 decoded
  state and framebuffer equality; original player movement verified.

Reproduce with new output directories, preserving existing evidence and overlays:

```sh
python3 tools/bootstrap_pc_source.py --boot-only --output artifacts/pc-neutral-boot-NEW
python3 tools/capture_pc_session.py --mode baseline \
  --boot-state artifacts/pc-neutral-boot-NEW/neutral-boot/reference.state \
  --output artifacts/pc-lifecycle-baseline-NEW
python3 tools/capture_pc_session.py --mode trace \
  --boot-state artifacts/pc-neutral-boot-NEW/neutral-boot/reference.state \
  --output artifacts/pc-lifecycle-trace-NEW \
  --compare artifacts/pc-lifecycle-baseline-NEW/report.json
./tools/godot.sh --disable-render-loop --script res://tests/test_pc_session_bridge.gd -- \
  --native --output "$PWD/artifacts/pc-session-native-NEW"
./PC\ Bridge.command
```

## Historical snapshot verification receipts

```sh
python3 -m unittest tests.test_pc_bridge -v
python3 tools/verify_pc_bridge.py \
  --state reference/pc-live/mission-entry/reference.state \
  --output artifacts/pc-bridge-replay-NEW
ABRAMS_PYTHON=$(command -v python3) ./tools/godot.sh --headless \
  --script res://tests/test_pc_live_bridge.gd
./PC\ Bridge.command --reference --capture
```

* `artifacts/pc-bridge-replay-01/report.json`: initial check **failed**, one stale
  first-video mismatch and an incorrect expectation of instantaneous braking.
  RAM matched even at that first frame. The failed artifact is retained.
* `artifacts/pc-bridge-replay-02/report.json`: **978 paired samples per take**, two
  original-executable runs, zero differences in full 640 KiB RAM, framebuffer
  bytes, input sets and decoded fields. All eight movement/station/turn/fire
  assertions passed. It proves this bounded same-core replay, not every mission
  or equivalence to a different emulator/historical machine.
* `artifacts/pc-live-godot/report.json`: native Godot process-pipe integration
  passed movement, stations, braking, turret rotation, HEAT consumption, PNG
  decoding and graceful helper exit with code zero.
* `artifacts/pc-bridge-viewer/paired-view.png`: native side-by-side render. It is
  a diagnostic pose view, not finished terrain or cockpit artwork.

Keypad 5 decelerates the hull, while key release alone retains motion. The manual
explicitly calls 5 Stop; live captures and the replay establish the distinction.
Do not change the original's handling to the authored range's assumptions.

## Remaining critical path

Recover logical update boundaries, remaining opaque drawing commands and exact
integer edge coverage. Bounded solid geometry, dynamic actors, materials, bitmap
effects and cockpit composition already have separate evidence. Calibrate
CPU/input timing against the original reference. Cover all station/weapon modes,
AI, damage and outcomes, then every mission and campaign/save transition.
Finish audiovisual event extraction and restored presentation without changing
simulation decisions. Build/import dependency handling and release permissions
remain open. No proprietary files or this local prototype have been published.

## Historical static world bridge (reference backend)

State schema 2 supplies signed `position_raw`, continuous `world_position_raw`,
window origin and read-only static/dynamic pools. The ready packet includes
static wire geometry only after the source SHAPE.TBL matches the running game
RAM exactly. Godot keys static instances by WLD entry offset across streaming
slot reuse. `artifacts/pc-world-live-01/report.json` adds a live window rebase and
zero static-placement mismatches to the two 978-frame matching replays.
The detailed original-instruction oracle and boundaries are in
`pc-world-research.md`.

Protocol 2 carries primitive-ID geometry dictionaries and per-frame static face
masks, plus the cached original camera. The reference backend retains this version; the tandem backend uses protocol 4.
