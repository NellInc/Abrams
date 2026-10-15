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
// False when the frame supplied no valid source camera basis. The two uniforms
// above are then the zero defaults, so no world-anchored normal is defined.
uniform bool camera_basis_ready = false;
// One atlas holds every effect donor (burst, fading, smoke); kind 4 only.
uniform sampler2D impact_burst : filter_linear, repeat_disable;
uniform sampler2D effect_correction : filter_linear, repeat_disable;
uniform sampler2D vehicle_panels : filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D vehicle_colours : source_color, filter_nearest, repeat_disable;
uniform float vehicle_materials;
uniform bool modern_active = false;
// Calibration Range-inspired surface treatment. Modern's existing pixels are
// unchanged when this is false; source geometry and ownership stay identical.
uniform bool tactical_landscape = false;
// Signed distance to the observed PC horizon in original screen pixels.
uniform vec3 source_horizon_line = vec3(0.0);
uniform float source_focal_pixels = 192.0;
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
varying float architecture_finish;
varying float material_finish;
varying float realism_family;
varying vec2 realism_crew_point;
#include "res://scripts/pc_tactical_materials.gdshaderinc"
#include "res://scripts/pc_tactical_effect_finish.gdshaderinc"
uniform bool tactical_material_ready = false;
uniform sampler2D tactical_steel_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tactical_plaster_detail : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tactical_stone_detail : filter_linear_mipmap_anisotropic, repeat_enable;

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

// Fine grass blades are a world-anchored surface material, not new cover.
// Their footprint fades before subpixel shimmer; source silhouettes and every
// actor's ownership remain unchanged, including through foliage cutouts.
// Shared source-plane footprint: unresolved relief converges smoothly to its
// mean. Broad colour retains its preceding minimum mip, with a coarser mip only
// when the actual pixel footprint requires it.
float tactical_ground_detail(vec2 footprint, float period) {
    return 1.0-smoothstep(0.14,0.50,max(footprint.x,footprint.y)/period);
}
float tactical_ground_colour_fade(vec2 dx,vec2 dy,float period) {
    // A continuous tail for already-prefiltered colour, using the same 16x
    // anisotropic ellipse as the atlas. Relief keeps its separate Nyquist fade.
    float footprint=realism_footprint(dx/period,dy/period,8.0)/(512.0*0.22);
    return 1.0/(1.0+footprint*footprint);
}
float tactical_ground_broad_lod(vec2 footprint, float period, vec2 dimensions) {
    vec2 texels=footprint*dimensions/period;
    return max(3.0,log2(max(max(texels.x,texels.y),1.0)));
}

vec3 tactical_meadow(vec3 base, vec2 ground, vec2 source_footprint, float light) {
    vec2 p=ground/14.0;
    float footprint=max(source_footprint.x,source_footprint.y)/14.0;
    float fade=1.0-smoothstep(0.20,0.85,footprint);
    vec2 patch=floor(p);
    float seed=ground_hash(patch);
    vec2 q=fract(p)-0.5;
    q-=vec2((seed-0.5)*0.56,(ground_hash(patch+vec2(27.0,13.0))-0.5)*0.16);
    float height=0.38+seed*0.40;
    float y=q.y+0.44;
    float lean=(seed-0.5)*0.55*y;
    float width=0.055*(1.0-clamp(y/height,0.0,1.0));
    float edge=max(footprint*0.45,0.006);
    float blade=1.0-smoothstep(width,width+edge,abs(q.x-lean));
    blade*=smoothstep(0.0,0.06,y)*(1.0-smoothstep(height-edge,height,y));
    float clump=smoothstep(0.24,0.60,ground_noise(ground/170.0));
    vec3 leaf=mix(vec3(0.21,0.29,0.14),vec3(0.39,0.47,0.25),seed);
    return mix(base,leaf*light,blade*fade*clump*0.65*smoothstep(0.18,0.38,seed));
}

// Existing road faces only. Aggregate is a material finish, never added stones,
// damage, lane markings or tyre tracks. The fine grain fades below two pixels.
vec3 tactical_road(vec3 base, vec2 ground, vec2 footprint, float middle) {
    float pixel=max(footprint.x,footprint.y)/5.5;
    float fade=1.0-smoothstep(0.20,0.50,pixel);
    float grain=ground_noise(ground/5.5)-0.5;
    float stones=smoothstep(0.06,0.34,grain);
    float pores=smoothstep(0.08,0.32,-grain);
    base*=1.0+(middle-0.4546305661)*0.24;
    return base+vec3((stones*0.035-pores*0.025)*fade);
}

// A single world-angular sky supplies the background and opaque water/glass
// reflections. Clouds keep their existing shape; no actors or terrain reflect.
vec3 tactical_coherent_sky(vec3 direction,vec3 world_direction) {
    float height=max(direction.z,0.0);
    vec3 colour=mix(vec3(0.78,0.82,0.76),vec3(0.46,0.62,0.69),smoothstep(0.0,0.62,height));
    vec2 p=direction.xy/(height+0.32)*vec2(1.65,3.8);
    float shape=ground_noise(p+vec2(4.7,9.2))*0.76+ground_noise(p*2.1)*0.24;
    float cloud=smoothstep(0.57,0.72,shape)*smoothstep(0.045,0.18,height);
    bool coherent=modern_environment_polish && dot(source_horizon_line.xy,source_horizon_line.xy)>0.5;
    if(coherent)colour=tactical_sky_finish(colour,world_direction,height);
    // Dense banks have a softly shaded underside and brighter thinner edges.
    // Reuse the broad cloud field rather than adding noise or a moving clock.
    float bank=smoothstep(0.57,0.76,shape);
    vec3 lit=mix(vec3(0.90,0.92,0.87),vec3(0.70,0.76,0.74),bank*0.58);
    lit+=vec3(0.025,0.022,0.014)*smoothstep(0.14,0.55,height)*0.35;
    if(coherent)lit=tactical_cloud_finish(lit,world_direction,shape);
    return mix(colour,lit,cloud*0.40);
}

// Reflection rays already use source-world coordinates. Keep the original
// cloud sampling direction separate from the lighting direction for the sky.
vec3 tactical_sky_colour(vec3 direction) {
    return tactical_coherent_sky(direction,direction);
}

bool tactical_daylight_observed() {
    return dot(source_horizon_line.xy,source_horizon_line.xy)>0.5;
}

float tactical_glint_fade(float distance,float eye_pixel) {
    return (1.0-smoothstep(800.0,6000.0,distance))*(1.0-smoothstep(0.003,0.05,eye_pixel));
}

vec3 tactical_water(vec2 water, vec2 footprint, vec3 face, vec3 to_eye, float broad, float fine, float eye_pixel, float distance) {
    // Two oblique ripple fields break up parallel bands. These are stationary
    // world-space material normals, with no displacement or independent clock.
    vec2 direction_a=vec2(0.011,0.024);
    vec2 direction_b=vec2(-0.019,0.012);
    vec2 phase=vec2(dot(water,direction_a),dot(water,direction_b));
    phase+=vec2(sin(water.x/230.0),sin(water.y/310.0))*0.65;
    // Include the warp's maximum derivative; radians fade below Nyquist.
    vec2 pixel=vec2(dot(abs(direction_a)+vec2(0.65/230.0,0.0),footprint),
                    dot(abs(direction_b)+vec2(0.0,0.65/310.0),footprint));
    vec2 fade=vec2(1.0)-smoothstep(vec2(0.65),vec2(2.6),pixel);
    vec2 slope=(direction_a+vec2(cos(water.x/230.0)*0.65/230.0,0.0))*cos(phase.x)*fade.x;
    slope+=(direction_b+vec2(0.0,cos(water.y/310.0)*0.65/310.0))*cos(phase.y)*fade.y*0.55;
    vec3 normal=normalize(face+vec3(-slope*3.8,0.0));
    float facing=clamp(dot(normal,to_eye),0.0,1.0);
    float reflection=0.12+pow(1.0-facing,5.0)*0.48;
    vec3 ray=reflect(-to_eye,normal);
    vec3 sky=tactical_daylight_observed() ? tactical_sky_colour(ray) : mix(vec3(0.72,0.80,0.76),vec3(0.40,0.59,0.67),smoothstep(0.0,0.75,max(ray.z,0.0)));
    vec3 body=vec3(0.15,0.29,0.32)*(1.0+broad*0.18+fine*0.06);
    vec3 colour=mix(body,sky,reflection);
    // Broken broad wave highlights, modulated by the crossing field. They stay
    // below foam-white and disappear with the same filtered ripple footprint.
    float crest=pow(0.5+0.5*sin(phase.x+sin(phase.y)*0.45),4.0);
    crest*=0.55+0.45*sin(phase.y*0.63);
    colour+=vec3(0.035,0.045,0.047)*crest*fade.x*fade.y;
    vec3 halfway=normalize(vec3(-0.58,0.34,0.74))+to_eye;
    halfway/=max(length(halfway),0.0001);
    float glint=pow(max(dot(normal,halfway),0.0),48.0)*0.055;
    if(tactical_daylight_observed())glint*=tactical_glint_fade(distance,eye_pixel)*fade.x*fade.y;
    colour+=vec3(1.0,0.97,0.82)*glint;
    return colour;
}

// Bounded decorative optics, in display colour space. The atlas gain is a
// filtered roughness cue, not measured optical data or reflected scene content.
float tactical_optical_fresnel(float facing,float head_on,float grazing) {
    float edge=1.0-clamp(facing,0.0,1.0);
    return mix(head_on,grazing,edge*edge*edge*edge*edge);
}

