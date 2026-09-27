# Genesis office and Wilson in the PC tandem

## Delivered presentation

The default tandem now restores the office in eligible original briefing and
debriefing frames. The Genesis-derived office, neutral Wilson and speaking
Wilson are joined by a new both-hands facepalm illustration. The original PC
program chooses every pose, dialogue line, transition and input response.

The new `local-art/genesis/remastered/wilson-facepalm-v1.png` is 1293x1217 RGBA,
with genuine alpha. It was made with the built-in image generator using only
the selected Genesis-derived `wilson-v1.png` as its visual reference. The PC
pose supplies performance meaning and placement, not the illustration style.
It is an authored variant, not a recovered Genesis animation frame. Its exact
prompt, reference, hash, dimensions and review are retained in the adjacent
`wilson-facepalm-v1-prompt.json`. The generator did not receive a ROM or executable.

This implementation and the visual review were performed by the same assistant.
Independent human acceptance and all Wilson animation variants remain open.

## Exact recognition and protected dialogue

`build_pc_frontend_catalog.py` decodes the supplied OFFICE and CO resources,
then composes the three observed original poses at their measured positions:
neutral (89,36), speaking (86,36) and facepalm (91,47). The office palette differs
from SIM: index 6 is bright red. That distinction is required for exact source
matching. The original opaque-black index 11 and transparent index 0 are kept
separate.

The runtime pins the local catalog, original resources/executables and all four
Genesis image hashes. It accepts only BRIEF or END. Every RGB pixel above the
original dialogue border must match a complete source composition hash. The
border must be a full white row with original blue inner corners. Heights are
bounded to the observed ten-pixel line grid, or a completely matched full scene.
Partial pictures, altered pixels, unsupported poses and unknown program states
retain the original framebuffer. There is no approximate scene recognition.

The shader draws the office and transparent character only above that boundary.
The dialogue box remains original. The existing typography renderer now decodes
its actual visible 8x8 glyph cells, using the pinned original font. Every glyph
must have exactly one matching character, and every pixel of the complete line
is checked again before scalable lettering is permitted. Unknown colours,
partial/unknown glyphs and ambiguous characters retain the whole original line.
No string is supplied from queued dialogue or hidden memory. `--original-text`
keeps the original lettering; `--original-art` disables this restoration too.

Working if: an active scene has a complete original RGB-prefix match, scalable
text is reconstructed only from uniquely matched visible glyphs, and every
pixel outside the permitted art/text regions is unchanged.

This makes the three observed poses available live. It does not recover the
other CO poses, all mouth frames, every dialogue-box arrangement, motor-pool
animation, menus, title cards, information pages or endings. Unsupported states
continue to use the original. In-flight partial draws can therefore briefly
retain original art until a complete supported scene is visible.

## Proof and reproducibility

* `artifacts/pc-frontend-research-01/`: original palette, pose matching, complete
  prefix observations and reproducible catalog receipt. Early non-matches are
  retained: a SIM palette and an unclipped portrait cannot match BRIEF correctly.
* `artifacts/pc-frontend-native-01/report.json`: art-only native test, 8,148,958
  checks, zero errors, terminal exit 0. All original dialogue pixels remain exact.
* `artifacts/pc-frontend-native-02/report.json`: combined art/scalable-text test,
  6,825,954 checks, zero errors, terminal exit 0. Independent bilinear/alpha probes
  check the actual Genesis donors. Source overwrites and dialogue edits test the
  fallback boundary.
* `artifacts/pc-genesis-brief-live-01/`: actual Play-launcher cold boot captures
  the restored facepalm. `pc-genesis-brief-live-02/` captures the speaking pose
  with three verified dialogue lines. Both exit 0; native captures inspected.
* `artifacts/pc-genesis-brief-original-01/`: same speaking-pose route with
  `--original-art`, exit 0. `pc-genesis-brief-comparison-01.json` proves identical
  original frame bytes and complete program/presentation packets. BRIEF has no
  active SIM state; this receipt does not claim full-RAM or all-mission parity.
* `artifacts/pc-genesis-cockpits-frontend-regression-01/report.json`: the 21
  recorded cockpit/status frames and damaged-schematic check still pass,
  11,944,300 checks, zero errors, terminal exit 0.
* `artifacts/validation-20260927T183539Z/results.txt`: all 25 source/test stages
  pass, including 203 Python tests, 109 frontend checks and original preservation.
* `artifacts/pc-frontend-missing-fixture-01.log`: a missing evidence fixture
  exits 1. A first prototype used an unavailable byte-array hashing method;
  `pc-frontend-headless-01.log` preserves that failure. The code now uses the
  established HashingContext API. The new gate has a bounded quit limit and
  requires an explicit successful completion marker, as well as no engine errors.

The optional Impeccable linter is unavailable. Native Godot rendering and the
pixel/glyph checks above provide the applicable visual evidence.

```sh
# The builder refuses an existing output directory.
python3 tools/build_pc_frontend_catalog.py --output local-art/pc-frontend-v1
./tools/godot.sh --quit-after 300 --script res://tests/test_pc_frontend_art.gd -- \
  --native --text --output "$PWD/artifacts/pc-frontend-native-new"
./'Play.command' --boot --capture --capture-briefing speaking \
  --output "$PWD/artifacts/pc-genesis-brief-live-new"
```

The other bounded capture choices are `neutral` and `facepalm`. These routes send
ordinary original input only. All original samples and generated artwork remain
ignored, local-only and outside the source export. No redistribution permission,
push or publication is implied.
