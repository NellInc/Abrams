# Player references

The loading screen, setup and **Help** menu open the offline player references
inside Abrams. The macOS setup embeds the searchable HTML edition; the game
and Windows/Linux setup use a native, searchable reader. The game continues
while a reference is open, so pause first when needed.

* **Keyboard controls:** original station and menu keys, remaster shortcuts,
  save slots and fast forward. Commands are larger and bolder than descriptions.
* **Scenarios and vehicles:** all eight scenarios, sixteen manual vehicle
  entries, guided weapons, ammunition, other units and crew stations.
* **Original credits:** the original game's creators, studio and publisher,
  with the remaster contribution credited separately.

The three-page keyboard PDF and 31-page field-guide PDF are bundled beside the
HTML editions. Players need no local server or original manual.

## Illustrations and sources

Text paraphrases the original DOS manual. Page references use its printed
numbering. Specifications and threat ratings retain its game-era values.
M113, M1A1 Abrams, M2 Bradley and M60A3 are friendly units.

Fourteen restored side-view drawings retain the manual's original silhouettes.
Each vehicle also has a study of its current Modern model.
All eight manual maps are redrawn in a consistent NATO-style cartographic
language. Each scenario has one landscape PDF page pairing its manual
map and extracted PC game-data map side by side, with the complete briefing
and objectives below. HTML pairs the maps in
responsive columns.
The terrain maps use the original PC world's terrain placement and
geometry. They show static geography; moving units and objectives are omitted.
The extracted terrain diagrams remain vector in HTML and PDF. The native reader uses matching
2400-pixel editions, preserving the compass and legend lettering.

Original creator names and roles are transcribed from the original PC intro
credit cards. `credits.json` is their shared source for the in-app readers,
About and authored guides.

## Authoring

Reviewed text lives in `manual-content.json`; illustrations are indexed by
`visuals.json`. Generate world diagrams with
`python3 -m tools.build_reference_maps`, which requires local PC game files
and the existing local geometry catalogue. It statically checks the original
selector-to-world association before drawing maps and executes no guest code.
Generate HTML, model studies and PDFs with
`python3 tools/build_player_reference.py` in a ReportLab authoring environment.
Use `--field-guide-only` for catalogue updates that leave controls and existing
model studies unchanged.
Use `--render-maps` when terrain SVGs change; this raster authoring step
requires Poppler's `pdftoppm`. Unchanged map PNGs are reused. These tools are used
only during authoring; players need neither.

The packaged outputs include no original game, ROM or manual. Source hashes,
page/crop references and restoration details are recorded in
`maps-provenance.json`, `manual-maps-provenance.json`,
`wireframes-provenance.json` and `illustrations.json`.
