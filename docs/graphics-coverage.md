# Whole-graphics restoration register

## Source precedence and completion criteria

The scope remains **all graphics**, including gauges, portraits, information
screens, menus, world art and effects. Genesis is the primary visual basis
wherever its corresponding graphic exists. The original PC executable owns
gameplay, information, controls, layout constraints and visibility.

A family is finished only when its required variants are inventoried, its
Genesis availability is checked, its high-resolution assets are authored and
reviewed against the source, its live PC binding preserves displayed information,
and its applicable native transition/damage/motion checks pass. A gallery image
or exact source decode alone does not satisfy this gate.

Working if: a completed family has source, authored-asset, live-binding and
native-proof pointers; any PC-derived visual has an explicit Genesis-gap reason.

This is a finite family-level work register. The complete per-variant denominator
is still being recovered; no overall completion percentage is justified.

| Family | Genesis source availability | Authored art / live status | Required remaining work |
|---|---|---|---|
| Four cockpit surrounds | All four extracted | Five-image cockpit/status pack; four stations live with original visibility and moving roof | Remaining trims and aliasing at original silhouettes; all state variants and motion acceptance |
| Gunner static instruments | Present in gunner extract | Nine illustrated cells live, pixel/provenance gated | Other symbols and colour/state variants |
| Dynamic gauges and reticles | Corresponding Genesis gauges visible | PC values use verified scalable type; most bars, reticles and orientation graphic remain original | Source-driven high-resolution bars, bearing/reticle lettering, rotating hull/turret diagram; no hidden information |
| Systems status | Native CHECK DAMAGE captured exactly | Genesis background and pristine schematic live; twelve labels and six values scalable | Actual damaged schematics and lamp art; original fallback remains until verified |
| Title and credits | Title extracted; complete credits variants unverified | Title v1 in gallery | PC title/credits bindings, original animation and transitions |
| Briefing office and Wilson | Office and two observed Wilson poses extracted | Office, Wilson neutral and lower-hand gesture in gallery | All mouth/gesture variants; registration across animation; original briefing/debrief display binding |
| Crew portraits | Four native crew-information portraits extracted | Four 1254x1254 derivatives; fully matched source faces bind to live crew lines, native gunner and loader verified | Live commander/driver evidence, injury/talking/other poses and radio bindings |
| Motor pool | Native scene extracted | Background v1 in gallery | PC setup controls, allocation values, menu visibility and transitions |
| Crew information | Native diagram and portrait placements extracted | Four portrait derivatives; whole-page study rejected for added boxes/layout drift | Faithful complete page composition and PC information-flow binding |
| Ammunition information | AX, HEAT and SABOT pages reconstructed exactly | AX and SABOT illustrations at 2172x724 in gallery; HEAT revision blocked by image tool | HEAT art, original text/layout composition, animation variants and PC binding |
| Armament information | Coax, cannon and smoke pages reconstructed exactly | Untouched extracts prepared; high-resolution illustration work open | Three weapon illustrations, live labels/values, correct PC content and bindings |
| Recognition information | Genesis counterpart not yet fully inventoried | PC IDENTIFY only a format/layout oracle | Find Genesis equivalents before selecting visual donors; all vehicle identities and pages |
| Maps and mission information | Commander map visible; long-range and mission pages incomplete | Original PC map retained live | Complete Genesis references, scalable map symbols, original information/visibility, briefing/debrief mission variants |
| Menus, pause, saves, scores, endings | Some Genesis menus captured; full families unverified | Original PC flows retained | Inventory complete states, source-matched hi-res frames/type, original focus/input/saved-game behaviour |
| World vehicles and objects | Genesis imagery/palette available; geometry/variant correspondence incomplete | Original PC geometry and visibility live; earlier PC model studies are unaccepted | Genesis-first materials/detail for each class; maintain PC silhouettes where visibility matters; all views, damage and effects |
| Terrain, buildings and vegetation | Native scenes and palette captured in part | Grass and seven selected original surfaces have detail | Remaining terrain/object materials, horizon variants and source-consistent silhouettes |
| Explosions, smoke, tracers and damage overlays | Native Genesis variant inventory incomplete | Original PC effects retained live | Extract Genesis effect families, remaster all frames, bind to original timing and occlusion |
| Fonts, cursors and interface symbols | Some glyph correspondence found, complete font inventory open | Verified PC text rendered with scalable substitute font | Faithful Genesis typography across all glyphs, native source-layout controls, non-Latin/unknown glyph policy if applicable |

## Current source and output pointers

* `local-art/genesis/source/source-manifest.json`: original first collection.
* `source/systems-status-receipt.json`: STATUS crop and exact VDP reconstruction.
* `source/wilson-animation-v1/manifest.json`: two observed poses, not all poses.
* `source/crew-information-receipt.json`: four 48x48 portrait crops and full page.
* `source/info-v1/manifest.json`: six information pages and illustration crops.
* `local-art/genesis/cockpit-v2/manifest.json`: default runtime set and hashes.
* `local-art/genesis/remastered/crew-v1/manifest.json`: four selected portraits,
  original prompts and rejected coarse-outline variants.
* `local-art/genesis/remastered/info-v1/manifest.json`: ammunition illustrations,
  failed candidates and exact HEAT safety-filter rejection.

Paths abbreviated with `source/` above are under `local-art/genesis/`.
The image tool rejected the HEAT contour-cleanup revision with HTTP 400 at output
moderation, category `illicit`. No replacement image was returned. It was not
retried through a differently worded request or another image route. The earlier
coarse candidate is retained and excluded from the selected gallery set.

The art-review gallery has 15 pages, including isolated portrait and ammunition
illustrations. The cockpit/status, verified instrument cells and eligible crew portraits
bind these new images into the original-PC tandem. Portrait evidence is in
`genesis-portrait-integration.md`. Gallery availability must
never be reported as completed live-game integration.
