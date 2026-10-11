shader_type canvas_item;
render_mode unshaded;
uniform sampler2D map_pixels : filter_nearest, repeat_disable;
uniform sampler2D surface_pixels : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(144.0,96.0);
uniform bool local_map = false;
uniform vec4 marker_0;
uniform vec4 marker_1;
uniform vec4 marker_colour_0;
uniform vec4 marker_colour_1;

vec3 cartography(vec3 c) {
	ivec3 rgb=ivec3(round(c*255.0));
	if (rgb==ivec3(0)) return vec3(0.035,0.055,0.042);
	if (rgb==ivec3(255)) return vec3(0.94,0.94,0.81);
	if (rgb==ivec3(170)) return vec3(0.76,0.73,0.57);
	if (rgb==ivec3(85)) return vec3(0.55,0.60,0.46);
	if (rgb==ivec3(85,85,255)) return vec3(0.17,0.35,0.42);
	if (rgb==ivec3(85,255,255)) return vec3(0.48,0.82,0.79);
	if (rgb==ivec3(170,0,0)) return vec3(0.88,0.39,0.28);
	if (rgb==ivec3(170,85,0)) return vec3(0.49,0.36,0.20);
	if (rgb==ivec3(0,170,0)) return vec3(0.22,0.32,0.21);
	if (rgb==ivec3(85,255,85)) return vec3(0.64,0.85,0.45);
	if (rgb==ivec3(255,255,85)) return vec3(0.91,0.77,0.40);
	if (rgb==ivec3(255,85,85)) return vec3(1.0,0.62,0.50);
	if (rgb==ivec3(0,0,170)) return vec3(0.19,0.28,0.60);
	// Derived only from complete source-phased black/brown or gray/brown periods.
	if (rgb==ivec3(85,43,0)) return vec3(0.40,0.34,0.22);
	if (rgb==ivec3(128,85,43)) return vec3(0.56,0.50,0.36);
	return c;
}

bool same(vec3 a,vec3 b) { return distance(a,b)<0.001; }
bool inside(vec2 p,vec4 r) { return all(greaterThanEqual(p,r.xy)) && all(lessThan(p,r.zw)); }
vec4 cell(vec2 at) {
	return texture(surface_pixels,clamp((at+0.5)/grid_size,vec2(0.5)/grid_size,vec2(1.0)-vec2(0.5)/grid_size));
}
float corner_field(vec2 f,vec2 at,vec2 corner,vec3 positive) {
	vec2 away=mix(f,vec2(1.0)-f,corner);
	vec4 x0=cell(at+vec2(mix(-1.0,2.0,corner.x),0.0));
	vec4 x1=cell(at+vec2(mix(-1.0,2.0,corner.x),1.0));
	vec4 y0=cell(at+vec2(0.0,mix(-1.0,2.0,corner.y)));
	vec4 y1=cell(at+vec2(1.0,mix(-1.0,2.0,corner.y)));
	// Keep diagonal runs straight. At a bend/cap, join the next source edge
	// tangentially instead of leaving a 45-degree corner between patches.
	float bend_x=(min(x0.a,x1.a)>0.99 && same(x0.rgb,positive) && same(x1.rgb,positive))?0.0:1.0;
	float bend_y=(min(y0.a,y1.a)>0.99 && same(y0.rgb,positive) && same(y1.rgb,positive))?0.0:1.0;
	float t=clamp(away.x-away.y+0.5,0.0,1.0);
	float u=1.0-t;
	// Cubic Hermite arc in diagonal coordinates. Both endpoints stay at the
	// original shared-edge midpoints. The arc stays inside this corner's
	// source half-cell, retaining finite cores and open one-cell corridors.
	float boundary=0.5+bend_x*t*u*u+bend_y*t*t*u;
	float slope=bend_x*u*(1.0-3.0*t)+bend_y*t*(2.0-3.0*t);
	return (boundary-away.x-away.y)/sqrt(2.0*(1.0+slope*slope));
}
vec3 edged(vec3 raw,float distance_to_edge,float width) {
	vec3 colour=cartography(raw);
	ivec3 rgb=ivec3(round(raw*255.0));
	float line=1.0-smoothstep(width*0.5,width*1.8,distance_to_edge);
	if (rgb==ivec3(170) || rgb==ivec3(85)) colour=mix(colour,colour*0.68,line*0.75);
	if (rgb==ivec3(85,85,255)) colour=mix(colour,vec3(0.39,0.54,0.55),line*0.58);
	return colour;
}

void fragment() {
	vec2 p=UV*vec2(144.0,96.0);
	vec2 sample_position=UV*grid_size-0.5;
	vec2 at=floor(sample_position);
	vec2 f=fract(sample_position);
	vec4 a=cell(at), b=cell(at+vec2(1,0)), c=cell(at+vec2(0,1)), d=cell(at+vec2(1,1));
	// Explicit texel centres also remain exact when WebGL shares this texture
	// with the TextureRect's differently filtered default sampler.
	vec3 original=cartography(texture(map_pixels,(floor(p)+0.5)/vec2(144.0,96.0)).rgb);
	vec3 nearest=cell(floor(UV*grid_size)).rgb;
	vec3 colour=cartography(nearest);
	// Protected patches keep their nearest-cell footprint and styled palette.
	// Falling back to the full raw raster here reintroduced nearby stipple.
	bool safe=min(min(a.a,b.a),min(c.a,d.a))>0.99;
	if (safe) {
		vec3 other=!same(a.rgb,b.rgb)?b.rgb:(!same(a.rgb,c.rgb)?c.rgb:d.rgb);
		bool two=(same(b.rgb,a.rgb)||same(b.rgb,other)) && (same(c.rgb,a.rgb)||same(c.rgb,other)) && (same(d.rgb,a.rgb)||same(d.rgb,other));
		bool ba=same(b.rgb,a.rgb), ca=same(c.rgb,a.rgb), da=same(d.rgb,a.rgb);
		int count=1+int(ba)+int(ca)+int(da);
		bool diagonal=(count==2 && da);
		if (two && count<4 && !diagonal) {
			float field=0.0;
			vec3 positive=a.rgb, negative=other;
			if (count==1 || count==3) {
				vec2 corner=vec2(0);
				if (count==3) {
					positive=other;negative=a.rgb;
					corner=!ba?vec2(1,0):(!ca?vec2(0,1):vec2(1,1));
				}
				field=corner_field(f,at,corner,positive);
			} else field=ba?0.5-f.y:0.5-f.x;
			float aa=clamp(fwidth(field)*0.6,0.001,0.06);
			float line_width=clamp(fwidth(field),0.006,0.075);
			colour=mix(edged(negative,abs(field),line_width),edged(positive,abs(field),line_width),smoothstep(-aa,aa,field));
		}
		// Diagonal/checker and multi-class junctions retain their source shape.
	}
	// LOCAL has no terrain evidence beneath the player, so this stencil uses
	// exact current source texels rather than the cache's transparent sentinel.
	if (local_map && inside(p,vec4(69.0,45.0,75.0,51.0))) colour=original;
	vec2 grid=abs(fract(p/24.0+0.5)-0.5)*24.0;
	float rule=1.0-smoothstep(0.0,max(fwidth(p).x,fwidth(p).y)*0.55,min(grid.x,grid.y));
	colour=mix(colour,colour*1.075,rule*0.4);
	COLOR=vec4(colour,1.0);
	// Source-selected position, size and colour, including black and blinking.
	if (inside(p,marker_0)) COLOR=marker_colour_0;
	if (inside(p,marker_1)) COLOR=marker_colour_1;
}
