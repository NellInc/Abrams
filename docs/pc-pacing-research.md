# Live presentation pacing

## Fidelity-preserving bridge pass, 30 September 2026

The host now retains at most 128 exact expected text-colour proofs. Each use
still compares every current framebuffer RGB bit in the source rectangle.
Palette, glyph pixels, ink mask, foreground and rectangle are part of the key.
Current text/event metadata is returned freshly. Native BGRX padding keeps its
previous meaning. The compiled rectangle proof removes repeated row arithmetic
and RGB deinterleaving without approximating colours or caching a past match.

Loaded cockpit bitmap decoding now expands the four independent EGA planes
with bounded byte tables and bulk integer operations. The explicit opacity
plane, mask polarity, descriptor/layout rejection and flags are unchanged.
Source font validation, original execution, input cadence, one-frame requests,
resolution, models, materials, shaders, 4x MSAA and 16x anisotropy are unchanged.

The identical 1,020-frame diagnostic route made 6,021,796 Python calls before
and 3,594,141 after, a 40.3% reduction. Alternating scalar/bulk microbenchmarks
on all seven original cockpit struts measured 11.1x to 36.5x faster bitmap
verification. These are CPU-work measurements, not whole-game FPS gains.
A whole-frame Pillow decode/crop experiment was exact but slower and discarded.

### Native audit-enabled probes

Apple M1 Max, Godot 4.7.2 Compatibility, 1280x960 display. The real viewer's
interactive loop was exercised with profiling, complete-packet hashing and
frame audits enabled. Those diagnostics add work compared with ordinary Play.
Other apps, a VM and independent build jobs remained active. No processes were
interrupted to improve these results.

| Run | Source frames | Source-frame cadence | Mean interval | p95 | p99 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Moving baseline A1 | 1,020 | 25.37 fps | 39.42 ms | 86.63 ms | 97.99 ms |
| Moving candidate B1 | 1,020 | 21.80 fps | 45.87 ms | 104.67 ms | 153.74 ms |
| Moving baseline A2 | 1,020 | 24.64 fps | 40.59 ms | 84.37 ms | 109.06 ms |
| Stationary baseline | 240 | 28.32 fps | 35.31 ms | 67.93 ms | 104.35 ms |
| Stationary candidate | 240 | 31.43 fps | 31.82 ms | 63.94 ms | 83.69 ms |

The second moving candidate lost focus: only 99/1,020 samples were focused,
with 87 input mismatches. Its receipt is retained and excluded. The intended
ABBA comparison is incomplete. Stationary cadence improved in this probe;
the valid moving candidate was slower. A general FPS improvement and sustained
60fps are **not established**. These timings also cannot establish ordinary
Play performance or historical CPU-speed calibration. Further native timing
needs an uninterrupted foreground window and a quiet, scheduled machine.

### Exactness and validation

- All 1,020 complete host-route packets, RAM/video hashes and original inputs
  equal the preceding implementation.
- The three valid native moving runs have identical complete packets, one-frame
  requests, final capture metadata and all four final decoded images.
- The stationary pair has identical requests, final capture metadata and four
  final decoded images; per-frame stationary packet hashes were not collected.
- All 663 staged Godot files equal the current files, including assets/shaders.
- 57 focused observer tests pass. Locked-source Python aggregate: 557 tests,
  one skip. Source-only package contract: 91 tests, three skips, no originals.
- Native PlayDisplay: 739 checks and 11,521,118 pixel comparisons. Native Modern:
  159,107 checks. Both pass.

Evidence: `artifacts/performance-20260930/host-final-parity.json`,
`native-comparison.json`, `native-handback.json` and the retained logs.
Exactly eight serial native launches exited naturally within the admitted
25-minute slot; no Blender launch or process signal was used. The source changes
are verified locally. Release binaries have not been rebuilt for this pass.

Self-review: this pass was authored and verified in this chat.

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

## Exact expected-glyph reuse, 28 September 2026

Typography now retains up to 64 expected bitmap runs, keyed by exact font ID,
text, foreground and background RGBA values, and guarded by a complete copy of
the actual font bytes. This is expected-pattern reuse only: current source RGBA
bytes, every current UI ownership byte, current RGB hash and current metadata
are still checked on each draw. Every returned run carries the current event's
draw sequence and resources. Font reloads clear the cache, including failed loads.
Cursor exclusions and non-RGB8/RGBA8 source or non-L8 mask formats use the unchanged
pixel-loop path. Transparent bearing text and authored outline contours are
unchanged.

Working if: warm expected bytes never authorize changed source pixels, alpha,
ownership, font bytes, hash or event identity; cache size stays at most 64; cursor
coverage keeps its original semantics; complete source traces and rendered pixels
remain equal to the preceding implementation.

