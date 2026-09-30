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
uniform bool modern_active = false;
// Diagnostic A/B switch; ordinary Modern rendering keeps this enabled.
uniform bool modern_surface_variation = true;
// Static presentation only: no TIME, new draw calls or cache invalidation.
uniform bool modern_environment_polish = true;
uniform sampler2D source_ownership : filter_nearest, repeat_disable;
uniform sampler2D modern_colours : source_color, filter_nearest, repeat_disable;
uniform float modern_colour_count;
uniform sampler2D modern_tree : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying float source_owner;
varying vec3 original_view;

// Neutral, non-tiled surface grain. No blade, rock or ground image is sampled.
float ground_hash(vec2 cell) {
    vec3 p = fract(vec3(cell.x,cell.y,cell.x)*vec3(0.1031,0.1030,0.0973));
    p += dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
}

float ground_noise(vec2 point) {
    vec2 cell=floor(point);
    vec2 f=fract(point);
    vec2 blend=f*f*(3.0-2.0*f);
    return mix(mix(ground_hash(cell),ground_hash(cell+vec2(1.0,0.0)),blend.x),
               mix(ground_hash(cell+vec2(0.0,1.0)),ground_hash(cell+vec2(1.0,1.0)),blend.x),blend.y);
}

float ground_grain(vec2 point) {
    vec2 cells=point/2.5;
    float footprint=max(length(dFdx(cells)),length(dFdy(cells)));
    // Fade before the grain can shimmer or form a distant screen-door pattern.
    return (ground_noise(cells)-0.5)*0.12*(1.0-smoothstep(0.35,1.25,footprint));
}

// Hind paint, shared by both original rotor states. Broad organic patches in
// source-local y/z, with no bitmap, animation, geometry or extra light. Ratios
// retain the authored facet shading in each renderer's working colour space.
vec3 hind_livery(vec3 base, vec2 source, vec2 footprint) {
    vec2 p=source/vec2(86.0,70.0)+vec2(4.3,1.9);
    p+=vec2(sin(p.y*2.1),sin(p.x*1.7))*0.25;
    float field=ground_noise(p);
    float edge=max(length(footprint/vec2(86.0,70.0))*0.3,0.005);
    float grey=smoothstep(0.49-edge,0.49+edge,field);
    vec3 green=OUTPUT_IS_SRGB ? vec3(1.129310,1.156250,1.023256) : vec3(1.299566,1.371897,1.048661);
    vec3 pale=OUTPUT_IS_SRGB ? vec3(1.663793,1.554688,2.104651) : vec3(3.053446,2.645805,4.965422);
    vec3 underside=OUTPUT_IS_SRGB ? vec3(0.534483,1.203125,2.151163) : vec3(0.275823,1.497000,5.213361);
    vec3 paint=mix(green,pale,grey);
    // Follow the original rising tail bottom rather than a world-height plane.
    float bottom=-40.0+clamp((-40.0-source.x)/260.0,0.0,1.0)*100.0;
    float height=source.y-bottom;
    float hem=max((footprint.y+footprint.x*0.385)*0.7,0.6);
    float blue=1.0-smoothstep(18.0-hem,18.0+hem,height);
    return base*mix(paint,underside,blue);
}

// Quieter two-tone olive for selected APC/utility hulls. Broad painted regions,
// no photographic grain, and no treatment on wheels, glass, flags or canvas.
vec3 armour_livery(vec3 base, vec2 source, vec2 footprint) {
    vec2 p=source/vec2(62.0,54.0)+vec2(1.8,3.2);
    p+=vec2(sin(p.y*1.6),sin(p.x*1.8))*0.22;
    float edge=max(length(footprint/vec2(62.0,54.0))*0.3,0.008);
    float patch=smoothstep(0.49-edge,0.49+edge,ground_noise(p));
    vec3 tint=mix(vec3(0.85,0.90,0.83),vec3(1.16,1.12,1.19),patch);
    return base*(OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2)));
}

