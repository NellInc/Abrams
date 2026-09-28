# Live presentation pacing

## Playability follow-up, 28 September 2026

Profiling found repeated full-font decoding in `loaded_font`. Decoding now uses
an eight-entry immutable exact-byte cache, after every observation verifies the
complete loaded font against the supplied catalog. Caller-visible dictionaries
are separate, and shared glyph bytes are immutable. Changed font bytes, catalog
identity or bounds still reject the observation. Full-frame mask range checks
use equivalent byte-translation predicates instead of Python element iteration.

The host also retains exactly one encoded original framebuffer. Reuse requires
equal complete framebuffer bytes, width, height and pitch. It does not cache
state, text, drawing metadata, audio, event identities or the program lifecycle.
Current per-frame checks, synchronization, CPU settings and input cadence remain.

`artifacts/pc-playability-01/observer-parity/final-verification.json` compares
601 complete audit-enabled host packets before and after these changes. The
entire JSON stream is byte-identical, including every paired RAM/video hash,
PNG, audio event and presentation field. Instrumented observer-only execution
before PNG caching took 6.43 seconds before and 4.66 after; these durations are
diagnostic throughput, not live-game speed claims.

Native default-audio probes measured 23.68 fps initially, 53.41 with font caching,
48.10 with bulk mask checks, and 59.03 in the final 1,200-frame stationary run
with PNG caching. The original core advertised 59.47 fps. Machine load varied,
so these results do not isolate the causal improvement from each optimization.
The final receipt is `artifacts/pc-play-final-pacing-01/pacing.json`; its mean
interval was 16.94 ms. Sustained moving-gameplay and historical-speed calibration
remain distinct acceptance requirements.

## Exact instrument-region checks, 28 September 2026

The instrument layer now checks static icon rectangles and gauge surrounds with
native byte operations for RGB8/RGBA8 source images and L8 ownership masks. Every
current pixel remains part of the predicate. RGB and RGBA are compared with exact
opaque-alpha expansion when needed; alpha differences still reject. Other image
formats retain the prior per-pixel comparison. Coloured ownership masks retain
red-channel semantics, rather than being converted to luminance. Guard rectangles
are split around their dynamic interiors, including the driver's separate lamp
guard. Dynamic gauge values, orientation geometry and all rendering are unchanged.
No cached validity result, palette tolerance, approximate matching or omitted
source region was introduced.

Working if: changing any icon RGB/alpha byte, UI ownership bit or plate tag
rejects that cell, all guard pixels are tested exactly once, and matching source
traces produce identical presentation metadata and native pixels.

`pc-pacing-cache-work-01/comparison.json` compares the native before/after route:
all 1,020 complete packet hashes (including paired RAM/video audits), original
requests, final capture metadata and all four decoded images match exactly.
The measured repeated instrument predicate fell from 4.83 to 1.96 ms; overall
frame rate was 20.04 then 30.17 fps. These are different-time runs on a loaded
machine, so they do not isolate a causal whole-game speedup or prove target-rate
acceptance. Unrelated processes were left untouched.

`test_pc_gauges.gd` additionally checks every pixel in all nine icon regions,
every mask byte value, RGB/RGBA/float-format comparisons, alpha differences, and
all guard complements against a separate pixel-loop definition. The focused run
passes 14,003 checks. An initial test-only image type-inference error was repaired;
its failed log is retained, superseded by `gauges-02.log`.

Final verification: `validation-20260928T103922Z` passes all 41 stages and
286 Python tests, including the 14,003 gauge checks. The separate retained
original-instruction gauge oracle passes 14,939 checks. Native scenario replay
`pc-instrument-regions-stations-01` passes 161 checks across all 32 station/scenario
cases; every case's metadata and all 39,321,600 rendered pixels match the previous
reference. Original files remain unchanged.

The existing native profiler now supports up to 20 repetitions of its original
1,020-frame control route (`--replay-cycles`, requiring `--replay-controls`). Each
request still advances one original frame. Its bounded timeout scales with the
requested diagnostic length; normal Play timing and limits are unchanged. Rows
record the original program and audio failure state so a long run ending in a
menu cannot silently masquerade as sustained combat.

