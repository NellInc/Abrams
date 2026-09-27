shader_type canvas_item;
render_mode unshaded;

uniform bool world_enabled = false;
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform vec4 camera_rect; // source-pixel x, y, width, height
uniform bool gunner_art_enabled = false;
uniform sampler2D gunner_art : filter_nearest, repeat_disable;
uniform vec3 station_art_enabled = vec3(0.0);
uniform sampler2D commander_art : filter_nearest, repeat_disable;
uniform sampler2D cupola_art : filter_nearest, repeat_disable;
uniform sampler2D driver_art : filter_nearest, repeat_disable;
uniform bool driver_assembly_enabled = false;
uniform sampler2D driver_assembly_mask : filter_nearest, repeat_disable;
uniform sampler2D plate_mask : filter_nearest, repeat_disable;
uniform bool genesis_art = false;
uniform bool status_art_enabled = false;
uniform bool status_diagram_verified = false;

bool in_box(vec2 p, vec4 box) {
	return all(greaterThanEqual(p, box.xy)) && all(lessThan(p, box.zw));
}

// Renderer-owned vertical anchors align the generated material donors with
// the original silhouettes. They never change the camera or ownership mask.
float gunner_y(float y) {
	if (genesis_art) {
		if (y < 13.0) return y*15.0/13.0;
		if (y < 110.0) return mix(15.0,111.0,(y-13.0)/97.0);
		if (y < 123.0) return mix(111.0,118.0,(y-110.0)/13.0);
		return mix(118.0,200.0,(y-123.0)/77.0);
	}
	if (y < 13.0) return y*20.0/13.0;
	if (y < 110.0) return mix(20.0,94.0,(y-13.0)/97.0);
	if (y < 123.0) return mix(94.0,123.0,(y-110.0)/13.0);
	return y;
}
float driver_y(float y) {
	if (genesis_art) {
		if (y < 18.0) return y*1.5/18.0;
		if (y < 46.0) return mix(1.5,28.0,(y-18.0)/28.0);
		if (y < 77.0) return mix(28.0,60.0,(y-46.0)/31.0);
		if (y < 127.0) return mix(60.0,112.0,(y-77.0)/50.0);
		if (y < 187.0) return mix(112.0,172.0,(y-127.0)/60.0);
		return mix(172.0,192.0,(y-187.0)/13.0);
	}
	if (y < 14.0) return mix(0.0,9.0,y/14.0);
	if (y < 46.0) return mix(9.0,34.0,(y-14.0)/32.0);
	if (y < 77.0) return mix(34.0,66.0,(y-46.0)/31.0);
	if (y < 127.0) return mix(66.0,122.0,(y-77.0)/50.0);
	return mix(122.0,200.0,(y-127.0)/73.0);
}
float cupola_y(float y) {
	if (genesis_art) return y;
	if (y < 85.0) return y*74.0/85.0;
	if (y < 114.0) return mix(74.0,101.0,(y-85.0)/29.0);
	if (y < 159.0) return mix(101.0,146.0,(y-114.0)/45.0);
	return mix(146.0,200.0,(y-159.0)/41.0);
}

vec2 driver_donor(vec2 p) {
	if (genesis_art && p.y < 18.0) return vec2(50.0,0.5)/vec2(320.0,200.0);
	return vec2(p.x,driver_y(p.y))/vec2(320.0,200.0);
}

bool commander_instrument(vec2 p) {
	return in_box(p,vec4(15.0,62.0,161.0,160.0)) ||
		in_box(p,vec4(14.0,176.0,94.0,194.0)) ||
		in_box(p,vec4(102.0,176.0,163.0,194.0)) ||
		in_box(p,vec4(214.0,81.0,280.0,130.0)) ||
		in_box(p,vec4(212.0,131.0,282.0,143.0)) ||
		in_box(p,vec4(207.0,148.0,289.0,187.0));
}

