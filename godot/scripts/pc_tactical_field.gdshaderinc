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

// Pinned original cupola barrel spans, registered to the authored metal contour.
// Material UVs only. The existing source masks and edge coverage remain authoritative.
vec2 field_cupola_barrel_uv(vec2 p) {
	vec3 profile[25] = vec3[](
		vec3(4.0,661.00,709.00),
		vec3(7.0,655.93,714.75),
		vec3(8.0,650.86,720.49),
		vec3(9.0,645.77,726.17),
		vec3(10.0,640.19,730.22),
		vec3(11.0,634.85,734.12),
		vec3(12.0,632.73,735.95),
		vec3(12.0,630.60,737.77),
		vec3(13.0,628.47,739.60),
		vec3(13.0,625.86,741.19),
		vec3(13.0,623.12,742.71),
		vec3(14.0,620.39,744.23),
		vec3(14.0,617.65,745.15),
		vec3(14.0,614.91,745.45),
		vec3(15.0,612.18,745.76),
		vec3(15.0,609.38,746.25),
		vec3(15.0,606.33,747.47),
		vec3(16.0,603.29,748.68),
		vec3(16.0,600.25,749.90),
		vec3(17.0,594.42,755.58),
		vec3(17.0,588.33,761.67),
		vec3(19.0,579.92,770.29),
		vec3(21.0,568.69,781.99),
		vec3(23.0,559.56,792.40),
		vec3(24.0,555.00,800.00)
	);
	float row=clamp(p.y-85.5,0.0,24.0);
	int i=int(floor(row));
	vec3 span=mix(profile[i],profile[min(i+1,24)],fract(row));
	float across=clamp(0.5+(p.x-120.0)/(2.0*span.x),0.0,1.0);
	float y=mix(540.0,676.0,row/24.0);
	return vec2(mix(span.y,span.z,across)/1672.0,y/941.0);
}

// Pinned original driver barrel spans, registered to the authored metal contour.
// Material UVs only. The existing source masks and edge coverage remain authoritative.
vec2 field_driver_barrel_uv(vec2 p) {
	vec3 profile[46] = vec3[](
		vec3(35.0,682.53,979.58),
		vec3(34.0,683.80,978.56),
		vec3(34.0,685.08,977.54),
		vec3(34.0,686.35,976.52),
		vec3(33.0,687.62,975.50),
		vec3(33.0,688.90,974.48),
		vec3(32.0,690.17,973.46),
		vec3(32.0,691.45,972.44),
		vec3(31.0,693.12,971.20),
		vec3(31.0,695.10,969.78),
		vec3(31.0,697.08,968.37),
		vec3(30.0,699.06,966.95),
		vec3(30.0,701.05,965.54),
		vec3(29.0,703.03,964.12),
		vec3(29.0,705.01,962.71),
		vec3(29.0,708.46,959.98),
		vec3(28.0,713.39,955.93),
		vec3(28.0,718.32,951.88),
		vec3(27.0,723.24,947.84),
		vec3(26.0,728.17,943.79),
		vec3(25.0,733.10,939.74),
		vec3(24.0,737.56,935.80),
		vec3(23.0,741.91,931.88),
		vec3(21.0,746.27,927.96),
		vec3(19.0,750.62,924.04),
		vec3(17.0,754.98,920.12),
		vec3(17.0,759.33,916.20),
		vec3(16.0,763.69,912.28),
		vec3(16.0,766.05,909.95),
		vec3(15.0,768.25,907.75),
		vec3(15.0,770.46,905.54),
		vec3(15.0,772.67,903.33),
		vec3(14.0,774.87,901.13),
		vec3(14.0,777.08,898.92),
		vec3(14.0,779.29,896.71),
		vec3(13.0,781.49,894.51),
		vec3(13.0,783.95,891.74),
		vec3(13.0,786.93,887.76),
		vec3(12.0,789.92,883.78),
		vec3(12.0,792.90,879.79),
		vec3(11.0,795.89,875.81),
		vec3(10.0,798.88,871.83),
		vec3(9.0,802.55,866.94),
		vec3(8.0,807.91,859.79),
		vec3(7.0,813.56,852.67),
		vec3(4.0,824.80,846.12)
	);
	float row=clamp(p.y-31.5,0.0,45.0);
	int i=int(floor(row));
	vec3 span=mix(profile[i],profile[min(i+1,45)],fract(row));
	float across=clamp(0.5+(p.x-161.0)/(2.0*span.x),0.0,1.0);
	float source_y=clamp(p.y,31.5,76.5);
	float y=source_y<46.0 ? mix(200.0,307.0,(source_y-18.0)/28.0) : mix(307.0,487.0,(source_y-46.0)/31.0);
	return vec2(mix(span.y,span.z,across)/1672.0,y/941.0);
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
	vec2 uv=vec2(x/1672.0,y/941.0);
	// Ease the cylinder into its mounting collar, without a straight UV splice.
	if(p.y>=28.5 && p.y<77.0 && abs(p.x-161.0)<36.5)
		uv=mix(uv,field_driver_barrel_uv(p),smoothstep(28.5,34.0,p.y));
	return uv;
}
vec2 field_cupola_uv(vec2 p) {
	if(p.y>=84.0 && p.y<110.0 && abs(p.x-120.0)<27.0)return field_cupola_barrel_uv(p);
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
