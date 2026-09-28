# Ending newspapers

All three original outcomes have a Genesis-derived high-resolution newspaper:
Moscow Surrenders, Paris Devastated, and Stalemate. The original PC END program
continues to select and time them. Nothing reads a campaign score to manufacture
an ending, and no mission was completed or game memory edited for this work.

## Source and live binding

`tools/extract_genesis_newspapers.py` executes the unchanged Genesis M68000
9AFE/9B20 decoder against read-only ROM and isolated output RAM. Six returned
resource extents match their headers. Tile banks 6/7/8 and maps 18/19/20 are selected
by original scripts 93CE/9402/9436. Palette lists 58E8E and 58FE6 reconstruct their
320x200 source artwork. Original sources remain local and excluded from Git.

`tools/build_pc_newspaper_catalog.py` binds the three corresponding PC plates to
monochrome source pixels. `pc_newspaper_art.gd` validates the local catalog, source
files and selected donors, then requires END plus an exact displayed hash.
Complete matching plates receive the entire remaster. After the original changes
the story area, only the independently matched top 72 rows receive new artwork.
Every pixel below that boundary remains PC-owned, including partially drawn text.
An altered header, wrong executable, missing source or missing asset clears art.

Upscaled uses the authored assets. Genesis uses directly decoded native donors.
EGA remains exact original output. Switching does not advance guest execution.
Modern remains unavailable. Publisher/aftermath and office layers are separate.

## Authored assets

The three 1586x992 images live in
`local-art/genesis/remastered/newspapers-v1/`. Exact built-in imagegen prompts
are retained in `prompts.json`; runtime hashes/dimensions are in the pinned local
`pc-newspapers-v1/newspapers.json` catalog. The original monochrome composition,
headlines, small globe masthead and engraved newspaper style are retained. Fine
article marks remain typographic texture, as in the original illustration; the
original game supplies its readable ending prose separately.

The same assistant directed generation, implemented the binding and visually
reviewed the rendered output. Human aesthetic acceptance remains separate.

## Evidence

* Four Python tests: source identities, palette commands, flipped tiles, invalid
  geometry and high-resolution asset dimensions.
* Native Godot `artifacts/finish-20260928/newspapers-native-04/report.json`:
  780,124 checks, zero errors. Three papers, complete/prose phases, original/native/
  upscaled switching, independent bilinear donor samples, exact original lower
  region and negative matching checks. No engine errors or leaked resources.
* The first native pass had 315,121 passing checks. An extended pass stalled on a
  frame-drawn signal; it was closed through its exact owned process's normal app
  quit protocol. The harness now uses explicit draw/sync plus a 90-second deadline.
  A later run found an unparented static helper leak, repaired by parenting it.
  The final receipt above supersedes both incomplete/failed runs.

These are native-rendered, original-resource fixtures and production binding
checks. Arrival at all endings through a full original campaign remains untested.
Working if: identical original frames select identical papers, all original prose
survives, and a one-pixel header mutation restores the original framebuffer.
