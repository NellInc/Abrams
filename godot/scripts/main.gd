extends Node3D

const Simulation = preload("res://scripts/simulation.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const Landscape = preload("res://scripts/landscape.gd")
const CoverScene = preload("res://scripts/cover_scene.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/audio.gd")

var sim = Simulation.new()
var vehicle: Node3D
var camera: Camera3D
var sound: Node
var ui: Control
var environment: Environment
var world_environment: WorldEnvironment
var cover_scene: Node3D
var landscape: Node3D
var menu_mood := -1
var light: DirectionalLight3D
var fill_light: DirectionalLight3D
var target_nodes: Array[Node3D] = []
var effects: Array[Dictionary] = []
var commands: Dictionary = {}
var screen := "menu"
var paused := false
var show_help := false
var show_damage := false
var subtitles := true
var reduced_motion := false
var subtitle := ""
var subtitle_time := 0.0
var notice := ""
var notice_time := 0.0
var scan_angle := 0.0
var map_overview := false
var elapsed := 0.0
var flash := 0.0
var hit_count := 0
var shots := 0
var capture_mode := false
var thermal_material: StandardMaterial3D
# Burst particles share one unit sphere and three materials; per-particle size is node scale.
var burst_mesh: SphereMesh
var burst_smoke: StandardMaterial3D
var burst_hit: StandardMaterial3D
var burst_dust: StandardMaterial3D
var shutting_down := false
var thermal_overlay_state := -1
var range_save := "user://range-save.bin"

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_setup_world()
	sound = Sound.new()
	add_child(sound)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Interface.new()
	ui.main = self
	canvas.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.rebuild_buttons()
	_update_targets()
	var args := OS.get_cmdline_user_args()
	if "--capture" in args:
		capture_mode = true
		_capture_sequence.call_deferred()
	if "--smoke-test" in args:
		_smoke_test.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

func request_quit() -> void:
	if shutting_down:
		return
	shutting_down = true
	paused = true
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_key_input(false)
	var drained: bool = await sound.drain_for_shutdown()
	get_tree().quit.call_deferred(0 if drained else 1)

# Title screen uses the cover set; play views keep the range daylight.
func _apply_mood(menu: bool) -> void:
	if int(menu) == menu_mood:
		return
	menu_mood = int(menu)
	world_environment.environment = cover_scene.environment if menu else environment
	cover_scene.set_active(menu)
	landscape.visible = not menu
	light.visible = not menu
	fill_light.visible = not menu
	vehicle.crew.visible = menu

func _setup_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	# Late-afternoon light: a cool zenith over a warm, hazy horizon.
	material.sky_top_color = Color("35546e")
	material.sky_horizon_color = Color("cfc29a")
	material.ground_bottom_color = Color("464e34")
	material.ground_horizon_color = Color("bfb187")
	material.sky_curve = 0.11
	material.sun_angle_max = 4.5
	material.sun_curve = 0.12
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7bfae")
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.3
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.1
	environment.adjustment_contrast = 1.06
	environment.fog_enabled = true
	environment.fog_light_color = Color("cdbd92")
	environment.fog_density = 0.00016
	environment.fog_sun_scatter = 0.3
	environment.fog_aerial_perspective = 0.35
	world_environment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	light = DirectionalLight3D.new()
	# A lower, warmer sun rakes across the hull and throws long shadows through the grass.
	light.rotation_degrees = Vector3(-17,-95,0)
	light.light_color = Color("ffd9a3")
	light.light_energy = 1.2
	# A faint cool sky fill from the opposite side lifts shadowed armour out of pure black.
	fill_light = DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-32,95,0)
	fill_light.light_color = Color("a9bed0")
	fill_light.light_energy = 0.28
	fill_light.light_specular = 0.2
	add_child(fill_light)
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 220
	add_child(light)
	landscape = Landscape.new()
	add_child(landscape)
	cover_scene = CoverScene.new()
	add_child(cover_scene)
	vehicle = Vehicle.new()
	add_child(vehicle)
	camera = Camera3D.new()
	camera.far = 2800
	camera.near = 0.08
	add_child(camera)
	camera.make_current()
	thermal_material = StandardMaterial3D.new()
	thermal_material.albedo_color = Color("d7ffba")
	thermal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burst_mesh = SphereMesh.new()
	burst_mesh.radius = 1.0
	burst_mesh.height = 2.0
	burst_mesh.radial_segments = 8
	burst_mesh.rings = 4
	burst_smoke = StandardMaterial3D.new()
	burst_smoke.albedo_color = Color("b8bcac")
	burst_hit = StandardMaterial3D.new()
	burst_hit.albedo_color = Color("dda057")
	burst_dust = StandardMaterial3D.new()
	burst_dust.albedo_color = Color("66665b")
	for target in sim.targets:
		var model := Vehicle.new()
		model.scale = Vector3(0.88,0.88,0.88)
		add_child(model)
		model.position = Vector3(target.pos.x,0,target.pos.y)
		model.rotation.y = PI + 0.18
		target_nodes.append(model)