vec2 tactical_optical_response(float gain,float power,float eye_pixel) {
    float worn=clamp((1.0-gain)/0.18,-1.0,1.0);
    float width=power*exp2(-0.55*worn);
    // Broaden unresolved lobes continuously and lower their peak. This uses
    // the existing pre-discard angular footprint, with no mip/atlas re-read.
    width/=1.0+power*max(eye_pixel,0.0)*max(eye_pixel,0.0)*160.0;
    width=max(width,power*0.22);
    return vec2(min(1.0,width/power),width);
}

vec3 tactical_optical_environment(vec3 sky,vec3 ray,float roughness) {
    // A subdued lower hemisphere is an analytic material tint. It contains
    // no bank/actor silhouettes and crosses the horizon continuously.
    vec3 ground=mix(vec3(0.24,0.28,0.20),vec3(0.16,0.23,0.16),clamp(-ray.z,0.0,1.0));
    float above=smoothstep(-0.18,0.12,ray.z);
    vec3 broad=mix(tactical_horizon_palette(ray),vec3(0.46,0.62,0.69),smoothstep(0.0,0.62,max(ray.z,0.0)));
    vec3 softened=mix(sky,broad,clamp(roughness,0.0,1.0)*0.28);
    return mix(ground,softened,above);
}

vec3 tactical_textured_water(vec2 water,vec2 footprint,vec3 face,vec3 eye,float broad,float fine,float eye_pixel,float distance,float gain) {
    // Reuse the preceding two world-anchored fields and their conservative
    // normal filter. Crest/trough colour has a broad tail after fine relief.
    vec2 direction_a=vec2(0.011,0.024);
    vec2 direction_b=vec2(-0.019,0.012);
    vec2 phase=vec2(dot(water,direction_a),dot(water,direction_b));
    phase+=vec2(sin(water.x/230.0),sin(water.y/310.0))*0.65;
    vec2 pixel=vec2(dot(abs(direction_a)+vec2(0.65/230.0,0.0),footprint),
                    dot(abs(direction_b)+vec2(0.0,0.65/310.0),footprint));
    vec2 fade=vec2(1.0)-smoothstep(vec2(0.65),vec2(2.6),pixel);
    vec2 slope=(direction_a+vec2(cos(water.x/230.0)*0.65/230.0,0.0))*cos(phase.x)*fade.x;
    slope+=(direction_b+vec2(0.0,cos(water.y/310.0)*0.65/310.0))*cos(phase.y)*fade.y*0.55;
    vec3 normal=normalize(face+vec3(-slope*3.8,0.0));
    float facing=clamp(dot(normal,eye),0.0,1.0);
    float roughness=clamp(0.55+(1.0-gain)*1.5,0.25,0.85);
    vec3 ray=reflect(-eye,normal);
    vec3 environment=tactical_optical_environment(tactical_sky_colour(ray),ray,roughness);
    float reflection=tactical_optical_fresnel(facing,0.065,0.62)*(1.0-roughness*0.14);
    vec3 body=mix(vec3(0.13,0.27,0.29),vec3(0.21,0.30,0.25),clamp(0.5+broad*2.0,0.0,1.0));
    body*=1.0+broad*0.12+fine*0.05;
    vec2 colour_fade=vec2(1.0)/(vec2(1.0)+pixel*pixel*0.8);
    float crossing=0.65+0.35*sin(phase.y);
    float wave=sin(phase.x+sin(phase.y)*0.45);
    float crest=pow(max(wave,0.0),3.0)*crossing;
    float trough=max(-wave,0.0)*(1.0-crossing*0.35);
    vec3 colour=mix(body,environment,reflection);
    colour+=(vec3(0.024,0.038,0.035)*crest-vec3(0.014,0.024,0.021)*trough)*colour_fade.x*colour_fade.y;
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    vec3 sum=sun+eye;vec3 halfway=sum/max(length(sum),0.0001);
    vec2 response=tactical_optical_response(gain,48.0,eye_pixel);
    float glint=pow(max(dot(normal,halfway),0.0),response.y)*response.x*0.055;
    glint*=max(dot(normal,sun),0.0)*tactical_glint_fade(distance,eye_pixel)*fade.x*fade.y;
    return colour+vec3(1.0,0.97,0.88)*glint;
}

// Shared close/distant tree palette in display colour space. The illustration
// still supplies every leaf facet and cutout; no new foliage coverage or clock.
vec3 tactical_crown(vec3 authored, vec2 uv, float variant) {
    float facet=clamp(dot(authored,vec3(0.24,0.63,0.13))*1.7,0.0,1.0);
    float upper=1.0-smoothstep(0.08,0.80,uv.y);
    vec3 shade=mix(vec3(0.15,0.24,0.14),vec3(0.20,0.27,0.12),variant);
    vec3 tips=mix(vec3(0.43,0.57,0.32),vec3(0.53,0.61,0.30),variant);
    vec3 crown=mix(shade,tips,facet);
    crown*=mix(0.90,1.08,upper);
    return crown;
}

// Broad implied crown volume within the existing sprite, never new geometry.
// Its camera-facing hemisphere is transformed back into the source world so
// the same fixed sun lights trees and real shrub meshes. Authored facets remain.
vec3 tactical_tree_normal(vec2 uv) {
    float height=clamp(1.0-uv.y/0.805,0.0,1.0);
    float width=mix(0.48,0.16,height);
    float x=clamp((uv.x-0.5)/width,-0.95,0.95);
    vec3 camera_normal=normalize(vec3(x,-sqrt(max(1.0-x*x,0.0))*0.85,0.18+height*0.45));
    vec3 normal=camera_to_local*camera_normal;
    vec3 world=vec3(normal.x,-normal.y,normal.z);
    return dot(world,world)>1e-8 ? normalize(world) : vec3(0.0,0.0,1.0);
}

vec3 tactical_tree_light(vec3 base, vec2 uv, vec2 footprint, vec3 eye, float distance) {
    float height=clamp(1.0-uv.y/0.805,0.0,1.0);
    vec3 normal=tactical_tree_normal(uv);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    float direct=max(dot(normal,sun),0.0);
    float sky=clamp(normal.z*0.5+0.5,0.0,1.0);
    vec3 tint=mix(vec3(0.94,0.985,1.025),vec3(1.06,1.035,0.94),direct);
    vec3 lit=base*tint*(0.97+sky*0.05);
    float back=pow(max(dot(-eye,sun),0.0),3.0);
    lit+=base*vec3(0.085,0.065,0.028)*back*smoothstep(0.20,0.75,height);
    if(modern_environment_polish)lit*=tactical_environment_tint(normal,0.70);
    float pixel=max(footprint.x,footprint.y);
    float detail=(1.0-smoothstep(0.02,0.09,pixel))*(1.0-smoothstep(1600.0,10000.0,distance));
    return mix(base,lit,detail);
}

vec3 tactical_bark(vec3 base, vec2 uv, vec2 footprint) {
    // Broad longitudinal grain, filtered before it can become striping on a
    // distant trunk. Both the grain and collar stay inside the existing stem.
    vec2 grain_uv=uv*vec2(110.0,9.0);
    float pixel=max(footprint.x*110.0,footprint.y*9.0);
    float grain=(ground_noise(grain_uv)-0.5)*(1.0-smoothstep(0.20,0.50,pixel));
    float height=clamp((0.995-uv.y)/0.19,0.0,1.0);
    float root=1.0-smoothstep(0.0,0.27,height);
    float collar=smoothstep(0.72,1.0,height);
    float amount=1.0+grain*0.25-root*0.12-collar*0.16;
    return base*amount;
}

// Implied cylinder light stays inside the already admitted trunk span.
vec3 tactical_trunk_fill(vec2 uv,vec2 footprint,float width) {
    float side=clamp((uv.x-0.5)/max(width,0.001),-0.95,0.95);
    vec3 camera_normal=normalize(vec3(side,-sqrt(max(1.0-side*side,0.0)),0.08));
    vec3 n=camera_to_local*camera_normal;n=vec3(n.x,-n.y,n.z);
    n=dot(n,n)>1e-8 ? normalize(n) : vec3(0.0,0.0,1.0);
    float resolved=1.0-smoothstep(0.25,0.80,footprint.x/max(width,0.001));
    return tactical_environment_tint(n,0.55*resolved);
}

// Differentiate the unit direction instead of wrapped atan coordinates. The
// angular footprint is continuous at +/-pi and bounded at the zenith.
vec2 tactical_horizon_gradient(vec3 direction, vec3 dx, vec3 dy) {
    float horizontal=max(dot(direction.xy,direction.xy),0.0001);
    return vec2(direction.y*dx.x-direction.x*dx.y,
                direction.y*dy.x-direction.x*dy.y)*(96.0/6.28318530718)/horizontal;
}

float tactical_horizon_detail(float pixel) {
    return 1.0-smoothstep(0.25,0.80,pixel);
}

