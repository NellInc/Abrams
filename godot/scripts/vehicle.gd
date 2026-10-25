extends Node3D
## Original authored procedural M1A1 presentation model, built to published M1A1 proportions
## (7.9 m hull, 3.66 m over skirts, 2.44 m to the turret roof). Never participates in simulation.
## Geometry is batched per frame and material, so a vehicle costs a few draw calls.

var turret_root: Node3D
var barrel: Node3D
var paint: ShaderMaterial
var turret_paint: ShaderMaterial
var bustle_paint: ShaderMaterial
var fender_paint: ShaderMaterial
var dark: ShaderMaterial
var metal: StandardMaterial3D
var crew: Node3D
var _skin_face_mesh: ArrayMesh
# Only the title's hero gets sub-centimetre edge machining and extra hardware.
# Range targets retain their cheaper geometry batches.
var cover_detail := false
var recoil := 0.0
var authored_cover_batches := 0
const COVER_BLENDER_ASSET := "res://assets/cover_blender_v1.json"
var _batches: Dictionary = {}
var running_rig: Skeleton3D
var crew_rig: Skeleton3D
var _running_bone := 0
var _anatomy_active := false
var _running_parts: Array[Dictionary] = []
var _shoe_path: Array = []
var _shoe_stations: Array[float] = []
var _shoe_length := 0.0
const CREW_HIPS := [Vector3(0.7,0.98,0.48),Vector3(-0.72,0.96,0.56)]
const CREW_NECKS := [Vector3(0.77,1.49,0.39),Vector3(-0.68,1.26,-0.04)]
const CREW_HANDS := [[Vector3(0.98,1.34,0.3),Vector3(0.74,1.36,0.02)],
	[Vector3(-0.58,0.858,-0.12),Vector3(-0.96,0.858,-0.13)]]

# Hull roof, and the turret ring plane raised on its bearing above it. From the low box-cover
# camera the roof sits just below the nose line, so only the dark ring gap shows.
const DECK := 1.3
const RING_Y := 1.4
const RING_Z := -0.1
# Where the gun leaves the mantlet, in the turret frame.
const GUN_ROOT := Vector3(0,0.74,-1.67)
# Front plane of the fenders and nose.
const NOSE := -3.86
# Outward splay of the front skirt plates.
const FLARE := 0.3

# Box-cover finish: a single coat of worn olive drab under heavy field dust, grime and
# rain streaks. Weathering lives in the hull (or turret) frame through to_local, so it rides
# with the vehicle instead of swimming across it as the tank moves.
const PAINT_SHADER := """shader_type spatial;
uniform mat4 to_local;
uniform float height_offset = 0.0;
uniform vec3 base_color : source_color = vec3(0.30,0.29,0.21);
uniform vec3 grime : source_color = vec3(0.10,0.09,0.07);
uniform vec3 dust : source_color = vec3(0.41,0.37,0.30);
uniform vec3 mud : source_color = vec3(0.17,0.13,0.1);
uniform float dust_reach = 1.4;
uniform float dust_amount = 1.0;
varying vec3 lp;
varying vec3 ln;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*0.6+noise(p*2.1+7.3)*0.28+noise(p*4.3-3.1)*0.12;}
void vertex(){
 lp=(to_local*(MODEL_MATRIX*vec4(VERTEX,1.0))).xyz;
 ln=normalize((to_local*(MODEL_MATRIX*vec4(NORMAL,0.0))).xyz);
}
void fragment(){
 vec3 colour=base_color;
 // Sun-faded and touched-up panels mottled with grime, projected onto each face's own
 // plane, then fine paint grain on every face orientation.
 vec3 w=abs(ln);
 float mott=(fbm(lp.zy*1.8+3.0)*w.x+fbm(lp.xy*1.8+7.0)*w.z+fbm(lp.xz*1.8)*w.y)/(w.x+w.y+w.z);
 colour*=0.72+0.5*mott;
 float grit=(noise(lp.zy*55.0)*w.x+noise(lp.xy*55.0+3.0)*w.z+noise(lp.xz*55.0)*w.y)/(w.x+w.y+w.z);
 colour*=0.95+0.1*grit;
 // Spattered mud flecks and dried dust specks, as on the cover's armour.
 float fleck=(noise(lp.zy*90.0)*w.x+noise(lp.xy*90.0+7.0)*w.z+noise(lp.xz*90.0+1.0)*w.y)/(w.x+w.y+w.z);
 float speck=(noise(lp.zy*70.0+3.0)*w.x+noise(lp.xy*70.0+9.0)*w.z+noise(lp.xz*70.0+5.0)*w.y)/(w.x+w.y+w.z);
 colour=mix(colour,mud*0.6,smoothstep(0.92,0.97,fleck)*0.45);
 colour=mix(colour,dust*1.3,smoothstep(0.95,0.99,speck)*0.35);
 colour*=0.95+0.05*noise(lp.xy*26.0)+0.05*noise(lp.zy*26.0+5.0)-0.05*noise(lp.xz*26.0);
 // Oily grime and rain streaks running down the flanks.
 float streak=smoothstep(0.55,0.95,noise(vec2(lp.x*6.0+lp.z*4.5,lp.y*0.7)));
 colour=mix(colour,grime,streak*0.15*(1.0-abs(ln.y)));
 colour=mix(colour,grime,smoothstep(0.62,0.8,fbm(lp.xz*3.1-lp.y*1.4))*0.3);
 // Faces turned to the ground sit in the hull's own shadow.
 colour*=mix(0.72,1.0,smoothstep(-0.6,0.2,ln.y));
 // Road dust kicked up from the tracks: caked low on the hull, settled on upward faces.
 float height=lp.y+height_offset;
 float caked=(1.0-smoothstep(0.0,dust_reach,height))*(0.45+0.45*fbm(lp.xz*2.4+lp.y*3.0));
 float settled=smoothstep(0.55,0.95,ln.y)*0.25*fbm(lp.xz*1.3);
 float film=0.14*fbm(lp.xz*3.4-lp.y*2.0)+0.1*smoothstep(0.4,0.9,fbm(lp.xz*0.6));
 // Wet mud cakes the lowest plates; dry dust settles on top faces and films the rest.
 colour=mix(colour,mud,clamp(caked*dust_amount,0.0,0.85));
 colour=mix(colour,dust,clamp((settled+film)*dust_amount,0.0,0.6));
 ALBEDO=colour;
 // Fine sand-cast steel and rolled armour, with broad satin reflections across the plates.
 // The coarse relief remains in colour; centimetre-scale normal noise made flat steel lumpy.
 vec3 bump=vec3(noise(lp.zy*125.0)-0.5,noise(lp.xz*125.0+2.0)-0.5,noise(lp.xy*125.0+4.0)-0.5);
 // to_local is rigid, so its transposed rotation carries vehicle-frame directions to world.
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*(transpose(mat3(to_local))*(bump*0.085)));
 ROUGHNESS=clamp(0.71+0.23*caked+0.08*grit,0.0,1.0);
 SPECULAR=0.36;
 RIM=0.025;
 RIM_TINT=0.7;
}"""

# Crew cloth: creased fabric with soft fold shadows, and an optional three-colour desert
# camouflage. Bind-space coordinates keep the weave attached while the crew move.
const CLOTH_SHADER := """shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.9);
uniform vec3 camo_a : source_color = vec3(0.6,0.5,0.36);
uniform vec3 camo_b : source_color = vec3(0.46,0.36,0.25);
uniform float camo = 0.0;
uniform float surface_roughness = 0.94;
varying vec3 wp;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
  mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){wp=VERTEX;}
void fragment(){
 vec3 colour=base_color;
 // Large soft camouflage blotches.
 float blot=noise(wp*11.0)*0.65+noise(wp*24.0+3.1)*0.35;
 colour=mix(colour,camo_a,camo*0.8*smoothstep(0.44,0.52,blot));
 colour=mix(colour,camo_b,camo*0.7*smoothstep(0.64,0.72,blot));
 // Tailored folds are modelled into the sleeves; the fabric carries quiet tonal variation.
 float fold=noise(wp*vec3(26.0,12.0,26.0));
 vec3 q=wp*220.0;
 // Fade sub-pixel fibres instead of letting them sparkle in the full menu view.
 float resolved=1.0-smoothstep(0.25,1.2,length(fwidth(q)));
 float weave=mix(0.5,noise(q),resolved);
 vec3 grain=vec3(noise(q+vec3(0.17,0,0))-noise(q-vec3(0.17,0,0)),
  noise(q+vec3(0,0.17,0))-noise(q-vec3(0,0.17,0)),
  noise(q+vec3(0,0,0.17))-noise(q-vec3(0,0,0.17)));
 NORMAL=normalize(NORMAL-mat3(VIEW_MATRIX)*grain*(0.025*resolved));
 colour*=0.91+0.12*fold+0.025*weave;
 ALBEDO=colour;
 ROUGHNESS=clamp(surface_roughness+0.045*(weave-0.5),0.0,1.0);
 SPECULAR=0.24;
 RIM=0.035;
 RIM_TINT=0.85;
}"""

func cloth_material(base: Color, camouflage := false, roughness := 0.94) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = CLOTH_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color",base)
	m.set_shader_parameter("camo",1.0 if camouflage else 0.0)
	m.set_shader_parameter("surface_roughness",roughness)
	return m

# Skin carries low-contrast colour variation and a broad, broken-up highlight.
# Pores fade below pixel size; the face's authored vertex colours supply lips and stubble.
const SKIN_SHADER := """shader_type spatial;
uniform vec3 base_color : source_color = vec3(0.64,0.49,0.39);
varying vec3 wp;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p);vec3 f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
  mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){wp=VERTEX;}
void fragment(){
 float variation=noise(wp*38.0);
 vec3 q=wp*460.0;
 float resolved=1.0-smoothstep(0.25,1.2,length(fwidth(q)));
 float pore=mix(0.5,noise(q),resolved);
 vec3 grain=vec3(noise(q+vec3(0.15,0,0))-noise(q-vec3(0.15,0,0)),
  noise(q+vec3(0,0.15,0))-noise(q-vec3(0,0.15,0)),
  noise(q+vec3(0,0,0.15))-noise(q-vec3(0,0,0.15)));
 NORMAL=normalize(NORMAL-mat3(VIEW_MATRIX)*grain*(0.055*resolved));
 ALBEDO=base_color*COLOR.rgb*(0.97+0.06*variation);
 ROUGHNESS=0.65+0.08*pore+0.035*variation;
 SPECULAR=0.32;
 BACKLIGHT=ALBEDO*vec3(0.065,0.025,0.012);
}"""

func skin_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = SKIN_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color",Color("a47c64"))
	return m

func paint_material(base: Color, offset := 0.0, dust_reach := 1.4, dust_amount := 1.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = PAINT_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color",base)
	m.set_shader_parameter("height_offset",offset)
	m.set_shader_parameter("dust_reach",dust_reach)
	m.set_shader_parameter("dust_amount",dust_amount)
	return m

func _process(_delta: float) -> void:
	# Keep the weathering anchored to the hull and turret frames (five uniforms per vehicle).
	var hull_inverse := global_transform.affine_inverse()
	paint.set_shader_parameter("to_local",Projection(hull_inverse))
	dark.set_shader_parameter("to_local",Projection(hull_inverse))
	fender_paint.set_shader_parameter("to_local",Projection(hull_inverse))
	var turret_inverse := Projection(turret_root.global_transform.affine_inverse())
	turret_paint.set_shader_parameter("to_local",turret_inverse)
	bustle_paint.set_shader_parameter("to_local",turret_inverse)

func material(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

# ---- Batched geometry -------------------------------------------------------------------

func _batch(frame: Node3D, mat: Material, tag := "") -> SurfaceTool:
	# Faceted custom geometry carries no UVs, so it batches apart from primitive meshes.
	var key := "%d:%d:%s" % [frame.get_instance_id(), mat.get_instance_id(), tag]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = {"st":st,"frame":frame,"mat":mat,"moving":{},"anatomy":false}
	if _anatomy_active: _batches[key].anatomy = true
	return _batches[key].st

func _add(frame: Node3D, mesh: Mesh, xform: Transform3D, mat: Material, tag := "") -> void:
	_batch(frame,mat,tag).append_from(mesh,0,xform)
	if _running_bone > 0:
		var key := "%d:%d:%s" % [frame.get_instance_id(),mat.get_instance_id(),tag]
		for vertex in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			_batches[key].moving[(xform*vertex).snapped(Vector3.ONE*0.00001)] = _running_bone

func _cover_authored_batches(path := COVER_BLENDER_ASSET) -> Dictionary:
	if not cover_detail or has_meta("cover_export_source") or not FileAccess.file_exists(path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var asset = parser.data
	if not asset is Dictionary:
		return {}
	var schema = asset.get("schema",0)
	if not (schema is int or schema is float) or schema != 1:
		return {}
	var batches = asset.get("batches",{})
	return batches if batches is Dictionary else {}

func _cover_batch_selector(arrays: Array) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_TEX_UV],arrays[Mesh.ARRAY_INDEX]]))
	return hash.finish().hex_encode()

