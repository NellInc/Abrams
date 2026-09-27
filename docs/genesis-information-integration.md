# Genesis illustrations in the PC information pages

## Current result

Five illustrations now bind to original PC M1-Info pages: AX, SABOT, coax,
cannon and smoke dischargers. Genesis supplies every selected illustration.
The original START executable still draws the information, handles keys and
chooses pages. Specifications are retained from the PC, including differences
from the Genesis text. This is an illustration-restoration milestone; the
page typography, outer frames, top-down tank highlights and crew-information
composition remain to be remastered. HEAT remains original pending its recorded
image-tool blocker. No attempt was made to route around that rejection.

The three armament v2 images are in the 18-page art gallery and now have live
bindings. Coax is 2168x725; cannon and smoke are 2172x724. Original Genesis
extracts, exact built-in image prompts, rejected v1 palette candidates and
selected v2 hashes remain under `local-art/genesis/remastered/armament-v1/`.
AX and SABOT use the earlier `remastered/info-v1/` v2 images.

## Recognition and preservation

`pc_information_art.gd` pins START.EXE, INFO.BMP, the local catalog and each
selected image. It requires an exact RGB hash of all 320x175 pixels in the
complete original page content area and the active START program identity.
There is no tolerant recognition, inferred value, colour-key hole or new menu
state machine. A changed caption, drawing pixel, unsupported page or partial
transition retains the original source presentation and clears stale art.

The original page can retain variable pixels from the animated main menu in
row 175. Direct comparisons between separate captures found all differences
confined to this row, outside every illustration and text area. That row and
all lower rows are copied unchanged. The first complete-frame hash gate
correctly failed six pages; its failed `pc-information-baseline-01` receipt is
retained. Recognition now covers rows 0 through 174 exactly, with native tests
checking every output pixel outside each authorized illustration rectangle.

The source catalog also checks the original INFO.BMP pixels at their actual
screen locations and their loaded EGA planes and preservation masks. Six
sprite instances comprise 40,456 source pixels and 40,456 mask bits. These PC
resources are recognition/layout evidence, never visual donors.

The catalog hash is
`715ffe8b7b28e85ef83d50cf0254562f6fb6a2b0f9c83ef1a139ab0b10cc47ab`.
Generate it into a fresh local directory:

```sh
python3 tools/build_pc_frontend_catalog.py \
  --information-capture artifacts/pc-information-baseline-02 \
  --output local-art/pc-information-v1
```

Runtime pictures retain their aspect ratio by cropping only their background
padding to fit the original PC illustration cells. The frame is drawn with
the Genesis red. Native captures were visually reviewed by the implementing
assistant; this is self-review, not separate human art acceptance.

Working if: all original text and navigation remain visible and unchanged,
unknown pages stay original, and a recognized page replaces only its matching
Genesis illustration while every protected pixel remains source-identical.

## Evidence

* `pc-information-baseline-02/report.json`: all seven information pages and
  180-frame settled waits verified against original content fingerprints.
* `pc-information-trace-01/report.json`: 5,749 full RAM/video/input records,
  72 stage states and program boundaries exactly match the shared-neutral-state
  original baseline. The entire route stays in START, with no SIM state or
  invented geometry. Source core pins remain unchanged.
* `pc-information-native-01/report.json`: 11,559,472 checks, zero errors,
  all five supported illustrations, unsupported crew/HEAT/menu fallbacks,
  one-pixel caption/image/prefix corruption and preserved lower-border changes.
  Independent native donor/filter probes verify actual replacement art.
* `pc-information-headless-01.log`: 37 checks, zero errors. The focused Python
  catalog, session and launcher set passes 14 tests.

* `validation-20260927T202710Z`: all 27 stages complete, including 210 Python
  tests and unchanged original-file verification.
* `pc-information-launcher-parity-02.json`: both actual Play captures exit 0;
  source PNG, state, program, presentation and 60 samples match. The Genesis
  cannon is active only in the remastered capture, and the composite differs.

Artifacts above are under `artifacts/`. The last actual launcher capture was
visually inspected. These bounded receipts do not establish all-mission parity.

Capture an actual live information page locally:

```sh
./Play.command --capture --capture-information cannon \
  --output "$PWD/artifacts/information-review"
```

The route also accepts `crew`, `ax`, `heat`, `sabot`, `coax` and `smoke`.
The launcher partitions waits into bridge requests of at most 600 frames,
preserving every frame and held key. The initial live-01 attempt failed at
the 720-frame startup wait; its error is retained rather than treated as a
successful capture. No original game file or simulation instruction changed.

All reference images, generated derivatives, original state dumps and runtime
captures remain ignored local files. No publishing or redistribution is implied.
