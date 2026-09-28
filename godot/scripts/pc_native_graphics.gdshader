shader_type canvas_item;
render_mode unshaded;
uniform sampler2D plate_donors : filter_nearest, repeat_disable;
uniform sampler2D plate_originals : filter_nearest, repeat_disable;
uniform sampler2D plate_tags : filter_nearest, repeat_disable;
uniform sampler2D ui_mask : filter_nearest, repeat_disable;
uniform bool plates_enabled = false;
uniform int enabled_bits = 0;
void fragment() {
 vec4 original=texture(TEXTURE,UV);
 COLOR=original;
 if (plates_enabled) {
  int id=int(round(texture(plate_tags,UV).r*255.0));
  if (id>=1 && id<=8 && (enabled_bits & (1<<id))!=0 && texture(ui_mask,UV).r==1.0) {
   int slot=id==8?6:id;
   vec2 sample_uv=vec2(UV.x,(float(slot-1)+UV.y)/6.0);
   vec4 expected=texture(plate_originals,sample_uv);
   vec4 donor=texture(plate_donors,sample_uv);
   if (all(lessThan(abs(expected.rgb-original.rgb),vec3(0.001))) && donor.a>0.99) COLOR=vec4(donor.rgb,1.0);
  }
 }
}