func _authored_cover_mesh(source: Mesh, role: String, authored: Dictionary) -> Mesh:
	var arrays: Array = source.surface_get_arrays(0)
	var replacement = authored.get(_cover_batch_selector(arrays),{})
	if not replacement is Dictionary:
		return source
	var frame = replacement.get("frame","")
	if not frame is String or frame != role:
		return source
	var source_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count = replacement.get("count",0)
	if not (count is int or count is float) or count != source_vertices.size():
		return source
	var positions = replacement.get("vertices",[])
	var normals = replacement.get("normals",[])
	if not positions is Array or not normals is Array:
		return source
	if positions.size() != source_vertices.size()*3 or normals.size() != positions.size():
		return source
	for component in positions+normals:
		if not (component is int or component is float) or not is_finite(float(component)):
			return source
	var vertices := PackedVector3Array()
	var authored_normals := PackedVector3Array()
	for i in range(source_vertices.size()):
		var point := Vector3(positions[i*3],positions[i*3+1],positions[i*3+2])
		var normal := Vector3(normals[i*3],normals[i*3+1],normals[i*3+2])
		if point.distance_to(source_vertices[i]) > 0.01 or absf(normal.length()-1.0)>0.01:
			return source
		vertices.append(point)
		authored_normals.append(normal)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = authored_normals
	var refined := ArrayMesh.new()
	refined.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return refined

func _commit() -> void:
	var authored := _cover_authored_batches()
	for entry in _batches.values():
		var node := MeshInstance3D.new()
		var original: Mesh = entry.st.commit()
		node.mesh = original
		if not authored.is_empty():
			var role := "hull" if entry.frame == self else ("turret" if entry.frame == turret_root else ("barrel" if entry.frame == barrel else "crew"))
			node.mesh = _authored_cover_mesh(original,role,authored)
			if node.mesh != original:
				node.set_meta("blender_source_batch",_cover_batch_selector(original.surface_get_arrays(0)))
				authored_cover_batches += 1
		node.material_override = entry.mat
		entry.frame.add_child(node)
		# Add runtime skin weights after matching the unchanged Blender buffers.
		# Working if all authored batches still match and the rest pose is exact.
		var rig: Skeleton3D = crew_rig if entry.anatomy else running_rig
		if rig != null and (entry.anatomy or not entry.moving.is_empty()):
			var arrays: Array = node.mesh.surface_get_arrays(0)
			var source: PackedVector3Array = original.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var bones := PackedInt32Array()
			var weights := PackedFloat32Array()
			for point in source:
				if entry.anatomy:
					var person := 0 if point.x > 0.0 else 1
					var blend := crew_weights(point,person)
					bones.append_array(PackedInt32Array([0,1+person*2,2+person*2,0]))
					weights.append_array(PackedFloat32Array([1.0-blend.x,blend.x*(1.0-blend.y),blend.x*blend.y,0.0]))
				else:
					bones.append_array(PackedInt32Array([entry.moving.get(point.snapped(Vector3.ONE*0.00001),0),0,0,0]))
					weights.append_array(PackedFloat32Array([1.0,0.0,0.0,0.0]))
			arrays[Mesh.ARRAY_BONES] = bones
			arrays[Mesh.ARRAY_WEIGHTS] = weights
			var skinned := ArrayMesh.new()
			skinned.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			node.mesh = skinned
			node.skin = rig.create_skin_from_rest_transforms()
			node.skeleton = node.get_path_to(rig)
			node.extra_cull_margin = 0.08 if entry.anatomy else 8.0
	_batches.clear()

func _new_motion_rig(parent: Node3D, label: String) -> Skeleton3D:
	var rig := Skeleton3D.new()
	rig.name = label
	parent.add_child(rig)
	rig.add_bone("Fixed")
	rig.set_bone_rest(0,Transform3D.IDENTITY)
	rig.reset_bone_pose(0)
	return rig

func _motion_bone(rig: Skeleton3D, rest: Transform3D, label: String, parent := 0) -> int:
	var bone := rig.add_bone(label)
	rig.set_bone_parent(bone,parent)
	rig.set_bone_rest(bone,rest)
	rig.reset_bone_pose(bone)
	return bone

func _wheel_bone(at: Vector3, radius: float) -> void:
	if running_rig == null: return
	_running_bone = _motion_bone(running_rig,Transform3D(Basis(),at),"Wheel%d" % _running_parts.size())
	_running_parts.append({"bone":_running_bone,"radius":radius})

static func crew_weights(point: Vector3, person: int) -> Vector2:
	var hip: Vector3 = CREW_HIPS[person]
	var neck: Vector3 = CREW_NECKS[person]
	var axis := (neck-hip).normalized()
	var body := smoothstep(0.015,0.22,(point-hip).dot(axis))
	for hand in CREW_HANDS[person]:
		body *= smoothstep(0.105,0.25,point.distance_to(hand))
	var head := smoothstep(-0.045,0.055,(point-neck).dot(axis))
	return Vector2(body,head)

func update_cover_motion(time: float, distance: float) -> void:
	if running_rig == null: return
	for part in _running_parts:
		if part.has("radius"):
			running_rig.set_bone_pose_rotation(part.bone,Quaternion(Vector3.RIGHT,-distance/part.radius))
		else:
			var along := fposmod(part.station+distance,_shoe_length)
			var at := 0
			while at+1 < _shoe_stations.size() and _shoe_stations[at+1] <= along: at += 1
			var next := (at+1)%_shoe_path.size()
			var end: float = _shoe_stations[next] if next > 0 else _shoe_length
			var mix_at := (along-_shoe_stations[at])/(end-_shoe_stations[at])
			var point: Vector2 = _shoe_path[at].p.lerp(_shoe_path[next].p,mix_at)
			running_rig.set_bone_pose_position(part.bone,Vector3(part.x,point.y,point.x))
			running_rig.set_bone_pose_rotation(part.bone,Quaternion(Vector3.RIGHT,lerp_angle(_shoe_path[at].pitch,_shoe_path[next].pitch,mix_at)))
	for person in 2:
		var phase := float(person)*1.7
		var breath := sin(time*1.6+phase)-sin(phase)
		var sway := sin(time*1.05+phase)-sin(phase)
		var glance := sin(time*0.72+phase)-sin(phase)
		var body := 1+person*2
		crew_rig.set_bone_pose_position(body,CREW_HIPS[person]+Vector3(0.0,breath*0.012,0.0))
		crew_rig.set_bone_pose_rotation(body,Quaternion.from_euler(Vector3(sway*0.04,glance*0.04,breath*0.02)))
		crew_rig.set_bone_pose_rotation(body+1,Quaternion.from_euler(Vector3((sin(time*0.9+phase)-sin(phase))*0.075,glance*0.30,0.0)))

