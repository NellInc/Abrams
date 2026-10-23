shader_type canvas_item;
render_mode unshaded;
// Authored ambient motion. The original PC selects and times the entire slide.
// Explicit phase keeps captures, pause and reduced-motion deterministic.
uniform float smoke_phase = 0.0;
uniform int scene_index = 0;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
float cool(vec3 c) {
	return step(0.28,c.r)*step(c.r-0.02,c.g)*step(c.g-0.03,c.b);
}
void fragment() {
	vec4 base=texture(TEXTURE,UV);
	vec2 q=UV;
	float anchor=0.0;
	if (scene_index==1) {
		if (UV.x>0.19 && UV.x<0.33 && UV.y<0.565) anchor=(1.0-smoothstep(0.30,0.565,UV.y));
		if (UV.x>0.43 && UV.x<0.66 && UV.y<0.445) anchor=(1.0-smoothstep(0.20,0.445,UV.y));
		if (UV.x>0.69 && UV.x<0.84 && UV.y<0.399) anchor=(1.0-smoothstep(0.17,0.399,UV.y));
	} else if (scene_index==2 && UV.x>0.51 && UV.x<0.57 && UV.y<0.658) {
		anchor=(1.0-smoothstep(0.35,0.658,UV.y));
	}
	q.x+=(sin(UV.y*19.0+smoke_phase)-sin(UV.y*19.0))*0.004*anchor;
	q.y+=(sin(UV.y*13.0+smoke_phase*0.5)-sin(UV.y*13.0))*0.005*anchor;
	vec4 moved=texture(TEXTURE,q);
	// Registered plumes include adjacent sky so a moving edge replaces its
	// original footprint cleanly. Warm flames and hardware stay source-fixed.
	// Testing only smoke-coloured texels left a thin unmoved edge behind.
	float safe=cool(base.rgb)*cool(moved.rgb)*step(0.0001,anchor);
	COLOR=mix(base,moved,safe)*vertex_tint;
}
