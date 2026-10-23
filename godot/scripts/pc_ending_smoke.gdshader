shader_type canvas_item;
render_mode unshaded;
// Source-registered ambient motion only. The PC still selects and times slides.
// No TIME: pause, captures and reduced motion share the explicit phase.
uniform float smoke_phase = 0.0;
uniform int scene_index = 0;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
float cool(vec3 c) {
	return step(0.28,c.r)*step(c.r-0.02,c.g)*step(c.g-0.03,c.b);
}
float fire(vec3 c) {
	return step(0.65,c.r)*step(0.10,c.r-c.g)*step(0.08,c.g-c.b);
}
float plume(vec3 c) {
	return cool(c)*(1.0-smoothstep(0.10,0.22,c.g-c.r));
}
void fragment() {
	vec4 base=texture(TEXTURE,UV);
	vec4 result=base;
	float anchor=0.0;
	float flame_tip=0.0;
	float flame_region=0.0;
	if (scene_index==1) {
		if (UV.x>0.19 && UV.x<0.33 && UV.y<0.565) anchor=1.0-smoothstep(0.30,0.565,UV.y);
		if (UV.x>0.43 && UV.x<0.66 && UV.y<0.445) anchor=1.0-smoothstep(0.20,0.445,UV.y);
		if (UV.x>0.69 && UV.x<0.84 && UV.y<0.399) anchor=1.0-smoothstep(0.17,0.399,UV.y);
		if (UV.x>0.21 && UV.x<0.245 && UV.y>0.50 && UV.y<0.575) {
			flame_region=1.0; flame_tip=1.0-smoothstep(0.52,0.57,UV.y);
		}
		if (UV.x>0.44 && UV.x<0.56 && UV.y>0.45 && UV.y<0.62) {
			flame_region=1.0; flame_tip=1.0-smoothstep(0.49,0.60,UV.y);
		}
		if (UV.x>0.55 && UV.x<0.65 && UV.y>0.33 && UV.y<0.54) {
			flame_region=1.0; flame_tip=1.0-smoothstep(0.40,0.53,UV.y);
		}
		if (UV.x>0.72 && UV.x<0.81 && UV.y>0.33 && UV.y<0.54) {
			flame_region=1.0; flame_tip=1.0-smoothstep(0.40,0.53,UV.y);
		}
	} else if (scene_index==2) {
		if (UV.x>0.51 && UV.x<0.57 && UV.y<0.658) anchor=1.0-smoothstep(0.35,0.658,UV.y);
		if (UV.x>0.53 && UV.x<0.56 && UV.y>0.64 && UV.y<0.677) {
			flame_region=1.0; flame_tip=(1.0-smoothstep(0.655,0.675,UV.y))*0.20;
		}
	}
	// Travelling curls climb through the plumes; the base remains anchored.
	// Include both footprints to erase vacated edges, but leave open sky still.
	vec2 q=UV;
	q.x+=((sin(UV.y*29.0+smoke_phase*2.2)-sin(UV.y*29.0))*0.012
		+(sin(UV.y*61.0+smoke_phase*3.1)-sin(UV.y*61.0))*0.003)*anchor;
	q.y+=(sin(UV.y*23.0+smoke_phase*1.8)-sin(UV.y*23.0))*0.020*anchor;
	vec4 moved=texture(TEXTURE,q);
	float smoke_mask=cool(base.rgb)*cool(moved.rgb)*max(plume(base.rgb),plume(moved.rgb))*step(0.0001,anchor);
	result=mix(result,moved,smoke_mask);
	// Animate the authored flame colours, including tips against smoke/sky.
	// Dark/olive wreck pixels are ineligible, so no hardware can wobble.
	vec2 f=UV;
	f.x+=(sin(UV.y*113.0+smoke_phase*8.0)-sin(UV.y*113.0))*0.004*flame_tip;
	f.y+=(sin(UV.x*139.0+smoke_phase*6.0)-sin(UV.x*139.0))*0.009*flame_tip;
	vec4 flicker=texture(TEXTURE,f);
	float original_fire=fire(base.rgb);
	float moved_fire=fire(flicker.rgb);
	float fire_mask=flame_region*max(original_fire,moved_fire)
		*max(cool(base.rgb),original_fire)*max(cool(flicker.rgb),moved_fire);
	float pulse=1.0+0.12*(sin(smoke_phase*13.0+UV.x*53.0)-sin(UV.x*53.0))
		+0.06*(sin(smoke_phase*21.0+UV.y*87.0)-sin(UV.y*87.0));
	flicker.rgb=mix(flicker.rgb,clamp(flicker.rgb*vec3(pulse,0.98*pulse+0.02,1.0),vec3(0.0),vec3(1.0)),moved_fire);
	result=mix(result,flicker,fire_mask);
	COLOR=result*vertex_tint;
}
