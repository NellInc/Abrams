shader_type canvas_item;
render_mode unshaded;

uniform bool ega_upscaled = true;
uniform sampler2D ega_source : filter_nearest, repeat_disable;

vec4 ega_pixel(sampler2D source, vec2 p, vec2 dimensions) {
	return texture(source,(clamp(p,vec2(0.0),dimensions-1.0)+0.5)/dimensions);
}

vec4 ega_scale3x(sampler2D source, vec2 uv) {
	vec2 dimensions=vec2(textureSize(source,0));
	vec2 p=floor(uv*dimensions);
	vec2 part=floor(fract(uv*dimensions)*3.0);
	vec4 e=ega_pixel(source,p,dimensions);
	// Centre texels always retain the original, including isolated fine ink.
	if (part==vec2(1.0)) return e;
	vec4 b=ega_pixel(source,p+vec2(0.0,-1.0),dimensions);
	vec4 d=ega_pixel(source,p+vec2(-1.0,0.0),dimensions);
	vec4 f=ega_pixel(source,p+vec2(1.0,0.0),dimensions);
	vec4 h=ega_pixel(source,p+vec2(0.0,1.0),dimensions);
	if (b==h || d==f) return e;
	if (part==vec2(0.0,0.0)) return d==b ? d : e;
	if (part==vec2(2.0,0.0)) return b==f ? f : e;
	if (part==vec2(0.0,2.0)) return d==h ? d : e;
	if (part==vec2(2.0,2.0)) return h==f ? f : e;
	vec4 a=ega_pixel(source,p+vec2(-1.0,-1.0),dimensions);
	vec4 c=ega_pixel(source,p+vec2(1.0,-1.0),dimensions);
	vec4 g=ega_pixel(source,p+vec2(-1.0,1.0),dimensions);
	vec4 i=ega_pixel(source,p+vec2(1.0,1.0),dimensions);
	if (part.y==0.0) return ((d==b && e!=c) || (b==f && e!=a)) ? b : e;
	if (part.x==0.0) return ((d==b && e!=g) || (d==h && e!=a)) ? d : e;
	if (part.x==2.0) return ((b==f && e!=i) || (h==f && e!=c)) ? f : e;
	return ((d==h && e!=i) || (h==f && e!=g)) ? h : e;
}

void fragment() {
	COLOR=ega_scale3x(ega_source,UV);
}
