shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled, blend_mul;
#include "res://scripts/pc_tactical_light.gdshaderinc"
// Tactical screen-space light. One full-screen multiplicative quad drawn after
// opaque source surfaces and decorative foliage, before smoke and particles.
// Only source terrain pixels (and the original ground background) receive it.
// Only visible depth can occlude the sun: the source-depth target holds the
// painter-visible original surface at each pixel, so an actor the original
// hid contributes nothing. Visible actors cast (Nell, 2 November 2026) but
// are never darkened themselves.
uniform sampler2D source_depth : filter_nearest, repeat_disable;
uniform vec2 source_origin;
uniform vec2 source_dimensions = vec2(1.0);
uniform vec2 source_center;
uniform float source_focal_pixels = 192.0;
uniform mat3 camera_to_local;
uniform float eye_height = 0.0;
// Source-world camera position (raw units): anchors the static cloud field.
uniform vec3 world_origin = vec3(0.0);
// 1 in production; 0 leaves every pixel untouched (diagnostic A/B).
uniform float light_strength = 1.0;

const int LIGHT_STEPS=32;
const float LIGHT_REACH=2400.0;
const int LIGHT_AO_SAMPLES=8;
const float LIGHT_AO_RADIUS=96.0;
// Full sun loss: cooler and darker, as open-sky fill replaces direct sun.
const vec3 LIGHT_SHADE=vec3(0.70,0.75,0.86);
const float LIGHT_AO=0.34;
// Large-scale sky visibility on sloped terrain: steep faces lose open sky
// toward their foot, so hills settle into the ground; flat ground is exact.
const float LIGHT_RELIEF=0.30;
const float LIGHT_RELIEF_HEIGHT=900.0;
// Static cloud shadow (Nell, 2 November 2026): a world-anchored field at a
// fixed cloud height, projected down the sun. No clock, so it never drifts.
const float CLOUD_HEIGHT=9000.0;
const float CLOUD_SCALE=5200.0;
const float CLOUD_STRENGTH=0.78;

varying flat vec3 sun_camera;
varying flat vec3 up_camera;

void vertex() {
    POSITION=vec4(VERTEX.xy,0.0,1.0);
    // Source camera frame: x right, y forward, z up (raw source units).
    mat3 to_camera=inverse(camera_to_local);
    vec3 sun=normalize(TACTICAL_LIGHT_SUN);
    sun_camera=normalize(to_camera*vec3(sun.x,-sun.y,sun.z));
    up_camera=normalize(to_camera*vec3(0.0,0.0,1.0));
}

vec3 light_ray(vec2 uv) {
    vec2 s=source_origin+uv*source_dimensions;
    return vec3((s.x-source_center.x)/source_focal_pixels,1.0,(source_center.y-s.y)/source_focal_pixels);
}

vec2 light_project(vec3 p) {
    vec2 s=source_center+vec2(p.x,-p.z)*source_focal_pixels/p.y;
    return (s-source_origin)/source_dimensions;
}

// x: forward depth (raw units). y: 0 nothing usable (sky, sprite, round
// command), 1 static scenery, 2 source terrain, 3 actor, 4 original ground
// background (z=0). Receivers are 2 and 4; casters are 1, 2 and 3.
vec2 light_surface(vec2 uv) {
    vec4 encoded=texture(source_depth,uv);
    if (encoded.a<0.5) {
        float down=-(camera_to_local*light_ray(uv)).z;
        return down>0.00001 && eye_height>0.0 ? vec2(eye_height/down,4.0) : vec2(0.0);
    }
    return light_depth_decode(round(encoded.rgb*255.0));
}

bool light_receiver(float kind) { return abs(kind-2.0)<0.5 || abs(kind-4.0)<0.5; }
bool light_caster(float kind) { return kind>0.5 && kind<3.5; }

float cloud_hash(vec2 cell) {
    vec3 p=fract(vec3(cell.xyx)*vec3(0.1031,0.1030,0.0973));
    p+=dot(p,p.yzx+33.33);
    return fract((p.x+p.y)*p.z);
}
float cloud_noise(vec2 p) {
    vec2 i=floor(p);
    vec2 f=fract(p);
    f=f*f*(3.0-2.0*f);
    return mix(mix(cloud_hash(i),cloud_hash(i+vec2(1.0,0.0)),f.x),
               mix(cloud_hash(i+vec2(0.0,1.0)),cloud_hash(i+vec2(1.0,1.0)),f.x),f.y);
}
// Fraction of sun a cloud removes at a source-world ground point.
float cloud_cover(vec3 world, vec3 sun, float distance) {
    if (sun.z<0.05) return 0.0;
    vec2 at=(world.xy+sun.xy*(CLOUD_HEIGHT-world.z)/sun.z)/CLOUD_SCALE;
    float field=cloud_noise(at)*0.58+cloud_noise(at*2.03+vec2(17.1,3.7))*0.29+cloud_noise(at*4.11+vec2(-5.3,11.9))*0.13;
    // Edges widen with distance so far patches stay soft rather than shimmer.
    float edge=0.06+distance/120000.0;
    return smoothstep(0.55-edge,0.55+edge,field);
}

// Neighbour difference along one screen axis, preferring the side on the same
// surface (smaller depth step) so polygon edges do not bend the normal.
vec3 light_tangent(vec2 uv, vec2 step, vec3 point, float depth) {
    vec2 a=light_surface(uv-step);
    vec2 b=light_surface(uv+step);
    bool a_ok=light_receiver(a.y);
    bool b_ok=light_receiver(b.y);
    bool use_a=a_ok && (!b_ok || abs(a.x-depth)<abs(b.x-depth));
    if (use_a) return point-light_ray(uv-step)*a.x;
    if (b_ok) return light_ray(uv+step)*b.x-point;
    return vec3(0.0);
}

