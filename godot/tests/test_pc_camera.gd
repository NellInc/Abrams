extends SceneTree
const PcCamera = preload("res://scripts/pc_camera.gd")
const WorldView = preload("res://scripts/pc_world_view.gd")
var failures: Array[String] = []
var checked := 0
var max_error := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	var cases: Array = []
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--fixture":
		var file := FileAccess.open(args[1], FileAccess.READ)
		if file == null:
			printerr("FAIL: original camera fixture missing")
			quit(1)
			return
		var fixture = JSON.parse_string(file.get_as_text())
		for name in fixture.captures:
			var capture: Dictionary = fixture.captures[name]
			cases.append({"name": name, "camera": capture.state.camera, "samples": capture.projection_samples})
	else:
		for clip in [[32, 13, 287, 109], [0, 10, 319, 52], [0, 0, 319, 116], [0, 0, 319, 135]]:
			var center := [floori(float(clip[0] + clip[2]) / 2.0), floori(float(clip[1] + clip[3]) / 2.0)]
			var frame := {"matrix_q14_columns": [16384, 0, 0, 0, 16384, 0, 0, 0, 16384],
				"world_position_raw": [79872, 141312, 50], "clip": clip, "center": center,
				"near_raw": 16, "focal_pixels": 128}
			var samples: Array = []
			for delta in [[0, 4096, 0], [1024, 4096, 512], [-1024, 4096, -512]]:
				samples.append({"local_delta": delta, "camera_i16": delta,
					"pixel_float": [center[0] + delta[0] / 32.0, center[1] - delta[2] / 32.0]})
			cases.append({"name": str(clip), "camera": frame, "samples": samples})
	for item in cases:
		var frame: Dictionary = item.camera
		var clip: Array = frame.clip
		var dimensions := PcCamera.apply(camera, frame, WorldView.coordinates(frame.world_position_raw))
		viewport.size = dimensions * 4
		await process_frame
		for sample in item.samples:
			if sample.camera_i16[1] < 1024: continue
			var expected := Vector2(sample.pixel_float[0] - clip[0], sample.pixel_float[1] - clip[1])
			if expected.x < -64 or expected.x > dimensions.x + 64 or expected.y < -64 or expected.y > dimensions.y + 64: continue
			var delta: Array = sample.local_delta
			var point := Vector3(float(delta[0]), float(delta[2]), -float(delta[1])) / WorldView.DISPLAY_SCALE
			var actual := camera.unproject_position(point) / 4.0
			var error := actual.distance_to(expected)
			max_error = maxf(max_error, error)
			checked += 1
			# Original Q14 transform truncates before projection; Godot retains
			# sub-unit detail. Allow less than one native pixel, never a FOV drift.
			if error >= 1.0: failures.append("%s projection error %.4f: %s versus %s" % [item.name, error, actual, expected])
	if checked < 12: failures.append("insufficient projection cases")
	viewport.queue_free()
	await process_frame
	print("PC_CAMERA: %d projections; maximum original-pixel error %.6f" % [checked, max_error])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
