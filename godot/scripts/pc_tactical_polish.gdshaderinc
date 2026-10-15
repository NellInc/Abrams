// Tactical variant only. Existing filtered atlas gain supplies material colour
// separation; never introduce a second grain field, seam, wear mask or sample.
// Family order is the incumbent realism_response order. Matte minerals get
// warmer pores, timber warmer fibres, rubber a quiet neutral response. Painted
// steel remains almost chromatically neutral and keeps its authored livery.
vec3 tactical_polish_colour_response(float family) {
    if(family>0.5 && family<1.5)return vec3(0.004,0.002,-0.003);
    if(family>1.5 && family<2.5)return vec3(0.016,0.003,-0.012);
    if(family>2.5 && family<3.5)return vec3(0.019,0.005,-0.014);
    if(family>3.5 && family<4.5)return vec3(0.022,0.003,-0.017);
    if(family>4.5 && family<5.5)return vec3(0.006,0.002,-0.005);
    if(family>5.5 && family<6.5)return vec3(-0.004,0.001,0.004);
    if(family>6.5 && family<7.5)return vec3(0.009,0.002,-0.007);
    return vec3(0.0);
}

// Caller admission must include Tactical, modern active, observed daylight,
// environment/surface variation, ready atlas, detail > 1, sampled/usable UVs
// and the existing source-model tags (excluding crew, courtyard and glass).
// Keep every fallback byte-for-byte at the input value. Reject degenerate or
// mirrored UV charts; all derivatives are those captured before owner discard.
vec3 tactical_polish_finish_colour(vec3 base,vec3 face,float family,float gain,
        vec2 uv_dx,vec2 uv_dy,vec3 point_dx,vec3 point_dy,float distance,
        float eye_pixel,bool admitted) {
    if(!admitted || family<=0.5 || family>=7.5 || gain==1.0)return base;
    if(!(dot(face,face)>=0.00000001) || !(gain>=0.82 && gain<=1.18))return base;
    float uv_area=uv_dx.x*uv_dy.y-uv_dx.y*uv_dy.x;
    float uv_scale=length(uv_dx)*length(uv_dy);
    float point_area=dot(point_dx,cross(point_dy,face));
    float point_scale=length(point_dx)*length(point_dy)*length(face);
    if(!(uv_scale>=0.00000001 && point_scale>=0.00000001))return base;
    if(abs(uv_area)<uv_scale*0.0001 || abs(point_area)<point_scale*0.0001)return base;
    if(!(uv_area*point_area>0.0) || !(distance>=0.0 && eye_pixel>=0.0))return base;
    // The sampled gain already converges toward one as its detail resolves to
    // the atlas mean. This additional broad tail is continuous and never
    // resurrects hidden high-frequency detail or changes its mip selection.
    float range=max(distance,0.0)/12000.0;
    float angular=max(eye_pixel,0.0)*12.0;
    float resolved=1.0/(1.0+range*range+angular*angular);
    float grain=clamp((gain-1.0)/0.18,-1.0,1.0)*resolved;
    vec3 tint=vec3(1.0)+tactical_polish_colour_response(family)*grain;
    return base*(OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2)));
}

// One source-stable canopy palette for the nearby authored sprite and distant
// woodland. Broad tint only, with supplied pre-discard derivative filtering.
vec3 tactical_polish_crown(vec3 colour,vec2 uv,float seed,vec2 footprint) {
    if(!(seed>=0.0 && seed<=1.0) || !(dot(footprint,footprint)>=0.0))return colour;
    float resolved=1.0/(1.0+dot(footprint,footprint)*36.0);
    float shade=(seed-0.5)*resolved;
    float lower=smoothstep(0.48,0.805,uv.y)*resolved;
    return colour*(vec3(1.0)+vec3(0.045,0.018,-0.028)*shade)+vec3(0.003,0.005,0.001)*lower;
}
vec3 tactical_polish_collar(vec3 bark,vec2 uv,vec2 footprint) {
    float resolved=1.0/(1.0+dot(footprint,footprint)*64.0);
    // A broad lift of the existing upper stem, no extra trunk or canopy area.
    float collar=(1.0-smoothstep(0.805,0.88,uv.y))*resolved;
    return bark+vec3(0.008,0.010,0.006)*collar;
}
vec3 tactical_polish_road_edge(vec3 base,vec2 edges,vec2 dx,vec2 dy,float distance) {
    float width=edges.x+edges.y;
    if(!(edges.x>=0.0 && edges.y>=0.0 && width>=8.0 && distance>=0.0))return base;
    float footprint=max(length(dx),length(dy));
    float band=min(width*0.085,64.0);
    float resolved=1.0/(1.0+pow(footprint/max(band,1.0),2.0)+pow(distance/18000.0,2.0));
    float edge=1.0-smoothstep(0.0,band+footprint,min(edges.x,edges.y));
    // Dry shoulder tone remains strictly on the original road-owned face.
    return base*mix(vec3(1.0),vec3(1.038,1.026,1.012),edge*resolved);
}
