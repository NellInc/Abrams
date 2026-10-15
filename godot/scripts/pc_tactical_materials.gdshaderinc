uniform bool tactical_realism_ready = false;
uniform sampler2D tactical_realism_atlas : filter_linear_mipmap_anisotropic, repeat_disable;

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
// Return the preceding colour gain plus a signed, filtered height gradient.
// The three existing atlas reads supply both; no extra texture lookup.
vec3 realism_sample(vec2 uv,vec2 dx,vec2 dy,float family,float distance) {
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
    float colour_fade=fade;
    if(realism_ground(family)) {
        // Mip/anisotropic sampling already removes unresolved colour detail.
        // Retain a broad tail instead of switching all ground contrast off at
        // the relief cutoff. Normals keep their conservative preceding fade.
        float footprint=realism_footprint(dx,dy,family)/8.0;
        float range=max(distance-1200.0,0.0)/9000.0;
        colour_fade=1.0/((1.0+footprint*footprint)*(1.0+range*range));
    }
    if(max(fade,colour_fade)<0.001)return vec3(1.0,0.0,0.0);
    float height=textureGrad(tactical_realism_atlas,sample_uv,gx,gy).r;
    float hx=textureGrad(tactical_realism_atlas,sample_uv+vec2(1.0/1152.0,0.0),gx,gy).r;
    float hy=textureGrad(tactical_realism_atlas,sample_uv+vec2(0.0,1.0/1152.0),gx,gy).r;
    vec2 response=realism_response(family);
    // Small height-gradient relief changes light, never vertices or alpha.
    float relief=clamp((height-hx)*0.8+(hy-height)*0.5,-0.075,0.075);
    relief*=response.y;
    float gain=1.0+clamp((height-realism_mean(family))*response.x+relief,-0.18,0.18)*colour_fade;
    // Mirrored tiles reverse their local slope. Quiet folds before an unresolved
    // finite-difference normal can become a bright repeat seam.
    vec2 cell=fract(uv);
    vec2 fold=min(min(cell,vec2(1.0)-cell),abs(cell-vec2(0.5)));
    vec2 seam=smoothstep(vec2(0.0),max(abs(dx)+abs(dy),vec2(2.0/512.0)),fold);
    vec2 gradient=vec2(hx-height,hy-height)*512.0*orientation*fade*seam;
    return vec3(gain,gradient);
}

float realism_gain(vec2 uv,vec2 dx,vec2 dy,float family,float distance) {
    return realism_sample(uv,dx,dy,family,distance).x;
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


// Analytic, source-unit atmospheric colour only. Near detail is exact; the
// caller chooses a conservative maximum blend for terrain or original actors.
float tactical_air_weight(vec3 relative,float eye_height,float ceiling) {
    float distance=length(relative);
    if(distance<=600.0 || ceiling<=0.0)return 0.0;
    float start=max(eye_height,0.0);
    float end=max(eye_height+relative.z,0.0);
    float a=exp2(-start/512.0);float b=exp2(-end/512.0);
    float height_delta=(end-start)/512.0;
    float density=abs(height_delta)<0.002 ? (a+b)*0.5 : (a-b)/(height_delta*0.69314718);
    density=0.35+0.65*clamp(density,0.0,1.0);
    float path=1.0-exp2(-max(distance-600.0,0.0)/9000.0);
    return clamp(path*density*ceiling,0.0,ceiling);
}

// Display-space ratios, bounded before working-colour conversion. Source
// normals supply broad hemisphere fill; no added light, texture or shadow pass.
vec3 tactical_environment_tint(vec3 normal,float strength) {
    vec3 n=normal/max(length(normal),0.0001);
    float sky=clamp(n.z*0.5+0.5,0.0,1.0);
    float facing=clamp(dot(n,normalize(vec3(-0.58,0.34,0.0)))*0.5+0.5,0.0,1.0);
    vec3 tint=mix(vec3(0.975,1.0,1.045),vec3(1.035,1.015,0.970),facing);
    tint*=mix(0.968,1.012,sky);
    return mix(vec3(1.0),clamp(tint,vec3(0.94),vec3(1.06)),clamp(strength,0.0,1.0));
}

// One directional horizon palette for sky and existing atmospheric colour.
// Inputs use source-world coordinates with the camera's y sign undone.
vec3 tactical_horizon_palette(vec3 direction) {
    vec3 d=direction/max(length(direction),0.0001);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    float warm=pow(max(dot(d,sun),0.0),2.0);
    float cool=pow(max(dot(d,-sun),0.0),2.0);
    vec3 colour=mix(vec3(0.72,0.79,0.78),vec3(0.82,0.81,0.70),warm);
    return colour*mix(vec3(1.0),vec3(0.985,1.0,1.012),cool);
}

vec3 tactical_sky_finish(vec3 base,vec3 direction,float height) {
    vec3 d=direction/max(length(direction),0.0001);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    float h=clamp(height,0.0,1.0);
    float low=1.0-smoothstep(0.0,0.34,h);
    base=mix(base,tactical_horizon_palette(d),low*0.42);
    // A broad aureole, with no disc, bloom, actor reflection or moving clock.
    float halo=pow(max(dot(d,sun),0.0),4.0);
    halo*=0.045+0.07*(1.0-smoothstep(0.10,0.70,h));
    base=mix(base,vec3(0.91,0.875,0.73),halo);
    float opposite=pow(max(dot(d,-sun),0.0),2.0)*(1.0-smoothstep(0.15,0.70,h));
    base*=mix(vec3(1.0),vec3(0.982,1.005,1.02),opposite*0.5);
    base*=mix(vec3(1.0),vec3(0.970,1.002,1.028),smoothstep(0.22,0.86,h)*0.55);
    return clamp(base,vec3(0.0),vec3(1.0));
}

// Reuse the preceding cloud field and density, never add another noise octave.
vec3 tactical_cloud_finish(vec3 base,vec3 direction,float shape) {
    vec3 d=direction/max(length(direction),0.0001);
    float sunward=max(dot(d,normalize(vec3(-0.58,0.34,0.74))),0.0);
    float thin=smoothstep(0.55,0.63,shape)*(1.0-smoothstep(0.64,0.77,shape));
    float dense=smoothstep(0.61,0.79,shape);
    vec3 tint=mix(vec3(0.975,1.005,1.035),vec3(1.045,1.018,0.967),sunward);
    tint*=1.0-dense*0.03+thin*sunward*0.018;
    return clamp(base*tint,vec3(0.0),vec3(1.0));
}

vec3 tactical_air_colour(vec3 base,vec3 relative,float eye_height,float ceiling) {
    float amount=tactical_air_weight(relative,eye_height,ceiling);
    if(amount==0.0)return base;
    vec3 direction=relative/max(length(relative),0.0001);
    // Weight, near-field protection and contrast bounds remain unchanged.
    vec3 air=tactical_horizon_palette(direction);
    air=OUTPUT_IS_SRGB ? air : pow(air,vec3(2.2));
    return mix(base,air,amount);
}
