shader_type canvas_item;
render_mode unshaded;
uniform vec4 strokes[8]; // source-pixel inclusive/exclusive rectangle edges
uniform int stroke_count = 0;
uniform vec4 ink_color = vec4(0.0,0.0,0.0,1.0);

void fragment() {
	vec2 p = UV*vec2(320.0,200.0);
	vec2 footprint = fwidth(p);
	float coverage = 0.0;
	bool owned = false;
	for (int i=0; i<8; i++) {
		if (i>=stroke_count) break;
		vec4 r = strokes[i];
		vec2 overlap = clamp((min(p+footprint*0.5,r.zw)-max(p-footprint*0.5,r.xy))/footprint,vec2(0.0),vec2(1.0));
		coverage = max(coverage,overlap.x*overlap.y);
		// Never extend the antialias fringe into another source-owned symbol.
		owned = owned || (all(greaterThanEqual(floor(p),r.xy)) && all(lessThan(floor(p),r.zw)));
	}
	COLOR = vec4(ink_color.rgb,owned ? coverage : 0.0);
}
