// Tactical screen-space light: helpers shared by the source-depth target and
// the multiplicative shade pass. No clocks, scene lights or texture assets.

// The fixed Tactical sun, in the source-world frame used by pc_surface,
// pc_tactical_materials, the foliage and vehicle shaders (x east, y north,
// z up). test_pc_tactical_light.gd checks every copy still agrees.
const vec3 TACTICAL_LIGHT_SUN=vec3(-0.58,0.34,0.74);

// Godot 4.7.2 Compatibility writes linear_to_srgb(srgb_to_linear(ALBEDO)),
// where srgb_to_linear is the cubic in drivers/gles3/shaders/tonemap_inc.glsl.
// Invert that once so a written value lands on the intended 8-bit code (the
// CPU does the same for ownership IDs in pc_colour.input_color).
vec3 light_output(vec3 v) {
    vec3 target=pow((clamp(v,0.0,1.0)+0.055)/1.055,vec3(2.4));
    vec3 x=pow(target,vec3(1.0/2.2));
    for (int i=0;i<5;i++) {
        vec3 curve=x*(x*(x*0.305306011+0.682171111)+0.012522878);
        vec3 slope=x*(x*0.915918033+1.364342222)+0.012522878;
        x-=(curve-target)/max(slope,vec3(0.0001));
        x=clamp(x,0.0,1.0);
    }
    return mix(x,vec3(0.0),vec3(lessThanEqual(v,vec3(0.0))));
}

// 22-bit log2 forward depth in raw source units, 16 to 262144 (14 octaves),
// relative step 2.3e-6, so reconstructed normals stay smooth on broad faces.
// Red, green and the upper six bits of blue carry the code; the low two bits
// of blue carry the light class (1 static scenery, 2 terrain, 3 actor). An
// all-zero texel is "no usable depth" (sprite or round command).
const float LIGHT_LOG_NEAR=4.0;
const float LIGHT_LOG_SPAN=14.0;
const float LIGHT_CODES=4194303.0;
vec3 light_depth_bytes(float forward, float light_class) {
    float t=clamp((log2(max(forward,16.0))-LIGHT_LOG_NEAR)/LIGHT_LOG_SPAN,0.0,1.0);
    float code=1.0+floor(t*(LIGHT_CODES-1.0)+0.5);
    float red=floor(code/16384.0);
    float rest=code-red*16384.0;
    float green=floor(rest/64.0);
    return vec3(red,green,(rest-green*64.0)*4.0+light_class);
}
// x: forward depth, y: class (0 none, 1 static scenery, 2 terrain, 3 actor).
vec2 light_depth_decode(vec3 bytes) {
    float light_class=mod(bytes.b,4.0);
    float code=bytes.r*16384.0+bytes.g*64.0+floor(bytes.b/4.0);
    if (code<0.5 || light_class<0.5) return vec2(0.0);
    return vec2(exp2(LIGHT_LOG_NEAR+(code-1.0)/(LIGHT_CODES-1.0)*LIGHT_LOG_SPAN),light_class);
}

// Jimenez's interleaved gradient noise (SIGGRAPH 2014), fixed to the pixel.
float light_noise(vec2 pixel) {
    return fract(52.9829189*fract(dot(pixel,vec2(0.06711056,0.00583715))));
}
