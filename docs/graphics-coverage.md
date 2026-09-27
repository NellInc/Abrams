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
| Briefing office and Wilson | Office and two observed Wilson poses extracted | Office, neutral/speaking Wilson and a Genesis-derived facepalm live; exact visible 8x8 dialogue gets scalable lettering | Other CO poses, mouth variants, all dialogue layouts and partial-draw transitions |
| Crew portraits | Four native crew-information portraits extracted | Four 1254x1254 derivatives; fully matched source faces bind to live crew lines, native gunner and loader verified | Live commander/driver evidence, injury/talking/other poses and radio bindings |
| Motor pool | Native scene and menu extracted | Clean-contour v2 live; seven verified scalable text runs and complete-source-gated Genesis panel; governor, all three allocation fields and mission reentry checked | Partial/unrecognized drawing retains PC pixels; remaining limits, settings and transition variants |
| Crew information | Native diagram and portrait placements extracted | Four portrait derivatives; whole-page study rejected for added boxes/layout drift | Faithful complete page composition and PC information-flow binding |
| Ammunition information | AX, HEAT and SABOT pages reconstructed exactly | AX and SABOT illustrations at 2172x724 in gallery and original-PC pages; HEAT revision blocked by image tool | HEAT art, scalable original text/layout, remaining variants |
| Armament information | Coax, cannon and smoke pages reconstructed exactly | Three high-resolution Genesis-derived illustrations in gallery and original-PC pages, palette revision selected | Scalable PC labels/values, top-down tank highlights and page frames; remaining variants |
| Recognition information | Genesis counterpart not yet fully inventoried | PC IDENTIFY only a format/layout oracle | Find Genesis equivalents before selecting visual donors; all vehicle identities and pages |
| Maps and mission information | Commander map visible; long-range and mission pages incomplete | Original PC map retained live | Complete Genesis references, scalable map symbols, original information/visibility, briefing/debrief mission variants |
| Menus, pause, saves, scores, endings | Some Genesis menus captured; full families unverified | Original PC flows retained | Inventory complete states, source-matched hi-res frames/type, original focus/input/saved-game behaviour |
| World vehicles and objects | Genesis imagery/palette available; geometry/variant correspondence incomplete | Original PC geometry and visibility live; earlier PC model studies are unaccepted | Genesis-first materials/detail for each class; maintain PC silhouettes where visibility matters; all views, damage and effects |
| Terrain, buildings and vegetation | Native scenes and palette captured in part | Grass and seven selected original surfaces have detail | Remaining terrain/object materials, horizon variants and source-consistent silhouettes |
| Explosions, smoke, tracers and damage overlays | Native Genesis variant inventory incomplete | Original PC effects retained live | Extract Genesis effect families, remaster all frames, bind to original timing and occlusion |
| Fonts, cursors and interface symbols | Four PC faces decoded; all 95 printable Genesis stencil glyphs match PC STENCIL | Original glyph meshes replace the substitute font in verified cockpit, arming and office runs, with exact source metrics | Remaining Genesis font families, high-resolution bindings for source-only pages, cursors and symbols; unknown glyphs retain original pixels |

## Current source and output pointers

* `local-art/genesis/source/source-manifest.json`: original first collection.
* `source/systems-status-receipt.json`: STATUS crop and exact VDP reconstruction.
* `source/wilson-animation-v1/manifest.json`: two observed poses, not all poses.
* `source/crew-information-receipt.json`: four 48x48 portrait crops and full page.
* `source/info-v1/manifest.json`: six information pages and illustration crops.
* `local-art/genesis/cockpit-v2/manifest.json`: default runtime set and hashes.
* `local-art/genesis/remastered/crew-v1/manifest.json`: four selected portraits,
  original prompts and rejected coarse-outline variants.
* `local-art/genesis/remastered/armament-v1/manifest.json`: three armament illustrations,
  source and image hashes, exact prompts and superseded palette candidates.
* `local-art/genesis/remastered/info-v1/manifest.json`: ammunition illustrations,
  failed candidates and exact HEAT safety-filter rejection.

Paths abbreviated with `source/` above are under `local-art/genesis/`.
The image tool rejected the HEAT contour-cleanup revision with HTTP 400 at output
moderation, category `illicit`. No replacement image was returned. It was not
retried through a differently worded request or another image route. The earlier
coarse candidate is retained and excluded from the selected gallery set.

The art-review gallery has 18 pages, including isolated portrait, ammunition and armament
illustrations. The cockpit/status, verified instrument cells, eligible crew portraits and
matched office/Wilson scenes and the motor pool bind these images into the original-PC tandem.
Portrait evidence is in `genesis-portrait-integration.md`; the extra live
facepalm derivative and briefing evidence are in `genesis-briefing-integration.md`;
motor-pool evidence is in `genesis-motor-pool-integration.md`; five information
illustration bindings are in `genesis-information-integration.md`. Gallery availability must
never be reported as completed live-game integration.
