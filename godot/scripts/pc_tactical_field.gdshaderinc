// Quiet olive enamel, shared by the HUD housing and source-owned crew art.
// Spatial only: no time input, shimmer, new data or changed coverage.
float field_hash(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float field_grain(vec2 p) {
	vec2 cell=floor(p);
	vec2 f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(field_hash(cell),field_hash(cell+vec2(1,0)),f.x),
		mix(field_hash(cell+vec2(0,1)),field_hash(cell+vec2(1,1)),f.x),f.y)-0.5;
}
vec3 field_housing(vec2 p) {
	float crown=1.0-smoothstep(0.0,0.85,p.y);
	float grain=field_grain(p*vec2(780,440))*0.012;
	float cast=field_grain(p*vec2(37,21))*0.008;
	return vec3(0.105,0.130,0.093)+crown*vec3(0.055,0.059,0.042)+grain+cast;
}
vec3 field_enamel(vec3 original,vec2 p,float hardware) {
	float light=dot(original,vec3(0.2126,0.7152,0.0722));
	// Keep the donor's illustrated facets, seams and fastening geometry.
	float grain=field_grain(p*5.0)*0.016+field_grain(p*0.36)*0.010;
	vec3 coat=vec3(0.036,0.047,0.031)+pow(max(light,0.0),1.12)*vec3(0.53,0.58,0.39);
	coat+=grain*smoothstep(0.08,0.35,light);
	return mix(coat,original,clamp(hardware,0.0,1.0));
}

// Concept texture registration only. The paired source masks still own every
// fragment, including the signed moving driver assembly and its edge samples.
vec2 field_driver_uv(vec2 p) {
	float y;
	if(p.y<18.0)y=mix(121.0,200.0,p.y/18.0);
	else if(p.y<46.0)y=mix(200.0,307.0,(p.y-18.0)/28.0);
	else if(p.y<77.0)y=mix(307.0,487.0,(p.y-46.0)/31.0);
	else if(p.y<127.0)y=mix(487.0,722.0,(p.y-77.0)/50.0);
	else if(p.y<136.0)y=mix(722.0,762.0,(p.y-127.0)/9.0);
	else if(p.y<187.0)y=mix(762.0,803.0,(p.y-136.0)/51.0);
	else y=mix(803.0,894.0,(p.y-187.0)/13.0);
	float x=p.x*1672.0/320.0;
	if(p.y>=127.0) {
		if(p.x<80.0)x=mix(0.0,450.0,p.x/80.0);
		else if(p.x<240.0)x=mix(450.0,1222.0,(p.x-80.0)/160.0);
		else x=mix(1222.0,1672.0,(p.x-240.0)/80.0);
	}
	return vec2(x/1672.0,y/941.0);
}
vec2 field_cupola_uv(vec2 p) {
	float x;
	if(p.x<59.0)x=mix(0.0,69.0,p.x/59.0);
	else if(p.x<183.0)x=mix(69.0,191.0,(p.x-59.0)/124.0);
	else x=mix(191.0,320.0,(p.x-183.0)/137.0);
	x=mix(130.7+(x-130.7)*0.82+0.6,x,smoothstep(105.0,110.0,p.y));
	float y;
	if(p.y<85.0)y=mix(0.0,530.0,p.y/85.0);
	else if(p.y<114.0)y=mix(530.0,714.0,(p.y-85.0)/29.0);
	else if(p.y<146.0)y=mix(714.0,843.0,(p.y-114.0)/32.0);
	else y=mix(843.0,941.0,(p.y-146.0)/54.0);
	return vec2(x/320.0,y/941.0);
}