vec3 horizon_vegetation(vec3 colour, vec3 direction, float elevation, vec4 footprint) {
    // Wrap a fixed angular field exactly once around the view. These distant
    // hedges are underpaint, so original terrain and actors still own visibility.
    float angle=atan(direction.x,direction.y);
    float lane=angle*(96.0/6.28318530718);
    float cell=mod(floor(lane),96.0);
    float seed=ground_hash(vec2(cell,71.0));
    float center=mix(0.28,0.72,ground_hash(vec2(cell,313.0)));
    float x=fract(lane)-center;
    float pixel_y=max(abs(footprint.z)+abs(footprint.w),0.00015);
    float pixel_x=max(abs(footprint.x)+abs(footprint.y),0.001);

    // Broken, irregular hedgerows rather than a flat green strip. Broad banks
    // and small leaf clusters give the canopy a lit top and a darker root line.
    vec2 around=vec2(sin(angle),cos(angle));
    float bank=ground_noise(around*13.0+vec2(17.0,29.0));
    float leaves=ground_noise(around*173.0+vec2(5.0,8.0));
    // Keep the broad bank; unresolved leaf clusters converge to their mean.
    leaves=mix(0.5,leaves,tactical_horizon_detail(pixel_x*(6.28318530718/96.0)*173.0));
    float hedge_height=(0.016+bank*0.032+leaves*0.016)*smoothstep(0.18,0.39,bank);
    float hedge=1.0-smoothstep(hedge_height-pixel_y,hedge_height+pixel_y,elevation);
    hedge*=smoothstep(0.0001,0.0015,hedge_height);
    float top=clamp(elevation/max(hedge_height,0.001),0.0,1.0);
    vec3 hedge_colour=mix(vec3(0.19,0.28,0.16),vec3(0.43,0.53,0.29),top);
    float canopy=ground_noise(vec2(lane*2.7,elevation*160.0));
    canopy=mix(0.5,canopy,tactical_horizon_detail(max(pixel_x*2.7,pixel_y*160.0)));
    hedge_colour*=0.85+canopy*0.28;
    hedge_colour=mix(hedge_colour,vec3(0.52,0.60,0.50),0.08+top*0.06);
    if(modern_environment_polish && modern_surface_variation) {
        vec3 world=vec3(direction.x,-direction.y,direction.z);
        vec3 normal=normalize(vec3(-world.xy*(0.45+top*0.35),0.65));
        float resolved=tactical_horizon_detail(max(pixel_x*2.7,pixel_y*160.0));
        hedge_colour*=tactical_environment_tint(normal,0.45*resolved);
    }
    colour=mix(colour,hedge_colour,hedge);

    if (seed>0.24) {
        float crown_height=mix(0.045,0.105,ground_hash(vec2(cell,151.0)));
        float stem_height=mix(0.012,0.024,ground_hash(vec2(cell,229.0)));
        // Give distant stems coverage instead of thresholding away a filtered
        // subpixel alpha. The roots meet the exact source sky/ground boundary.
        float half_stem=max(0.020,pixel_x*0.55);
        float stem=(1.0-smoothstep(half_stem-pixel_x*0.35,half_stem+pixel_x*0.35,abs(x)));
        stem*=1.0-smoothstep(stem_height+crown_height*0.32,stem_height+crown_height*0.34,elevation);
        vec3 bark=mix(vec3(0.29,0.25,0.18),vec3(0.45,0.37,0.25),smoothstep(-half_stem,half_stem,-x));
        colour=mix(colour,bark,stem);
        vec2 tree_uv=vec2(x/0.76+0.5,0.805-(elevation-stem_height)/crown_height*0.80);
        if (tree_uv.x>0.0 && tree_uv.x<1.0 && tree_uv.y>0.005 && tree_uv.y<0.805) {
            // Explicit cell-local gradients avoid implicit LOD in divergent
            // crown/cutout branches. No derivative of floor/seed is required.
            vec2 tree_dx=vec2(footprint.x/0.76,-footprint.z*0.80/crown_height);
            vec2 tree_dy=vec2(footprint.y/0.76,-footprint.w*0.80/crown_height);
            vec4 tree=textureGrad(modern_tree,tree_uv,tree_dx,tree_dy);
            vec3 foliage=mix(tree.rgb,vec3(0.34,0.44,0.23),0.42);
            if (modern_surface_variation) {
                // Match the nearby trees, with a restrained cool distance tint.
                // Keep the existing horizon alpha, positions and hedge profile.
                foliage=mix(tactical_crown(tree.rgb,tree_uv,seed),vec3(0.52,0.60,0.50),0.22);
                if(modern_environment_polish) {
                    float resolved=tactical_horizon_detail(max(length(tree_dx),length(tree_dy)));
                    foliage*=tactical_environment_tint(tactical_tree_normal(tree_uv),0.45*resolved);
                }
            }
            colour=mix(colour,foliage,smoothstep(0.38,0.76,tree.a));
        }
    }
    return colour;
}

vec3 daylight_sky(vec3 ray, vec2 source_pixel, vec4 horizon_footprint) {
    vec3 direction=normalize(ray);
    float height=max(direction.z,0.0);
    vec3 horizon=tactical_landscape ? vec3(0.78,0.82,0.76) : vec3(0.71,0.81,0.83);
    vec3 overhead=tactical_landscape ? vec3(0.46,0.62,0.69) : vec3(0.27,0.51,0.78);
    vec3 colour=mix(horizon,overhead,smoothstep(0.0,0.62,height));
    // Broad, quiet cloud banks in source-world angular coordinates. They turn
    // with the view, survive restores exactly, and never veil ground or actors.
    // Keep Modernized's original gradient and cloud blend byte-for-byte.
    if(tactical_landscape && tactical_daylight_observed())colour=tactical_coherent_sky(direction,vec3(direction.x,-direction.y,direction.z));
    else {
        vec2 p=direction.xy/(height+0.32)*vec2(1.65,3.8);
        float shape=ground_noise(p+vec2(4.7,9.2))*0.76+ground_noise(p*2.1)*0.24;
        float cloud=smoothstep(0.57,0.72,shape)*smoothstep(0.045,0.18,height);
        colour=mix(colour,tactical_landscape ? vec3(0.88,0.90,0.84) : vec3(0.87,0.89,0.84),cloud*(tactical_landscape ? 0.40 : 0.53));
    }
    if (tactical_landscape && dot(source_horizon_line.xy,source_horizon_line.xy)>0.5) {
        float elevation=-dot(vec3(source_pixel,1.0),source_horizon_line)/source_focal_pixels;
        if (elevation>=0.0 && elevation<0.14) colour=horizon_vegetation(colour,direction,elevation,horizon_footprint);
    }
    return OUTPUT_IS_SRGB ? colour : pow(colour,vec3(2.2));
}

// Bounded material light on existing facets, sharing the meadow/foliage sun.
// The authored palette still supplies all paint, insignia and surface colours.
vec3 tactical_daylight(vec3 base, vec3 normal, vec3 to_eye, float sheen) {
    vec3 sun_direction=normalize(vec3(-0.58,0.34,0.74));
    float sun=max(dot(normal,sun_direction),0.0);
    float sky=clamp(normal.z*0.5+0.5,0.0,1.0);
    vec3 tint=mix(vec3(0.96,1.01,1.045),vec3(1.035,1.02,0.955),sun);
    tint*=0.82+sky*0.16+sun*0.18;
    vec3 halfway=sun_direction+to_eye;
    halfway/=max(length(halfway),0.0001);
    float highlight=pow(max(dot(normal,halfway),0.0),18.0)*sheen;
    // No view-facing rim, bloom, or lit silhouette through source occluders.
    vec3 result=base*(OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2)));
    return result+(OUTPUT_IS_SRGB ? vec3(highlight) : vec3(highlight*0.35));
}

// Authored material families choose a restrained lobe strength and width.
// Mineral surfaces stay matte, paint and rubber differ, cloth is very subdued.
vec2 tactical_highlight_response(float family) {
    if(family<1.5)return vec2(0.028,22.0);
    if(family<3.5)return vec2(0.0,8.0);
    if(family<4.5)return vec2(0.004,10.0);
    if(family<5.5)return vec2(0.0025,7.0);
    if(family<6.5)return vec2(0.006,9.0);
    if(family<7.5)return vec2(0.007,12.0);
    return vec2(0.0,18.0);
}

// The existing filtered atlas gain is a decorative roughness cue, not a
// measured roughness map. Peak strength never exceeds the preceding family.
// Broader lobes receive a lower peak; matte and neutral cues remain exact.
vec2 tactical_textured_response(float family,float texture_gain) {
    vec2 response=tactical_highlight_response(family);
    if(family<0.5 || family>7.5 || response.x==0.0 || texture_gain==1.0)return response;
    float roughness=clamp((1.0-texture_gain)/0.18,-1.0,1.0);
    float power=response.y*exp2(-0.45*roughness);
    return vec2(response.x*min(1.0,power/response.y),power);
}

vec3 tactical_textured_finish_light(vec3 base,vec3 normal,vec3 eye,float legacy_sheen,float family,float distance,float eye_pixel,float texture_gain) {
    if(family<0.5 || !tactical_daylight_observed())return tactical_daylight(base,normal,eye,legacy_sheen);
    vec3 result=tactical_daylight(base,normal,eye,0.0);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    vec3 sum=sun+eye;
    vec3 halfway=sum/max(length(sum),0.0001);
    vec2 response=tactical_textured_response(family,texture_gain);
    float light=pow(max(dot(normal,halfway),0.0),response.y)*response.x;
    // Only sun-facing source facets receive the lobe. A filtered warm tint
    // preserves the original paint rather than bleaching it into white/chrome.
    light*=max(dot(normal,sun),0.0)*tactical_glint_fade(distance,eye_pixel);
    return result+vec3(1.0,0.97,0.88)*light*(OUTPUT_IS_SRGB ? 1.0 : 0.35);
}

// Keep the neutral response available to existing diagnostics and callers.
vec3 tactical_finish_light(vec3 base,vec3 normal,vec3 eye,float legacy_sheen,float family,float distance,float eye_pixel) {
    return tactical_textured_finish_light(base,normal,eye,legacy_sheen,family,distance,eye_pixel,1.0);
}

