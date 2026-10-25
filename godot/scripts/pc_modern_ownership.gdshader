shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
// IDs travel in full-precision UVs. The CPU compensates Compatibility's
// colour transfer once, matching its established source-material path.
// UV2.x carries compensated blue classification: background/default 0,
// optional guarded owner 8, protected source line 64, observed round write 255.
void fragment() {
    ALBEDO = vec3(UV,UV2.x);
}
