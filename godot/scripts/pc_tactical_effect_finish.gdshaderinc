// Colour-only finishes shared by source sprites and snapshot-derived puffs.
// All inputs come from existing coverage, source phase and two noise fields.
// No opacity, geometry, clock, texture lookup or simulated light lives here.
vec3 tactical_plume_finish(vec2 q, float coarse, float detail, float density, float filtered, float kind) {
    float dome=sqrt(max(1.0-clamp(dot(q,q),0.0,1.0),0.0));
    float crown=clamp(0.5-q.y*0.35-q.x*0.18,0.0,1.0);
    float fold=(coarse-0.5)*(0.12+0.08*dome);
    float grain=(detail-0.5)*0.055*filtered;
    float light=clamp(0.18+dome*0.33+crown*0.28+fold+grain,0.0,1.0);
    float core=clamp(density,0.0,1.0);
    float rim=(1.0-core)*(1.0-core)*smoothstep(0.3,0.85,crown);
    vec3 colour=mix(vec3(0.31,0.345,0.35),vec3(0.73,0.745,0.715),light);
    colour*=1.0-core*(0.08+0.10*(1.0-crown));
    colour=mix(colour,vec3(0.79,0.785,0.745),rim*0.23);
    if(kind>0.5 && kind<1.5) {
        // Dense diesel bodies, neutral dispersing wisps and subdued brown soot.
        colour=mix(vec3(0.105,0.11,0.105),vec3(0.43,0.435,0.415),light);
        colour*=1.0-core*(0.13+0.12*(1.0-crown));
        colour+=vec3(0.024,0.014,0.004)*(coarse-0.5)*core;
        colour=mix(colour,vec3(0.49,0.49,0.47),rim*0.18);
    } else if(kind>3.5) {
        // Loamy low folds, sandy lifted crowns and thin warm scattering edges.
        colour=mix(vec3(0.315,0.275,0.215),vec3(0.70,0.635,0.50),light);
        colour*=1.0-core*(0.065+0.09*(1.0-crown));
        colour+=vec3(0.027,0.019,0.008)*(coarse-0.5)*core;
        colour=mix(colour,vec3(0.76,0.685,0.54),rim*0.20);
    }
    return clamp(colour,vec3(0.045),vec3(0.88));
}

vec3 tactical_hot_finish(vec2 q, float coarse, float detail, float filtered, float motor) {
    float radius=clamp(length(q),0.0,1.0);
    float warmth=clamp(1.0-radius+(coarse-0.5)*0.16*(1.0-radius),0.0,1.0);
    float heat=pow(warmth,mix(1.45,2.15,clamp(motor,0.0,1.0)));
    vec3 colour=mix(vec3(0.37,0.075,0.025),vec3(0.94,0.30,0.045),smoothstep(0.0,0.42,heat));
    colour=mix(colour,vec3(0.99,0.66,0.18),smoothstep(0.25,0.72,heat));
    colour=mix(colour,vec3(1.0,0.93,0.72),smoothstep(0.65,0.98,heat));
    float pockets=smoothstep(0.65,0.92,detail)*smoothstep(0.42,0.85,heat)*filtered;
    colour=mix(colour,vec3(1.0,0.88,0.52),pockets*0.12);
    colour*=0.94+coarse*0.06+(detail-0.5)*0.035*filtered*heat;
    return clamp(colour,vec3(0.0),vec3(1.0));
}