func box(frame: Node3D, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mesh: Mesh
	var bevel := minf(0.016,minf(size.x,minf(size.y,size.z))*0.12)
	if cover_detail and minf(size.x,minf(size.y,size.z)) > 0.075:
		mesh = _chamfer_box(size,bevel)
	else:
		var cube := BoxMesh.new()
		cube.size = size
		mesh = cube
	_add(frame,mesh,Transform3D(Basis.from_euler(rot),at),mat,"machined" if cover_detail else "")

# Six inset faces, twelve edge strips and eight corner facets. Tiny bevels catch the
# key and firelight without softening the Abrams' characteristic slab silhouette.
func _chamfer_box(size: Vector3, bevel: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var h := size*0.5
	var inner := h-Vector3.ONE*bevel
	for axis in range(3):
		var a := (axis+1)%3
		var b := (axis+2)%3
		for sign_at in [-1.0,1.0]:
			var pts: Array[Vector3] = []
			for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var p := Vector3.ZERO
				p[axis] = h[axis]*sign_at
				p[a] = inner[a]*corner.x
				p[b] = inner[b]*corner.y
				pts.append(p)
			var normal := Vector3.ZERO
			normal[axis] = sign_at
			_quad(st,pts[0],pts[1],pts[2],pts[3],normal)
		for sa in [-1.0,1.0]:
			for sb in [-1.0,1.0]:
				var pts: Array[Vector3] = []
				for end in [-1.0,1.0]:
					for face in range(2):
						var p := Vector3.ZERO
						p[axis] = inner[axis]*end
						p[a] = (h[a] if face == 0 else inner[a])*sa
						p[b] = (inner[b] if face == 0 else h[b])*sb
						pts.append(p)
				_quad(st,pts[0],pts[1],pts[3],pts[2],(pts[0]+pts[3])*0.5)
	for sx in [-1.0,1.0]:
		for sy in [-1.0,1.0]:
			for sz in [-1.0,1.0]:
				var sign_at := Vector3(sx,sy,sz)
				_tri(st,Vector3(h.x,inner.y,inner.z)*sign_at,Vector3(inner.x,h.y,inner.z)*sign_at,Vector3(inner.x,inner.y,h.z)*sign_at,sign_at)
	st.generate_normals()
	return st.commit()

func cylinder(frame: Node3D, radius: float, height: float, at: Vector3, mat: Material, rot := Vector3.ZERO, segments := 16, top := -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	_add(frame,mesh,Transform3D(Basis.from_euler(rot),at),mat)

func sphere(frame: Node3D, radius: float, scale_by: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_add(frame,mesh,Transform3D(Basis().scaled(scale_by),at),mat)

# Flat-shaded solid between a bottom and a top ring of points (same count, same order).
func loft(frame: Node3D, bottom: Array, top: Array, mat: Material, xform := Transform3D()) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := bottom.size()
	var centre_b := Vector3.ZERO
	var centre_t := Vector3.ZERO
	for i in range(n):
		centre_b += bottom[i]
		centre_t += top[i]
	centre_b /= n
	centre_t /= n
	for i in range(n):
		var j := (i+1)%n
		_quad(st,bottom[i],bottom[j],top[j],top[i],(bottom[i]+bottom[j])*0.5-centre_b)
		_tri(st,centre_t,top[i],top[j],Vector3.UP)
		_tri(st,centre_b,bottom[j],bottom[i],Vector3.DOWN)
	st.generate_normals()
	_add(frame,st.commit(),xform,mat,"facet")

# Side-profile polygon in (z, y) extruded across x from x0 to x1.
func extrude_x(frame: Node3D, profile: Array, x0: float, x1: float, mat: Material) -> void:
	if cover_detail and x1-x0 > 0.3:
		_bevel_plate(frame,profile,x0,x1,mat)
		return
	var bottom: Array = []
	var top: Array = []
	for p in profile:
		bottom.append(Vector3(x0,p.y,p.x))
		top.append(Vector3(x1,p.y,p.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := profile.size()
	var centre := Vector3.ZERO
	for p in bottom:
		centre += p
	centre /= n
	for i in range(n):
		var j := (i+1)%n
		var mid: Vector3 = (bottom[i]+bottom[j])*0.5
		_quad(st,bottom[i],bottom[j],top[j],top[i],Vector3(0,mid.y-centre.y,mid.z-centre.z))
		_tri(st,Vector3(x0,centre.y,centre.z),bottom[j],bottom[i],Vector3.LEFT)
		_tri(st,Vector3(x1,centre.y,centre.z),top[i],top[j],Vector3.RIGHT)
	st.generate_normals()
	_add(frame,st.commit(),Transform3D(),mat,"facet")

# Chamfered outline with properly triangulated concave caps.
func _bevel_plate(frame: Node3D, profile: Array, x0: float, x1: float, mat: Material) -> void:
	var outline := PackedVector2Array(profile)
	var centre := Vector2.ZERO
	for p in outline:
		centre += p
	centre /= outline.size()
	var inset := PackedVector2Array()
	for p in outline:
		inset.append(p.move_toward(centre,0.014))
	var indices := Geometry2D.triangulate_polygon(inset)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(outline.size()):
		var j := (i+1)%outline.size()
		var a := Vector3(0,outline[i].y,outline[i].x)
		var b := Vector3(0,outline[j].y,outline[j].x)
		var ai := Vector3(0,inset[i].y,inset[i].x)
		var bi := Vector3(0,inset[j].y,inset[j].x)
		var outward := (a+b)*0.5-Vector3(0,centre.y,centre.x)
		_quad(st,a+Vector3(x0+0.014,0,0),b+Vector3(x0+0.014,0,0),b+Vector3(x1-0.014,0,0),a+Vector3(x1-0.014,0,0),outward)
		for side in [x0,x1]:
			var sign_at := -1.0 if side == x0 else 1.0
			var edge := Vector3(side-sign_at*0.014,0,0)
			var face := Vector3(side,0,0)
			_quad(st,a+edge,b+edge,bi+face,ai+face,outward+Vector3(sign_at,0,0))
	for i in range(0,indices.size(),3):
		for side in [x0,x1]:
			var pts: Array[Vector3] = []
			for k in range(3):
				var p := inset[indices[i+k]]
				pts.append(Vector3(side,p.y,p.x))
			_tri(st,pts[0],pts[1],pts[2],Vector3.LEFT if side == x0 else Vector3.RIGHT)
	st.generate_normals()
	_add(frame,st.commit(),Transform3D(),mat,"facet")

# Godot front faces wind clockwise when seen from outside.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a)
	if normal.dot(outward) < 0.0:
		for v in [a,b,c]:
			st.add_vertex(v)
	else:
		for v in [a,c,b]:
			st.add_vertex(v)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(st,a,b,c,outward)
	_tri(st,a,c,d,outward)

# ---- Model -------------------------------------------------------------------------------

func _ready() -> void:
	paint = paint_material(Color("4a483c"),0.0,1.2,0.4)
	# Fenders and front skirts wear the thickest coat of pale road dust.
	fender_paint = paint_material(Color("6b6352"),0.0,1.5,0.7)
	turret_paint = paint_material(Color("4a483c"),RING_Y,1.2,0.15)
	# Running gear: dark rubber and steel under the heaviest coat of road dust.
	dark = paint_material(Color("1f1e1a"),0.0,1.5,0.55)
	metal = material(Color("1d1e1b"),0.55,0.5)
	var rubber := material(Color("151513"),0.95)
	var glass := material(Color("1d2422"),0.12,0.8)
	var lamp := material(Color("ff9a3a"),0.3)
	lamp.emission_enabled = true
	lamp.emission = Color("ffad36")
	lamp.emission_energy_multiplier = 1.8
	if cover_detail and not has_meta("cover_export_source"):
		running_rig = _new_motion_rig(self,"RunningGearMotion")
	_hull(rubber,lamp)
	turret_root = Node3D.new()
	turret_root.name = "Turret"
	add_child(turret_root)
	turret_root.position = Vector3(0,RING_Y,RING_Z)
	barrel = Node3D.new()
	turret_root.add_child(barrel)
	barrel.position = GUN_ROOT
	_turret(rubber,glass)
	_gun(rubber)
	if cover_detail:
		_hero_hardware()
	crew = Node3D.new()
	crew.visible = false
	turret_root.add_child(crew)
	if running_rig != null:
		crew_rig = _new_motion_rig(crew,"CrewMotion")
		for person in 2:
			var body := _motion_bone(crew_rig,Transform3D(Basis(),CREW_HIPS[person]),"Body%d" % person)
			_motion_bone(crew_rig,Transform3D(Basis(),CREW_NECKS[person]-CREW_HIPS[person]),"Head%d" % person,body)
	if cover_detail:
		_crew()
	_commit()

func _hull(rubber: Material, lamp: Material) -> void:
	# Main hull between the tracks: rear plate, long deck, almost flat upper glacis ending
	# in a shallow nose lip, then the lower glacis raking back under the nose to the belly.
	var body := [Vector2(3.9,0.5),Vector2(3.95,1.2),Vector2(3.88,DECK),Vector2(-2.2,DECK),
		Vector2(-3.8,1.34),Vector2(NOSE+0.02,1.2),Vector2(-3.3,0.95),Vector2(-3.0,0.48),Vector2(3.7,0.48)]
	extrude_x(self,body,-1.1,1.1,paint)
	# Upper glacis caked dark with wet earth thrown up by the tracks.
	extrude_x(self,[Vector2(-2.2,DECK+0.01),Vector2(-3.8,1.35),Vector2(-3.8,1.33),Vector2(-2.2,DECK-0.01)],-1.08,1.08,dark)
	# Lower glacis: a mud-blackened plate raking back under the nose lip.
	extrude_x(self,[Vector2(NOSE+0.02,1.2),Vector2(-3.35,0.62),Vector2(-3.0,0.48),Vector2(-3.3,0.95)],-1.1,1.1,material(Color("2a231e"),0.95))
	# Rounded, dust-coated nose lip between the headlights, which catches the key light as a
	# bright band across the cover's hull front.
	cylinder(self,0.075,2.2,Vector3(0,1.235,NOSE+0.05),fender_paint,Vector3(0,0,PI/2),14)
	for side in [-1.0,1.0]:
		# Sponson and front fender over each track: a square-faced fender whose lower band
		# rakes back below a seam, carried the full length of the hull.
		# The fender top falls slightly toward the rear, so from the low cover camera only its
		# rolled front edge catches the light.
		var fender := [Vector2(NOSE+0.09,1.36),Vector2(NOSE,1.28),Vector2(NOSE,1.13),Vector2(NOSE+0.07,0.97),
			Vector2(3.92,0.97),Vector2(3.92,1.14),Vector2(3.8,1.18),Vector2(-2.6,1.33)]
		extrude_x(self,fender,minf(1.1*side,1.76*side),maxf(1.1*side,1.76*side),fender_paint)
		box(self,Vector3(0.66,0.012,0.012),Vector3(1.43*side,1.13,NOSE-0.004),dark)
		_running_gear(side,rubber)
		_skirts(side)
		_headlight(side,lamp)
		# Rear grille louvre per side.
		box(self,Vector3(0.95,0.6,0.05),Vector3(0.62*side,0.92,3.95),dark)
		# Fender stowage boxes behind the turret.
		box(self,Vector3(0.5,0.2,1.1),Vector3(1.45*side,1.2,2.7),paint)
	# Driver's hatch and periscopes at the front centre of the deck.
	cylinder(self,0.34,0.06,Vector3(0,DECK+0.02,-2.45),paint,Vector3.ZERO,16)
	for px in [-0.22,0.0,0.22]:
		box(self,Vector3(0.14,0.07,0.06),Vector3(px,DECK+0.05,-2.78),dark)
	# Engine deck: grille doors and the exhaust louvre.
	for i in range(9):
		box(self,Vector3(2.0,0.03,0.07),Vector3(0,DECK+0.015,1.6+i*0.24),dark)
	box(self,Vector3(2.2,0.28,0.08),Vector3(0,1.22,3.96),metal)

func _headlight(side: float, lamp: Material) -> void:
	# Armoured headlight cluster on the glacis, tucked against the inside of each fender:
	# a dark housing, one amber lamp, a sloped hood and a bar guard.
	# The cover shows the right-hand cluster set further outboard than the left one.
	var lx: float = 0.885*side+(0.07 if side > 0.0 else 0.0)
	box(self,Vector3(0.35,0.15,0.3),Vector3(lx,1.24,-3.72),dark)
	sphere(self,0.048,Vector3(1,1,0.5),Vector3(lx-0.02*side,1.26,NOSE-0.01),lamp)
	box(self,Vector3(0.17,0.1,0.22),Vector3(lx+0.06*side,1.37,-3.74),dark,Vector3(-0.35,0,0))
	box(self,Vector3(0.4,0.022,0.022),Vector3(lx,1.325,NOSE-0.04),metal)
	for gx in [-0.19,0.19]:
		box(self,Vector3(0.022,0.17,0.022),Vector3(lx+gx,1.24,NOSE-0.04),metal)
	box(self,Vector3(0.4,0.022,0.022),Vector3(lx,1.16,NOSE-0.04),metal)

func _running_gear(side: float, rubber: Material) -> void:
	# Mud-caked steel shoes and charcoal rubber pads, catching dust light under the fenders.
	var track := material(Color("38342a"),0.83,0.15)
	var pad := material(Color("282824"),0.94)
	var x: float = 1.45*side
	# Seven dual road wheels, front idler, rear drive sprocket and two return rollers.
	for i in range(7):
		var z := -2.55+i*0.82
		_wheel_bone(Vector3(x,0.4,z),0.32)
		for half in [-0.15,0.15]:
			cylinder(self,0.32,0.13,Vector3(x+half,0.4,z),dark,Vector3(0,0,PI/2),18)
			cylinder(self,0.14,0.14,Vector3(x+half,0.4,z),metal,Vector3(0,0,PI/2),10)
		_running_bone = 0
		box(self,Vector3(0.34,0.12,0.55),Vector3(x,0.6,z+0.2),dark,Vector3(-0.35,0,0))
	_wheel_bone(Vector3(x,0.55,-3.3),0.31)
	for half in [-0.15,0.15]:
		cylinder(self,0.31,0.13,Vector3(x+half,0.55,-3.3),dark,Vector3(0,0,PI/2),18)
	_wheel_bone(Vector3(x,0.56,3.5),0.36)
	for half in [-0.15,0.15]:
		cylinder(self,0.36,0.11,Vector3(x+half,0.56,3.5),metal,Vector3(0,0,PI/2),18)
	for t in range(12):
		var angle := TAU*t/12.0
		box(self,Vector3(0.36,0.09,0.09),Vector3(x,0.56+sin(angle)*0.39,3.5+cos(angle)*0.39),dark,Vector3(angle,0,0))
	for z in [-1.3,1.0]:
		_wheel_bone(Vector3(x,0.8,z),0.1)
		cylinder(self,0.1,0.3,Vector3(x,0.8,z),dark,Vector3(0,0,PI/2),10)
	_running_bone = 0
	# Track: shoes along the ground run, up and over the idler and sprocket, and the top run.
	var path: Array = []
	path.append_array(_track_line(Vector2(-2.9,0.07),Vector2(2.9,0.07),15))
	path.append_array(_track_line(Vector2(2.9,0.07),Vector2(3.72,0.44),3))
	path.append_array(_track_arc(Vector2(3.5,0.56),0.42,-0.75,1.75,5))
	path.append_array(_track_line(Vector2(3.3,0.96),Vector2(-3.1,0.92),16))
	path.append_array(_track_arc(Vector2(-3.3,0.55),0.39,1.75,4.2,6))
	path.append_array(_track_line(Vector2(-3.55,0.38),Vector2(-2.9,0.07),3))
	if running_rig != null and _shoe_path.is_empty():
		_shoe_path = path
		for i in path.size():
			_shoe_stations.append(_shoe_length)
			_shoe_length += path[i].p.distance_to(path[(i+1)%path.size()].p)
	for index in path.size():
		var shoe: Dictionary = path[index]
		var pitch: float = shoe.pitch
		var p: Vector2 = shoe.p
		var n: Vector2 = shoe.n
		if running_rig != null:
			_running_bone = _motion_bone(running_rig,Transform3D(Basis(Vector3.RIGHT,pitch),Vector3(x,p.y,p.x)),"Shoe%d" % _running_parts.size())
			_running_parts.append({"bone":_running_bone,"station":_shoe_stations[index],"x":x})
		box(self,Vector3(0.64,0.07,0.36),Vector3(x,p.y,p.x),track,Vector3(pitch,0,0))
		# Rubber pads, two per shoe, standing proud of the mud-caked shoe.
		for px in [-0.17,0.17]:
			box(self,Vector3(0.24,0.06,0.26),Vector3(x+px,p.y+n.y*0.055,p.x+n.x*0.055),pad,Vector3(pitch,0,0))
		# Steel grouser on the outer face of every shoe.
		box(self,Vector3(0.66,0.035,0.06),Vector3(x,p.y+n.y*0.045,p.x+n.x*0.045),metal,Vector3(pitch,0,0))
	_running_bone = 0

# Track shoes as {p: (z, y) centre, pitch: rotation about x, n: outward normal in (z, y)}.
# A box's long axis (+z) pitched by atan2(-dy, dz) follows the direction (dz, dy).
const TRACK_CENTRE := Vector2(0.0,0.55)

func _track_line(a: Vector2, b: Vector2, count: int) -> Array:
	var shoes: Array = []
	var d := (b-a).normalized()
	var n := Vector2(-d.y,d.x)
	var mid := (a+b)*0.5
	if n.dot(mid-TRACK_CENTRE) < 0.0:
		n = -n
	for i in range(count):
		shoes.append({"p":a.lerp(b,(i+0.5)/count),"pitch":atan2(-d.y,d.x),"n":n})
	return shoes

func _track_arc(centre: Vector2, radius: float, from: float, to: float, count: int) -> Array:
	var shoes: Array = []
	for i in range(count):
		var t := from+(to-from)*(i+0.5)/count
		var n := Vector2(cos(t),sin(t))
		shoes.append({"p":centre+n*radius,"pitch":atan2(-n.x,-n.y),"n":n})
	return shoes

func _skirts(side: float) -> void:
	var x: float = 1.8*side
	# Heavy front skirt plate hinged at the fender's outer edge and splayed out, as on the box
	# cover, with a rolled top lip and a raked lower edge; then ballistic panels butted with
	# dark seams and bolted along the top.
	var flare := Node3D.new()
	add_child(flare)
	flare.transform = Transform3D(Basis(Vector3.UP,FLARE*side),Vector3(1.83*side,0,NOSE))
	var plate := [Vector2(0,1.34),Vector2(0,1.12),Vector2(0.08,0.72),Vector2(1.35,0.5),Vector2(1.35,1.27)]
	extrude_x(flare,plate,minf(0.0,-0.06*side),maxf(0.0,-0.06*side),paint)
	cylinder(flare,0.035,1.35,Vector3(-0.02*side,1.3,0.675),fender_paint,Vector3(PI/2,0,0),8)
	var flare_end := 1.83+1.35*sin(FLARE)
	box(self,Vector3(flare_end-1.78,0.62,0.05),Vector3((flare_end+1.78)*0.5*side,0.97,NOSE+1.35*cos(FLARE)),fender_paint)
	for i in range(6):
		var z0 := -2.55+i*1.05
		box(self,Vector3(0.05,0.64,1.03),Vector3(x,0.92,z0+0.52),paint)
		box(self,Vector3(0.055,0.64,0.02),Vector3(x,0.92,z0+1.04),dark)
		for bz in [0.15,0.5,0.85]:
			cylinder(self,0.022,0.03,Vector3(x+0.03*side,1.18,z0+bz),metal,Vector3(0,0,PI/2),6)
	box(self,Vector3(0.08,0.05,6.3),Vector3(x,1.25,0.6),paint)

func _turret(rubber: Material, glass: Material) -> void:
	var t := turret_root
	bustle_paint = paint_material(Color("24231d"),RING_Y,1.2,0.15)
	# Side profile (z, y) of the M1 cheeks and slab sides: the roof edge, the armour nose
	# jutting ahead of it, the deep undercut, the flat skirt line and the raked rear edge
	# where the bustle box begins.
	var cheek := [Vector2(-2.36,0.75),Vector2(-2.4,0.37),Vector2(-1.92,0.15),Vector2(-0.3,0.13),
		Vector2(0.3,0.17),Vector2(0.3,0.3),Vector2(-0.02,0.78)]
	extrude_x(t,cheek,0.55,1.7,turret_paint)
	extrude_x(t,cheek,-1.7,-0.55,turret_paint)
	# Worn, dust-polished roof edge along each slab side, which catches the light on the cover.
	var edge_paint := material(Color("625b4a"),0.7)
	for side in [-1.0,1.0]:
		box(t,Vector3(0.05,0.04,2.21),Vector3(side*1.69,0.765,-1.12),edge_paint,Vector3(0.0136,0,0))
	# Centre section, recessed behind the cheeks so the mantlet sits in a slot.
	var centre := [Vector2(-1.55,0.76),Vector2(-1.55,0.2),Vector2(-0.3,0.13),Vector2(0.3,0.17),Vector2(0.3,0.78)]
	extrude_x(t,centre,-0.55,0.55,turret_paint)
	# Gun shield across the slot.
	box(t,Vector3(1.0,0.5,0.24),Vector3(0,0.53,-1.62),dark)
	box(t,Vector3(0.6,0.36,0.08),Vector3(0,0.59,-1.76),turret_paint)
	# Turret ring skirt in the shadowed gap between the turret floor and the deck.
	cylinder(t,1.15,0.34,Vector3(0,-0.02,-0.1),dark,Vector3.ZERO,24)
	# Bustle: the stowage box behind the slab sides, its side bins flush with the armour.
	box(t,Vector3(3.24,0.66,1.62),Vector3(0,0.53,0.72),bustle_paint)
	# The deep shadowed well under the bustle overhang, which reads as one dark band below the
	# turret side on the cover rather than showing sky through to the far side.
	box(t,Vector3(3.1,0.34,1.5),Vector3(0,0.03,0.72),dark)
	# The bustle's lower skirt flares out below the rear of the side bins in a sloped,
	# dust-lit plate; ahead of it the side stays in shadow.
	for side in [-1.0,1.0]:
		var inner: float = 1.62*side
		var outer: float = 1.74*side
		loft(t,[Vector3(inner,0.2,0.7),Vector3(inner,0.2,1.53),Vector3(outer,-0.05,1.53),Vector3(outer,-0.05,0.7)],[Vector3(inner,0.22,0.7),Vector3(inner,0.22,1.53),Vector3(outer,-0.03,1.53),Vector3(outer,-0.03,0.7)],turret_paint)
	box(t,Vector3(3.26,0.02,1.5),Vector3(0,0.7,0.75),dark)
	# Tactical marking on the right bin, as on the box cover: two discs and a triangle.
	var ink := material(Color("b8934a"),0.8)
	for i in range(2):
		cylinder(t,0.06,0.012,Vector3(1.626,0.59,1.36-i*0.135),ink,Vector3(0,0,PI/2),14)
	_flat(t,[Vector3(1.627,0.54,1.15),Vector3(1.627,0.54,1.03),Vector3(1.627,0.645,1.09)],Vector3.RIGHT,ink)
	# Bustle rack: three rails down each side, sagging slightly toward the back as on the
	# cover, across the back, with posts at the rear.
	for y in [0.23,0.48,0.765]:
		for side in [-1.0,1.0]:
			box(t,Vector3(0.035,0.035,2.36),Vector3(side*1.78,y,0.93),metal,Vector3(0.035,0,0))
		box(t,Vector3(3.56,0.035,0.035),Vector3(0,y-0.04,2.1),metal)
	for side in [-1.0,1.0]:
		for z in [1.83,2.1]:
			box(t,Vector3(0.05,0.66,0.05),Vector3(side*1.78,0.46,z),metal)
	# Kit stowed in the rack: bedrolls and boxes.
	cylinder(t,0.17,1.3,Vector3(-0.7,0.4,1.95),material(Color("4f4a36")),Vector3(0,0,PI/2),10)
	box(t,Vector3(0.9,0.36,0.4),Vector3(0.75,0.4,1.95),material(Color("2f2e25")))
	# Gunner's primary sight "doghouse" on the right front roof.
	box(t,Vector3(0.5,0.22,0.68),Vector3(0.75,0.88,-0.94),turret_paint)
	box(t,Vector3(0.38,0.14,0.03),Vector3(0.75,0.87,-1.29),glass)
	# Commander's weapon station (right) with vision blocks, loader's hatch (left).
	cylinder(t,0.44,0.2,Vector3(0.75,0.87,0.45),turret_paint,Vector3.ZERO,18)
	# Raised weapon-station ring around the commander and his open hatch lid standing behind.
	cylinder(t,0.4,0.22,Vector3(0.75,1.08,0.45),dark,Vector3.ZERO,18)
	cylinder(t,0.36,0.06,Vector3(0.82,1.4,0.98),dark,Vector3(-1.25,0,0.25),18)
	# Bedroll and pack strapped against the lid.
	sphere(t,0.3,Vector3(1.0,1.15,0.8),Vector3(0.98,1.38,0.86),material(Color("1c1d19"),0.95))
	for i in range(6):
		var a := TAU*i/6.0+0.3
		box(t,Vector3(0.13,0.09,0.05),Vector3(0.75+cos(a)*0.43,0.91,0.45+sin(a)*0.43),glass,Vector3(0,-a+PI/2,0))
	cylinder(t,0.4,0.08,Vector3(-0.7,0.81,0.1),turret_paint,Vector3.ZERO,16)
	box(t,Vector3(0.74,0.05,0.5),Vector3(-0.7,1.02,0.52),turret_paint,Vector3(1.0,0,0))
	_loader_weapon(t)
	# Antenna mount and crosswind sensor mast.
	cylinder(t,0.03,0.5,Vector3(1.0,1.02,1.42),metal,Vector3.ZERO,6)
	cylinder(t,0.025,0.5,Vector3(0,1.02,1.4),metal,Vector3.ZERO,6)
	box(t,Vector3(0.06,0.06,0.26),Vector3(0,1.27,1.4),metal)

func _loader_weapon(t: Node3D) -> void:
	# One mounted assembly. The old low receiver disappeared behind the cheek
	# while its independently positioned barrel remained against the sky.
	# Working if the title view shows a continuous barrel, receiver and cradle.
	var steel := material(Color("242620"),0.63,0.35)
	# Forward of the loader's braced hand, with the foot on the turret roof.
	var pivot := Vector3(-0.98,1.25,-0.40)
	cylinder(t,0.072,0.07,Vector3(pivot.x,0.865,pivot.z),steel,Vector3.ZERO,12)
	cylinder(t,0.038,0.38,Vector3(pivot.x,1.06,pivot.z),steel,Vector3.ZERO,12)
	cylinder(t,0.06,0.19,pivot,steel,Vector3(0,0,PI/2),12)
	var gun := Transform3D(Basis(Vector3.RIGHT,0.45),pivot)
	_add(t,_box_mesh(Vector3(0.12,0.15,0.46)),gun.translated_local(Vector3(0,0.055,-0.13)),steel)
	_add(t,_box_mesh(Vector3(0.14,0.035,0.31)),gun.translated_local(Vector3(0,0.145,-0.12)),steel)
	for side in [-1.0,1.0]:
		_add(t,_box_mesh(Vector3(0.035,0.13,0.16)),gun.translated_local(Vector3(side*0.075,0.025,0.0)),steel)
	for section in [[-0.37,0.15,0.043],[-0.67,0.52,0.025],[-0.945,0.07,0.034]]:
		var tube := CylinderMesh.new()
		tube.top_radius = section[2]
		tube.bottom_radius = section[2]
		tube.height = section[1]
		tube.radial_segments = 24 if cover_detail else 12
		if section[0] == -0.945: tube.cap_bottom = false
		_add(t,tube,gun*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0.075,section[0])),steel)
	_add(t,_box_mesh(Vector3(0.09,0.09,0.13)),gun.translated_local(Vector3(0,0.025,0.145)),steel)
	# Machined muzzle lip and recessed bore replace the visible solid end cap.
	# Working if the centre is open at the lip and the original mount is exact.
	var bore := SurfaceTool.new()
	bore.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(24):
		var a := TAU*float(i)/24.0
		var b := TAU*float(i+1)/24.0
		var ra := Vector3(cos(a),sin(a),0)
		var rb := Vector3(cos(b),sin(b),0)
		var front := Vector3(0,0.075,-0.98)
		var back := Vector3(0,0.075,-0.931)
		_quad(bore,front+ra*0.034,front+rb*0.034,front+rb*0.012,front+ra*0.012,Vector3.FORWARD)
		_quad(bore,front+ra*0.012,front+rb*0.012,back+rb*0.012,back+ra*0.012,-(ra+rb))
	bore.index()
	bore.generate_normals()
	_add(t,bore.commit(),gun,steel)

func _gun(rubber: Material) -> void:
	var b := barrel
	# M256 120 mm as the box cover shows it: a heavy boot at the mantlet, a long tapering
	# thermal sleeve with one bore-evacuator bulge a third of the way out, a single sleeve
	# joint, and the muzzle reference sensor on top at the end. (Cylinder tops face the root.)
	var sleeve := material(Color("23241f"),0.75,0.2)
	var along := Vector3(PI/2,0,0)
	cylinder(b,0.17,0.36,Vector3(0,0,-0.18),dark,along,48,0.19)
	cylinder(b,0.115,1.04,Vector3(0,0,-0.88),sleeve,along,48,0.125)
	cylinder(b,0.15,0.06,Vector3(0,0,-1.43),sleeve,along,48,0.115)
	cylinder(b,0.15,0.36,Vector3(0,0,-1.64),sleeve,along,48)
	cylinder(b,0.105,0.08,Vector3(0,0,-1.86),sleeve,along,48,0.15)
	cylinder(b,0.086,1.73,Vector3(0,0,-2.765),sleeve,along,48,0.105)
	cylinder(b,0.098,0.03,Vector3(0,0,-2.7),dark,along,48)
	var muzzle_shell := CylinderMesh.new()
	muzzle_shell.top_radius = 0.095
	muzzle_shell.bottom_radius = 0.095
	muzzle_shell.height = 0.1
	muzzle_shell.radial_segments = 48
	muzzle_shell.cap_top = false
	muzzle_shell.cap_bottom = false
	_add(b,muzzle_shell,Transform3D(Basis.from_euler(along),Vector3(0,0,-3.67)),sleeve)
	if cover_detail:
		var bore := CylinderMesh.new()
		bore.top_radius = 0.061
		bore.bottom_radius = 0.061
		bore.height = 0.27
		bore.radial_segments = 48
		bore.cap_top = false
		bore.cap_bottom = false
		var interior := material(Color("151512"),0.91)
		interior.cull_mode = BaseMaterial3D.CULL_DISABLED
		_add(b,bore,Transform3D(Basis.from_euler(along),Vector3(0,0,-3.595)),interior)
		cylinder(b,0.061,0.008,Vector3(0,0,-3.455),rubber,along,48)
		var lip := TorusMesh.new()
		lip.inner_radius = 0.061
		lip.outer_radius = 0.094
		lip.rings = 48
		lip.ring_segments = 8
		_add(b,lip,Transform3D(Basis.from_euler(along),Vector3(0,0,-3.72)),metal)
	else:
		cylinder(b,0.055,0.02,Vector3(0,0,-3.72),rubber,along,14)
	box(b,Vector3(0.06,0.07,0.12),Vector3(0,0.13,-3.6),metal)

# Welds, fasteners, lifting eyes and lens ribs supply scale where the cover's light rakes.
func _hero_hardware() -> void:
	var weld := material(Color("4c483b"),0.79)
	var worn := material(Color("716958"),0.68,0.25)
	for side in [-1.0,1.0]:
		# Fender fasteners and rolled weld along the exposed front band.
		for i in range(6):
			var x: float = side*(1.14+float(i)*0.105)
			cylinder(self,0.014,0.012,Vector3(x,1.235,NOSE-0.012),worn,Vector3(PI/2,0,0),8)
		box(self,Vector3(0.6,0.009,0.014),Vector3(side*1.44,1.30,NOSE-0.008),weld)
		# Recessed tow points below the glacis, with open rather than solid eyes.
		var eye := TorusMesh.new()
		eye.inner_radius = 0.047
		eye.outer_radius = 0.075
		eye.rings = 20
		eye.ring_segments = 8
		_add(self,eye,Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(side*0.9,0.86,-3.56)),metal)
		box(self,Vector3(0.15,0.18,0.08),Vector3(side*0.9,0.88,-3.50),dark)
		# Turret cheek weld and bolt heads along its rear joining seam.
		box(turret_root,Vector3(0.012,0.012,2.22),Vector3(side*1.704,0.75,-1.12),weld)
		for z in [-1.98,-0.14]:
			for y in [0.28,0.66]:
				cylinder(turret_root,0.022,0.013,Vector3(side*1.707,y,z),worn,Vector3(0,0,PI/2),6)
		# Bin-door seams and hinges break up the broad rear armour without invented signage.
		for z in [0.35,1.02,1.5]:
			box(turret_root,Vector3(0.009,0.49,0.009),Vector3(side*1.626,0.49,z),dark)
			cylinder(turret_root,0.022,0.1,Vector3(side*1.644,0.70,z),worn,Vector3(PI/2,0,0),8)
		# Straps around the commander's pack, following its rounded silhouette.
		box(turret_root,Vector3(0.027,0.54,0.025),Vector3(0.98+side*0.13,1.38,0.62),dark,Vector3(-0.12,0,0))

func _crew() -> void:
	var c := crew
	var shirt := cloth_material(Color("c9c9ba"))
	var vest := cloth_material(Color("1a1b18"),false,0.91)
	var khaki := cloth_material(Color("b09a76"),true)
	var helmet := material(Color("30312a"),0.83)
	var skin := skin_material()
	var lens := material(Color("242c2b"),0.28,0.08)
	var glove := cloth_material(Color("252720"),false,0.76)
	# The loader's helmet wears a dusty cloth scrim, lighter than the commander's bare shell.
	var scrim := cloth_material(Color("54534a"))
	# Commander standing in the weapon station in a white shirt under a black flak vest, left arm
	# down by his side and both gloved hands on the M2's grips, facing the camera.
	_man(c,{"hip":Vector3(0.7,0.98,0.48),"sh_l":Vector3(0.87,1.45,0.6),"sh_r":Vector3(0.58,1.4,0.26),
		"el_l":Vector3(0.96,1.17,0.58),"hand_l":Vector3(0.98,1.34,0.3),"el_r":Vector3(0.52,1.24,0.02),"hand_r":Vector3(0.74,1.36,0.02),
		"head":Vector3(0.77,1.61,0.39)},Vector3(0.72,-0.05,-0.69),shirt,vest,glove,skin,helmet,lens)
	# The M2's spade grips and back plate across his chest, between his hands.
	var grip_steel := material(Color("121311"),0.54,0.35)
	_limb(c,Vector3(0.98,1.305,0.3),Vector3(0.74,1.325,0.02),0.012,grip_steel)
	for hand in [Vector3(0.98,1.34,0.3),Vector3(0.74,1.36,0.02)]:
		_limb(c,hand-Vector3.UP*0.038,hand+Vector3.UP*0.038,0.013,grip_steel)
	box(c,Vector3(0.1,0.14,0.08),Vector3(0.86,1.35,0.16),material(Color("121311"),0.5,0.4),Vector3(0,0.85,0))
	# Weapon-station housing at chest height ahead of him, under the gun.
	box(c,Vector3(0.62,0.3,0.42),Vector3(0.82,1.06,0.0),dark,Vector3(0,-0.5,0))
	# M2 .50 cal pointed high, with its sight box and ammunition belt.
	# Swung toward the camera so its receiver side and ammunition belt show, as on the cover.
	var gun := Transform3D(Basis(Vector3.UP,-0.35)*Basis(Vector3.RIGHT,1.38),Vector3(0.75,1.2,-0.33))
	var receiver := material(Color("121311"),0.5,0.4)
	# Receiver with its feed cover, the perforated barrel jacket, barrel and flash hider.
	_add(c,_box_mesh(Vector3(0.2,0.26,0.66)),gun.translated_local(Vector3(0,0,-0.12)),receiver)
	_add(c,_box_mesh(Vector3(0.17,0.05,0.3)),gun.translated_local(Vector3(0,0.13,-0.05)),receiver)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.048
	tube.bottom_radius = 0.048
	tube.height = 0.32
	tube.radial_segments = 10
	_add(c,tube,gun*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.55)),receiver)
	var muzzle := CylinderMesh.new()
	muzzle.top_radius = 0.022
	muzzle.bottom_radius = 0.022
	muzzle.height = 0.18
	muzzle.radial_segments = 8
	_add(c,muzzle,gun*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.8)),receiver)
	_add(c,_box_mesh(Vector3(0.05,0.05,0.07)),gun.translated_local(Vector3(0,0,-0.9)),receiver)
	_add(c,_box_mesh(Vector3(0.025,0.04,0.42)),gun.translated_local(Vector3(-0.1,0.02,-0.2)),material(Color("b08a3a"),0.4,0.6))
	if cover_detail:
		# Individual cartridges follow the feed belt, with tips at the receiver.
		var brass := material(Color("86704b"),0.48,0.55)
		for i in range(9):
			var round_mesh := CylinderMesh.new()
			round_mesh.top_radius = 0.006
			round_mesh.bottom_radius = 0.011
			round_mesh.height = 0.075
			round_mesh.radial_segments = 8
			_add(c,round_mesh,gun*Transform3D(Basis(Vector3.FORWARD,PI/2),Vector3(-0.13,0.025,-0.37+float(i)*0.039)),brass)
	# The sight box turns its glass toward the cover's right, so it reads as a lit side face.
	var sight := Basis(Vector3.UP,0.15)
	_add(c,_box_mesh(Vector3(0.3,0.24,0.3)),Transform3D(sight,Vector3(0.64,1.62,-0.66)),material(Color("2c2e2f"),0.5,0.3))
	_add(c,_box_mesh(Vector3(0.24,0.18,0.02)),Transform3D(sight,Vector3(0.64,1.62,-0.66)+sight*Vector3(0,0,-0.155)),_glow(Color("53675b"),0.08))
	# Bracket carrying the sight box off the gun cradle.
	_limb(c,Vector3(0.74,1.3,-0.4),Vector3(0.66,1.5,-0.62),0.025,metal)
	_add(c,_box_mesh(Vector3(0.12,0.18,0.28)),Transform3D(Basis(),Vector3(0.93,1.2,-0.3)),material(Color("1d1e1a")))
	# Loader leans from the hips, with the neck extending naturally above the lowered
	# shoulder line. Bent elbows carry his weight into the existing hatch contacts.
	_man(c,{"hip":Vector3(-0.72,0.96,0.56),"sh_l":Vector3(-0.49,1.265,0.04),"sh_r":Vector3(-0.88,1.235,0.10),
		"el_l":Vector3(-0.36,1.04,0.15),"hand_l":Vector3(-0.58,0.858,-0.12),"el_r":Vector3(-1.02,1.035,0.19),"hand_r":Vector3(-0.96,0.858,-0.13),
		"head":Vector3(-0.68,1.36,-0.06)},Vector3(0.25,-0.45,-0.86),khaki,null,glove,skin,scrim,lens,false)