func _physics_process(_delta: float) -> void:
	if screen != "range" or paused or sim.status != "active":
		commands.clear()
		return
	var input := commands.duplicate()
	commands.clear()
	input.throttle = float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_KP_8)) - float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_KP_2))
	var steer := float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_KP_4)) - float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_KP_6))
	input.steer = steer
	input.turret_axis = steer
	input.sight_axis = input.throttle
	# Space fire is edge-triggered in _unhandled_key_input; M is the one deliberately held action (COAX cadence gates it).
	if Input.is_key_pressed(KEY_M):
		input.machinegun = true
	if capture_mode:
		# Deterministic --capture runs drive the sim from _capture_sequence; ignore all live keyboard input.
		input = {}
	var was_locked: bool = sim.locked
	var events: Array = sim.tick(input)
	for event in events:
		_process_event(event)
	if not was_locked and sim.locked:
		announce("GUNNER", "Target acquired.", "target")
	_update_targets()
	if sim.status != "active":
		ui.rebuild_buttons()

func _process(delta: float) -> void:
	elapsed += delta
	subtitle_time = maxf(0.0,subtitle_time-delta)
	notice_time = maxf(0.0,notice_time-delta)
	flash = maxf(0.0,flash-delta*4.0)
	vehicle.position = Vector3(sim.pos.x,0,sim.pos.y)
	vehicle.rotation = Vector3(0,sim.heading,0)
	vehicle.visible = screen != "range" or sim.station == 2
	vehicle.update_pose(sim.turret-sim.heading,delta)
	_apply_mood(screen != "range")
	if screen != "range":
		# Box-cover framing: low, front three-quarter view with the gun raised.
		vehicle.visible = true
		vehicle.position = Vector3.ZERO
		vehicle.rotation = Vector3(CoverScene.HULL_PITCH,0,0)
		vehicle.update_pose(CoverScene.TURRET,delta,CoverScene.ELEVATION,CoverScene.GUN_YAW)
		CoverScene.frame(camera,get_viewport().get_visible_rect().size)
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.near = 0.08
		var bearing: float = view_bearing()
		var eye := 2.65
		if sim.station == 2:
			eye = 3.05
		elif sim.station == 3:
			eye = 1.48
		var base := Vector3(sim.pos.x,eye,sim.pos.y)
		if sim.station == 3:
			base += Vector3(-sin(sim.heading),0,-cos(sim.heading))*2.0
		camera.position = base
		camera.rotation = Vector3(sim.elevation if sim.station != 3 else 0.0,bearing,0)
		var zoom_factor: float = [1.0,3.0,10.0][sim.zoom_level] if sim.station == 0 else 1.0
		camera.fov = rad_to_deg(2.0*atan(tan(deg_to_rad(65.0)/2.0)/zoom_factor))
		if sim.station == 2:
			camera.fov = 75
	if not reduced_motion and screen == "range" and flash > 0:
		camera.rotation.x += sin(elapsed*70)*flash*0.008
	_update_effects(delta)
	sound.update_engine(sim.speed,screen == "range" and not paused and sim.status == "active")
	ui.queue_redraw()

