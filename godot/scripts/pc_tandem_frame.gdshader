shader_type canvas_item;
render_mode unshaded;

uniform bool world_enabled = false;
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform vec4 camera_rect; // source-pixel x, y, width, height
uniform bool gunner_art_enabled = false;
uniform sampler2D gunner_art : filter_nearest, repeat_disable;
uniform sampler2D plate_mask : filter_nearest, repeat_disable;

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
		vec4 art = texture(gunner_art, UV);
		result.rgb = mix(result.rgb, art.rgb, art.a);
	}
	COLOR = result;
}