# Capsule spanning two points.
func _limb(c: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b)+radius*2.0
	capsule.radial_segments = 8 if radius < 0.015 else 16
	capsule.rings = 2 if radius < 0.015 else 5
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_add(c,capsule,Transform3D(Basis(side,up,side.cross(up)),(a+b)*0.5),mat)

# ---- Crew --------------------------------------------------------------------------------
# Joint positions (turret frame) were back-projected from the box cover's two crewmen.

# Smooth organic lofts share vertices between neighbouring rings; neck hems stay open. This is
# deliberately separate from the tank's flat-shaded armour lofts. Cubic contour
# refinement removes angular silhouettes while preserving the authored joints.
func _crew_refined_rings(rings: Array, subdivisions: int) -> Array:
	if subdivisions > 1:
		var refined: Array = []
		for row in range(rings.size()-1):
			for step in range(subdivisions):
				var t := float(step)/float(subdivisions)
				var ring: Array = []
				for i in range(rings[row].size()):
					var p: Vector3 = rings[row][i]
					ring.append(p.cubic_interpolate(rings[row+1][i],rings[maxi(row-1,0)][i],rings[mini(row+2,rings.size()-1)][i],t))
				refined.append(ring)
		refined.append(rings.back())
		return refined
	return rings

func _crew_volume(c: Node3D, rings: Array, mat: Material, xform := Transform3D(), subdivisions := 1, cap_top := true, inside := false, shared: SurfaceTool = null, cap_start := true, shared_flip := false) -> void:
	rings = _crew_refined_rings(rings,subdivisions)
	var st := SurfaceTool.new() if shared == null else shared
	if shared == null:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(0)
	var centres: Array[Vector3] = []
	for ring in rings:
		var centre := Vector3.ZERO
		for p in ring: centre += p
		centres.append(centre/float(ring.size()))
	for row in range(rings.size()-1):
		for i in range(rings[row].size()):
			var j: int = (i+1)%rings[row].size()
			var outward: Vector3 = (rings[row][i]+rings[row][j])*0.5-centres[row]
			if shared == null:
				_quad(st,rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i],-outward if inside else outward)
			else:
				var points := [rings[row][i],rings[row][j],rings[row+1][j],rings[row+1][i]]
				for index in ([0,2,1,0,3,2] if shared_flip else [0,1,2,0,2,3]): st.add_vertex(points[index])
	for end in [0,rings.size()-1]:
		if end == 0 and not cap_start: continue
		if end == rings.size()-1 and not cap_top: continue
		var normal := (centres[0]-centres[1]) if end == 0 else (centres[end]-centres[end-1])
		for i in range(rings[end].size()):
			if shared == null:
				_tri(st,centres[end],rings[end][i],rings[end][(i+1)%rings[end].size()],-normal if inside else normal)
			else:
				var points := [centres[end],rings[end][i],rings[end][(i+1)%rings[end].size()]]
				for index in ([0,2,1] if shared_flip else [0,1,2]): st.add_vertex(points[index])
	if shared == null:
		st.index()
		st.generate_normals()
		_add(c,st.commit(),xform,mat,"organic")

