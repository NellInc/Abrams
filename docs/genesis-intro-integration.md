# Genesis-derived title animation in the PC tandem

## Implemented scope

The default tandem renderer now restores the title illustration, all four
observed expanding muzzle-flash poses and all eight original PC credit cards.
`pc_intro_art.gd` selects each composition using the complete 320x200 RGB frame
and the active original START executable. There is no presentation animation
clock, input interception, random effect or authored credit schedule.

The original PC controls frame holds, the response to keys, credit wording and
order, and the transition into the menu. Unknown or altered frames retain the
original framebuffer. Missing or modified local source/art files also disable
the replacement. `--original-art` disables it through the existing diagnostic.

The initial publisher splash, joystick question, moving 3D menu backdrop and
unobserved transition variants remain original. This completes the observed
title/fire/credits sequence's binding, not the entire animation programme.
No intro audio replacement was added in this pass.

## Dedication

At Nell's explicit request, the final original copyright card is accompanied by
a lower-left memorial panel:

> Dedicated to the memory of  
> David "Ming" Kenny

The panel uses the original 6X6 and 8X8 letterforms, a black background, the same
red border as the credit cards, a subdued grey introduction and a white name.
It does not cover or replace an original credit. It appears only while the
original final credit frame is displayed, with no extra hold, input or timing
change. This is an authored remaster dedication, distinct from original content.
The new name and every panel/font pixel are checked independently in the native
intro test, and unknown frames clear it with the rest of the title restoration.

## Original source evidence

`tools/capture_pc_intro.py` records every paired RAM/video/input boundary and
stores each unique original RGB image once. Both cores start from the same
fingerprinted neutral START snapshot. Source files and the emulator builds were
unchanged.

* `artifacts/pc-intro-baseline-02/report.json` and
  `artifacts/pc-intro-trace-01/report.json`: 6,000 identical records, 369 unique
  images, including the later moving menu backdrop.
* `artifacts/pc-intro-skip-baseline-01/report.json` and
  `artifacts/pc-intro-skip-trace-01/report.json`: 1,800 identical records after
  pressing space for three frames at recorded index 450. The first credit
  appears at index 452 rather than 514. The PC owns this response.
* `tools/build_pc_intro_catalog.py` decodes CREDITS and EXPLO.BMP. Their cumulative
  composition matches all five complete original title/flash frames, covering
  320,000 RGB pixels. The original sprite positions are `(173,100)`, `(178,100)`,
  `(182,93)` and `(196,87)`. Later phases preserve earlier drawing beneath them.
* Each credit card differs from the final flash frame only inside its original
  card rectangle. Horizontal coloured spans retain every original lettering,
  spacing, border and background pixel as scalable geometry. No substitute font
  or generated lettering is used for the credits.

The local catalog is `local-art/pc-intro-v1/intro.json`, SHA-256
`1d90451bca98d7c2311ba29c2c9ca09352193c3ef72213c59a895d473bc8e99b`.
It contains 13 complete-frame bindings and pins the executable, native resources
and selected artwork. It is ignored by Git with the other reference-derived data.

## Genesis and authored art

`reference/genesis/intro-animation-01/` records 600 native frames and 49 distinct
screens. The four flash captures are frames 238, 243, 248 and 254. Each has an
independent exact VDP reconstruction under `reference/genesis/extracted/intro-flash-*`,
totalling 286,720 compared pixels with zero differences.

The lossless RGBA donors in `local-art/genesis/source/intro-v1/` subtract pixels
identical to the clean Genesis title and retain the remaining native colours.
Their manifest records source hashes and the common crop. Genesis's artwork
provides the four poses and palette; PC positions provide runtime registration.

The built-in image-generation tool produced
`local-art/genesis/remastered/intro-v1/flash-atlas-v1.png`:

* Four poses on one transparent atlas, measured **1448x1086**, RGBA.
* SHA-256 `df55f12daf04a9e9dc44663b399c88041665699b699139d863c6e779d517d05c`.
* The exact prompt is `prompt.txt` beside it; `manifest.json` records all four
  references, output dimensions, selected regions and the generated original.
