shader_type canvas_item;
render_mode unshaded;

// Applied to the completed PC frame, after all source-verified typography,
// instruments, maps and reticles. Only pixels owned by the paired UI mask move.
uniform sampler2D hud_mask : filter_nearest, repeat_disable;
uniform sampler2D panel_mask : filter_nearest, repeat_disable;
uniform bool panels_verified = false;
uniform vec4 camera_bounds = vec4(0.0);
uniform bool camera_verified = false;
uniform bool map_verified = false;
uniform int wide_station = 0;
uniform int layout_count = 0;
uniform vec4 source_regions[8];
uniform vec4 destination_regions[8];

bool inside(vec2 p, vec4 box) {
	return all(greaterThanEqual(p, box.xy)) && all(lessThan(p, box.zw));
}

vec2 remap(vec2 p, vec4 destination, vec4 source) {
	vec2 t = (p - destination.xy) / (destination.zw - destination.xy);
	return mix(source.xy, source.zw, t) / vec2(320.0, 200.0);
}

bool live_cell(int plate, vec2 p) {
	if (plate == 1) return inside(p, vec4(11.0,139.0,94.0,174.0)) ||
		inside(p, vec4(11.0,176.0,94.0,194.0)) ||
		inside(p, vec4(124.0,136.0,194.0,197.0)) ||
		inside(p, vec4(224.0,139.0,265.0,193.0)) ||
		inside(p, vec4(269.0,139.0,310.0,193.0));
	if (plate == 2) return inside(p,vec4(15.0,62.0,161.0,160.0)) ||
		inside(p,vec4(14.0,176.0,94.0,194.0)) ||
		inside(p,vec4(102.0,176.0,163.0,194.0)) ||
		inside(p,vec4(207.0,81.0,289.0,187.0));
	if (plate == 5) return inside(p,vec4(18.0,37.0,105.0,100.0)) ||
		inside(p,vec4(123.0,37.0,305.0,100.0)) ||
		inside(p,vec4(9.0,107.0,313.0,184.0));
	return true; // Cupola and driver hull geometry remains source-shaped.
}

vec3 neutral_ink(float luma) {
	// A continuous dark-olive material ramp retains the source's light/dark
	// ordering. Black lettering on pale metal and pale lettering on black cells
	// therefore keep their distinct contrast and exact shapes.
	if (luma < 0.13) return mix(vec3(0.030, 0.055, 0.043), vec3(0.105, 0.156, 0.118), luma / 0.13);
	if (luma < 0.45) return mix(vec3(0.105, 0.156, 0.118), vec3(0.320, 0.398, 0.310), (luma - 0.13) / 0.32);
	if (luma < 0.77) return mix(vec3(0.320, 0.398, 0.310), vec3(0.665, 0.710, 0.625), (luma - 0.45) / 0.32);
	return mix(vec3(0.665, 0.710, 0.625), vec3(0.925, 0.939, 0.838), (luma - 0.77) / 0.23);
}