# A continuous sleeve follows shoulder, elbow and wrist. Uneven ring fullness makes
# compression folds on the inside of the elbow, with a distinct narrowed cuff.
func _sleeve(c: Node3D, shoulder: Vector3, elbow: Vector3, wrist: Vector3, cloth: Material, thread: Material, armhole: Array, surface: SurfaceTool, flip: bool) -> void:
	var end := wrist-(wrist-elbow).normalized()*0.035
	var root_centre := Vector3.ZERO
	for point in armhole: root_centre += point
	root_centre /= float(armhole.size())
	var upper := shoulder.lerp(elbow,0.27)
	var centres: Array[Vector3] = [root_centre.lerp(upper,0.55),upper]
	for t in [0.20,0.43,0.68,0.86]: centres.append(upper.lerp(elbow,t))
	centres.append(elbow)
	for t in [0.16,0.35,0.57,0.77,0.92,1.0]: centres.append(elbow.lerp(end,t))
	var widths := [0.067,0.069,0.069,0.067,0.063,0.059,0.057,0.059,0.054,0.050,0.046,0.042,0.041]
	var inside := ((shoulder-elbow).normalized()+(wrist-elbow).normalized()).normalized()
	var along_root := (upper-root_centre).normalized()
	var first: Vector3 = armhole[0]-root_centre
	var transported_axis := (first-along_root*first.dot(along_root)).normalized()
	var winding := signf(along_root.dot(first.cross(armhole[1]-root_centre)))
	var rings: Array = [armhole]
	for r in range(centres.size()):
		var previous: Vector3 = root_centre if r == 0 else centres[r-1]
		var along := (centres[mini(r+1,centres.size()-1)]-previous).normalized()
		transported_axis = (transported_axis-along*transported_axis.dot(along)).normalized()
		var axis := transported_axis
		var across := along.cross(axis).normalized()
		var ring: Array[Vector3] = []
		for i in range(32):
			var a := winding*TAU*float(i)/32.0
			var fold := 1.0+0.035*sin(a*3.0+float(r)*0.75)+0.020*sin(a*5.0-float(r)*0.45)
			var compression := pow(maxf(0.0,(axis*cos(a)+across*sin(a)).dot(inside)),3.0)
			fold += 0.065*sin(float(r)*2.4)*compression*exp(-pow((float(r)-6.0)/2.5,2.0))
			var point := centres[r]+(axis*cos(a)+across*sin(a)*0.91)*float(widths[r])*fold
			if r == 0: point = armhole[i].lerp(point,0.55)
			ring.append(point)
		rings.append(ring)
	# Share the exact armhole vertices with the shirt, with no buried end cap.
	# Working if both sleeves and torso form one manifold connected surface.
	_crew_volume(c,rings,cloth,Transform3D(),3,true,false,surface,false,flip)
	# A narrow folded band replaces the capsule that ballooned over the glove.
	var along := (wrist-elbow).normalized()
	var axis := along.cross(Vector3.FORWARD if absf(along.z) < 0.9 else Vector3.RIGHT).normalized()
	var across := along.cross(axis).normalized()
	rings = []
	for q in [[-0.021,0.041],[-0.018,0.043],[0.012,0.042],[0.016,0.039]]:
		var ring: Array = []
		for i in range(32):
			var a := TAU*float(i)/32.0
			ring.append(end+along*q[0]+(axis*cos(a)+across*sin(a)*0.91)*q[1])
		rings.append(ring)
	_crew_volume(c,rings,cloth)
	var edge: Array = []
	var radii: Array = []
	for i in range(33):
		var a := TAU*float(i)/32.0
		edge.append(end+along*0.009+(axis*cos(a)+across*sin(a)*0.91)*0.0425)
		radii.append(0.00055)
	_crew_tube(c,edge,radii,thread)

