shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// One ordered triangle stream retains the original painter ordering. The
// reference dither stays in original screen-pixel coordinates as resolution grows.
uniform sampler2D material_patterns : source_color, filter_nearest, repeat_disable;
uniform vec2 source_origin;
uniform vec2 source_dimensions;
uniform float pattern_width = 64.0;

void fragment() {
    vec2 pixel = floor(SCREEN_UV * source_dimensions + source_origin);
    vec2 phase = mod(pixel, 2.0);
    vec2 lookup = (vec2(round(UV.x) * 2.0, 0.0) + phase + vec2(0.5)) / vec2(pattern_width, 2.0);
    ALBEDO = texture(material_patterns, lookup).rgb;
}
