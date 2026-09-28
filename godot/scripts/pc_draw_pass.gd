extends Node3D
## Camera-relative replay of observed original draw calls. Presentation only.
## Wire outlines do not establish filled-surface occlusion or material parity.
const SurfaceGeometry = preload("res://scripts/pc_surface_geometry.gd")
const SurfaceShader = preload("res://scripts/pc_surface.gdshader")
const Colour = preload("res://scripts/pc_colour.gd")
const TerrainStyle = preload("res://scripts/pc_terrain_style.gd")
var solid_enabled := false
var presentation_palette: Array = []
var terrain_style: RefCounted
var effect_art: RefCounted
var effect_art_ids: Array[int] = []
var _effect_uvs := PackedVector2Array()
var terrain_active := false
var terrain_polygon_count := 0
var _pattern_key := ""
var _pattern_texture: Texture2D
var render_warnings: Array[String] = []
const DISPLAY_SCALE := 64.0
var mesh_node: MeshInstance3D
var polygon_count := 0
var dynamic_polygon_count := 0
var sprite_count := 0
var source_points: Array = []

func _init() -> void:
	mesh_node = MeshInstance3D.new()
	add_child(mesh_node)

static func camera_point(raw: Array) -> Vector3:
	return Vector3(float(raw[0]), float(raw[2]), -float(raw[1])) / DISPLAY_SCALE

func apply_pass(pass_data: Dictionary) -> void:
	render_warnings.clear()
	sprite_count = 0
	effect_art_ids.clear()
	terrain_active = false
	terrain_polygon_count = 0
	if solid_enabled:
		_apply_surfaces(pass_data)
		return
	var vertices := PackedVector3Array()
	polygon_count = 0
	dynamic_polygon_count = 0
	source_points.clear()
	for object in pass_data.objects:
		for polygon in object.polygons:
			var points: Array = polygon.camera_vertices
			if points.size() < 2: continue
			polygon_count += 1
			# A zero-angle dynamic actor can use the original static arithmetic
			# shortcut. Allocation identity and transform path are distinct.
			if bool(object.get("dynamic_instance", not bool(object.static_path))): dynamic_polygon_count += 1
			source_points.append_array(points)
			var edges: int = points.size() if points.size() > 2 else 1
			for i in edges:
				vertices.append(camera_point(points[i]))
				vertices.append(camera_point(points[(i + 1) % points.size()]))
	if vertices.is_empty():
		mesh_node.mesh = null
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("82a7a0")
	mesh.surface_set_material(0, material)
	mesh_node.mesh = mesh