// Existing opaque glass facets only. Sky tint is analytic: no scene sampler,
// hidden actor reflection, transparency, extra pass or independently moving sun.
vec3 tactical_glazing(vec3 base, vec3 normal, vec3 eye, float distance, float eye_pixel) {
    vec3 ray=reflect(-eye,normal);
    float grazing=pow(1.0-clamp(abs(dot(normal,eye)),0.0,1.0),3.0);
    vec3 sky=tactical_daylight_observed() ? tactical_sky_colour(ray) : mix(vec3(0.52,0.61,0.61),vec3(0.28,0.45,0.54),smoothstep(0.0,0.65,max(ray.z,0.0)));
    sky=OUTPUT_IS_SRGB ? sky : pow(sky,vec3(2.2));
    vec3 result=mix(base*(OUTPUT_IS_SRGB ? 0.78 : pow(0.78,2.2)),sky,0.12+grazing*0.26);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    vec3 half_sum=sun+eye;
    vec3 half_light=half_sum/max(length(half_sum),0.001);
    float light=pow(max(dot(normal,half_light),0.0),16.0)*max(dot(normal,sun),0.0);
    light*=0.075*(1.0-smoothstep(700.0,4000.0,distance));
    if(tactical_daylight_observed())light*=tactical_glint_fade(distance,eye_pixel);
    result+=OUTPUT_IS_SRGB ? vec3(0.94,0.97,0.87)*light : vec3(0.94,0.97,0.87)*light*0.35;
    return result;
}

vec3 tactical_textured_glazing(vec3 base,vec3 normal,vec3 eye,float distance,float eye_pixel,float gain) {
    vec3 ray=reflect(-eye,normal);
    float roughness=clamp(0.34+(1.0-gain)*1.5,0.15,0.65);
    vec3 sky=tactical_optical_environment(tactical_sky_colour(ray),ray,roughness);
    sky=OUTPUT_IS_SRGB ? sky : pow(sky,vec3(2.2));
    float reflection=tactical_optical_fresnel(abs(dot(normal,eye)),0.065,0.48)*(1.0-roughness*0.12);
    vec3 result=mix(base*(OUTPUT_IS_SRGB ? 0.82 : pow(0.82,2.2)),sky,reflection);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    vec3 sum=sun+eye;vec3 halfway=sum/max(length(sum),0.0001);
    vec2 response=tactical_optical_response(gain,24.0,eye_pixel);
    float light=pow(max(dot(normal,halfway),0.0),response.y)*response.x*max(dot(normal,sun),0.0);
    light*=0.075*(1.0-smoothstep(700.0,4000.0,distance))*tactical_glint_fade(distance,eye_pixel);
    return result+vec3(1.0,0.97,0.88)*light*(OUTPUT_IS_SRGB ? 1.0 : 0.35);
}

// Existing vent, canvas and rubber facets. Louvres already exist in the mesh;
// deepen their material rather than painting invented slots or tyre treads.
vec3 tactical_equipment(vec3 base, vec2 source, vec2 footprint, float kind) {
    vec3 tint=vec3(0.72,0.75,0.77);
    if (kind>19.8) {
        float grain=ground_noise(source/7.0)-0.5;
        float fade=1.0-smoothstep(0.25,0.65,max(footprint.x,footprint.y)/7.0);
        tint=vec3(0.84,0.865,0.88)*(1.0+grain*0.045*fade);
    } else if (kind>19.7) {
        float patch=ground_noise(source/vec2(22.0,28.0))-0.5;
        float broad=1.0-smoothstep(0.30,0.80,max(footprint.x/22.0,footprint.y/28.0));
        vec2 weave=source/1.6;
        float fade=1.0-smoothstep(0.18,0.45,max(footprint.x,footprint.y)/1.6);
        float thread=sin(weave.x*6.2831853)*sin(weave.y*6.2831853)*0.022*fade;
        tint=vec3(1.025,1.015,0.99)*(1.0+patch*0.14*broad+thread);
    }
    return base*(OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2)));
}

// Each verified hill face already carries a source-fixed UV plane. Reuse it
// for material light as well as colour, including vertical x/z and y/z faces.
vec3 tactical_slope_normal(vec3 face, vec2 gradient, float kind) {
    vec3 relief=vec3(-gradient.x,-gradient.y,0.0);
    if (kind>8.5) relief=vec3(-gradient.x,0.0,-gradient.y);
    else if (kind>7.5) relief=vec3(0.0,-gradient.x,-gradient.y);
    relief-=face*dot(face,relief);
    return normalize(face+relief*0.8);
}

// Soil variation is confined to existing classified earth slopes. It adds no
// rocks, ledges, vegetation, geometry, new texture or independent simulation.
vec3 tactical_soil(vec3 base, vec2 surface, vec2 dx, vec2 dy, vec3 face, vec3 eye, float kind, float distance) {
    vec2 footprint=abs(dx)+abs(dy);
    float broad=textureLod(hill_detail,surface/1536.0,tactical_ground_broad_lod(footprint,1536.0,vec2(textureSize(hill_detail,0)))).r;
    float middle=textureGrad(hill_detail,surface/384.0,dx/384.0,dy/384.0).r;
    float fine=textureGrad(hill_detail,surface/96.0,dx/96.0,dy/96.0).r;
    float sx=textureGrad(hill_detail,(surface+vec2(12.0,0.0))/96.0,dx/96.0,dy/96.0).r-fine;
    float sy=textureGrad(hill_detail,(surface+vec2(0.0,12.0))/96.0,dx/96.0,dy/96.0).r-fine;
    float fine_fade=tactical_ground_detail(footprint,96.0);
    float near=1.0-smoothstep(2400.0,12000.0,distance);
    vec3 normal=tactical_slope_normal(face,vec2(sx,sy)*fine_fade,kind);
    float patch=clamp(broad*0.55+middle*0.45,0.0,1.0);
    vec3 tint=mix(vec3(0.90,0.88,0.83),vec3(1.16,1.08,0.91),patch);
    tint*=1.0+(fine-hill_mean)*0.16*fine_fade*near;
    base*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));
    vec3 lit=tactical_daylight(base,normal,eye,0.0);
    vec3 distant=tactical_daylight(base,face,eye,0.0);
    vec3 result=mix(distant,lit,near);
    if(modern_environment_polish && tactical_daylight_observed()) {
        vec3 tint=tactical_environment_tint(normal,0.55);
        result*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));
    }
    return result;
}

// Periodic material seams fade before their period falls below two pixels.
// Derivatives are supplied before ownership discard, never taken on cutout lanes.
float tactical_seam(float coordinate, float footprint, float width) {
    float edge=max(footprint*0.65,0.008);
    float distance=min(fract(coordinate),1.0-fract(coordinate));
    return (1.0-smoothstep(width,width+edge,distance))*(1.0-smoothstep(0.20,0.50,footprint));
}

vec3 tactical_structure(vec3 base, vec2 source, vec2 footprint, float kind) {
    float amount=1.0;
    if (kind>20.45) {
        vec2 tile=source/vec2(18.0,14.0);
        vec2 pixel=footprint/vec2(18.0,14.0);
        float course=tactical_seam(tile.y,pixel.y,0.035);
        float stagger=mod(floor(tile.y),2.0)*0.5;
        float joint=tactical_seam(tile.x+stagger,pixel.x,0.028);
        joint*=1.0-smoothstep(0.20,0.50,pixel.y);
        float glaze=sin(tile.y*6.2831853)*0.025*(1.0-smoothstep(0.20,0.50,pixel.y));
        amount=1.0-course*0.16-joint*0.065+glaze;
    } else if (kind>20.4) {
        float joint=tactical_seam(source.x/64.0,footprint.x/64.0,0.012);
        amount=1.0-joint*0.09;
    } else {
        // Broad plaster variation and a restrained plinth tint. No invented
        // windows, damage, bricks or geometry on the original wall.
        float plaster=ground_noise(source/vec2(43.0,31.0))-0.5;
        float scale=max(footprint.x/43.0,footprint.y/31.0);
        float detail=1.0-smoothstep(0.30,0.80,scale);
        float foot=1.0-smoothstep(1.0,20.0,source.y);
        amount=1.0+plaster*0.10*detail-foot*0.075;
    }
    return base*(OUTPUT_IS_SRGB ? vec3(amount) : vec3(pow(amount,2.2)));
}

// Authored doors, timber panels and stone trim only. Preserve their painted
// colours and topology; surface fibres and minerals never invent damage/joints.
vec3 tactical_architecture(vec3 base, vec2 source, vec2 footprint, float finish) {
    float amount=1.0;
    if (finish<2.5) {
        float broad=ground_noise(source/vec2(31.0,79.0))-0.5;
        vec2 fibres=source/vec2(3.8,67.0);
        fibres.x+=sin(fibres.y*2.1)*0.28;
        float scale=max(footprint.x/3.8,footprint.y/67.0);
        float fade=1.0-smoothstep(0.18,0.50,scale);
        float grain=ground_noise(fibres)-0.5;
        float thread=sin(fibres.x*6.2831853+sin(fibres.y)*0.7);
        float coarse_fade=1.0-smoothstep(0.30,0.80,max(footprint.x/31.0,footprint.y/79.0));
        amount=1.0+broad*0.07*coarse_fade+(grain*0.065+thread*0.012)*fade;
        if (finish>1.5) amount-=0.025*coarse_fade;
    } else {
        float scale=max(footprint.x,footprint.y);
        float mineral=ground_noise(source/vec2(5.0,4.0))-0.5;
        float pores=ground_noise(source/1.9)-0.5;
        amount=1.0+mineral*0.075*(1.0-smoothstep(1.0,2.5,scale));
        amount+=pores*0.035*(1.0-smoothstep(0.35,0.95,scale));
        // Only existing plinth pieces receive this restrained base tint.
        // Window and door surrounds keep their lighter stone finish.
        if (finish>3.5) {
            float base_fade=1.0-smoothstep(4.0,12.0,scale);
            float weather=0.045+(ground_noise(source/vec2(39.0,27.0))-0.5)*0.025;
            amount-=weather*base_fade;
        }
    }
    return base*(OUTPUT_IS_SRGB ? vec3(amount) : vec3(pow(amount,2.2)));
}

