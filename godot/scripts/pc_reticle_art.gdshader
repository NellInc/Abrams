shader_type canvas_item;
render_mode unshaded;
uniform vec4 strokes[8]; // source-pixel inclusive/exclusive rectangle edges
uniform int stroke_count = 0;
uniform vec4 ink_color = vec4(0.0,0.0,0.0,1.0);
uniform bool tactical = false;

void fragment() {
	vec2 p = UV*vec2(320.0,200.0);
	vec2 footprint = fwidth(p);
	float coverage = 0.0;
	float inset_pixels = 0.0;
	bool owned = false;
	for (int i=0; i<8; i++) {
		if (i>=stroke_count) break;
		vec4 r = strokes[i];
		vec2 overlap = clamp((min(p+footprint*0.5,r.zw)-max(p-footprint*0.5,r.xy))/footprint,vec2(0.0),vec2(1.0));
		coverage = max(coverage,overlap.x*overlap.y);
		if (tactical) inset_pixels=max(inset_pixels,min(min(p.x-r.x,r.z-p.x)/footprint.x,min(p.y-r.y,r.w-p.y)/footprint.y));
		// Never extend the antialias fringe into another source-owned symbol.
		owned = owned || (all(greaterThanEqual(floor(p),r.xy)) && all(lessThan(floor(p),r.zw)));
	}
	vec3 ink=ink_color.rgb;
	// Etched daylight ink stays wholly inside the proven original strokes.
	// White thermal ink, the aim gap and every source endpoint remain unchanged.
	if (tactical && ink_color.r<0.5) ink=mix(vec3(0.035,0.065,0.047),vec3(0.80,0.86,0.65),smoothstep(0.65,1.25,inset_pixels));
	COLOR = vec4(ink,owned ? coverage : 0.0);
}
