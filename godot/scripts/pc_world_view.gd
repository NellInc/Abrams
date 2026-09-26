extends Node3D
## Original static-world wire survey. Never use allocated objects as a gameplay
## visibility list. Culling, materials, LOD and the original camera remain open.
const DISPLAY_SCALE := 64.0
var meshes: Dictionary = {}
var instances: Dictionary = {}
var anchor := Vector3.ZERO
var anchored := false

static func coordinates(raw: Array) -> Vector3:
	# PC's continuous axes are east, south, height; Godot is east, up, south.
	return Vector3(float(raw[0]), float(raw[2]), float(raw[1])) / DISPLAY_SCALE

func set_geometry(shapes: Dictionary) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("82a7a0")
	for key in shapes:
		var vertices := PackedVector3Array()
		for polygon in shapes[key]:
			if polygon.size() < 2: continue
			var edge_count: int = polygon.size() if polygon.size() > 2 else 1
			for i in edge_count:
				for point in [polygon[i], polygon[(i + 1) % polygon.size()]]:
					# Shape vectors use north-positive Y, unlike continuous map south.
					vertices.append(Vector3(float(point[0]), float(point[2]), -float(point[1])) / DISPLAY_SCALE)
		if vertices.is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
		mesh.surface_set_material(0, material)
		meshes[int(key)] = mesh

func apply_state(state: Dictionary) -> Vector3:
	if not anchored:
		anchor = coordinates(state.world_position_raw)
		anchored = true
	var present := {}
	for object in state.world.static:
		var identity := int(object.world_entry_offset)
		var shape := int(object.shape_index)
		if not meshes.has(shape): continue
		present[identity] = true
		if not instances.has(identity):
			var node := MeshInstance3D.new()
			node.name = "WorldEntry_%d" % identity
			add_child(node)
			instances[identity] = node
		var node: MeshInstance3D = instances[identity]
		node.mesh = meshes[shape]
		node.position = coordinates(object.world_position_raw) - anchor
	for identity in instances.keys():
		if not present.has(identity):
			instances[identity].queue_free()
			instances.erase(identity)
	return coordinates(state.world_position_raw) - anchor
