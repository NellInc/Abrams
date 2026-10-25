shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
uniform sampler2D source_ownership : filter_nearest, repeat_disable;
uniform sampler2D allowed_terrain : filter_nearest, repeat_disable;
uniform sampler2D roots : filter_nearest, repeat_disable;
uniform float owner_count;
uniform float root_width;
uniform float dynamics_time=-1.0;
uniform float plume_phase=0.0;
uniform vec3 plume_sun=vec3(-0.58,-0.74,0.34);
uniform vec3 plume_world_up=vec3(0.0,0.0,1.0);
uniform vec4 plume_projection=vec4(1.0,1.0,-0.5,0.5);
varying vec4 emitter;
varying vec4 anchor;
varying float confined;
varying vec3 plume_frame;
#include "res://scripts/pc_tactical_effect_finish.gdshaderinc"
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
    vec2 c=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);
    return mix(mix(hash(c),hash(c+vec2(1.0,0.0)),f.x),mix(hash(c+vec2(0.0,1.0)),hash(c+vec2(1.0)),f.x),f.y);
}
// The animated colour field's existing four corner hashes also supply its
// analytic slope. No extra noise samples or post-discard screen derivatives.
vec3 noise_slope(vec2 p) {
    vec2 cell=floor(p);vec2 f=fract(p);
    vec2 df=6.0*f*(1.0-f);f=f*f*(3.0-2.0*f);
    float a=hash(cell);float b=hash(cell+vec2(1.0,0.0));
    float c=hash(cell+vec2(0.0,1.0));float d=hash(cell+vec2(1.0));
    return vec3(mix(mix(a,b,f.x),mix(c,d,f.x),f.y),
                mix(b-a,d-c,f.y)*df.x,mix(c-a,d-b,f.x)*df.y);
}
vec3 plume_billow(vec2 p,float phase,float seed) {
    vec2 angles=phase+p.yx*vec2(1.8,1.5);
    vec2 flow=vec2(sin(angles.x),cos(angles.y))*0.22;
    vec3 field=noise_slope(p*3.0+seed*7.0+flow);
    // Warp Jacobian: derivatives remain in the plume's right/down frame.
    return vec3(field.x,3.0*field.y-0.33*sin(angles.y)*field.z,
                        3.0*field.z+0.396*cos(angles.x)*field.y);
}
float owner_at(vec2 uv) {
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0)))) return -1.0;
    vec2 id=round(texture(source_ownership,uv).rg*255.0);
    return id.x+256.0*id.y;
}
vec3 plume_frame_at(vec2 root) {
    // Perspective-project world-up at the observed root, including off-centre
    // emitters in a pitched sight. The whole puff shares this tangent frame.
    vec2 ray=vec2(root.x*plume_projection.x+plume_projection.z,
                  plume_projection.w-root.y*plume_projection.y);
    vec2 up=vec2(plume_world_up.x-ray.x*plume_world_up.y,
                 -plume_world_up.z+ray.y*plume_world_up.y);
    float magnitude=length(up);
    if(magnitude<0.00001)return vec3(0.0,-1.0,0.0);
    return vec3(up/magnitude,smoothstep(0.02,0.20,magnitude));
}
// Tactical puff colour only. The shared source-sprite finish stays byte-exact.
// Reuse the incumbent density and footprint, preserving every mask and alpha.
vec3 tactical_particle_volume(vec3 colour, vec2 q, float density, float kind, vec2 fold_light) {
    float dome=sqrt(max(1.0-clamp(dot(q,q),0.0,1.0),0.0));
    float crown=clamp(0.5-q.y*0.35-q.x*0.18,0.0,1.0);
    float lower=smoothstep(0.05,0.75,q.y)*(0.35+0.65*dome);
    float shoulder=dome*(1.0-dome)*4.0*crown;
    float core=clamp(density,0.0,1.0);
    // Broad upper shoulders and lower folds survive tiny projected footprints.
    // Fine structure already fades through the incumbent filtered noise field.
    colour*=1.0-lower*core*0.075+shoulder*0.04;
    if(kind>1.5 && kind<3.5) {
        // Subdued amber motor shoulders, with the existing hot core retained.
        colour*=mix(vec3(1.0),vec3(1.0,0.965,0.92),dome*0.45);
    } else {
        // Cool dense folds and neutral/warm lifted rims stay within the
        // existing smoke or diesel palette. No opacity-derived new coverage.
        float cool=core*(1.0-crown)*0.65;
        colour*=mix(vec3(1.01,1.0,0.98),vec3(0.975,0.995,1.025),cool);
        // The visible hemisphere receives the same world-fixed sun as armour.
        // Lighting changes RGB only, including the thin, backlit shoulders.
        vec3 normal=normalize(vec3(q*0.75-fold_light,max(dome,0.12)));
        float direct=max(dot(normal,plume_sun),0.0);
        float back=max(-plume_sun.z,0.0);
        float rim=pow(1.0-dome,2.0)*(1.0-core)*back;
        vec3 fill=mix(vec3(0.91,0.955,1.025),vec3(1.075,1.045,0.965),direct);
        colour=colour*fill+vec3(0.065,0.055,0.035)*rim;
    }
    return clamp(colour,vec3(0.0),vec3(1.0));
}

