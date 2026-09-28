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
uniform sampler2D hill_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D material_means : source_color, filter_nearest, repeat_disable;
uniform float hill_mean;
uniform mat3 camera_to_local;
uniform vec3 world_origin;
uniform sampler2D impact_burst : filter_linear, repeat_disable;
uniform sampler2D impact_fading : filter_linear, repeat_disable;
uniform sampler2D impact_smoke : filter_linear, repeat_disable;
uniform sampler2D effect_correction : filter_linear, repeat_disable;
uniform sampler2D vehicle_panels : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D vehicle_colours : source_color, filter_nearest, repeat_disable;
uniform float vehicle_materials;
varying vec3 original_view;

void vertex() {
    original_view = vec3(VERTEX.x,-VERTEX.z,VERTEX.y)*64.0;
}

void fragment() {
    if (UV.y > 9.5) {
        vec4 panel = texture(vehicle_panels,UV2);
        float mean = UV.y < 10.5 ? 0.2262180410 : (UV.y < 11.5 ? 0.2180028921 : 0.2656186350);
        float fade = 1.0-smoothstep(1024.0,4096.0,original_view.y);
        // Alpha controls detail only: transparent pixels retain the original
        // facet. Never discard a vehicle fragment or expose a hidden surface.
        float level = clamp(round(32.0+(panel.r-mean)*128.0*smoothstep(0.5,0.9,panel.a)*fade),0.0,64.0);
        if (UV.y > 12.5) level=32.0;
        ALBEDO=texture(vehicle_colours,vec2((round(UV.x)+0.5)/vehicle_materials,(level+0.5)/65.0)).rgb;
    } else if (UV.y > 3.5 && UV.y < 6.5) {
        vec4 effect;
        if (UV.y < 4.5) effect = texture(impact_burst,UV2);
        else if (UV.y < 5.5) effect = texture(impact_fading,UV2);
        else effect = texture(impact_smoke,UV2);
        // Cutout keeps the complete mesh in its original opaque painter stream.
        // Discard low-alpha generation residue rather than exposing RGB fringes.
        if (effect.a < 0.5) discard;
        vec3 lookup = (effect.rgb*255.0+vec3(0.5))/256.0;
        ALBEDO = vec3(texture(effect_correction,vec2(lookup.r,0.5)).r,
                      texture(effect_correction,vec2(lookup.g,0.5)).r,
                      texture(effect_correction,vec2(lookup.b,0.5)).r);
    } else {
    vec2 pixel = floor(SCREEN_UV * source_dimensions + source_origin);
    vec2 phase = mod(pixel, 2.0);
    float level = detail_levels > 1.0 ? 16.0 : 0.0;
    if (detail_levels > 1.0 && UV.y > 0.5) {
        vec3 local = camera_to_local*original_view;
        bool usable = true;
        if (UV.y > 2.5 && UV.y < 3.5) {
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
            if (UV.y > 6.5) {
                vec3 position = world_origin+vec3(local.x,-local.y,local.z);
                vec2 hill_uv = ground;
                if (UV.y > 8.5) hill_uv = position.xz;
                else if (UV.y > 7.5) hill_uv = position.yz;
                detail = texture(hill_detail,hill_uv/768.0).r-hill_mean;
            }
            float fade = 1.0-smoothstep(2048.0,8192.0,length(local.xy));
            if (UV.y > 6.5) fade = 1.0-smoothstep(8192.0,32768.0,length(local.xy));
            level = clamp(round(16.0+detail*64.0*fade),0.0,32.0);
        }
    }
    vec2 lookup = (vec2(round(UV.x)*2.0,level*2.0)+phase+vec2(0.5))/vec2(pattern_width,detail_levels*2.0);
    if (UV.y > 6.5) {
        // Restore the colour represented by the old 2x2 dither; retain the
        // original facet and painter stream, with no new geometry or lighting.
        ALBEDO = texture(material_means,vec2((round(UV.x)+0.5)/(pattern_width*0.5),
                         (level+0.5)/detail_levels)).rgb;
    } else ALBEDO = texture(material_patterns, lookup).rgb;
    }
}
