shader_type canvas_item;
render_mode unshaded;
uniform sampler2D office : filter_linear, repeat_disable;
uniform sampler2D portrait : filter_linear_mipmap, repeat_disable; // premultiplied alpha
uniform vec4 portrait_rect;
uniform float restored_height = 0.0;
uniform sampler2D motor_pool : filter_linear, repeat_disable;
uniform sampler2D motor_mask : filter_nearest, repeat_disable;
uniform bool motor_enabled = false;
uniform bool scene_enabled = false;
uniform sampler2D scene_mask : filter_nearest, repeat_disable;
void fragment() {
	vec2 p = UV*vec2(320.0,200.0);
	vec4 result = texture(TEXTURE,UV);
	// Mip selection needs implicit derivatives, which are undefined inside the
	// per-fragment branches below; sample in uniform flow (repeat_disable clamps).
	vec2 q = (p-portrait_rect.xy)/max(portrait_rect.zw,vec2(1e-6));
	vec4 face = texture(portrait,q);
	if (scene_enabled && texture(scene_mask,UV).r < 0.5) result.a = 0.0;
	if (motor_enabled) {
		result=int(round(texture(motor_mask,UV).r*255.0))==8 ? texture(motor_pool,UV) : vec4(0.0);
	}
	if (p.y < restored_height) {
		result = texture(office,UV);
		if (all(greaterThanEqual(q,vec2(0.0))) && all(lessThan(q,vec2(1.0)))) {
			result.rgb = face.rgb+result.rgb*(1.0-face.a);
		}
	}
	COLOR = result;
}