// Helmet, brim and face facets inside an observed original head's exact spans.
// Screen-normalized local coordinates follow its captured center and radii.
vec3 crew_head_paint(vec2 p) {
    vec3 c=vec3(0.79,0.59,0.40);
    if (p.x>0.18) c*=0.86;
    if (p.y < -0.16+abs(p.x)*0.10) {
        c=vec3(0.39,0.47,0.29);
        if (p.x < -0.12 && p.y < -0.38) c=vec3(0.53,0.60,0.38);
        if (p.x > 0.48) c*=0.77;
    } else if (p.y < -0.015) c=vec3(0.22,0.28,0.18);
    else if (abs(p.x)>0.64 && p.y<0.67) c=vec3(0.28,0.31,0.20);
    else if (p.y>0.15 && p.y<0.24 && abs(abs(p.x)-0.25)<0.10) c=vec3(0.20,0.23,0.18);
    else if (p.y>0.62 && p.y<0.69 && abs(p.x)<0.23) c*=0.65;
    else if (p.x>0.01 && p.x<0.17 && p.y>0.22 && p.y<0.48) c*=1.10;
    return OUTPUT_IS_SRGB ? c : pow(c,vec3(2.2));
}

vec3 daylight_sky(vec3 ray) {
    vec3 direction=normalize(ray);
    float height=max(direction.z,0.0);
    vec3 horizon=vec3(0.71,0.81,0.83);
    vec3 overhead=vec3(0.27,0.51,0.78);
    vec3 colour=mix(horizon,overhead,smoothstep(0.0,0.62,height));
    // Broad, quiet cloud banks in source-world angular coordinates. They turn
    // with the view, survive restores exactly, and never veil ground or actors.
    vec2 p=direction.xy/(height+0.32)*vec2(1.65,3.8);
    float shape=ground_noise(p+vec2(4.7,9.2))*0.76+ground_noise(p*2.1)*0.24;
    float cloud=smoothstep(0.57,0.72,shape)*smoothstep(0.045,0.18,height);
    colour=mix(colour,vec3(0.87,0.89,0.84),cloud*0.53);
    return OUTPUT_IS_SRGB ? colour : pow(colour,vec3(2.2));
}

void vertex() {
    source_owner = floor(UV.y/32.0);
    UV.y = mod(UV.y,32.0);
    original_view = vec3(VERTEX.x,-VERTEX.z,VERTEX.y)*64.0;
}

