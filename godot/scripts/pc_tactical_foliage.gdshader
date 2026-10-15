shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never, fog_disabled;
uniform sampler2D source_ownership : filter_nearest, repeat_disable;
uniform sampler2D allowed_ground : filter_nearest, repeat_disable;
uniform float owner_count;
uniform vec2 source_origin;
uniform vec2 source_dimensions;
uniform vec2 source_center;
uniform float source_focal;
uniform mat3 camera_to_local;
uniform vec3 horizon;
uniform float source_eye_height = 0.0;
varying vec4 plant;
varying float light;
varying float material_kind;
varying float tone;
varying float distance_fade;
varying float plant_height;
varying vec3 leaf_normal;
varying vec3 leaf_eye;
varying vec2 material_point;
#include "res://scripts/pc_tactical_materials.gdshaderinc"

// Resolution-aware sheen only. Leaf colour, broad transmission, stems and
// contact opacity remain independent of this bounded pixel footprint.
float tactical_leaf_highlight(float pixel) {
    return 1.0-smoothstep(0.02,0.09,pixel);
}

void vertex() {
    // Face-local dominant planes keep leaf proportions on roof and side facets.
    float axis=mod(round(UV2.x*16.0),8.0);
    material_point=axis<0.5 ? VERTEX.zy : axis<1.5 ? VERTEX.xz : VERTEX.xy;
    plant=INSTANCE_CUSTOM;
    material_kind=UV2.x;
    material_kind=floor(material_kind*2.0)/2.0;
    tone=UV2.y;
    plant_height=clamp(VERTEX.y/(plant.w>0.5 ? 11.0 : 12.5),0.0,1.0);
    // Undo the captured camera once so the sun does not rotate with the optic.
    // Plant proportions vary independently, so normals need inverse scale.
    vec3 view_normal=MODEL_NORMAL_MATRIX*NORMAL;
    vec3 local_normal=camera_to_local*vec3(view_normal.x,-view_normal.z,view_normal.y);
    local_normal=normalize(vec3(local_normal.x,-local_normal.y,local_normal.z));
    leaf_normal=local_normal;
    light=0.62+0.38*max(dot(local_normal,normalize(vec3(-0.58,0.34,0.74))),0.0);
    vec3 view_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    vec3 local_eye=camera_to_local*vec3(-view_position.x,view_position.z,-view_position.y);
    leaf_eye=vec3(local_eye.x,-local_eye.y,local_eye.z);
    distance_fade=smoothstep(10.0,46.0,length(view_position));
}

bool grass_at(vec2 uv) {
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThanEqual(uv,vec2(1.0)))) return false;
    vec3 owner=texture(source_ownership,uv).rgb;
    float id=floor(owner.r*255.0+0.5)+256.0*floor(owner.g*255.0+0.5);
    if (id>=owner_count || texture(allowed_ground,vec2((id+0.5)/owner_count,0.5)).r<0.5) return false;
    vec2 pixel=source_origin+uv*source_dimensions;
    vec3 ray=camera_to_local*vec3(pixel.x-source_center.x,source_focal,source_center.y-pixel.y);
    return ray.z < -0.001 && dot(horizon,vec3(pixel,1.0))>0.5;
}