* This is a smooth illustrated reinterpretation of the extracted poses, with
  white/yellow cores and red outer curls. It is not an exact enlargement.
* Explicit donor regions omit empty margins and isolated generated specks.
  The generated PNG itself is unmodified. The earlier `title-v1.png` supplies
  the background, now live as well as available in the gallery.

The generated atlas and integration were produced with this assistant's input.
Native visual inspection covered the small flash, final expanded flash and
first credit card. The muzzle remains registered to the title barrel; the
original credit panel stays in front. Nell's art acceptance remains separate.
No ROM or executable was sent to the image tool, and no redistribution rights
are asserted.

## Runtime and validation

`godot/tests/test_pc_intro_art.gd` runs beneath the full tandem material hierarchy.
Its native oracle samples the actual image donors independently and checks every
credit-card pixel at 4x. It also exercises one-pixel changes, wrong executables,
missing sources, stale-art clearing, all thirteen bindings and every boundary
of both recorded routes.

* `artifacts/pc-intro-native-01/report.json`: **2,259,820 checks, zero errors**.
* `artifacts/pc-intro-headless-01.log`: **7,921 checks, zero errors**.
* `tests/test_pc_intro_catalog.py`: three passing tests for resource composition,
  reproducible catalog bytes, exact credit lettering, and baseline comparisons.
* `artifacts/validation-20260927T214511Z`: all **28 stages** passed, including
  **214 Python tests** and the existing office/information regressions.

The first launcher comparison exposed variable cold-start timing: one capture
reached credit 1 while the other still displayed flash 4. The failed comparison
is preserved in `artifacts/pc-intro-launcher-parity-01.json`. It was not gameplay
parity evidence. The diagnostic `--capture-intro` now uses the existing neutral
START snapshot for repeatable comparisons. Ordinary Play still cold boots.
This final diagnostic-only change was checked through paired launcher runs after
the full gate; the complete gate above predates it.

`artifacts/pc-intro-launcher-parity-02.json` has all nine checks passing. Both
`pc-intro-live-02` and `pc-intro-original-live-02` exit successfully with three
samples and identical original PNG bytes, program, presentation and state. The
remaster selects credit 1 and is byte-identical to its native test image; the
original-art view reproduces every original pixel. This proves the selected
launcher boundary. The separate 7,800-record traces provide the broader
RAM/video/input comparison, rather than inferring it from one screenshot.

The optional Impeccable linter is not installed. Native Godot rendering, the
independent pixel oracle and launcher evidence cover the changed visual surface.

## Local reproduction

```sh
python3 -m tools.capture_pc_intro --mode baseline --frames 6000 --output artifacts/new-intro-baseline
python3 -m tools.capture_pc_intro --mode trace --frames 6000 --output artifacts/new-intro-trace --compare artifacts/new-intro-baseline/report.json
python3 -m tools.build_pc_intro_catalog --capture artifacts/new-intro-trace --output local-art/new-intro-catalog
./tools/godot.sh --script res://tests/test_pc_intro_art.gd -- --native --output "$PWD/artifacts/new-intro-native"
./Play.command --capture --capture-intro --output "$PWD/artifacts/new-intro-live"
./Play.command --capture --capture-intro --original-art --output "$PWD/artifacts/new-intro-original"
./Play.command --capture --capture-intro dedication --output "$PWD/artifacts/new-dedication-live"
```

`artifacts/pc-intro-native-01/title-sequence-v2.mp4` is a silent preview assembled
from the verified native renders using original frame holds. Its receipt checks
every input transition timestamp and the 2,657 encoded frames at 59.9227 Hz.
It is not a real-time screen recording or evidence for audio synchronization.

All extracted/generated media, local catalogs, snapshots and captures remain
excluded from source-control distribution. No push, publication or release
packaging was performed.
