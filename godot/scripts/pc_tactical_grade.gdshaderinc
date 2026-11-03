// Tactical daylight grade for the composed 3D view (pc_tandem_frame.gdshader).
// A hue-preserving luminance S-curve whose own slope stays within 0.78..1.22
// (Nell asked for a stronger grade, 2 November 2026), a vibrance lift that
// favours muted colours, and a luminance-neutral warm-light/cool-shade split.
// test_pc_tactical_light.gd measures the combined response on rendered ramps.
vec3 tactical_grade_colour(vec3 c) {
	float luma=dot(c,vec3(0.2126,0.7152,0.0722));
	if (luma<=0.0) return c;
	float curved=luma-0.22*sin(6.2831853*luma)/6.2831853;
	vec3 graded=c*(curved/luma);
	float spread=max(max(graded.r,graded.g),graded.b)-min(min(graded.r,graded.g),graded.b);
	graded=mix(vec3(curved),graded,1.0+0.30*(1.0-clamp(spread,0.0,1.0)));
	// The split tone carries no luminance and fades out toward white, so it
	// never pushes a bright channel into clipping.
	vec3 tint=mix(vec3(0.965,0.995,1.060),vec3(1.050,1.008,0.945),smoothstep(0.15,0.75,curved));
	tint/=dot(tint,vec3(0.2126,0.7152,0.0722));
	graded*=mix(tint,vec3(1.0),smoothstep(0.80,1.0,curved));
	return clamp(graded,0.0,1.0);
}
