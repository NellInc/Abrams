shader_type canvas_item;
render_mode unshaded;
uniform sampler2D office : filter_linear, repeat_disable;
uniform sampler2D portrait : filter_linear, repeat_disable;
uniform vec4 portrait_rect;
uniform float restored_height = 0.0;
void fragment() {
	vec2 p = UV*vec2(320.0,200.0);
	vec4 result = texture(TEXTURE,UV);
	if (p.y < restored_height) {
		result = texture(office,UV);
		vec2 q = (p-portrait_rect.xy)/portrait_rect.zw;
		if (all(greaterThanEqual(q,vec2(0.0))) && all(lessThan(q,vec2(1.0)))) {
			vec4 face = texture(portrait,q);
			result.rgb = mix(result.rgb,face.rgb,face.a);
		}
	}
	COLOR = result;
}
