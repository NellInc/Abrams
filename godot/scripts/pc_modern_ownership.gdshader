shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
// IDs travel in full-precision UVs. The CPU compensates Compatibility's
// colour transfer once, matching its established source-material path.
// UV2.x marks observed round-command writes.
void fragment() {
    ALBEDO = vec3(UV,UV2.x);
}
