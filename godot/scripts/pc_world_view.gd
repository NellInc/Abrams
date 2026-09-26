extends Node3D
## Original-camera static outlines, filtered by the original draw queue,
## detail root and face rejection. Solid occlusion and materials remain open.
const DISPLAY_SCALE := 64.0
var meshes: Dictionary = {}
var geometry: Dictionary = {}
var material: StandardMaterial3D
var instances: Dictionary = {}
var anchor := Vector3.ZERO
var anchored := false

static func coordinates(raw: Array) -> Vector3:
	# PC's continuous axes are east, south, height; Godot is east, up, south.
	return Vector3(float(raw[0]), float(raw[2]), float(raw[1])) / DISPLAY_SCALE

func set_geometry(shapes: Dictionary) -> void:
	geometry = shapes
	material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("82a7a0")
	for key in shapes:
		var mesh := _mesh(shapes[key].values())
		if mesh: meshes[int(key)] = mesh

func _mesh(polygons: Array) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for polygon in polygons:
		if polygon.size() < 2: continue
		var edge_count: int = polygon.size() if polygon.size() > 2 else 1
		for i in edge_count:
			for point in [polygon[i], polygon[(i + 1) % polygon.size()]]:
				vertices.append(Vector3(float(point[0]), float(point[2]), -float(point[1])) / DISPLAY_SCALE)
	if vertices.is_empty(): return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh.surface_set_material(0, material)
	return mesh

func apply_state(state: Dictionary) -> Vector3:
	if not anchored:
		anchor = coordinates(state.world_position_raw)
		anchored = true
	var present := {}
	var selection := {}
	var filtered := state.has("render_static_faces")
	for item in state.get("render_static_faces", []):
		selection[int(item.world_entry_offset)] = item.primitive_ids
	for object in state.world.static:
		var identity := int(object.world_entry_offset)
		var shape := int(object.shape_index)
		if not meshes.has(shape): continue
		if filtered and (not selection.has(identity) or selection[identity].is_empty()): continue
		present[identity] = true
		if not instances.has(identity):
			var node := MeshInstance3D.new()
			node.name = "WorldEntry_%d" % identity
			add_child(node)
			instances[identity] = node
		var node: MeshInstance3D = instances[identity]
		if filtered:
			var signature := str(shape) + ":" + str(selection[identity])
			if node.get_meta("selection", "") != signature:
				var polygons: Array = []
				for primitive in selection[identity]:
					polygons.append(geometry[str(shape)][str(int(primitive))])
				node.mesh = _mesh(polygons)
				node.set_meta("selection", signature)
		else:
			node.mesh = meshes[shape]
		node.position = coordinates(object.world_position_raw) - anchor
	for identity in instances.keys():
		if not present.has(identity):
			instances[identity].queue_free()
			instances.erase(identity)
	return coordinates(state.world_position_raw) - anchor
