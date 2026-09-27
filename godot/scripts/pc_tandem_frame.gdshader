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

bool in_box(vec2 p, vec4 box) {
	return all(greaterThanEqual(p, box.xy)) && all(lessThan(p, box.zw));
}

// Renderer-owned vertical anchors align the generated material donors with
// the original silhouettes. They never change the camera or ownership mask.
float gunner_y(float y) {
	if (y < 13.0) return y*20.0/13.0;
	if (y < 110.0) return mix(20.0,94.0,(y-13.0)/97.0);
	if (y < 123.0) return mix(94.0,123.0,(y-110.0)/13.0);
	return y;
}
float driver_y(float y) {
	if (y < 14.0) return mix(0.0,9.0,y/14.0);
	if (y < 46.0) return mix(9.0,34.0,(y-14.0)/32.0);
	if (y < 77.0) return mix(34.0,66.0,(y-46.0)/31.0);
	if (y < 127.0) return mix(66.0,122.0,(y-77.0)/50.0);
	return mix(122.0,200.0,(y-127.0)/73.0);
}
float cupola_y(float y) {
	if (y < 85.0) return y*74.0/85.0;
	if (y < 114.0) return mix(74.0,101.0,(y-85.0)/29.0);
	if (y < 159.0) return mix(101.0,146.0,(y-114.0)/45.0);
	return mix(146.0,200.0,(y-159.0)/41.0);
}

void fragment() {
	vec2 pixel = UV * vec2(320.0, 200.0);
	bool inside = all(greaterThanEqual(pixel, camera_rect.xy))
		&& all(lessThan(pixel, camera_rect.xy + camera_rect.zw));
	vec4 result = texture(TEXTURE, UV);
	if (world_enabled && inside && texture(ui_mask, UV).r < 0.5) {
		result = texture(world_texture, (pixel - camera_rect.xy) / camera_rect.zw);
	}
	// Material-only pilot. The complete lower instrument panel stays original.
	// Camera geometry comes from the PC, regardless of the artwork's aperture.
	if (gunner_art_enabled && !inside && pixel.y < 123.0 &&
		int(round(texture(plate_mask, UV).r * 255.0)) == 1 && texture(ui_mask, UV).r > 0.5) {
		// Explicit texel centres avoid GPU float rounding choosing the previous
		// row when the piecewise anchor lands exactly on a donor-texel boundary.
		float donor_height = float(textureSize(gunner_art,0).y);
		float donor_row = floor(gunner_y(pixel.y)*donor_height/200.0+0.0001);
		vec4 art = texture(gunner_art, vec2(UV.x,(donor_row+0.5)/donor_height));
		result.rgb = mix(result.rgb, art.rgb, art.a);
	}
	// Other stations may have cockpit occluders inside their view rectangle.
	// Only proven original UI/plate pixels qualify, so scenery is never covered.
	int plate = int(round(texture(plate_mask, UV).r * 255.0));
	if (texture(ui_mask, UV).r > 0.5) {
		vec4 art = vec4(0.0);
		if (station_art_enabled.x > 0.5 && plate == 2 &&
			!in_box(pixel,vec4(15.0,62.0,161.0,160.0)) &&
			!in_box(pixel,vec4(0.0,166.0,170.0,200.0)) &&
			!in_box(pixel,vec4(190.0,66.0,305.0,195.0))) {
			art = texture(commander_art,UV);
		} else if (station_art_enabled.y > 0.5 && plate == 3) {
			art = texture(cupola_art,vec2(UV.x,cupola_y(pixel.y)/200.0));
		} else if (station_art_enabled.z > 0.5 && plate == 4 &&
			!in_box(pixel,vec4(53.0,187.0,267.0,200.0))) {
			art = texture(driver_art,vec2(UV.x,driver_y(pixel.y)/200.0));
		}
		result.rgb = mix(result.rgb,art.rgb,art.a);
	}
	if (driver_assembly_enabled && texture(ui_mask,UV).r > 0.5) {
		vec3 claim = round(texture(driver_assembly_mask,UV).rgb*255.0);
		if (claim.b == 255.0) {
			float offset = claim.r+claim.g*256.0-16384.0;
			vec4 art = texture(driver_art,vec2((pixel.x-offset)/320.0,driver_y(pixel.y)/200.0));
			result.rgb = mix(result.rgb,art.rgb,art.a);
		}
	}
	COLOR = result;
}