// Neutral authored bitmap detail. Source-local UVs follow the owning face;
// mirrored repeat joins edges exactly, and supplied gradients keep mip choice
// valid before source-ownership discard. Palette, normals and coverage stay put.
vec3 tactical_material(vec3 base, vec2 source, vec2 footprint, vec2 dx, vec2 dy, float finish, float distance) {
    float period=finish<1.5 ? 78.0 : finish<2.5 ? 136.0 : 44.0;
    vec2 uv=source/period;
    vec2 tile=1.0-abs(fract(uv)*2.0-1.0);
    dx*=2.0/period;dy*=2.0/period;
    float value;
    float mean;
    float strength;
    if (finish<1.5) {
        value=textureGrad(tactical_steel_detail,tile,dx,dy).r;
        mean=0.454363346;strength=0.55;
    } else if (finish<2.5) {
        value=textureGrad(tactical_plaster_detail,tile,dx,dy).r;
        mean=0.598401989;strength=0.65;
    } else {
        value=textureGrad(tactical_stone_detail,tile,dx,dy).r;
        mean=0.690467338;strength=0.55;
    }
    float fade=(1.0-smoothstep(1800.0,6500.0,distance));
    fade*=1.0-smoothstep(0.018,0.10,max(footprint.x,footprint.y)/period);
    float amount=1.0+clamp((value-mean)*strength,-0.075,0.075)*fade;
    return base*(OUTPUT_IS_SRGB ? vec3(amount) : vec3(pow(amount,2.2)));
}

vec3 tactical_wheel(vec3 base, vec2 local, vec2 footprint) {
    float radius=length(local);
    float pixel=max(length(footprint),0.001);
    float fade=1.0-smoothstep(0.10,0.32,pixel);
    float hub=1.0-smoothstep(0.20-pixel,0.20+pixel,radius);
    float rim=(1.0-smoothstep(0.026,0.026+pixel,abs(radius-0.72)))*fade;
    float spokes=1.0-smoothstep(0.14,0.14+pixel*4.0,abs(sin(atan(local.y,local.x)*3.0)));
    spokes*=smoothstep(0.22,0.22+pixel,radius)*(1.0-smoothstep(0.64-pixel,0.64+pixel,radius))*fade;
    float rubber=smoothstep(0.76-pixel,0.76+pixel,radius);
    float amount=1.0+hub*0.10+rim*0.15-spokes*0.22-rubber*0.18;
    return base*(OUTPUT_IS_SRGB ? vec3(amount) : vec3(pow(amount,2.2)));
}

// Signed derivative of the same repeated seam profile used by painted marks.
// A finite bevel width and footprint fade prevent subpixel ridge glitter.
float tactical_bevel_slope(float coordinate,float pixel,float width,float height) {
    float edge=max(pixel*0.65,0.008);
    float p=fract(coordinate+0.5)-0.5;
    float t=clamp((abs(p)-width)/edge,0.0,1.0);
    return -height*sign(p)*6.0*t*(1.0-t)/edge*(1.0-smoothstep(0.20,0.50,pixel));
}

// Macrorelief uses only existing wheel/link/roof markings. No new hardware,
// coverage or phase. Gradients are per source UV, not per screen pixel.
vec2 tactical_form_gradient(vec2 source,vec2 footprint,float kind,float distance,float family) {
    vec2 gradient=vec2(0.0);
    if(kind>20.1 && kind<20.2) {
        gradient.x=tactical_bevel_slope(source.x,footprint.x,0.065,-0.09);
        gradient.x+=tactical_bevel_slope(source.x-0.15,footprint.x,0.028,0.035);
    } else if(kind>20.2 && kind<20.3) {
        float radius=length(source);float pixel=max(length(footprint),0.001);
        float resolved=1.0-smoothstep(0.10,0.32,pixel);
        float dish=1.0-smoothstep(0.62,0.76,radius);
        gradient=-source*1.6*dish*resolved;
        float ring=tactical_bevel_slope(radius-0.72,pixel,0.026,0.10);
        gradient+=source/max(radius,0.20)*ring*resolved;
        float angle=radius>0.001 ? atan(source.y,source.x) : 0.0;
        float phase=angle*(3.0/3.14159265);
        float angle_pixel=pixel*(3.0/3.14159265)/max(radius,0.20);
        float spoke=tactical_bevel_slope(phase,angle_pixel,0.045,-0.075);
        vec2 radial=vec2(-source.y,source.x)/max(dot(source,source),0.04)*(3.0/3.14159265);
        float band=smoothstep(0.22,0.28,radius)*(1.0-smoothstep(0.60,0.66,radius));
        gradient+=radial*spoke*band*resolved;
    } else if(kind>20.45 && kind<20.48 && family>6.5 && family<7.5) {
        vec2 tile=source/vec2(18.0,14.0);vec2 pixel=footprint/vec2(18.0,14.0);
        float stagger=mod(floor(tile.y),2.0)*0.5;
        gradient.y=tactical_bevel_slope(tile.y,pixel.y,0.035,-0.16)/14.0;
        float joint=tactical_bevel_slope(tile.x+stagger,pixel.x,0.028,-0.07)/18.0;
        // The existing stagger changes at a course boundary. Quiet the joint's
        // slope there rather than introducing a discontinuous normal seam.
        float boundary=abs(fract(tile.y+0.5)-0.5);
        joint*=smoothstep(0.0,max(pixel.y,0.04),boundary);
        gradient.x=joint*(1.0-smoothstep(0.20,0.50,pixel.y));
    } else if(kind>20.4 && kind<20.45 && family>6.5 && family<7.5) {
        gradient.x=tactical_bevel_slope(source.x/64.0,footprint.x/64.0,0.012,-0.12)/64.0;
    }
    return gradient*(1.0-smoothstep(1600.0,8000.0,distance));
}

// Source-unit relief amplitudes and maximum tangent slopes. Paint is fine,
// minerals deeper, fabric/rubber subdued. Unknown families stay flat.
vec2 tactical_relief_profile(float family) {
    if(family<0.5 || family>7.5)return vec2(0.0);
    if(family<1.5)return vec2(0.45,0.15);
    if(family<2.5)return vec2(0.80,0.18);
    if(family<3.5)return vec2(1.80,0.28);
    if(family<4.5)return vec2(0.70,0.22);
    if(family<5.5)return vec2(0.10,0.08);
    if(family<6.5)return vec2(0.08,0.06);
    return vec2(1.00,0.22);
}

// Convert a source-UV height gradient to the existing face's world tangent
// plane. Derivatives are supplied before ownership clipping, never taken here.
vec3 tactical_relief_normal(vec3 face,vec2 gradient,vec3 position_dx,vec3 position_dy,vec2 uv_dx,vec2 uv_dy,float family) {
    vec2 profile=tactical_relief_profile(family);
    if(profile.x==0.0 || dot(gradient,gradient)<0.00000001)return face;
    vec3 u=cross(position_dy,face);
    vec3 v=cross(face,position_dx);
    float determinant=dot(position_dx,u);
    float area=length(position_dx)*length(position_dy);
    if(area<0.00000001 || abs(determinant)<area*0.0001)return face;
    vec3 slope=(u*dot(gradient,uv_dx)+v*dot(gradient,uv_dy))/determinant;
    slope-=face*dot(face,slope);
    slope*=profile.x;
    slope*=min(1.0,profile.y/max(length(slope),0.000001));
    return normalize(face-slope);
}

// Interpolated UV is not guaranteed bit-exact for a per-vertex constant. The
// nearest distinct kind tags are 1/256 apart, so 1/1024 cannot select another.
bool kind_is(float tag, float kind) {
    return abs(tag-kind)<0.0009765625;
}

