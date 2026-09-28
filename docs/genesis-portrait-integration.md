# Genesis crew portraits in the PC tandem

## Visual and gameplay authority

The four selected 1254x1254 illustrations in
`local-art/genesis/remastered/crew-v1/` come from the Genesis crew-information
portraits. They are now connected to eligible original PC crew messages.
The PC executable still decides the speaker, message, location and duration.

The PC FACES resource is used only as an identity/visibility verification
sample. It is not a visual donor. `tools/extract_pc_portraits.py` verifies all
10,696 decoded pixels and preservation-mask bits against the original loaded
four-plane data before writing the ignored `local-art/pc-portraits-v1/` catalog.
The original FACES hash, extracted catalog and all four Genesis derivatives are
pinned by the renderer. No guest memory or executable is changed.

## Binding and fallback

`pc_portrait_art.gd` checks all four identities at the original gunner-popup
position `(37,59)`. SIM's instructions at `3ee1..3f03` draw the current FACES
entry there before the caption call at `3f18`. The pinned original instruction
span is covered by `tests/test_pc_portraits.py`.

Every opaque pixel must match the presented framebuffer and original
UI-ownership mask. A partial face, overwritten pixel, missing ownership or
ambiguous identity retains the original. Missing assets also retain the
original. Text hints, queued speaker state and previous frames cannot grant
visibility, move the face or delay an otherwise complete match.

The Genesis face is linearly sampled inside the original 49-pixel-wide opaque
extent. Original transparency is preserved at its source-pixel boundary.
This leaves coarse silhouette edges, but cannot cover scenery or text that the
original portrait did not cover. No transparent pixel, hidden character or
hidden message is reconstructed. A separate CanvasItem shader avoids adding
another sampler to the cockpit compositor. Menu and invalid-frame fallbacks
clear the portrait immediately.

Working if: a displayed derivative appears on the first complete source
identity/ownership match, clears when that match disappears, and every output
pixel outside the original face coverage is unchanged by the portrait layer.

All four identities pass synthetic source-frame tests. The real gunner message
has been captured through the native live bridge, and a recorded original loader
hit report passes the native portrait renderer. This is bounded acceptance;
live commander coverage, injury/talking variants and briefing
portrait coverage remain outside this crew-popup proof.

## Driver first-frame repair (28 September 2026)

The earlier caption-dependent binding visibly delayed the driver replacement.
The original Escort route draws the complete driver face at frame 3583, while
the primary caption first qualifies at frame 3601. Waiting for the caption
therefore left 18 original frames showing the old face. All 2,243 opaque driver
pixels already matched, with full UI ownership, throughout that interval.

The renderer now uses the source-defined face position directly. It retains
complete pixel/ownership verification on every frame, without a timer, guessed
speaker, extra overlay area or changes to the original executable. Caption and
speech timing remain independently governed by their existing source checks.
The original clears the face at frame 3690; the remaster clears with it.

The onset and entire 146-frame transition window are retained in
`artifacts/pc-portrait-lifecycle-trace-01/`. `source-comparison.json` verifies all
3,716 RAM/video/input/queued-state records against the unmodified baseline.
`portrait-analysis.json` records a separate Python pixel comparison using the
original catalogue. The old renderer's native captures in
`artifacts/pc-portrait-onset-before-01/` show no replacement at 3583 or 3600,
followed by the replacement at 3601.

* `artifacts/pc-portrait-lifecycle-native-01/report.json`: all 146 consecutive
  original frames plus four synthetic identities render with zero errors,
  149,625,683 checks and terminal exit 0. The independent donor/filter and
  outside-coverage pixel checks remain enabled throughout.
* `artifacts/pc-portrait-live-01/report.json`: the actual production viewer and
  source host pass 26,440 checks over all 3,716 original frames, including every
  onset/display/erasure frame, with zero errors and terminal exit 0. Original
  RAM, video and audio events match the parity-tested route. Native screenshots
  at frames 3583, 3601 and 3690 were inspected.
* `artifacts/validation-20260928T122401Z/results.txt`: all 42 aggregate stages
  pass, including 299 Python tests and 55 portrait lifecycle checks. The optional
  offline Impeccable invocation exited 0 with no output; it establishes no
  GDScript-specific lint coverage.

## Evidence

This implementation and its visual review were performed by the same assistant.
These are machine checks and author review, not independent human acceptance.

