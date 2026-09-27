# Original PC fonts and visible text

The tandem bridge now supplies read-only `presentation.text_runs` metadata for
selected original labels. Every supplied run has passed both native glyph and
presented-frame checks. Godot still displays the original pixels. This stage
adds no replacement typography or subtitles. The subsequent READY-specific
loader voice gate is described in `pc-audio-research.md`.

## Native font storage

The four-byte header is cell width, height, first character and character count.
The payload is glyph-major, row-major, with `ceil(width/8)` bytes per row and the
most significant bit at the left. File length must equal the header's declared
payload exactly. The supplied files are:

| Resource | Cell | First | Count | Observation |
|---|---|---|---|---|
| `6X6.FNT` | 6 x 6 | 32 | 96 | Same bytes as VM.FNT |
| `VM.FNT` | 6 x 6 | 32 | 96 | Alias, preserve both original names |
| `8X6.FNT` | 8 x 8 | 32 | 96 | Header takes precedence over filename |
| `8X8.FNT` | 8 x 8 | 32 | 105 | Nine stored upper-code glyphs are rejected by the original driver |
| `STENCIL.FNT` | 8 x 8 | 32 | 96 | Separate glyph artwork |

Main DS offsets 364e, 3662, 3676 and 368a hold the selected header fields;
369e holds the payload segment. `pc_fonts.loaded_font` reconstructs the complete
source bytes and requires a match against the supplied files. Unfamiliar fonts
stay source-only.

The original character driver is relative CS:IP `1388:0068..032c`, selected by
main DS:35b4. Its 709 original instruction bytes match SIM.EXE offset 80616 and
SHA-256 `f4139b282b485998e11c05b9c9ca4f87b0a3f583ee7e2a167f9e7acebfa194c7`.
Signed comparisons reject codes 128 through 136 even though 8X8.FNT stores them.
The observer preserves that behaviour. It does not repair the original font.

`pc_font_oracle.py` executes those unchanged instructions in the pinned isolated
Unicorn 2.1.4 CPU. It compares all four complete 64 KiB planes, including untouched
bytes, at four aligned/unaligned positions, on both EGA pages, with opaque and
transparent text. `pc-font-oracle-02.json` records 3,912 blits, 1,025,507,328 checked
plane bytes and 62,208 VGA writes. The retained first attempt correctly failed
at code 128 because the initial expectation incorrectly rendered every stored
glyph. This is font-driver evidence, with no DOS or historical timing claim.

## Original display boundary

The original string wrapper runs at `0f8d:020a..0259`. Its far-call stack contains
return IP/CS, string pointer, x and y. It reads the selected font and drawing page,
converts foreground/background indices through the original word table at 48a6,
then calls the original character driver for each byte.

The observer recognizes only these return addresses in the original main code
segment:

| Return IP | Meaning | Source routine |
|---|---|---|
| 3f1d | Primary crew text | 0000:3e7e |
| 3f58 | Secondary crew text, including formatted hit bearings | 0000:3e7e |
| 400d | Radio text actually being drawn | 0000:3f7a |
| 55df | Weapon status, including READY, TRACK and LOAD | 0000:54b6 |

Native event 26 copies conventional RAM at wrapper entry. Event 27 copies a
six-word rectangle header `(x,y,width,height,page_offset,return_ip)`, followed by
one EGA colour index per pixel, immediately before the wrapper's RETF. It reads
host plane storage directly, avoiding guest VGA reads that would change latches.
The original instructions, rendering, registers and emulated cycle schedule
continue unchanged. The trace manifest requires `text_event_schema: 1`.

## Visibility gate

1. Decode the exact loaded source font and original string at the known draw call.
2. Match every glyph foreground pixel and, for opaque text, every background pixel
   against the original completed EGA rectangle. Transparent text retains the
   actual background from the original draw.
3. Freeze completed candidates for the original page at scanout start. Keep them
   with the same native triple-buffer slot as its pixels and palette.
4. At presentation, compare every RGB channel in the entire rectangle with the
   actual BGRX framebuffer. Require visible ink/background contrast.
5. Expose only matching runs. Empty, offscreen, rejected-character, unknown-font,
   overwritten, wrong-page, unknown-palette and unobserved runs remain absent.

Candidates are bounded to four callsites on each of two pages. A redraw replaces
that page/callsite's candidate; a new SIM collector discards the old mission's
candidates. A later draw cannot mutate an older scanout's evidence. Internal
candidate pixels never appear in the JSON bridge payload.

Working if: a queued or erased message cannot become visible metadata, altered
rectangle pixels invalidate the run, and original RAM/video/input comparisons
remain equal to the untouched core.

