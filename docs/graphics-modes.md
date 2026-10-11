# Live graphics modes

The original PC executable owns every frame, input, transition, value and rule.
The graphics selector never requests an emulator frame or changes game state.
Assets are validated and loaded at startup. Switching uses the currently cached
source framebuffer, presentation metadata and paired world texture synchronously.

* **EGA** displays the exact original 320×200 RGB framebuffer, including source
  glyphs and colours. The display scales those pixels with nearest sampling.
  Every presentation overlay and world-compositing shader is bypassed.
* **Genesis** uses extracted original-resolution Genesis images, with nearest
  sampling to the PC-owned layout. It does not downsample generated artwork.
  Unmatched and dynamic regions retain the current original PC pixels. This is
  a partial-donor presentation, not emulation of the Genesis version. A missing
  or invalid complete native pack rejects the switch and preserves the prior mode.
* **Upscaled** restores the existing high-resolution artwork, typography and
  scanout-paired world. Its existing provenance and visibility gates still apply.
* **Modern** uses refined source-bound low-poly geometry, illustrated foliage
  and a restrained daylight palette, composed with the restored Upscaled UI.
  Buildings have fine plaster grain and muted clay roofs; hills and grass have
  broad colour variation, and water has subdued, distance-filtered ripples.
  It requires the local Modern asset catalogue and supported PC files.
  Unsupported sensor palettes retain source rendering. See [renderer boundaries](modern-renderer.md).
* **Tactical** uses the same source-bound Modern geometry and restored UI with
  Calibration Range-inspired olive terrain, directional surface shading, a
  pale overcast sky, clustered hedgerows and a distant illustrated treeline.
  Horizon vegetation is grounded on the observed PC sky/ground boundary;
  original terrain and actors always appear in front of this underpaint.
  Tactical shades a tapered stem within each source tree's trunk plane to
  prevent filtered texture alpha from erasing it. Original ownership still clips it.
  It requires the same Modern assets. This is a separate
  graphics mode: choosing Modern restores its existing palette exactly. The
  source camera, terrain silhouette, actor visibility and gameplay remain PC-owned.
  No decorative Range hills or trees are added to the battlefield geometry.

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

Working if: every verified station uses its own 16:9 layout, all live source cells
remain visible, unknown overlays return to full 4:3, and Restored removes the reflow.

The dedication to David "Ming" Kenny remains on the final credit card in Genesis
and Upscaled, and is inherited by Modern and Tactical. EGA is deliberately untouched, so its framebuffer contains the
original credits. EGA, Genesis and Upscaled keep their existing vehicle rendering. Modern and Tactical share the same replacement geometry.

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

## Integration

`pc_tandem_frame.gd` provides:

* `load_graphics_sources(root)` once at startup.
* `set_frame(source, presentation, world, program)` for a newly paired frame.
* `present_frontend(program)` for program-aware frontend routing.
* `set_graphics_mode("ega" | "genesis" | "upscaled" | "modern" | "tactical")` for immediate switching.

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
