extends SceneTree
## Research tandem view. Original PC executables own every game flow.
const PcAudio = preload("res://scripts/pc_audio.gd")
const Bridge = preload("res://scripts/pc_bridge.gd")
const Keyboard = preload("res://scripts/pc_keyboard.gd")
const WorldView = preload("res://scripts/pc_world_view.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
const PlayDisplay = preload("res://scripts/pc_play_display.gd")
var play_mode := false
var play_display: Control
var requested_window_size := Vector2i.ZERO
var requested_fullscreen := false
var pc_audio: Node
var audio_menu: MenuBar
var audio_drained := true
var world_view: Node3D
var draw_view: Node3D
var trace_mode := false
var boot_mode := false
var wire_mode := false
var gunner_art_requested := false
var cockpit_art_requested := false
var genesis_style = preload("res://scripts/pc_genesis_style.gd").new()
var genesis_colours_requested := false
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
var capture_effect := -1
var capture_effect_seen := false
var samples := 0
var output: String
var auto_steps := [[3, ["c"]], [30, []], [30, ["kp6"]], [30, []], [3, ["kp5"]], [60, []], [3, ["space"]], [300, []]]
var auto_index := 0
var campaign_capture_phase := ""
var campaign_review_pending := false
var campaign_choice := ""
var started: int
var fast_forward := 1
var pending_state_command: Dictionary = {}
var state_control_pending := false
var inflight_fast := false

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
	play_mode = trace_mode and "--play" in args and "--compare" not in args
	if play_mode:
		root.title = "Abrams Battle Tank"
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_factor = 1.0
		root.min_size = Vector2i(640,480)
		requested_window_size = Vector2i(1280,960)
	if "--window-size" in args:
		var index := args.find("--window-size")+1
		var requested := PlayDisplay.parse_extent(args[index] if index<args.size() else "")
		if requested==Vector2i.ZERO:
			printerr("--window-size requires WIDTHxHEIGHT, from 640x480 to 16384x16384")
			quit(2)
			return
		requested_window_size = requested
	requested_fullscreen = "--fullscreen" in args
	_configure_window.call_deferred()
	wire_mode = "--wire" in OS.get_cmdline_user_args()
	cockpit_art_requested = (play_mode and not wire_mode) or "--cockpit-art" in args or (trace_mode and "--original-art" not in args and "--gunner-art" not in args and not wire_mode)
	gunner_art_requested = "--gunner-art" in args or cockpit_art_requested
	genesis_colours_requested = (cockpit_art_requested or "--genesis-colours" in args) and "--pc-colours" not in args
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if genesis_colours_requested: genesis_style.load_palette(directory.path_join("reference/genesis/extracted/gunner/palette.gpl"))
	output = directory.path_join("artifacts/pc-boot-viewer" if boot_mode else ("artifacts/pc-trace-viewer" if trace_mode else "artifacts/pc-bridge-viewer"))
	if "--output" in args and args.find("--output")+1 < args.size(): output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	_build_ui()
	if trace_mode: tandem_frame.frontend_art.text_enabled = "--original-text" not in args
	if trace_mode and cockpit_art_requested and not wire_mode and "--flat-world" not in args:
		var terrain := preload("res://scripts/pc_terrain_style.gd").new()
		if terrain.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")):
			if "--original-hills" not in args: terrain.load_hills(directory)
			draw_view.terrain_style = terrain
	if trace_mode and cockpit_art_requested and not wire_mode and "--original-effects" not in args:
		var effects := preload("res://scripts/pc_effect_art.gd").new()
		if effects.load_assets(directory): draw_view.effect_art = effects
	# Retain original flat vehicle faces. The panel studies were rejected;
	# replacement models and textures are deliberately absent from live Play.
	if trace_mode and cockpit_art_requested and "--original-text" not in args:
		tandem_frame.typography.load_sources(directory.path_join("GAME"))
	if audio_requested(trace_mode,args):
		pc_audio = PcAudio.new()
		root.add_child(pc_audio)
	if play_mode:
		audio_menu=preload("res://scripts/pc_play_menu.gd").new()
		audio_menu.audio=pc_audio
		if capture: audio_menu.config_path=""
		audio_menu.load_settings()
		if pc_audio: pc_audio.set_mix(audio_menu.settings)
		root.add_child(audio_menu)
		audio_menu.graphics_selected.connect(_choose_graphics)
		audio_menu.speed_selected.connect(_choose_speed)
		audio_menu.state_requested.connect(_request_state)
		audio_menu.resized.connect(_layout_audio_menu)
		_layout_audio_menu.call_deferred()
	if trace_mode and cockpit_art_requested:
		tandem_frame.load_genesis_art(directory)
	elif trace_mode and gunner_art_requested:
		var art_path := directory.path_join("local-art/pc-ui-remastered/gunner-plate-v2.png")
		if FileAccess.file_exists(art_path): tandem_frame.set_gunner_art(Image.load_from_file(art_path))
	if play_mode:
		tandem_frame.load_graphics_sources(directory)
		var initial_mode := "ega" if "--original-art" in args else "upscaled"
		if "--graphics" in args:
			var index := args.find("--graphics")+1
			initial_mode=args[index] if index<args.size() else ""
			if initial_mode not in ["ega","genesis","upscaled"]:
				printerr("--graphics requires ega, genesis or upscaled; Modern artwork is not available")
				quit(2)
				return
		audio_menu.choose_graphics(initial_mode)
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty(): python = "/opt/homebrew/bin/python3"
	var state_path := "artifacts/pc-source-boot-01/mission-entry/reference.state" if trace_mode else "reference/pc-live/mission-entry/reference.state"
	var startup_state := "" if boot_mode else directory.path_join(state_path)
	# Frame-sensitive intro comparison requires a shared neutral START boundary.
	# This diagnostic alone uses it; ordinary Play continues to cold boot.
	if boot_mode and capture and "--capture-intro" in args:
		startup_state=directory.path_join("artifacts/pc-neutral-boot-01/neutral-boot/reference.state")
	var save_path := output.path_join("saves")
	if "--saves" in args:
		var index := args.find("--saves")+1
		if index>=args.size() or args[index].begins_with("--"):
			printerr("--saves requires a local save directory")
			quit(2)
			return
		save_path=ProjectSettings.globalize_path(args[index])
	bridge.start(python, startup_state, save_path,
		output.path_join("host.log"), "trace" if trace_mode else "reference", "--frame-audit" in args)
	if boot_mode and capture:
		auto_steps = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_boot_steps.json"))
	if capture and "--capture-menu" in args:
		var index:=args.find("--capture-menu")+1
		var phase:String=args[index] if index<args.size() else ""
		var conflict:=["--capture-intro","--capture-briefing","--capture-motor-pool","--capture-information","--capture-station","--capture-crew"].any(func(flag):return flag in args)
		if not boot_mode or conflict or phase not in ["joystick","main","scenario","name"]:
			bridge.failure="Menu capture requires cold boot, a supported phase, and no other route"
		elif phase=="joystick":auto_steps=[[1,[]]]
		elif phase=="main":auto_steps=auto_steps.slice(0,10)
		elif phase=="scenario":auto_steps=auto_steps.slice(0,12)
		else:
			auto_steps=auto_steps.slice(0,10)
			for key in ["right","return","return","n","e","l","l"]:auto_steps.append_array([[10,[key]],[90,[]]])
	if capture and "--capture-intro" in args:
		var conflict := ["--capture-briefing","--capture-motor-pool","--capture-information","--capture-station","--capture-crew"].any(func(flag):return flag in args)
		if not boot_mode or conflict:
			bridge.failure = "Intro capture requires START mode and no other route"
		else:
			var index:=args.find("--capture-intro")+1
			var phase: String=args[index] if index<args.size() and not args[index].begins_with("--") else "credits"
			if phase not in ["credits","dedication"]: bridge.failure="Unsupported intro capture phase"
			elif phase=="dedication": auto_steps=[[3,["return"]],[600,[]],[600,[]],[600,[]],[600,[]]]
			else: auto_steps = [[3,["return"]],[550,[]]]
	if capture and "--capture-briefing" in args:
		var index := args.find("--capture-briefing")+1
		var pose: String = args[index] if index<args.size() else ""
		var count: int = {"facepalm":16,"neutral":18,"speaking":20}.get(pose,0)
		if not boot_mode or count==0 or "--capture-station" in args or "--capture-crew" in args:
			bridge.failure = "Briefing capture requires cold boot, a supported pose, and no station/crew route"
		else: auto_steps = auto_steps.slice(0,count)
	if capture and "--capture-motor-pool" in args:
		if not boot_mode or "--capture-briefing" in args or "--capture-station" in args or "--capture-crew" in args:
			bridge.failure = "Motor-pool capture requires cold boot and no other capture route"
		else: auto_steps = auto_steps.slice(0,23)
	if capture and "--capture-information" in args:
		var index := args.find("--capture-information")+1
		var page: String = args[index] if index<args.size() else ""
		var conflict := ["--capture-briefing","--capture-motor-pool","--capture-station","--capture-crew"].any(func(flag):return flag in args)
		if not boot_mode or conflict or page not in ["crew","ax","heat","sabot","coax","cannon","smoke"]:
			bridge.failure = "Information capture requires cold boot, a supported page, and no other route"
		else:
			auto_steps.clear()
			var route: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_information_steps.json"))
			for step in route:
				var remaining := int(step.frames)
				while remaining>0:
					var chunk := mini(remaining,600)
					auto_steps.append([chunk,step.keys])
					remaining-=chunk
				if step.label==page: break

	if capture and "--capture-station" in args:
		var station_arg := args.find("--capture-station")+1
		var station: String = args[station_arg] if station_arg < args.size() else ""
		var key: String = {"gunner":"f1","commander":"f2","cupola":"f3","driver":"f4"}.get(station,"")
		if key.is_empty():
			bridge.failure = "Unsupported capture station"
		else:
			if not boot_mode: auto_steps = [[3,["f2"]],[300,[]]]
			auto_steps.append_array([[3,[key]],[300,[]]])
	if capture and "--capture-crew" in args:
		if not trace_mode:
			bridge.failure = "Crew capture requires the original trace backend"
		else:
			if not boot_mode and "--capture-station" not in args: auto_steps = [[30,[]]]
			# Same ordinary input pulses as capture_pc_render_trace.py's text
			# profile. No RAM edits or presentation-created crew messages.
			for i in 7: auto_steps.append_array([[3,["s"]],[30,[]]])
	if capture and "--capture-effect" in args:
		var index := args.find("--capture-effect")+1
		var requested: String = args[index] if index<args.size() else ""
		var conflict := ["--capture-crew","--capture-station","--capture-information","--capture-menu","--capture-intro","--capture-briefing","--capture-motor-pool"].any(func(flag):return flag in args)
		if boot_mode or not trace_mode or conflict or requested not in ["51","52","53"]:
			bridge.failure = "Effect capture requires --trace, a supported bitmap (51/52/53), and no other capture route"
		else:
			capture_effect = int(requested)
			auto_steps = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_effect_steps.json"))
			# Observe each original frame after firing; never synthesize a phase.
			for i in 300: auto_steps.append([1,[]])
	if capture and "--capture-vehicle" in args:
		var conflict := ["--capture-crew","--capture-station","--capture-information","--capture-menu","--capture-intro","--capture-briefing","--capture-motor-pool","--capture-effect"].any(func(flag):return flag in args)
		if boot_mode or not trace_mode or conflict:
			bridge.failure="Vehicle approach capture requires --trace and no other capture route"
		else:
			auto_steps=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_vehicle_approach_steps.json"))

	if capture and "--capture-campaign" in args:
		var index := args.find("--capture-campaign")+1
		var phase: String = args[index] if index<args.size() else ""
		var conflicts := Array(args).filter(func(arg):return str(arg).begins_with("--capture-") and arg!="--capture-campaign")
		if not boot_mode or not conflicts.is_empty() or phase not in ["new","continue"]:
			bridge.failure="Campaign capture requires cold boot, new/continue, and no other route"
		else:
			campaign_capture_phase=phase
			campaign_review_pending=phase=="new"
			auto_steps=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_campaign_steps.json"))[phase]

	# Large diagnostic batches can exceed the transport deadline under load.
	# Split only capture requests, preserving every frame and held-key value.
	if capture: auto_steps = capture_chunks(auto_steps)

static func audio_requested(tracing: bool, args: Array) -> bool:
	return tracing and "--no-audio" not in args

static func capture_chunks(steps: Array) -> Array:
	var result: Array = []
	for step: Array in steps:
		var remaining := int(step[0])
		while remaining>0:
			var count := mini(remaining,60)
			result.append([count,step[1].duplicate()])
			remaining -= count
	return result

func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _configure_window() -> void:
	# Startup project overrides are applied after SceneTree._initialize(). Apply
	# the requested native size once the real window exists, then trust its actual
	# size signals (including OS limits, HiDPI and fullscreen transitions).
	if requested_window_size!=Vector2i.ZERO: root.size = requested_window_size
	if requested_fullscreen: root.mode = Window.MODE_FULLSCREEN

func _layout_audio_menu() -> void:
	# macOS uses its menu bar without touching the image. Other backends reserve
	# a header above the largest complete 4:3 game rectangle, never over the HUD.
	if audio_menu and play_display:
		play_display.offset_top=0 if audio_menu.is_native_menu() else audio_menu.get_combined_minimum_size().y

func _build_play_ui() -> void:
	play_display = PlayDisplay.new()
	root.add_child(play_display)
	play_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_viewport = play_display.world_viewport
	tandem_viewport = play_display.tandem_viewport
	tandem_frame = play_display.tandem_frame
	# These retain diagnostic state/capture access without exposing extra tactical
	# information or research furniture over the original game screen.
	picture = TextureRect.new()
	status = _label("Starting the original PC game...",22)
	status.add_theme_constant_override("outline_size",4)
	status.add_theme_color_override("font_outline_color",Color.BLACK)
	caption = _label("",18)
	for node in [picture,status,caption]: play_display.add_child(node)
	picture.hide()
	caption.hide()
	status.position = Vector2(24,24)
	_build_stage(world_viewport)

func _build_ui() -> void:
	if play_mode:
		_build_play_ui()
		return
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
		column.add_child(_label("ORIGINAL PC FRAMEBUFFER" if side == 0 else (("GODOT / REMASTERED COCKPIT" if cockpit_art_requested else "GODOT WORLD / ORIGINAL COCKPIT" if not wire_mode else "GODOT WIREFRAME / ORIGINAL COCKPIT") if trace_mode else "GODOT: ORIGINAL CAMERA / STATIC FACES"), 19))
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
	var footer := "Original camera, draw queue, static detail selection and face rejection. Wireframe research view: dynamic vehicles, solid occlusion and materials are still pending."
	if trace_mode:
		footer = "Scanout-paired Godot world with original cockpit, reticle and messages. Source-resolution UI is temporary; high-resolution artwork and exact polygon edges remain open."
		if gunner_art_requested: footer = "Material pilot: verified gunner-surround pixels use high-resolution art. Instruments and other stations remain original. Camera geometry stays authoritative."
		if cockpit_art_requested: footer = "High-resolution cockpit materials follow original pixel provenance. Live instruments, messages, visibility and controls remain authoritative."
		if wire_mode: footer = "Original wireframe diagnostic. Omit --wire for filled surfaces."
	stack.add_child(_label(footer,17))

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

static func frame_remainder(elapsed_seconds: float, source_fps: float) -> float:
	# Keep the fractional phase. Resetting to zero turns 59.92 Hz into 30 Hz
	# under a steady 60 Hz redraw. Whole missed intervals are still discarded:
	# never invent a catch-up batch or backdate a newly sampled key press.
	return fmod(elapsed_seconds,1.0/source_fps)

func _advance_live_frame() -> bool:
	if capture or closing or state_control_pending or not pending_state_command.is_empty() or bridge.pending or not bridge.failure.is_empty() or elapsed<1.0/fps:
		return false
	elapsed=frame_remainder(elapsed,fps)
	# Sample current original keys once, never queue a second outstanding frame.
	var held := Keyboard.held()
	if audio_menu: held=audio_menu.game_keys(held)
	# Fast-forward changes wall-clock delivery only: the host still executes
	# every original frame in order at its unchanged emulated CPU settings.
	var sent: bool=bridge.step(fast_forward,held)
	if sent: inflight_fast=fast_forward>1
	return sent

func _choose_graphics(mode: String) -> void:
	if not tandem_frame.set_graphics_mode(mode):
		audio_menu.graphics_mode=tandem_frame.graphics_mode
		audio_menu.state_message="Requested graphics assets are unavailable."
		audio_menu.refresh_controls()

func _choose_speed(multiplier: int) -> void:
	fast_forward=multiplier
	elapsed=0.0
	if pc_audio: pc_audio.set_transport_muted(multiplier>1 or inflight_fast or state_control_pending or not pending_state_command.is_empty())
	if play_mode: root.title="Abrams Battle Tank" if multiplier==1 else "Abrams Battle Tank (%dx fast forward)"%multiplier

func _request_state(operation: String, slot: int) -> void:
	if closing or state_control_pending or not pending_state_command.is_empty(): return
	pending_state_command={"op":operation,"slot":slot}
	if pc_audio: pc_audio.set_transport_muted(true)

func _send_state_command() -> void:
	if pending_state_command.is_empty() or bridge.pending or state_control_pending: return
	if bridge.state_command(pending_state_command.op,int(pending_state_command.slot)):
		state_control_pending=true
		pending_state_command.clear()

func _state_result(message: Dictionary) -> void:
	# Restored samples carry their own original snapshot and a new audio
	# timeline. This control response never advances or injects a game key.
	var restored = message.get("restored")
	if restored is Dictionary:
		_apply_sample(restored)
	state_control_pending=false
	if audio_menu and audio_menu.has_method("set_state_status"):
		audio_menu.set_state_status(message.get("slots",[]),str(message.get("message","State operation finished")))
	if pc_audio: pc_audio.set_transport_muted(fast_forward>1)
	elapsed=0.0

func _capture_deadline_msec() -> int:
	return 180000 if boot_mode or "--capture-vehicle" in OS.get_cmdline_user_args() else 60000

func _process(delta: float) -> bool:
	elapsed += delta
	for message in bridge.poll():
		if message.type=="state_result": _state_result(message)
		else: _apply_sample(message)
	if not bridge.failure.is_empty():
		status.text = "Game stopped: " + bridge.failure + "\nClose this window to exit."
		status.show()
		if capture: _close()
		elif not closing:
			# Keep actionable failures visible instead of making Play disappear.
			bridge.close()
			if pc_audio: pc_audio.stop_all()
			return false
	if closing:
		if bridge.has_exited() and audio_drained: quit(0 if bridge.failure.is_empty() and bridge.exit_code() == 0 else 1)
		return false
	if not bridge.pending:
		if not pending_state_command.is_empty():
			_send_state_command()
			return false
		if capture:
			if auto_index < auto_steps.size():
				var step: Array = auto_steps[auto_index]
				auto_index += 1
				bridge.step(step[0], step[1])
			elif campaign_review_pending:
				# Diagnostic driver only: END may show a different number of review
				# pages. Select R+R only after its exact original prompt is visible.
				if not campaign_choice.is_empty():
					if campaign_choice=="continue": auto_steps.append_array([[10,["left"]],[90,[]]])
					auto_steps.append_array([[10,["return"]],[600,[]]])
					campaign_review_pending=false
				elif previous_program.get("name")=="END":
					auto_steps.append_array([[10,["space"]],[90,[]]])
				else:
					bridge.failure="Campaign capture left END before the original R+R prompt"
				# Rechunk the unconsumed suffix without changing the delivered prefix.
				auto_steps=auto_steps.slice(0,auto_index)+capture_chunks(auto_steps.slice(auto_index))
			elif not capture_done:
				capture_done = true
				if capture_effect>=0 and not capture_effect_seen:
					bridge.failure = "Original effect was not observed before capture route ended"
					_close()
				else: _capture.call_deferred()
		else:
			_advance_live_frame()
	if capture and Time.get_ticks_msec() - started > _capture_deadline_msec():
		bridge.failure = "capture deadline"
		_close()
	return false

func _apply_sample(message: Dictionary) -> void:
	if message.get("timeline_reset",false) and pc_audio: pc_audio.reset_timeline()
	if message.has("slots") and audio_menu and audio_menu.has_method("set_state_status"):
		audio_menu.set_state_status(message.slots)
	if pc_audio and pc_audio.has_method("set_transport_muted"):
		pc_audio.set_transport_muted(fast_forward>1 or inflight_fast or state_control_pending or not pending_state_command.is_empty())
	inflight_fast=false
	if pc_audio and not pc_audio.apply_audio(message.get("audio", {})):
		bridge.failure = pc_audio.failure
		return
	if pc_audio and pc_audio.has_method("set_transport_muted"):
		pc_audio.set_transport_muted(fast_forward>1 or state_control_pending or not pending_state_command.is_empty())
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
	if campaign_review_pending:
		var probe := image.duplicate()
		probe.convert(Image.FORMAT_RGB8)
		var digest := HashingContext.new()
		digest.start(HashingContext.HASH_SHA256)
		digest.update(probe.get_data())
		campaign_choice={
			"179660660519b1e466871e94b9bae9ecae5c35ce22a92a1b19d9f7b2c36ecfba":"continue",
			"dd261b967d88052666983f1d36607c8935192ef56ed2bc2e9f0e406487662433":"rest"
		}.get(digest.finish().hex_encode(),"")
	# The completed packet owns its pixels and metadata. Once validated, the
	# original host may compute the next frame while we build this presentation.
	# All Godot scene work remains on the main thread; capture never prefetches.
	_advance_live_frame()
	picture.texture = ImageTexture.create_from_image(image)
	if play_mode: status.hide()
	previous_program = message.get("program", {}) if message.get("program") is Dictionary else {}
	if pc_audio:
		var music_context: String=pc_audio.music_context_for_frame(image,previous_program,message.get("presentation",{}))
		# Frontend music follows the user's mix; original SIM F5/pause gates
		# continue to govern gameplay audio. Unknown frontend frames stay quiet.
		pc_audio.apply_music_context(music_context,true)
	if not state is Dictionary:
		previous = {}
		previous_presentation = message.get("presentation", {})
		draw_view.apply_pass({"objects": []})
		tandem_frame.set_frame(image, previous_presentation, null, previous_program)
		status.text = "ORIGINAL PC: " + str(previous_program.get("name","STARTING"))
		caption.text = "Original menu/briefing or SIM initialization. Showing the original framebuffer; no substitute simulation."
		if trace_mode and cockpit_art_requested and tandem_frame.present_frontend(previous_program):
			caption.text = "GENESIS ART: " + tandem_frame.frontend_art.active.name + " | original PC content, timing and controls"
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
			draw_view.presentation_palette = genesis_style.for_original(displayed.palette_rgb) if genesis_colours_requested else []
			draw_view.apply_pass(displayed)
			if capture_effect>=0 and not capture_effect_seen:
				for object: Dictionary in displayed.objects:
					if object.get("sprite_status","")=="observed" and int(object.get("bitmap_index",-1))==capture_effect:
						capture_effect_seen = true
						auto_index = auto_steps.size()
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
		if play_mode: play_display.set_camera_dimensions(dimensions)
		else: world_viewport.size = dimensions * 4
		# Source 320x200 pixels stretch to 4:3 outside the 3D projection.
		if not trace_mode: world_aspect.ratio = float(dimensions.x) / (float(dimensions.y) * 1.2)
	if trace_mode:
		tandem_frame.set_frame(image, previous_presentation, world_viewport.get_texture(), previous_program)
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
		if cockpit_art_requested:
			caption.text += "\nGENESIS-DERIVED COCKPITS: " + str(tandem_frame.cockpit_art_ids) + " | PC live values"
			caption.text += " | illustrated instrument cells: %d" % tandem_frame.instrument_art.active.size()
			caption.text += " | vector gauges: %d" % tandem_frame.instrument_art.gauges.size()
			caption.text += " | source-verified graticule" if not tandem_frame.reticle_art.packet.is_empty() else ""
			if not tandem_frame.portrait_art.active.is_empty(): caption.text += " | Genesis " + tandem_frame.portrait_art.active.name + " portrait"
			caption.text += " | moving driver assembly" if tandem_frame.driver_assembly_enabled else ""
			caption.text += " | Genesis colour study" if genesis_colours_requested and not genesis_style.palette.is_empty() else ""
			caption.text += " | terrain detail" if draw_view.terrain_active else ""
			caption.text += " | verified high-res text: %d" % tandem_frame.typography.runs.size()
		elif gunner_art_requested:
			caption.text += "\n" + ("HIGH-RES GUNNER SURROUND: original instruments retained" if tandem_frame.gunner_art_enabled else "ORIGINAL MATERIALS: " + tandem_frame.gunner_art_reason)
	if trace_mode and cockpit_art_requested and tandem_frame.present_frontend(previous_program):
		caption.text = "GENESIS MOTOR POOL: original PC arming menu, values and controls"
	previous = state

func _capture() -> void:
	if not campaign_capture_phase.is_empty():
		var expected_program := "START" if campaign_capture_phase=="new" else "SIM"
		if previous_program.get("name")!=expected_program or (expected_program=="SIM" and previous.is_empty()):
			bridge.failure="Campaign capture did not reach its original save/resume boundary"
			_close()
			return
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
		"graphics_mode":tandem_frame.graphics_mode if trace_mode else "reference","fast_forward":fast_forward,
		"display": play_display.description() if play_mode else {"mode":"comparison"},
		"ui_composited": tandem_frame.world_enabled if trace_mode else false,
		"audio": {"delivered": pc_audio.delivered, "suppressed": pc_audio.suppressed, "receipts": pc_audio.receipts, "loop_transitions": pc_audio.loop_transitions} if pc_audio else null,
		"gunner_materials": tandem_frame.gunner_art_enabled if trace_mode else false,
		"driver_assembly": tandem_frame.driver_assembly_enabled if trace_mode else false,
		"genesis_colours": genesis_colours_requested and not genesis_style.palette.is_empty(),
		"world_bearing_text": tandem_frame.typography.runs.filter(func(r):return r.get("transparent_world",false)).map(func(r):return r.text) if trace_mode else [],
		"high_resolution_text_runs": tandem_frame.typography.runs.size() if trace_mode else 0,
		"terrain_detail": draw_view.terrain_active if trace_mode else false,
		"terrain_polygons": draw_view.terrain_polygon_count if trace_mode else 0,
		"hill_polygons": draw_view.hill_polygon_count if trace_mode else 0,
		"vehicle_polygons": draw_view.vehicle_polygon_count if trace_mode else 0,
		"effect_art": draw_view.effect_art_ids if trace_mode else [],
		"cockpit_materials": tandem_frame.cockpit_art_ids if trace_mode else [],
		"genesis_art": tandem_frame.genesis_art_enabled if trace_mode else false,
		"instrument_art": tandem_frame.instrument_art.active.map(func(item): return item.name) if trace_mode else [],
		"orientation_art": tandem_frame.instrument_art.orientation.packet if trace_mode else {},
		"reticle_art": tandem_frame.reticle_art.packet if trace_mode else {},
		"instrument_gauges": tandem_frame.instrument_art.gauges.map(func(item): return item.name) if trace_mode else [],
		"portrait_art": {"id":tandem_frame.portrait_art.active.id,"name":tandem_frame.portrait_art.active.name} if trace_mode and not tandem_frame.portrait_art.active.is_empty() else null,
		"frontend_art": tandem_frame.frontend_art.active if trace_mode else {},
		"frontend_text": tandem_frame.frontend_art.typography.runs.map(func(r):return r.text) if trace_mode else [],
		"menu_text": tandem_frame.frontend_art.flow_typography.runs.map(func(r):return r.text) if trace_mode else [],
		"scope": ("scanout-paired original wireframe diagnostic" if wire_mode else "scanout-paired Godot surfaces and effects; optional proven-pixel cockpit materials with original instruments/HUD; exact raster edges and unsupported commands remain open") if trace_mode else "original camera and static face selection; dynamic rendering, solid occlusion and materials unresolved"}, "  "))
	print("PC_BRIDGE_VIEW_CAPTURED " + output)
	_close()

func _drain_audio() -> void:
	if not await pc_audio.drain_for_shutdown(): bridge.failure = "Original-event audio did not drain"
	audio_drained = true

func _close() -> void:
	if closing: return
	if pc_audio:
		audio_drained = false
		_drain_audio.call_deferred()
	if not closing and not bridge.failure.is_empty(): printerr("PC_VIEW_FAILED: " + bridge.failure)
	closing = true
	bridge.close()
