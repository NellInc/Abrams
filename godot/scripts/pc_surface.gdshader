shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;

// One ordered triangle stream retains the original painter ordering. The
// reference dither stays in original screen-pixel coordinates as resolution grows.
uniform sampler2D material_patterns : source_color, filter_nearest, repeat_disable;
uniform vec2 source_origin;
uniform vec2 source_dimensions;
uniform float pattern_width = 64.0;
uniform float detail_levels = 1.0;
uniform sampler2D field_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D road_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform mat3 camera_to_local;
uniform vec3 world_origin;
varying vec3 original_view;

void vertex() {
    original_view = vec3(VERTEX.x,-VERTEX.z,VERTEX.y)*64.0;
}

void fragment() {
    vec2 pixel = floor(SCREEN_UV * source_dimensions + source_origin);
    vec2 phase = mod(pixel, 2.0);
    float level = detail_levels > 1.0 ? 16.0 : 0.0;
    if (detail_levels > 1.0 && UV.y > 0.5) {
        vec3 local = camera_to_local*original_view;
        bool usable = true;
        if (UV.y > 2.5) {
            // The original flat background has no depth. Project only its
            // existing ground pixels onto z=0; the original horizon stays fixed.
            usable = world_origin.z > 0.0 && local.z < -0.0001;
            if (usable) local *= -world_origin.z/local.z;
        }
        if (usable) {
            vec2 ground = world_origin.xy+vec2(local.x,-local.y);
            bool road = UV.y > 1.5 && UV.y < 2.5;
            float detail = road ? texture(road_detail,ground/256.0).r-0.4546305661
                                : texture(field_detail,ground/512.0).r-0.4323640162;
            float fade = 1.0-smoothstep(2048.0,8192.0,length(local.xy));
            level = clamp(round(16.0+detail*64.0*fade),0.0,32.0);
        }
    }
    vec2 lookup = (vec2(round(UV.x)*2.0,level*2.0)+phase+vec2(0.5))/vec2(pattern_width,detail_levels*2.0);
    ALBEDO = texture(material_patterns, lookup).rgb;
}