* `artifacts/pc-portrait-extraction-01.json`: four unique original plane blocks
  and their exact preservation masks.
* `artifacts/pc-portrait-native-01/report.json`: four synthetic identities and
  35 recorded original frames; 39,757,118 checks, zero errors, terminal exit 0.
  Donor/filter probes compare against independently sampled Genesis pixels;
  every protected output pixel is checked byte-for-byte. One real gunner frame
  is eligible; all other recorded frames retain their original portraits.
* `artifacts/pc-portrait-loader-native-01/report.json`: four synthetic identities
  and two paired original dialogue samples; 5,965,113 checks, zero errors, terminal
  exit 0. The original loader hit report visibly selects the Genesis loader.
* `artifacts/pc-portrait-loader-trace-comparison-01.json`: all 2,500 per-frame
  RAM/video/program/input records match the existing same-core dialogue trace.
  The new capture option only records paired UI evidence.
* `artifacts/pc-genesis-cockpits-portrait-regression-01/report.json`: all 21
  recorded cockpit/status samples plus the damage overwrite test still pass,
  11,944,300 checks, zero errors and terminal exit 0.
* `artifacts/pc-genesis-crew-live-02/`: actual live Genesis gunner portrait,
  four-station art pack, nine illustrated instrument cells and scalable text.
  Native capture inspected; terminal exit 0 in the sibling log.
* `artifacts/pc-genesis-crew-original-01/`: same original input sequence with
  `--original-art`, terminal exit 0.
* `artifacts/pc-genesis-crew-presentation-comparison-01.json`: the complete
  original state, program, presentation packet and original framebuffer are
  identical in those two runs. The remastered composite differs as intended.
* `artifacts/validation-20260927T180807Z/results.txt`: all 24 aggregate stages
  pass, including 200 Python tests and 37 portrait lifecycle/negative checks. Native rendering is
  separately required; a headless pass alone does not establish visual output.

The first live probe, `pc-genesis-crew-live-01`, starts from an old mission
snapshot whose cockpit provenance is unavailable until the original redraws a
station. It correctly retains the PC cockpit while replacing the proven face.
The next probe switches away and back using original keys, then exercises the
same crew call with all proven Genesis cockpit components present. The older
standalone text trace is offset by the bridge's extra startup frame, so it is
not used as an equal-state replay pair.

## Reproduce locally

Requires the supplied originals, selected local artwork, pinned local core,
and source mission state. None of those proprietary assets is exported.
Use a new output directory for each retained receipt.

```sh
python3 tools/extract_pc_portraits.py \
  --capture artifacts/pc-live-type-crew-02/first-render.bin \
  --trace artifacts/pc-live-type-crew-02/report.json \
  --output local-art/pc-portraits-v1
./tools/godot.sh --script res://tests/test_pc_portrait_art.gd -- \
  --native --output "$PWD/artifacts/pc-portrait-native-new"
./'PC Bridge.command' --trace --capture --capture-station gunner \
  --capture-crew --output "$PWD/artifacts/pc-genesis-crew-live-new"
```

To record paired original dialogue evidence, use:

```sh
python3 tools/capture_pc_dialogue.py --mode trace --capture-ui --frames 2500 \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-portrait-loader-trace-new
./tools/godot.sh --script res://tests/test_pc_portrait_art.gd -- --native \
  --fixture "$PWD/artifacts/pc-portrait-loader-trace-new/report.json" \
  --output "$PWD/artifacts/pc-portrait-loader-native-new"
```

The extractor intentionally refuses an existing output directory. Ordinary play
uses `Play.command`; `--capture-crew` is a bounded research route that sends seven
original smoke-key pulses, rather than creating a message or changing RAM.

For consecutive driver onset and erasure frames, add the bounded capture window:

```sh
python3 tools/capture_pc_dialogue.py --mode trace --radio --capture-ui \
  --capture-window 3570 3715 --frames 3716 \
  --state artifacts/pc-radio-scout-01/entry/reference.state \
  --output artifacts/pc-portrait-lifecycle-trace-new
```

The window includes both endpoints and retains a paired UI packet on every
supported frame, even when the visible text has not changed. The production
native route in `test_pc_radio_bridge.gd` checks all 146 driver transition frames
and captures onset, caption appearance and erasure. Its full invocation is in
`docs/voice-workflow.md`.
