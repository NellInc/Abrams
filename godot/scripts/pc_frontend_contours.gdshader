shader_type canvas_item;
render_mode unshaded;
uniform sampler2D surface_pixels : filter_nearest, repeat_disable;
uniform vec2 grid_size = vec2(300.0,166.0);
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

void fragment() {
	vec2 sample_position=UV*grid_size-0.5;
	vec2 at=floor(sample_position), f=fract(sample_position);
	vec4 a=cell(at),b=cell(at+vec2(1,0)),c=cell(at+vec2(0,1)),d=cell(at+vec2(1,1));
	vec3 colour=cell(floor(UV*grid_size)).rgb;
	bool safe=min(min(a.a,b.a),min(c.a,d.a))>0.99;
	bool contour=false;
	float field=0.0;
	vec3 positive=a.rgb,negative=a.rgb;
	if (safe) {
		vec3 other=!same(a.rgb,b.rgb)?b.rgb:(!same(a.rgb,c.rgb)?c.rgb:d.rgb);
		bool two=(same(b.rgb,a.rgb)||same(b.rgb,other)) && (same(c.rgb,a.rgb)||same(c.rgb,other)) && (same(d.rgb,a.rgb)||same(d.rgb,other));
		bool ba=same(b.rgb,a.rgb),ca=same(c.rgb,a.rgb),da=same(d.rgb,a.rgb);
		int count=1+int(ba)+int(ca)+int(da);
		if (two && count<4 && !(count==2 && da)) {
			contour=true;negative=other;
			if (count==1 || count==3) {
				vec2 corner=vec2(0);
				if (count==3) {positive=other;negative=a.rgb;corner=!ba?vec2(1,0):(!ca?vec2(0,1):vec2(1,1));}
				field=corner_field(f,at,corner,positive);
			} else field=ba?0.5-f.y:0.5-f.x;
		}
	}
	float aa=clamp(fwidth(field)*0.6,0.001,0.06);
	if (contour) colour=mix(negative,positive,smoothstep(-aa,aa,field));
	COLOR=vec4(colour,1.0);
}
