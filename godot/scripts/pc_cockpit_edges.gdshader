shader_type canvas_item;
render_mode unshaded;
#include "res://scripts/pc_tactical_field.gdshaderinc"
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform sampler2D plate_mask : filter_nearest, repeat_disable;
uniform sampler2D driver_mask : filter_nearest, repeat_disable;
uniform sampler2D donor : filter_nearest, repeat_disable;
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform bool driver_enabled=false;
uniform bool rail_verified=false;
uniform bool modern=false;
uniform bool tactical=false;
uniform bool tactical_interior=false;
uniform vec2 tactical_armour_shift=vec2(0.0);
#include "res://scripts/pc_tactical_dynamics.gdshaderinc"
uniform int station=3;
uniform vec2 frame_size;
uniform vec2 camera_size;
varying vec2 point;
varying float direction;
void vertex() { point=VERTEX;direction=COLOR.r>0.5 ? -1.0 : 1.0; }
bool camera(vec2 p) { return p.x>=0.0 && p.x<320.0 && p.y>=0.0 && p.y<camera_size.y; }
bool rail(vec2 p) {
	float end_x=p.y<112.0?183.0:(p.y<113.0?206.0:(p.y<114.0?230.0:(p.y<115.0?242.0:(p.y<116.0?264.0:286.0))));
	return rail_verified && station==3 && p.y>=111.0 && p.y<117.0 && p.x>=159.0 && p.x<end_x;
}
bool claimed(vec2 p) {
	if (!camera(p) || texture(ui_mask,p/vec2(320,200)).r<0.5) return false;
	return int(round(texture(plate_mask,p/vec2(320,200)).r*255.0))==station || rail(p) ||
		(station==4 && driver_enabled && texture(driver_mask,p/vec2(320,200)).b>0.5);
}
float driver_y(float y) {
	if(y<18.0)return y*1.5/18.0;
	if(y<46.0)return mix(1.5,28.0,(y-18.0)/28.0);
	if(y<77.0)return mix(28.0,60.0,(y-46.0)/31.0);
	if(y<127.0)return mix(60.0,112.0,(y-77.0)/50.0);
	if(y<187.0)return mix(112.0,172.0,(y-127.0)/60.0);
	return mix(172.0,192.0,(y-187.0)/13.0);
}
vec3 paint(vec4 art,vec2 p) {
	if(tactical_interior)return field_round_barrel(art.rgb,p,station);
	if(!modern)return art.rgb;
	float light=dot(art.rgb,vec3(.2126,.7152,.0722));
	vec3 colour=mix(art.rgb,light*vec3(.65,.70,.46),smoothstep(.10,.30,light)*(1.0-art.a));
	if(tactical)colour=mix(field_enamel(vec3(light),p,0.0),colour,art.a);
	return colour;
}
void fragment() {
	vec2 p=point;
	float signed_distance=(p.y-UV.y)*direction;
	float aa=max(fwidth(signed_distance)*0.5,0.001);
	float coverage=smoothstep(-aa,aa,signed_distance);
	vec2 pixel=floor(p)+0.5;
	bool source_ui=texture(ui_mask,pixel/vec2(320,200)).r>0.5;
	bool owned=claimed(pixel);
	vec2 visible=p;
	float visible_distance=1e8;
	vec2 art_pixel=pixel;
	float art_distance=owned?0.0:1e8;
	// Bounded edge fragments only. Never read world RGB under original UI.
	for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++) {
		vec2 q=pixel+vec2(float(x),float(y));
		float distance=dot(q-p,q-p);
		if(camera(q) && texture(ui_mask,q/vec2(320,200)).r<0.5 && distance<visible_distance) {
			visible_distance=distance;visible=q;
		}
		if(claimed(q) && distance<art_distance){art_distance=distance;art_pixel=q;}
	}
	if(!source_ui)visible=p;
	bool safe=camera(p) && (!source_ui || owned) && art_distance<1e8 && visible_distance<1e8;
	vec2 sample_p=tactical_armour_sample(p,float(station),ui_mask,plate_mask,driver_mask,driver_enabled,tactical ? tactical_armour_shift : vec2(0.0));
	if(station==4) {
		if(driver_enabled) {
			vec3 claim=round(texture(driver_mask,art_pixel/vec2(320,200)).rgb*255.0);
			if(claim.b==255.0)sample_p.x-=claim.r+claim.g*256.0-16384.0;
		}
		if(!tactical_interior)sample_p=sample_p.y<18.0?vec2(50.0,0.5):vec2(sample_p.x,driver_y(sample_p.y));
	} else if(rail(p) && p.x>=183.0)sample_p=vec2(190.0,119.0);
	vec2 uv=sample_p/vec2(320,200);
	if(tactical_interior)uv=station==4 ? field_driver_uv(sample_p) : field_cupola_uv(sample_p);
	vec3 art=paint(texture(donor,uv),sample_p);
	if(tactical_interior) {
		// A subpixel black ink line follows the existing barrel contour.
		// RGB only: coverage, geometry and all source/world ownership stay exact.
		float centre=station==3 ? 120.0 : 161.0;
		float radius=station==3 ? 25.5 : 37.5;
		float barrel=1.0-smoothstep(radius-1.5,radius,abs(sample_p.x-centre));
		bool end_profile=station==3 ? (UV.y>82.0 && UV.y<110.0) : (UV.y>30.0 && UV.y<80.0);
		float pixel_width=max(length(vec2(dFdx(signed_distance),dFdy(signed_distance))),0.001);
		float ink=1.0-smoothstep(0.15,0.95,signed_distance/pixel_width);
		if(end_profile)art=mix(art,vec3(0.0),ink*barrel);
	}
	vec3 world=texture(world_texture,visible/camera_size).rgb;
	COLOR=vec4(mix(world,art,coverage),safe?1.0:0.0);
}
