extends Node3D
## Decorative geometry only. Same-frame source ownership always wins.
const Surface = preload("res://scripts/pc_surface_geometry.gd")
const Terrain = preload("res://scripts/pc_terrain_style.gd")
const ShaderSource = preload("res://scripts/pc_tactical_foliage.gdshader")
# Shrub and grass planting: grid spacing and radius in source units.
const LAYERS := [[220.0,3200.0],[48.0,850.0]]
# 12 transform floats (3x4 row-major) plus 4 custom floats per instance.
const STRIDE := 16
var plants: Array[MultiMeshInstance3D] = []
var material: ShaderMaterial
var instance_count := 0
var _grid_centers: Array[Vector2i] = [Vector2i.ZERO,Vector2i.ZERO]
var _grid_cache: Array = [[],[]]
var _grid_build_count := 0
var _buffers: Array[PackedFloat32Array] = []
var _allowed_bytes := PackedByteArray()
var _allowed_texture: ImageTexture

func _init() -> void:
	material = ShaderMaterial.new()
	material.shader = ShaderSource
	material.render_priority = 1
	var meshes := [_authored_mesh("shrub"),_authored_mesh("grass")]
	for layer in 2:
		var node := MultiMeshInstance3D.new()
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.use_custom_data = true
		node.multimesh.mesh = meshes[layer]
		# Allocate the whole planting grid once. Each rebuild uploads one buffer
		# and draws its leading visible_instance_count, never reallocating.
		var cells: int = 2*ceili(LAYERS[layer][1]/LAYERS[layer][0])+1
		node.multimesh.instance_count = cells*cells
		node.multimesh.visible_instance_count = 0
		var buffer := PackedFloat32Array()
		buffer.resize(cells*cells*STRIDE)
		_buffers.append(buffer)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		plants.append(node)
	visible = false

# Optional Blender-authored presentation meshes. Every absent or malformed asset
# falls back independently, without changing the source admission/planting path.
const WORLD_AUTHOR_SHA := "76788548500753d8f38fa4eb925544f38c237adb1c4439b9dd505d9f44512e9f"
static func _authored_mesh(name: String) -> ArrayMesh:
	var path := "res://assets/tactical_world_v1/"+name+".tres"
	if ResourceLoader.exists(path):
		var candidate: Resource = load(path)
		if candidate is ArrayMesh and _valid_authored_mesh(candidate,name): return candidate
	return _shrub() if name=="shrub" else _grass()

static func _valid_authored_mesh(mesh: ArrayMesh, name: String) -> bool:
	if mesh.get_meta("tactical_world_revision",0)!=1 or mesh.get_meta("author_sha256","")!=WORLD_AUTHOR_SHA: return false
	if mesh.get_surface_count()!=1 or mesh.surface_get_primitive_type(0)!=Mesh.PRIMITIVE_TRIANGLES: return false
	var arrays:=mesh.surface_get_arrays(0)
	if not arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array or not arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array or not arrays[Mesh.ARRAY_TEX_UV] is PackedVector2Array or not arrays[Mesh.ARRAY_TEX_UV2] is PackedVector2Array: return false
	if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty(): return false
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	var tags: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
	if vertices.size()<6 or vertices.size()>(2100 if name=="shrub" else 480) or vertices.size()%3!=0: return false
	if normals.size()!=vertices.size() or tags.size()!=vertices.size() or uv.size()!=vertices.size(): return false
	var radius:=25.0 if name=="shrub" else 5.0
	var height:=12.5 if name=="shrub" else 11.0
	var footprint: Array[Vector3]=[Vector3(-radius,.08,-radius),Vector3(radius,.08,-radius),Vector3(radius,.08,radius),Vector3(-radius,.08,-radius),Vector3(radius,.08,radius),Vector3(-radius,.08,radius)]
	for i in vertices.size():
		var p:=vertices[i];var n:=normals[i];var tag:=tags[i]
		if not p.is_finite() or not n.is_finite() or not uv[i].is_finite() or not tag.is_finite(): return false
		if absf(p.x)>radius+.001 or absf(p.z)>radius+.001 or p.y<-.001 or p.y>height: return false
		if n.length_squared()<.90 or n.length_squared()>1.10: return false
		var kind:=floorf(tag.x*2.0)/2.0
		if kind not in [0.0,0.5,1.0] or tag.y<.7 or tag.y>1.1: return false
		var axis:float=(tag.x-kind)*16.0
		if not is_equal_approx(axis,roundf(axis)) or axis<0.0 or axis>2.0: return false
		if i<6:
			if not p.is_equal_approx(footprint[i]) or kind!=1.0: return false
		elif kind==1.0:return false
	return true

