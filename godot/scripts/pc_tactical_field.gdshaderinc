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

// One source-width profile owns both donor registration and round shading.
float field_barrel_half_width(float y,bool upper) {
	if(upper) {
		float profile[25]=float[](4.0,7.0,8.0,9.0,10.0,11.0,12.0,12.0,13.0,13.0,13.0,14.0,14.0,14.0,15.0,15.0,15.0,16.0,16.0,17.0,17.0,19.0,21.0,23.0,24.0);
		float row=clamp(y-85.5,0.0,24.0);
		int i=int(floor(row));
		int j=min(i+1,24);
		float a=(profile[max(i-1,0)]+2.0*profile[i]+profile[min(i+1,24)])*0.25;
		float b=(profile[max(j-1,0)]+2.0*profile[j]+profile[min(j+1,24)])*0.25;
		return mix(a,b,fract(row));
	}
	float profile[46]=float[](35.0,34.0,34.0,34.0,33.0,33.0,32.0,32.0,31.0,31.0,31.0,30.0,30.0,29.0,29.0,29.0,28.0,28.0,27.0,26.0,25.0,24.0,23.0,21.0,19.0,17.0,17.0,16.0,16.0,15.0,15.0,15.0,14.0,14.0,14.0,13.0,13.0,13.0,12.0,12.0,11.0,10.0,9.0,8.0,7.0,4.0);
	float row=clamp(y-31.5,0.0,45.0);
	int i=int(floor(row));
	int j=min(i+1,45);
	float a=(profile[max(i-1,0)]+2.0*profile[i]+profile[min(i+1,45)])*0.25;
	float b=(profile[max(j-1,0)]+2.0*profile[j]+profile[min(j+1,45)])*0.25;
	return mix(a,b,fract(row));
}

// Continuous cylindrical normals inside the existing source-owned barrel.
// RGB only: neither this finish nor its curved collar grooves owns coverage.
vec3 field_round_barrel(vec3 original,vec2 p,int station) {
	bool upper=station==3;
	if(station!=3 && station!=4)return original;
	float start=upper ? 83.0 : 18.0;
	float end=upper ? 110.0 : 79.0;
	if(p.y<start || p.y>=end)return original;
	float half_width=field_barrel_half_width(p.y,upper);
	float flush=upper ? 1.0-smoothstep(92.0,98.0,p.y) : smoothstep(58.0,64.0,p.y);
	float across=(p.x-(upper ? 120.0 : 161.0))/max(half_width,1.0);
	if(abs(across)>=mix(1.06,1.4,flush))return original;
	float x=clamp(across,-1.0,1.0);
	float dome=sqrt(max(1.0-x*x,0.0));
	vec2 normal=vec2(x,dome);
	float diffuse=max(dot(normal,vec2(-0.48,0.877268)),0.0);
	float reflection=pow(max(dot(normal,vec2(-0.28,0.96)),0.0),18.0);
	vec3 enamel=upper ? vec3(0.55,0.57,0.425) : vec3(0.28,0.30,0.19);
	vec3 colour=enamel*(0.36+0.56*diffuse);
	colour+=reflection*(upper ? vec3(0.16,0.16,0.125) : vec3(0.08,0.08,0.06));
	// Grain follows the curved painted surface at a resolvable spatial scale.
	// Fine satin texture avoids the earlier oversampled, flat-looking finish.
	float grain_scale=min(24.0,half_width*0.75);
	vec2 paint_uv=vec2(asin(clamp(x,-0.995,0.995))*grain_scale,p.y*1.3);
	colour+=field_grain(paint_uv)*0.014+field_grain(p*0.23)*0.004;
	// Elliptical seams wrap around the cylinder instead of joining flat facets.
	float collar=upper ? 100.5+2.1*x*x : 56.0+3.4*dome;
	float groove=1.0-smoothstep(0.10,0.34,abs(p.y-collar));
	float lip=1.0-smoothstep(0.08,0.30,abs(p.y-collar+0.35));
	float seat=1.0-smoothstep(0.20,0.85,abs(p.y-collar));
	colour*=1.0-groove*0.36-seat*0.08;
	colour+=lip*(upper ? 0.045 : 0.026)*(0.35+0.65*diffuse)*vec3(1.0,1.0,0.8);
	if(!upper) {
		// Continue the same smooth metal into both existing mounting collars.
		// Their old donor seams were ragged; no new hardware or coverage is added.
		float mount=21.0+6.5*dome;
		float socket=34.0+6.4*dome;
		float seams=(1.0-smoothstep(0.09,0.32,abs(p.y-mount)))
			+(1.0-smoothstep(0.09,0.32,abs(p.y-socket)));
		float bevels=(1.0-smoothstep(0.08,0.30,abs(p.y-mount+0.40)))
			+(1.0-smoothstep(0.08,0.30,abs(p.y-socket+0.40)));
		colour*=1.0+0.14*(1.0-smoothstep(24.0,42.0,p.y));
		colour*=1.0-seams*0.34;
		colour+=bevels*(0.012+0.023*diffuse)*vec3(1.0,1.0,0.8);
	}
	// The underside emerges from a curved collar. A straight horizontal fade
	// would look like a cut even with a continuous cylindrical normal field.
	float blend=upper ? smoothstep(start,start+0.8,p.y)*(1.0-smoothstep(end-0.6,end,p.y))
		: smoothstep(17.5+1.6*dome,21.0+1.6*dome,p.y);
	blend*=1.0-smoothstep(0.94,1.06,abs(across));
	// End surfaces replace the donor completely, including its old bevel.
	return mix(original,clamp(colour,vec3(0.0),vec3(1.0)),mix(blend*0.96,1.0,flush));
}

