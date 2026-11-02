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

// Kill debris: nine seeded fragments thrown up from the wreck in the quad's
// screen-facing frame, falling to a local ground line and resting there until
// they fade. Age comes only from the explicit dynamics clock.
const float DEBRIS_LIFE=1.1;
vec4 kill_debris(vec2 q, float age, float seed, vec2 down, float pixel, float base) {
    vec2 right=vec2(down.y,-down.x);
    vec3 premultiplied=vec3(0.0);
    float coverage=0.0;
    for (int k=0;k<9;k++) {
        float n=float(k);
        float a=hash(vec2(seed*17.0+n,3.1));
        float b=hash(vec2(seed*29.0+n,7.7));
        float c=hash(vec2(seed*41.0+n,11.3));
        float d=hash(vec2(seed*53.0+n,19.9));
        // Apex lift^2/12 = 0.33..0.80 quad units above the wreck centre.
        float lift=2.0+b*1.1;
        float ground=base+d*0.04;
        // Gravity 6 quad units/s^2: landing solves -lift*t+3*t^2=ground.
        float landing=(lift+sqrt(lift*lift+12.0*ground))/6.0;
        float t=min(age,landing);
        vec2 at=right*((c-0.5)*0.24+(a-0.5)*1.1*t)+down*(-lift*t+3.0*t*t);
        float angle=a*6.2832+(b-0.5)*16.0*t;
        vec2 local=mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)))*(q-at);
        vec2 outside=abs(local)-vec2(0.030+0.040*c,0.018+0.026*d);
        float edge=length(max(outside,0.0))+min(max(outside.x,outside.y),0.0);
        float hit=1.0-smoothstep(-0.5*pixel,0.5*pixel,edge);
        // A third of the fragments leave hot and cool to charcoal.
        float ember=step(0.62,b)*(1.0-smoothstep(0.04,0.35,age));
        vec3 tone=mix(vec3(0.085,0.080,0.072),vec3(0.24,0.21,0.17),d);
        // One lit face turns with the fragment, so the tumble reads.
        float facing=dot(vec2(-sin(angle),cos(angle)),-down);
        tone*=1.0+0.55*smoothstep(0.0,0.6,facing)*step(0.0,-local.y);
        tone=mix(tone,vec3(1.0,0.56,0.20),ember);
        premultiplied=tone*hit+premultiplied*(1.0-hit);
        coverage=hit+coverage*(1.0-hit);
    }
    float fade=1.0-smoothstep(DEBRIS_LIFE-0.4,DEBRIS_LIFE,age);
    return vec4(premultiplied/max(coverage,0.0001),coverage*fade);
}