# Camera and compass yaw. F7-F10 scan is a commander-only view offset; the gunner sight always follows the gun.
func view_bearing() -> float:
	return (sim.heading if sim.station == 3 else sim.turret) + (scan_angle if sim.station == 1 else 0.0)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if screen in ["manual","record"]:
			set_screen("menu")
		elif screen == "range":
			paused = not paused
			commands.clear()
			if paused:
				sound.stop_all()
			ui.rebuild_buttons()
		return
	if screen == "menu" and event.keycode == KEY_ENTER:
		start_range()
		return
	if screen != "range" or paused:
		return
	match event.keycode:
		KEY_F1,KEY_F2,KEY_F3,KEY_F4:
			commands.station = int(event.keycode-KEY_F1)
			scan_angle = 0
			sound.play("switch")
		KEY_F5:
			sound.muted = not sound.muted
			sound.stop_all()
		KEY_F7,KEY_F8,KEY_F9,KEY_F10:
			if int(commands.get("station",sim.station)) == 1:
				scan_angle = [0.0,-PI/2,PI,PI/2][event.keycode-KEY_F7]
		KEY_1,KEY_2,KEY_3:
			commands.select_weapon = int(event.keycode-KEY_1)
		KEY_SPACE: commands.fire = true
		KEY_KP_5: commands.stop = true
		KEY_C: commands.toggle_control = true
		KEY_T: commands.toggle_thermal = true
		KEY_Z:
			if sim.station == 1:
				map_overview = not map_overview
			else:
				commands.toggle_zoom = true
		KEY_A: commands.align_turret = true
		KEY_S: commands.smoke = true
		KEY_R: commands.radio = true
		KEY_D: show_damage = not show_damage
		KEY_ENTER: commands.select_target = true
		KEY_L: commands.lock_target = true
		KEY_H: show_help = not show_help
		KEY_Q:
			paused = true
			ui.rebuild_buttons()
	get_viewport().set_input_as_handled()

func start_range() -> void:
	sim.reset()
	hit_count = 0
	shots = 0
	commands.clear()
	scan_angle = 0
	map_overview = false
	paused = false
	show_damage = false
	show_help = false
	screen = "range"
	clear_effects()
	_update_targets()
	ui.rebuild_buttons()
	announce("COMMANDER","Crew ready. Range is clear. Move out.","ready")

func set_screen(value: String) -> void:
	screen = value
	paused = false
	commands.clear()
	sound.stop_all()
	clear_effects()
	ui.rebuild_buttons()

func _process_event(event: Dictionary) -> void:
	match event.type:
		"fire":
			shots += 1
			if event.weapon == 3:
				sound.play("machinegun")
			else:
				sound.play("cannon")
				announce("GUNNER","On the way!","on_the_way")
				vehicle.recoil = 0.32
				flash = 0.55
		"impact":
			_burst(event.position,event.get("target",-1) >= 0)
			sound.play("impact")
		"hit":
			hit_count += 1
			set_notice(event.text)
		"reload":
			sound.play("reload")
			announce("LOADER","Up!","loaded")
		"smoke":
			sound.play("smoke")
			announce("GUNNER","Smoke out.","smoke")
			_burst(sim.pos + Vector2(-sin(sim.turret),-cos(sim.turret))*12,false,true)
		"voice":
			announce("RADIO",event.text,"")
		"won":
			announce("COMMANDER","Cease fire. Range complete.","cease_fire")
		"lost":
			announce("COMMANDER",event.text,"")

func announce(role: String, text: String, cue: String) -> void:
	subtitle = "%s   /   %s" % [role,text]
	subtitle_time = 4.0
	if not cue.is_empty():
		sound.speak(cue)

