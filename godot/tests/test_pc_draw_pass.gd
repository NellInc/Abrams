extends SceneTree
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var view = DrawPass.new()
	root.add_child(view)
	check(DrawPass.camera_point([64,128,192]) == Vector3(1,3,-2), "original camera axes changed")
	view.apply_pass({"objects": [{"static_path": 1, "dynamic_instance": true, "polygons": [
		{"camera_vertices": [[0,128,0], [64,128,0], [0,128,64]]}]}]})
	check(view.polygon_count == 1 and view.dynamic_polygon_count == 1, "dynamic polygon count")
	check(view.mesh_node.mesh.surface_get_array_len(0) == 6, "original triangle wire has three edges")
	view.apply_pass({"objects": []})
	check(view.mesh_node.mesh == null and view.source_points.is_empty(), "empty pass must clear previous geometry")
	view.queue_free()
	await process_frame
	var args := OS.get_cmdline_user_args()
	var projected := 0
	var pass_count := 0
	var maximum_error := 0.0
	var capture_path := ""
	if args.size() >= 2 and args[0] == "--fixture":
		var fixture = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
		if not fixture is Dictionary or fixture.get("render_passes", []).is_empty():
			printerr("FAIL: recorded original draw passes unavailable")
			quit(1)
			return
		var viewport := SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var display := TextureRect.new()
		display.texture = viewport.get_texture()
		display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(display)
		display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("293338")
		viewport.add_child(environment)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.make_current()
		var drawn = DrawPass.new()
		drawn.solid_enabled = "--solid" in args
		camera.add_child(drawn)
		for pass_data in fixture.render_passes:
			var frame: Dictionary = pass_data.camera.duplicate(true)
			# Captured vertices already include the original composed camera
			# transform. Applying it twice would rotate the drawing incorrectly.
			frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
			frame.world_position_raw = [0,0,0]
			var dimensions := PcCamera.apply(camera, frame, Vector3.ZERO)
			viewport.size = dimensions * 4
			drawn.apply_pass(pass_data)
			check(drawn.render_warnings.is_empty(), "surface warnings in draw pass %s: %s" % [str(pass_data.sequence), str(drawn.render_warnings)])
			await process_frame
			pass_count += 1
			for point in drawn.source_points:
				if float(point[1]) < float(frame.near_raw): continue
				var expected := Vector2(float(frame.center[0]) + float(point[0]) * float(frame.focal_pixels) / float(point[1]) - float(frame.clip[0]),
					float(frame.center[1]) - float(point[2]) * float(frame.focal_pixels) / float(point[1]) - float(frame.clip[1]))
				var actual := camera.unproject_position(DrawPass.camera_point(point)) / 4.0
				var error := actual.distance_to(expected)
				maximum_error = maxf(maximum_error, error)
				if error >= 0.01 and failures.size() < 5:
					failures.append("point=%s actual=%s expected=%s viewport=%s" % [str(point), str(actual), str(expected), str(viewport.size)])
				projected += 1
		check(projected > 0 and drawn.dynamic_polygon_count > 0, "fixture must include projected vehicle geometry")
		if "--capture" in args and args.find("--capture") + 1 < args.size():
			capture_path = args[args.find("--capture") + 1]
			await RenderingServer.frame_post_draw
			check(viewport.get_texture().get_image().save_png(capture_path) == OK, "native capture failed")
		print("PC_DRAW_PASS_FIXTURE: %d passes, %d projections, maximum error %.6f source pixels; %d dynamic polygons in final pass" % [pass_count, projected, maximum_error, drawn.dynamic_polygon_count])
	print("PC_DRAW_PASS: basic axes, geometry, classification and clearing checks complete")
	for message in failures: printerr("FAIL: " + message)
	quit(0 if failures.is_empty() else 1)
