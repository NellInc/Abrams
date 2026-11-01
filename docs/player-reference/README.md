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
Static structures placed in each world are drawn too: stone bridges (shapes
45, 46 and 108), the gabled building on its earth pad (47 on 48) and trees
(103, as fixed-size symbols because their crowns have no top-down area).
Convoy and Siegen Infiltration share terrain; only these structures and one
tree tell them apart. Hills are hillshaded per planar face, from the
north-west, and tinted by each placed shape's summit, so a hill no longer
splits into triangle-coloured patches. Each map is framed to the terrain
present, cell-aligned with one empty cell of margin and the aspect kept,
rather than a fixed 50-cell square that left Mass Destruction half empty.
Bridge symbols keep a legible minimum size; everything else is to scale.
Working if: Convoy and Siegen maps differ, every map shows its bridges and
building, and no map has an empty band beyond its terrain.
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
Use `--field-guide-only` for catalogue updates that leave the keyboard PDF and
existing model studies unchanged; it refuses to run if the Modern catalogue no
longer matches `illustrations.json`.
Use `--render-maps` when terrain SVGs change, including after any
`build_reference_maps` run; this raster authoring step requires Poppler's
`pdftoppm`. Otherwise map PNGs are reused, and the builder checks them before it
rewrites any reference. PDF rasters are embedded as JPEG, capped at 300 dpi of
their printed size. These tools are used
only during authoring; players need neither.

The builder sets ReportLab's invariant mode (`rl_config.invariant=1`: fixed
dates and document `/ID`), so an unchanged rebuild with the same ReportLab
release is byte-identical and a hash change means the content changed. PDF bytes
still depend on that release; record it with each rebuild. The 1 November 2026
full rebuild used ReportLab 5.1.0 from `.runtime/full-validation-venv`; model
studies came out byte-identical. Both tracked PDFs carry the invariant
2000-01-01 creation date.

Layout: ammunition ranges read as spans (`Range: 770–4000 m`), not lists.
Printed headings keep a clear gap below the preceding page reference or
paragraph. HTML scenario pairs fill two equal columns; the standalone map
rule's auto margins had shrunk each figure to its image's own width, leaving
the terrain map a third narrower with an unreadable legend. Under 700 px the
shortcut table uses smaller key chips so its Action column stays readable.
Working if: no PDF heading touches the line above it, and both maps in an HTML
pair are equally wide.

Model studies are drawn exactly back to front. A BSP tree over the mesh's
planes splits any face that crosses another face's plane, and coplanar faces
keep catalogue order. Source lines go into the same tree. Sorting whole
triangles by centroid had shown the wrong face on 7-21% of each study's visible
pixels: roadwheels cut through side plates, dark wedges on the M113 roof, the
Hind's cabin glazing buried. Against a per-pixel depth render, the studies now
differ only along one-pixel edges. A hairline in each polygon's own colour hides
split seams. `illustrations.json` counts source triangles and lines, plus the
drawn `polygons`.
Working if: every tracked vehicle's study shows a complete roadwheel row inside
its track bay.

Printing the HTML: the print stylesheet switches to a light colour scheme.
Under the screen's dark one, Chrome painted every page margin near-black.
Closed "Manual specifications" disclosures open for printing and close
afterwards. Vehicle cards print one per row, with the two figures side by side
and the specifications in two columns, so two cards fit on a page and none
splits. Headings stay with the content that follows. The field guide prints on
22 pages instead of 29, with nothing stranded.
Working if: a printed page has white margins and every vehicle shows its
specifications.
Working if: two consecutive invariant rebuilds produce identical PDF hashes.

The packaged outputs include no original game, ROM or manual. Source hashes,
page/crop references and restoration details are recorded in
`maps-provenance.json`, `manual-maps-provenance.json`,
`wireframes-provenance.json` and `illustrations.json`.
