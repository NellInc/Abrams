extends SceneTree
## Research tandem view. Original PC executables own every game flow.
const Bridge = preload("res://scripts/pc_bridge.gd")
const Keyboard = preload("res://scripts/pc_keyboard.gd")
const WorldView = preload("res://scripts/pc_world_view.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var world_view: Node3D
var draw_view: Node3D
var trace_mode := false
var boot_mode := false
var wire_mode := false
var previous_presentation: Dictionary = {}
var world_viewport: SubViewport
var world_aspect: AspectRatioContainer
var tandem_frame: TextureRect
var tandem_viewport: SubViewport
var bridge = Bridge.new()
var camera: Camera3D
var picture: TextureRect
var status: Label
var caption: Label
var previous: Dictionary = {}
var previous_program: Dictionary = {}
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

func _initialize() -> void:
	root.title = "Abrams: original PC / Godot bridge research"
	root.size = Vector2i(1440, 900)
	root.min_size = Vector2i(1100, 750)
	root.close_requested.connect(_close)
	auto_accept_quit = false
	started = Time.get_ticks_msec()
	capture = "--capture" in OS.get_cmdline_user_args()
	var args := OS.get_cmdline_user_args()
	boot_mode = "--boot" in args or ("--trace" not in args and "--reference" not in args)
	trace_mode = boot_mode or "--trace" in OS.get_cmdline_user_args()
	wire_mode = "--wire" in OS.get_cmdline_user_args()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = directory.path_join("artifacts/pc-boot-viewer" if boot_mode else ("artifacts/pc-trace-viewer" if trace_mode else "artifacts/pc-bridge-viewer"))
	DirAccess.make_dir_recursive_absolute(output)
	_build_ui()
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty(): python = "/opt/homebrew/bin/python3"
	var state_path := "artifacts/pc-source-boot-01/mission-entry/reference.state" if trace_mode else "reference/pc-live/mission-entry/reference.state"
	bridge.start(python, "" if boot_mode else directory.path_join(state_path), output.path_join("saves"),
		output.path_join("host.log"), "trace" if trace_mode else "reference")
	if boot_mode and capture:
		auto_steps = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_boot_steps.json"))

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
		column.add_child(_label("ORIGINAL PC FRAMEBUFFER" if side == 0 else (("GODOT WORLD / ORIGINAL COCKPIT" if not wire_mode else "GODOT WIREFRAME / ORIGINAL COCKPIT") if trace_mode else "GODOT: ORIGINAL CAMERA / STATIC FACES"), 19))
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
			world_aspect = AspectRatioContainer.new()
			world_aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
			column.add_child(world_aspect)
			var display := TextureRect.new()
			display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			world_aspect.add_child(display)
			world_viewport = SubViewport.new()
			world_viewport.size = Vector2i(1024, 388)
			world_viewport.own_world_3d = true
			world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			display.add_child(world_viewport)
			if trace_mode:
				world_aspect.ratio = 4.0 / 3.0
				tandem_viewport = SubViewport.new()
				tandem_viewport.size = Vector2i(1280, 800)
				tandem_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				display.add_child(tandem_viewport)
				# Explicit child-first viewport ordering: the composition must
				# sample this pass's world, including the first resized frame.
				world_viewport.reparent(tandem_viewport)
				tandem_frame = TandemFrame.new()
				tandem_frame.size = Vector2(1280, 800)
				tandem_viewport.add_child(tandem_frame)
				display.texture = tandem_viewport.get_texture()
			else:
				display.texture = world_viewport.get_texture()
			_build_stage(world_viewport)
	status = _label("Starting the locally supplied PC game...", 22)
	stack.add_child(status)
	caption = _label("", 18)
	stack.add_child(caption)
	stack.add_child(_label("Arrows/keypad: original controls   Enter: select   Q: mission quit   Esc: pause/back   F1 to F4: stations", 18))
	stack.add_child(_label(("Original wireframe diagnostic. Omit --wire for filled surfaces." if wire_mode else "Scanout-paired Godot world with original cockpit, reticle and messages. Source-resolution UI is temporary; high-resolution artwork and exact polygon edges remain open.") if trace_mode else "Original camera, draw queue, static detail selection and face rejection. Wireframe research view: dynamic vehicles, solid occlusion and materials are still pending.", 17))

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
	world_view = WorldView.new()
	world.add_child(world_view)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.look_at_from_position(Vector3(10, 8, 12), Vector3(0, 1.5, 0))
	camera.make_current()
	draw_view = DrawPass.new()
	draw_view.solid_enabled = trace_mode and not wire_mode
	camera.add_child(draw_view)
	world_view.visible = not trace_mode

func _process(delta: float) -> bool:
	elapsed += delta
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
			bridge.step(1, Keyboard.held())
	if capture and Time.get_ticks_msec() - started > (180000 if boot_mode else 60000):
		bridge.failure = "capture deadline"
		_close()
	return false

func _apply_sample(message: Dictionary) -> void:
	var state = message.get("state")
	if not state is Dictionary and not trace_mode:
		bridge.failure = "SIM state is unavailable. No substitute simulation was started."
		return
	samples += 1
	if capture: print("PC_VIEW_SAMPLE %d sequence=%d" % [samples, int(message.sequence)])
	fps = float(message.fps)
	var image := Image.new()
	if image.load_png_from_buffer(Marshalls.base64_to_raw(message.png)) != OK:
		bridge.failure = "invalid original framebuffer"
		return
	picture.texture = ImageTexture.create_from_image(image)
	previous_program = message.get("program", {}) if message.get("program") is Dictionary else {}
	if not state is Dictionary:
		previous = {}
		previous_presentation = message.get("presentation", {})
		draw_view.apply_pass({"objects": []})
		tandem_frame.set_frame(image, {}, null)
		status.text = "ORIGINAL PC: " + str(previous_program.get("name","STARTING"))
		caption.text = "Original menu/briefing or SIM initialization. Showing the original framebuffer; no substitute simulation."
		return
	if message.has("static_wire_geometry"):
		world_view.set_geometry(message.static_wire_geometry)
	var position: Array = state.world_position_raw
	var frame = state.camera
	if trace_mode:
		previous_presentation = message.get("presentation", {})
		var drawing = previous_presentation.get("draw_pass")
		if drawing is Dictionary:
			var displayed: Dictionary = drawing.duplicate(false)
			if previous_presentation.get("palette_rgb") is Array:
				displayed.palette_rgb = previous_presentation.palette_rgb
			draw_view.apply_pass(displayed)
			frame = drawing.camera.duplicate(true)
			frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
			frame.world_position_raw = [0,0,0]
		else:
			draw_view.apply_pass({"objects": []})
			frame = null
	else:
		world_view.apply_state(state)
	if frame is Dictionary:
		var dimensions: Vector2i = PcCamera.apply(camera, frame, Vector3.ZERO if trace_mode else world_view.anchor)
		world_viewport.size = dimensions * 4
		# Source 320x200 pixels stretch to 4:3 outside the 3D projection.
		if not trace_mode: world_aspect.ratio = float(dimensions.x) / (float(dimensions.y) * 1.2)
	if trace_mode:
		tandem_frame.set_frame(image, previous_presentation, world_viewport.get_texture())
	status.text = "%s   HEADING %03d   SIGHT %03d   SPEED %d   FUEL %d" % [str(state.station).to_upper(), state.heading_degrees, state.bearing_degrees, state.speed_display, state.fuel_display]
	caption.text = "HEAT %d   SABOT %d   AX %d   COAX %d     World: %s   Window: %s   Objects: %d" % [state.ammunition.HEAT, state.ammunition.SABOT, state.ammunition.AX, state.ammunition.COAX, str(position), str(state.world.window_origin), state.world.static.size()]
	if trace_mode:
		var drawing = previous_presentation.get("draw_pass")
		if drawing is Dictionary:
			caption.text += "\nDraw pass %d   Vehicle polygons %d   Sprites %d   Unsupported commands %d" % [int(drawing.sequence), draw_view.dynamic_polygon_count, draw_view.sprite_count, drawing.unsupported.size() + draw_view.render_warnings.size()]
		else:
			caption.text += "\nNo paired geometry: " + str(previous_presentation.get("reason", "awaiting scanout"))
		if not tandem_frame.world_enabled:
			caption.text += "\nORIGINAL FRAME FALLBACK: " + tandem_frame.fallback_reason
	previous = state

func _capture() -> void:
	print("PC_VIEW_CAPTURE_WAIT")
	await process_frame
	# Captures must not wait indefinitely for an OS-scheduled window redraw.
	# This deferred method runs on the main thread and advances no PC frames.
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	root.get_texture().get_image().save_png(output.path_join("paired-view.png"))
	world_viewport.get_texture().get_image().save_png(output.path_join("surface-view.png"))
	if trace_mode: tandem_viewport.get_texture().get_image().save_png(output.path_join("tandem-frame.png"))
	picture.texture.get_image().save_png(output.path_join("original-frame.png"))
	var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"state": previous, "program": previous_program, "samples": samples, "presentation": previous_presentation,
		"ui_composited": tandem_frame.world_enabled if trace_mode else false,
		"scope": ("scanout-paired original wireframe diagnostic" if wire_mode else "scanout-paired Godot surfaces and effects with original source-resolution cockpit/HUD; exact raster edges and unsupported commands remain open") if trace_mode else "original camera and static face selection; dynamic rendering, solid occlusion and materials unresolved"}, "  "))
	print("PC_BRIDGE_VIEW_CAPTURED " + output)
	_close()

func _close() -> void:
	if not closing and not bridge.failure.is_empty(): printerr("PC_VIEW_FAILED: " + bridge.failure)
	closing = true
	bridge.close()
