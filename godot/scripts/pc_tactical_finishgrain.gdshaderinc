// Smooth object-local de-repetition of the existing material-detail atlas.
// The original semantic patterns, terrain, foliage and all protected families
// retain their incumbent sampling. No additional texture read or clock.
vec2 tactical_finish_grain_profile(float family) {
    if(family>0.5 && family<1.5)return vec2(0.035,0.025); // paint
    if(family>1.5 && family<2.5)return vec2(0.150,0.100); // plaster
    if(family>2.5 && family<3.5)return vec2(0.100,0.080); // masonry
    if(family>3.5 && family<4.5)return vec2(0.035,0.055); // timber
    if(family>4.5 && family<5.5)return vec2(0.018,0.018); // fabric
    if(family>5.5 && family<6.5)return vec2(0.025,0.020); // rubber
    if(family>6.5 && family<7.5)return vec2(0.045,0.028); // roofing
    return vec2(0.0);
}

mat2 tactical_finish_grain_coordinates(inout vec2 uv,inout vec2 dx,inout vec2 dy,float family) {
    vec2 amplitude=tactical_finish_grain_profile(family);
    if(dot(amplitude,amplitude)==0.0)return mat2(vec2(1.0,0.0),vec2(0.0,1.0));
    vec2 u=vec2(0.47,0.21);vec2 v=vec2(-0.19,0.43);
    vec2 phase=vec2(dot(uv,u),dot(uv,v));
    vec2 rate=amplitude*cos(phase);
    // Column-major Jacobian: derivatives follow the transformed coordinates.
    mat2 jacobian=mat2(vec2(1.0+rate.x*u.x,rate.y*v.x),vec2(rate.x*u.y,1.0+rate.y*v.y));
    dx=jacobian*dx;dy=jacobian*dy;
    uv+=amplitude*sin(phase);
    return jacobian;
}

vec3 tactical_finish_grain_sample(vec2 uv,vec2 dx,vec2 dy,float family,float distance) {
    mat2 jacobian=tactical_finish_grain_coordinates(uv,dx,dy,family);
    vec3 sampled=realism_sample(uv,dx,dy,family,distance);
    // The sampler's slopes are in warped coordinates. Pull them back into the
    // original model UV plane before its established face-normal conversion.
    vec2 gradient=vec2(dot(jacobian[0],sampled.yz),dot(jacobian[1],sampled.yz));
    return vec3(sampled.x,gradient);
}