func set_notice(text: String) -> void:
	notice = text
	notice_time = 3.0

func _update_targets() -> void:
	for i in range(target_nodes.size()):
		var node := target_nodes[i]
		node.position = Vector3(sim.targets[i].pos.x,0,sim.targets[i].pos.y)
		node.visible = sim.targets[i].alive
	# Overlays are only re-applied on change; re-setting ~800 instances every tick costs RenderingServer updates.
	var thermal_on: bool = sim.thermal and screen == "range"
	if int(thermal_on) != thermal_overlay_state:
		thermal_overlay_state = int(thermal_on)
		for node in target_nodes:
			_apply_thermal(node,thermal_on)

func _apply_thermal(node: Node, enabled: bool) -> void:
	if node is GeometryInstance3D:
		node.material_overlay = thermal_material if enabled else null
	for child in node.get_children():
		_apply_thermal(child,enabled)

func _burst(at: Vector2, hit: bool, smoke := false) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = Vector3(at.x,0.8,at.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = 88 + effects.size()
	for i in range(10):
		var p := MeshInstance3D.new()
		p.mesh = burst_mesh
		p.scale = Vector3.ONE*(0.3+rng.randf()*0.5)
		p.material_override = burst_smoke if smoke else (burst_hit if hit and i<4 else burst_dust)
		p.position = Vector3(rng.randf_range(-1.2,1.2),rng.randf_range(0,1.5),rng.randf_range(-1.2,1.2))
		root.add_child(p)
	effects.append({"node":root,"age":0.0,"duration":8.0 if smoke else 2.2,"smoke":smoke})

func _update_effects(delta: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var fx: Dictionary = effects[i]
		fx.age += delta
		fx.node.scale = Vector3.ONE*(1.0+float(fx.age)*2.4)
		fx.node.position.y += delta*0.85
		if fx.age >= fx.duration:
			fx.node.queue_free()
			effects.remove_at(i)

func clear_effects() -> void:
	for fx in effects:
		fx.node.queue_free()
	effects.clear()

func save_range() -> void:
	# Write a temporary file and replace the save only after a verified write, so a failure keeps the previous save.
	var temp := range_save + ".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		set_notice("Save failed: cannot open user data directory.")
		return
	var ok: bool = file.store_var({"simulation":sim.snapshot(),"shots":shots,"hits":hit_count},false)
	file.flush()
	ok = ok and file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(range_save)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp))
		set_notice("Save failed: could not write range state. Previous save kept.")
		return
	set_notice("Range state saved locally.")

func load_range() -> void:
	if not FileAccess.file_exists(range_save):
		set_notice("No saved range state.")
		return
	var file := FileAccess.open(range_save,FileAccess.READ)
	if file == null or file.get_length() > 1048576:
		set_notice("Save rejected: unreadable or oversized.")
		return
	var data: Variant = file.get_var(false)
	if not data is Dictionary or not data.has_all(["simulation","shots","hits"]) or not data.shots is int or not data.hits is int or data.shots < 0 or data.hits < 0 or data.hits > data.shots or not data.simulation is Dictionary or not sim.restore(data.simulation):
		set_notice("Save rejected. Current state preserved.")
		return
	shots = data.shots
	hit_count = data.hits
	commands.clear()
	clear_effects()
	scan_angle = 0
	_update_targets()
	ui.rebuild_buttons()
	set_notice("Range state restored.")