void vertex() {
    emitter=texture(roots,vec2((UV2.x*2.0+0.5)/root_width,0.5));
    anchor=texture(roots,vec2((UV2.x*2.0+1.5)/root_width,0.5));
    confined=UV2.y;
    plume_frame=plume_frame_at(anchor.xy);
}
void fragment() {
    // Evaluate the quad footprint before source-ownership discard diverges.
    // Only colour grain is filtered; opacity and source coverage stay exact.
    vec2 q=UV;
    float filtered=1.0-smoothstep(0.12,0.65,max(length(dFdx(q*7.0)),length(dFdy(q*7.0))));
    float id=owner_at(SCREEN_UV);
    float root=owner_at(anchor.xy);
    // Emitter-owned puffs (vehicle fumes, flare glow, effect ash) require a
    // visible root and shade strictly that object's final painter coverage, so
    // nearer terrain, trees and actors that covered it cover the puff too.
    // Smoke deployments use only the observed terrain/background, never actors.
    if (id<0.0 || root<0.0 || id>=owner_count) discard;
    if (emitter.x>0.0 && root!=emitter.x) discard;
    if (confined>0.5) { if (id!=emitter.x) discard; }
    else if (id!=emitter.x && texture(allowed_terrain,vec2((id+0.5)/owner_count,0.5)).r<0.5) discard;
    if (emitter.x==0.0 && texture(allowed_terrain,vec2((root+0.5)/owner_count,0.5)).r<0.5) discard;
    float coarse=noise(q*3.0+emitter.z*7.0);
    float detail=noise(q*7.0+emitter.z*11.0);
    float edge=length(q)+coarse*0.18-0.09;
    float density=(1.0-smoothstep(0.30,0.98,edge))*(0.70+coarse*0.30);
    // Preserve the two incumbent noise fields above for exact opacity. A
    // periodic, rising colour flow rolls within that stationary footprint.
    // Derivative filtering removes unresolved interior detail while panning.
    float billow=coarse;
    float grain=detail;
    vec2 fold_light=vec2(0.0);
    if(emitter.y<1.5) {
        vec2 down=-plume_frame.xy;
        vec2 right=vec2(down.y,-down.x);
        vec2 flow_q=vec2(dot(q,right),dot(q,down));
        float phase=plume_phase+emitter.z*0.73;
        vec3 billow_field=plume_billow(flow_q,phase,emitter.z);
        float resolved=filtered*clamp(plume_frame.z,0.0,1.0);
        billow=mix(coarse,billow_field.x,resolved*0.85);
        grain=mix(detail,0.5+0.5*sin(flow_q.y*7.0+flow_q.x*2.5+phase*2.0),resolved*0.35);
        // Rotate the analytic slope into the dome's screen-facing tangent
        // plane. Bounded relief shades moving folds without moving coverage.
        fold_light=(right*billow_field.y+down*billow_field.z)*(0.055*resolved);
        fold_light*=min(1.0,0.22/max(length(fold_light),0.0001));
    }
    vec3 colour=tactical_plume_finish(q,billow,grain,density,filtered,emitter.y);
    if (emitter.y>1.5 && emitter.y<2.5) {
        colour=tactical_hot_finish(q,coarse,detail,filtered,0.0);
    }
    if (emitter.y>2.5 && emitter.y<3.5) {
        colour=tactical_hot_finish(q,coarse,detail,filtered,1.0);
    }
    colour=tactical_particle_volume(colour,q,density,emitter.y,fold_light);
    if(anchor.w>=0.0 && anchor.w<=1.0)colour=tactical_impact_phase(colour,q,anchor.w);
    if(dynamics_time>=0.0 && emitter.w>0.0) {
        // Short ballistic sparks, colour-only inside the incumbent alpha/mask.
        float age=max(dynamics_time-(emitter.w-1.0),0.0);
        float energy=1.0-smoothstep(0.16,0.55,age);
        float angle=emitter.z*7.91;
        vec2 flight=vec2(cos(angle)*0.95,-0.95-abs(sin(angle))*0.5)*age;
        flight.y+=2.6*age*age;
        float spark=1.0-smoothstep(0.025,0.09,length(q-flight));
        colour=mix(colour,vec3(1.0,0.73,0.28),spark*energy*0.8);
    }
    ALBEDO=OUTPUT_IS_SRGB ? colour : pow(colour,vec3(2.2));
    ALPHA=density*anchor.z;
}
