// Frozen authored pre-microfinish atlas functions. No original-game data.
// Source: artifacts/tactical-naturalism-20261012/source/godot/scripts/pc_tactical_materials.gdshaderinc
// SHA-256: 89017f8301ac7edc7b45d7b5aa7089c76e433458a93dc13eccb671416de045a2
// Original helper text below is unchanged; the test namespaces it at runtime.
float realism_mean(float family) {
    if(family<1.5)return 0.454363346;
    if(family<2.5 || family>13.5)return 0.598401989;
    if(family<3.5)return 0.690467338;
    if(family<4.5)return 0.509101657;
    if(family<5.5)return 0.461039571;
    if(family<6.5)return 0.359861930;
    if(family<7.5)return 0.453370871;
    if(family<8.5)return 0.364562218;
    if(family<9.5)return 0.378619436;
    if(family<10.5)return 0.420609281;
    if(family<11.5)return 0.404078622;
    if(family<12.5)return 0.453220157;
    return 0.505315401;
}

bool realism_ground(float family) {
    return (family>7.5 && family<8.5) || (family>9.5 && family<11.5);
}

// Ground detail fades by the anisotropic ellipse, not just its longest axis.
// The 16x default can resolve a narrow footprint even at grazing angles.
// Walls, equipment and foliage keep the original conservative fade.
float realism_footprint(vec2 dx,vec2 dy,float family) {
    float footprint=max(length(dx),length(dy))*512.0;
    if(realism_ground(family)) {
        vec2 x=dx*512.0;vec2 y=dy*512.0;
        float a=dot(x,x);float b=dot(x,y);float c=dot(y,y);
        float major=sqrt(max(0.5*(a+c+sqrt(max((a-c)*(a-c)+4.0*b*b,0.0))),0.0));
        // determinant/major avoids cancellation for very elongated footprints.
        float minor=abs(x.x*y.y-x.y*y.x)/max(major,0.000001);
        footprint=max(minor,major/16.0);
    }
    return footprint;
}

// Gentle continuous variation softens mirrored terrain repeats. Carry the
// exact Jacobian into textureGrad so the warped detail still resolves to mips.
// Coordinates remain source-world anchored, with no time or camera seed.
void realism_ground_coordinates(inout vec2 uv,inout vec2 dx,inout vec2 dy) {
    vec2 phase=vec2(dot(uv,vec2(0.41,0.19)),dot(uv,vec2(-0.17,0.37)));
    vec2 rate=0.22*cos(phase);
    dx+=rate*vec2(dot(dx,vec2(0.41,0.19)),dot(dx,vec2(-0.17,0.37)));
    dy+=rate*vec2(dot(dy,vec2(0.41,0.19)),dot(dy,vec2(-0.17,0.37)));
    uv+=0.22*sin(phase);
}

// Match detail contrast to the surface. Small, soft materials should not
// inherit the pronounced height/colour variation of masonry.
vec2 realism_response(float family) {
    if(family<1.5)return vec2(0.70,0.65); // painted steel
    if(family<2.5)return vec2(0.62,0.55); // plaster
    if(family<3.5)return vec2(0.85,1.00); // masonry
    if(family<4.5)return vec2(0.72,0.70); // timber and bark
    if(family<5.5)return vec2(0.45,0.40); // fabric and webbing
    if(family<6.5)return vec2(0.38,0.35); // rubber and leather
    if(family<7.5)return vec2(0.70,0.75); // roofing
    if(family<8.5)return vec2(0.55,0.45); // meadow
    if(family<9.5)return vec2(0.58,0.40); // leaves
    if(family<10.5)return vec2(0.66,0.65); // soil
    if(family<11.5)return vec2(0.58,0.50); // asphalt
    if(family<12.5)return vec2(0.38,1.00); // water
    if(family<13.5)return vec2(0.18,0.15); // glazing
    return vec2(0.06,0.15); // original skin colours
}

// UVs live in the source object's dominant plane or observed world terrain.
// Mirrored tiles have continuous edge coordinates; padded tiles do not bleed.
float realism_gain(vec2 uv,vec2 dx,vec2 dy,float family,float distance) {
    if(realism_ground(family))realism_ground_coordinates(uv,dx,dy);
    float index=family>13.5 ? 1.0 : family-1.0;
    vec2 origin=vec2(mod(index,4.0),floor(index/4.0))*288.0+16.0;
    vec2 tile=1.0-abs(fract(uv)*2.0-1.0);
    vec2 orientation=mix(vec2(1.0),vec2(-1.0),step(vec2(0.5),fract(uv)));
    vec2 gx=dx*orientation*(512.0/1152.0);
    vec2 gy=dy*orientation*(512.0/1152.0);
    vec2 sample_uv=(origin+tile*255.0+0.5)/1152.0;
    float fade=1.0-smoothstep(4.0,16.0,realism_footprint(dx,dy,family));
    fade*=1.0-smoothstep(2400.0,9000.0,distance);
    if(fade<0.001)return 1.0;
    float height=textureGrad(tactical_realism_atlas,sample_uv,gx,gy).r;
    float hx=textureGrad(tactical_realism_atlas,sample_uv+vec2(1.0/1152.0,0.0),gx,gy).r;
    float hy=textureGrad(tactical_realism_atlas,sample_uv+vec2(0.0,1.0/1152.0),gx,gy).r;
    vec2 response=realism_response(family);
    // Small height-gradient relief changes light, never vertices or alpha.
    float relief=clamp((height-hx)*0.8+(hy-height)*0.5,-0.075,0.075);
    relief*=response.y;
    return 1.0+clamp((height-realism_mean(family))*response.x+relief,-0.18,0.18)*fade;
}

float realism_period(float family) {
    if(family<1.5)return 78.0;
    if(family<2.5)return 136.0;
    if(family<3.5)return 44.0;
    if(family<4.5)return 36.0;
    if(family<5.5)return 42.0;
    if(family<6.5)return 28.0;
    if(family<7.5)return 96.0;
    if(family<8.5)return 160.0;
    if(family<9.5)return 54.0;
    if(family<10.5)return 128.0;
    if(family<11.5)return 144.0;
    if(family<12.5)return 280.0;
    return 96.0;
}