vec2 commander_donor(vec2 p) {
	if (!genesis_art) return p/vec2(320.0,200.0);
	vec2 q = p;
	if (p.x >= 190.0 && p.x < 305.0 && p.y >= 66.0) {
		q.x = mix(188.0,308.0,(p.x-190.0)/115.0);
		if (p.y>=131.0 && p.y<143.0) {
			q.x = p.x<212.0 ? mix(188.0,196.0,(p.x-190.0)/22.0) : (p.x<282.0 ? mix(196.0,297.0,(p.x-212.0)/70.0) : mix(297.0,308.0,(p.x-282.0)/23.0));
		}
		if (p.y < 82.0) q.y = mix(68.5,80.5,(p.y-66.0)/16.0);
		else if (p.y < 128.0) q.y = mix(80.5,121.0,(p.y-82.0)/46.0);
		else if (p.y < 131.0) q.y = mix(121.0,127.5,(p.y-128.0)/3.0);
		else if (p.y < 143.0) q.y = mix(127.5,139.5,(p.y-131.0)/12.0);
		else if (p.y < 147.0) q.y = mix(139.5,146.5,(p.y-143.0)/4.0);
		else if (p.y < 188.0) q.y = mix(146.5,185.0,(p.y-147.0)/41.0);
		else q.y = mix(185.0,200.0,(p.y-188.0)/12.0);
	} else if (p.x < 170.0 && p.y >= 166.0) {
		q.y = p.y<176.0 ? mix(170.0,174.5,(p.y-166.0)/10.0) : (p.y<194.0 ? mix(174.5,192.0,(p.y-176.0)/18.0) : mix(192.0,200.0,(p.y-194.0)/6.0));
		if (p.x<14.0) q.x = p.x*13.0/14.0;
		else if (p.x<94.0) q.x = mix(13.0,91.0,(p.x-14.0)/80.0);
		else if (p.x<102.0) q.x = mix(91.0,101.0,(p.x-94.0)/8.0);
		else if (p.x<163.0) q.x = mix(101.0,162.0,(p.x-102.0)/61.0);
		else q.x = mix(162.0,170.0,(p.x-163.0)/7.0);
	}
	return q/vec2(320.0,200.0);
}

bool status_live_cell(vec2 p) {
	if (in_box(p,vec4(82.0,37.0,105.0,100.0))) return true;
	if (!status_diagram_verified && in_box(p,vec4(123.0,37.0,305.0,100.0))) return true;
	if (p.y>=108.0 && p.y<182.0 && mod(p.y-108.0,13.0)<9.0) {
		return (p.x>=9.0 && p.x<23.0) || (p.x>=32.0 && p.x<156.0) ||
			(p.x>=164.0 && p.x<289.0) || (p.x>=298.0 && p.x<313.0);
	}
	return false;
}

vec2 status_donor(vec2 p) {
	vec2 q = p;
	if (p.y<20.0 || p.x<9.0 || p.x>=313.0) return vec2(0.002,0.002);
	if (p.y>=105.0) return vec2(0.5,0.975);
	if (p.y<105.0) {
		q.y = mix(2.0,86.0,(p.y-20.0)/85.0);
		if (p.y>=32.0 && (p.x<11.0 || p.x>=311.0 || p.y>=103.0)) {
			q = vec2(10.0,5.0); // Genesis green outer frame
		} else if (in_box(p,vec4(123.0,37.0,305.0,100.0))) {
			q.x = mix(119.0,300.0,(p.x-123.0)/182.0);
			q.y = mix(16.0,80.5,(p.y-37.0)/63.0);
		} else if (in_box(p,vec4(18.0,37.0,105.0,100.0))) {
			q.x = mix(20.0,108.0,(p.x-18.0)/87.0);
			q.y = mix(16.0,80.5,(p.y-37.0)/63.0);
		} else if (p.y>=32.0) {
			q = vec2(110.0,40.0); // unmarked black spacing, no duplicate labels
		}
	}
	// Label and lamp cells remain source-owned. Only the unmarked grey frame
	// between them samples this donor, avoiding invented equipment states.
	return q/vec2(320.0,200.0);
}

bool gunner_instrument(vec2 p) {
	return in_box(p,vec4(11.0,139.0,94.0,174.0)) ||
		in_box(p,vec4(11.0,176.0,94.0,194.0)) ||
		in_box(p,vec4(126.0,136.0,193.0,183.0)) ||
		in_box(p,vec4(124.0,184.0,194.0,197.0)) ||
		in_box(p,vec4(224.0,139.0,265.0,193.0)) ||
		in_box(p,vec4(269.0,139.0,310.0,193.0));
}