func set_material_atlas(atlas: Texture2D) -> void:
	material.set_shader_parameter("tactical_realism_ready",atlas!=null)
	if atlas!=null:material.set_shader_parameter("tactical_realism_atlas",atlas)

# UV2 selects leaves, bark or the soft ground footprint without the instance
# colour modulation used by MultiMesh. All three
# share the same two batches and the same source-ownership gate.
static func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, kind: float, tone: float=1.0, round_center: Vector3=Vector3.ZERO, roundness: float=0.0) -> void:
	var face_normal:=(c-a).cross(b-a).normalized()
	var dominant:=face_normal.abs()
	var axis:int=0 if dominant.x>dominant.y and dominant.x>dominant.z else 1 if dominant.y>dominant.z else 2
	# Fractional axis bits stay within the incumbent leaf/bark/footprint bands.
	st.set_uv2(Vector2(kind+float(axis)/16.0,tone))
	for point: Vector3 in [a,b,c]:
		# Leaf clusters retain facets, with a soft transition over their volume.
		st.set_normal(face_normal.lerp((point-round_center).normalized(),roundness).normalized())
		st.set_uv(Vector2(point.x,point.z)/25.0)
		st.add_vertex(point)

static func _footprint(st: SurfaceTool, radius: float) -> void:
	var a:=Vector3(-radius,0.08,-radius)
	var b:=Vector3(radius,0.08,-radius)
	var c:=Vector3(radius,0.08,radius)
	var d:=Vector3(-radius,0.08,radius)
	_triangle(st,a,b,c,1.0)
	_triangle(st,a,c,d,1.0)

static func _shrub() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_footprint(st,25.0)
	var offsets: Array[Vector3]=[Vector3(-9,11,0),Vector3(7,13,3),Vector3(0,17,-4),Vector3(-2,10,8),Vector3(5,8,-9)]
	for lobe in offsets.size():
		var at: Vector3=offsets[lobe]
		# Low, rooted scrub rather than raised miniature trees. Retain each
		# footprint and horizontal lobe position; shorten the stems and crown.
		at.y=at.y*0.38+0.8
		var lower:=PackedVector3Array()
		var upper:=PackedVector3Array()
		var height:=(5.0+float(lobe%3))*0.72
		for i in 6:
			var angle:=TAU*float(i)/6.0+float(lobe)*1.7
			var radius:=5.0+float((i*3+lobe)%5)*0.85
			lower.append(at+Vector3(cos(angle)*radius,-height*0.35,sin(angle)*radius))
			upper.append(at+Vector3(cos(angle)*radius*0.84,height*0.48,sin(angle)*radius*0.84))
		for i in 6:
			var next: int=(i+1)%6
			# Two shoulder rings break the old pointed diamond silhouette.
			for face: Array in [[at+Vector3(0.6,height,-0.5),upper[i],upper[next]],
					[upper[i],lower[i],lower[next]],[upper[i],lower[next],upper[next]],
					[at-Vector3(0,height*0.8,0),lower[next],lower[i]]]:
				_triangle(st,face[0],face[1],face[2],0.0,0.92+float(lobe%3)*0.035,at,0.55)
		# Thin forked stems meet the ground and remain visible below the canopy.
		var base:=Vector3(at.x*0.3,0,at.z*0.3)
		for i in 5:
			var angle:=TAU*float(i)/5.0
			var next:=TAU*float(i+1)/5.0
			var a:=base+Vector3(cos(angle)*0.8,0,sin(angle)*0.8)
			var b:=base+Vector3(cos(next)*0.8,0,sin(next)*0.8)
			_triangle(st,a,b,at,0.5)
	return st.commit()

