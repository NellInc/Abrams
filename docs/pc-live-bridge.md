# Original PC to Godot bridge research

The original PC executable is the intended gameplay authority. Godot consumes
read-only snapshots and supplies presentation. The authored calibration range
remains separate and is never instantiated by this bridge.

## What runs locally

`PC Bridge.command` opens a native side-by-side research view: the original PC
framebuffer on the left, the original static-world wire survey and an authored calibration vehicle driven by
original position/heading/turret state on the right. Controls are forwarded as keyboard
input to the original executable. Arrow keys map to the manual's numeric keypad.
Use 5 to stop or brake, C for control mode, Space to fire, and F1 through F4 for
stations. Closing the window asks this helper to exit and waits for its exit.
It does not signal the separately running DOSBox-X app.

The diagnostic stage now has original static terrain/structure outlines. Enemy
rendering, original camera/visibility/LOD matching and gameplay collision remain
unimplemented in this view. Its translation scale is explicitly 1:64 for inspection;
original world units and height mapping remain unverified. The current view
starts from a local original-game save state in The Mossel Defense. It does not
yet replace the authored range as the main application.

Working if: input changes originate in the PC executable, the Godot pose and
ammunition readouts follow captured original state, and no provisional range
simulation participates.

## Local dependency and file custody

* Core: DOSBox Pure, downloaded from the official [libretro buildbot](https://buildbot.libretro.com/nightly/apple/osx/arm64/latest/dosbox_pure_libretro.dylib.zip).
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

## Verification receipts

```sh
python3 -m unittest tests.test_pc_bridge -v
python3 tools/verify_pc_bridge.py \
  --state reference/pc-live/mission-entry/reference.state \
  --output artifacts/pc-bridge-replay-NEW
ABRAMS_PYTHON=$(command -v python3) ./tools/godot.sh --headless \
  --script res://tests/test_pc_live_bridge.gd
./PC\ Bridge.command --capture
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

Recover logical update boundaries, original camera transforms, world/actor
geometry and visibility before replacing the original combat view. Calibrate
CPU/input timing against the original reference. Cover all station/weapon modes,
AI, damage and outcomes, then every mission and campaign/save transition.
Finish audiovisual event extraction and restored presentation without changing
simulation decisions. Build/import dependency handling and release permissions
remain open. No proprietary files or this local prototype have been published.

## World bridge extension

State schema 2 supplies signed `position_raw`, continuous `world_position_raw`,
window origin and read-only static/dynamic pools. The ready packet includes
static wire geometry only after the source SHAPE.TBL matches the running game
RAM exactly. Godot keys static instances by WLD entry offset across streaming
slot reuse. `artifacts/pc-world-live-01/report.json` adds a live window rebase and
zero static-placement mismatches to the two 978-frame matching replays.
The detailed original-instruction oracle and boundaries are in
`pc-world-research.md`.