void fragment() {
    vec2 detail_uv=material_point/(material_kind>0.25 ? 12.0 : plant.w>0.5 ? 10.0 : 14.0);
    vec2 detail_dx=dFdx(detail_uv);vec2 detail_dy=dFdy(detail_uv);
    vec3 n=normalize(leaf_normal);
    vec3 eye=normalize(leaf_eye);
    float light_pixel=max(max(length(dFdx(n)),length(dFdy(n))),max(length(dFdx(eye)),length(dFdy(eye))));
    light_pixel=max(light_pixel,max(length(detail_dx),length(detail_dy)));
    float highlight_detail=tactical_leaf_highlight(light_pixel);
    // Both rooted position and covered pixel must be observed flat grass.
    // Original actors, trees, effects, roads and banks always remain on top.
    if (!grass_at(plant.xy) || !grass_at(SCREEN_UV)) discard;
    vec3 leaf=mix(vec3(0.20,0.30,0.12),vec3(0.40,0.48,0.22),plant.z);
    // Root-to-tip variation follows the mesh, not the screen or a noise clock.
    // Broad gradients survive distance filtering without stippled leaf shimmer.
    leaf*=mix(vec3(0.78,0.86,0.76),vec3(1.08,1.06,0.94),plant_height);
    if (plant.w>0.5) leaf=mix(leaf,vec3(0.49,0.52,0.30),smoothstep(0.35,0.95,plant_height)*0.38);
    // Existing instance seed supplies a small, camera-stable hue difference.
    // Broad colour only: crown silhouette and source-admitted coverage stay.
    float crown_variation=(plant.z-0.5)*(1.0-distance_fade*0.55);
    leaf*=vec3(1.0+crown_variation*0.075,1.0+crown_variation*0.025,1.0-crown_variation*0.045);
    if (material_kind>0.25 && material_kind<0.75) leaf=mix(vec3(0.25,0.21,0.14),vec3(0.40,0.33,0.21),plant_height);
    if (material_kind<0.75) {
        // The lowest broad leaf/stem band shares the soil's subdued loam hue.
        // Keep the preceding footprint and every alpha expression exact.
        float basal=(1.0-smoothstep(0.03,0.38,plant_height))*(1.0-distance_fade*0.45);
        leaf*=mix(vec3(1.0),vec3(0.86,0.84,0.80),basal);
        leaf=mix(leaf,leaf*vec3(1.045,0.985,0.91),basal*0.35);
        // Grasses read as sparse dry-green blades beside the quieter field.
        // Scrub crowns retain their greener material identity.
        if (plant.w>0.5 && material_kind<0.25) leaf*=vec3(1.025,0.965,0.95);
    }
    if (material_kind<0.25) {
        // Interpolate the rounded normals, then relight per fragment. No new
        // geometry or texture is needed to soften the existing canopy facets.
        vec3 sun=normalize(vec3(-0.58,0.34,0.74));
        float sky=clamp(n.z*0.5+0.5,0.0,1.0);
        vec3 fill=mix(vec3(0.49,0.52,0.39),vec3(0.68,0.77,0.82),sky);
        float direct=max(dot(n,sun),0.0);
        vec3 lit=leaf*(fill+vec3(0.35,0.34,0.28)*direct);
        // Broad highlights and thin-leaf transmission disappear gradually at
        // range. They carry no noise, clock, alpha change or new visibility.
        float detail=1.0-distance_fade;
        float crown=smoothstep(0.14,0.80,plant_height);
        float back=pow(max(dot(-eye,sun),0.0),3.0);
        lit+=leaf*vec3(0.32,0.27,0.12)*back*crown*detail;
        // sun+eye is zero when exactly backlit: a bounded denominator keeps
        // the half vector finite even there.
        vec3 half_sum=sun+eye;
        vec3 half_light=half_sum/max(length(half_sum),0.001);
        float sheen=pow(max(dot(n,half_light),0.0),12.0);
        lit+=vec3(0.050,0.055,0.035)*sheen*direct*crown*detail*highlight_detail;
        // Broad, bounded fill uses existing normals and distance filtering.
        // Root colour stays subdued; plant height, placement and alpha stay.
        float fill_strength=mix(0.45,0.70,plant_height)*(1.0-distance_fade);
        leaf=lit*tone*tactical_environment_tint(n,fill_strength);
    } else {
        // Stems and contact footprints retain their established materials.
        leaf*=light*tone;
        if(material_kind<0.75)leaf*=tactical_environment_tint(n,0.40*(1.0-distance_fade));
    }
    if(tactical_realism_ready && material_kind<0.75)leaf*=realism_gain(detail_uv,detail_dx,detail_dy,material_kind>0.25 ? 4.0 : plant.w>0.5 ? 8.0 : 9.0,length(leaf_eye));
    // One restrained woodland-green transition for crowns and stems. Existing
    // aerial colour below remains the sole directional atmospheric response.
    leaf=mix(leaf,vec3(0.39,0.435,0.315),distance_fade*0.28);
    float alpha=1.0;
    if (material_kind>0.75) {
        // A soft material footprint, never a new shadow/depth viewport. It is
        // clipped by exactly the same verified grass pixels as the plant.
        float radius=plant.w>0.5 ? 0.20 : 1.0;
        vec2 q=UV/vec2(radius,radius*0.72);
        alpha=(1.0-smoothstep(0.25,1.0,length(q)))*0.26;
        leaf=vec3(0.075,0.105,0.052);
    }
    leaf=OUTPUT_IS_SRGB ? leaf : pow(leaf,vec3(2.2));
    // MODEL units are source units / 64. Leaves and stems share the original
    // ground's observed eye height; contact opacity/material stays unchanged.
    if(material_kind<0.75 && source_eye_height>0.0)leaf=tactical_air_colour(leaf,-leaf_eye*64.0,source_eye_height,0.10);
    ALBEDO=leaf;
    ALPHA=alpha;
}
