shader_type canvas_item;
render_mode unshaded;

uniform bool world_enabled = false;
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform vec4 camera_rect; // source-pixel x, y, width, height

void fragment() {
	vec2 pixel = UV * vec2(320.0, 200.0);
	bool inside = all(greaterThanEqual(pixel, camera_rect.xy))
		&& all(lessThan(pixel, camera_rect.xy + camera_rect.zw));
	vec4 result = texture(TEXTURE, UV);
	if (world_enabled && inside && texture(ui_mask, UV).r < 0.5) {
		result = texture(world_texture, (pixel - camera_rect.xy) / camera_rect.zw);
	}
	COLOR = result;
}