void fragment() {
    // Evaluate derivatives before the ownership discard. Evaluating them in
    // surviving fragments alone leaves paint-edge helper lanes undefined.
    vec2 hind_footprint=vec2(0.0);
    if ((UV.y > 20.08 && UV.y < 20.1) || (UV.y > 20.48 && UV.y < 20.51)) hind_footprint=fwidth(UV2);
    if (modern_active && source_owner > 0.5) {
        vec3 ownership = texture(source_ownership,SCREEN_UV).rgb;
        vec2 packed_owner = round(ownership.rg*255.0);
        float owner = packed_owner.x + packed_owner.y*256.0;
        if (abs(owner-source_owner)>0.25) discard;
        // Exact observed round-command writes override inferred model facets.
        if ((ownership.b>0.5) != (UV.y>21.5)) discard;
    }
    if (UV.y > 21.5) {
        ALBEDO = texture(material_patterns,vec2(UV.x*2.0+0.5,floor(detail_levels*0.5)*2.0+0.5)/vec2(pattern_width,detail_levels*2.0)).rgb;
        if (modern_active && UV.y>22.5 && UV.y<23.5) ALBEDO=crew_head_paint(UV2);
    } else if (UV.y > 20.5) {
        vec4 tree = texture(modern_tree,UV2);
        if (tree.a < 0.85) discard;
        ALBEDO = tree.rgb;
        if (modern_environment_polish) {
            // Preserve the authored sprite and its alpha exactly. Lift its
            // deep foliage facets and warm trunk without adding foliage area.
            float green=smoothstep(0.0,0.065,tree.g-tree.r);
            float light=dot(tree.rgb,vec3(0.24,0.63,0.13));
            vec3 foliage=tree.rgb*vec3(0.93,1.055,1.045);
            foliage+=vec3(0.022,0.036,0.019)*(1.0-smoothstep(0.18,0.55,light));
            foliage*=mix(vec3(0.97,1.005,1.045),vec3(1.035,1.02,0.96),UV.x);
            vec3 trunk=tree.rgb*vec3(1.14,1.09,1.035);
            ALBEDO=mix(trunk,foliage,green);
        }
    } else if (UV.y > 19.5) {
        ALBEDO = texture(modern_colours,vec2((UV.x+0.5)/modern_colour_count,0.5)).rgb;
        // Only verified Hind olive/edge facets carry 20.09375. Glazing, vents,
        // original red accents and every other model keep their own materials.
        if (UV.y > 20.08 && UV.y < 20.1) ALBEDO=hind_livery(ALBEDO,UV2,hind_footprint);
        if (UV.y > 20.48 && UV.y < 20.51) ALBEDO=armour_livery(ALBEDO,UV2,hind_footprint);
        // The farm courtyard shares the restrained grass grain, keeping its
        // authored green. Source coordinates keep it fixed under camera motion.
        if (UV.y > 20.015 && UV.y < 20.04 && modern_surface_variation) {
            vec3 local=camera_to_local*original_view;
            vec2 ground=world_origin.xy+vec2(local.x,-local.y);
            ALBEDO *= 1.0+ground_grain(ground)*0.5;
        }
        // Small source-position-linked running-gear markings. Geometry and
        // outer silhouettes stay fixed; stationary camera changes add no phase.
        if (UV.y > 20.3 && UV.y < 20.48 && detail_levels > 1.0 && modern_surface_variation) {
            // Broad plaster/stone variation, tied to authored local faces.
            // No photographic panels, normal maps, new geometry or lighting.
            float fade = 1.0-smoothstep(4096.0,16384.0,original_view.y);
            float coarse = textureLod(field_detail,UV2/1024.0,6.0).r-0.4323640162;
            float grain = texture(road_detail,UV2/48.0).r-0.4546305661;
            vec3 warm = vec3(1.045,1.01,0.955);
            ALBEDO *= mix(vec3(1.0),warm,clamp(coarse*3.0+0.35,0.0,1.0)*fade);
            ALBEDO *= 1.0+(coarse*0.22+grain*0.12)*fade;
            // Roof colour belongs to the authored model palette. Preserve the
            // farm's warm clay, slate roofs and red ridge rather than tinting
            // every roof brown here (or losing its colour with detail off).
        } else if (UV.y > 20.2 && UV.y < 20.3) {
            float radius = length(UV2);
            float spoke = abs(sin(atan(UV2.y,UV2.x)*3.0));
            if (radius>0.2 && radius<0.72 && spoke<0.2) ALBEDO *= 0.72;
        } else if (UV.y > 20.1 && UV.y < 20.2 && fract(UV2.x)<0.18) ALBEDO *= 0.78;
    } else if (UV.y > 15.5 && UV.y < 16.5 && modern_active) {
        ALBEDO=texture(material_means,vec2((round(UV.x)+0.5)/(pattern_width*0.5),0.5)).rgb;
        if (modern_environment_polish) ALBEDO=daylight_sky(camera_to_local*original_view);
    } else if (UV.y > 14.5 && UV.y < 15.5 && modern_active) {
        // The original source-line path keeps its far/painter depth and exact
        // width; only the verified bridge framework's colour is replaced.
        ALBEDO=texture(modern_colours,vec2((UV.x+0.5)/modern_colour_count,0.5)).rgb;
    } else if (UV.y > 13.5 && UV.y < 14.5 && modern_active) {
        vec3 local = camera_to_local*original_view;
        vec2 water = world_origin.xy+vec2(local.x,-local.y);
        float broad = texture(field_detail,water/2048.0).r-0.4323640162;
        float fine = texture(road_detail,water/vec2(384.0,96.0)).r-0.4546305661;
        float fade = 1.0-smoothstep(2048.0,12288.0,length(local.xy));
        // Calm directional ripples fade before they become subpixel shimmer.
        // The original water plane and opaque visibility stay exactly intact.
        float phase = water.y/38.0+sin(water.x/190.0)*0.45;
        float ripple = sin(phase)*0.022*(1.0-smoothstep(0.15,0.8,fwidth(phase)));
        vec3 base = texture(material_means,vec2((round(UV.x)+0.5)/(pattern_width*0.5),16.5/detail_levels)).rgb;
        ALBEDO = modern_surface_variation ? base*vec3(0.88,1.025,1.015)*(1.0+broad*0.25+(fine*0.16+ripple)*fade) : base;
        if (modern_environment_polish && modern_surface_variation) {
            float grazing=1.0-clamp(abs(normalize(local).z)*2.2,0.0,1.0);
            vec3 sheen=OUTPUT_IS_SRGB ? vec3(0.60,0.73,0.76) : pow(vec3(0.60,0.73,0.76),vec3(2.2));
            ALBEDO*=vec3(0.86,1.035,1.025);
            ALBEDO=mix(ALBEDO,sheen,0.08+grazing*grazing*0.25);
            // Restrained broad glints, derivative-filtered before they shimmer.
            float glint=smoothstep(0.82,1.0,sin(phase*0.58+sin(water.x/270.0)*0.35));
            glint*=fade*(1.0-smoothstep(0.12,0.65,fwidth(phase*0.58)));
            ALBEDO+=vec3(0.022,0.031,0.031)*glint;
        }
    } else if (UV.y > 9.5) {
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
            float detail=0.0;
            if (road) detail=texture(road_detail,ground/256.0).r-0.4546305661;
            else if (!modern_active) detail=texture(field_detail,ground/512.0).r-0.4323640162;
            vec2 grain_position=ground;
            if (UV.y > 6.5) {
                vec3 position = world_origin+vec3(local.x,-local.y,local.z);
                vec2 hill_uv = ground;
                if (UV.y > 8.5) hill_uv = position.xz;
                else if (UV.y > 7.5) hill_uv = position.yz;
                grain_position=hill_uv;
                if (!modern_active) detail=texture(hill_detail,hill_uv/768.0).r-hill_mean;
            }
            if (modern_active && !road) detail=modern_surface_variation ? ground_grain(grain_position) : 0.0;
            float fade = 1.0-smoothstep(2048.0,8192.0,length(local.xy));
            if (UV.y > 6.5) fade = 1.0-smoothstep(8192.0,32768.0,length(local.xy));
            level = clamp(round(16.0+detail*64.0*fade),0.0,32.0);
        }
    }
    vec2 lookup = (vec2(round(UV.x)*2.0,level*2.0)+phase+vec2(0.5))/vec2(pattern_width,detail_levels*2.0);
    if (modern_active || UV.y > 6.5) {
        // Modern also resolves unclassified source faces to their mean.
        // Restore the colour represented by the old 2x2 dither; retain the
        // original facet and painter stream, with no new geometry or lighting.
        ALBEDO = texture(material_means,vec2((round(UV.x)+0.5)/(pattern_width*0.5),
                         (level+0.5)/detail_levels)).rgb;
        // Only verified hill faces with source grass material 19. Its original
        // black/green dither is lifted from the grass ramp; other hill faces and
        // every other object using these material numbers stay untouched.
        if (modern_active && UV.y > 6.5 && UV.y < 9.5 && abs(UV.x-19.0)<0.25) {
            ALBEDO = texture(material_means,vec2(8.5/(pattern_width*0.5),
                             (level+0.5)/detail_levels)).rgb*vec3(0.78,0.90,0.84);
        }
        if (modern_active && modern_surface_variation && detail_levels > 1.0 && UV.y > 0.5) {
            vec3 local = camera_to_local*original_view;
            bool usable = true;
            if (UV.y > 2.5 && UV.y < 3.5) {
                usable = world_origin.z > 0.0 && local.z < -0.0001;
                if (usable) local *= -world_origin.z/local.z;
            }
            if (usable) {
                vec2 ground = world_origin.xy+vec2(local.x,-local.y);
                bool road=UV.y > 1.5 && UV.y < 2.5;
                float patch=road ? clamp((texture(field_detail,ground/4096.0).r-0.32)*2.5,0.0,1.0)
                                : ground_noise(ground/2048.0);
                bool hill = UV.y > 6.5;
                vec3 warm = hill ? vec3(1.075,1.025,0.945) : vec3(1.045,1.015,0.965);
                vec3 cool = hill ? vec3(0.945,1.025,0.92) : vec3(0.965,1.025,0.95);
                ALBEDO *= mix(cool,warm,patch);
            }
        }
        // Palette balance is confined to verified terrain tags. Luminance
        // retains the road's existing coarse relief, without an olive cast.
        // Objects sharing source material indices never receive this paint.
        if (modern_active && detail_levels > 1.0) {
            bool road=UV.y > 1.5 && UV.y < 2.5;
            bool grass=(UV.y > 0.5 && UV.y < 3.5 && !road && abs(UV.x-8.0)<0.25)
                    || (UV.y > 6.5 && UV.y < 9.5 && abs(UV.x-19.0)<0.25);
            if (road) {
                float light=dot(ALBEDO,vec3(0.2126,0.7152,0.0722));
                vec3 warm=vec3(1.045,1.0,0.935);
                ALBEDO=light*(OUTPUT_IS_SRGB ? warm : pow(warm,vec3(2.2)));
            } else if (grass) {
                vec3 fresh=vec3(0.88,1.085,0.98);
                ALBEDO*=OUTPUT_IS_SRGB ? fresh : pow(fresh,vec3(2.2));
            }
        }
    } else ALBEDO = texture(material_patterns, lookup).rgb;
    }
}