The longer native run `pc-pacing-sustained-01/verification.json` completed 6,120
consecutive interactive frames over 134.84 seconds, all inside SIM, with healthy
remastered audio and no rejected vehicle textures. Every one-frame request
matches the six-cycle control script. Its first 1,020 complete packets equal the
before/after route above; the remaining 5,100 paired RAM/video audits are recorded
without a second original execution, so full longer-route parity is unproven.
Measured rate was **45.39 fps against 59.47 advertised**, with six segment rates
46.33, 51.76, 52.96, 51.14, 44.71 and 32.80. This demonstrates longer-session
stability, and also demonstrates that sustained target-rate acceptance is still
**failing on this loaded host**. No catch-up, dropped source frame, batched live
input or changed emulated CPU rate was used to conceal that result.

```sh
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner --interactive-clock \
  --replay-controls --replay-cycles 6 --frame-audit \
  --output "$PWD/artifacts/pacing-sustained-NEW"
```

## Follow-up: overlap original dispatch and presentation

The production viewer now dispatches the next clock-eligible original frame
after the received packet passes the existing audio, required-state and PNG
checks, before constructing its Godot presentation. The complete received packet
owns its bytes, so advancing the child cannot change the picture being built.
There is still one outstanding request, one original frame per interactive
request, current held-key sampling, and no catch-up queue. Scene construction
stays on Godot's main thread. Explicit capture batches retain their old ordering.

Working if: a valid interactive response dispatches before scene construction,
invalid source/audio/image packets cannot dispatch, capture ends without an extra
frame, and changing held keys cannot alter an already outstanding request.

`test_pc_live_scheduling.gd` exercises the actual production loop with a local
transport fixture and Godot input events. It covers key holds/releases, keypad
versus top-row identities, early ordering, pending/closing/error gates, clock
phase and exact diagnostic batch boundaries. Its optional `--invalid-png` case
deliberately produces libpng/engine corruption diagnostics, then verifies no
request was sent. This negative case runs separately from the aggregate's
no-engine-errors gate. Ordinary capture timeouts remain 60 seconds for a restored
mission and 180 seconds for cold boot. The profiler has its own bounded deadline, at least 90 seconds including final
capture, scaled for sustained diagnostics as described above.

The opt-in `--frame-audit` diagnostic fingerprints **already paired** conventional
RAM and native framebuffer bytes. It performs no extra guest read, fence or step,
and emits only hashes and dimensions in the local pipe. Normal Play does not pay
this hashing cost. The protocol's existing fields and original core are unchanged.

### Evidence and timing limits

* `artifacts/pc-transport-profile-01/full-boundary-parity.json`: all 1,020 original
  one-frame requests match the control fixture through the real Godot keyboard
  path. Every complete packet hash and every paired 640 KiB conventional-RAM and
  320x200 framebuffer hash matches between previous and early dispatch policies.
  That covers 668,467,200 RAM bytes and 261,120,000 framebuffer bytes. Movement,
  braking, turret control, firing, smoke and all four station key routes are
  exercised. Final native images and all recorded audio receipts/loop transitions
  match too. No packet fields or memory regions were excluded.
* `artifacts/pc-transport-profile-01/controls-parity.json` records a second,
  non-audited 1,020-frame A/B comparison with identical complete packets, requests,
  final metadata and native images. Both runs include remastered audio, with
  cannon/on-the-way, loaded and smoke cues, plus engine/turret loop transitions.
  This is bounded replay parity, not full campaign or historical timing parity.
* That non-audited control run measured **44.33 fps late / 55.29 fps early**.
  The later audit-enabled comparison measured **51.04 late / 46.19 early**, the
  opposite ordering. System contention and instrumentation affect these runs;
  a general performance improvement is not established by them. Neither result
  is discarded. The change removes a mandatory serialized presentation wait;
  sustained target-rate acceptance remains open.
* Final 1,200-frame stationary interactive probes without audit instrumentation
  measured **57.21 fps gunner** and **59.91 fps driver**. These are local,
  roughly twenty-second measurements, not a sustained-rate guarantee.
* The initial instrumented gunner run failed with `PC_VIEW_FAILED: capture
  deadline` at 19.08 fps. An uninstrumented control measured 19.04 fps, with
  sample application above 14 ms versus roughly 5 ms in the earlier run.
  The machine load average was 15.85. Unrelated processes were left alone.
  All transport probes recorded zero partial JSON prefixes, so packet splitting
  was not supported as the cause of these measured delays.
* `artifacts/validation-20260928T040422Z`: the final aggregate exits 0, all 36
  stages and 247 Python tests pass. Production-loop scheduling contributes 54
  checks. Its separately invoked corrupt-PNG case passes 55 checks and reports
  the expected PNG decoder diagnostics without dispatching a new original frame.
