// Frozen pre-radiance sky from the retained 2026-10-12 Tactical lighting snapshot.
// Source pc_surface.gdshader SHA256:
// 51f9db7a661f1cefe79778951fa857222538240b853490c0de3a8919943bedf7
// Function renamed only; colour and cloud operations remain unchanged.
vec3 preceding_sky_colour(vec3 direction) {
    float height=max(direction.z,0.0);
    vec3 colour=mix(vec3(0.78,0.82,0.76),vec3(0.46,0.62,0.69),smoothstep(0.0,0.62,height));
    vec2 p=direction.xy/(height+0.32)*vec2(1.65,3.8);
    float shape=ground_noise(p+vec2(4.7,9.2))*0.76+ground_noise(p*2.1)*0.24;
    float cloud=smoothstep(0.57,0.72,shape)*smoothstep(0.045,0.18,height);
    // Dense banks have a softly shaded underside and brighter thinner edges.
    // Reuse the broad cloud field rather than adding noise or a moving clock.
    float bank=smoothstep(0.57,0.76,shape);
    vec3 lit=mix(vec3(0.90,0.92,0.87),vec3(0.70,0.76,0.74),bank*0.58);
    lit+=vec3(0.025,0.022,0.014)*smoothstep(0.14,0.55,height)*0.35;
    return mix(colour,lit,cloud*0.40);
}
