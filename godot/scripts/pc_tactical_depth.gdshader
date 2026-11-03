shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
#include "res://scripts/pc_tactical_light.gdshaderinc"
// The source ownership mesh in its original painter order: the last writer
// at each pixel is the same visible original object as in the ID mask. It
// writes its forward depth and light class (see pc_tactical_light.gdshaderinc).
// UV2.y: 0 static scenery (casts), 1 source terrain (casts and receives),
// 2 sprite or round command (neither; written as an all-zero texel),
// 3 actor polygon (casts only).
void fragment() {
    float light_class=round(UV2.y);
    vec3 bytes=vec3(0.0);
    if (light_class<1.5) bytes=light_depth_bytes(-VERTEX.z*64.0,light_class+1.0);
    else if (light_class>2.5) bytes=light_depth_bytes(-VERTEX.z*64.0,3.0);
    ALBEDO=light_output(bytes/255.0);
}