static func _grass() -> ArrayMesh:
	var st:=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_footprint(st,5.0)
	for blade in 5:
		var angle:=float(blade)*2.4
		var height:=5.0+float((blade*3)%7)
		var base:=Vector3(cos(angle)*2.5,0,sin(angle)*2.5)
		var side:=Vector3(cos(angle+1.2),0,sin(angle+1.2))*0.72
		var mid:=base+Vector3(cos(angle)*1.3,height*0.64,sin(angle)*1.3)
		var tip:=base+Vector3(cos(angle)*4.4,height*0.86,sin(angle)*4.4)+side*float(blade%3-1)*0.65
		for face: Array in [[base-side,base+side,mid+side*0.45],[base-side,mid+side*0.45,mid-side*0.45],[mid-side*0.45,mid+side*0.45,tip]]:
			_triangle(st,face[0],face[1],face[2],0.0,0.86+float(blade%3)*0.06)
			_triangle(st,face[2],face[1],face[0],0.0,0.86+float(blade%3)*0.06)
	return st.commit()

static func seed_at(cell: Vector2i, salt: int) -> float:
	var value: int = (cell.x*73856093) ^ (cell.y*19349663) ^ salt
	value = ((value ^ (value>>13))*1274126177) & 0x7fffffff
	return float(value%65536)/65535.0

func clear() -> void:
	visible = false
	instance_count = 0
	for node in plants: node.multimesh.visible_instance_count = 0

func _planting_grid(layer: int, center: Vector2i, spacing: float, reach: int) -> Array:
	# Two bounded grids contain only deterministic world placement. Camera
	# projection, distance fade and same-frame ownership are never cached.
	if not _grid_cache[layer].is_empty() and _grid_centers[layer]==center: return _grid_cache[layer]
	var grid: Array=[]
	for y in range(-reach,reach+1):
		for x in range(-reach,reach+1):
			var cell:=center+Vector2i(x,y)
			var seed:=seed_at(cell,198803+layer)
			var patch:=Vector2i(floori(float(cell.x)/3.0),floori(float(cell.y)/3.0))
			if seed<0.20+(1.0-seed_at(patch,719+layer))*0.56: continue
			var ground:=(Vector2(cell)+Vector2(seed_at(cell,17),seed_at(cell,53)))*spacing
			grid.append([ground,seed,Basis(Vector3.UP,seed*TAU)])
	_grid_centers[layer]=center
	_grid_cache[layer]=grid
	_grid_build_count+=1
	return grid