void vertex() {
    source_owner = floor(UV.y/32.0);
    UV.y = mod(UV.y,32.0);
    // Decode the material tag back to the exact incumbent kind before all
    // depth, roof, lighting and Modernized branches consume it.
    material_finish=0.0;
    if (UV.y==20.01171875) { material_finish=1.0;UV.y=20.0; }
    else if (UV.y==20.3828125) { material_finish=2.0;UV.y=20.375; }
    else if (UV.y==20.09375 || UV.y==20.5) material_finish=1.0;
    architecture_finish=0.0;
    if (UV.y==20.3125) { architecture_finish=1.0;UV.y=20.0; }
    else if (UV.y==20.34375) { architecture_finish=2.0;UV.y=20.375; }
    else if (UV.y==20.390625) { architecture_finish=3.0;UV.y=20.375; }
    else if (UV.y==20.4140625) { architecture_finish=3.0;UV.y=20.4375; }
    else if (UV.y==20.359375) { architecture_finish=4.0;UV.y=20.375; }
    else if (UV.y==20.421875) { architecture_finish=4.0;UV.y=20.4375; }
    if (architecture_finish>2.5) material_finish=3.0;
    realism_crew_point=vec2(0.0);
    realism_family=material_finish;
    if(UV.y>=24.0 && UV.y<28.0) {
        float basis=floor(UV.y-24.0);
        realism_family=round(fract(UV.y)*64.0);
        UV.y=basis<0.5 ? 20.0 : basis<1.5 ? 20.375 : basis<2.5 ? 20.4375 : 20.46875;
    } else if(UV.y==20.0625) {
        realism_family=floor(UV2.y/512.0);
        realism_crew_point=vec2(fract(UV2.x)*1024.0-512.0,mod(UV2.y,512.0)-128.0);
        UV2.x=floor(UV2.x);UV2.y=0.0;UV.y=20.0625;
    } else if(UV.y==23.0)realism_family=14.0;
    else if(UV.y==20.25390625) {realism_family=6.0;UV.y=20.25;}
    else if(architecture_finish>0.5 && architecture_finish<2.5)realism_family=4.0;
    else if(UV.y>20.4 && UV.y<20.48 && realism_family<0.5)realism_family=7.0;
    else if(UV.y==19.625 || UV.y==20.125 || UV.y==20.25)realism_family=1.0;
    else if(UV.y==19.75)realism_family=5.0;
    else if(UV.y==19.875)realism_family=6.0;
    else if(UV.y==20.0078125)realism_family=13.0;
    original_view = vec3(VERTEX.x,-VERTEX.z,VERTEX.y)*64.0;
}

