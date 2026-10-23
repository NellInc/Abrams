shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_opaque,fog_disabled;

// Bespoke UV materials. OpenGL tangent normals are baked against the exact
// flat-shaded game mesh; UV V is flipped to the PNG's top-left convention.
uniform sampler2D tactical_vehicle_albedo: source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tactical_vehicle_normal: filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D tactical_vehicle_orm: filter_linear_mipmap_anisotropic, repeat_disable;
varying float source_owner;
varying vec3 original_view;
varying float authored_height;
uniform sampler2D source_ownership: filter_nearest, repeat_disable;
uniform mat3 camera_to_local;
uniform vec3 world_origin;
uniform bool camera_basis_ready=false;
uniform float instance_owner=0.0;
uniform bool strict_source_coverage=false;
uniform bool source_piecewise=false;
uniform bool source_group=false;
uniform bool source_round=false;
uniform vec2 source_round_center;
uniform vec2 source_round_radii;
uniform vec3 source_projection;
uniform mat3 source_group_basis;
uniform vec3 source_group_origin;
uniform vec3 source_camera;
uniform vec3 source_cu;
uniform vec3 source_cv;
uniform vec3 source_cn;
uniform vec3 source_anchors[16];

vec3 tactical_daylight(vec3 base,vec3 normal,vec3 eye,float sheen) {
    float sun=max(dot(normal,normalize(vec3(-0.58,0.34,0.74))),0.0);
    float sky=clamp(normal.z*0.5+0.5,0.0,1.0);
    vec3 tint=mix(vec3(0.96,1.01,1.045),vec3(1.035,1.02,0.955),sun);
    // Preserve the sunlit value while giving shaded armour and cloth folds
    // enough separation to reveal the authored bevels and baked normals.
    tint*=0.72+sky*0.18+sun*0.28;
    return base*(OUTPUT_IS_SRGB ? tint : pow(tint,vec3(2.2)));
}

vec3 tactical_vehicle_response(vec2 uv,vec2 dx,vec2 dy,vec3 face,vec3 eye,vec3 px,vec3 py) {
    vec3 base=textureGrad(tactical_vehicle_albedo,uv,dx,dy).rgb;
    vec3 map=textureGrad(tactical_vehicle_normal,uv,dx,dy).rgb*2.0-1.0;
    vec3 orm=textureGrad(tactical_vehicle_orm,uv,dx,dy).rgb;
    float det=dx.x*dy.y-dx.y*dy.x;
    vec3 normal=face;
    float area=length(dx)*length(dy);
    if(area>0.000000000001 && abs(det)>area*0.0001) {
        vec3 tangent=(px*dy.y-py*dx.y)/det;
        vec3 bitangent=(py*dx.x-px*dy.x)/det;
        tangent-=face*dot(face,tangent);
        bitangent-=face*dot(face,bitangent);
        if(dot(tangent,tangent)>0.00000001 && dot(bitangent,bitangent)>0.00000001) {
            tangent=normalize(tangent);
            // Match the orthonormal tangent frame used by Blender's bake,
            // including mirrored UV islands and the explicit V convention.
            float handedness=dot(cross(face,tangent),bitangent)<0.0 ? -1.0 : 1.0;
            bitangent=normalize(cross(face,tangent))*handedness;
            normal=normalize(tangent*map.x-bitangent*map.y+face*max(map.z,0.05));
        }
    }
    vec3 lit=tactical_daylight(base,normal,eye,0.0)*mix(0.56,1.0,orm.r);
    vec3 light=normalize(vec3(-0.58,0.34,0.74));
    vec3 sum=light+eye;
    vec3 halfway=sum/max(length(sum),0.0001);
    float rough=clamp(orm.g,0.23,1.0);
    float ndl=max(dot(normal,light),0.0);
    float ndv=max(dot(normal,eye),0.05);
    float ndh=max(dot(normal,halfway),0.0);
    float vdh=max(dot(eye,halfway),0.0);
    float a2=pow(rough,4.0);
    float denom=ndh*ndh*(a2-1.0)+1.0;
    float distribution=a2/max(3.14159265*denom*denom,0.00001);
    float k=pow(rough+1.0,2.0)/8.0;
    float geometry=(ndv/(ndv*(1.0-k)+k))*(ndl/(ndl*(1.0-k)+k));
    vec3 f0=mix(vec3(0.04),base,orm.b);
    vec3 fresnel=f0+(1.0-f0)*pow(1.0-vdh,5.0);
    vec3 spec=distribution*geometry*fresnel*ndl/max(4.0*ndv*ndl,0.0001);
    return lit+min(spec,vec3(0.22))*vec3(1.0,0.97,0.91);
}

