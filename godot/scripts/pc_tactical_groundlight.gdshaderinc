// Tactical terrain material/light only; no uniforms, textures or geometry.
// Natural loam and exposed mineral colour on verified brown hill recipes.
// Rebase the old discrete palette ramp to a continuous material; reuse the
// incumbent three hill samples and the already-filtered soil atlas gain.
// World-height strata colour never adds ledges, stones or collision geometry.
vec3 tactical_hill_earth(vec3 face,vec3 point,vec3 samples,vec2 filters,float gain,float mean) {
    filters=clamp(filters,vec2(0.0),vec2(1.0));
    float steep=1.0-smoothstep(0.25,0.82,abs(face.z));
    float patch=clamp(0.50+(samples.x-mean)*1.35+(samples.y-mean)*0.70*filters.x,0.0,1.0);
    vec3 earth=mix(vec3(0.30,0.248,0.177),vec3(0.50,0.416,0.296),patch);
    vec3 rock=mix(vec3(0.36,0.335,0.28),vec3(0.55,0.52,0.435),patch);
    // Filtered bright grains reveal muted stone, rather than bleaching soil.
    float mineral=smoothstep(0.015,0.12,max(gain-1.0,0.0));
    earth=mix(earth,rock,mineral*(0.16+0.58*steep));
    float strata=sin(point.z/52.0+sin(point.x/360.0+point.y/430.0)*1.2+(samples.x-mean)*2.0);
    earth*=1.0+strata*0.09*steep*filters.y;
    earth*=1.0+(samples.z-mean)*0.18*filters.x;
    return clamp(earth,vec3(0.08),vec3(0.72));
}

vec3 tactical_terrain_profile(float family) {
    if(family>7.5 && family<8.5)return vec3(1.20,0.16,0.0);
    if(family>9.5 && family<10.5)return vec3(1.65,0.22,0.0);
    if(family>10.5 && family<11.5)return vec3(0.65,0.09,0.018);
    return vec3(0.0);
}

// The atlas already supplies height neighbours for colour. Convert that same
// gradient through its terrain warp and the original face's tangent plane.
// Source UVs are world-plane projections, so their ambient height gradient
// projects directly onto that plane. No additional derivative or inversion.
vec3 tactical_terrain_slope(vec3 face,vec2 gradient,vec2 uv,float kind,float family) {
    float amplitude=tactical_terrain_profile(family).x;
    bool terrain=(kind>0.5 && kind<3.5) || (kind>6.5 && kind<9.5);
    if(!terrain || amplitude==0.0 || dot(gradient,gradient)<0.00000001)return vec3(0.0);
    vec2 u=vec2(1.0,0.0);vec2 v=vec2(0.0,1.0);
    realism_ground_coordinates(uv,u,v);
    gradient=vec2(dot(gradient,u),dot(gradient,v))/realism_period(family);
    vec3 slope=vec3(gradient,0.0);
    if(kind>8.5)slope=vec3(gradient.x,0.0,gradient.y);
    else if(kind>7.5)slope=vec3(0.0,gradient);
    slope-=face*dot(face,slope);
    return slope*amplitude;
}

// Combine broad and microscopic relief once, preserving the incumbent broad
// normal exactly when fine detail has filtered away. Existing broad slopes
// are never flattened merely because their atlas family has a smaller budget.
vec3 tactical_terrain_normal(vec3 face,vec3 broad,vec3 slope,float family) {
    if(dot(slope,slope)<0.00000001)return broad;
    vec3 tangent=broad/max(dot(face,broad),0.0001)-face;
    float limit=max(length(tangent),tactical_terrain_profile(family).y);
    tangent-=slope;
    tangent*=min(1.0,limit/max(length(tangent),0.000001));
    return normalize(face+tangent);
}

// Dry aggregate gets a low, broad sun response, not a wet reflection. Atlas
// gain controls roughness; pixel footprint and distance quietly remove glints.
vec3 tactical_asphalt_light(vec3 base,vec3 normal,vec3 eye,float gain,float distance,float eye_pixel) {
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    vec3 half_vector=sun+eye;
    if(dot(half_vector,half_vector)<0.000001)return base;
    float roughness=clamp(0.82-(gain-1.0)*1.6,0.58,0.96);
    float power=mix(8.0,20.0,1.0-roughness);
    float blur=eye_pixel*power*0.5;
    float grazing=pow(1.0-clamp(abs(dot(normal,eye)),0.0,1.0),3.0);
    float range=distance/8000.0;
    float light=pow(max(dot(normal,normalize(half_vector)),0.0),power);
    light*=max(dot(normal,sun),0.0)*(0.35+0.65*grazing);
    light*=0.018/((1.0+blur*blur)*(1.0+range*range));
    return base+vec3(0.89,0.87,0.79)*light;
}

