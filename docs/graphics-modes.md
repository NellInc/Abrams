# Live graphics modes

The original PC executable owns every frame, input, transition, value and rule.
The graphics selector never requests an emulator frame or changes game state.
A successful explicit mode selection is remembered with HUD style and quality. Startup and command-line overrides never overwrite that preference. An unavailable saved mode falls back to Genesis Upscaled with a visible warning and retains its intent for the next compatible import.

Assets are validated and loaded at startup. Switching uses the currently cached
source framebuffer, presentation metadata and paired world texture synchronously.

* **EGA** displays the exact original 320×200 RGB framebuffer, including source
  glyphs and colours. The display scales those pixels with nearest sampling.
  Every presentation overlay and world-compositing shader is bypassed.
* **EGA Upscaled** enlarges the current original PC frame with palette-preserving
  [Scale3x](https://www.scale2x.it/algorithm) neighbourhood rules. Edge contours
  gain subpixel steps; every displayed colour is selected from the original
  frame, with no interpolation, generated replacement artwork or skin-colour
  substitution. Original dark brown skin tones, clothing, text and scenery
  retain their source colours. This option requires only the player's PC game,
  works on frontend screens as well as in missions, and is available through
  `--graphics ega_upscaled`, the Graphics menu and the browser selector.
* **Genesis** uses extracted original-resolution Genesis images, with nearest
  sampling to the PC-owned layout. It does not downsample generated artwork.
  Unmatched and dynamic regions retain the current original PC pixels. This is
  a partial-donor presentation, not emulation of the Genesis version. A missing
  or invalid complete native pack rejects the switch and preserves the prior mode.
* **Genesis Upscaled** (`upscaled`) restores the existing high-resolution artwork, typography and
  scanout-paired world. Its existing provenance and visibility gates still apply.
* **Modern** uses refined source-bound low-poly geometry, illustrated foliage
  and a restrained daylight palette, composed with the restored Upscaled UI.
  Buildings have fine plaster grain and muted clay roofs; hills and grass have
  broad colour variation, and water has subdued, distance-filtered ripples.
  It requires the local Modern asset catalogue and supported PC files.
  Unsupported sensor palettes retain source rendering. See [renderer boundaries](modern-renderer.md).
* **Tactical** uses the same source-bound Modern geometry and restored UI with
  Calibration Range-inspired meadow colour, directional surface shading, a
  pale blue-grey sky, fuller clustered hedgerows and a distant illustrated treeline.
  Low, leafy shrub clusters and bent grass tufts now add real near-field
  geometry, using the Calibration Range's primitive style. Their placement is
  deterministic in original world coordinates. Two instanced batches limit
  draw calls, and distant plants shrink smoothly into the meadow. They add no
  collision or gameplay cover. Roots and visible fragments are both restricted
  to verified flat grass by the same-frame original ownership mask; roads,
  water, slopes, vehicles, trees and effects remain unobscured. Raised or
  uncertain ground receives no decorative plants. Fine surface grass shading
  remains underneath the geometry.
  Horizon vegetation is grounded on the observed PC sky/ground boundary;
  original terrain and actors always appear in front of this underpaint.
  Tactical shades a tapered stem within each source tree's trunk plane to
  prevent filtered texture alpha from erasing it. Crown facets retain visible
  greens, and a distance-aware alpha threshold preserves filtered leaves. The
  original ownership mask still clips every recovered leaf and stem fragment.
  It requires the same Modern assets. This is a separate
  graphics mode: choosing Modern restores its existing palette exactly. The
  source camera, terrain silhouette, actor visibility and gameplay remain PC-owned.
  No decorative Range hills or trees are added to the battlefield geometry.

Working if: Tactical shows rooted near-field shrub and grass meshes on verified
flat grass, original roads and vehicles remain clear, and matched Modernized
views remain pixel-identical when switching back.

Graphics mode and **HUD Style** are independent. Choose Tactical in both menus
for the complete Range-inspired scene and station-specific widescreen interfaces, or combine
either graphics treatment with the Restored HUD.

Tactical HUD provides expanded Gunner optics, a panoramic Commander sight with
separate map/navigation/system panels, a larger Cupola view, and a larger Driver
view with the original instrument strip. Systems Status uses the same olive
housing and typography, with stores, vehicle schematic and every damage indicator
retained. Each arrangement copies complete source rectangles from the finished
paired frame. Source ownership must prove that every discarded pixel belongs to
static cockpit artwork; an unknown live overlay immediately restores the complete
4:3 arrangement. Camera projection, zoom, thermal semantics and controls are unchanged.
All five layouts also work with PC-only imports, without an optional Genesis ROM.

Tactical instrument faces use output-resolution vector gauges, ammunition and
status readouts, orientation diagrams, and an authored M1A1 plan-view schematic.
The original visible lamp colours, bar segments, selected ammunition, quantities,
and all 32 visible diagram-damage combinations remain authoritative. Unrecognised
ink keeps its original panel. These faces also work with PC-only imports and do
not change Modernized graphics or the Restored HUD.

The Tactical commander map has a larger cartographic display, a distinct muted
palette, a quiet unnumbered plotting grid and an original-state LOCAL/OVERVIEW
indicator. Its full source raster remains authoritative, including small features
and the exact current player-marker colour. Roads, rivers and terrain now use
continuous contours with rounded bends, fine road casings and bank highlights. Ambiguous
junctions and small or unknown ink keep their original shapes. Complete matching
local checker patterns become clean earth materials, while unmatched detail
stays intact. No roads, waterways, contacts or terrain features are invented.
Tactical menus, aligned instrument fields, registration corners and
crew-station keycaps share the same olive/cream presentation. Condensed section
headings and lamp labels separate hierarchy from monospaced measurements;
subtle inset panel edges and lit segment tops provide material definition. Restored retains
its original theme and map rendering.

The 2026-10-11 foliage/HUD refinement was checked locally in Godot Web using
paired original-game frame captures: all five stations, zoom, thermal, scan,
both map modes and compact layouts. Four matched Modernized station captures
were pixel-identical before and after the change. This pass did not run the
native renderer or a moving-performance benchmark.

The subsequent real-mesh foliage pass was verified in twelve Godot Web views:
four Modernized baselines, four Tactical stations, gunner zoom, a 90-degree
commander scan, compact driver and a return to Modernized. All four matched
Modernized station screenshots remained pixel-identical. Tactical changes were
confined to the 3D view; the checked gunner road, sight and far-vehicle regions
were unchanged. Raised and uncertain terrain deliberately omit the decoration.
The two batches use bounded far-to-near painter ordering; they do not introduce
a separate foliage depth viewport. Moving-performance and native-renderer
acceptance remain outside this local browser pass.

The additional Tactical finish replaces rounded shrub lobes with smaller,
irregular leafy crowns and forked stems. Bent, tapered grass ribbons and
world-seeded patches leave open spaces between clumps. Both foliage batches
share the terrain's fixed light direction and restrained distance separation.
Soft contact footprints are clipped to the same verified flat-grass ownership
as the plants; they introduce no depth viewport or gameplay cover.

Cupola and driver paint is finished on the verified artwork before the existing
hull-edge/world blend. Metal coverage retains the illustrated caps and fittings,
and the original silhouette and source visibility predicates are unchanged.
The extra paint uniforms are false in Modern. Tactical labels use a brighter
muted colour, with red/yellow emphasis derived exclusively from current source
readings and lamps. Dark/off lamps do not become warnings.

Only the source-proven player point receives a rounded output-resolution map
symbol, inside its exact original footprint and in its current source colour.
Black/blinking and differently coloured source rows retain their exact writes.
Unidentified small map marks remain intact; the renderer does not infer enemy
or friendly identities from colour or hidden world allocations.

This finish was checked in the actual Godot Web renderer across seventeen
matched station, sensor, map and compact-layout views. The foliage regression
and all 65 Tactical HUD checks passed. A captured original-game driving,
turning, zoom and scan sequence supplied 138 matched frames, with 108 distinct
camera positions and 58 rotations, for before/after renderer timing and six
moving-state inspections. On the local M1 Max browser, median presentation-to-two-
animation-frame latency was 87.1 ms, between the two baseline runs at 79.7 and
97.3 ms. These are matched browser measurements under variable host load,
not a native-renderer or full-mission frame-rate guarantee. Modernized station
and switchback pixel comparisons are retained with the local verification
artifacts. The native runtime was left untouched.

The subsequent optics/readability pass adds a cream-core, dark-edged daylight
sight wholly inside the verified original graticule. Its aiming gap, endpoints,
clipping and white thermal ink are unchanged. Tactical bearing digits use
monospaced lettering with a subtle contrasting outline inside the original
text boxes. Crew notices use olive framing and cream text only after both
original text parts, every background pixel and the complete border match.
Unknown content keeps the source panel. Spare fallback gutters show the
original station keys and action hints when there is sufficient room; they
never overlap or crop the retained 4:3 frame. Water colours and bank accents
are clearer, using the existing exact contours and protected map marks.

Two bounded foliage-grid caches reuse deterministic planting seeds and
rotations. Each frame still computes its own projection, distance fade,
source ownership and eligible ground. In an alternating-order Godot Web
microbenchmark, cached preparation took a median 1.16 ms against 3.765 ms
with the grids rebuilt (40 measured samples each). This compares warm and
cold caches, not whole-game frame rates. Twenty-one matched browser cases
covered stations, sensors, maps, compact layouts, crew notices and fallback
views. Modernized's four stations and switchback were pixel-identical; the
checked Driver/Cupola foliage, crew-notice scene and thermal sight were also
unchanged. All 334 sight and 72 Tactical HUD assertions, foliage cache/ownership
regressions and the source-only safeguard passed (125 tests, 10 skipped).
The same 138-frame original movement trace passed. Median presentation-to-two-
animation-frame latency was 68.3 ms, between baseline runs of 63.6 and 104.9 ms;
host variability prevents a whole-frame performance claim. This remains a
local browser/source verification, with no native run or publication.

The fallback-continuity pass keeps individually verified Tactical instruments
when an unknown overlay requires the complete 4:3 game frame. Gunner, Commander,
Driver and Status gauges, measurements and diagrams stay in their original
source rectangles. Each panel has a bounded clipping control, with whole output
pixels contained inside its proven footprint after resizing. One failed panel
leaves the other verified panels active; stale frame metadata, mismatched plate
masks, malformed UI masks, non-SIM screens and Restored clear the treatment.
Neither the wider-layout proof nor the original camera changes.

UI-owned OVERVIEW maps receive the existing Tactical cartography inside the
exact original 144 by 96 crop, without an added caption or surround. Fallback
LOCAL terrain remains source-rendered because the recorded mask owns only its
player marker, not the terrain. Wide LOCAL maps keep their existing treatment.
Verified crew-message parts become one readable line, with their exact words
and original timing. Measured gutter text accommodates compact windows without
overlapping the game; fallback instrument fonts use an undistorted 4:3 drawing
scale and enlarge within their existing fields.

The actual Godot Web renderer passed 219 HUD assertions, including recorded
PC-only station fixtures, three window sizes, corrupted glyphs, unknown panels,
unpaired metadata, missing map ownership and mode transitions. Thirty-five
matched browser cases covered sensors, both map modes, compact layouts, forced
fallbacks, an unknown panel, six original moving states and Modernized return.
Modernized's four stations and switchback were pixel-identical. Fallback changes
were confined to accepted instrument/map footprints and spare gutters; the
rejected panel and fallback LOCAL map were pixel-identical. Checked camera
regions were unchanged outside the exact original crew banner. The source-only
safeguard passed 125 tests (10 skipped). This is local browser/source evidence;
native rendering and whole-mission performance were not measured in this pass.

Working if: a source-forced 4:3 fallback retains verified Tactical instruments
at their original coordinates, every unknown panel stays visible and unchanged,
and Restored removes all retained overlay children immediately.

The instrument-legibility pass gives speed and fuel scales contained endpoint
labels and ticks registered to their segment rails. Readout columns measure the
exact verified value before fitting their labels, giving long words such as
READY more space. Commander miniature lamps use tighter housing and spacing so
their system names can remain larger. An inset marker repeats the original
ammunition selection, and navigation footers separate heading readouts from
their diagrams. All changes remain inside the existing verified panels.

Lamp shapes repeat the original source-selected states without adding a new
diagnosis: green uses a filled well, yellow a dash, and red temperature/system
lamps a cross. Black inactive wells have a visible outline. The original target
lock uses red for active; it receives target brackets and no fault-style row
background. Its original visibility and colour remain authoritative.

The actual Godot Web renderer passed 273 assertions, covering column separation,
scale containment, the colour/lock distinction and the existing station/fallback
proofs. Thirty-five matched first-pass browser cases were followed by twelve
final-candidate confirmations, including an explicitly synthetic active-lock
well exercising the original pixel predicates. Pixel comparisons confined
changes to accepted instrument rectangles. Modernized's four stations and
switchback, map and camera regions, crew messages, gutters and the rejected
panel remained unchanged. Only the Tactical instrument script changed in the
production pack. This pass remains local; native rendering and whole-mission
performance were not measured.

Working if: compact speed/fuel endpoints stay fully readable, verified long
readings do not overlap their labels, and an active red lock uses target brackets
while a red system/temperature lamp uses a cross.

Tactical's Audio, Session, Graphics and Help popups share the HUD's olive
surfaces, cream action text and amber focus. Their nested menus inherit the same
spacing, quiet separators and readable olive-tinted secondary text. Existing
engine radio/check indicators and submenu arrows are recoloured while keeping
their tonal detail, dimensions and antialiased alpha. Text contrast is 13.32:1
for actions, 8.44:1 for focus and 7.64:1 for secondary information.

The menu bar retains its original 32-pixel Tactical allocation, preserving the
game viewport. Tactical separators are non-selectable, including in an empty
Load submenu. Restored resets the popup theme and returns the incumbent
separator flags on reopening. Menu contents, command IDs, settings, original
key identities and the existing gameplay-input quarantine remain unchanged.
The styling uses the existing [Godot PopupMenu theme properties](https://docs.godotengine.org/en/stable/classes/class_popupmenu.html#theme-property-descriptions).

The actual Godot Web menu regression passed 243 checks. Final browser captures
covered both 1440- and 960-pixel widths, keyboard focus, all four top-level menus,
audio/quality/load submenus and return to Modernized. Paired comparisons found
zero changed rendered pixels in the checked Modernized scene and Audio popup,
including switchback, or in the closed-menu Tactical canvas at either size.
Only the menu script changed in this pass's production pack. This remains local
browser/source evidence; native rendering was not exercised.

Working if: pointer and keyboard focus use the same olive row, selected settings
remain distinguishable, empty Load menus have no selectable divider, and
Restored removes Tactical styling without changing the game viewport.

## Tactical navigation and schematic clarity

Navigation diagrams fit their complete verified grid centrally above the heading
row. The fit preserves the original 320×200 display's 4:3 pixel aspect, preventing
wide instrument wells from stretching the hull and turret. Four restrained olive
fills distinguish the existing source quadrilaterals. Their vertices, fill flags,
edge state colours and heading readings retain their original authority.

Vehicle schematics use clearer hull, track, turret and engine layering. Their
structural edges, hatch rings, grille lines and damage hatching retain at least
one output pixel in both expanded and source-footprint layouts. The five damage
zones keep their existing registration and bit order. STATUS retains its genuine
any-key return hint and omits station-switch hints, in the footer and spare gutter.

The actual Godot Web HUD regression passed 322 checks. Twenty-three paired browser
cases covered normal and compact windows, source-forced 4:3 fallbacks, rejected
navigation and combined damage. Damage previews used an existing CPU-oracle crop
composition; its fingerprints and all five individual-bit crops match the pinned
catalogue. Modernized's four vehicle views and switchback remained pixel-identical.
Changes stayed inside navigation, schematics and the removed STATUS key hints;
maps, cameras, other instruments and unknown navigation remained unchanged.
Only the two Tactical rendering scripts changed in this pass's production pack.
These checks were local; native rendering was not exercised.

Working if: navigation retains its original proportions at every checked size,
compact schematics keep readable structural and damage linework, unknown source
ink stays original, and STATUS advertises only its actual return action.

Working if: every verified station uses its own 16:9 layout, all live source cells
remain visible, unknown overlays return to full 4:3, and Restored removes the reflow.

The dedication to David "Ming" Kenny remains on the final credit card in Genesis
and Upscaled, and is inherited by Modern and Tactical. EGA is deliberately untouched, so its framebuffer contains the
original credits. EGA, Genesis and Upscaled keep their existing vehicle rendering. Modern and Tactical share the same source-bound vehicle geometry; Tactical alone adds the masked decorative plants.

## Tactical station and control readability

1. Compact headers place the station name and its role on a shared baseline,
   with measured separation. Campaign and HUD labels remain in their existing
   right-hand column. Larger windows retain the established two-line header.
2. The active F1-F4 station keycap has an amber outline as well as its existing
   fill, making the current position easier to identify across vehicle views.
3. Current-station commands use individual keycaps, separating each original
   key from its action. These are keyboard legends, not new clickable controls
   or additional bindings.
4. Footer groups use actual font measurements and a clear gap between station
   switching and station actions. Compact labels grow within the existing
   footer. STATUS keeps only its genuine any-key return action.
5. The map's verified LOCAL or OVERVIEW label has a matching Z keycap. It remains
   above the map; terrain, source cells, markers, projection and proof are unchanged.
6. Keycap outlines and registration corners retain at least one output pixel,
   preserving their definition at smaller browser sizes.

The actual Godot Web HUD regression passed 527 checks. Twenty-nine paired
browser cases covered five Tactical stations, compact windows, genuine crew
messages, source-forced fallbacks and rejected navigation. Seven Modernized
views, including switchback, were pixel-identical. Map contents, instruments
and complete fallback source frames also remained unchanged. Fifteen crew-strip
captures exactly matched an independent original-render reference with only the
incumbent footer legends omitted. This distinguishes removal of the old compact
keycap antialiasing fringe from any change to source content. Only the Tactical
chrome and map-label scripts changed in this pass's production pack. Verification
and delivery remain local; native rendering was not exercised.

Working if: all five stations retain readable identities and original commands,
active keycaps remain distinct, crew reports stay unobscured, map labels remain
outside map content, and Modernized keeps its existing pixels.

## Tactical compact instrument detail

1. Ammunition, stores, heading, fuel and other verified readings increase their
   font size in compact windows. Readings target 13 output-pixel font sizes,
   with exact width and height fitting where their source-owned cells are tighter.
2. Instrument labels target 12 output-pixel font sizes. Complete system names
   remain intact; labels fit their actual cells without new abbreviations.
3. Label/value columns allocate space using the larger reading's measured width.
   READY and other long source readings remain right-aligned and separated from
   their labels. All values and foreground state meanings remain source-authoritative.
4. System and temperature lamps retain readable silhouettes and output-pixel
   outlines. Filled, fault-cross, caution-dash, inactive-outline and target-lock
   bracket meanings are unchanged. Labels retain a measured gap before the lamp.
5. Gauge ticks are clearer and segments retain at least one output-pixel gap.
   Original scale labels, segment counts, lit counts and segment colours are unchanged.
6. Row separators, selection borders and ammunition-selection pointers remain
   distinct at smaller sizes, using the existing olive and amber visual language.

The actual Godot Web HUD regression passed 679 checks. Thirty paired browser
cases covered compact and normal stations, source-footprint fallbacks, genuine
crew messages and rejected panels. Seven Modernized views and both Cupola sizes
were pixel-identical. Every changed pixel remained inside an individually accepted
instrument rectangle; maps, cameras, crew messages, chrome and unknown panels were
unchanged. STATUS tank geometry was also pixel-identical. Source verification,
panel registration, navigation geometry and damage interpretation retain their
existing code. Only the Tactical instrument script changed in the production pack.
Verification and delivery remain local; native rendering was not exercised.

Working if: compact readings and labels stay fitted and separated, all original
indicator meanings and gauge segments remain visible, unknown ink stays original,
and Modernized retains its existing pixels.

## Tactical cartographic material finish

1. Accepted grass and earth regions gain a subtle, static print texture. It is
   anchored to source-map coordinates and communicates material only, with no
   invented elevation, vegetation, objects or tactical information.
2. Water gains restrained teal material variation and a clearer bank finish.
   Bank shading uses the existing contour distance; the Hermite arcs, original
   cell cores and one-cell corridors retain their existing geometry.
3. Existing cream and grey routes gain cleaner, more distinct material colours
   and edge separation. Road widths, crossings, connectivity and original
   palette-class distinctions remain unchanged.
4. The existing map grid is easier to read over accepted materials, at its
   original spacing and coordinates. The wide-map surround retains at least
   one output-pixel stroke at compact sizes, without shifting the map or labels.

The player point's radius derivative is evaluated before varying shader
branches, keeping compact edge smoothing independent of neighbouring material
shading. Its source-proven footprint, selected colour and point geometry remain
unchanged. Black and asymmetric marker rows retain their exact source writes.
Protected source patches outside that proven point retain their previous pixels.
Fallback LOCAL terrain remains original when its UI mask does not own the map.

The actual Godot Web HUD regression passed 729 checks. Twenty-two paired browser
cases covered both map modes, three viewport sizes, source-footprint fallbacks,
stale proof, marker colours and Modernized switchback. All three Modernized
views, both stale-proof views, Gunner, Status and both fallback LOCAL views were
pixel-identical. No changes occurred outside the Tactical map and its surround.
Exact GPU source-coordinate readbacks checked every protected patch; thirteen
incumbent-material reference views confirmed that new shading does not change
the stabilized player marker. Black, colour and asymmetric marker probes use
synthetic source-write variants of recorded frames, rather than additional
recorded gameplay events. Source proof, terrain classification, cache identity,
contour geometry and map registration retain their existing code. The shader
uses the same two textures and no time-based effects or extra rendering pass.
Only the map script and shader changed in this pass's production pack.
Verification and delivery remain local; native rendering was not exercised.

Working if: accepted materials have a coherent field-map finish, source routes
and water retain their geometry, protected marks remain intact, source-selected
player colours stay inside their exact footprints, compact borders stay visible,
and Modernized retains its existing pixels.

## Tactical section hierarchy and fallback navigation

1. Gunner, Commander and Status section headings target a 12 output-pixel font
   size at compact widths, while retaining the established normal-size lettering.
   Complete titles fit their measured columns, at their original baselines.
2. Restrained trailing rules align each title with its instrument group. Rules
   start after the measured text and retain one output-pixel thickness. The map
   heading reserves the existing LOCAL/OVERVIEW badge's space; no rule enters a
   live panel, camera or map.
3. Source-footprint fallback views now use the same amber-key, olive-surround
   action keycaps as the wide HUD. Each complete key and action label is fitted
   to its available gutter width. Exact existing keys, command meanings, row
   positions and the fallback Status return label remain intact.
4. Fallback role labels retain the complete existing station description,
   including COMMAND & NAVIGATION and VEHICLE SYSTEMS. Narrow gutters wrap the
   original words into at most two fitted lines, keeping both campaign metadata
   and the lower action group separated from the original game frame.

The actual Godot Web HUD regression passed 1,070 checks. Thirty-three paired
browser cases covered all five stations, normal and compact widths, three small
wide layouts, ten source-forced fallback views, rejected navigation, crew messages
and Modernized switchback. All seven Modernized views were pixel-identical.
All live camera, map and instrument rectangles, complete fallback source frames,
map-mode keycaps and crew messages were unchanged. Wide Driver and Cupola views
were also pixel-identical. Every changed pixel stayed in an incumbent section-
heading band or spare fallback gutter. Forced fallback fixtures use the established
test-only unknown source-cell/plate-ownership rejection; they are variants of
recorded frames, rather than additional recorded gameplay events.
Only the Tactical chrome script changed in this pass's production pack.
Verification and delivery remain local; native rendering was not exercised.

Working if: compact section titles are legible and complete, measured rules stop
before live content and the map-mode badge, fallback keycaps and full role labels
fit their spare gutters, all original game pixels remain visible, and Modernized
retains its existing pixels.

## Tactical diagnostic schematics

1. Vehicle diagrams separate the recessed tracks, turret deck faces, hatch rings,
   gun sleeves and engine louvers using the existing olive and cream palette.
   The outer hull, gun and turret silhouettes retain their existing coordinates.
2. Repeated mechanical details retain at least four output pixels between lines.
   Secondary track rails, hatch rings and deck engraving appear only when the
   schematic is at least 300 output pixels wide, keeping Commander miniatures
   cleaner without removing their primary structure.
3. Proven damage uses a translucent warning wash, preserving the underlying
   vehicle anatomy instead of obscuring it with an opaque rectangle.
4. Each existing damage zone has clear corner marks and clipped diagonal
   hatching. Hatch spacing retains at least seven output pixels. The five zones,
   bit order, source fingerprints and unknown-pixel rejection remain unchanged.

This pass changes only the Tactical schematic renderer. It introduces no new
readings, labels, animation, damage inference or gameplay state.

The actual Godot Web HUD regression passed 1,184 checks. Twenty-six paired
browser views covered Commander and Status diagrams, normal and compact sizes,
source-forced fallbacks, combined damage and rejected source ink. All seven
Modernized views were pixel-identical. Every changed pixel stayed inside a
Commander or Status schematic; cameras, maps, readings, lamps, headings,
controls and crew pixels were unchanged. The rejected diagram also remained
pixel-identical. All 32 original damage RGB/tag fingerprints match the unchanged
catalogue. Combined-damage captures use the existing CPU-oracle composition,
whose crop matches the all-five-zones entry, rather than a newly recorded combat
event. Only the Tactical instrument script changed in the production pack.
Verification and delivery remain local; native rendering was not exercised.

Working if: Commander miniatures retain distinct mechanical layers, Status damage
remains readable over the tank anatomy, every warning stays registered to its
original zone, unknown diagrams retain source pixels, and Modernized is unchanged.

## Tactical retained instrument drawing

1. Unchanged accepted instrument panels retain their existing Godot drawing
   commands, avoiding repeated text layout, diagram construction, clipping setup
   and hide/show operations.
2. Source verification still runs on every frame. Reuse happens after the current
   accepted panel list is built; ownership, source pixels and previous acceptance
   decisions are never cached by this optimization.
3. The retained state includes all readings, gauge data, orientation geometry,
   damage, panel rectangles, station, layout mode, dimensions and font resources.
   Nested changes invalidate a detached copy; resizing and font-resource changes
   also refresh the drawings. Advancing draw sequences and framebuffer-page
   metadata still receive normal verification without unnecessarily redrawing
   identical instruments.
4. Only one current drawing-state snapshot is retained. Clearing the HUD releases
   it and hides all panels immediately. Rejected panels disappear while other
   accepted panels remain available, and valid source data restores them.

The rendering functions and source-verification body are unchanged. This is a
Tactical-only drawing optimization with no reduction in visual detail or update
frequency. The actual Web HUD regression passed 1,228 checks, including nested
reading changes, gauge/orientation/damage changes, font updates, resizing,
advancing provenance, rejection, recovery and explicit clearing. Across six
identical updates at each of four stations, instrument draw callbacks fell from
78 to zero. This measures avoided drawing work, not an end-to-end FPS gain.
Twenty-nine paired browser views were pixel-identical, including all seven
Modernized comparisons, compact and fallback layouts, combined damage, rejected
and recovered diagrams, crew updates and station switchback. Only the Tactical
instrument script changed in this pass's production pack. Both browser bundles
were updated locally; native rendering was not exercised.

Working if: repeated identical verified frames cause no instrument draw callbacks,
changed readings and geometry redraw promptly, rejection hides stale panels in the
same update, the retained state stays bounded, and Tactical and Modernized retain
their existing pixels.

## Tactical player reference

The in-game Help reader follows **HUD Style**, independently of Graphics.
Tactical uses the cockpit's olive surfaces, cream body text, amber section and
shortcut emphasis, and Barlow Condensed controls. Search focus, selection,
clear button and the scrollbar use the same palette. The existing five sections,
manual text, numerical specifications, illustrations and creator credits remain
unchanged.

Tactical sizes and recentres the reader when its host viewport changes, leaving
space for the embedded title bar even on the 640 × 360 canvas. Section changes
and searches return to the beginning of the scrollable content. Restored retains
its original theme and layout, including when the retained reader is reopened.
The menu's existing held-key quarantine still protects gameplay while reading.

The browser asset selector also includes the guide's three source-reviewed JSON
indices. Previously, its private-art-only selection shipped the illustrations
without the text or index, so Help opened empty in every graphics mode. This
packaging repair restores the same guide for both styles; it does not change
Modernized's rendering or theme. No original game files are added.

## Tactical 3D daylight and materials

Tactical's source-bound vehicle and building facets now share the fixed world
sun used by its meadow and foliage. Warm light and a restrained cool fill retain
the authored paint colours. Hull facets receive a broad paint highlight;
tracks, wheels and masonry stay matte. The original courtyard and source-ordered
crew planes keep their separate treatments.

Grass slopes use the reconstructed facet normal beneath their small material
relief instead of assuming a horizontal surface. Earth hills retain their
existing palette with directional light. Tactical roads sample the pinned road
texture for their middle/fine aggregate and relief, keeping the exact original
road shape. Rivers receive a restrained blue-green body and broad filtered
highlights inside the same opaque source polygons.

The normal is reconstructed before ownership rejection, in the original world
coordinate frame. No mesh positions, ownership masks, source input packets,
collision, gameplay state, texture assets, shadow/reflection passes or animation
clocks are added or altered. Modern's shader path remains unchanged.

Local Web verification on 2026-10-12 passed 105 focused material checks across
12 terrain, vehicle, structure, tree and crew studies. Eighteen matched browser
views include every station, zoom, sensor view, scan, compact driver and a
recorded camera turn. All seven Modernized comparisons are pixel-identical;
Tactical differences are confined to the 3D view. In the recorded thermal view,
already-rendered vehicle/building facets receive the new light while the sky,
sight, road, ground and black-pixel coverage remain identical. An unsupported
palette still preserves the source fallback. Native rendering and performance
delta were not measured. Evidence is in
`artifacts/tactical-daylight-20261012/`; this pass remains local only.

Working if: matched Modernized and switchback frames are pixel-identical,
Tactical's new material pixels stay within the existing source coverage, and
vehicle/terrain studies retain geometry and stable same-frame rendering.

## Tactical shrub and meadow forms

1. Five overlapping shrub lobes now have two shoulder rings and gently rounded
   leaf normals. They retain the low-poly style with fuller crowns, using 147
   triangles per shrub, below the existing 200-triangle ceiling.
2. Each existing plant seed supplies stable width, height and depth proportions.
   The scale is applied in plant-local axes before the captured camera transform;
   turning the optic cannot stretch a plant. Lighting uses inverse-scale normal
   transformation for these non-uniform proportions.
3. Grass keeps its five blades and 32-triangle mesh, with narrower stems, bent
   upper sections and varied tip lean. Its planting locations and distance fade
   are unchanged.
4. Broad root-to-tip leaf colour separates shaded interiors from exposed tips.
   Grass tips gain restrained straw colour, and stems retain their separate bark
   treatment. These gradients require no extra textures or animation clock.
5. The original two instanced batches, source ownership rejection, flat-ground
   eligibility, deterministic grid cache and ordering remain in place. Plants
   still cannot paint over original roads, riverbanks, slopes, actors or trees.
   Modernized never enables this decorative foliage.

Local Godot Web draw-pass checks passed, including mesh bounds, unit normals,
stationary instance-buffer identity, camera-relative proportions, grid reuse,
source immutability and rejection. Eighteen paired browser views confirmed
pixel-identical results for all seven Modernized comparisons, Tactical thermal
and Status. Changed pixels stay inside the 3D camera; the sampled gunner road,
sky and distant actor regions and opaque reticle interiors remain identical.
The reticle's antialias fringe may composite different decorative grass behind
it; its drawing code and source geometry are unchanged.

The shrub increases from 107 to 147 triangles; grass remains at 32. No rendering
batch or texture is added. Native rendering and an end-to-end performance delta
were not measured. Evidence is in `artifacts/tactical-botanical-20261012/`.

Working if: crowns look fuller in the close driver view, grass blades retain
their shape without rigid broad fans, unchanged source frames reproduce exactly,
the protected world and HUD remain untouched, and Modernized comparisons remain
pixel-identical. This pass is local only.

## Tactical mechanical and architectural finish

1. Source-tagged moving track bands receive filtered link grooves and restrained
   raised-edge highlights. The existing source-position phase remains unchanged;
   this adds no clock, odometer or new motion inference.
2. Source-tagged road wheels separate rubber sidewalls, painted centres, rim
   edges and recessed spokes. Radial detail filters against the projected pixel
   footprint, using the existing wheel coordinates and silhouettes.
3. Verified pitched roofs gain shallow courses and staggered joints. The authored
   clay, slate and ridge colours remain intact. Flat roofs use quieter, widely
   spaced sheet joints instead of the pitched-roof pattern.
4. Verified wall faces receive broad plaster variation and a restrained tint at
   their base. Existing doors, windows, geometry and source-visible markings
   remain unchanged; no damage or additional architectural features are inferred.
5. Fine seams fade before their period drops below two output pixels. UV
   footprints are evaluated before source-ownership discard. Patterns stay in
   object-local coordinates, with no new images, mesh triangles or render passes.

This shader treatment is confined to Tactical. Modernized follows the original
branches. Turning surface variation off restores the incumbent material finish.

Verification: 111 Web material checks passed, including eight unaffected model
studies and detail-off comparisons. Eighteen paired browser views include seven
pixel-identical Modernized views. Tactical changes remain inside the 3D viewport;
status, zoom and the sampled near terrain/foliage remain identical. Thermal model
surfaces receive the finish while sky, sight, road, ground and black coverage
remain fixed. Close studies and receipts are under
`artifacts/tactical-finish-20261012/`. Native rendering and performance deltas were
not measured in this pass.

Working if: close vehicle and building studies show the separate material
finishes, their geometry and black-background coverage remain fixed, stationary
frames and world rebases preserve the pattern, and matched Modernized frames
remain pixel-identical. This pass is local only.

## Tactical canopy and bark refinement

1. The illustrated tree's existing leaf facets receive deeper evergreen interior
   colours and warmer upper foliage. Leaf alpha, crossed source planes, trunk
   widths and planting positions are unchanged.
2. The existing source-placement colour seed blends restrained evergreen and
   olive variants. Neither the clock nor the camera supplies a new random seed.
3. Trunks receive longitudinal bark grain, a restrained root tint and a shaded
   collar below the crown. Grain filters out before its period drops below two
   pixels; its derivatives are evaluated before source-ownership rejection.
4. Distant horizon trees share the same crown palette with a cool distance tint.
   Their alpha, positions and the existing hedgerow profile remain unchanged.
5. The finish requires Tactical and surface variation. Detail-off restores the
   previous material finish. Modernized's shader branches remain unchanged, and
   this pass adds no assets, geometry, texture samples or rendering batches.

Local Web verification passed 151 checks across 16 material studies, including
near/distant trees, both palette extremes, eleven unchanged control models and a
horizon scene with a protected source actor. Detail-off, rebase, stable-frame,
geometry, source-packet, coverage and Modernized switchback checks passed.
Eighteen paired browser views include seven pixel-identical Modernized views;
every Tactical change stays inside the 3D camera. Status, sampled near-ground
foliage and protected thermal sky/sight/road/ground pixels remain identical.
Native rendering and end-to-end performance deltas were not measured. Evidence
is in `artifacts/tactical-canopy-20261012/`.

Working if: nearby and distant trees retain their original coverage while gaining
coherent material depth, stable source frames and restores reproduce exactly,
sky/ground/actors remain protected, and Modernized comparisons are pixel-identical.
This pass is local only.

## Tactical road and water finish

1. Source-tagged road faces receive fine mineral grain and pores over their
   existing texture. Grain is world-anchored and fades before its period falls
   below two output pixels. No stones, damage, tracks or lane markings are added.
2. Roads use a more neutral gravel palette and a separate distance tint, reducing
   the previous meadow-green cast. Geometry, edges and silhouettes are unchanged.
3. Water uses two oblique, gently warped ripple fields to break up parallel bands.
   Their gradients affect material normals only, without moving the opaque plane.
4. A blue-green body colour blends towards a sky tint at grazing angles, with
   restrained fixed-sun highlights. No scene reflection, hidden actor, depth
   texture, new rendering pass or independent animation clock is introduced.
5. Detail footprints are evaluated before source-ownership rejection. Surface
   variation off restores the prior road and water finish. All changes are
   Tactical-only; Modernized retains its previous branches.

Local Web verification passed 147 checks across 15 material studies, including
near/distant roads and rivers, grazing-angle water and ten unchanged control
models. Source packets, geometry and coverage remain fixed; detail-off,
world-coordinate restoration and Modernized switchback checks passed.
Eighteen paired browser views include seven pixel-identical Modernized views,
and fully unchanged Thermal and Status captures. Every Tactical change stays
inside the 3D camera. In the gunner capture, differences are confined to the
projected source road polygons with a two-pixel filter margin. Native rendering
and end-to-end performance deltas were not measured. Evidence is in
`artifacts/tactical-terrain-20261012/`.

Working if: road grain resolves near the viewer and filters at distance, rivers
retain opaque coverage with varied surface light, original road/river boundaries
and source state stay fixed, and Modernized comparisons remain pixel-identical.
This pass is local only.

## Tactical hillside material finish

1. The prefiltered field atlas now uses each verified hill face's original
   source-fixed UV plane, including x/z and y/z faces. This removes the
   stretched vertical streaks caused by projecting that detail onto x/y.
2. Grass slopes gain broad, restrained pasture-colour variation. Decorative
   blade shading fades on steep faces; source grass/earth classification is
   unchanged, and no foliage is planted on unsupported slopes.
3. Earth slopes receive warmer soil and mineral colour variation, reusing the
   existing hill atlas at broad, middle and fine scales.
4. Material gradients are projected into each source face's tangent plane.
   Fine relief changes surface light only, leaving every vertex and boundary
   fixed. The slope uses the same fixed sun as Tactical foliage and vehicles.
5. Fine relief is footprint-filtered and distance-faded. Surface variation off
   retains the preceding finish. No textures, rendering batches, shadow passes,
   simulation clocks, terrain features or gameplay cover are introduced.

Local Godot Web verification passed 158 checks across sixteen material
studies, including six slope cases and ten unchanged controls. Source packets,
geometry and coverage are unchanged; static-frame, world-coordinate restore,
detail-off and Modernized switchback checks passed. Eighteen paired browser
views include seven pixel-identical Modernized controls and unchanged Tactical
Thermal and Status. Changes in the turned Driver frame stay within the
projected original hill faces, with a two-pixel filtering margin. Sampled gunner
road, sky, foliage and far-actor regions are unchanged. Native rendering and
end-to-end frame-rate impact were not measured. Evidence:
`artifacts/tactical-slopes-20261012/`.

Working if: steep hills lose projected texture streaks, grass and soil have
coherent surface depth, stationary and restored source frames remain stable,
terrain silhouettes and actor visibility remain fixed, and Modernized retains
its previous pixels exactly. This pass is local only.

## Tactical canopy and window finish

1. Existing `glass` and `cockpit` facets on ten intact building, truck and
   helicopter models receive an explicit material tag. This classification
   uses authored semantics and model identity, never a blue-colour match.
   Wrecks, vents, canvas, rubber, paint, window frames and unknown models retain
   their preceding treatments.
2. Tactical glazing retains its authored tint with a deeper body colour and
   restrained angle-dependent sky fill. The sky colour uses Tactical's fixed
   daylight palette; it contains no reflected scene objects or hidden actors.
3. Broad fixed-sun highlights fade with distance. There is no independent
   animation clock, high-frequency sparkle, transparency, reflection viewport,
   added geometry, texture or rendering batch.
4. The new tag retains the original points and adds no UV coordinates.
   Modernized and surface-variation-off continue through their existing
   material paths. Original painter ordering and ownership still determine
   every visible opaque pane.

Working if: close canopies and windows read separately from painted surfaces,
new colour stays within tagged glazing, source coverage and geometry remain
fixed, and matched Modernized views reproduce their previous pixels exactly.
This pass is local only.

Verification: 444 checks passed in the Godot Web renderer across 16 material
studies and explicit model/material classification checks. Seven studies show
the new glazing, including opposite-angle truck and helicopter panes and a
distant building; nine non-glazing controls retain their previous pixels. A
production-shader semantic mask confirms every changed pixel remains inside
tagged glass. Detail-off, Modernized, source packets, geometry, opaque coverage
and static-frame restoration are checked. All 18 paired recorded station views
are pixel-identical, including seven Modernized controls. These particular
station frames contain no eligible glazing models, so they provide preservation
evidence; the material studies provide visible-change evidence. Native rendering
and a performance delta were not measured.

## Grounded Tactical scrub and original-PC presentation choices

1. Tactical shrub crowns now reach at most 12.3 source units before the existing
   deterministic instance scaling, compared with 24 previously. The horizontal
   cluster pattern is retained, with shorter forked stems and a lower canopy.
   Leaves stay above the ground and stems still end at ground level. The shader's
   root-to-tip colour gradient follows the new 12.5-unit height envelope.
2. Plant placement, grass geometry, contact footprints, source ownership and the
   existing two instanced batches remain unchanged. This lowers decorative
   obstruction without changing original scenery, actors or gameplay cover.
   Modernized has no decorative shrub layer and retains its preceding 3D output.
3. The Restored HUD's three main-round icons now enlarge the original PC glyphs,
   preserving their thinner bodies, fins, tips, proportions and well colours.
   The shared palette-preserving Scale3x shader refines their contours. Each
   crop is explicitly bound to its shader source sampler, including reloaded
   icon controls. Exact source-cell matching and current UI/plate ownership still authorize each
   icon; changed or unowned cells remain original. Tactical HUD keeps its
   preceding instrument treatment. Ammunition values and selection stay PC-owned.
4. EGA Upscaled is an additional choice beside plain EGA and the existing
   generated-art Upscaled mode. It enlarges the entire current original frame,
   including portraits and frontend scenes, without replacing or recolouring
   people. The selector and graphics-cycle shortcuts include this PC-only mode.
   Switching back clears its shader flag and restores the preceding render path.

Working if: Tactical scrub reads as low rooted foliage, original actors and
roads remain clear, Restored rounds retain the thinner PC silhouettes, EGA
Upscaled selects only original colours, and Modernized changes are confined to
the three requested ammunition cells. This pass stays local.

Verification: five focused Godot Web suites passed. The draw-pass, menu,
shortcut and quality suites report 931 checks combined; the compositor reports
329,342 exact RGB comparisons, including the Scale3x oracle, thin-round source
contours, dark-brown colour, borders, guards and switchback. Eighteen paired
station views confine every Modernized change to the three requested ammunition
cells; five other Modernized captures are pixel-identical. Tactical changes stay
inside the 3D view, with its HUD, Status, thermal, sampled roads, sky, sight ink
and actor region unchanged. Four additional browser captures exercise plain EGA,
EGA Upscaled, the existing Upscaled choice and return to Modernized. Both EGA
choices retain the 11 original frame colours in the captured mission, excluding
the existing temporary remaster feedback label. Returning to Modernized is
pixel-identical outside that same label; a label-free compositor test verifies
exact restoration. Native rendering and a performance delta were not measured.

## Native donor boundaries

`tools/build_pc_graphics_catalog.py` produces the local-only pinned native pack.
Every donor is a hash-checked extraction under `local-art/genesis/source`.
The catalogue pins the recognition catalogs, donor dimensions, image hashes and
original plate identities. The production renderer loads no remastered image in
its Genesis path. Generated atlas pixels copy native donor colours directly.

Cockpit and motor-pool material pixels require an original plate tag, opaque UI
ownership, the correct original resource identity, and an exact original RGB
pixel match. Known instrument wells and captured-world regions are excluded.
The STATUS diagram requires the entire original schematic to remain pristine;
a single changed pixel rejects the complete native schematic. Moving driver
roof parts, maps, numbers, gauge values and unsupported states remain PC pixels.

Title, four flash states and eight credits require complete original-frame
recognition. Original credit rectangles are copied intact before the dedication
is added. Office neutral and speaking poses require the complete original region
above an observed dialogue border. Facepalm remains original because no native
Genesis pose has been verified. Known information illustrations and all four
crew-information portraits use native crops; HEAT uses a pinned complete PC
baseline frame. The crew diagram uses its original 200×61 crop. Live crew faces
require all original opaque face pixels and UI ownership to match.

The three ending papers and two aftermath scenes now use their exact decoded
Genesis donors. Upscaled uses the corresponding authored versions. Later PC
newspaper prose remains original-authoritative and is handled separately from
the full-paper artwork. The publisher card preserves PC Dynamix identity.
Additional authored Wilson performances have no proven native-pose counterpart,
so Genesis retains conservative original-PC pose fallbacks.

Unknown transitions, menus without matched illustrations,
world geometry and effects retain PC pixels in Genesis. Existing native source
availability does not imply that every variant has a verified live binding.

## Tactical near-field foliage lighting

Shrub crowns and grass now use per-fragment rounded-normal shading, cool sky
fill and warmer earth-facing fill. Broad leaf highlights and restrained
backlighting pick out the upper growth; these accents fade with distance.
The original planted positions, plant silhouettes, stems and soft contact
footprints are retained. There are still two instanced batches, with no added
textures, triangles, animation clock or shadow pass. Modernized does not use
this shader. Original ownership still rejects decoration over roads, water,
actors and unsupported ground.

Local Godot Web verification passed 60 draw-pass/material assertions and
18 paired station views, including six close-up foliage studies, zoom, thermal,
scan, compact Driver and a source-recorded turn. Seven Modernized captures,
Tactical Thermal and Status were pixel-identical. All changed station pixels
were inside the 3D viewport; sampled road, sky, actor and opaque reticle regions
were unchanged. Native rendering and end-to-end frame-rate impact were not
measured. Evidence: `artifacts/tactical-leaflight-20261012/`.

Working if: near-field leaves read as rounded, softly lit volumes, stationary
views remain stable, protected source features stay visible, and switching
back to Modernized reproduces its previous pixels exactly.

## Tactical vehicle-material finish

Tactical now distinguishes authored engine vents, truck canvas and rubber tyres
from painted armour. Vents and grilles have cooler, deeper recess colours and
restrained edge light. Existing mesh louvres supply their shape; the shader adds
no slots, tread patterns or new parts. Barrel bores, which share the dark vent
palette, are explicitly excluded.

The truck canopy has broad, soft fabric variation and a subtle woven finish.
Tyres have darker, matte rubber shading. Fine fabric and rubber detail fades
with its screen-space footprint. Coordinates use each authored face's dominant
local plane, including horizontal canopy tops, so camera translation and world
rebasing cannot slide the finish. These materials share Tactical's established
sun and sky lighting. Turning surface variation off preserves the preceding
material appearance. Modernized keeps its existing rendering.

Both **EGA Upscaled** and **Genesis Upscaled** remain independent choices in
the native Graphics menu and browser selector. The generated-art choice is
now explicitly labelled Genesis Upscaled; its saved identifier remains
`upscaled`. EGA Upscaled retains `ega_upscaled`, original PC colours and the
existing palette-preserving filter. Original-resolution Genesis remains a
separate option. No graphics mode or donor artwork has been removed.

Local Godot Web verification passed 263 material assertions and 270 menu
assertions. Seventeen material studies include six visible positive cases:
elevated T-62 and M113 engine decks, truck front/rear and distant views, and
Hind vents. Their changed pixels remain inside the exact semantic material
mask, with unchanged coverage, geometry, source packets, rebasing and restores.
Eleven controls, including flat-on tank/APC views, remain unchanged. All 22
paired mission/selection captures are pixel-identical, including eight
Modernized comparisons and both upscale modes; these recorded mission views
do not expose the new finish. Native rendering and frame-rate impact were not
measured. Evidence: `artifacts/tactical-equipment-20261012/`.

Working if: eligible materials have distinct finishes only in Tactical,
original silhouettes and visibility remain exact, barrel bores and other
untagged surfaces are unchanged, Modernized switches back to identical pixels,
and both upscale choices remain independently selectable.

## Integration

`pc_tandem_frame.gd` provides:

* `load_graphics_sources(root)` once at startup.
* `set_frame(source, presentation, world, program)` for a newly paired frame.
* `present_frontend(program)` for program-aware frontend routing.
* `set_graphics_mode("ega" | "ega_upscaled" | "genesis" | "upscaled" | "modern" | "tactical")` for immediate switching.

`graphics_mode` reports the selection. `native_graphics.loaded`, `load_count`
and `active` expose source-pack readiness and actual donor/fallback coverage.
The mode transaction completes in one synchronous call. EGA and Genesis hide
all scalable text, reticle, portrait, instrument and frontend remaster layers.

## Reproduction

```sh
python3 -m tools.build_pc_graphics_catalog
./tools/godot.sh --headless --script res://tests/test_pc_graphics_modes.gd
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_graphics_modes.gd -- --native
```

The native gate replays 158 existing transition fixtures across the lifecycle,
information pages, title and credits, all four stations and STATUS. It checks
exact EGA output, native donor samples and fallback pixels, same-frame Upscaled
restoration, missing-asset rejection, Modern UI reuse, immutable inputs and one-time asset loading.
Results and selected rendered frames are retained under
`artifacts/graphics-modes-work/final-native`. This is machine preservation evidence and
implementer visual review, not independent aesthetic or full-mission acceptance.

## Gunner donor-margin correction

The first native atlas excluded the PC instrument wells but still sampled the
captured Genesis instrument margins. Those wells have different extents, so
baked letters and widget edges leaked beside the live PC instruments. The first
native sampling gate was insufficient: it faithfully checked the chosen atlas
without independently checking its material-only eligibility.

Both complete gunner lower side consoles now retain PC pixels, including their
outer margins. Native donors remain on eligible surrounding and central framing.
Independent tests require zero donor alpha throughout those side consoles and
compare every surviving gunner-tagged pixel there directly with the source
frame. This intentionally conservative fallback avoids invented clean material
and preserves every current field and selection. The repair evidence is under
`artifacts/graphics-modes-work/side-console-native`.

### Tactical source effects

Tactical adds source-bound smoke and particles in one transparent mesh batch:

* Smoke deployment uses SIM's original active flag, timer and streamed canister
  position. Rounded billows expand and dissipate with that timer. When the
  original smoke background places the optic inside the cloud, immersed
  billows soften that same background while foreground ownership stays intact.
* Guided missiles receive a compact motor flare and short exhaust wake. The
  original AX and enemy guided-launch routines allocate shape-base + 71 with
  header 100 and movement speed 250, then alternate shapes 186/187
  in the pinned game. Both flare phases retain the wake. Only the actually observed, matching
  projectile is eligible. A launcher crew model alone never produces a flare.
* Moving vehicles with admitted engine geometry receive restrained exhaust.
  The emitter is fitted to the original observed face. Stationary engines are
  not assumed to be running from allocation alone.
* Ground vehicles receive low dust at their source-model contact height. Hinds
  receive engine fumes without ground dust. Decorative dust changes no cover,
  collision, aim or ground shape.
* Every admitted original effect phase receives shaded smoke, warm fire cores
  and sparse hot fragments. The original bitmap selects its phase and footprint.
  The existing cutout and painter coverage remain authoritative.
* Soft particles sample the same-frame ownership mask. An exhaust root must
  belong to its visible vehicle; hidden or unmatched actors emit nothing.
  Other actors, trees and fallback geometry stay in front. Burst embellishment
  is additionally confined to its original registered sprite rectangle.
* Particles reconstruct from the current source snapshot. There is no wall-clock
  timer, accumulated history, emitter simulation or replay of an old launch.
  Repeated, paused and restored packets reproduce the same image. Switching
  away clears the particle batch. A finite 512-puff ceiling, one batch and
  derivative-filtered detail bound the additional work. A smoke-timer or
  movement-cue change updates only the small particle batch when the original
  geometry is unchanged, retaining the terrain and actor mesh cache.

Smoke and dust use rounded colour shading with darker folds, pale lifted crowns
and restrained warm edges. Diesel soot keeps a darker, brown-grey body. Launch
bursts and missile motors use warm-white, gold, orange and cooled-red transitions;
the source-selected sprites retain their authored highlights and cutouts. Shared
colour-only finishes use existing source-seeded noise, with fine detail filtered
before ownership and cutout discard. Opacity, placement and source timing remain
unchanged. These are shaped colour cues, without volumetric simulation or scene
lighting. Modernized, EGA Upscaled and Genesis Upscaled retain their preceding
rendering.

Working if: popping smoke shows a source-timed cloud, an observed guided
projectile has a motor wake, a visible moving vehicle has rooted fumes and low
dust, covered emitters stay silent, and matching Modernized views remain exact.

## Tactical doors, timber and stone trim

1. Existing doors on the seven admitted intact building shapes gain subtle
   vertical paint/wood fibres while keeping their authored colours. The hangar,
   vehicles, destroyed buildings and unrecognised components are excluded.
2. The farm's existing timber panels receive a distinct, quieter painted-wood
   finish. The source-local face projection follows their horizontal/height
   axes; there is no camera-dependent texture phase or invented board layout.
3. Authored window/door surrounds and plinth pieces receive fine mineral
   variation. Only the existing base trim receives restrained weathering.
   Roofs, glass, plaster fields, markings and silhouettes remain unchanged.
4. Material tags decode to their exact incumbent dispatch before depth, roof,
   lighting and Modernized branches. Turning surface variation off restores the
   preceding finish. Detail is derivative-filtered before ownership rejection.
5. No assets, textures, mesh triangles, render passes, clocks or gameplay state
   are added. Near and distant finishes retain the existing Tactical daylight.

Working if: close doors, timber and stone trim have distinct subtle finishes,
untagged faces and coverage remain exact, detail stays fixed under camera/world
rebasing and filters at distance, and matching Modernized renders are identical.
This pass remains local only.

### Tactical authored material textures (local, 12 October 2026)

Tactical uses three neutral authored bitmap details on explicitly admitted vehicle
paint, intact-building plaster, and masonry trims/plinths. The current painted
colours, faction accents, glass, canvas, roofs, crew, foliage and terrain keep
their own existing treatments. The bitmap luminance modulates the authored
colour rather than replacing it. Modernized never samples the new material maps.

The loader pins each PNG's SHA-256, prepares 512-square single-channel mipmapped
textures once, and accepts the set only when all three files validate. Missing or
modified maps retain the preceding Tactical materials. Source-local UVs,
mirrored repeat and explicit pre-discard gradients keep the material attached to
its owning face. Restrained contrast and footprint/distance fading suppress
unresolved detail. No additional geometry, draw pass, animation or game state is
introduced. Both EGA Upscaled and Genesis Upscaled remain available.

Working if: close source-bound paint/plaster/masonry studies show the new detail,
untagged facets and coverage remain identical, missing-map captures retain the
preceding Tactical materials, and paired Modernized captures remain exact.

Local verification: 346 WebGL material checks; 25 studies (18 positive and seven
unchanged controls); 13 exact Modernized comparisons and exact EGA/both upscale
captures. Thirty of 32 full-game paired captures were identical. Two Tactical
views had small horizon-colour differences (171 pixels in compact Driver, 24 in
the turned Driver view; maximum channel difference 7/255), with cause unconfirmed.
These differences are not positive texture evidence. Native rendering and FPS
were not measured. Evidence: `artifacts/tactical-textures-20261012/completion.md`.


### Tactical full-scene material finish (local, 12 October 2026)

Tactical now gives every recognised scene surface its own photographic material
finish. Ten original authored grayscale scans extend the existing steel,
plaster and masonry maps. They modulate the existing paint and light rather than
replacing source colours, faction markings or crew skin tones:

* **Vehicles and equipment:** fine painted-metal grain on hulls, turrets,
  tracks, fittings, wrecks and markings; distinct rubber tyres and leather;
  woven canvas on truck covers, clothing, webbing and flags.
* **Buildings and ruins:** plaster, exposed brick and stone, timber grain on
  doors and structural wood, and distinct tiled/slate roof grain. Empty ruin
  openings stay empty.
* **Ground and transport surfaces:** meadow texture, earthen slope detail,
  asphalt aggregate and appropriate material detail on bridges and hangars.
  The observed world position anchors ground textures.
* **Vegetation:** leaf detail on original tree crowns and low shrub clusters,
  bark on trunks and stems, and grass detail on the existing instanced tufts.
  Dominant-face projection keeps leaf detail proportionate on both the tops
  and sides of shrub clusters. Their existing low canopy height is retained.
* **Water and glazing:** subdued water-surface detail and a faint glass finish,
  retaining the established ripples, highlights and original opacity.
* **Crew:** distinct fabric, webbing, leather and very restrained skin detail,
  with the original pose, palette and painter order preserved.

The existing illustrated cockpit textures are retained unchanged. Unrecognised
surfaces, sky, instrument ink, source effects and thermal rendering retain their
existing treatments. The smoke/particle pass remains intact.

All thirteen material tiles share one 1152-square, single-channel mipmapped atlas
with padded borders. Every authored map is hash-checked and prepared once at
startup. Missing or altered extended maps retain the preceding Tactical finish.
Source-local UVs, mirrored repeat, explicit gradients and footprint/distance
filtering keep grain attached to its face and suppress unresolved detail. The
existing source ownership, silhouette, cover rules and geometry remain intact.
Modernized never applies the atlas finish. EGA Upscaled and Genesis Upscaled
remain separate, available options.

Working if: close eligible surfaces show their distinct material textures,
shrub tops have proportionate leaf detail, original coverage and source-owned
HUD/reticle pixels remain exact, and paired Modernized and both upscale renders
are identical. This pass remains local only.

Local verification: 640 material and 65 foliage WebGL checks passed. Thirty-two
paired playable views confirmed 13 exact Modernized comparisons, exact EGA and
both upscale renders, and Tactical-only changes inside the 3D destination.
Both local browser build copies and all 45 BUNDLE records verify. Native
rendering and FPS were not measured. Evidence:
`artifacts/tactical-realism-20261012/completion.md`.


### Continuous Tactical terrain colour

Prefiltered ground colour uses a gradual footprint and distance tail. Fine
colour hands over to the existing filtered middle texture instead of a flat
mean, retaining road and field definition through the transition. Colour uses
the 16x-bounded footprint ellipse; relief normals keep their preceding
conservative fade. Original terrain ownership, geometry and world anchoring
remain unchanged. Non-ground material responses and Modernized retain their
preceding rendering.

Working if: Tactical roads and fields retain a gradual detail handoff, fine
relief stays filtered, the three Restored ammunition cells show their original
PC glyphs with the current shared sampler shader, and Modernized and both
upscale options remain pixel-identical in the paired browser views.

### Tactical grazing-road filtering (local, 12 October 2026)

The default scenery viewport already uses 16x anisotropic filtering, and the
material atlas requests linear anisotropic mip sampling. The road material's
extra contrast fade previously used the longest pixel footprint, suppressing
resolvable detail at grazing angles. It now uses the footprint ellipse's minor
axis, bounded below by the major axis divided by 16. Rotation and shear therefore
retain the same filtering budget; extremely elongated footprints still fade.
The existing texture gradients, mipmaps, distance fade and sample count are
unchanged. Other material families retain the previous fade calculation.

WebGL confirmed a maximum anisotropy of 16 and actual sampler requests of 1/16.
Seven GPU footprint checks and 32 paired playable views passed. All 13 Modernized
comparisons, EGA, EGA Upscaled and Genesis Upscaled stayed pixel-identical. HUD
outside the 3D, protected sky and opaque reticle ink remained exact. The two local
build copies and all 45 BUNDLE records verify. Only the shared Tactical material
shader payload changed; no original files, observer, HUD or authored assets
changed. Native rendering and FPS delta were not measured.

Evidence: `artifacts/tactical-anisotropy-20261012/completion.md`.

Working if: shallow-angle road detail extends into the middle distance without
removing mip/distance filtering, Modernized and both upscale comparisons remain
exact, and this pass stays local only.

### Tactical material naturalism (local, 12 October 2026)

This pass refines the existing authored textures rather than adding another
rendering layer:

1. **Quieter asphalt:** lower aggregate contrast and height relief reduce the
   large mottled appearance. The existing road texture, source road boundaries,
   anisotropic mip sampling and distance fade remain in use.
2. **Material-specific response:** painted steel, plaster, roofing, cloth,
   rubber and leather have individual contrast/relief weights. Masonry retains
   its stronger grain; timber retains a more pronounced response than fabric.
   Water, glazing and original-colour skin retain their preceding weights.
3. **Less obvious terrain repetition:** a small, continuous coordinate warp
   varies mirrored meadow, soil and asphalt tiles. It stays anchored to the
   observed world position, with no screen-space or wall-clock seed. It changes
   texture coordinates only, preserving source geometry and road/river edges.
4. **Consistent grazing-ground filtering:** meadow and soil now use the same
   16x-bounded footprint ellipse as asphalt. The exact coordinate-warp Jacobian
   is passed to textureGrad, preserving appropriate mip selection. Unresolved
   and distant detail still fades; non-ground materials keep the conservative
   footprint calculation.
5. **Softer vegetation detail:** leaf and grass texture relief is gentler, with
   restrained bark grain. Low shrub canopies, visible stems, source-owned cover,
   instance placement, mesh budgets and the two existing foliage batches stay
   unchanged. Contact shadows retain their preceding material branch.

The shared atlas, thirteen authored maps and three texture samples per eligible
fragment are unchanged. There are no new assets, samplers or rendering passes.
Cockpit art, HUD, gameplay, observer and original files are untouched. Modernized
skips this Tactical finish. EGA Upscaled and Genesis Upscaled remain separate
options. This pass stays local only.

Working if: actual close material studies show the quieter and differentiated
finish, ground detail stays attached to source coordinates, foliage coverage is
exact, and paired Modernized and both upscale renders remain pixel-identical.

Local verification: 36 GPU coordinate/filter/profile checks, 58 production
material checks and 65 foliage checks passed. Thirty-two paired playable views
confirmed 13 pixel-identical Modernized comparisons, exact EGA and both upscale
renders, and Tactical changes confined to the original 3D destination. Source
sky, opaque reticle ink and HUD outside the 3D remain exact. Both local browser
build copies and all 45 BUNDLE records verify. Only the shared Tactical material
include changed in the normal playable package. Native rendering and FPS delta
were not measured. Evidence:
`artifacts/tactical-naturalism-20261012/completion.md`.

### Tactical coherent light and sky (local, 12 October 2026)

1. **Material-specific highlights:** explicit painted-metal, timber, canvas,
   rubber and roofing families now choose their own restrained highlight
   strength and width. Mineral surfaces stay matte. Sun-facing facets receive
   a warm lobe, preserving authored paint colours. Unclassified surfaces retain
   the preceding response; crew planes keep their separate treatment.
2. **Filtered glints:** paint, glazing and water highlights fade with source
   distance and the view-direction pixel footprint. The footprint is evaluated
   before source-ownership discard. The bounded half vector stays finite when
   looking directly away from the sun. Diffuse light and broad reflections remain.
3. **Coherent opaque reflections:** water and glass now share Tactical's sky
   palette and world-angular cloud field. Reflections are analytic sky colour,
   with no reflection of unseen actors, scene/depth sampling, transparency or
   extra rendering passes. Original painter order and source coverage still
   govern the surfaces.
4. **Cloud depth:** the existing broad cloud field receives softer dense-bank
   undersides, brighter thin edges and a subdued warm upper fill. Its placement,
   threshold and world-view coordinates are retained. No independent animation,
   additional cloud noise layer or new weather/simulation state is introduced.

The new finish requires the existing verified daylight horizon marker. A normal
palette alone does not establish daylight: thermal views use that same palette
with different sky/ground colours. Thermal and other unverified-light frames
therefore retain the preceding Tactical highlights and reflection colours.

The preceding atlas, material textures, anisotropic ground filtering, foliage,
particles, cockpit, HUD and gameplay are unchanged. The normal playable package
changes only the source surface shader. Modernized retains its original sky and
material branches; EGA Upscaled and Genesis Upscaled remain available separately.
This pass stays local only.

Working if: actual vehicle/water/glass/sky studies show the intended light,
filtered highlight checks remain finite and bounded, original coverage and source
actors remain exact, and Modernized and both upscale comparisons are identical.

Local verification: 19 WebGL lighting checks and 124 production material checks
passed across 14 studies. Nine studies show positive changes; ground, tree and
crew controls remain exact. Each isolated non-sky study also verifies exact
preceding materials without the daylight marker and exact daylight restoration.
Thirty-two paired playable views passed, including 13 exact Modernized
comparisons, exact EGA/both upscale renders and exact Tactical thermal rendering.
Tactical changes stay inside the source 3D destination; opaque reticle ink and
HUD outside the 3D remain exact. Both local browser build copies and all 45 BUNDLE
records verify. Only the source surface shader changed in the normal package.
Native rendering and FPS delta were not measured. Evidence:
`artifacts/tactical-lighting-20261012/completion.md`.

### Tactical particle material depth (local, 12 October 2026)

1. **Screening smoke:** cool dense-bank shading, softer sunward crowns and a
   restrained warm rim give the existing billows a less flat finish. Density
   drives colour only; the preceding opacity and feathering remain exact.
2. **Diesel exhaust:** darker dense soot cores and cooler dispersing edges
   distinguish engine exhaust from screening smoke. Original visible-engine
   anchors, movement requirements, seven-puff queues and heading remain intact.
3. **Low dust:** a subdued earth-colour response gives dust warmer thin edges
   than soot. Its existing low placement, four-puff queue and original source
   visibility are unchanged; no new obstruction is introduced.
4. **Flame and missile cores:** the existing amber burst embellishments and
   guided-motor cores now grade from brighter hot centres to subdued orange
   edges. Source sprites, flight state, original bitmap phase and plume geometry
   remain in use. No independent animation or invented launch events are added.
5. **Boundary filtering:** colour-grain derivatives are evaluated before
   source-ownership discard diverges. The preceding bounded footprint filter
   remains; opacity still uses the original density calculation.

This is a colour-only refinement of the existing Tactical particle shader. The
same two procedural noise layers, three ownership/anchor samplers, puff budgets
and single particle mesh remain. There are no new textures, scene lights,
reflection/depth reads, rendering passes or simulation state. Surface materials,
foliage, sky, HUD, cockpit, observer and original files are untouched. Modernized
never uses this shader; EGA Upscaled and Genesis Upscaled remain distinct options.
This pass stays local only.

Working if: actual smoke, exhaust/dust and burst/motor studies show the revised
finish, their composited opacity and source coverage stay pixel-identical,
repeated packets and pause/switchback controls remain exact, and Modernized and
both upscale comparisons remain identical.

Local verification: 239 WebGL particle checks passed. Four visible material
studies changed positively; the hollow source-smoke ring remains an exact
negative control. All five production-shader white-output comparisons retain
pixel-identical composited opacity and coverage. Original timers, pause,
repeated-packet, engine/missile admission and painter-occlusion controls pass.
Thirty-two paired playable views pass, including 13 exact Modernized comparisons,
exact EGA/both upscale renders and exact Tactical thermal rendering. Smoke and
missile material changes stay inside the original 3D destination; opaque reticle
ink and surrounding HUD remain exact.

One Tactical turn-view comparison differed by three RGB1 sky pixels. Explicit
fresh redraws reproduce those same two quantization states in both the preceding
and updated builds, with zero puffs and effects invisible. The updated capture
matches a measured preceding-build redraw exactly. The underlying GPU cause was
not established; this is measured baseline variation, not a relaxed Modernized
comparison or a new particle leak.

Both local playable build copies and all 45 BUNDLE records verify. Only the
particle shader changed in the normal package; the other 1,113 payloads are
identical. Native rendering and FPS delta were not measured. Evidence:
`artifacts/tactical-billow-20261012/completion.md`.

### Tactical distant woodland filtering (local, 12 October 2026)

1. **Pre-clipping footprints:** angular and elevation derivatives are evaluated
   before original source-ownership discard and the per-pixel hedge/crown
   branches. Antialiasing receives defined helper-lane values at those edges.
2. **Explicit crown mip gradients:** distant trees sample the existing authored
   mipmapped image with cell-local textureGrad coordinates. Crown/cutout branches
   no longer choose texture detail from implicit derivatives inside the branch.
3. **Continuous angular wrap:** gradients come from the unit world direction,
   avoiding the atan discontinuity at positive/negative pi. A bounded horizontal
   denominator also keeps the calculation finite near the zenith.
4. **Unresolved-detail fade:** tiny hedge leaf clusters converge towards their
   mean when their angular footprint becomes too large. Fine canopy shading
   likewise fades to its mean, retaining the broad irregular bank field.
5. **Distant colour depth:** a restrained cool atmospheric fill softens the
   dark hedge band and relates it to the existing distant-tree palette. Close
   trees, low shrubs, grass and their contact footprints keep their preceding
   materials and placements.

The same 96-cell world-angular layout, broad bank noise, tree artwork, crown
heights, stem placement and original horizon band remain in use. Filtering may
change resolved distant cutout pixels and fine hedge edges. These are decorative
underpaint within the verified daylight sky; original terrain/actors and painter
ownership still govern visibility. Clouds, reflections, surface materials,
particles, cockpit, HUD, observer and original files are unchanged. There are no
new assets, samplers, noise layers, geometry, rendering passes or independent
animation. Modernized retains its preceding sky branch. EGA Upscaled and Genesis
Upscaled remain separate options. This pass stays local only.

Working if: actual forward, angular-wrap and compact horizon studies show the
filtered woodland, source actors/ground and upper clouds stay exact, gradients
remain finite and continuous across the wrap, and Modernized/both upscale
comparisons remain pixel-identical.

Local verification: 12 WebGL gradient/filter checks, 121 production-material
checks and 16 targeted source-actor occlusion checks passed. Forward, angular-wrap
and compact horizon studies show positive changes. Thirteen surface/near-tree/
crew controls are exact. Upper clouds and original ground remain exact in the
horizon studies; an opaque source actor crossing the changed woodland band keeps
its entire tested interior exact. Fresh captures and angular restores pass.

Thirty-two paired normal playable views pass, including 13 exact Modernized
comparisons, exact EGA/both upscale renders and exact Tactical thermal rendering.
Tactical changes remain inside the source 3D destination; surrounding HUD and
opaque reticle ink stay exact. Both local browser builds and all 45 BUNDLE records
verify. The normal package changes only the surface shader; the other 1,113
payloads are identical. Native rendering and FPS delta were not measured.
Evidence: `artifacts/tactical-horizon-20261012/completion.md`.


### Tactical terrain footprint and light coherence (local, 12 October 2026)

1. **Explicit grazing-angle sampling:** the existing field, road and hill
   textures use textureGrad for middle/fine colour and relief, with their
   source-world plane derivatives supplied before painter-ownership discard.
   Existing anisotropic mip samplers remain in place.
2. **Resolution-aware broad colour:** broad terrain colour keeps its preceding
   minimum mip level of three, then chooses coarser mips when the observed pixel
   footprint requires them. Unresolved fine grass/asphalt colour converges to
   the existing texture means; unresolved relief fades to the source face normal.
3. **Slope-coherent relief:** grass, asphalt and soil reuse the source face's
   XY, YZ or XZ material plane. Relief is projected into its tangent plane,
   including oblique faces, rather than tipping tilted ground with a flat-plane
   perturbation. No vertices or terrain classification change.
4. **Lit fine grass:** the painted fine blades receive the same bounded sun
   multiplier as the underlying grass before the existing distance tint.
   Their footprint comes from the supplied source-plane derivatives, rather
   than implicit derivatives inside a clipped material branch.
5. **Background-plane footprints:** original background ground uses the same
   observed-camera ray projection onto z=0 for its pre-discard derivatives. A
   bounded denominator keeps helper lanes finite at the horizon; the existing
   usable-ray condition still decides whether the ground material is drawn.

This changes colour and material light only within original terrain ownership.
Source silhouettes, geometry, occlusion, camera, physics, HUD, sky, nearby
foliage, particles and authored assets retain their preceding code/data. No new
textures, samplers, sample layers, geometry, render passes or clocks are added.
Modernized keeps its preceding material branch. EGA Upscaled and Genesis
Upscaled remain separate options. This pass stays local only.

Working if: near and angled ground studies show resolved material changes,
large footprints produce finite coarser mips and flat relief, original source
coverage/actor interiors and all sky remain exact, source-coordinate restores
are exact, and Modernized/both upscale comparisons stay pixel-identical.

Local verification: 13 production-function WebGL checks and 84 material checks
passed. Seven near/angled/background terrain studies show positive changes;
four vehicle, river, tree and crew controls remain exact. All studies retain
original coverage, immutable geometry/packets and stable fresh redraws. The
background study protects the entire sky/woodland half and an opaque original
actor overlapping the changed ground. Ground source-coordinate restores are
exact. These new studies use captured PC terrain material words; the initial
synthetic bank did not represent grass colours accurately.

Thirty-two normal playable comparisons pass, including 13 exact Modernized
views, exact EGA/both upscale renders and exact Tactical thermal rendering. Ten
Tactical views show changes confined to the source 3D destination; surrounding
HUD and opaque reticle ink remain exact. Both local browser build copies and
all 45 BUNDLE records verify. Only the surface shader changes in the normal
package; the other 1,113 payloads are identical and original game files are
absent. The runtime requested 16x anisotropy on this WebGL implementation.
Native rendering and FPS delta were not measured. Evidence:
`artifacts/tactical-grounding-20261012/completion.md`.


### Tactical near-vegetation light and filtering (local, 12 October 2026)

1. **Implied crown volume:** a broad camera-facing canopy hemisphere shades
   the existing source-tree artwork. Its normal is transformed through the
   captured camera basis into the source world, sharing the real shrub sun.
   Authored leaf facets and palette remain the colour foundation.
2. **Restrained transmission:** a warm upper-canopy response appears towards
   the observed sun. The volume/transmission treatment converges to the
   preceding crown colour with distance or an unresolved UV footprint. It is
   enabled only for verified daylight and the existing Tactical detail mode.
3. **Pre-clipping tree gradients:** explicit textureGrad sampling reuses the
   existing mipmapped tree artwork. UV gradients are supplied before source
   ownership discard, rather than derived in the clipped tree material branch.
4. **Consistent cutout/stem footprints:** the existing leaf threshold and
   tapered-trunk rules now receive those same supplied derivatives. Their
   constants, artwork, UV extent, geometry and source-owner bounds stay put.
   Filtering can change resolved leaf-cutout pixels inside those bounds.
5. **Resolution-aware shrub/grass sheen:** the existing leaf highlights fade
   according to local material, normal and view-direction footprints evaluated
   before grass ownership discard. Broad leaf fill/transmission, stems, alpha
   and contact-footprint code retain their preceding expressions.

This adds no assets, texture samplers, mesh instances, geometry, passes or
independent animation. The crown normal is a presentation approximation inside
an existing sprite; it does not imply a new volumetric tree model. Original
actors and gameplay ownership still govern visibility. Modernized retains its
preceding texture and material branch. EGA Upscaled and Genesis Upscaled remain
separate options. This pass stays local only.

Working if: actual lit/backlit/compact tree studies show bounded colour changes
confined to original tree ownership, an overlapping source actor stays exact,
compact shrub/grass studies retain exact alpha/stems/contact branches, distant
or unresolved crown-light functions return the preceding colour, and Modernized
and both upscale comparisons stay pixel-identical.

The explicit-gradient API follows the official Godot shader function reference:
https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shader_functions.html#shader-func-texturegrad

Verified locally in WebGL: 136 focused checks passed (12 helper, 58 material,
66 draw-pass/foliage), including four positive tree studies, an opaque overlapping
source actor, and six compact shrub/grass studies with identical alpha. All 32
normal playable-view comparisons passed against the preceding pinned build:
13 Modernized views, EGA, EGA Upscaled, Genesis Upscaled, Tactical thermal and
status were pixel-identical. Ten eligible Tactical views changed only inside
the existing 3D destination; opaque reticle ink and HUD remained exact.

The first compact-foliage check failed its new >100 changed-pixel threshold for
grass. Inspection found only 13 changed highlight pixels across three views,
with 165 to 185 covered pixels per view and identical alpha. The corrected
check requires an observable change in every compact orientation, rather than
an inappropriate shrub-sized count. Its original failed log is preserved.

The verified normal package is installed in both local browser copies, SHA-256
c3da68ff148e73b58a76f110f1b36975a1188b4d7e3bfb66fcbd4af9b2ef4e92.
Only its two shader payloads changed; the other 1112 package payloads remain
identical. All 45 BUNDLE records and the existing website verifier passed.
Original game fixtures remain absent from the playable package. Native rendering
and frame-rate changes were not measured. Nothing was pushed or published.
Evidence: artifacts/tactical-arbor-20261012/completion.md.


### Tactical source-face material relief (local, 12 October 2026)

1. **Painted-metal microrelief:** the existing authored steel atlas height field
   now affects diffuse and restrained highlight normals on eligible vehicle,
   aircraft and equipment faces. The preceding texture colour gain is reused.
2. **Mineral depth:** plaster and masonry receive distinct source-unit height
   amplitudes and slope limits. Stone has the stronger response, while plaster
   retains its smoother painted finish.
3. **Soft-material restraint:** timber, canvas, rubber and roofing have their
   own bounded relief profiles. Cloth and rubber stay substantially flatter
   than masonry; authored colours and structural detail are preserved.
4. **Source-face coherence:** a tangent-plane conversion uses the observed
   source-position and UV gradients supplied before owner clipping. Relief
   follows horizontal, vertical and oblique faces; degenerate frames retain
   their preceding normals. Original vertices, silhouettes and ownership stay.
5. **Filtered reuse:** the preceding three atlas reads return their existing
   colour gain plus a signed height gradient. Mirrored folds and unresolved or
   distant relief fade; the model branch caches the sample for the final colour
   multiplier, avoiding another atlas lookup.

This is a bounded shading approximation from the existing grayscale height
textures. It adds no maps, samplers, geometry, draw passes, clocks or game state.
Only recognised model material families 1 to 7 receive the new normal, and only
with verified daylight and the existing texture/detail settings. Crew planes,
glass, terrain, water, sky, foliage, particles, cockpit and HUD retain their
preceding treatments. Modernized remains unchanged; EGA Upscaled and Genesis
Upscaled remain separate options. This pass is local only.

Working if: actual eligible vehicles/buildings show source-owned colour changes,
preceding atlas colour gain is retained, coverage and fresh redraws are exact,
unverified daylight returns the preceding image, tangent/mirror/degenerate
controls pass, and all Modernized/both upscale comparisons stay exact.

The derivative and explicit-gradient APIs follow the official Godot reference:
https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shader_functions.html

Local verification: 33 GPU checks and 138 production-material checks passed.
Eight vehicle/building studies show positive changes, including an oblique
building and an opaque source-actor overlap. All 13 studies retain identical
coverage and source ownership; river, asphalt, tree, crew and sky controls are
exact. Missing-atlas and correctly paired no-daylight renders are exact.
Horizontal/vertical/oblique tangent, mirror, degenerate, distance/footprint and
family slope-limit checks pass. The preceding atlas colour gain is retained.

Two new test issues were repaired without changing production code: the GPU
entry point continued into unavailable fixtures after completing its checks,
and the first no-daylight control compared against a daylight baseline. The
corrected entry point returns, and baseline/current renders now share the same
no-daylight conditions. Initial failed logs are retained alongside passing logs.

All 32 normal playable comparisons are pixel-identical, including 13 Modernized,
EGA and both separate upscale options. These fixed mission views do not show
eligible close relief; the eight positive model studies establish its actual
admission. HUD, opaque reticles, foliage, ground and effects in these captures
remain exact. Both local browser builds are installed with SHA-256
fcb0faa2bde155ae0d6295e58566c00a7142db5b2d7db5af3fca706dcff0f45e.
Only the surface shader and shared material include changed; the other 1112
normal package payloads remain identical. All 45 BUNDLE records and the standard
website verifier pass. Original game fixtures are absent from the playable pack.
No native rendering or FPS delta was measured. Nothing was pushed or published.
Evidence: artifacts/tactical-microfinish-20261012/completion.md.


### Tactical bounded atmospheric depth (local, 12 October 2026)

1. **Distance-based colour depth:** original terrain, river, vehicle, building
   and tree surfaces receive restrained daylight air colour using their observed
   source-world camera-to-surface distance. No new fog volume or depth buffer.
2. **Near-field protection:** surfaces within 600 raw source units retain their
   preceding colour. Model/tree/foliage blending is capped at 10%; terrain at
   16%. Under an identical air path and surface class, colour differences retain
   at least 90% or 84%.
   Original target silhouettes, labels, ownership and occlusion remain intact.
3. **Low-ground density:** an analytic exponential-height path uses the actual
   eye height and surface height. Its bounded density avoids haze inversions at
   nearly equal heights, and keeps elevated surfaces clearer than low ground.
4. **Coherent foliage:** shrubs/grass use that same source-unit function and
   observed eye height. Their renderer units convert back to raw units by 64;
   leaves/stems receive colour depth, while contact material/opacity, instances,
   placement and low canopy height keep their preceding code/data.
5. **World-fixed tint:** a restrained warm sunward/cool opposite palette follows
   the existing Tactical sun. It adds no cloud/texture samples, glow or clocks.

This colour-only pass requires verified daylight, positive observed eye height
and the preceding Tactical presentation switches. Thermal/unverified-light
views, sky/clouds, crew planes, original effects, cockpit, reticle and HUD are
excluded. The existing source ownership still determines visibility. No maps,
samplers, texture reads, geometry, passes, independent weather or game state are
added. Modernized is unchanged. EGA Upscaled and Genesis Upscaled remain separate
options. This pass stays local only.

The change spans the existing surface shader, shared material include and
foliage shader/script so all surfaces use one calculation and the foliage shader
receives real source eye height rather than a guessed constant.

Working if: actual far ground/model/foliage studies show bounded colour depth,
near and unverified-light controls are exact, source coverage and opaque actor
interiors stay exact, height/distance/contrast bounds pass, and Modernized and
both upscale renders remain pixel-identical.

Local verification: 19 GPU path/height/contrast/direction checks, 141 actual
material checks and 67 draw-pass/foliage checks passed (227 total). Ten positive
far material studies and six foliage orientations show bounded atmospheric
colour. Near T-62 and shrub/grass controls are exact; the near model's 2931
admitted vertices have maximum raw distance 458.605. Crew/unclassified-source
controls, no-daylight comparisons, source ownership/coverage, contact material,
instance buffers and fresh redraws pass. The background-ground study protects
all upper sky/woodland and an original opaque actor interior.

The initial near T-62 test extended beyond the 600-unit boundary and showed 32
changed pixels. It was moved entirely inside that boundary. A follow-up distance
assertion also counted the mesh's far background triangles; it now checks only
source-owned eligible model vertices. The distance and image-equality gates were
retained, and both initial failure logs are preserved.

All 32 normal playable comparisons pass. Thirteen Modernized renders, EGA,
EGA Upscaled, Genesis Upscaled, Tactical thermal/status and four source-effect
captures are exact (22 exact overall). Ten eligible Tactical captures change
only within the existing 3D destination; opaque reticle ink, upper sky and HUD
remain exact. Both local browser builds are installed with SHA-256
6e8d6efcf8b5bfa87ca4f9537b11b98106e271e8e44eeb56c68871e7871822e3.
The four named presentation payloads changed; the other 1110 normal package
payloads are identical. All 45 BUNDLE records and the standard website verifier
pass. Original game inputs remain absent from the normal package. No native
rendering or FPS delta was measured. Nothing was pushed or published.
Evidence: artifacts/tactical-aerial-20261012/completion.md.


### Tactical running-gear and roof bevel light (local, 13 October 2026)

1. **Track-link depth:** the existing repeating dark grooves and light link
   edges now receive shallow bevel normals. Existing world-position-linked UVs
   still supply their phase; source geometry and marks stay in place.
2. **Rounded wheel faces:** shallow dish/rim response and the existing spoke
   pattern receive source-face-aligned relief. The polar centre and wrap remain
   finite. The existing wheel footprint/shape/colour and motion coordinates stay.
3. **Pitched-roof courses:** existing tile courses and staggered joints gain a
   restrained bevel light response. Joint relief fades at course boundaries;
   roofing family admission keeps stone trim/plinths out of the roof treatment.
4. **Flat-roof seams:** the preceding seams receive a shallow normal bevel,
   preserving painted colours, source silhouettes and existing roof detail.
5. **Filtered, combined finish:** supplied pre-ownership UV derivatives filter
   each bevel, with distance/unresolved detail fade. Macro and texture height
   derivatives combine before the existing material slope cap once, preventing
   stacked normal limits. No additional texture lookup, clock or moving phase.

This is normal/light refinement inside existing graphical marks, not displaced
geometry or new hardware. Verified daylight and the existing Tactical detail
switches are required. Thermal/unverified-light frames, glass, walls, stone trim,
ground, water, foliage, sky, effects, crew, cockpit and HUD retain their preceding
treatments. Only the surface shader changes in the normal playable package.
Modernized is unchanged; EGA Upscaled and Genesis Upscaled remain separate.
This pass is local only.

Working if: actual admitted wheel/track/roof studies show bounded bevel lighting,
phase changes/restores follow original world-position inputs, coverage/opaque
source ownership and fresh redraws remain exact, distant/unsupported-material
controls converge to the preceding finish, and Modernized/both upscales retain
pixel identity.

Local verification: 22 GPU derivative/profile/polar/slope-cap checks and 153
actual source-model checks passed (175 total). Seven positive studies cover
T-62/M113 running gear, BTR-70 tyres/hubs, flat/pitched/farm roofs and roof overlap.
Seven exact controls cover the untagged truck, distant roof, river, road, tree,
crew and sky. Coverage, source ownership, overlapping actor interiors,
unverified daylight, source-position phase restoration and Modernized switchback
checks pass.

The initial truck-positive fixture was wrong: that authored asset has no
moving-wheel metadata. It now remains an exact control; the catalog-tagged
BTR-70 verifies wheeled-vehicle relief instead. The three failed assertions
are retained in the evidence log. No production change was needed.

All 32 normal playable comparisons pass. Thirteen Modernized views, EGA,
EGA Upscaled, Genesis Upscaled and Tactical thermal/status are pixel-identical.
Thirty captures are exact overall; gunner and effects-gunner each differ by one
pixel inside the 3D destination. Close-up material studies establish the visible
positive bevel treatment. Opaque reticle ink, HUD and upper sky remain exact.
Both local browser builds are installed with SHA-256
00f2fd6992d60185a481af1c5776136bebf70d55e35b2587d768ae113df9f1be.
Only the surface-shader payload changes; the other 1113 payloads are identical.
All 45 BUNDLE records and the standard website verifier pass. Original game
inputs remain absent from the normal package. Native rendering and FPS delta
were not measured. No shared runtime or other-task browser was controlled.
Nothing was pushed or published.
Evidence: artifacts/tactical-bevel-20261013/completion.md.


### Tactical textured sheen (local, 13 October 2026)

1. **Painted armour:** existing paint texture modulates highlight width, giving
   painted steel a restrained uneven finish while keeping authored colours.
2. **Roofing:** the same filtered signal gives roof material local sheen
   variation. Existing clay, slate and ridge colours and bevel normals remain.
3. **Rubber, timber and canvas:** their separate, subdued family responses stay
   distinct; stone and plaster retain their exact matte response.
4. **Filtered detail:** the cached atlas gain already contains mip, footprint and
   source-distance fading. Neutral/unresolved gain restores the preceding lobe.
   Existing eye-angle/distance glint filtering remains in place.
5. **Bounded cost and brightness:** peak strength never exceeds the preceding
   family peak; broadening lowers the peak. No new texture reads, maps, samplers,
   geometry, passes, clocks or source game state. Some shader arithmetic is added.

The atlas gain is a decorative roughness cue, rather than a measured roughness
map or a physical reflectance simulation. Diffuse light, colour gain, source
ownership, geometry and the preceding surface relief are unchanged. Only
already-admitted cached daylight samples affect the new response; unavailable
atlas, reduced detail and thermal/unverified daylight keep the preceding finish.
Modernized is unchanged. EGA Upscaled (original colours) and Genesis Upscaled
remain separate options. This pass is local only.

Working if: actual vehicle/roof/architecture studies show source-owned sheen
changes, material width/peak and neutral/matte GPU controls pass, coverage and
opaque actor occlusion stay exact, missing-atlas and unverified-light captures
return the preceding finish, and Modernized/both upscale renders stay exact.

Local verification: 58 GPU material-width/peak/neutral/matte/filter checks and
154 actual material assertions passed (212 total). Eight source-model studies
show positive changes; five representative paint/roof studies exceed 100 changed
pixels. Six distant/river/road/tree/crew/sky controls are exact. An isolated
truck-canvas comparison changes 53 pixels, all inside 23348 visible canvas pixels;
atlas colour, normals and other material families are held identical. Source
coverage, opaque occlusion, packet/geometry, no-daylight and missing-atlas checks
pass.

Initial diagnostic views poorly exposed reflected light. The sunward fixture
also needed the shader's source-Y inversion. Its corrected orthonormal basis is
checked directly. A generic 100-pixel minimum was unsuitable for small/low-peak
probes; admission now requires a positive difference, with a separate 100-pixel
visibility gate on five representative studies. All preservation assertions
remain exact. The three initial failed logs/reports are retained. Production
brightness was never increased to satisfy those fixtures.

All 32 normal playable comparisons are pixel-identical, including 13 Modernized
views, EGA and both separate upscale options. These frozen mission views do not
expose resolved close sheen; the actual model studies establish positive
integration. Both local browser builds are installed with SHA-256
8c4688276de45482f5f8b46467f7c277caf31c43904f9345a2985f66fd71be55.
Only the surface shader changed in the normal package; the other 1113 payloads
are identical. All 45 BUNDLE records and the standard website verifier pass.
No original game inputs were added to the normal package. Native rendering and
FPS impact were not measured. Other-task browsers and the shared native runtime
were left untouched. Nothing was pushed or published.
Evidence: artifacts/tactical-sheen-20261013/completion.md.


### Tactical daylight environment and foliage depth (local, 13 October 2026)

This broader pass implements 22 visual refinements and six preservation/cost
boundaries across the existing sky, reflections, terrain, source models and
vegetation. Its full 28-item implementation list is in
artifacts/tactical-radiance-20261013/completion.md.

The shared material include supplies bounded hemisphere fill, a directional
horizon palette, broad solar aureole and cloud colour response. Sky sampling
retains the preceding cloud field; its lighting direction explicitly undoes the
source camera's y sign. Existing water/glass reflection rays already use
source-world coordinates, so their wrapper shares the same sky. Existing air
colour uses that horizon palette without changing near protection, density,
blend ceilings or contrast-weight calculation.

Known vehicle/architecture families, grass/road relief and classified earth
slopes receive restrained ambient ratios. Nearby shrub/grass leaves and stems
use their existing normals, height gradient and distance fade. Existing tree
canopies, trunk spans, distant hedges and distant crown underpaint receive
filtered directional fill. The display-space environment ratio is bounded to
0.94 through 1.06 before material-strength blending and colour-space conversion.
This is colour/light refinement, with no physical shadow or weather simulation.

Vertices, source ownership, foliage ground admission, instance generation,
contact alpha, cutouts, cloud/noise sampling, atlas filtering, surface relief and
preceding sheen calculations remain exact. No new textures, sampler reads,
noise octaves, geometry, passes, clocks or game state are added. Shader arithmetic
is added; native rendering and FPS impact remain unmeasured. Modernized and both
separate upscale choices remain unchanged. Nothing was published in this pass.

Working if: actual sky/model/terrain/tree and near/far foliage studies show the
bounded treatment, source coverage and opaque occlusion stay exact, unsupported
and unverified-light controls retain their preceding renders, and playable
Modernized/upscale/thermal/HUD/sight preservation checks pass.

Local verification: 60 GPU checks, 195 actual material assertions and 69
near/far draw-pass/foliage assertions pass (324 total). Seventeen material/sky
studies show positive changes, with two exact controls and zero coverage or
ownership escapes. Near/far foliage, buffers, contact opacity, fresh redraws,
opaque blockers and unverified-light checks pass. All checks passed first run.

All 32 playable comparisons pass. Thirteen Modernized views, EGA and both
separate upscale choices, Tactical thermal/status and four source-effect views
are exact (22 exact overall). Ten Tactical views change within the existing 3D
camera destination only. HUD outside the camera and opaque sight ink stay exact.
Both local browser builds are installed with SHA-256
137c97cc684117c6d8c19ffa8c4a1b5565111cdb611cd43e835f8bdd4a875dca.
The three shader/include payloads change; the other 1111 payloads are identical.
All 45 BUNDLE records and the standard website verifier pass. Original game
inputs remain absent from the normal package. Nothing was pushed or published.
Native rendering and FPS impact remain unmeasured.

### Tactical water and glazing optics (local, 13 October 2026)

The existing opaque water and glazing facets gain a bounded, texture-sensitive
optical colour response. Water retains more body colour head-on and a stronger
sky response at grazing angles. Its existing world-anchored crossing waves now
separate subdued crests and troughs, with a continuous colour tail after fine
normal relief fades. The existing material fields supply green/blue/sediment
variation; no river or bank geometry is changed.

Eligible truck, helicopter and building glazing retains its authored dark pane
colour head-on and gains a stronger oblique reflection. Both water and glass
blend the existing sky palette into an analytic earth/grass lower hemisphere.
This is a broad colour tint without reflected objects, banks or hidden actors.
Their existing atlas gain supplies a decorative roughness cue, with broader,
lower-peak highlights on rougher patches and screen-footprint-aware filtering.
Glint peaks are capped at 0.055 for water and 0.075 for glazing before their
existing visibility/distance gates. The fixed Tactical sun direction is shared.

Only Tactical, verified daylight, a ready atlas and enabled surface detail admit
this refinement. Preceding fallback functions remain byte-identical. Modernized,
original EGA, EGA Upscaled (original colours) and Genesis Upscaled are retained.
Coverage, source geometry/ownership, depth, thermal paths, HUD and sights stay
under their existing authority. No texture, sampler, atlas read, geometry, clock
or drawing pass is added: the preceding final colour sample is cached for both
roughness and colour. Shader arithmetic is added; no FPS improvement is claimed.

Working if: actual water and eligible glazing studies show the treatment only
inside their original admitted facets, opaque blockers and mode switchbacks are
exact, unsupported-light/atlas controls match the preceding build, and normal
playable Modernized/upscale/HUD/thermal comparisons pass. Verification and local
installation are recorded in artifacts/tactical-optics-20261013/completion.md.

Local optics acceptance is complete: 34 GPU checks and 231 actual material
assertions pass. Seventeen source-model studies include eleven positive cases
and six exact controls, with zero coverage/ownership/occluder changes and an
explicit eligible-facet mask. All 32 normal playable comparisons pass; thirteen
Modernized views, EGA and both separate upscales are pixel-identical. Thirty-one
views are exact overall; 229 Tactical commander-scan pixels change inside 3D
only. HUD, map, thermal/status, source effects and opaque sight ink remain exact.
Both local normal PCK copies now match SHA256
6c835fcaec4606ed83cffd446d4f290c21cffab5cb5d6c5a4705abe491c4588f.
Only the surface shader payload changes; the other 1115 payloads are identical.
All 45 BUNDLE records and the static website verifier pass. No original game
inputs/private diagnostic hooks were added. Native rendering and FPS remain
unmeasured by this chat. No publication occurred. Evidence:
artifacts/tactical-optics-20261013/completion.md.


### Tactical terrain atlas lighting (local, 13 October 2026)

The existing meadow, soil and asphalt height samples contribute to source-face
lighting as well as colour. Each family has a separate shallow slope budget.
Broad and microscopic relief combine into one bounded normal. Meadow remains
soft, soil deeper and asphalt flatter. The existing terrain warp Jacobian,
source-world XY/YZ/XZ planes, mirrored orientation and filtered slopes remain.
The ambient height gradient projects directly onto the original face. The
incumbent pre-clipping coordinate-derivative block is unchanged.

Dry asphalt gains a low, broad, texture-sensitive sun response, capped at0.018
before facing, footprint and distance attenuation. It adds no wet reflection,
puddles, stones, ruts or markings. Current grass/earth/road colours, meadow
blades, continuous distant colour tail and anisotropic mip sampling remain.

Modernized and admission-off states use the original compiled surface program.
A separately cached Tactical variant is selected only with active Tactical
geometry, bound/ready atlas, enabled detail/variation/polish and finite verified
daylight. The existing material and bindings remain; no mesh rebuild or game
tick is requested. The variant extends the original source using checked exact
anchors and one helper include, rather than duplicating the whole shader. It
shares the exact existing painter/depth injection. The existing small cold-start
prewarm also compiles it; there is no new per-frame pass or scene geometry.
Owner-controlled uniform changes refresh selection, including retained cached
frames and mode-only switching. Exact fallback comparisons are not weakened.

The existing three atlas reads are reused for material light and final colour.
No new texture, sampler, clock, simulation or tactical information is added.
EGA Upscaled (original colours) and Genesis Upscaled remain distinct.

The local build passed46GPU and265material checks,32strict paired-playable
comparisons, and seven map-repeat controls. All13Modernized comparisons and
both upscales retain exact pixels. Both local browser packages contain the
accepted terrain/brown-hill candidate. Original geometry, ownership and actor
coverage are preserved; all45website BUNDLE records verify. Nothing is published.
Evidence and the completed finite40-item plan remain in
artifacts/tactical-groundlight-20261013/.

Working if: admitted Tactical terrain shows bounded material light on original
facets; admission-off transitions select the exact incumbent program and pixels;
mode/cached transitions preserve geometry and bindings; Modernized and both
upscales retain their pixels; both local packages contain the tested candidate.

### Tactical brown hills, local refinement

The pending terrain-lighting variant now rebases only verified brown hill
materials17 and26 onto continuous dry-loam colour, with muted mineral grains,
soft world-height strata and slope-sensitive exposure. It reuses the existing
filtered hill samples and soil-atlas gain. Original hill silhouettes, positions,
ownership, cover and collisions remain unchanged. Green hill recipes,
Modernized, unavailable-atlas and admission-off rendering keep their incumbent
paths. No texture, sampler, simulation clock or geometry is added.

This extension is verified and installed in both local browser packages.
The source-bound brown-hill and oblique studies have exact geometry, ownership
and actor coverage. Modernized and both upscales remain unchanged. See the
terrain-lighting acceptance record above; nothing is published.

Working if: brown slopes show continuous earth/mineral colour on their existing
faces; strict fallback and Modernized controls pass; no other objects receive
hill paint; both local packages contain the accepted candidate.

### Tactical rough-surface diffusion (local pass)

A separately compiled Tactical variant adds bounded rough diffuse response to
paint, plaster, masonry, timber, fabric, rubber, roofing, meadow, soil and
asphalt. The correction is inspired by Oren-Nayar angular scattering, blended
conservatively into the established sun/sky fill. The existing filtered atlas
gain supplies a shallow decorative cavity cue. It is not a measured ambient
occlusion map or a new shadow system. Accepted specular lobes remain separate.

No texture/sample, geometry, derivative, clock or per-frame pass is added.
Brightness is bounded and the correction attenuates continuously with distance
and pixel footprint. Water, glass, foliage, sky, skin, effects, original source
ownership and thermal paths are outside the treatment. Original Surface and
the accepted brown-hill helper remain byte-identical. Modernized/admission-off
use their exact original compiled program.

Verified and installed in both local browser packages. Actual WebGL checks
passed: 101 mathematical cases, 370 material checks, 20 source-model studies
and 32 paired playable views. All 13 Modernized comparisons, EGA and both
upscales are pixel-identical. Tactical differences stay inside the original
3D camera; map, HUD and opaque reticle ink remain exact. Four full-frame
map-station repeats and three cross-build map/HUD comparisons are exact.

The source studies use isolated cameras around original game models. Native
rendering and an FPS delta were not measured by this pass. Nothing is
published. Evidence and the detailed 60-point plan:
artifacts/tactical-diffusion-20261013/.

Working if: only admitted source-owned material facets change; positive source
studies and mathematical cases pass, masks/actors/mode/fallback controls remain
exact, both local browser packages contain the tested candidate and Modernized
plus both upscales retain their pixels.

### Tactical material grain (local pass)

The source implementation adds smooth, material-specific coordinate variation
to the existing detail atlas on classified paint, plaster, stone, timber,
fabric, rubber and roofing. The exact Jacobian carries the transformed texture
footprint into the existing filtered sampler and pulls its relief slopes back
into the original source-model UV plane. Semantic markings, model shapes,
terrain, foliage, skin and the original Surface programme remain untouched.

No new atlas reads, sampler, geometry, clock, GPU derivative reads or render
passes are added. The accepted diffusion and ground-light helpers remain
byte-identical. Modernized retains its original compiled programme.

Source and private packages are prepared. Runtime acceptance and local browser
installation are pending a separately admitted QA window after the other
tasks' owed resource slots. Installed local packages retain the preceding
verified pass. Nothing is published. Detailed plan and evidence:
artifacts/tactical-finishgrain-20261013/.

Working if: the admitted model materials show stable grain and coherent relief
in the real rendered checks, protected material/mode pixels remain exact, and
both local browser packages contain the tested candidate after verification.

### Local Tactical refinement, 14 October 2026

Tactical now adds filtered material-grain colour separation, subtle finishing along verified straight road faces, consistent near/distant tree colours, grounded shrub shading and broad particle volume. These treatments preserve source geometry, cover, event timing and ownership; road edges remain inside the observed road polygons, with junction and ambiguous geometry rejected. Modernized uses its unchanged shader and shared helpers.

Priority instrument values have more visual emphasis; gauge ticks follow the original cells. Tactical map corners retain source-edge midpoints and tangents while joining straight segments with zero endpoint curvature. Small components, narrow corridors, diagonal/multi-class junctions and unknown LOCAL stencils remain protected. Menus explain the six existing graphics choices: EGA Upscaled keeps the original palette and skin colours; Genesis Upscaled is the existing generated high-resolution artwork option.

This pass is verified and installed locally, with the original simulation and accepted HUD performance improvement retained. The separate experimental mask cache was rejected by its measured performance gate. Evidence and per-item dispositions are recorded in `artifacts/tactical-complete-polish-20261014/`.

### Full-quality reset, 14 October 2026

Graphics now offers **Restore full-quality defaults (4× / 16×)**, also available in the browser's extended controls. This explicit action restores 4× MSAA and 16× anisotropic filtering together. The selected graphics mode, HUD style, retained unavailable-mode preference and audio mix remain unchanged. Failed preference writes retain the live full-quality settings and show a settings warning. No automatic quality reduction is introduced.