// Register each illustrated component separately. A whole-image stretch would
// leave the donor's empty display frames behind the original live instruments.
vec2 gunner_donor(vec2 p) {
	if (!genesis_art || p.y < 123.0) return vec2(p.x,gunner_y(p.y));
	vec2 q = p;
	if (p.x < 103.0) {
		q.x = p.x < 11.0 ? p.x*5.5/11.0 : (p.x < 94.0 ? mix(5.5,101.0,(p.x-11.0)/83.0) : mix(101.0,104.0,(p.x-94.0)/9.0));
		if (p.y < 139.0) q.y = mix(118.2,136.4,(p.y-123.0)/16.0);
		else if (p.y < 174.0) q.y = mix(136.4,166.7,(p.y-139.0)/35.0);
		else if (p.y < 176.0) q.y = mix(166.7,170.4,(p.y-174.0)/2.0);
		else if (p.y < 194.0) q.y = mix(170.4,191.6,(p.y-176.0)/18.0);
		else q.y = mix(191.6,200.0,(p.y-194.0)/6.0);
	} else if (p.x < 216.0) {
		float l = p.y < 184.0 ? 125.0 : 110.0;
		float r = p.y < 184.0 ? 195.0 : 210.0;
		q.x = p.x < 124.0 ? mix(104.0,l,(p.x-103.0)/21.0) : (p.x < 194.0 ? mix(l,r,(p.x-124.0)/70.0) : mix(r,216.0,(p.x-194.0)/22.0));
		if (p.y < 136.0) q.y = mix(118.2,130.3,(p.y-123.0)/13.0);
		else if (p.y < 183.0) q.y = mix(130.3,174.6,(p.y-136.0)/47.0);
		else if (p.y < 184.0) q.y = mix(174.6,179.5,p.y-183.0);
		else if (p.y < 197.0) q.y = mix(179.5,193.3,(p.y-184.0)/13.0);
		else q.y = mix(193.3,200.0,(p.y-197.0)/3.0);
	} else {
		// The six source-owned instrument rectangles retain exact PC positions;
		// use only the donor's unmarked silver strip for the surrounding chassis.
		q.x = mix(228.0,280.0,(p.x-216.0)/104.0);
		q.y = mix(120.0,127.0,(p.y-123.0)/77.0);
	}
	return q;
}

void fragment() {
	vec2 pixel = UV * vec2(320.0, 200.0);
	bool inside = all(greaterThanEqual(pixel, camera_rect.xy))
		&& all(lessThan(pixel, camera_rect.xy + camera_rect.zw));
	vec4 result = texture(TEXTURE, UV);
	if (world_enabled && inside && texture(ui_mask, UV).r < 0.5) {
		result = texture(world_texture, (pixel - camera_rect.xy) / camera_rect.zw);
	}
	// Legacy pilot retains the lower panel; Genesis art protects live cells.
	// Camera geometry comes from the PC, regardless of the artwork's aperture.
	if (gunner_art_enabled && !inside && (pixel.y < 123.0 || (genesis_art && !gunner_instrument(pixel))) &&
		int(round(texture(plate_mask, UV).r * 255.0)) == 1 && texture(ui_mask, UV).r > 0.5) {
		// Explicit texel centres avoid GPU float rounding choosing the previous
		// row when the piecewise anchor lands exactly on a donor-texel boundary.
		float donor_height = float(textureSize(gunner_art,0).y);
		vec2 donor = gunner_donor(pixel);
		float donor_row = floor(donor.y*donor_height/200.0+0.0001);
		vec4 art = texture(gunner_art, vec2(donor.x/320.0,(donor_row+0.5)/donor_height));
		result.rgb = mix(result.rgb, art.rgb, art.a);
	}
	// Other stations may have cockpit occluders inside their view rectangle.
	// Only proven original UI/plate pixels qualify, so scenery is never covered.
	int plate = int(round(texture(plate_mask, UV).r * 255.0));
	if (texture(ui_mask, UV).r > 0.5) {
		vec4 art = vec4(0.0);
		bool commander_protected = genesis_art ? commander_instrument(pixel) :
			(in_box(pixel,vec4(15.0,62.0,161.0,160.0)) || in_box(pixel,vec4(0.0,166.0,170.0,200.0)) || in_box(pixel,vec4(190.0,66.0,305.0,195.0)));
		if (station_art_enabled.x > 0.5 && plate == 2 && !commander_protected) {
			vec2 donor = commander_donor(pixel);
			if (genesis_art) donor.y *= 0.5;
			art = texture(commander_art,donor);
		} else if (station_art_enabled.y > 0.5 && plate == 3) {
			art = texture(cupola_art,vec2(UV.x,cupola_y(pixel.y)/200.0));
		} else if (station_art_enabled.z > 0.5 && plate == 4 &&
			!in_box(pixel,vec4(53.0,187.0,267.0,200.0))) {
			art = texture(driver_art,driver_donor(pixel));
		} else if (status_art_enabled && plate==5 && !status_live_cell(pixel)) {
			vec2 donor = status_donor(pixel);
			donor.y = 0.5+donor.y*0.5;
			art = texture(commander_art,donor);
		}
		result.rgb = mix(result.rgb,art.rgb,art.a);
	}
	if (driver_assembly_enabled && texture(ui_mask,UV).r > 0.5) {
		vec3 claim = round(texture(driver_assembly_mask,UV).rgb*255.0);
		if (claim.b == 255.0) {
			float offset = claim.r+claim.g*256.0-16384.0;
			vec4 art = texture(driver_art,driver_donor(vec2(pixel.x-offset,pixel.y)));
			result.rgb = mix(result.rgb,art.rgb,art.a);
		}
	}
	COLOR = result;
}
