extends SceneTree
const Bridge = preload("res://scripts/pc_bridge.gd")
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

func _initialize() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = root_path.path_join("artifacts/pc-live-godot")
	DirAccess.make_dir_recursive_absolute(output)
	started = Time.get_ticks_msec()
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty():
		python = "/opt/homebrew/bin/python3"
	bridge.start(python, root_path.path_join("reference/pc-live/mission-entry/reference.state"),
		output.path_join("saves"), output.path_join("host.log"))

func _process(_delta: float) -> bool:
	for message in bridge.poll():
		var state = message.get("state")
		if not state is Dictionary or state.get("basis") != "original-PC-SIM-read-only":
			errors.append("Missing original SIM state")
			_stop()
			break
		if message.type == "ready":
			initial = state
			if int(state.schema) != 2: errors.append("continuous world schema missing")
			if state.world.static.size() != 37: errors.append("original initial static pool differs")
			if not message.has("static_wire_geometry") or not message.static_wire_geometry.has("50"):
				errors.append("original static wire geometry missing")
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
		var report := {"errors": errors, "initial": initial, "snapshots": snapshots, "host_exit": bridge.exit_code()}
		var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
		if errors.is_empty():
			print("PC_LIVE_BRIDGE: original movement, stations, braking, turret, firing and child shutdown passed")
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
