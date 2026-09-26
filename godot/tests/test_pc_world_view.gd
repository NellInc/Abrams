extends SceneTree
const WorldView = preload("res://scripts/pc_world_view.gd")
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view = WorldView.new()
	root.add_child(view)
	view.set_geometry({"1": [[[0, 0, 0], [64, 0, 0], [64, 64, 64]]], "2": [[[0, 0, 0], [0, 128, 0]]], "3": []})
	check(view.meshes.size() == 2, "empty geometry should not create an invalid surface")
	check(view.meshes[1].surface_get_array_len(0) == 6, "triangle wire should have three edges")
	check(view.meshes[2].surface_get_array_len(0) == 2, "line should have one edge")
	var vertices: PackedVector3Array = view.meshes[1].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices[3] == Vector3(1, 1, -1), "source north/up axes or scale changed")
	var object := {"world_entry_offset": 8193, "shape_index": 1, "world_position_raw": [128, 256, 64]}
	var state := {"world_position_raw": [64, 128, 0], "world": {"static": [object]}}
	check(view.apply_state(state) == Vector3.ZERO, "initial player should anchor the survey")
	var identity: MeshInstance3D = view.instances[8193]
	check(identity.position == Vector3(1, 1, 2), "world placement should use continuous coordinates")
	state.world_position_raw = [64, 64, 0]
	object.shape_index = 2
	check(view.apply_state(state) == Vector3(0, 0, -1), "northward movement should remain continuous")
	check(view.instances[8193] == identity and identity.mesh == view.meshes[2], "changed shape must retain source identity")
	state.world.static = []
	view.apply_state(state)
	check(view.instances.is_empty(), "unloaded world entries must leave the survey")
	view.queue_free()
	await process_frame
	if failures.is_empty(): print("PC_WORLD_VIEW: 9 original-coordinate wire-survey checks passed")
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