# Cut the two armholes from the existing torso and sew sleeves into their exact
# boundary loops. Working if smooth shoulder normals cross a real shared edge.
func _shirt_body(c: Node3D, rings: Array, joints: Dictionary, cloth: Material, lining: Material, thread: Material) -> void:
	var refined := _crew_refined_rings(rings,4)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var centres: Array[Vector3] = []
	for row in refined:
		var centre := Vector3.ZERO
		for point in row: centre += point
		centres.append(centre/float(row.size()))
	# The whole garment has one winding. Per-face radial guesses inverted
	# concave underarm/elbow triangles. Working if every shared edge opposes.
	var direction: Vector3 = (refined[0][1]-refined[0][0]).cross(refined[1][1]-refined[0][0])
	var flip := direction.dot(refined[0][0]-centres[0]) >= 0.0
	for row in range(refined.size()-1):
		for i in range(40):
			var hole := row >= 10 and row < 20 and (i < 3 or i >= 37 or (i >= 17 and i < 23))
			if hole: continue
			var next := (i+1)%40
			var points := [refined[row][i],refined[row][next],refined[row+1][next],refined[row+1][i]]
			for index in ([0,2,1,0,3,2] if flip else [0,1,2,0,2,3]): st.add_vertex(points[index])
	for i in range(40):
		_tri(st,centres[0],refined[0][i],refined[0][(i+1)%40],centres[0]-centres[1])
	for side_index in range(2):
		var column := side_index*20
		var boundary: Array = []
		for i in range(-3,3): boundary.append(refined[10][posmod(column+i,40)])
		for row in range(10,20): boundary.append(refined[row][posmod(column+3,40)])
		for i in range(3,-3,-1): boundary.append(refined[20][posmod(column+i,40)])
		for row in range(20,10,-1): boundary.append(refined[row][posmod(column-3,40)])
		var suffix := "l" if side_index == 0 else "r"
		_sleeve(c,joints["sh_"+suffix],joints["el_"+suffix],joints["hand_"+suffix],cloth,thread,boundary,st,flip)
	st.index()
	st.generate_normals()
	var mesh := st.commit()
	_add(c,mesh,Transform3D(),cloth,"organic")
	# The same joined geometry supplies the opaque inner collar lining.
	var arrays := mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for i in range(normals.size()): normals[i] = -normals[i]
	arrays[Mesh.ARRAY_NORMAL] = normals
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i in range(0,indices.size(),3):
		var swap := indices[i]
		indices[i] = indices[i+2]
		indices[i+2] = swap
	arrays[Mesh.ARRAY_INDEX] = indices
	var interior := ArrayMesh.new()
	interior.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_add(c,interior,Transform3D(),lining,"organic")

# Flat woven straps follow their centreline with a transported width direction.
func _crew_webbing(c: Node3D, points: Array, width: float, thickness: float, outward: Vector3, mat: Material, subdivisions := 3) -> void:
	var rings: Array = []
	var across := Vector3.ZERO
	for r in range(points.size()):
		var tangent: Vector3 = (points[mini(r+1,points.size()-1)]-points[maxi(r-1,0)]).normalized()
		if r == 0:
			across = tangent.cross(outward).normalized()
		else:
			across = (across-tangent*across.dot(tangent)).normalized()
		var normal := across.cross(tangent).normalized()
		var ring: Array = []
		for q in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
			ring.append(points[r]+across*q.x*width+normal*q.y*thickness)
		rings.append(ring)
	_crew_volume(c,rings,mat,Transform3D(),subdivisions)

# A continuous folded shirt collar is rooted around the actual open neck hem.
# Its front ends taper onto the chest; there are no separate floating collar leaves.
func _shirt_collar(c: Node3D, centre: Vector3, up: Vector3, side: Vector3, forward: Vector3, cloth: Material, thread: Material) -> void:
	var front: Array = [[],[],[],[]]
	var back: Array = [[],[],[],[]]
	var start := PI*0.5+0.55
	var finish := PI*2.5-0.55
	const STEPS := 56
	for i in range(STEPS+1):
		var a := lerpf(start,finish,float(i)/float(STEPS))
		var radial := (side*cos(a)+forward*sin(a)).normalized()
		var dip := 0.045*pow(maxf(0.0,sin(a)),8.0)
		var root_at := centre+up*(0.018-dip)+side*cos(a)*0.075+forward*sin(a)*0.062
		var tip := exp(-pow((a-start)/0.35,2))+exp(-pow((a-finish)/0.35,2))
		var section := [root_at,root_at+up*0.016+radial*0.001,
			root_at+up*0.014+radial*0.016,
			root_at+up*(0.004-0.028*tip)+radial*0.035+forward*0.022*tip]
		var normals := [radial,(radial+up).normalized(),up,(up*0.8+radial*0.2).normalized()]
		for row in range(4):
			front[row].append(section[row])
			back[row].append(section[row]-normals[row]*0.0012)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for row in range(3):
		for i in range(STEPS):
			var a := lerpf(start,finish,(float(i)+0.5)/float(STEPS))
			var radial := (side*cos(a)+forward*sin(a)).normalized()
			var outward: Vector3 = [radial,(radial+up).normalized(),up][row]
			_quad(st,front[row][i],front[row][i+1],front[row+1][i+1],front[row+1][i],outward)
			_quad(st,back[row][i],back[row+1][i],back[row+1][i+1],back[row][i+1],-outward)
	for i in range(STEPS):
		var a := lerpf(start,finish,(float(i)+0.5)/float(STEPS))
		var radial := (side*cos(a)+forward*sin(a)).normalized()
		_quad(st,back[0][i],back[0][i+1],front[0][i+1],front[0][i],-radial)
		_quad(st,front[3][i],front[3][i+1],back[3][i+1],back[3][i],radial)
	for end in [0,STEPS]:
		var a := start if end == 0 else finish
		var outward := (-side*sin(a)+forward*cos(a))*(-1.0 if end == 0 else 1.0)
		for row in range(3):
			_quad(st,front[row][end],front[row+1][end],back[row+1][end],back[row][end],outward)
	st.index()
	st.generate_normals()
	_add(c,st.commit(),Transform3D(),cloth,"organic")
	var seam: Array = []
	var radii: Array = []
	for point in front[3]:
		seam.append(point+up*0.0005)
		radii.append(0.0004)
	_crew_tube(c,seam,radii,thread)

# Continuous tapered finger tubes keep the knuckles smooth. Capsules at every joint
# created swollen beads and deep intersection shadows at this camera distance.
func _crew_tube(c: Node3D, points: Array, radii: Array, mat: Material, round_tip := false) -> void:
	if round_tip:
		points = points.duplicate()
		radii = radii.duplicate()
		var tip: Vector3 = points.back()
		var tangent: Vector3 = (tip-points[points.size()-2]).normalized()
		var radius: float = radii.back()
		# A hemispherical fingertip retains its width before turning smoothly inward.
		for angle in [PI/6.0,PI/3.0,PI/2.0-0.06]:
			points.append(tip+tangent*radius*sin(angle))
			radii.append(radius*cos(angle))
	var rings: Array = []
	var side := Vector3.ZERO
	for r in range(points.size()):
		var tangent: Vector3 = (points[mini(r+1,points.size()-1)]-points[maxi(0,r-1)]).normalized()
		if r == 0:
			side = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT).normalized()
		else:
			side = (side-tangent*side.dot(tangent)).normalized()
		var other := tangent.cross(side).normalized()
		var ring: Array = []
		for i in range(16):
			var a := TAU*float(i)/16.0
			ring.append(points[r]+(side*cos(a)+other*sin(a))*float(radii[r]))
		rings.append(ring)
	_crew_volume(c,rings,mat,Transform3D(),2)