func prepare(data: Dictionary, mapping: Dictionary, ownership: Texture2D) -> void:
	clear()
	if mapping.is_empty() or ownership==null: return
	var background: Dictionary = data.background if data.get("background") is Dictionary else {}
	var colors: Array = background.colors if background.get("colors") is Array else []
	if background.get("kind","")!="horizon" or colors.size()!=2 or int(colors[0])!=5 or int(colors[1])!=8: return
	var frame: Dictionary = data.camera
	var origin: Vector3 = mapping.origin
	if origin.z<=0.0: return
	var view: Basis = mapping.inverse.inverse()
	var axis := Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
	var orientation := axis*view*axis.inverse()
	var clip := Rect2(Vector2(frame.clip[0],frame.clip[1]),Vector2(frame.clip[2]-frame.clip[0]+1,frame.clip[3]-frame.clip[1]+1))
	# Only positively identified, flat field surfaces join the ground backdrop.
	# No actor, road, water, slope or uncertain source polygon is admitted.
	var allowed := Image.create(data.objects.size()+1,1,false,Image.FORMAT_RGBA8)
	allowed.set_pixel(0,0,Color.WHITE)
	for i in data.objects.size():
		var object: Dictionary = data.objects[i]
		var flat: bool = object.get("polygons",[]).size()==1 and not object.has("sprite") and object.get("round_forms",[]).is_empty()
		for polygon: Dictionary in object.get("polygons",[]):
			flat = flat and Terrain.surface_kind(object,polygon)==1 and int(object.get("root",-1))==5109
			for raw: Array in polygon.camera_vertices:
				var local: Vector3 = mapping.inverse*Vector3(raw[0],raw[1],raw[2])
				flat = flat and absf(local.z+origin.z)<1.0
		if flat: allowed.set_pixel(i+1,0,Color.WHITE)
	var a := Vector2(background.line[0][0],background.line[0][1])
	var b := Vector2(background.line[1][0],background.line[1][1])
	if a.x>b.x:
		var swap := a; a=b; b=swap
	var delta := b-a
	if absf(delta.x)<0.001: return
	material.set_shader_parameter("source_ownership",ownership)
	# The whitelist only changes with the object list; identical bytes keep the
	# uploaded texture, and a changed list gets a fresh exact one.
	if _allowed_texture==null or allowed.get_data()!=_allowed_bytes:
		_allowed_bytes=allowed.get_data()
		_allowed_texture=ImageTexture.create_from_image(allowed)
		material.set_shader_parameter("allowed_ground",_allowed_texture)
	material.set_shader_parameter("owner_count",float(allowed.get_width()))
	material.set_shader_parameter("source_origin",clip.position)
	material.set_shader_parameter("source_dimensions",clip.size)
	material.set_shader_parameter("source_center",Vector2(frame.center[0],frame.center[1]))
	material.set_shader_parameter("source_focal",float(frame.focal_pixels))
	material.set_shader_parameter("camera_to_local",mapping.inverse)
	material.set_shader_parameter("source_eye_height",origin.z)
	material.set_shader_parameter("horizon",Vector3(-delta.y,delta.x,delta.y*a.x-delta.x*a.y)/delta.length())
	for layer in 2:
		var spacing: float = LAYERS[layer][0]
		var radius: float = LAYERS[layer][1]
		var center := Vector2i(floori(origin.x/spacing),floori(origin.y/spacing))
		var reach := ceili(radius/spacing)
		var instances: Array = []
		for planted: Array in _planting_grid(layer,center,spacing,reach):
			var ground: Vector2=planted[0]
			var seed: float=planted[1]
			var distance := ground.distance_to(Vector2(origin.x,origin.y))
			if distance>radius: continue
			var raw: Vector3 = view*Vector3(ground.x-origin.x,origin.y-ground.y,-origin.z)
			if raw.y<float(frame.near_raw)+32.0: continue
			var projected := Surface.project([raw.x,raw.y,raw.z],frame)
			if not clip.has_point(projected): continue
			var size_factor := (0.7+seed*0.9)*(1.0-smoothstep(radius*0.76,radius,distance))
			# Shape variation belongs to each fixed seed, never camera position or
			# elapsed time. Apply it in plant axes before the captured camera basis.
			var shape:=Vector3(0.86+seed*0.28,0.90+seed*0.20,1.14-seed*0.28)
			var transform := Transform3D(orientation*planted[2]*Basis.from_scale(shape*size_factor/64.0),Vector3(raw.x,raw.z,-raw.y)/64.0)
			instances.append([raw.y,transform,(projected-clip.position)/clip.size,seed])
		# Transparent draw order is far to near; convex lobes have backface culling.
		instances.sort_custom(func(left,right): return left[0]>right[0])
		var mm: MultiMesh = plants[layer].multimesh
		var buffer: PackedFloat32Array = _buffers[layer]
		for i in instances.size():
			var t: Transform3D = instances[i][1]
			var at: int = i*STRIDE
			buffer[at]=t.basis.x.x;buffer[at+1]=t.basis.y.x;buffer[at+2]=t.basis.z.x;buffer[at+3]=t.origin.x
			buffer[at+4]=t.basis.x.y;buffer[at+5]=t.basis.y.y;buffer[at+6]=t.basis.z.y;buffer[at+7]=t.origin.y
			buffer[at+8]=t.basis.x.z;buffer[at+9]=t.basis.y.z;buffer[at+10]=t.basis.z.z;buffer[at+11]=t.origin.z
			buffer[at+12]=instances[i][2].x;buffer[at+13]=instances[i][2].y;buffer[at+14]=instances[i][3];buffer[at+15]=float(layer)
		# Instances past visible_instance_count keep stale data and are not drawn.
		mm.buffer = buffer
		mm.visible_instance_count = instances.size()
		instance_count += instances.size()
	visible = instance_count>0