* `artifacts/pc-transport-profile-01/public-matched-parity.json`: actual public
  Play and cold-boot joystick captures match earlier complete capture metadata
  and all four PNGs. The first gunner comparison wrongly used a 1440x900 window
  against a 1440x810 reference and failed; matching the actual reference size
  resolves that test setup error without changing production code.

Reproduce the controlled A/B run with fresh output directories:

```sh
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner --interactive-clock \
  --replay-controls --audio --frame-audit --late-dispatch \
  --output "$PWD/artifacts/control-late-NEW"
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner --interactive-clock \
  --replay-controls --audio --frame-audit \
  --output "$PWD/artifacts/control-overlap-NEW"
```

Compare `sample_hashes` and `requests` in the two `pacing.json` files, require
exactly 1,020 consecutive frames and the expanded keys from
`godot/tests/fixtures/pc_play_control_steps.json`, and compare the complete
`capture.json` plus all four captured PNGs. The source audit records must each
contain 655,360 RAM bytes and 256,000 native-video bytes. Packet hashing is over
Godot's sorted JSON representation; source RAM/video hashes are over raw bytes.
`--late-dispatch` is a profiler-only A/B option, not an alternative gameplay mode.

## Scope and measured result

The following measurements describe the preceding byte-optimization pass. See
the follow-up above for the newer dispatch ordering and its mixed timing results.

The original PC executable still advances one requested VGA frame at a time.
Godot forwards the current original keys with one pipe request outstanding.
This pass reduces read-only observer and presentation overhead, and repairs the
fractional clock phase. It changes no core binary, guest instruction, source
artwork, emulated CPU setting or input batching policy.

On this local M1 Max, Godot 4.7.2 compatibility renderer, native Play at 1280x960:

| Probe | Before | After | Interpretation |
|---|---:|---:|---|
| Gunner, 120 unpaced single-frame requests | 29.55 fps | 55.78 fps | Same original final state, metadata and every captured image byte |
| Gunner sample application | 15.73 ms | 5.49 ms | Average CPU time inside the production viewer's sample handler |
| Repeated gunner plate predicate | 7.47 ms | 0.18 ms | 30 calls on the same recorded frame |
| Repeated driver assembly predicate | 15.62 ms | 0.46 ms | 30 calls; driver baseline was the intermediate phase-corrected build |

An earlier separate gunner probe measured 27.80 fps. These short probes establish
the observed bottlenecks, not an invariant hardware speedup. Host scheduling and
machine load vary. The benchmarks ran serially, separately from heavy tests.

The final **actual interactive clock** probes each advanced 1,200 frames after
the original station-entry route:

| Station | Effective original frames/second | Mean sample application |
|---|---:|---:|
| Gunner | 54.23 | 5.39 ms |
| Driver | 58.57 | 3.72 ms |
| Commander | 59.10 | 4.83 ms |
| Cupola | 59.98 | 2.73 ms |

The core advertises 59.9227256774902 Hz. Gunner remains below that rate. These are
roughly twenty-second stationary measurements, without optional remastered audio,
and do not establish sustained combat performance, historical-machine speed,
wall-clock input parity or performance on other hardware. The intermediate
phase-only 1,200-frame gunner run measured 47.19 fps and is retained too. A
two-second driver run slightly above 60 fps is not used as sustained-rate proof.

## Exact optimization boundaries

* `tools/pc_pixel_bytes.py` replaces per-pixel Python RGB loops with row slices,
  channel lookup tables and native byte operations. Every original pixel is
  still compared exactly. There is no colour tolerance or omitted region.
* `Collector.mask_png` retains the last immutable raw/PNG byte pair for each of
  three mask kinds. Current slot, dimensions, binary values and UI ownership are
  checked before encoding can be reused. The cache holds at most three entries.
* Godot retains one successful plate-tags/UI pair and one successful moving-roof/
  UI pair. Exact decoded byte equality reuses only the ownership predicate.
  Current source hashes, palette, dimensions and artwork availability are still
  checked; live instruments and text still receive the current framebuffer.
  Invalid packets clear active art as before. Mutable caller images cannot alter
  the retained byte snapshots.
* UI-mask binary validation uses native byte counts instead of an interpreted
  64,000-element loop, preserving rejection of every nonbinary value.

Working if: corruption after a cache hit disables the affected layer, missing
artwork cannot be resurrected by a cache, and identical original traces produce
identical metadata and native rendered images.

