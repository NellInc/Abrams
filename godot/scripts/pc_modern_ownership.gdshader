shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
// IDs travel in full-precision UVs. The CPU compensates Compatibility's
// colour transfer once, matching its established source-material path.
uniform sampler2D effect_atlas : filter_linear, repeat_disable;
void fragment() {
    if (COLOR.r > 0.5) {
        if (texture(effect_atlas,UV2).a < 0.5) discard;
        ALBEDO = vec3(UV,0.0);
    } else {
        ALBEDO = vec3(UV,UV2.x);
    }
}
