shader_type canvas_item;
render_mode unshaded;
uniform sampler2D map_pixels : filter_nearest, repeat_disable;
uniform vec4 marker_0;
uniform vec4 marker_1;
uniform vec4 marker_colour_0;
uniform vec4 marker_colour_1;

vec3 cartography(vec3 c) {
	// Each distinct source class has a distinct material. This never classifies
	// units, adds contacts, or discards small regions as alleged background.
	ivec3 rgb=ivec3(round(c*255.0));
	if (rgb==ivec3(0)) return vec3(0.035,0.055,0.042);
	if (rgb==ivec3(255)) return vec3(0.94,0.94,0.81);
	if (rgb==ivec3(170)) return vec3(0.64,0.66,0.49);
	if (rgb==ivec3(85)) return vec3(0.43,0.48,0.36);
	if (rgb==ivec3(85,85,255)) return vec3(0.16,0.33,0.39);
	if (rgb==ivec3(85,255,255)) return vec3(0.48,0.82,0.79);
	if (rgb==ivec3(170,0,0)) return vec3(0.88,0.39,0.28);
	if (rgb==ivec3(170,85,0)) return vec3(0.49,0.36,0.20);
	if (rgb==ivec3(0,170,0)) return vec3(0.22,0.32,0.21);
	if (rgb==ivec3(85,255,85)) return vec3(0.64,0.85,0.45);
	if (rgb==ivec3(255,255,85)) return vec3(0.91,0.77,0.40);
	if (rgb==ivec3(255,85,85)) return vec3(1.0,0.62,0.50);
	if (rgb==ivec3(0,0,170)) return vec3(0.19,0.28,0.60);
	return c;
}

vec3 cell(vec2 at) {
	return cartography(texture(map_pixels,clamp((at+0.5)/vec2(144.0,96.0),vec2(0.5)/vec2(144.0,96.0),vec2(1.0)-vec2(0.5)/vec2(144.0,96.0))).rgb);
}

bool inside(vec2 p,vec4 r) { return all(greaterThanEqual(p,r.xy)) && all(lessThan(p,r.zw)); }

void fragment() {
	vec2 p=UV*vec2(144.0,96.0);
	vec2 at=floor(p);
	vec2 f=fract(p);
	vec2 width=min(fwidth(p)*0.65,vec2(0.22));
	vec3 colour=cell(at);
	// Antialias only the existing boundary, within one output pixel. No
	// smoothing/simplification changes a region, channel or isolated contact.
	vec2 edge=min(f,1.0-f);
	vec2 direction=mix(vec2(-1.0),vec2(1.0),step(vec2(0.5),f));
	vec2 blend=(1.0-smoothstep(vec2(0.0),width,edge))*0.5;
	colour=mix(colour,cell(at+vec2(direction.x,0)),blend.x);
	colour=mix(colour,cell(at+vec2(0,direction.y)),blend.y);
	// A quiet, unnumbered plotting grid is material, not added terrain data.
	vec2 grid=abs(fract(p/24.0+0.5)-0.5)*24.0;
	float rule=1.0-smoothstep(0.0,max(width.x,width.y),min(grid.x,grid.y));
	colour=mix(colour,colour*1.075,rule*0.55);
	COLOR=vec4(colour,1.0);
	// Source-selected colours include black. Never hide or independently blink it.
	if (inside(p,marker_0)) COLOR=marker_colour_0;
	if (inside(p,marker_1)) COLOR=marker_colour_1;
}
