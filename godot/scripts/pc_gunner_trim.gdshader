shader_type canvas_item;
render_mode unshaded;
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform sampler2D plate_mask : filter_nearest, repeat_disable;
uniform sampler2D world_texture : filter_nearest, repeat_disable;
uniform vec2 frame_size;
uniform bool corners_verified = false;
varying vec2 point;
void vertex() { point = VERTEX; }
bool box(vec2 p, vec4 r) {
	return all(greaterThanEqual(p,r.xy)) && all(lessThan(p,r.zw));
}
void fragment() {
	vec2 uv = point/frame_size;
	vec2 p = uv*vec2(320.0,200.0);
	bool camera = box(p,vec4(32.0,13.0,288.0,110.0));
	bool instrument = box(p,vec4(13.0,141.0,92.0,172.0)) ||
		box(p,vec4(13.0,178.0,92.0,192.0)) || box(p,vec4(128.0,138.0,191.0,181.0)) ||
		box(p,vec4(126.0,186.0,192.0,195.0)) || box(p,vec4(226.0,141.0,263.0,191.0)) ||
		box(p,vec4(271.0,141.0,308.0,191.0));
	bool allowed = !camera && !instrument && round(texture(plate_mask,uv).r*255.0)==1.0;
	// These 84 grey pixels are the original rounded aperture's four corners.
	// The CPU verifies the entire shape against this scanout before repainting.
	vec2 d = min(floor(p)-vec2(32.0,13.0),vec2(287.0,109.0)-floor(p));
	float run = d.y<1.0 ? 7.0 : (d.y<2.0 ? 5.0 : (d.y<3.0 ? 3.0 : (d.y<5.0 ? 2.0 : 1.0)));
	if (corners_verified && camera && d.y<7.0 && d.x<run) {
		allowed = true;
		// Antialias the rounded lip using the nearest ALREADY VISIBLE world
		// pixel. Never sample scenery concealed behind the original corner.
		vec2 scale = frame_size/vec2(320.0,200.0);
		float radius = 7.0*min(scale.x,scale.y);
		vec2 q = abs((p-vec2(160.0,61.5))*scale)-vec2(128.0,48.5)*scale+radius;
		float distance = length(max(q,0.0))+min(max(q.x,q.y),0.0)-radius;
		float coverage = 1.0-smoothstep(-0.5,0.5,distance);
		vec2 direction = vec2(p.x<160.0 ? 1.0 : -1.0,p.y<61.5 ? 1.0 : -1.0);
		float best = 1e8;
		vec2 visible = vec2(0.0);
		for (int y=0; y<8; y++) for (int x=0; x<8; x++) {
			vec2 candidate = floor(p)+vec2(float(x),float(y))*direction+0.5;
			float delta = dot((candidate-p)*scale,(candidate-p)*scale);
			if (delta<best && texture(ui_mask,candidate/vec2(320.0,200.0)).r<0.5) {
				best = delta;
				visible = candidate;
			}
		}
		if (best<1e8) COLOR.rgb = mix(COLOR.rgb,texture(world_texture,(visible-vec2(32.0,13.0))/vec2(256.0,97.0)).rgb,coverage);
	}
	if (p.y>=123.0 && (p.x<max(0.0,147.0-p.y) || p.x>320.0-max(0.0,147.0-p.y))) allowed = false;
	if (!allowed || texture(ui_mask,uv).r<0.5) COLOR.a = 0.0;
}