## Capture output directory, or "" when refused. Godot runs from godot/ under --path, so relative paths mean the
## repo root, as in the launchers. Outputs inside res:// (imported, exportable) or the original sources are refused,
## as are an empty value and the bare repo root (captures would land loose beside the sources).
static func capture_directory(path: String, repo_root: String = "") -> String:
	if path.strip_edges().is_empty():
		return ""
	var project := ProjectSettings.globalize_path("res://").trim_suffix("/")
	if repo_root.is_empty():
		repo_root = project.get_base_dir()
	var resolved := ProjectSettings.globalize_path(path)
	if resolved.is_relative_path():
		resolved = repo_root.path_join(resolved)
	resolved = resolved.simplify_path()
	# Like tools/source_guard.inside_source, compare symlink-resolved paths too, so a link outside the repo that
	# points at GAME/, GENESIS/ or godot/ is still refused.
	var real := _real_path(resolved)
	if real.is_empty():
		return ""
	# APFS and NTFS are case-insensitive, so a miscased game/ is still GAME/.
	var candidates := [resolved.to_lower(), real.to_lower()]
	for candidate in candidates:
		for root in [repo_root.simplify_path(), _real_path(repo_root.simplify_path())]:
			if candidate == root.to_lower():
				return ""
		for blocked in [project, repo_root.path_join("GAME"), repo_root.path_join("GENESIS")]:
			var plain: String = blocked.simplify_path()
			for root in [plain, _real_path(plain)]:
				var folded: String = root.to_lower()
				if not folded.is_empty() and (candidate == folded or candidate.begins_with(folded + "/")):
					return ""
	return resolved

## The absolute path with every symlink component replaced by its target, component by component, as realpath
## does; missing components are kept as they are. "" for a dangling link or a link loop, whose target cannot be
## checked.
static func _real_path(path: String) -> String:
	var parts := Array(path.simplify_path().split("/"))
	var real: String = parts.pop_front() + "/"
	var hops := 0
	while not parts.is_empty():
		var name: String = parts.pop_front()
		if name.is_empty():
			continue
		var dir := DirAccess.open(real)
		if dir == null or not dir.is_link(name):
			real = real.path_join(name)
			continue
		hops += 1
		var target := dir.read_link(name)
		if hops > 40 or target.is_empty():
			return ""
		if target.is_relative_path():
			target = real.path_join(target)
		target = target.simplify_path()
		if not DirAccess.dir_exists_absolute(target) and not FileAccess.file_exists(target):
			return ""
		# Resolve the target's own components again before continuing with the rest of the path.
		parts = Array(target.split("/")).slice(1) + parts
		real = target.split("/")[0] + "/"
	return real.simplify_path()

func _capture_sequence() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture")
	# A missing value or a following flag means the default; "--capture --smoke-test" must not create "--smoke-test/".
	# An empty value (an unset "$OUT") also means the default rather than the repo root.
	var requested := args[index+1] if index+1 < args.size() and not args[index+1].begins_with("--") and not args[index+1].strip_edges().is_empty() else "user://captures"
	var out := capture_directory(requested)
	if out.is_empty():
		printerr("--capture refuses output inside godot/ or the original sources: " + requested)
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("01-menu.png"))
	start_range()
	paused = false
	sim.tick({"select_target":true,"lock_target":true})
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("02-gunner.png"))
	sim.station = 2
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("03-cupola.png"))
	sim.station = 0
	sim.thermal = true
	sim.zoom_level = 1
	_update_targets()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("04-thermal.png"))
	set_screen("manual")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("05-manual.png"))
	print("CAPTURE_COMPLETE ",out)
	request_quit()

func _smoke_fail(message: String) -> void:
	push_error("RUNTIME_SMOKE_FAIL: " + message)
	get_tree().quit(1)

# The smoke save lives in a per-process cache folder, never beside the player's real profile saves.
func _smoke_save_dir() -> String:
	return OS.get_cache_dir().path_join("abrams-range-smoke-%d" % OS.get_process_id())

# Every exit after the smoke save is redirected runs this, pass or fail.
func _smoke_cleanup_save(real_save: String) -> void:
	for path in [range_save + ".tmp", range_save]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if DirAccess.dir_exists_absolute(_smoke_save_dir()):
		DirAccess.remove_absolute(_smoke_save_dir())
	range_save = real_save