void vertex() {
    source_owner=instance_owner;
    authored_height=source_round ? 1.0 : UV2.y;
    vec3 raw;
    if(source_round) {
        // Observed spans own complete pixel cells, including the final row.
        // Centre the volume on those cells and reach their outer half-pixels;
        // fragment ownership still clips to the exact original round writes.
        vec2 pixel=source_round_center+vec2(0.5)
            +vec2(VERTEX.x,-VERTEX.z)*(source_round_radii+vec2(0.5));
        float depth=1024.0+VERTEX.y*source_round_radii.y*1024.0/source_projection.x;
        raw=vec3((pixel.x-source_projection.y)*depth/source_projection.x,depth,
                 (source_projection.z-pixel.y)*depth/source_projection.x);
    }
    else if(source_group) raw=source_group_origin+source_group_basis*VERTEX;
    else if(source_piecewise) {
        int packed=int(round(UV2.x));
        int ia=packed%16;int ib=(packed/16)%16;int ic=packed/256;
        raw=source_anchors[ia]*VERTEX.x+source_anchors[ib]*VERTEX.y+source_anchors[ic]*(1.0-VERTEX.x-VERTEX.y)+source_cn*VERTEX.z;
    } else raw=source_camera+source_cu*VERTEX.x+source_cv*VERTEX.y+source_cn*VERTEX.z;
    original_view=raw;
    VERTEX=vec3(raw.x,raw.z,-raw.y)/64.0;
}

void fragment() {
    // Evaluate all derivatives before the authoritative visibility discard.
    vec2 dx=dFdx(UV);vec2 dy=dFdy(UV);
    vec3 local=camera_to_local*original_view;
    vec3 relative=vec3(local.x,-local.y,local.z);
    vec3 px=dFdx(relative);vec3 py=dFdy(relative);
    vec3 face=cross(px,py);
    float magnitude=length(face);
    face=magnitude>0.000001 ? face/magnitude : vec3(0.0,0.0,1.0);
    if(dot(face,relative)>0.0)face=-face;
    vec3 eye=-relative/max(length(relative),0.0001);
    // Original painter ownership protects every other nonterrain source pixel
    // (byte 8), observed line (64), round write (255), and later terrain owner.
    // Release the old self silhouette only over empty/earlier terrain coverage.
    vec3 owner=texture(source_ownership,SCREEN_UV).rgb;
    vec2 packed=round(owner.rg*255.0);
    float source_id=packed.x+packed.y*256.0;
    float coverage=round(owner.b*255.0);
    bool own_surface=abs(source_id-source_owner)<0.25 && coverage==(source_round ? 255.0 : 8.0);
    bool earlier_background=!strict_source_coverage && source_id<source_owner-0.25 && coverage==0.0;
    if(!own_surface && !earlier_background)discard;
    ALBEDO=camera_basis_ready ? tactical_vehicle_response(UV,dx,dy,face,eye,px,py) : textureGrad(tactical_vehicle_albedo,UV,dx,dy).rgb;
    // Subtle lower-body/footing shade supplements baked local AO. Heights
    // come from whole admitted model bounds, never per-group camera fits.
    // This affects only pixels admitted above, with no projected terrain shadow.
    if(camera_basis_ready) {
        float grounding=1.0-0.06*(1.0-smoothstep(0.0,0.25,authored_height));
        ALBEDO*=OUTPUT_IS_SRGB ? grounding : pow(grounding,2.2);
    }
    if(camera_basis_ready && world_origin.z>0.0) {
        float haze=clamp((1.0-exp2(-max(length(relative)-600.0,0.0)/9000.0))*0.10,0.0,0.10);
        vec3 air=vec3(0.78,0.82,0.76);
        ALBEDO=mix(ALBEDO,OUTPUT_IS_SRGB ? air : pow(air,vec3(2.2)),haze);
    }
}