The interactive clock formerly reset its accumulator to zero after a request.
At a steady 60 Hz redraw, this services a 59.92 Hz source only every other draw.
`frame_remainder` retains the fractional interval instead. Whole missed intervals
are still discarded. It neither creates catch-up batches nor backdates newly
sampled keys. Under overload the original therefore still runs slower than its
advertised wall-clock rate. That remaining limitation is explicit.

Working if: the deterministic 60-second 60 Hz fixture emits 3,595 requests rather
than the old 1,800, the phase stays bounded, and a stall creates no queued burst.

## Verification and retained local evidence

* `artifacts/pc-pacing-profile-01/before-after-parity.json`: the entire new
  1,458-frame reticle trace report is byte-identical to the pre-change report,
  SHA-256 `6ae268644aa82eb11d95cd30142cf7c0ff5c9d21dbc16268f21c55fb1e35b3e1`.
  All 76 saved PNG files match too. This includes text, orientation, reticle,
  source RAM/video/input hashes, masks, render passes and rejection counts.
  No fields were excluded. All 337 observed reticle draws complete; 1,207 visible
  candidates match and 246 stale/overwritten candidates remain rejected.
* `artifacts/pc-pacing-profile-01/source-parity.json`: all 20 independent baseline
  and visible-source-crop checks pass on the new trace.
* The same before/after receipt compares complete native gunner and driver
  capture JSON plus original, world, tandem and window PNG bytes. All match.
  Component profiling re-applies the final message once without advancing the
  guest; both sides use that same diagnostic sequence.
* `artifacts/pc-pacing-profile-final-01/host-report.json`: 147 paired baseline/
  tracing-core RAM, video and input records match. Mean traced step time fell
  from 10.05 to 6.31 ms across the retained initial and final probes. Observer
  method timing is diagnostic instrumentation in an isolated host process.
* Warm-cache corruption and lifecycle regressions pass. Native synthetic
  gunner and multi-station/moving-roof fixtures compare 1,024,000 and 4,096,000
  pixels respectively, with all nonpixel assertions passing as well.
* `artifacts/pc-pacing-genesis-native-01/report.json`: the recorded Genesis
  cockpit/instrument/text regression passes 12,238,012 checks. Source masks and
  current state continue to control every remastered cell.
* Actual public Play cold-boots the joystick menu with its refined text;
  `artifacts/pc-pacing-profile-01/menu-parity.json` records identical complete
  capture metadata and original, tandem and native-window image bytes.
* `artifacts/validation-20260928T034057Z`: terminal exit 0, all 35 stages pass,
  including 246 Python tests, 49,159 clock assertions and source preservation.

The implementing assistant inspected the actual gunner capture. This is
self-review of work produced with the assistant's input, not Nell's art approval.
The repaired frame joins and ammunition proportions remain intact. This pass adds
no visual styling; optional Impeccable was not needed or installed.

## Reproduce

Use a fresh output directory for each run. Do not run competing heavy tests while
collecting timing. Performance output is diagnostic and has no artificial
pass threshold.

```sh
./tools/godot.sh --script res://tests/profile_pc_play.gd -- \
  --play --trace --capture --capture-station gunner \
  --interactive-clock --profile-frames 1200 --output "$PWD/artifacts/pacing-new"
./tools/validate.sh
```

Supported stations are gunner, driver, commander and cupola. Omit
`--interactive-clock` for unpaced sequential throughput, and add `--components`
for repeated CPU component measurements on the last frame. Neither mode is a
standalone-original wall-clock calibration. Interactive mode polls the actual
keyboard; input during a run must be considered when comparing its final state.

Remaining pacing work: isolate host-ready versus Godot-poll/render latency under
controlled machine load, test sustained combat and audio beyond the bounded
replay above, then calibrate against the standalone pinned original. No catch-up
policy or broader timing parity is implied by these optimizations.

The current matched 1,020-frame moving/station/firing replay is
`artifacts/pc-play-final-controls-02/verification.json`: every original key input
and paired RAM/video hash equals the retained reference, 57.93 effective fps
against 59.47 advertised. Diagnostic chunking shifted request IDs by eight,
so whole-packet hashes across those differently chunked runs are not compared.
The separate 601-packet cache gate above compares complete packet bytes.
An initial comparison used different warmup routes and correctly failed; it is
retained at `pc-play-final-controls-01/verification.json` with the setup diagnosis.
