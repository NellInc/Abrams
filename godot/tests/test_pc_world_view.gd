extends SceneTree
const WorldView = preload("res://scripts/pc_world_view.gd")
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	if not condition: failures.append(detail)

func _initialize() -> void:
	# A script error aborts _run() before quit(); fail the gate instead of hanging it.
	create_timer(60).timeout.connect(func(): printerr("FAIL: world view deadline"); quit(2))
	_run.call_deferred()

func _run() -> void:
	var view = WorldView.new()
	root.add_child(view)
	# Asymmetric third vertex: east, north and up all differ, so an axis swap cannot pass.
	view.set_geometry({"1": {"10": [[0, 0, 0], [64, 0, 0], [64, 128, 192]]}, "2": {"20": [[0, 0, 0], [0, 128, 0]]}, "3": {}})
	check(view.meshes.size() == 2, "empty geometry should not create an invalid surface")
	if not (view.meshes.has(1) and view.meshes.has(2)):
		_finish(["source shapes must be keyed by integer shape index"])
		return
	check(view.meshes[1].surface_get_array_len(0) == 6, "triangle wire should have three edges")
	check(view.meshes[2].surface_get_array_len(0) == 2, "line should have one edge")
	var vertices: PackedVector3Array = view.meshes[1].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(vertices.size() == 6 and vertices[1] == Vector3(1, 0, 0) and vertices[3] == Vector3(1, 3, -2), "source east/north/up axes or scale changed")
	var object := {"world_entry_offset": 8193, "shape_index": 1, "world_position_raw": [128, 256, 64]}
	var state := {"world_position_raw": [64, 128, 0], "world": {"static": [object]}}
	check(view.apply_state(state) == Vector3.ZERO, "initial player should anchor the survey")
	var identity: MeshInstance3D = view.instances.get(8193)
	if identity == null:
		_finish(["static world entry must be surveyed"])
		return
	check(identity.position == Vector3(1, 1, 2), "world placement should use continuous coordinates")
	state.world_position_raw = [64, 64, 0]
	object.shape_index = 2
	check(view.apply_state(state) == Vector3(0, 0, -1), "northward movement should remain continuous")
	check(view.instances.get(8193) == identity and identity.mesh == view.meshes[2], "changed shape must retain source identity")
	state.render_static_faces = [{"world_entry_offset": 8193, "primitive_ids": [20]}]
	view.apply_state(state)
	check(view.instances.has(8193) and view.instances[8193].mesh.surface_get_array_len(0) == 2, "original primitive mask should select the source line")
	state.render_static_faces = []
	view.apply_state(state)
	check(view.instances.is_empty(), "allocated objects absent from the original draw queue must be hidden")
	state.render_static_faces = [{"world_entry_offset": 8193, "primitive_ids": [20]}]
	view.apply_state(state)
	check(view.instances.has(8193), "re-selected entry must return to the survey")
	# Keep the draw-queue selection so only the world.static removal path can prune it.
	state.world.static = []
	view.apply_state(state)
	check(view.instances.is_empty(), "unloaded world entries must leave the survey")
	view.queue_free()
	await process_frame
	_finish([])

func _finish(fatal: Array[String]) -> void:
	failures.append_array(fatal)
	if failures.is_empty(): print("PC_WORLD_VIEW: 12 original-coordinate and draw-mask checks passed")
	else:
		for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
