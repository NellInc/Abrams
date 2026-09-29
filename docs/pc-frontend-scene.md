# Opening scenario preview

The opening scenario selector uses START's separate `ANIM.TBL` renderer.
Previously only its typography and FRAME surround were upgraded. The scenery
now participates in Upscaled and Modern while the PC executable continues to
own every selection, animation step and input.

## Source binding

The observer pins START.EXE, ANIM.TBL and SHAPE.TBL. Read-only callbacks copy
completed draw data and backing VGA planes without changing guest memory,
registers, VGA latches or emulated cycles. Native hooks are stateless, so the
observer checkpoint ABI remains unchanged. Rebuild the trace core to obtain
`frontend_scene_schema: 1`.

Every replayed polygon uses the original chosen primitive, actual matrix,
camera, palette, painter order and clip. Computed vertices are checked against
the original transformed vertex buffers. Twenty-one ANIM scenery shapes have
exactly matching geometry and face colours in SHAPE.TBL; these reuse the
existing Modern scenery. ANIM-only tank components retain their own geometry,
rendered at high resolution, without being mistaken for gameplay shape IDs.

The overlay activates only on the pixel-verified scenario panel. Every exposed
preview pixel must match a completed original draw. The separately verified
cursor is excluded from that comparison and retained above the replacement.
Missing observations, changed pixels and other screens retain original video.
The first preview frame sizes both colour and ownership viewports before mesh
construction, preventing missing bridge lines or tree silhouettes.

EGA remains untouched. Genesis keeps its existing donor/fallback behaviour.
Upscaled replays the source geometry; Modern also applies the existing material
and scenery refinements. There is no Genesis counterpart substituted for this
PC-specific animated preview.

## Regression checks

Generate the original menu route using `tools.capture_pc_menu_text` in baseline
and trace modes, then compare the report's complete `records` arrays. The route
covers all eight mission choices, time and skill changes, leaving the selector,
campaign/name entry, information and original exit.

```sh
python3 -m unittest tests.test_pc_frontend_scene tests.test_pc_frontend_text
python3 -m tools.capture_pc_menu_text --mode baseline --output artifacts/scene-baseline
python3 -m tools.capture_pc_menu_text --mode trace --output artifacts/scene-trace \
  --compare artifacts/scene-baseline/report.json
./tools/godot.sh --audio-driver Dummy --script res://tests/test_pc_frontend_scene.gd -- \
  --native --fixture "$PWD/artifacts/scene-trace/report.json"
```

The native test checks all four graphics modes, pixel-exact EGA, unchanged
high-resolution menu panels, scene clearing, first-frame ownership dimensions
and the existing quarter-source-pixel Modern anchor tolerance.