// Wreck fire: patchy flames licking up the wreck, hot at the kill and
// cooling to smoke by about 0.9 s. The caller admits it only on the wreck's
// own pixels, so it burns on the tank and nowhere else.
vec4 wreck_fire(vec2 q, float age, float seed, vec2 down, float base) {
    vec2 right=vec2(down.y,-down.x);
    float x=dot(q,right);
    float rise=base-dot(q,down); // 0 at the wreck's base, positive upward
    if (rise<-0.05) return vec4(0.0);
    float flicker=noise(vec2(x*22.0+seed*13.0,rise*14.0-age*16.0));
    float tongue=noise(vec2(x*8.0-seed*7.0,rise*5.0-age*6.0));
    float density=smoothstep(0.18,0.62,tongue*0.6+flicker*0.55-rise*0.9);
    float heat=density*(1.0-smoothstep(0.25,0.75,age))*(0.75+0.6*flicker);
    vec3 flame=mix(vec3(0.70,0.10,0.03),vec3(1.0,0.52,0.10),smoothstep(0.15,0.55,heat));
    flame=mix(flame,vec3(1.0,0.93,0.62),smoothstep(0.65,0.95,heat));
    vec3 smoke=mix(vec3(0.16,0.15,0.14),vec3(0.30,0.29,0.27),flicker);
    vec3 colour=mix(smoke,flame,smoothstep(0.05,0.30,heat));
    float alpha=density*(1.0-smoothstep(0.6,0.95,age));
    return vec4(colour,alpha);
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
    float pixel=max(length(dFdx(q)),length(dFdy(q)));
    bool debris=emitter.y>3.5;
    float id=owner_at(SCREEN_UV);
    float root=owner_at(anchor.xy);
    // Emitter-owned puffs (vehicle fumes, flare glow, effect ash) require a
    // visible root and shade strictly that object's final painter coverage, so
    // nearer terrain, trees and actors that covered it cover the puff too.
    // Smoke deployments use only the observed terrain/background, never actors.
    if (id<0.0 || root<0.0 || id>=owner_count) discard;
    if (!debris && emitter.x>0.0 && root!=emitter.x) discard;
    vec4 owner_class=texture(allowed_terrain,vec2((id+0.5)/owner_count,0.5));
    if (debris) {
        // Kill debris covers the wreck's own pixels and original impact
        // sprites. The open form (anchor -4) adds terrain and background the
        // original painted before the wreck. Actors, trees and nearer terrain
        // always stay in front. Nothing draws without the explicit clock.
        bool open=anchor.w<-3.5 && id<emitter.x && owner_class.r>0.5;
        if (id!=emitter.x && owner_class.g<0.5 && !open) discard;
        if (dynamics_time<0.0 || emitter.w<=0.0 || dynamics_time-(emitter.w-1.0)>DEBRIS_LIFE) discard;
        // The burst needs a visible source: some pixel of the wreck's drawn
        // rectangle (half-extent 0.357 quad units) painted by the wreck or an
        // impact sprite. A small wreck's centre may be a gap or covered, so
        // probe a grid. A wreck wholly hidden by a crest throws nothing.
        // Centre outward (0,-1,+1,-2,...), stopping at the first hit, so a
        // visible wreck usually costs one or two samples per fragment.
        vec2 uv_per_q=1.0/max(pixel*VIEWPORT_SIZE,vec2(0.0001));
        bool seen=false;
        for (int i=0;i<35 && !seen;i++) {
            int ix=i%7;int iy=i/7;
            float px=float((ix+1)/2)*(ix%2==1 ? -1.0 : 1.0);
            float py=float((iy+1)/2)*(iy%2==1 ? -1.0 : 1.0);
            float probe=owner_at(anchor.xy+vec2(px*0.11,py*0.07)*uv_per_q);
            if (probe<0.0 || probe>=owner_count) continue;
            seen=probe==emitter.x || texture(allowed_terrain,vec2((probe+0.5)/owner_count,0.5)).g>0.5;
        }
        if (!seen) discard;
    }
    else if (confined>0.5) { if (id!=emitter.x) discard; }
    else if (id!=emitter.x && owner_class.r<0.5) discard;
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
    if(anchor.w == -2.0) {
        // Source-qualified missile puffs are incandescent. Grey smoke here
        // obscured the authored hot centre with a soft, dark "eye".
        // RGB only: retain density, alpha, discard and both incumbent clocks.
        float heat=smoothstep(0.02,0.75,density+(billow-coarse)*0.06*filtered);
        colour=mix(vec3(1.0,0.68,0.22),vec3(1.0,0.97,0.85),heat);
        // Keep the same moving colour fields; only the palette is replaced.
        colour*=0.96+0.04*(billow*0.65+grain*0.35)*filtered;
    }
    if(anchor.w>=0.0 && anchor.w<=1.0)colour=tactical_impact_phase(colour,q,anchor.w);
    if(dynamics_time>=0.0 && emitter.w>0.0 && !debris) {
        // Short ballistic sparks, colour-only inside the incumbent alpha/mask.
        float age=max(dynamics_time-(emitter.w-1.0),0.0);
        float energy=1.0-smoothstep(0.16,0.55,age);
        float angle=emitter.z*7.91;
        vec2 flight=vec2(cos(angle)*0.95,-0.95-abs(sin(angle))*0.5)*age;
        flight.y+=2.6*age*age;
        float spark=1.0-smoothstep(0.025,0.09,length(q-flight));
        colour=mix(colour,vec3(1.0,0.73,0.28),spark*energy*0.8);
    }
    float alpha=density*anchor.z;
    if (debris) {
        float age=max(dynamics_time-(emitter.w-1.0),0.0);
        vec4 chunk=kill_debris(q,age,emitter.z,-plume_frame.xy,pixel,confined-2.0);
        // Fire only on the wreck's own pixels: the impact sprite keeps its
        // authored fireball, and the fire never spreads onto open ground.
        vec4 fire=id==emitter.x ? wreck_fire(q,age,emitter.z,-plume_frame.xy,confined-2.0) : vec4(0.0);
        float over=chunk.a+fire.a*(1.0-chunk.a);
        colour=(chunk.rgb*chunk.a+fire.rgb*fire.a*(1.0-chunk.a))/max(over,0.0001);
        alpha=over*anchor.z;
    }
    ALBEDO=OUTPUT_IS_SRGB ? colour : pow(colour,vec3(2.2));
    ALPHA=alpha;
}