func _apply_surfaces(pass_data: Dictionary) -> void:
	mesh_node.mesh = null
	polygon_count = 0
	dynamic_polygon_count = 0
	source_points.clear()
	if not pass_data.get("camera") is Dictionary: return
	if not pass_data.get("materials") is Array or not pass_data.get("palette_rgb") is Array:
		render_warnings.append("Original material/palette observation unavailable")
		return
	var frame: Dictionary = pass_data.camera
	var palette: Array = presentation_palette if presentation_palette.size() == 16 else pass_data.palette_rgb
	var vertices := PackedVector3Array()
	var materials := PackedVector2Array()
	_effect_uvs.clear()
	var material_count: int = pass_data.materials.size()
	var mapping: Dictionary = terrain_style.mapping(frame,pass_data.palette_rgb) if terrain_style else {}
	terrain_active = not mapping.is_empty()
	var levels: int = TerrainStyle.LEVELS if terrain_active else 1
	# Cache the compensated RGB ramps; the original palette/patterns never change.
	var key := JSON.stringify([palette,pass_data.materials,levels])
	if key != _pattern_key:
		var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
		var texture := Image.create((material_count+16)*2,levels*2,false,Image.FORMAT_RGBAF if compatibility else Image.FORMAT_RGBA8)
		for level in levels:
			for index in material_count+16:
				var words: Array = pass_data.materials[index] if index < material_count else [index-material_count,index-material_count]
				for y in 2:
					for x in 2:
						var word: int = int(words[0]) if y == 1 else int(words[1])
						var value := int(words[0]) & 15 if words[0] == words[1] else (word >> (8 if x == 0 else 0)) & 15
						var rgb: Array = TerrainStyle.detail_rgb(palette[value],level) if terrain_active else palette[value]
						texture.set_pixel(index*2+x,level*2+y,Colour.input_color(rgb,compatibility))
		_pattern_texture = ImageTexture.create_from_image(texture)
		_pattern_key = key
	if pass_data.get("background") is Dictionary:
		var backgrounds: Array = SurfaceGeometry.background_polygons(pass_data.background, frame)
		if backgrounds.is_empty(): render_warnings.append("Unsupported vertical horizon")
		for background: Dictionary in backgrounds:
			var points: Array = []
			for point: Vector2 in background.points: points.append(SurfaceGeometry.unproject(point, 1024.0, frame))
			var kind := 3 if terrain_active and pass_data.background.kind == "horizon" and int(background.material) == 8 else 0
			_add_triangles(vertices, materials, SurfaceGeometry.triangle_vertices(points, frame), int(background.material), pass_data.materials.size(),kind)
	else:
		render_warnings.append("Original background observation unavailable")
	for object: Dictionary in pass_data.objects:
		if object.get("sprite") is Dictionary:
			sprite_count += 1
			var effect: Dictionary = effect_art.mapping(object,frame,pass_data.palette_rgb) if effect_art else {}
			if not effect.is_empty():
				effect_art_ids.append(effect.index)
				_add_effect(vertices,materials,effect,frame)
			else:
				for run: Dictionary in SurfaceGeometry.sprite_runs(object.sprite, frame):
					var points: Array = []
					for point: Vector2 in run.points: points.append(SurfaceGeometry.unproject(point, 1024.0, frame))
					_add_triangles(vertices, materials, SurfaceGeometry.triangle_vertices(points, frame), material_count + int(run.color), material_count + 16)
		for polygon: Dictionary in object.polygons:
			var points: Array = polygon.camera_vertices
			if points.size() < 2: continue
			polygon_count += 1
			if bool(object.get("dynamic_instance", not bool(object.static_path))): dynamic_polygon_count += 1
			source_points.append_array(points)
			var fill := int(polygon.get("fill_mode", 0)) != 0 and points.size() >= 3
			if fill:
				var triangles: Array = SurfaceGeometry.triangle_vertices(points, frame)
				var kind: int = TerrainStyle.surface_kind(object,polygon) if terrain_active else 0
				if kind != 0: terrain_polygon_count += 1
				_add_triangles(vertices, materials, triangles, int(polygon.colors[1]), pass_data.materials.size(),kind)
			if not fill or polygon.colors[0] != polygon.colors[1]:
				var edges: int = points.size() if points.size() > 2 else 1
				for i in edges:
					_add_triangles(vertices, materials, SurfaceGeometry.line_vertices(points[i], points[(i + 1) % points.size()], frame), int(polygon.colors[0]), pass_data.materials.size())
	if vertices.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = materials
	arrays[Mesh.ARRAY_TEX_UV2] = _effect_uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = SurfaceShader
	material.set_shader_parameter("material_patterns",_pattern_texture)
	material.set_shader_parameter("pattern_width",float(_pattern_texture.get_width()))
	material.set_shader_parameter("detail_levels",float(levels))
	if not effect_art_ids.is_empty():
		material.set_shader_parameter("impact_burst",effect_art.textures[0])
		material.set_shader_parameter("impact_fading",effect_art.textures[1])
		material.set_shader_parameter("impact_smoke",effect_art.textures[2])
		material.set_shader_parameter("effect_correction",effect_art.correction)
	if terrain_active:
		material.set_shader_parameter("field_detail",terrain_style.textures.field)
		material.set_shader_parameter("road_detail",terrain_style.textures.road)
		material.set_shader_parameter("camera_to_local",mapping.inverse)
		material.set_shader_parameter("world_origin",mapping.origin)
	material.set_shader_parameter("source_origin", Vector2(frame.clip[0], frame.clip[1]))
	material.set_shader_parameter("source_dimensions", Vector2(frame.clip[2] - frame.clip[0] + 1, frame.clip[3] - frame.clip[1] + 1))
	mesh.surface_set_material(0, material)
	mesh_node.mesh = mesh

func _add_triangles(vertices: PackedVector3Array, materials: PackedVector2Array, points: Array, material: int, count: int, kind: int = 0) -> void:
	if material < 0 or material >= count:
		render_warnings.append("Unsupported original material %d" % material)
		return
	for point: Array in points:
		vertices.append(camera_point(point))
		materials.append(Vector2(material,kind))
		_effect_uvs.append(Vector2.ZERO)

func _add_effect(vertices: PackedVector3Array, materials: PackedVector2Array, effect: Dictionary, frame: Dictionary) -> void:
	var rect: Rect2 = effect.rect
	var target: Rect2 = effect.target
	var uv: Rect2 = effect.source_uv
	var points := [rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]
	for index in [0,1,2,0,2,3]:
		var point: Vector2 = points[index]
		vertices.append(camera_point(SurfaceGeometry.unproject(point,1024.0,frame)))
		materials.append(Vector2(0,4+int(effect.donor)))
		_effect_uvs.append(uv.position+(point-target.position)/target.size*uv.size)