The metadata contains the displayed words, rectangle, source pointer, font hash,
callsite, monotone draw sequence, palette indices and complete RGB rectangle hash. The crew speaker byte
is captured at the original draw, with no added character identity inferred.
These are visible **runs**, not once-only message occurrences. Repeated drawing,
repeated identical messages, primary/secondary grouping, radio acknowledgement
and speech cancellation still need a separate occurrence/timing contract.

## Bounded live evidence

* `pc-text-audio-01/report.json`: 2,091 actual frames, 372 observed text calls, all
  372 source-glyph matches, 1,570 presented runs. READY appears in 1,148 frames,
  LOAD in 381 and TRACK in 41. There are 516 rejected frame/candidate comparisons.
  `pc-text-parity-01.json` passes all 18 existing audio/control checks against
  `pc-audio-baseline-03`; RAM, video, input and sound-channel states match exactly.
* `pc-text-visibility-audio-01.json`: all eleven visibility/parity checks pass. This
  capture has no saved per-stage source crops; its live RGB comparison is separate
  from the saved-crop proof below. All three reload-completion hooks precede the
  first visible READY label by three emulated frames: 822 to 825, 1477 to 1480,
  and 1918 to 1921. Triggering a bark directly from the RAM update would reveal
  readiness before the original interface does in this probe.
* `pc-text-crew-01` and `pc-text-crew-baseline-01`: 1,308 frames and all stage states
  match. Seven ordinary smoke-key requests exhaust the six original mortars and
  cause the original crew warning. All 260 native text calls match source glyphs;
  the warning is visible in 134 frames. It is absent after the original clears it.
  Station-key requests remain original inputs; this capture proves the crew
  warning in the gunner display only.
* `pc-text-crew-comparison-01.json`: all 12 checks pass. Twenty-four saved source
  image crops independently match their runtime RGB rectangle hashes, including
  the crew warning. `ui-smoke-7-frame-00260.png` was also visually inspected.
* `pc-text-lifecycle-02/report.json`: all 11 lifecycle checks pass, including
  7,267 equal RAM/video/input frames, 52 stage states and identical original
  START/BRIEF/SIM/END/reentry transitions against `pc-lifecycle-baseline-02`.
  The first run used a wrong baseline filename and failed at comparison; its
  log is retained. Baseline readability is now checked before launching a core.
* `pc-text-native-01/report.json`: the updated core also passes the native Godot
  one-frame bridge/audio test: 1,692 original frames, 3,386 loop checks, correct
  96,000-frame loop endpoints, two audible cannon shots, one silent shot, one
  impact, one coax request, one smoke request, zero errors and child exit 0.
* `validation-20260927T104409Z/results.txt`: all 18 repository stages pass,
  including 158 Python tests and 52 Godot audio assertions.

The implementation was reviewed by the same assistant that wrote it. No live
hit-bearing suffix or displayed radio message was exercised in these probes.
Their recognized callsites are source-derived; live acceptance remains open.
The earlier all-256 bearing formatter/TTS tests do not close that gap. These font/text probes predate the subsequent loader integration. They do not
establish a font remaster or full dialogue coverage.

## Reproduction

Use fresh output directories. All proprietary source files and captures remain
local and excluded from Git and exports.

```sh
.runtime/pc-analysis-venv/bin/python tools/pc_font_oracle.py \
  --capture artifacts/pc-ui-controls-02/first-render.bin \
  --output artifacts/pc-font-oracle-03.json
python3 tools/build_pc_trace_core.py
python3 tools/capture_pc_render_trace.py --mode baseline --profile text \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-text-crew-baseline-02
python3 tools/capture_pc_render_trace.py --mode trace --profile text --capture-ui \
  --state artifacts/pc-source-boot-01/mission-entry/reference.state \
  --output artifacts/pc-text-crew-02
python3 tools/verify_pc_text_trace.py \
  --trace artifacts/pc-text-crew-02/report.json \
  --baseline artifacts/pc-text-crew-baseline-02/report.json \
  --output artifacts/pc-text-crew-comparison-02.json
```

The font/readiness build used trace core SHA-256
`303d494ecbb28a900d3732fc772e292b3a4fa271036f9c2cdf214f60698776e2`;
trace header SHA-256 is
`e42c666bad4102220c158506fc27329d8d49ec21f84f9021d5f9cdc7b9d34869`.
The unchanged source baseline remains
`57edbd309eb2ab6264b70188c3a85408fbcfa8c62e83b8c7b9c39b7309f61ac6`.


The subsequent [original crew-message integration](pc-audio-research.md#fully-displayed-original-crew-messages-2026-09-27)
adds assignment identity, complete prefix/suffix grouping, and live incoming-hit
and damage coverage. Its updated native core fingerprints and acceptance
receipts supersede the font/readiness build pins above. Displayed radio coverage
remains open.
