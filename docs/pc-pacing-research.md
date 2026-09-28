# Live presentation pacing

## Scope and measured result

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

Remaining pacing work: instrument pipe-ready versus Godot-poll latency and the
native rendering schedule, test combat and remastered audio over longer runs,
then calibrate against the standalone pinned original. A transport/scheduling
change must preserve original key identity and sampling evidence. No catch-up
policy or broader timing parity is implied by this optimization.