void fragment() {
    float effect_filter=0.0;
    float effect_fine_filter=0.0;
    if(tactical_landscape && modern_active && UV.y>3.5 && UV.y<4.5) {
        // Unwrapped atlas derivatives precede both owner and alpha discard.
        // Only colour is filtered; donor sampling and coverage remain exact.
        vec2 effect_uv=UV2*vec2(5.0,4.0)*516.0/512.0;
        float footprint=max(length(dFdx(effect_uv)),length(dFdy(effect_uv)));
        effect_filter=1.0-smoothstep(0.08,0.45,footprint*11.0);
        effect_fine_filter=1.0-smoothstep(0.08,0.45,footprint*23.0);
    }
    // Evaluate derivatives before the ownership discard. Evaluating them in
    // surviving fragments alone leaves paint-edge helper lanes undefined.
    vec2 hind_footprint=vec2(0.0);
    if ((UV.y > 20.08 && UV.y < 20.1) || (UV.y > 20.48 && UV.y < 20.51)) hind_footprint=fwidth(UV2);
    vec2 finish_footprint=vec2(0.0);
    vec2 finish_dx=vec2(0.0);vec2 finish_dy=vec2(0.0);
    if (tactical_landscape && modern_active && ((UV.y>20.1 && UV.y<20.48) || (UV.y>19.55 && UV.y<19.95) || architecture_finish>0.5 || material_finish>0.5)) {
        finish_dx=dFdx(UV2);finish_dy=dFdy(UV2);
        finish_footprint=abs(finish_dx)+abs(finish_dy);
    }
    vec2 material_dx=vec2(0.0);
    vec2 material_dy=vec2(0.0);
    if (tactical_landscape && modern_surface_variation && tactical_material_ready && material_finish>0.5) {
        material_dx=dFdx(UV2);material_dy=dFdy(UV2);
    }
    vec2 tree_dx=vec2(0.0);vec2 tree_dy=vec2(0.0);
    vec2 bark_footprint=vec2(0.0);
    if (tactical_landscape && modern_active && UV.y>20.5 && UV.y<21.5) {
        tree_dx=dFdx(UV2);tree_dy=dFdy(UV2);
        bark_footprint=abs(tree_dx)+abs(tree_dy);
    }
    vec2 terrain_dx=vec2(0.0);vec2 terrain_dy=vec2(0.0);
    vec2 terrain_footprint=vec2(0.0);
    if (tactical_landscape && modern_active &&
            ((UV.y>0.5 && UV.y<3.5) || (UV.y>6.5 && UV.y<9.5) || (UV.y>13.5 && UV.y<14.5))) {
        vec3 local=camera_to_local*original_view;
        if (UV.y>2.5 && UV.y<3.5) {
            // Evaluate the same background z=0 projection before source clipping.
            // The safe denominator prevents invalid helper-lane values at the
            // horizon. Unusable rays are still excluded by the existing branch.
            local*= -world_origin.z/min(local.z,-0.0001);
        }
        vec3 position=world_origin+vec3(local.x,-local.y,local.z);
        vec2 surface=position.xy;
        if (UV.y>8.5 && UV.y<9.5) surface=position.xz;
        else if (UV.y>7.5 && UV.y<8.5) surface=position.yz;
        terrain_dx=dFdx(surface);terrain_dy=dFdy(surface);
        terrain_footprint=abs(terrain_dx)+abs(terrain_dy);
    }
    vec3 tactical_normal=vec3(0.0,0.0,1.0);
    vec3 tactical_to_eye=vec3(0.0,0.0,1.0);
    float tactical_eye_pixel=0.0;
    vec3 tactical_position_dx=vec3(0.0);vec3 tactical_position_dy=vec3(0.0);
    if (tactical_landscape && modern_active) {
        // Derivatives precede ownership discard, so cutout helper lanes remain
        // defined. Undo the source camera and its y sign, just as foliage does.
        vec3 local=camera_to_local*original_view;
        vec3 relative=vec3(local.x,-local.y,local.z);
        tactical_position_dx=dFdx(relative);tactical_position_dy=dFdy(relative);
        vec3 face=cross(tactical_position_dx,tactical_position_dy);
        if (dot(face,face)>0.000001) {
            tactical_normal=normalize(face);
            if (dot(tactical_normal,relative)>0.0) tactical_normal=-tactical_normal;
        }
        tactical_to_eye=-relative/max(length(relative),0.0001);
        tactical_eye_pixel=max(length(dFdx(tactical_to_eye)),length(dFdy(tactical_to_eye)));
    }
    vec2 realism_uv=UV2;
    float family=realism_family;
    vec3 realism_local=camera_to_local*original_view;
    bool realism_usable=true;
    if(UV.y>0.5 && UV.y<9.5 && !(UV.y>3.5 && UV.y<6.5)) {
        if(UV.y>2.5 && UV.y<3.5) {
            realism_usable=world_origin.z>0.0 && realism_local.z< -0.0001;
            if(realism_usable)realism_local*= -world_origin.z/realism_local.z;
        }
        vec3 position=world_origin+vec3(realism_local.x,-realism_local.y,realism_local.z);
        realism_uv=position.xy;
        if(UV.y>8.5)realism_uv=position.xz;
        else if(UV.y>7.5)realism_uv=position.yz;
        family=UV.y>1.5 && UV.y<2.5 ? 11.0 : UV.y>6.5 && abs(UV.x-19.0)>0.25 ? 10.0 : 8.0;
    } else if(kind_is(UV.y,14.0) || kind_is(UV.y,20.03125)) {
        realism_uv=world_origin.xy+vec2(realism_local.x,-realism_local.y);
        family=kind_is(UV.y,14.0) ? 12.0 : 8.0;
    } else if(kind_is(UV.y,21.0)) {
        family=UV2.y>=0.805 ? 4.0 : 9.0;
        realism_uv=UV2*vec2(100.0,220.0);
    }
    if(kind_is(UV.y,20.0625) && family>0.5)realism_uv=realism_crew_point;
    if(kind_is(UV.y,23.0))realism_uv=UV2*80.0;
    realism_uv/=realism_period(family);
    // Wheels/tracks use normalized moving coordinates rather than raw units.
    if(kind_is(UV.y,20.25) || kind_is(UV.y,20.125))realism_uv=UV2*0.8;
    vec2 realism_dx=vec2(0.0);vec2 realism_dy=vec2(0.0);
    if(tactical_landscape && tactical_realism_ready && modern_surface_variation && family>0.5) {
        realism_dx=dFdx(realism_uv);realism_dy=dFdy(realism_uv);
    }
    vec4 horizon_footprint=vec4(0.0);
    if(tactical_landscape && modern_active && modern_environment_polish && camera_basis_ready && tactical_daylight_observed()) {
        // Before owner discard and the per-fragment horizon/crown branches.
        vec3 direction=normalize(camera_to_local*original_view);
        vec2 angular=tactical_horizon_gradient(direction,dFdx(direction),dFdy(direction));
        vec2 source_pixel=SCREEN_UV*source_dimensions+source_origin;
        float elevation=-dot(vec3(source_pixel,1.0),source_horizon_line)/source_focal_pixels;
        horizon_footprint=vec4(angular,dFdx(elevation),dFdy(elevation));
    }
    if (modern_active && source_owner > 0.5) {
        vec3 ownership = texture(source_ownership,SCREEN_UV).rgb;
        vec2 packed_owner = round(ownership.rg*255.0);
        float owner = packed_owner.x + packed_owner.y*256.0;
        if (abs(owner-source_owner)>0.25) discard;
        // Exact observed round-command writes override inferred model facets.
        if ((ownership.b>0.5) != (UV.y>21.5)) discard;
    }
    vec3 finish_sample=vec3(1.0,0.0,0.0);
    bool finish_sampled=false;
    vec3 finish_normal=tactical_normal;
    if(tactical_landscape && modern_active && modern_surface_variation && tactical_realism_ready && detail_levels>1.0 &&
            tactical_daylight_observed() && UV.y>19.5 && UV.y<20.51 && !(UV.y>20.04 && UV.y<20.08) && family>0.5 && family<7.5) {
        finish_sample=realism_sample(realism_uv,realism_dx,realism_dy,family,length(realism_local));
        finish_sampled=true;
        finish_normal=tactical_relief_normal(tactical_normal,finish_sample.yz,tactical_position_dx,tactical_position_dy,realism_dx,realism_dy,family);
    }
    if(tactical_landscape && modern_active && modern_surface_variation && detail_levels>1.0 && tactical_daylight_observed()) {
        vec2 form=tactical_form_gradient(UV2,finish_footprint,UV.y,length(original_view),family);
        if(dot(form,form)>0.00000001) {
            // Sum both height derivatives in screen x/y, then apply the existing
            // source-face conversion and material slope limit exactly once.
            vec2 height_pixel=vec2(dot(form,finish_dx),dot(form,finish_dy));
            if(finish_sampled)height_pixel+=vec2(dot(finish_sample.yz,realism_dx),dot(finish_sample.yz,realism_dy));
            finish_normal=tactical_relief_normal(tactical_normal,vec2(1.0,0.0),tactical_position_dx,tactical_position_dy,vec2(height_pixel.x,0.0),vec2(height_pixel.y,0.0),family);
        }
    }
    if (UV.y > 21.5) {
        ALBEDO = texture(material_patterns,vec2(UV.x*2.0+0.5,floor(detail_levels*0.5)*2.0+0.5)/vec2(pattern_width,detail_levels*2.0)).rgb;
        if (modern_active && UV.y>22.5 && UV.y<23.5) ALBEDO=crew_head_paint(UV2);
    } else if (UV.y > 20.5) {
        vec4 tree = tactical_landscape ? textureGrad(modern_tree,UV2,tree_dx,tree_dy) : texture(modern_tree,UV2);
        bool tactical_trunk=tactical_landscape && UV2.y>=0.805;
        // A tapered stem stays inside the original trunk plane. A bounded
        // pixel footprint prevents mipmapped alpha from erasing it at distance.
        float trunk_width=mix(0.07,0.05,clamp((0.995-UV2.y)/0.19,0.0,1.0));
        float trunk_pixel=tactical_landscape ? bark_footprint.x : fwidth(UV2.x);
        trunk_width=max(trunk_width,min(trunk_pixel*0.65,0.1));
        if (tactical_trunk) tree.a=abs(UV2.x-0.5)<=trunk_width ? 1.0 : 0.0;
        // Filtering must not erase the entire distant crown. The original
        // ownership gate still bounds every recovered Tactical leaf fragment.
        float leaf_cutoff=tactical_landscape ? mix(0.72,0.38,smoothstep(0.006,0.04,max(bark_footprint.x,bark_footprint.y))) : 0.85;
        if (tree.a < leaf_cutoff) discard;
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
            if (tactical_landscape) {
                // Keep the authored leaf facets readable instead of multiplying
                // an already shaded crown down into near-black olive.
                float facet=clamp(light*1.7,0.0,1.0);
                vec3 crown=mix(vec3(0.16,0.25,0.12),vec3(0.48,0.59,0.31),facet);
                crown*=mix(0.92,1.08,UV.x);
                if (modern_surface_variation) {
                    crown=tactical_crown(tree.rgb,UV2,UV.x);
                    if(camera_basis_ready && tactical_daylight_observed())crown=tactical_tree_light(crown,UV2,bark_footprint,tactical_to_eye,length(original_view));
                }
                vec3 leaf_colour=OUTPUT_IS_SRGB ? crown : pow(crown,vec3(2.2));
                ALBEDO=mix(ALBEDO,leaf_colour,green);
            }
        }
        if (tactical_trunk) {
            float facet=smoothstep(0.5-trunk_width,0.5+trunk_width*0.4,UV2.x);
            vec3 bark=mix(vec3(0.48,0.39,0.27),vec3(0.28,0.24,0.17),facet);
            if (modern_surface_variation) bark=tactical_bark(bark,UV2,bark_footprint);
            if(modern_environment_polish && modern_surface_variation && camera_basis_ready && tactical_daylight_observed())bark*=tactical_trunk_fill(UV2,bark_footprint,trunk_width);
            ALBEDO=OUTPUT_IS_SRGB ? bark : pow(bark,vec3(2.2));
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
            if (tactical_landscape) ALBEDO=tactical_structure(ALBEDO,UV2,finish_footprint,UV.y);
        } else if (UV.y > 20.2 && UV.y < 20.3) {
            if (tactical_landscape && modern_surface_variation) ALBEDO=tactical_wheel(ALBEDO,UV2,finish_footprint);
            else {
                float radius = length(UV2);
                float spoke = abs(sin(atan(UV2.y,UV2.x)*3.0));
                if (radius>0.2 && radius<0.72 && spoke<0.2) ALBEDO *= 0.72;
            }
        } else if (UV.y > 20.1 && UV.y < 20.2) {
            if (tactical_landscape && modern_surface_variation) {
                float groove=tactical_seam(UV2.x,finish_footprint.x,0.065);
                float edge=tactical_seam(UV2.x-0.15,finish_footprint.x,0.028);
                float amount=1.0-groove*0.23+edge*0.09;
                ALBEDO*=OUTPUT_IS_SRGB ? vec3(amount) : vec3(pow(amount,2.2));
            } else if (fract(UV2.x)<0.18) ALBEDO*=0.78;
        }
        if (tactical_landscape && modern_surface_variation && architecture_finish>0.5) {
            ALBEDO=tactical_architecture(ALBEDO,UV2,finish_footprint,architecture_finish);
        }
        if (tactical_landscape && modern_surface_variation && tactical_material_ready && material_finish>0.5) {
            ALBEDO=tactical_material(ALBEDO,UV2,finish_footprint,material_dx,material_dy,material_finish,length(original_view));
        }
        if (tactical_landscape && modern_surface_variation && !(UV.y>20.015 && UV.y<20.08)) {
            // Courtyard grass and source-ordered crew planes keep their own
            // treatments. Explicit material families determine the restrained
            // highlight; unclassified facets retain their preceding response.
            bool matte=UV.y>20.1 && UV.y<20.48;
            if (UV.y>19.55 && UV.y<19.95) {
                ALBEDO=tactical_equipment(ALBEDO,UV2,finish_footprint,UV.y);
                ALBEDO=tactical_textured_finish_light(ALBEDO,finish_normal,tactical_to_eye,UV.y<19.7 ? 0.008 : 0.0,family,length(original_view),tactical_eye_pixel,finish_sample.x);
            } else if (UV.y>20.006 && UV.y<20.010) {
                if(modern_environment_polish && tactical_daylight_observed() && tactical_realism_ready && detail_levels>1.0) {
                    finish_sample=realism_sample(realism_uv,realism_dx,realism_dy,family,length(realism_local));
                    finish_sampled=true;
                    ALBEDO=tactical_textured_glazing(ALBEDO,tactical_normal,tactical_to_eye,length(original_view),tactical_eye_pixel,finish_sample.x);
                } else ALBEDO=tactical_glazing(ALBEDO,tactical_normal,tactical_to_eye,length(original_view),tactical_eye_pixel);
            } else {
                ALBEDO=tactical_textured_finish_light(ALBEDO,finish_normal,tactical_to_eye,matte ? 0.0 : 0.028,family,length(original_view),tactical_eye_pixel,finish_sample.x);
            }
        }
    } else if (UV.y > 15.5 && UV.y < 16.5 && modern_active) {
        ALBEDO=texture(material_means,vec2((round(UV.x)+0.5)/(pattern_width*0.5),0.5)).rgb;
        if (modern_environment_polish && camera_basis_ready) ALBEDO=daylight_sky(camera_to_local*original_view,SCREEN_UV*source_dimensions+source_origin,horizon_footprint);
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
            if (tactical_landscape) {
                // Sky colour only: never reflect hidden actors or sample scene
                // depth. Original opaque water coverage remains authoritative.
                vec3 water_colour;
                if(tactical_daylight_observed() && tactical_realism_ready && detail_levels>1.0) {
                    finish_sample=realism_sample(realism_uv,realism_dx,realism_dy,family,length(realism_local));
                    finish_sampled=true;
                    water_colour=tactical_textured_water(water,terrain_footprint,tactical_normal,tactical_to_eye,broad,fine,tactical_eye_pixel,length(original_view),finish_sample.x);
                } else water_colour=tactical_water(water,terrain_footprint,tactical_normal,tactical_to_eye,broad,fine,tactical_eye_pixel,length(original_view));
                ALBEDO=OUTPUT_IS_SRGB ? water_colour : pow(water_colour,vec3(2.2));
            }
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
    } else if (UV.y > 3.5 && UV.y < 4.5) {
        vec4 effect = texture(impact_burst,UV2);
        // Cutout keeps the complete mesh in its original opaque painter stream.
        // Discard low-alpha generation residue rather than exposing RGB fringes.
        if (effect.a < 0.5) discard;
        vec3 lookup = (effect.rgb*255.0+vec3(0.5))/256.0;
        ALBEDO = vec3(texture(effect_correction,vec2(lookup.r,0.5)).r,
                      texture(effect_correction,vec2(lookup.g,0.5)).r,
                      texture(effect_correction,vec2(lookup.b,0.5)).r);
        if (tactical_landscape && modern_active) {
            // Source-selected donor phase, frozen with the original packet.
            // Keep the established alpha cutout and painter ownership exact.
            vec2 local=(fract(UV2*vec2(5.0,4.0))*516.0-2.0)/512.0;
            float billow=ground_noise(local*11.0+UV.x*2.71);
            float fine=ground_noise(local*23.0+UV.x*7.3);
            float resolved_billow=mix(0.5,billow,effect_filter);
            vec3 authored=effect.rgb;
            float brightness=dot(authored,vec3(0.2126,0.7152,0.0722));
            float heat=UV.x>2.5 && UV.x<3.5 ? 0.0 : clamp((authored.r-authored.b)*2.6+smoothstep(0.70,0.96,brightness),0.0,1.0);
            vec2 q=(local-vec2(0.5))*2.0;
            vec3 smoke=tactical_plume_finish(q,resolved_billow,fine,1.0-brightness,effect_fine_filter,0.0)*(0.55+brightness*0.65);
            vec3 warmth=tactical_hot_finish(q,resolved_billow,fine,effect_fine_filter,0.0);
            // Source highlights stay authored, while coloured shoulders gain
            // the same bounded thermal palette as the supplementary puffs.
            vec3 fire=mix(authored*vec3(1.04,1.0,0.91),warmth,heat*0.24*(1.0-smoothstep(0.86,0.98,brightness)));
            vec3 result=mix(smoke,fire,heat);
            // Sparse hot fragments stay within the approved burst footprint.
            float spark=smoothstep(0.94,0.995,fine)*heat*effect_fine_filter;
            result=mix(result,vec3(1.0,0.86,0.45),spark*0.35);
            result=clamp(result,vec3(0.0),vec3(1.0));
            ALBEDO=OUTPUT_IS_SRGB ? result : pow(result,vec3(2.2));
        }
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
            if (road) detail=(tactical_landscape && modern_active && modern_surface_variation ? textureGrad(road_detail,ground/256.0,terrain_dx/256.0,terrain_dy/256.0).r : texture(road_detail,ground/256.0).r)-0.4546305661;
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
            if (modern_active && !road) {
                detail=modern_surface_variation ? ground_grain(grain_position) : 0.0;
                if (tactical_landscape && modern_surface_variation) {
                    // The Range's prefiltered field atlas is confined to
                    // Tactical, leaving Modern's original grain untouched.
                    float field=textureGrad(field_detail,grain_position/512.0,terrain_dx/512.0,terrain_dy/512.0).r-0.4323640162;
                    detail=field*0.40+detail*0.60;
                }
            }
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
            if (tactical_landscape && (grass || road)) {
                // The Range's three scales of field colour and grazing relief
                // are painted only on original terrain faces. A filtered
                // height-gradient gives dimensional light without displacement,
                // added blades or actors hidden behind decorative scenery.
                vec3 local=camera_to_local*original_view;
                bool usable=true;
                if (UV.y > 2.5 && UV.y < 3.5) {
                    usable=world_origin.z>0.0 && local.z < -0.0001;
                    if (usable) local *= -world_origin.z/local.z;
                }
                if (usable) {
                    vec2 ground=world_origin.xy+vec2(local.x,-local.y);
                    if (modern_surface_variation && grass && UV.y>6.5) {
                        vec3 position=world_origin+vec3(local.x,-local.y,local.z);
                        if (UV.y>8.5) ground=position.xz;
                        else if (UV.y>7.5) ground=position.yz;
                    }
                    float broad_lod=tactical_ground_broad_lod(terrain_footprint,2048.0,vec2(textureSize(field_detail,0)));
                    float broad=textureLod(field_detail,ground/2048.0,broad_lod).r;
                    float middle=road ? textureGrad(road_detail,ground/384.0,terrain_dx/384.0,terrain_dy/384.0).r : textureGrad(field_detail,ground/384.0,terrain_dx/384.0,terrain_dy/384.0).r;
                    float fine=road ? textureGrad(road_detail,ground/96.0,terrain_dx/96.0,terrain_dy/96.0).r : textureGrad(field_detail,ground/96.0,terrain_dx/96.0,terrain_dy/96.0).r;
                    float fine_fade=tactical_ground_detail(terrain_footprint,96.0);
                    float colour_fade=tactical_ground_colour_fade(terrain_dx,terrain_dy,96.0);
                    // Hand fine colour to the already-filtered middle scale,
                    // rather than flattening that contribution to a constant.
                    float patch=clamp(broad*0.55+middle*0.30+mix(middle,fine,colour_fade)*0.15,0.0,1.0);
                    float slope_x=(road ? textureGrad(road_detail,(ground+vec2(24.0,0.0))/96.0,terrain_dx/96.0,terrain_dy/96.0).r : textureGrad(field_detail,(ground+vec2(24.0,0.0))/96.0,terrain_dx/96.0,terrain_dy/96.0).r)-fine;
                    float slope_y=(road ? textureGrad(road_detail,(ground+vec2(0.0,24.0))/96.0,terrain_dx/96.0,terrain_dy/96.0).r : textureGrad(field_detail,(ground+vec2(0.0,24.0))/96.0,terrain_dx/96.0,terrain_dy/96.0).r)-fine;
                    // Background ground has ray-projected depth; original faces
                    // keep their measured normals. Relief lies in each face's
                    // source UV tangent plane and converges to flat at distance.
                    vec3 face=UV.y>2.5 && UV.y<3.5 ? vec3(0.0,0.0,1.0) : tactical_normal;
                    vec3 normal=tactical_slope_normal(face,vec2(slope_x,slope_y)*fine_fade,UV.y);
                    float sun=0.70+0.36*max(dot(normal,normalize(vec3(-0.58,0.34,0.74))),0.0);
                    float range=length(local.xy)/6000.0;
                    float distance_fade=1.0/(1.0+range*range);
                    vec3 base=grass ? mix(vec3(0.24,0.30,0.16),vec3(0.39,0.45,0.27),patch)
                                    : mix(vec3(0.29,0.27,0.24),vec3(0.40,0.37,0.33),patch);
                    if (road && modern_surface_variation) {
                        base=mix(vec3(0.29,0.29,0.27),vec3(0.40,0.39,0.35),patch);
                        base=tactical_road(base,ground,terrain_footprint,middle);
                    }
                    base*=mix(1.0,sun,distance_fade);
                    if(modern_environment_polish && modern_surface_variation && tactical_daylight_observed())base*=tactical_environment_tint(normal,0.55);
                    if (grass && modern_surface_variation && UV.y>6.5) {
                        // Broad pasture variation is tied to this source face.
                        // It changes grass colour only, never land classification.
                        float pasture=ground_noise(ground/640.0)*0.65+ground_noise(ground/1700.0)*0.35;
                        vec3 tint=mix(vec3(0.92,1.01,0.91),vec3(1.10,1.035,0.90),pasture);
                        base*=mix(vec3(1.0),tint,distance_fade*0.75+0.25);
                    }
                    if (grass) {
                        vec3 meadow=tactical_meadow(base,ground,terrain_footprint,mix(1.0,sun,distance_fade));
                        float upright=UV.y>6.5 && modern_surface_variation ? smoothstep(0.15,0.65,face.z) : 1.0;
                        base=mix(base,meadow,upright);
                    }
                    vec3 distant=road && modern_surface_variation ? vec3(0.46,0.46,0.42) : vec3(0.42,0.46,0.33);
                    base=mix(base,distant,(1.0-distance_fade)*0.35);
                    ALBEDO=OUTPUT_IS_SRGB ? base : pow(base,vec3(2.2));
                }
            }
            if (tactical_landscape && modern_surface_variation && !grass && UV.y>6.5 && UV.y<9.5) {
                vec3 local=camera_to_local*original_view;
                vec3 position=world_origin+vec3(local.x,-local.y,local.z);
                vec2 surface=position.xy;
                if (UV.y>8.5) surface=position.xz;
                else if (UV.y>7.5) surface=position.yz;
                ALBEDO=tactical_soil(ALBEDO,surface,terrain_dx,terrain_dy,tactical_normal,tactical_to_eye,UV.y,length(local.xy));
            }
        }
    } else ALBEDO = texture(material_patterns, lookup).rgb;
    }
    if(tactical_landscape && modern_active && modern_surface_variation && tactical_realism_ready && family>0.5 && realism_usable && detail_levels>1.0) {
        float gain=finish_sampled ? finish_sample.x : realism_gain(realism_uv,realism_dx,realism_dy,family,length(realism_local));
        ALBEDO*=OUTPUT_IS_SRGB ? vec3(gain) : vec3(pow(gain,2.2));
    }
    if(tactical_landscape && modern_active && modern_environment_polish && modern_surface_variation && detail_levels>1.0 &&
            tactical_daylight_observed() && UV.y>19.5 && UV.y<20.51 && !(UV.y>20.04 && UV.y<20.08) && family>0.5 && family<7.5) {
        float strength=family<1.5 ? 0.65 : family<3.5 ? 0.60 : family<4.5 ? 0.65 : family<6.5 ? 0.40 : 0.75;
        vec3 tint=tactical_environment_tint(finish_normal,strength);
        ALBEDO*=OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2));
    }
    if(tactical_landscape && modern_active && modern_environment_polish && modern_surface_variation && tactical_daylight_observed() && world_origin.z>0.0) {
        bool terrain=(UV.y>0.5 && UV.y<3.5) || (UV.y>6.5 && UV.y<9.5) || (UV.y>13.5 && UV.y<14.5);
        bool model=UV.y>19.5 && UV.y<21.5 && !(UV.y>20.04 && UV.y<20.08);
        if(terrain || model) {
            vec3 relative=camera_to_local*original_view;
            bool usable=true;
            if(UV.y>2.5 && UV.y<3.5) {
                usable=relative.z< -0.0001;
                if(usable)relative*= -world_origin.z/relative.z;
            }
            relative=vec3(relative.x,-relative.y,relative.z);
            if(usable)ALBEDO=tactical_air_colour(ALBEDO,relative,world_origin.z,terrain ? 0.16 : 0.10);
        }
    }
}
