extends SubViewport
## Same-frame source painter ownership. IDs are pass-local array indices only.
const SourceCommands = preload("res://scripts/pc_modern_source_commands.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const Camera = preload("res://scripts/pc_camera.gd")
const Colour = preload("res://scripts/pc_colour.gd")
const ShaderSource = preload("res://scripts/pc_modern_ownership.gdshader")
var mesh_node: MeshInstance3D
var camera: Camera3D
var object_count := 0
var triangle_count := 0
var _flags := PackedVector2Array()

func _init() -> void:
	own_world_3d = true
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	msaa_3d = Viewport.MSAA_DISABLED
	screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	mesh_node = MeshInstance3D.new()
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(mesh_node)

func clear() -> void:
	mesh_node.mesh = null
	object_count = 0
	triangle_count = 0
	_flags.clear()
	render_target_update_mode = SubViewport.UPDATE_DISABLED

# Authored effect alpha never extends ownership past the original sprite's
# opaque pixels, so it cannot conceal an actor the original left visible.
# _effect_art is ignored; it remains only until the draw pass stops passing it.
func prepare(data: Dictionary, dimensions: Vector2i, _effect_art: RefCounted = null, protected_lines: Dictionary = {}, guarded_owners: Dictionary = {}, protected_surfaces: Dictionary = {}, pose_overrides: Dictionary = {}) -> bool:
	clear()
	if not data.get("camera") is Dictionary or not data.get("objects") is Array: return false
	if data.objects.size()>65534 or dimensions.x<1 or dimensions.y<1: return false
	var frame: Dictionary = data.camera.duplicate(true)
	frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
	frame.world_position_raw = [0,0,0]
	Camera.apply(camera,frame,Vector3.ZERO)
	size = dimensions
	var vertices := PackedVector3Array()
	var colours := PackedVector2Array()
	var compatible := RenderingServer.get_current_rendering_method()=="gl_compatibility"
	# Optional HQ coverage: byte 8 guards original nonterrain pixels, byte 64
	# preserves standalone lines. Default masks stay exact; rounds stay 255.
	var guarded_flag:float=Colour.input_color([0,0,8],compatible).b
	var line_flag:float=Colour.input_color([0,0,64],compatible).b
	for index in data.objects.size():
		var object: Dictionary = data.objects[index]
		var id: int = index+1
		var ordinary_flag:float=guarded_flag if id in guarded_owners else 0.0
		var surfaces:Dictionary=protected_surfaces.get(int(object.get("shape_index",-1)),{})
		var protected:Dictionary=protected_lines.get(int(object.get("shape_index",-1)),{})
		var corrected := Colour.input_color([id&255,(id>>8)&255,0],compatible)
		var color := Vector2(corrected.r,corrected.g)
		if id in pose_overrides:
			# One admitted replacement at exactly its original owner/painter slot.
			# Old standing polygons and round stamps never enter this mask.
			add_points(vertices,colours,pose_overrides[id].camera_triangles,color,false,guarded_flag)
			continue
		if object.get("sprite") is Dictionary:
			# Exactly the original opaque runs at this painter slot. Holes in an
			# authored redraw cannot reveal an actor the original sprite hid.
			for run: Dictionary in Geometry.sprite_runs(object.sprite,frame):
				var points: Array = []
				for point: Vector2 in run.points: points.append(Geometry.unproject(point,1024.0,frame))
				add_points(vertices,colours,Geometry.triangle_vertices(points,frame),color,false,ordinary_flag)
		for item: Dictionary in SourceCommands.ordered(object):
			if item.kind=="round_form":
				for run: Dictionary in SourceCommands.round_runs(item.data,frame):
					var points: Array=[]
					for point: Vector2 in run.points: points.append(Geometry.unproject(point,1024.0,frame))
					add_points(vertices,colours,Geometry.triangle_vertices(points,frame),color,true)
				continue
			var polygon: Dictionary=item.data
			var points: Array = polygon.camera_vertices
			if points.size()<2: continue
			var fill := int(polygon.get("fill_mode",0))!=0 and points.size()>=3
			var surface_flag:float=line_flag if int(polygon.get("primitive",-1)) in surfaces else ordinary_flag
			if fill: add_points(vertices,colours,Geometry.triangle_vertices(points,frame),color,false,surface_flag)
			if not fill or polygon.colors[0]!=polygon.colors[1]:
				var edges: int = points.size() if points.size()>2 else 1
				for edge in edges:
					var flag:float=line_flag if not fill and int(polygon.get("primitive",-1)) in protected else surface_flag
					add_points(vertices,colours,Geometry.line_vertices(points[edge],points[(edge+1)%points.size()],frame),color,false,flag)
	object_count = data.objects.size()
	if not vertices.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_TEX_UV] = colours
		arrays[Mesh.ARRAY_TEX_UV2] = _flags
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var material := ShaderMaterial.new()
		material.shader = ShaderSource
		mesh.surface_set_material(0,material)
		mesh_node.mesh = mesh
	# The mask is immutable until the next paired prepare (including resize).
	# A dependent scene samples it after this one draw; cache hits retain it.
	render_target_update_mode = SubViewport.UPDATE_ONCE
	return true

func add_points(vertices: PackedVector3Array, colours: PackedVector2Array, points: Array, color: Vector2, command: bool = false, line_flag:float=0.0) -> void:
	for point: Array in points:
		vertices.append(Vector3(point[0],point[2],-point[1])/64.0)
		colours.append(color)
		_flags.append(Vector2(1.0 if command else line_flag,0))
	triangle_count += points.size()/3
