extends SceneTree
## Diagnostic native view, not an original mission renderer or finished remaster.
const Bridge = preload("res://scripts/pc_bridge.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
var bridge = Bridge.new()
var vehicle: Node3D
var camera: Camera3D
var picture: TextureRect
var status: Label
var caption: Label
var previous: Dictionary = {}
var elapsed := 0.0
var fps := 59.9227
var closing := false
var capture := false
var capture_done := false
var samples := 0
var output: String
var auto_steps := [[3, ["c"]], [30, []], [30, ["kp6"]], [30, []], [3, ["kp5"]], [60, []], [3, ["space"]], [300, []]]
var auto_index := 0
var started: int
const INPUTS = {KEY_UP: "kp8", KEY_DOWN: "kp2", KEY_LEFT: "kp4", KEY_RIGHT: "kp6",
	KEY_KP_8: "kp8", KEY_KP_2: "kp2", KEY_KP_4: "kp4", KEY_KP_6: "kp6", KEY_KP_5: "kp5", KEY_5: "kp5",
	KEY_F1: "f1", KEY_F2: "f2", KEY_F3: "f3", KEY_F4: "f4", KEY_C: "c", KEY_A: "a",
	KEY_SPACE: "space", KEY_ENTER: "return", KEY_1: "1", KEY_2: "2", KEY_3: "3",
	KEY_M: "m", KEY_R: "r", KEY_S: "s", KEY_T: "t", KEY_Z: "z", KEY_L: "l"}

func _initialize() -> void:
	root.title = "Abrams: original PC / Godot bridge research"
	root.size = Vector2i(1440, 900)
	root.min_size = Vector2i(1100, 750)
	root.close_requested.connect(_close)
	auto_accept_quit = false
	started = Time.get_ticks_msec()
	capture = "--capture" in OS.get_cmdline_user_args()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = directory.path_join("artifacts/pc-bridge-viewer")
	DirAccess.make_dir_recursive_absolute(output)
	_build_ui()
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty(): python = "/opt/homebrew/bin/python3"
	bridge.start(python, directory.path_join("reference/pc-live/mission-entry/reference.state"),
		output.path_join("saves"), output.path_join("host.log"))

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _build_ui() -> void:
	var canvas := Control.new()
	root.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("141b1d")
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	canvas.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 24)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	stack.add_child(_label("ABRAMS  /  ORIGINAL PC TO GODOT", 32))
	stack.add_child(_label("Live bridge research. The original executable owns movement, turning and ammunition.", 20))
	var panels := HBoxContainer.new()
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.add_theme_constant_override("separation", 24)
	stack.add_child(panels)
	for side in 2:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panels.add_child(column)
		column.add_child(_label("ORIGINAL PC FRAMEBUFFER" if side == 0 else "GODOT: READ-ONLY VEHICLE POSE", 19))
		if side == 0:
			var aspect := AspectRatioContainer.new()
			aspect.ratio = 4.0 / 3.0
			aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			column.add_child(aspect)
			picture = TextureRect.new()
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			aspect.add_child(picture)
		else:
			var container := SubViewportContainer.new()
			container.stretch = true
			container.size_flags_vertical = Control.SIZE_EXPAND_FILL
			column.add_child(container)
			var viewport := SubViewport.new()
			viewport.size = Vector2i(640, 480)
			viewport.own_world_3d = true
			container.add_child(viewport)
			_build_stage(viewport)
	status = _label("Starting the locally supplied PC game...", 22)
	stack.add_child(status)
	caption = _label("", 18)
	stack.add_child(caption)
	stack.add_child(_label("Arrows: original keypad controls   5: stop/brake   C: hull/turret   Space: fire   F1 to F4: stations", 18))
	stack.add_child(_label("Diagnostic stage only. Terrain, camera matching and visibility are pending. Translation uses an explicit 1:64 display scale; original world units remain unverified.", 17))

func _build_stage(viewport: SubViewport) -> void:
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("293338")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c3ced2")
	environment.environment.ambient_light_energy = 0.65
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3b4847")
	for axis in 2:
		for offset in range(-40, 41, 4):
			var line := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(80, 0.03, 0.04) if axis == 0 else Vector3(0.04, 0.03, 80)
			line.mesh = mesh
			line.material_override = mat
			line.position = Vector3(0, 0, offset) if axis == 0 else Vector3(offset, 0, 0)
			world.add_child(line)
	vehicle = Vehicle.new()
	world.add_child(vehicle)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(10, 8, 12), Vector3(0, 1.5, 0))
	camera.make_current()

func _process(delta: float) -> bool:
	elapsed += delta
	vehicle.update_pose(vehicle.turret_root.rotation.y, delta)
	for message in bridge.poll():
		_apply_sample(message)
	if not bridge.failure.is_empty():
		status.text = "Bridge stopped: " + bridge.failure
		_close()
	if closing:
		if bridge.has_exited(): quit(0 if bridge.failure.is_empty() and bridge.exit_code() == 0 else 1)
		return false
	if not bridge.pending:
		if capture:
			if auto_index < auto_steps.size():
				var step: Array = auto_steps[auto_index]
				auto_index += 1
				bridge.step(step[0], step[1])
			elif not capture_done:
				capture_done = true
				_capture.call_deferred()
		elif elapsed >= 1.0 / fps:
			# One outstanding request. Slow presentation never advances invented
			# gameplay ticks or runs the authored range alongside the PC game.
			elapsed = 0.0
			var keys: Array = []
			for key in INPUTS:
				if Input.is_key_pressed(key) and INPUTS[key] not in keys: keys.append(INPUTS[key])
			bridge.step(1, keys)
	if capture and Time.get_ticks_msec() - started > 60000:
		bridge.failure = "capture deadline"
		_close()
	return false

func _apply_sample(message: Dictionary) -> void:
	var state = message.get("state")
	if not state is Dictionary:
		bridge.failure = "SIM state is unavailable. No substitute simulation was started."
		return
	samples += 1
	fps = float(message.fps)
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(message.png)) != OK:
		bridge.failure = "invalid original framebuffer"
		return
	picture.texture = ImageTexture.create_from_image(image)
	var position: Array = state.position_raw
	vehicle.position = Vector3((float(position[0]) - 2048.0) / 64.0, 0, -(float(position[1]) - 2048.0) / 64.0)
	vehicle.rotation.y = float(state.hull_angle_u8) * TAU / 256.0
	vehicle.update_pose(float(state.turret_relative_u8) * TAU / 256.0, 0)
	camera.position = vehicle.position + Vector3(10, 8, 12)
	camera.look_at(vehicle.position + Vector3(0, 1.5, 0))
	if not previous.is_empty():
		for weapon in ["HEAT", "SABOT", "AX"]:
			if state.ammunition[weapon] < previous.ammunition[weapon]: vehicle.recoil = 0.4
	status.text = "%s   HEADING %03d   SIGHT %03d   SPEED %d   FUEL %d" % [str(state.station).to_upper(), state.heading_degrees, state.bearing_degrees, state.speed_display, state.fuel_display]
	caption.text = "HEAT %d   SABOT %d   AX %d   COAX %d     Original coordinates: %s     Sample %d" % [state.ammunition.HEAT, state.ammunition.SABOT, state.ammunition.AX, state.ammunition.COAX, str(position), int(message.sequence)]
	previous = state

func _capture() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("paired-view.png"))
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"state": previous, "samples": samples, "scope": "diagnostic pose only"}, "  "))
	print("PC_BRIDGE_VIEW_CAPTURED " + output)
	_close()

func _close() -> void:
	closing = true
	bridge.close()