func _hand(c: Node3D, at: Vector3, elbow: Vector3, view: Vector3, glove: Material, handed: float, braced := false) -> void:
	var approach := (at-elbow).normalized()
	var cuff_side := approach.cross(Vector3.FORWARD if absf(approach.z) < 0.9 else Vector3.RIGHT).normalized()
	var cuff_up := approach.cross(cuff_side).normalized()
	var cuff: Array = []
	for q in [[-0.048,0.035],[-0.030,0.036],[-0.010,0.033],[0.008,0.030]]:
		var ring: Array = []
		for i in range(24):
			var a := TAU*float(i)/24.0
			ring.append(at+approach*q[0]+(cuff_side*cos(a)+cuff_up*sin(a)*0.90)*q[1])
		cuff.append(ring)
	_crew_volume(c,cuff,glove,Transform3D(),3)
	var across := Vector3.UP
	var normal := Vector3(view.x,0,view.z).normalized()
	var forward := normal.cross(across).normalized()*handed
	if braced:
		normal = Vector3.UP
		forward = Vector3(at.x-elbow.x,0,at.z-elbow.z).normalized()
		across = forward.cross(normal).normalized()
	else:
		# Let the wrist approach its handle from the elbow, with the back of the glove visible.
		if forward.dot(approach) < 0.0: forward = -forward
	var rings: Array = []
	# Wrist, palm heel, metacarpals and the knuckle line have distinct cross-sections.
	var shape := [[-0.062,0.024,0.015],[-0.044,0.032,0.020],[-0.022,0.039,0.023],
		[0.0,0.041,0.021],[0.017,0.035,0.017]]
	for r in shape:
		var ring: Array = []
		var centre: Vector3 = at+forward*r[0]+normal*(0.024 if not braced else 0.013)
		for i in range(20):
			var a := TAU*float(i)/20.0
			ring.append(centre+across*cos(a)*r[1]+normal*sin(a)*r[2])
		rings.append(ring)
	_crew_volume(c,rings,glove,Transform3D(),3)
	# Quiet stitched reinforcement panels distinguish cloth gloves from smooth mittens.
	var seam := material(Color("414336"),0.96)
	for edge in [-1.0,1.0]:
		var points: Array = []
		for p in [Vector3(-0.046,0.018,0.040),Vector3(-0.023,0.025,0.047),Vector3(0.005,0.024,0.044)]:
			points.append(at+forward*p.x+across*p.y*edge+normal*(p.z if not braced else p.z-0.012))
		_crew_tube(c,points,[0.0013,0.0013,0.0013],seam)

	for finger in range(4):
		var root_at := at+across*(float(finger)-1.5)*0.016
		if braced: root_at += forward*float([-0.001,0.005,0.002,-0.007][finger])
		var points: Array = []
		var radii: Array = []
		var length_scale: float = [0.97,1.06,1.01,0.84][finger]
		for joint in range(9):
			var t := float(joint)/8.0
			if braced:
				points.append(root_at+forward*(0.012+t*0.055*length_scale)+across*(float(finger)-1.5)*0.0015*t+normal*(0.015+0.002*sin(t*PI)-0.016*t*t))
			else:
				var a := -0.32+t*2.75
				points.append(root_at+normal*cos(a)*0.028+forward*sin(a)*0.029*length_scale)
			radii.append(lerpf(0.0105,0.0065,t)*(1.0+0.04*sin(t*PI*3.0)))
		_crew_tube(c,points,radii,glove,true)
	var thumb_root := at-across*handed*0.039-forward*0.037+normal*0.022
	var thumb_joint := at-across*handed*0.035+forward*0.009+normal*0.019
	var thumb_tip := at-across*handed*0.018+forward*0.032+normal*(0.002 if not braced else 0.012)
	_crew_tube(c,[thumb_root,thumb_root.lerp(thumb_joint,0.5),thumb_joint,thumb_joint.lerp(thumb_tip,0.6),thumb_tip],[0.014,0.014,0.012,0.010,0.0075],glove,true)

# A flared neck emerges from the shirt and narrows under the jaw. Its centreline
# follows the head, instead of leaving a vertical stalk below a forward-set face.
func _neck(c: Node3D, shoulders: Vector3, head: Vector3, body_up: Vector3, look: Vector3, skin: Material) -> void:
	var face_forward := look.normalized()
	var right := body_up.cross(face_forward).normalized()
	var head_up := face_forward.cross(right).normalized()
	var base := shoulders-body_up*0.055
	var top := head-head_up*0.086-face_forward*0.020
	var rings: Array = []
	for r in [[0.0,0.080,0.061],[0.2,0.067,0.054],[0.43,0.051,0.044],[0.68,0.049,0.043],[1.0,0.057,0.050]]:
		var centre: Vector3 = base.lerp(top,r[0])
		var ring: Array = []
		for i in range(32):
			var a := TAU*float(i)/32.0
			var front := maxf(0.0,sin(a))
			var throat: float = 0.003*sin(r[0]*PI)*pow(front,8.0)
			ring.append(centre+right*cos(a)*r[1]+face_forward*(sin(a)*r[2]+throat))
		rings.append(ring)
	_crew_volume(c,rings,skin,Transform3D(),3)

# Smooth facial proportions, in head-local coordinates. The nose, cheekbones,
# eye sockets, lips and chin are sculpted into one surface, without intersecting beads.
const FACE_PROFILE := [[-0.126,0.032,0.038,0.013],[-0.113,0.049,0.057,0.009],[-0.094,0.064,0.069,0.003],
	[-0.068,0.070,0.078,-0.002],[-0.032,0.080,0.083,-0.004],[0.006,0.083,0.089,-0.007],
	[0.042,0.081,0.085,-0.012],[0.080,0.070,0.074,-0.020],[0.108,0.044,0.050,-0.024],[0.126,0.009,0.012,-0.022]]

func _face_point(y: float, a: float) -> Vector3:
	var profile := FACE_PROFILE

	var index := 0
	while index < profile.size()-2 and y > float(profile[index+1][0]): index += 1
	var t := clampf((y-float(profile[index][0]))/float(profile[index+1][0]-profile[index][0]),0,1)
	var samples: Array[Vector3] = []
	for k in range(-1,3):
		var r: Array = profile[clampi(index+k,0,profile.size()-1)]
		samples.append(Vector3(r[1],r[2],r[3]))
	var q := 0.5*(2.0*samples[1]+(-samples[0]+samples[2])*t+(2.0*samples[0]-5.0*samples[1]+4.0*samples[2]-samples[3])*t*t+(-samples[0]+3.0*samples[1]-3.0*samples[2]+samples[3])*t*t*t)
	var x := cos(a)*q.x
	var z := sin(a)*q.y+q.z
	var front := smoothstep(0.15,0.65,sin(a))
	# Gaussians blend broad anatomical planes; high-frequency pores would alias at menu scale.
	var cheek := 0.009*exp(-pow((absf(x)-0.052)/0.025,2))*exp(-pow((y+0.024)/0.031,2))
	var socket := -0.011*exp(-pow((absf(x)-0.034)/0.019,2))*exp(-pow((y-0.004)/0.018,2))
	var bridge := 0.020*exp(-pow(x/0.012,2))*exp(-pow((y+0.011)/0.045,2))
	var nose := 0.027*exp(-pow(x/0.018,2))*exp(-pow((y+0.039)/0.016,2))
	var alae := 0.012*exp(-pow((absf(x)-0.019)/0.010,2))*exp(-pow((y+0.046)/0.012,2))
	var nostril := -0.003*exp(-pow((absf(x)-0.014)/0.006,2))*exp(-pow((y+0.052)/0.0035,2))
	var mouth := 0.006*exp(-pow(x/0.034,4))*exp(-pow((y+0.073)/0.015,2))
	var mouth_line := -0.074+0.0025*pow(minf(absf(x)/0.033,1.0),2)
	var lips := 0.0030*exp(-pow(x/0.027,4)-pow((y-mouth_line-0.004)/0.0032,2))
	lips += 0.0040*exp(-pow(x/0.029,4)-pow((y-mouth_line+0.0037)/0.004,2))
	lips -= 0.0023*exp(-pow(x/0.031,6)-pow((y-mouth_line)/0.0012,2))
	var philtrum := -0.0018*exp(-pow(x/0.004,2)-pow((y+0.060)/0.007,2))
	var fold := -0.0016*exp(-pow((absf(x)-(0.025+0.2*(-y-0.045)))/0.005,2)-pow((y+0.060)/0.020,2))
	var chin := 0.009*exp(-pow(x/0.031,2))*exp(-pow((y+0.106)/0.014,2))
	z += front*(cheek+socket+bridge+nose+alae+nostril+mouth+lips+philtrum+fold+chin)
	return Vector3(x,y,z)

