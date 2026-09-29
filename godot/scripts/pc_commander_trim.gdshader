shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform sampler2D plate_mask : filter_nearest, repeat_disable;
uniform vec2 frame_size;
varying vec2 point;
void vertex() { point = VERTEX; }
bool box(vec2 p, vec4 r) {
	return all(greaterThanEqual(p,r.xy)) && all(lessThan(p,r.zw));
}
void fragment() {
	vec2 uv = point/frame_size;
	vec2 p = uv*vec2(320.0,200.0);
	bool live = box(p,vec4(15.0,62.0,161.0,160.0)) ||
		box(p,vec4(14.0,176.0,94.0,194.0)) || box(p,vec4(101.0,176.0,163.0,194.0)) ||
		box(p,vec4(214.0,81.0,280.0,130.0)) || box(p,vec4(212.0,131.0,282.0,143.0)) ||
		box(p,vec4(207.0,148.0,289.0,187.0));
	// Exact ownership even for antialiased geometry and incorrectly tagged
	// live cells. STATUS, unknown plates and scenery are never eligible.
	if (live || !box(p,vec4(187.0,63.0,308.0,193.0)) ||
		texture(ui_mask,uv).r!=1.0 || round(texture(plate_mask,uv).r*255.0)!=2.0) COLOR.a=0.0;
}
