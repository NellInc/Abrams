// Move authored armour material within its existing source-owned destination.
// Apertures, silhouettes, instruments and all original pixels remain fixed.
vec2 tactical_armour_sample(vec2 p,float station,sampler2D ui,sampler2D plates,sampler2D assembly,bool driver,vec2 displacement) {
    if(all(equal(displacement,vec2(0.0))))return p;
    vec2 q=p+clamp(displacement,vec2(-0.30,-1.25),vec2(0.30,1.25));
    if(any(lessThan(q,vec2(0.0))) || any(greaterThanEqual(q,vec2(320.0,187.0))))return p;
    vec2 a=(floor(p)+0.5)/vec2(320.0,200.0);
    vec2 b=(floor(q)+0.5)/vec2(320.0,200.0);
    if(texture(ui,a).r<0.5 || texture(ui,b).r<0.5)return p;
    float pa=round(texture(plates,a).r*255.0);
    float pb=round(texture(plates,b).r*255.0);
    if(pa!=station || pb!=station)return p;
    if(driver) {
        vec3 ca=round(texture(assembly,a).rgb*255.0);
        vec3 cb=round(texture(assembly,b).rgb*255.0);
        // Source turret offsets and the assembly/static-deck boundary stay put.
        if(any(notEqual(ca,cb)))return p;
    }
    return q;
}
