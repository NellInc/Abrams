// Bounded Oren-Nayar-inspired diffuse correction and a decorative cavity cue.
// Original geometry, visibility, colour palette and specular lobes stay owned
// by the incumbent renderer. Reuse existing normals, eye and filtered gain.
vec3 tactical_rough_profile(float family) {
    if(family>0.5 && family<1.5)return vec3(0.12,0.18,0.035); // paint
    if(family>1.5 && family<2.5)return vec3(0.44,0.24,0.065); // plaster
    if(family>2.5 && family<3.5)return vec3(0.65,0.28,0.080); // masonry
    if(family>3.5 && family<4.5)return vec3(0.32,0.22,0.045); // timber
    if(family>4.5 && family<5.5)return vec3(0.40,0.20,0.035); // fabric
    if(family>5.5 && family<6.5)return vec3(0.22,0.17,0.045); // rubber
    if(family>6.5 && family<7.5)return vec3(0.35,0.23,0.055); // roofing
    if(family>7.5 && family<8.5)return vec3(0.26,0.18,0.025); // meadow
    if(family>9.5 && family<10.5)return vec3(0.56,0.26,0.055); // soil
    if(family>10.5 && family<11.5)return vec3(0.18,0.18,0.040); // asphalt
    return vec3(0.0); // foliage, water, glass, skin and unknowns are exact
}

float tactical_rough_gain(vec3 normal,vec3 eye,float family,float texture_gain,float distance,float eye_pixel) {
    vec3 profile=tactical_rough_profile(family);
    if(profile.x==0.0 || dot(normal,normal)<0.00000001 || dot(eye,eye)<0.00000001)return 1.0;
    vec3 n=normalize(normal);vec3 v=normalize(eye);
    vec3 sun=normalize(vec3(-0.58,0.34,0.74));
    float nl=clamp(dot(n,sun),0.0,1.0);float nv=clamp(dot(n,v),0.0,1.0);
    float sl=sqrt(max(1.0-nl*nl,0.0));float sv=sqrt(max(1.0-nv*nv,0.0));
    float azimuth=0.0;
    if(sl>0.0001 && sv>0.0001)azimuth=clamp((dot(sun,v)-nl*nv)/(sl*sv),0.0,1.0);
    float a=1.0-0.5*profile.x/(profile.x+0.33);
    float b=0.45*profile.x/(profile.x+0.09);
    // Evaluate irradiance rather than a grazing BRDF division. The last
    // denominator is conservative at the horizon; nl=0 adds no direct light.
    float rough=nl*(a+b*azimuth*max(sl,sv)*min(sl,sv)/max(max(nl,nv),0.05));
    float cavity=clamp((1.0-texture_gain)/0.18,0.0,1.0)*profile.z;
    float gain=clamp(1.0+(rough-nl)*profile.y-cavity,0.88,1.065);
    float range=max(distance,0.0)/16000.0;float pixel=max(eye_pixel,0.0)*8.0;
    float resolved=1.0/(1.0+range*range+pixel*pixel);
    return mix(1.0,gain,resolved);
}