// Pinned original cupola barrel spans, registered to the authored metal contour.
// Material UVs only. The existing source masks and edge coverage remain authoritative.
vec2 field_cupola_barrel_uv(vec2 p) {
	vec2 profile[25] = vec2[](
		vec2(661.00,709.00),
		vec2(655.93,714.75),
		vec2(650.86,720.49),
		vec2(645.77,726.17),
		vec2(640.19,730.22),
		vec2(634.85,734.12),
		vec2(632.73,735.95),
		vec2(630.60,737.77),
		vec2(628.47,739.60),
		vec2(625.86,741.19),
		vec2(623.12,742.71),
		vec2(620.39,744.23),
		vec2(617.65,745.15),
		vec2(614.91,745.45),
		vec2(612.18,745.76),
		vec2(609.38,746.25),
		vec2(606.33,747.47),
		vec2(603.29,748.68),
		vec2(600.25,749.90),
		vec2(594.42,755.58),
		vec2(588.33,761.67),
		vec2(579.92,770.29),
		vec2(568.69,781.99),
		vec2(559.56,792.40),
		vec2(555.00,800.00)
	);
	float row=clamp(p.y-85.5,0.0,24.0);
	int i=int(floor(row));
	vec2 span=mix(profile[i],profile[min(i+1,24)],fract(row));
	// Smooth the material width, not the source's stair-stepped silhouette.
	// Following every integer width used to pinch the longitudinal highlight.
	float half_width=field_barrel_half_width(p.y,true);
	float across=clamp(0.5+(p.x-120.0)/(2.0*half_width),0.025,0.975);
	float y=mix(533.0,688.62,row/24.0);
	return vec2(mix(span.x,span.y,across)/1672.0,y/941.0);
}

// Pinned original driver barrel spans, registered to the authored metal contour.
// Material UVs only. The existing source masks and edge coverage remain authoritative.
vec2 field_driver_barrel_uv(vec2 p) {
	vec2 profile[46] = vec2[](
		vec2(682.53,979.58),
		vec2(683.80,978.56),
		vec2(685.08,977.54),
		vec2(686.35,976.52),
		vec2(687.62,975.50),
		vec2(688.90,974.48),
		vec2(690.17,973.46),
		vec2(691.45,972.44),
		vec2(693.12,971.20),
		vec2(695.10,969.78),
		vec2(697.08,968.37),
		vec2(699.06,966.95),
		vec2(701.05,965.54),
		vec2(703.03,964.12),
		vec2(705.01,962.71),
		vec2(708.46,959.98),
		vec2(713.39,955.93),
		vec2(718.32,951.88),
		vec2(723.24,947.84),
		vec2(728.17,943.79),
		vec2(733.10,939.74),
		vec2(737.56,935.80),
		vec2(741.91,931.88),
		vec2(746.27,927.96),
		vec2(750.62,924.04),
		vec2(754.98,920.12),
		vec2(759.33,916.20),
		vec2(763.69,912.28),
		vec2(766.05,909.95),
		vec2(768.25,907.75),
		vec2(770.46,905.54),
		vec2(772.67,903.33),
		vec2(774.87,901.13),
		vec2(777.08,898.92),
		vec2(779.29,896.71),
		vec2(781.49,894.51),
		vec2(783.95,891.74),
		vec2(786.93,887.76),
		vec2(789.92,883.78),
		vec2(792.90,879.79),
		vec2(795.89,875.81),
		vec2(798.88,871.83),
		vec2(802.55,866.94),
		vec2(807.91,859.79),
		vec2(813.56,852.67),
		vec2(824.80,846.12)
	);
	float row=clamp(p.y-31.5,0.0,45.0);
	int i=int(floor(row));
	vec2 span=mix(profile[i],profile[min(i+1,45)],fract(row));
	float half_width=field_barrel_half_width(p.y,false);
	float across=clamp(0.5+(p.x-161.0)/(2.0*half_width),0.025,0.975);
	float source_y=clamp(p.y,31.5,76.5);
	// Stop just inside the painted end rim, before the donor's black cutout.
	float y=source_y<46.0 ? mix(200.0,307.0,(source_y-18.0)/28.0) : mix(307.0,479.0,(source_y-46.0)/31.0);
	return vec2(mix(span.x,span.y,across)/1672.0,y/941.0);
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
	vec2 uv=vec2(x/320.0,y/941.0);
	// Join the shoulder to the unchanged deck without a hard material splice.
	if(p.y>=84.0 && p.y<110.0 && abs(p.x-120.0)<27.0)
		uv=mix(field_cupola_barrel_uv(p),uv,smoothstep(108.0,110.0,p.y));
	return uv;
}