func _smoke_test() -> void:
	start_range()
	sound.muted = true
	paused = true
	var initial: Dictionary = sim.snapshot()
	for i in range(300):
		var events: Array = sim.tick({"throttle":0.5,"steer":0.1})
		for event in events:
			_process_event(event)
	if sim.pos == Vector2(initial.pos[0],initial.pos[1]):
		_smoke_fail("no movement")
		return
	var restored: bool = sim.restore(initial)
	if not restored:
		_smoke_fail("restore rejected")
		return
	for station in range(4):
		sim.tick({"station":station})
		_update_targets()
		await get_tree().process_frame
		if sim.station != station:
			_smoke_fail("station %d" % station)
			return
	sim.turret = 0.4
	scan_angle = PI
	for station in range(4):
		sim.station = station
		var expected: float = sim.heading if station == 3 else sim.turret + (PI if station == 1 else 0.0)
		if not is_equal_approx(view_bearing(),expected):
			_smoke_fail("scan offset at station %d" % station)
			return
	scan_angle = 0
	sim.thermal = true
	_update_targets()
	var meshes: Array = target_nodes[0].find_children("*","GeometryInstance3D",true,false) if not target_nodes.is_empty() else []
	if meshes.is_empty():
		_smoke_fail("no target geometry")
		return
	var sample: GeometryInstance3D = meshes[0]
	if sample.material_overlay != thermal_material:
		_smoke_fail("thermal overlay not applied")
		return
	sim.thermal = false
	_update_targets()
	if sample.material_overlay != null:
		_smoke_fail("thermal overlay not cleared")
		return
	sim.restore(initial)
	sim.tick({"station":0,"select_target":true,"lock_target":true})
	for event in sim.tick({"fire":true}):
		_process_event(event)
	if shots != 1 or effects.size() != 1:
		_smoke_fail("fire: %d shots, %d effects" % [shots,effects.size()])
		return
	sim.restore(initial)
	paused = false
	subtitle = ""
	commands = {"select_target":true,"lock_target":true}
	_physics_process(0)
	if not sim.locked or not "Target acquired." in subtitle:
		_smoke_fail("lock announcement")
		return
	subtitle = ""
	commands = {"lock_target":true}
	_physics_process(0)
	if sim.locked or not subtitle.is_empty():
		_smoke_fail("unlock announced as acquisition")
		return
	# Space is a one-shot press: it queues fire once, and a repeat or a paused press queues nothing.
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	commands.clear()
	_unhandled_key_input(space)
	var fired: bool = commands.get("fire",false)
	commands.clear()
	space.echo = true
	_unhandled_key_input(space)
	space.echo = false
	paused = true
	_unhandled_key_input(space)
	if not fired or not commands.is_empty():
		_smoke_fail("space fire is not edge-triggered")
		return
	var real_save := range_save
	if DirAccess.make_dir_recursive_absolute(_smoke_save_dir()) != OK:
		_smoke_fail("smoke save directory")
		return
	range_save = _smoke_save_dir().path_join("smoke-range-save.bin")
	save_range()
	var saved_shots := shots
	shots = 99
	load_range()
	if notice != "Range state restored.":
		_smoke_cleanup_save(real_save)
		_smoke_fail("save restore")
		return
	save_range()
	if shots != saved_shots or notice != "Range state saved locally." or FileAccess.file_exists(range_save + ".tmp"):
		_smoke_cleanup_save(real_save)
		_smoke_fail("save round trip")
		return
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(range_save + ".tmp"))
	save_range()
	var kept := FileAccess.file_exists(range_save) and notice.begins_with("Save failed")
	_smoke_cleanup_save(real_save)
	if DirAccess.dir_exists_absolute(_smoke_save_dir()):
		_smoke_fail("smoke save not cleaned up")
		return
	if not kept:
		_smoke_fail("failed save did not keep previous save")
		return
	set_screen("manual")
	await get_tree().process_frame
	set_screen("record")
	await get_tree().process_frame
	set_screen("menu")
	await get_tree().process_frame
	print("RUNTIME_SMOKE_PASS: movement, four stations, scan view, thermal overlay, selection, lock cue, fire, effects, atomic save, screen navigation")
	request_quit()
