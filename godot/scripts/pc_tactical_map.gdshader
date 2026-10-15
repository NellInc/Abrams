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
	if (rgb==ivec3(170)) return vec3(0.82,0.79,0.63);
	if (rgb==ivec3(85)) return vec3(0.55,0.60,0.46);
	if (rgb==ivec3(85,85,255)) return vec3(0.16,0.35,0.43);
	if (rgb==ivec3(85,255,255)) return vec3(0.48,0.82,0.79);
	if (rgb==ivec3(170,0,0)) return vec3(0.88,0.39,0.28);
	if (rgb==ivec3(170,85,0)) return vec3(0.49,0.36,0.20);
	if (rgb==ivec3(0,170,0)) return vec3(0.19,0.29,0.23);
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
	// Quintic Hermite: same source-edge midpoints and endpoint tangents as the
	// cubic, with zero endpoint curvature where the next patch is straight.
	// The contour stays in this corner's half-cell; checker/multi-class vetoes
	// below still protect junctions, crossings and open one-cell corridors.
	float t2=t*t, t3=t2*t, t4=t3*t, t5=t4*t;
	float boundary=0.5+bend_x*(t-6.0*t3+8.0*t4-3.0*t5)
		+bend_y*(4.0*t3-7.0*t4+3.0*t5);
	float slope=bend_x*(1.0-18.0*t2+32.0*t3-15.0*t4)
		+bend_y*(12.0*t2-28.0*t3+15.0*t4);
	return (boundary-away.x-away.y)/sqrt(2.0*(1.0+slope*slope));
}
float print_hash(vec2 p) {
	vec3 q=fract(vec3(p.xyx)*0.1031);
	q+=dot(q,q.yzx+33.33);
	return fract((q.x+q.y)*q.z);
}
float print_grain(vec2 p) {
	vec2 at=floor(p), f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(print_hash(at),print_hash(at+vec2(1,0)),f.x),
		mix(print_hash(at+vec2(0,1)),print_hash(at+vec2(1,1)),f.x),f.y)-0.5;
}
vec3 material_ink(vec3 raw,float grain) {
	vec3 colour=cartography(raw);
	ivec3 rgb=ivec3(round(raw*255.0));
	// Static print texture belongs only to accepted source materials. It carries
	// no elevation, objects, flow direction or additional tactical information.
	if (rgb==ivec3(0,170,0)) colour+=grain*vec3(0.011,0.016,0.010);
	if (rgb==ivec3(170,85,0) || rgb==ivec3(85,43,0) || rgb==ivec3(128,85,43)) colour+=grain*vec3(0.018,0.015,0.009);
	if (rgb==ivec3(170)) colour=vec3(0.87,0.85,0.72);
	if (rgb==ivec3(85)) colour=vec3(0.58,0.63,0.50);
	if (rgb==ivec3(85,85,255)) colour=vec3(0.17,0.38,0.43)+grain*vec3(0.004,0.008,0.009);
	return colour;
}
vec3 edged(vec3 raw,float distance_to_edge,float width,float grain) {
	vec3 colour=material_ink(raw,grain);
	ivec3 rgb=ivec3(round(raw*255.0));
	float line=1.0-smoothstep(width*0.5,width*1.8,distance_to_edge);
	if (rgb==ivec3(170) || rgb==ivec3(85)) colour=mix(colour,colour*0.64,line*0.58);
	if (rgb==ivec3(85,85,255)) {
		// Material relief follows the existing bank distance, never a new contour.
		colour=mix(colour*0.86,colour,1.0-smoothstep(width*1.8,width*5.0,distance_to_edge));
		colour=mix(colour,vec3(0.47,0.70,0.68),line*0.52);
	}
	return colour;
}