`pc_typography_pixel_oracle.gd` freezes the prior `verified_run` implementation
from commit `1bc962e` for direct comparison. Focused cases cover all printable
glyphs of all four fonts, every pixel of a representative warm text run, source
format/alpha changes, cursor-covered glyphs, actual font mutation, repeated event
identities, eviction and current colour pairs. Alternating in-process timing of
500 calls per implementation in six rounds recorded about 14 microseconds for
the new verifier and 116 microseconds for the old loop. This is predicate cost,
not a whole-game performance claim.

The native 1,020-frame control route `pc-typography-pacing-native-01/comparison.json`
compares with `pc-pacing-cache-after-01`: every complete packet hash, original
request, final metadata and all four decoded images match. It measured 59.61 fps
against the final advertised 59.47, with typography component time 0.66 ms versus
3.36 ms in the preceding run. Other components also ran faster, so changed host
load contributes to this different-time comparison. Sustained/historical pacing
needs its own evidence, independent of this short probe.

The subsequent six-cycle run `pc-typography-sustained-01/comparison.json` completed
6,120 consecutive SIM frames in 103.38 seconds at **59.20 fps against 59.47
advertised**. Its six segment rates span 58.89 to 59.54 fps. Every complete packet
hash, one-frame request, final capture metadata and all four decoded images equal
`pc-pacing-sustained-01`, extending the exact before/after comparison to the full
longer route. Audio stays healthy. This is a near-target local sustained probe,
not proof of long campaigns, historical-machine pacing, other hardware or
performance under arbitrary load. The earlier 45.39-fps result remains retained;
host load was not controlled across the two runs.

Final gates: `validation-20260928T104953Z` passes 41 stages and 286 Python tests,
including 185,967 typography checks. Native station replay retains all
39,321,600 pixels across 32 cases. Native menu replay passes 46,080,268 checks;
its complete report and 45 images (46,080,000 pixels) are identical to the
frozen previous verifier running with current assets. See
`pc-typography-menus-01/oracle-comparison.json`. The first comparison used an
older menu receipt predating the corrected R/terminal font pass; that failed
historical comparison is retained and is not used as immediate regression proof.
The diagnostic `--pixel-oracle` mode changes only the test's verifier nodes.

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

## Exact geometry and cockpit-proof reuse, 29 September 2026

The Modern mapper now compiles unique source positions and attributed corners
per validated catalogue face. Each call still validates the original anchors,
recomputes its transform and retains separate material, UV and motion seams.
Fully near-visible triangles share their projected corners while using the
same native triangulator. Near crossings keep the previous clipping path.
No model, texture, shader, resolution, visibility or source timing was reduced.

Cockpit plate and driver assembly masks now reuse successful exact row proofs.
Changed rows remain fully checked. Native byte counts cover uniform ranges;
commander housing checks and the cockpit outline's tag-range test use the same
exact predicates. Failed provenance cannot authorize a new frame.

A clean 1,020-frame, four-station native route measured 38.77 original replies
per second before and 40.12 after on this loaded M1 Max. Display p99 fell from
63.73 to 50.17 ms. Fresh mesh construction averaged 19.18 then 15.02 ms; mapping
averaged 12.63 then 8.64 ms. These different-time runs establish a local measured
improvement, not a guaranteed speedup on other hardware. **Consistent 60 fps is
not achieved.** Modern remains experimental.

All 1,020 requested input steps, station/position/draw-sequence observations and
four final decoded output images match. Cold boots produce different start-RAM
hashes, so this is not complete packet-byte parity. All 32 scenario/station
renders also match the preceding alpha's 39,321,600 pixels exactly. Receipts:
`artifacts/performance-60fps-20260929/baseline-clean`, `optimized-clean` and
`scenario-final/pixel-equivalence.json`. The earlier 55.70-fps run contained
unrequested native keypresses and is excluded. The profiler now requires every
request to match the intended replay before declaring a complete route.

Working if: numerical oracles remain byte-identical, mask mutations invalidate
the appropriate proof, native output remains unchanged and contaminated input
routes cannot pass the benchmark's acceptance flag.

## Further mapper refinement, 29 September 2026

The mapper now precomputes immutable face-basis coefficients in float64 and
retains one exact transformed-position result per validated catalogue face.
Anchors, primitive identity, palette acceptance and transformation inputs are
checked before reuse. Motion, UVs, clipping and the original source execution
remain live. Catalogue reloads reset the bounded cache.

The retained numerical oracle passes 68,150 checks across 482,759 facets;
32 production-viewer scenario/station replays preserve all 39,321,600 pixels.
Receipts: `artifacts/finish-all-20260929/mapping-coefficients.log` and
`scenario-frames/pixel-equivalence.json`. The corpus timings are mapper
microbenchmarks, not a new gameplay FPS measurement.

Fresh native rate attempts could not acquire the benchmark's required focus
and ended at their deadline. They supply no accepted new FPS result. The last
accepted moving-route result remains 40.12 fps; consistent 60 fps remains open.
