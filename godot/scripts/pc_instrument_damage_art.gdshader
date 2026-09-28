shader_type canvas_item;
uniform sampler2D changed_pixels : filter_linear, repeat_disable;
void fragment() {
	vec4 color = texture(TEXTURE, UV);
	// Original Genesis changed-pixel support removes unrelated neighbouring
	// plate contours. Linear coverage smooths its source-sized boundary.
	color.a *= smoothstep(0.15,0.8,texture(changed_pixels,UV).r);
	COLOR = color;
}