void fragment() {
	vec2 p=UV*vec2(144.0,96.0);
	vec4 footprint=vec4(min(marker_0.xy,marker_1.xy),max(marker_0.zw,marker_1.zw));
	vec2 q=(p-(footprint.xy+footprint.zw)*0.5)/((footprint.zw-footprint.xy)*0.5);
	float radius=length(q);
	// Evaluate derivatives before varying branches, keeping marker edges
	// independent of neighbouring terrain shading in compact WebGL views.
	float marker_aa=max(fwidth(radius)*0.55,0.01);
	vec2 sample_position=UV*grid_size-0.5;
	vec2 at=floor(sample_position);
	vec2 f=fract(sample_position);
	vec4 a=cell(at), b=cell(at+vec2(1,0)), c=cell(at+vec2(0,1)), d=cell(at+vec2(1,1));
	// Explicit texel centres also remain exact when WebGL shares this texture
	// with the TextureRect's differently filtered default sampler.
	vec3 original=cartography(texture(map_pixels,(floor(p)+0.5)/vec2(144.0,96.0)).rgb);
	vec4 nearest_cell=cell(floor(UV*grid_size));
	vec3 nearest=nearest_cell.rgb;
	vec3 colour=cartography(nearest);
	float grain=print_grain(p*0.9);
	bool material_owned=nearest_cell.a>0.99;
	if (material_owned) colour=material_ink(nearest,grain);
	// Protected patches keep their nearest-cell footprint and styled palette.
	// Falling back to the full raw raster here reintroduced nearby stipple.
	bool safe=min(min(a.a,b.a),min(c.a,d.a))>0.99;
	bool contour=false;
	float field=0.0;
	vec3 positive=a.rgb, negative=a.rgb;
	if (safe) {
		vec3 other=!same(a.rgb,b.rgb)?b.rgb:(!same(a.rgb,c.rgb)?c.rgb:d.rgb);
		bool two=(same(b.rgb,a.rgb)||same(b.rgb,other)) && (same(c.rgb,a.rgb)||same(c.rgb,other)) && (same(d.rgb,a.rgb)||same(d.rgb,other));
		bool ba=same(b.rgb,a.rgb), ca=same(c.rgb,a.rgb), da=same(d.rgb,a.rgb);
		int count=1+int(ba)+int(ca)+int(da);
		bool diagonal=(count==2 && da);
		if (two && count<4 && !diagonal) {
			contour=true;
			positive=a.rgb;negative=other;
			if (count==1 || count==3) {
				vec2 corner=vec2(0);
				if (count==3) {
					positive=other;negative=a.rgb;
					corner=!ba?vec2(1,0):(!ca?vec2(0,1):vec2(1,1));
				}
				field=corner_field(f,at,corner,positive);
			} else field=ba?0.5-f.y:0.5-f.x;

		}
		// Diagonal/checker and multi-class junctions retain their source shape.
	}
	// Evaluate the field derivative after all lanes reconverge. Derivatives
	// inside the per-pixel contour branch have undefined GLSL behaviour.
	float field_width=fwidth(field);
	if (contour) {
		float aa=clamp(field_width*0.6,0.001,0.06);
		float line_width=clamp(field_width,0.006,0.075);
		colour=mix(edged(negative,abs(field),line_width,grain),edged(positive,abs(field),line_width,grain),smoothstep(-aa,aa,field));
	}
	// LOCAL has no terrain evidence beneath the player, so this stencil uses
	// exact current source texels rather than the cache's transparent sentinel.
	if (local_map && inside(p,vec4(69.0,45.0,75.0,51.0))) colour=original;
	vec2 grid=abs(fract(p/24.0+0.5)-0.5)*24.0;
	float rule=1.0-smoothstep(0.0,max(fwidth(p).x,fwidth(p).y)*(material_owned?0.85:0.55),min(grid.x,grid.y));
	colour=mix(colour,colour*(material_owned?1.12:1.075),rule*(material_owned?0.32:0.4));
	COLOR=vec4(colour,1.0);
	// Only the observed player primitive has a proven identity. Its modern
	// point stays within the original footprint. Unknown marks remain source ink.
	if (inside(p,footprint)) {
		if (same(marker_colour_0.rgb,marker_colour_1.rgb) && length(marker_colour_0.rgb)>0.001) {
			float point=1.0-smoothstep(0.86-marker_aa,0.99,radius);
			// The dark keyline belongs to the marker, never inferred terrain.
			COLOR=vec4(mix(vec3(0.025,0.042,0.032),marker_colour_0.rgb,point),1.0);
		} else {
			// Black/blinking and asymmetric source rows retain their exact writes.
			if (inside(p,marker_0)) COLOR=marker_colour_0;
			if (inside(p,marker_1)) COLOR=marker_colour_1;
		}
	}
}
