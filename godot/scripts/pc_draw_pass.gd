extends Node3D
## Camera-relative replay of observed original draw calls. Presentation only.
## Wire outlines do not establish filled-surface occlusion or material parity.
const DISPLAY_SCALE := 64.0
var mesh_node: MeshInstance3D
var polygon_count := 0
var dynamic_polygon_count := 0
var source_points: Array = []

func _init() -> void:
	mesh_node = MeshInstance3D.new()
	add_child(mesh_node)

static func camera_point(raw: Array) -> Vector3:
	return Vector3(float(raw[0]), float(raw[2]), -float(raw[1])) / DISPLAY_SCALE

func apply_pass(pass_data: Dictionary) -> void:
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