void fragment() {
	vec2 source_uv = UV;
	bool mapped = true;
	if (wide_station != 0) {
		// These rectangles are also the CPU-side proof that no live source pixel
		// is lost. Unknown overlays restore the complete source arrangement.
		mapped=false;
		for (int i=0; i<8; i++) {
			if (i>=layout_count) break;
			if (inside(UV,destination_regions[i])) {
				source_uv=remap(UV,destination_regions[i],source_regions[i]);
				mapped=true;
				break;
			}
		}
	}
	if (!mapped) {
		vec3 housing=mix(vec3(0.027,0.050,0.041),vec3(0.063,0.099,0.077),smoothstep(0.74,1.0,UV.y));
		float hairline=1.0-smoothstep(0.0,0.0015,abs(UV.y-0.962));
		COLOR=vec4(mix(housing,vec3(0.37,0.49,0.34),hairline*0.55),1.0);
	} else {
		vec4 source = texture(TEXTURE, source_uv);
		vec2 p = source_uv * vec2(320.0, 200.0);
		int plate = panels_verified ? int(round(texture(panel_mask, source_uv).r * 255.0)) : 0;
		bool map_area = map_verified && inside(p, vec4(16.0, 63.0, 160.0, 159.0));
		// Sight ink and bearing against moving scenery keep their original contrast.
		// A palette transform cannot safely infer the background under that ink.
		if (wide_station!=0 && p.y>=197.0 && (plate==wide_station || (wide_station==5 && plate==2))) {
			// Retain live border writes, without copying decorative hull fragments.
			COLOR=vec4(0.080,0.112,0.083,1.0);
		} else if ((!map_area && texture(hud_mask, source_uv).r < 0.5) ||
			(camera_verified && inside(p, camera_bounds))) {
			COLOR = source;
		} else {
			float luma = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
			float strongest = max(source.r, max(source.g, source.b));
			float weakest = min(source.r, min(source.g, source.b));
			float chroma = strongest - weakest;
			vec3 colour = neutral_ink(luma);
			if (chroma > 0.19) {
			// Existing warning, selected-weapon, friendly/status and information
			// channels remain different. Their meaning is never inferred or moved.
			float weight = clamp((chroma - 0.19) * 2.2, 0.0, 1.0);
			vec3 accent;
			// Light red (b ~0.33) has its own salmon ramp: on the red/brown ramp
			// it lands within ~0.08 RGB of brown and the pair becomes unreadable.
			// Blue-dominant ink keeps a lifted blue ramp instead of near-black teal.
			if (source.r > source.g * 1.30 && source.r > source.b * 1.23) {
				if (source.b > 0.2) accent = mix(vec3(0.62, 0.30, 0.24), vec3(1.0, 0.62, 0.50), luma);
				else accent = mix(vec3(0.31, 0.09, 0.07), vec3(0.96, 0.58, 0.36), luma);
			} else if (source.r > source.b * 1.35 && source.g > source.b * 1.25) {
				accent = mix(vec3(0.34, 0.24, 0.09), vec3(0.97, 0.78, 0.39), luma);
			} else if (source.g > source.r * 1.22 && source.g > source.b * 1.14) {
				accent = mix(vec3(0.06, 0.23, 0.12), vec3(0.70, 0.92, 0.62), luma);
			} else if (source.b > source.g * 1.5 && source.b > source.r * 1.5) {
				accent = mix(vec3(0.13, 0.22, 0.42), vec3(0.60, 0.74, 0.95), luma);
			} else {
				accent = mix(vec3(0.06, 0.20, 0.22), vec3(0.58, 0.83, 0.82), luma);
			}
				colour = mix(colour, accent, weight);
			}
			// The verified static cockpit plates become a purpose-made, quiet field
			// instrument housing. Every live window is excluded before replacement.
			if ((plate == 1 || plate == 2 || plate == 5) &&
				(plate == 5 || (camera_verified && !inside(p, camera_bounds))) &&
				!live_cell(plate, p)) {
				float lower = smoothstep(112.0, 145.0, p.y);
				vec3 upper = vec3(0.061, 0.099, 0.073);
				vec3 lower_panel = vec3(0.105, 0.150, 0.112);
				colour = mix(upper, lower_panel, lower);
				colour += vec3(0.020, 0.031, 0.019) * (1.0 - abs(source_uv.x - 0.5) * 1.2);
				// Structural joints echo the range's instrument strip rather than the
				// restored cockpit's rivets and checkerboard. No data marks are added.
				float joint = 0.0;
				if (plate == 1 && p.y > 123.0) {
					joint = 1.0 - smoothstep(0.0, 0.52, min(abs(p.x - 103.0), abs(p.x - 216.0)));
					joint = max(joint, 1.0 - smoothstep(0.0, 0.52, abs(p.y - 124.0)));
				} else if (plate == 2 && p.y > 48.0) {
					joint = 1.0 - smoothstep(0.0, 0.52, min(abs(p.x - 168.0), abs(p.y - 174.0)));
				}
				colour = mix(colour, vec3(0.27, 0.38, 0.29), joint * 0.62);
			}
			// Etched interface seam. It is confined to the UI side of the original
			// aperture and makes no claims about targets, ranges, bearing or damage.
			vec2 source_step = vec2(1.0 / 320.0, 1.0 / 200.0);
			float seam = map_area ? 0.0 : 1.0 - min(min(texture(hud_mask, source_uv + vec2(source_step.x, 0.0)).r,
				texture(hud_mask, source_uv - vec2(source_step.x, 0.0)).r),
				min(texture(hud_mask, source_uv + vec2(0.0, source_step.y)).r,
					texture(hud_mask, source_uv - vec2(0.0, source_step.y)).r));
			colour = mix(colour, vec3(0.72, 0.86, 0.62), clamp(seam * 0.30, 0.0, 0.30));
			COLOR = vec4(colour, source.a);
		}
	}
}
