shader_type canvas_item;
render_mode unshaded;
uniform sampler2D original_coverage : filter_nearest, repeat_disable;
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	art.a *= texture(original_coverage, UV).r;
	COLOR = art;
}