func _face_mesh() -> ArrayMesh:
	if _skin_face_mesh != null:
		return _skin_face_mesh
	const SIDES := 128
	const ROWS := 129
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for r in range(ROWS):
		var y := lerpf(-0.126,0.126,float(r)/float(ROWS-1))
		for i in range(SIDES):
			var a := TAU*float(i)/float(SIDES)
			var point := _face_point(y,a)
			vertices.append(point)
			var tangent := _face_point(y,a+0.001)-_face_point(y,a-0.001)
			var vertical := _face_point(minf(y+0.001,0.126),a)-_face_point(maxf(y-0.001,-0.126),a)
			normals.append(vertical.cross(tangent).normalized())
			var front := smoothstep(0.2,0.8,sin(a))
			var blush := exp(-pow((absf(point.x)-0.05)/0.032,2)-pow((y+0.025)/0.037,2))*front
			var lip := exp(-pow(point.x/0.03,4)-pow((y+0.074)/0.008,2))*front
			var beard := (1.0-smoothstep(-0.095,-0.028,y))*front*(1.0-lip)
			var mouth_line := -0.074+0.0025*pow(minf(absf(point.x)/0.033,1.0),2)
			var seam := exp(-pow(point.x/0.031,6)-pow((y-mouth_line)/0.0016,2))*front
			var nostril := exp(-pow((absf(point.x)-0.014)/0.006,2)-pow((y+0.052)/0.0028,2))*front
			var cavity := maxf(seam*0.24,nostril*0.50)
			colors.append(Color(1.0-0.10*beard,1.0-0.06*blush-0.13*lip-0.09*beard,1.0-0.08*blush-0.13*lip-0.07*beard)*(1.0-cavity))
	for r in range(ROWS-1):
		for i in range(SIDES):
			var a := r*SIDES+i
			var b := r*SIDES+(i+1)%SIDES
			var c := b+SIDES
			var d := a+SIDES
			indices.append_array(PackedInt32Array([a,b,c,a,c,d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_skin_face_mesh = mesh
	return mesh

## Joint positions remain in the cover's turret frame. The shirt is a smooth tailored
## volume, with connected sleeves rather than overlapping shoulder and elbow capsules.
func _man(c: Node3D, j: Dictionary, look: Vector3, shirt: Material, vest: Material, glove: Material, skin: Material, helmet: Material, lens: Material, goggles := true) -> void:
	_anatomy_active = crew_rig != null
	var hip: Vector3 = j.hip
	var sh_l: Vector3 = j.sh_l
	var sh_r: Vector3 = j.sh_r
	var sh_c := (sh_l+sh_r)*0.5
	var up := (sh_c-hip).normalized()
	var side := sh_l-sh_r
	side = (side-up*side.dot(up)).normalized()
	var fwd := side.cross(up).normalized()
	if fwd.dot(look) < 0.0: fwd = -fwd
	var half := sh_l.distance_to(sh_r)*0.5
	var depth := half*0.69
	var thread := material(Color("a6a89a") if goggles else Color("88785d"),0.98)
	var ring := func(t: float, w: float, d: float, push: float) -> Array:
		var pts: Array = []
		var centre := hip.lerp(sh_c,t)+fwd*push
		for i in range(40):
			var a := TAU*float(i)/40.0
			var ease := 1.0+0.022*sin(a*5.0+t*7.0)
			pts.append(centre+side*cos(a)*w*ease+fwd*sin(a)*d*ease)
		return pts
	var shape := [[0.0,0.72,0.8,0.0],[0.22,0.80,0.88,0.01],[0.5,0.88,0.95,0.02],
		[0.74,0.96,0.94,0.02],[0.90,0.94,0.82,0.0],[1.0,0.65,0.57,-0.01]]
	var rings: Array = []
	for r in shape: rings.append(ring.call(r[0],half*r[1],depth*r[2],r[3]))
	# A shoulder yoke rolls into an open, V-dipped neck hem. No cap crosses the neck.
	for q in [[0.008,0.105,0.078],[0.018,0.075,0.062],[0.015,0.072,0.059]]:
		var rim: Array = []
		for i in range(40):
			var a := TAU*float(i)/40.0
			var dip := 0.045*pow(maxf(0.0,sin(a)),8.0)
			rim.append(sh_c+up*(q[0]-dip)+side*cos(a)*q[1]+fwd*sin(a)*q[2])
		rings.append(rim)
	# Keep the established collar opening, with a continuous sewn shoulder.
	var lining := cloth_material(Color("777b6e") if goggles else Color("71654f"),false,0.98)
	_shirt_body(c,rings,j,shirt,lining,thread)
	if vest != null:
		var v := [[0.04,0.78,0.86,0.0],[0.4,0.85,0.97,0.02],[0.72,0.87,1.02,0.035],[0.90,0.69,0.89,0.015]]
		rings = []
		for r in v: rings.append(ring.call(r[0],half*r[1],depth*r[2],r[3]))
		_crew_volume(c,rings,vest,Transform3D(),4)
		var strap := cloth_material(Color("24261f"),false,0.92)
		var web_thread := material(Color("3e4034"),0.98)
		for sign_at in [-1.0,1.0]:
			var points: Array = []
			var column := int(round(acos(sign_at*0.52)/TAU*40.0))
			for row in rings: points.append(row[column]+fwd*0.004)
			_crew_webbing(c,points,0.034,0.003,fwd,strap)
			for edge in [-1.0,1.0]:
				var seam: Array = []
				var radii: Array = []
				for point in points:
					seam.append(point+side*edge*0.013+fwd*0.002)
					radii.append(0.0006)
				_crew_tube(c,seam,radii,web_thread)
	else:
		# Sample every authored shirt subdivision, including its neighbouring rings.
		# A separately interpolated four-point path bowed away from the chest.
		var placket: Array = []
		for row in range(1,5):
			for step in range(4):
				var t := float(step)/4.0
				var point: Vector3 = rings[row][10]
				point = point.cubic_interpolate(rings[row+1][10],rings[row-1][10],rings[mini(row+2,rings.size()-1)][10],t)
				placket.append(point+fwd*0.0007)
		_crew_webbing(c,placket,0.018,0.001,fwd,shirt,1)
		for edge in [-1.0,1.0]:
			var seam: Array = []
			var radii: Array = []
			for point in placket:
				seam.append(point+side*edge*0.006+fwd*0.0008)
				radii.append(0.00035)
			_crew_tube(c,seam,radii,thread)
		var button := SphereMesh.new()
		button.radius = 0.0025
		button.height = 0.005
		button.radial_segments = 12
		button.rings = 6
		var button_material := material(Color("685e4b"),0.96)
		for index in [3,7,11]:
			_add(c,button,Transform3D(Basis(),placket[index]+fwd*0.0015),button_material)
	_shirt_collar(c,sh_c,up,side,fwd,shirt,thread)
	for k in [["sh_l","el_l","hand_l"],["sh_r","el_r","hand_r"]]:
		_hand(c,j[k[2]],j[k[1]],look,glove,1.0 if k[0] == "sh_l" else -1.0,not goggles)
	var head_at: Vector3 = j.head
	_neck(c,sh_c,head_at,up,look,skin)
	_head(c,head_at,up,look,skin,helmet,lens,goggles)
	_anatomy_active = false

## The face is one continuous coloured surface. A fitted helmet leaves its brow,
## jaw and cheeks readable, with a head basis that follows each crewman's gaze.
func _head(c: Node3D, at: Vector3, up: Vector3, look: Vector3, skin: Material, helmet: Material, lens: Material, goggles := true) -> void:
	var fwd := look.normalized()
	var right := up.cross(fwd).normalized()
	up = fwd.cross(right).normalized()
	var basis := Basis(right,up,fwd)
	var place := func(v: Vector3) -> Vector3: return at+basis*v
	var put := func(mesh: Mesh, scale_by: Vector3, v: Vector3, mat: Material, turn := Basis()) -> void:
		_add(c,mesh,Transform3D(basis*turn*Basis().scaled(scale_by),place.call(v)),mat)
	_add(c,_face_mesh(),Transform3D(basis,at),skin,"anatomy")
	var feature := SphereMesh.new()
	feature.radius = 1.0
	feature.height = 2.0
	feature.radial_segments = 20
	feature.rings = 10
	for sign_at in [-1.0,1.0]:
		put.call(feature,Vector3(0.014,0.027,0.012),Vector3(sign_at*0.083,-0.009,-0.014),skin)
	# Helmet rim, crown and back follow a single fitted shell. The rear drops over the nape.
	# A fitted shell leaves padding around the skull without ballooning over it.
	# Working if shell, rim, ear cups and straps retain their shared contact line.
	var helmet_fit := Vector3(0.91,0.97,0.94)
	var rings: Array = []
	var shell := [[0.018,0.132,0.142],[0.052,0.146,0.153],[0.092,0.139,0.146],[0.127,0.111,0.119],[0.151,0.065,0.074],[0.160,0.007,0.010]]
	for r in shell:
		var ring: Array = []
		for i in range(80):
			var a := TAU*float(i)/80.0
			var back := minf(0.0,sin(a))
			var y: float = r[0]+(0.068*back if r[0] < 0.06 else 0.0)
			var fold := 1.0+(0.028*sin(a*5.0+r[0]*45.0) if not goggles else 0.0)
			ring.append(Vector3(cos(a)*r[1]*fold,y,sin(a)*r[2]*fold-0.016)*helmet_fit)
		rings.append(ring)
	_crew_volume(c,rings,helmet,Transform3D(basis,at),4)
	# Stitched panel seams sit on the loader's cloth helmet cover, rather than extra balls.
	if not goggles:
		var stitching := material(Color("44463b"),0.98)
		for sign_at in [-1.0,1.0]:
			var seam_points: Array = []
			var seam_radii: Array = []
			# Sample the actual shell, front to crown to nape, so stitches cannot float.
			for back in [false,true]:
				var column := int(round((PI*1.5-sign_at*0.36 if back else PI*0.5+sign_at*0.36)/TAU*80.0))
				for step in range(rings.size()):
					var row: int = rings.size()-1-step if back else step
					var point: Vector3 = rings[row][column]
					point += Vector3(point.x,0.04,point.z+0.016).normalized()*0.0018
					seam_points.append(place.call(point))
					seam_radii.append(0.0012)
			_crew_tube(c,seam_points,seam_radii,stitching)
	var padding := cloth_material(Color("20221e"),false,0.96)
	var rim_points: Array = []
	var rim_radii: Array = []
	for i in range(81):
		var a := TAU*float(i)/80.0
		rim_points.append(place.call(Vector3(cos(a)*0.133,0.018+0.068*minf(0.0,sin(a)),sin(a)*0.143-0.016)*helmet_fit))
		rim_radii.append(0.006)
	_crew_tube(c,rim_points,rim_radii,padding)
	# Dished ear-cup shells, attached to the lower rim with fabric suspension straps.
	var cup := SphereMesh.new()
	cup.radius = 1.0
	cup.height = 2.0
	cup.radial_segments = 24
	cup.rings = 12
	for sign_at in [-1.0,1.0]:
		put.call(cup,Vector3(0.025,0.056,0.045),Vector3(sign_at*0.130,-0.023,-0.015)*helmet_fit,padding)
		put.call(cup,Vector3(0.025,0.047,0.038),Vector3(sign_at*0.144,-0.021,-0.017)*helmet_fit,helmet)
		_limb(c,place.call(Vector3(sign_at*0.124,0.08,-0.016)*helmet_fit),place.call(Vector3(sign_at*0.15,-0.01,-0.016)*helmet_fit),0.009,padding)
	# Flat chin webbing follows the jaw and meets below the chin on both crewmen.
	for sign_at in [-1.0,1.0]:
		var points: Array = []
		for point in [Vector3(sign_at*0.13,-0.065,-0.015)*helmet_fit,Vector3(sign_at*0.07,-0.101,0.018),Vector3(sign_at*0.028,-0.126,0.030),Vector3(0,-0.128,0.030)]:
			points.append(place.call(point))
		_crew_webbing(c,points,0.008,0.002,basis*Vector3(sign_at,0,0),padding)
	if cover_detail:
		var wire := material(Color("24251f"),0.64,0.2)
		_crew_tube(c,[place.call(Vector3(0.15,-0.04,0.02)*helmet_fit),place.call(Vector3(0.10,-0.065,0.10)),place.call(Vector3(0.027,-0.071,0.113))],[0.0035,0.0035,0.003],wire)
		put.call(feature,Vector3(0.011,0.007,0.008),Vector3(0.020,-0.071,0.113),padding)
	if not goggles:
		# Deep-set eyes and narrow lids remain quiet beneath the loader's helmet brow.
		var sclera := material(Color("a29a83"),0.72)
		var iris := material(Color("312b22"),0.63)
		for sign_at in [-1.0,1.0]:
			put.call(feature,Vector3(0.012,0.005,0.005),Vector3(sign_at*0.033,0.006,0.067),sclera)
			put.call(feature,Vector3(0.0035,0.0035,0.0015),Vector3(sign_at*0.033,0.006,0.072),iris)
			for lid in [-1.0,1.0]:
				var points: Array = []
				for i in range(7):
					var t := float(i)/6.0
					points.append(place.call(Vector3(sign_at*0.033+lerpf(-0.012,0.012,t),0.006+sin(t*PI)*0.004*lid,0.073)))
				_crew_tube(c,points,[0.0011,0.0014,0.0016,0.0016,0.0016,0.0014,0.0011],skin)
		return
	# Two shallow, canted lenses sit in a continuous rubber frame. No spherical eye bulges.
	var lens_profile := [Vector2(-0.05,-0.014),Vector2(-0.039,-0.026),Vector2(0.026,-0.024),
		Vector2(0.050,-0.006),Vector2(0.047,0.017),Vector2(0.030,0.024),Vector2(-0.035,0.023),Vector2(-0.052,0.011)]
	for iteration in range(2):
		var rounded: Array = []
		for i in range(lens_profile.size()):
			var a: Vector2 = lens_profile[i]
			var b: Vector2 = lens_profile[(i+1)%lens_profile.size()]
			rounded.append(a.lerp(b,0.17))
			rounded.append(a.lerp(b,0.83))
		lens_profile = rounded
	for sign_at in [-1.0,1.0]:
		var strap: Array = []
		for point in [Vector3(sign_at*0.097,-0.004,0.090),Vector3(sign_at*0.124,-0.004,0.052)*helmet_fit,Vector3(sign_at*0.139,-0.004,0.004)*helmet_fit]:
			strap.append(place.call(point))
		_crew_webbing(c,strap,0.013,0.0025,basis*Vector3(sign_at,0,0),padding)
		var lens_at := Vector3(sign_at*0.046,-0.004,0.088)
		var turn := Basis(Vector3.UP,sign_at*0.19)
		for layer in [0,1]:
			var border := 1.0 if layer == 0 else 0.85
			var front: Array = []
			var back: Array = []
			for p in lens_profile:
				front.append(lens_at+turn*Vector3(p.x*border,p.y*border,0.021+float(layer)*0.004))
				back.append(lens_at+turn*Vector3(p.x*border,p.y*border,0.008+float(layer)*0.004))
			_crew_volume(c,[front,back],padding if layer == 0 else lens,Transform3D(basis,at))
	put.call(feature,Vector3(0.016,0.009,0.014),Vector3(0,0.0,0.114),padding)

# Flat convex polygon facing the given direction (markings and small plates).
func _flat(frame: Node3D, pts: Array, outward: Vector3, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(1,pts.size()-1):
		_tri(st,pts[0],pts[i],pts[i+1],outward)
	st.generate_normals()
	_add(frame,st.commit(),Transform3D(),mat,"facet")

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := material(color,0.2)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func update_pose(relative_turret: float, delta: float, elevation := 0.0, gun_yaw := 0.0) -> void:
	turret_root.rotation.y = relative_turret
	recoil = move_toward(recoil, 0.0, delta*1.8)
	barrel.position = GUN_ROOT + barrel.basis.z*recoil
	barrel.rotation = Vector3(elevation,gun_yaw,0)
