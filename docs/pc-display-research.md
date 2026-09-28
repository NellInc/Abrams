# Native-resolution play window

## Display contract

`Play.command` selects a clean game window instead of the diagnostic comparison
layout. The original 320x200 display retains its historical 4:3 presented aspect.
The largest integral 4:3 rectangle fits inside the actual window; black bars
cover the remainder. No extra scenery, tactical data or research labels appear.
`PC Bridge.command` and `Play.command --compare` retain the comparison layout.

The composed interface renders directly at that rectangle's physical pixel size.
The world renders at an integer multiple of the original camera clip dimensions.
That multiple covers both display axes, including the original rectangular-pixel
stretch. The camera's exact aspect, asymmetric frustum, near plane, projected
centre, source visibility and zoom remain unchanged. Window shape never becomes
camera shape. The original software renderer and original input path still run.

Working if: every supported window shape shows the entire original 4:3 frame;
projection checks retain the same original-pixel coordinates; the first resized
composite uses current scenery; and resizing cannot write guest state or send keys.

`godot/scripts/pc_play_display.gd` owns display geometry and its child-first
viewport hierarchy. `pc_bridge_viewer.gd` supplies the same original frames,
read-only draw passes and remastered assets as the research layout. Its hidden
research labels are never presented over the play screen. Native resize signals
update render targets even while the original is paused or showing a menu.

Godot's Window size is measured in physical pixels. Play disables root content
scaling and uses the actual resulting size, including operating-system limits.
Requested startup dimensions are applied after engine startup, because project
window overrides otherwise replace sizes assigned in SceneTree initialization.
See the [official Window documentation](https://docs.godotengine.org/en/stable/classes/class_window.html#class-window-property-size)
and [resolution guide](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

## Controls

* `./Play.command`: resizable play window, initially 1280x960.
* `./Play.command --fullscreen`: native fullscreen; native window controls can
  also enter and leave fullscreen.
* `./Play.command --window-size 1920x1080`: requested initial physical window size.
* `./Play.command --compare`: the existing side-by-side diagnostic layout.

No keyboard shortcut was reserved or intercepted. Enter, Escape and all original
function keys keep their original meaning. Fullscreen is a presentation option,
not an original menu entry. This pass adds no persistent preferences or new
save-state behaviour. Audio remains the existing explicit `--audio` option.

## Acceptance coverage

`godot/tests/test_pc_play_display.gd` checks the actual production display graph:

* Six display sizes from 640x480 through 3840x2160, portrait and odd dimensions,
  all four station clips, three focal lengths and five camera-space points.
* Exact camera aspect and original-pixel projections; at least one rendered world
  sample per output pixel in both axes; balanced, maximal 4:3 letterboxing.
* First-render resizing across five distinct clip/colour/size combinations,
  followed by original-frame fallback for each.
* Recorded original draw passes for all four stations at two window sizes.
* Full-frame source/UI/world composition, including black letterbox pixels.

At an exact texture boundary, floating-point nearest sampling may choose either
adjacent texel. The oracle accepts only those specific neighbours at verified
boundaries, with no colour tolerance and no arbitrary nearby-pixel allowance.
Boundary detection uses exact integer ratios, including intermediate world texel
coordinates, rather than float32 epsilon tests. All non-boundary comparisons
remain exact RGB. The initial strict-floor oracle
failed at these ties; a separate Python examination of the gunner fixture found
all 21,107 retained-UI mismatches on exact boundaries, none elsewhere. Its failed
report is retained under `artifacts/pc-native-display-tests-01/`. Seven residual
mismatches in the first boundary-aware oracle were also exact world-texel ties:
independent Python rational arithmetic and captured world images proved every
one a valid adjacent sample. That proof is retained in
`artifacts/pc-native-display-diagnostics-03/rational-boundary-proof.json`.

`godot/tests/test_pc_play_resize.gd` subclasses the production viewer solely for
acceptance: it uses the real original-PC host, freezes one completed capture,
resizes the actual window four times, enters fullscreen, and returns to a window.
It requires identical original state/presentation/framebuffer and no added guest
samples, native-size render targets, exact window/composite RGB matching and
clean letterboxes. The initial fixture did not require the requested return size,
so its passing result was insufficient: the OS had ignored a resize requested
before fullscreen exit completed. It now waits for the mode transition before
resizing and asserts the exact requested size. These are frozen-frame presentation
tests, not timing parity
for an entire interactive campaign.

Final local evidence is recorded in `WORK_LEDGER.md`. The implementation and
visual inspection are by the same assistant, not independent art acceptance.
All original sources and generated artifacts stay local; no publication occurs.

## Reproduction

From the repository root, using the retained local source captures:

```sh
./tools/godot.sh --headless --quit-after 1200 \
  --script res://tests/test_pc_play_display.gd
./tools/godot.sh --disable-render-loop --quit-after 2400 \
  --script res://tests/test_pc_play_display.gd -- --native \
  --fixture "$PWD/artifacts/pc-cockpit-trace-05/report.json" \
  --output "$PWD/artifacts/pc-native-display-tests-NEW"
./tools/godot.sh --disable-render-loop \
  --script res://tests/test_pc_play_resize.gd -- --play --trace --capture \
  --capture-station gunner --output "$PWD/artifacts/pc-native-window-resize-NEW"
./tools/validate.sh
```

The window test opens and closes only its own Godot window and original-PC host.
Fullscreen changes are confined to that window. No source files are redistributed.
