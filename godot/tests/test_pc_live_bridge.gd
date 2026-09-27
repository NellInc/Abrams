extends SceneTree
const Bridge = preload("res://scripts/pc_bridge.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var bridge = Bridge.new()
var steps := [[3, ["f4"]], [30, []], [60, ["kp8"]], [60, []],
	[3, ["kp5"]], [240, []], [3, ["f1"]], [30, []], [3, ["c"]], [30, []],
	[60, ["kp6"]], [60, []], [3, ["kp5"]], [60, []], [3, ["space"]], [300, []]]
var snapshots: Array = []
var initial: Dictionary = {}
var output: String
var started: int
var stopping := false
var errors: Array[String] = []
var trace_mode := false
var paired_count := 0
var vehicle_polygons := 0
var unsupported_count := 0
var presentations: Array = []
var draw_view: Node3D
var tandem_frame: TextureRect
var ui_paired_count := 0

func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	trace_mode = "--trace" in OS.get_cmdline_user_args()
	output = root_path.path_join("artifacts/pc-trace-live-godot" if trace_mode else "artifacts/pc-live-godot")
	draw_view = DrawPass.new()
	draw_view.solid_enabled = trace_mode
	root.add_child(draw_view)
	if trace_mode:
		tandem_frame = TandemFrame.new()
		root.add_child(tandem_frame)
	DirAccess.make_dir_recursive_absolute(output)
	started = Time.get_ticks_msec()
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty():
		python = "/opt/homebrew/bin/python3"
	var state_path := "artifacts/pc-source-boot-01/mission-entry/reference.state" if trace_mode else "reference/pc-live/mission-entry/reference.state"
	bridge.start(python, root_path.path_join(state_path), output.path_join("saves"),
		output.path_join("host.log"), "trace" if trace_mode else "reference")

func _process(_delta: float) -> bool:
	for message in bridge.poll():
		var state = message.get("state")
		if not state is Dictionary or state.get("basis") != "original-PC-SIM-read-only":
			errors.append("Missing original SIM state")
			_stop()
			break
		if trace_mode:
			var presentation: Dictionary = message.get("presentation", {})
			var drawing = presentation.get("draw_pass")
			if drawing is Dictionary:
				var displayed: Dictionary = drawing.duplicate(false)
				if presentation.get("palette_rgb") is Array:
					displayed.palette_rgb = presentation.palette_rgb
				draw_view.apply_pass(displayed)
				errors.append_array(draw_view.render_warnings)
				paired_count += 1
				vehicle_polygons += draw_view.dynamic_polygon_count
				unsupported_count += drawing.unsupported.size()
				var original := Image.new()
				if original.load_png_from_buffer(Marshalls.base64_to_raw(message.png)) == OK:
					if tandem_frame.set_frame(original,presentation,ImageTexture.create_from_image(original)):
						ui_paired_count += 1
					else: errors.append("paired UI unavailable: " + tandem_frame.fallback_reason)
				else: errors.append("paired UI source PNG unavailable")
				presentations.append({"sequence": message.sequence, "scanout": presentation.scanout_sequence,
					"page": presentation.page_offset, "draw": drawing.sequence, "polygons": draw_view.polygon_count,
					"vehicle_polygons": draw_view.dynamic_polygon_count, "unsupported": drawing.unsupported})
			else:
				presentations.append({"sequence": message.sequence, "reason": presentation.get("reason", "missing")})
		if message.type == "ready":
			initial = state
			if int(state.schema) != 2: errors.append("continuous world schema missing")
			if state.world.static.size() != 37: errors.append("original initial static pool differs")
			if not trace_mode and (not message.has("static_wire_geometry") or not message.static_wire_geometry.has("50")):
				errors.append("original static wire geometry missing")
			elif not trace_mode and not message.static_wire_geometry["50"] is Dictionary:
				errors.append("source primitive IDs missing from geometry")
			if not state.camera is Dictionary or (not trace_mode and state.render_static_faces.is_empty()):
				errors.append("original camera/static face selection missing")
		else:
			snapshots.append(state)
		if snapshots.size() < steps.size():
			var step: Array = steps[snapshots.size()]
			bridge.step(step[0], step[1])
		else:
			if snapshots[1].station != "driver": errors.append("driver station not forwarded")
			if snapshots[3].position_raw == initial.position_raw: errors.append("original player did not move")
			if snapshots[5].speed_raw != 0: errors.append("original braking did not finish")
			if snapshots[5].world.window_origin == initial.world.window_origin: errors.append("original world did not rebase")
			if snapshots[5].world_position_raw[1] >= initial.world_position_raw[1]: errors.append("northward world position did not advance")
			if snapshots[7].station != "gunner": errors.append("gunner station not forwarded")
			if snapshots[13].turret_relative_u8 == snapshots[7].turret_relative_u8: errors.append("turret did not rotate")
			if snapshots[-1].ammunition.HEAT != initial.ammunition.HEAT - 1: errors.append("HEAT consumption mismatch")
			if trace_mode and (paired_count < 12 or vehicle_polygons == 0):
				errors.append("scanout-paired vehicle geometry missing")
			if trace_mode and ui_paired_count != paired_count:
				errors.append("scanout-paired UI masks missing")
			var image := Image.new()
			if image.load_png_from_buffer(Marshalls.base64_to_raw(message.png)) != OK:
				errors.append("Original framebuffer PNG failed to decode")
			else:
				image.save_png(output.path_join("original-after-fire.png"))
			_stop()
	if not bridge.failure.is_empty() and not stopping:
		errors.append(bridge.failure)
		_stop()
	if stopping and bridge.has_exited():
		if bridge.exit_code() != 0: errors.append("Host exit code %s" % bridge.exit_code())
		var report := {"errors": errors, "initial": initial, "snapshots": snapshots, "host_exit": bridge.exit_code(), "backend": "trace" if trace_mode else "reference",
			"paired_count": paired_count, "ui_paired_count": ui_paired_count, "vehicle_polygons": vehicle_polygons, "unsupported_count": unsupported_count, "presentations": presentations}
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		if errors.is_empty():
			print("PC_LIVE_BRIDGE: original movement, stations, braking, turret, firing and child shutdown passed; paired draws %d, UI masks %d, vehicle polygons %d, unsupported commands %d" % [paired_count, ui_paired_count, vehicle_polygons, unsupported_count])
		else:
			for error in errors: printerr("FAIL: " + error)
		quit(0 if errors.is_empty() else 1)
	if Time.get_ticks_msec() - started > 90000:
		printerr("FAIL: live bridge test deadline; child was asked to close")
		bridge.close()
		quit(1)
	return false

func _stop() -> void:
	stopping = true
	bridge.close()