void fragment() {
    vec2 uv=SCREEN_UV;
    vec2 here=light_surface(uv);
    if (light_strength<=0.0 || !light_receiver(here.y)) discard;
    vec3 point=light_ray(uv)*here.x;
    float distance=length(point);
    float far_fade=1.0-smoothstep(9000.0,24000.0,distance);
    float cloud_fade=1.0-smoothstep(40000.0,110000.0,distance);
    vec3 sun_world=normalize(TACTICAL_LIGHT_SUN);
    vec3 local=camera_to_local*point;
    float cloud=cloud_fade>0.0 ? cloud_cover(world_origin+vec3(local.x,-local.y,local.z),sun_world,distance)*cloud_fade : 0.0;
    if (far_fade<=0.0 && cloud<=0.0) discard;
    vec2 texel=1.0/vec2(textureSize(source_depth,0));

    vec3 normal=up_camera;
    if (abs(here.y-2.0)<0.5 && far_fade>0.0) {
        vec3 across=light_tangent(uv,vec2(texel.x,0.0),point,here.x);
        vec3 down=light_tangent(uv,vec2(0.0,texel.y),point,here.x);
        vec3 face=cross(across,down);
        if (dot(face,face)>0.00000001) normal=normalize(face);
        if (dot(normal,point)>0.0) normal=-normal;
    }
    // Faces turned from the sun lose it entirely (attached shadow).
    float attached=1.0-smoothstep(-0.08,0.28,dot(normal,sun_camera));
    float noise=light_noise(FRAGCOORD.xy);

    // Cast shadow: march toward the sun over visible static depth. A single
    // sample never shadows fully, and hits fade toward the end of the reach.
    float shadow=0.0;
    if (attached<0.999 && far_fade>0.0) {
        for (int i=0;i<LIGHT_STEPS;i++) {
            float f=(float(i)+noise)/float(LIGHT_STEPS);
            float t=4.0+LIGHT_REACH*f*f;
            vec3 q=point+sun_camera*t;
            if (q.y<16.0) break;
            vec2 at=light_project(q);
            if (any(lessThan(at,vec2(0.0))) || any(greaterThan(at,vec2(1.0)))) break;
            vec2 hit=light_surface(at);
            if (!light_caster(hit.y)) continue;
            float delta=q.y-hit.x;
            float bias=4.0+q.y*0.002;
            // Terrain masses are solid; trees, buildings and vehicles thinner.
            float thickness=abs(hit.y-2.0)<0.5 ? 900.0+t : 140.0+0.5*t;
            float occluded=smoothstep(bias,bias*3.0,delta)*(1.0-smoothstep(thickness*0.75,thickness,delta));
            occluded*=1.0-smoothstep(0.55,1.0,f);
            shadow=1.0-(1.0-shadow)*(1.0-0.38*occluded);
        }
    }

    // Contact occlusion (McGuire et al. 2011 estimator) from visible scenery
    // and actors; the ground plane itself adds nothing.
    float occlusion=0.0;
    float focal_view=source_focal_pixels*float(textureSize(source_depth,0).x)/source_dimensions.x;
    float radius_px=LIGHT_AO_RADIUS*focal_view/max(point.y,1.0);
    if (radius_px>1.5 && far_fade>0.0) {
        float sum=0.0;
        float reach_px=min(radius_px,64.0);
        for (int k=0;k<LIGHT_AO_SAMPLES;k++) {
            float angle=(float(k)+noise)*2.39996323;
            float reach=sqrt((float(k)+0.5)/float(LIGHT_AO_SAMPLES))*reach_px;
            vec2 at=uv+vec2(cos(angle),sin(angle))*reach*texel;
            vec2 other=light_surface(at);
            if (!light_caster(other.y)) continue;
            vec3 v=light_ray(at)*other.x-point;
            float vv=dot(v,v);
            if (vv>LIGHT_AO_RADIUS*LIGHT_AO_RADIUS*4.0) continue;
            sum+=max(dot(v,normal)-point.y*0.003,0.0)/(vv+LIGHT_AO_RADIUS*LIGHT_AO_RADIUS*0.01);
        }
        occlusion=clamp(sum*LIGHT_AO_RADIUS*1.2/float(LIGHT_AO_SAMPLES),0.0,1.0)*smoothstep(1.5,4.0,radius_px);
    }

    float slope=1.0-clamp(dot(normal,up_camera),0.0,1.0);
    float height=max(eye_height+dot(point,up_camera),0.0);
    float relief=smoothstep(0.02,0.25,slope)*(1.0-smoothstep(0.0,LIGHT_RELIEF_HEIGHT,height));

    // Local sun loss fades with range; a cloud removes sun independently, and
    // never darkens ground that is already in shadow a second time.
    float sun_lost=1.0-(1.0-attached)*(1.0-shadow);
    sun_lost=1.0-(1.0-sun_lost*far_fade)*(1.0-CLOUD_STRENGTH*cloud);
    vec3 shade=mix(vec3(1.0),LIGHT_SHADE,sun_lost);
    shade*=mix(vec3(1.0),(1.0-LIGHT_AO*occlusion)*(1.0-LIGHT_RELIEF*relief*vec3(1.0,0.97,0.9)),far_fade);
    shade=mix(vec3(1.0),max(shade,vec3(0.5)),clamp(light_strength,0.0,1.0));
    if (all(greaterThanEqual(shade,vec3(0.9995)))) discard;
    ALBEDO=light_output(shade);
}
