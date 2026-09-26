extends Node3D

const Simulation = preload("res://scripts/simulation.gd")
const Vehicle = preload("res://scripts/vehicle.gd")
const Landscape = preload("res://scripts/landscape.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/audio.gd")

var sim = Simulation.new()
var vehicle: Node3D
var camera: Camera3D
var sound: Node
var ui: Control
var environment: Environment
var light: DirectionalLight3D
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
var recorded_commands: Array = []
var capture_mode := false
var thermal_material: StandardMaterial3D

func _ready() -> void:
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

func _setup_world() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color("536b79")
	material.sky_horizon_color = Color("b5b8a4")
	material.ground_bottom_color = Color("515b43")
	material.ground_horizon_color = Color("b6b79f")
	material.sky_curve = 0.16
	material.sun_angle_max = 4.0
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("aab8bf")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("b0b5a0")
	environment.fog_density = 0.00009
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-42,0)
	light.light_color = Color("fff0ca")
	light.light_energy = 1.15
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 220
	add_child(light)
	add_child(Landscape.new())
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
	if Input.is_key_pressed(KEY_SPACE):
		input.fire = true
	if Input.is_key_pressed(KEY_M):
		input.machinegun = true
	if capture_mode:
		input = commands.duplicate()
	recorded_commands.append(input.duplicate(true))
	var events: Array = sim.tick(input)
	for event in events:
		_process_event(event)
	_update_targets()
	if sim.status != "active":
		ui.rebuild_buttons()

func _process(delta: float) -> void:
	elapsed += delta
	subtitle_time = maxf(0.0,subtitle_time-delta)
	notice_time = maxf(0.0,notice_time-delta)
	flash = maxf(0.0,flash-delta*4.0)
	vehicle.position = Vector3(sim.pos.x,0,sim.pos.y)
	vehicle.rotation.y = sim.heading
	vehicle.visible = screen != "range" or sim.station == 2
	vehicle.update_pose(sim.turret-sim.heading,delta)
	if screen != "range":
		vehicle.visible = true
		vehicle.position = Vector3.ZERO
		vehicle.rotation.y = -0.40
		vehicle.update_pose(-0.2,delta)
		camera.position = Vector3(11.5,5.4,-12.5)
		camera.look_at(Vector3(3.0,1.1,0))
		camera.fov = 39
	else:
		var bearing: float = sim.heading if sim.station == 3 else sim.turret
		bearing += scan_angle
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
		KEY_F7: scan_angle = 0
		KEY_F8: scan_angle = -PI/2
		KEY_F9: scan_angle = PI
		KEY_F10: scan_angle = PI/2
		KEY_1,KEY_2,KEY_3:
			commands.select_weapon = int(event.keycode-KEY_1)
		KEY_M: commands.machinegun = true
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
		KEY_L:
			commands.lock_target = true
			if sim.selected_target >= 0:
				announce("GUNNER", "Target acquired.", "target")
		KEY_H: show_help = not show_help
		KEY_Q:
			paused = true
			ui.rebuild_buttons()
	get_viewport().set_input_as_handled()

func start_range() -> void:
	sim.reset()
	hit_count = 0
	shots = 0
	recorded_commands.clear()
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
		_apply_thermal(node,sim.thermal and screen == "range")

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
		var mesh := SphereMesh.new()
		mesh.radius = 0.3+rng.randf()*0.5
		mesh.height = mesh.radius*2
		mesh.radial_segments = 8
		mesh.rings = 4
		var p := MeshInstance3D.new()
		p.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("b8bcac") if smoke else (Color("dda057") if hit and i<4 else Color("66665b"))
		p.material_override = mat
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
	var file := FileAccess.open("user://range-save.bin",FileAccess.WRITE)
	if file == null:
		set_notice("Save failed: cannot open user data directory.")
		return
	file.store_var({"simulation":sim.snapshot(),"shots":shots,"hits":hit_count},false)
	file.close()
	set_notice("Range state saved locally.")

func load_range() -> void:
	if not FileAccess.file_exists("user://range-save.bin"):
		set_notice("No saved range state.")
		return
	var file := FileAccess.open("user://range-save.bin",FileAccess.READ)
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
	recorded_commands.clear()
	clear_effects()
	scan_angle = 0
	_update_targets()
	ui.rebuild_buttons()
	set_notice("Range state restored.")

func _capture_sequence() -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--capture")
	var out := args[index+1] if index+1 < args.size() else "user://captures"
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
	get_tree().quit()

func _smoke_test() -> void:
	start_range()
	sound.muted = true
	paused = true
	var initial: Dictionary = sim.snapshot()
	for i in range(300):
		var events: Array = sim.tick({"throttle":0.5,"steer":0.1})
		for event in events:
			_process_event(event)
	assert(sim.pos != Vector2(initial.pos[0],initial.pos[1]))
	assert(sim.restore(initial))
	for station in range(4):
		sim.tick({"station":station})
		_update_targets()
		await get_tree().process_frame
	sim.tick({"station":0,"select_target":true,"lock_target":true})
	for event in sim.tick({"fire":true}):
		_process_event(event)
	assert(shots == 1)
	assert(effects.size() == 1)
	set_screen("manual")
	await get_tree().process_frame
	set_screen("record")
	await get_tree().process_frame
	set_screen("menu")
	await get_tree().process_frame
	print("RUNTIME_SMOKE_PASS: movement, four stations, selection, fire, effects, screen navigation")
	# Let this awaited frame callback return before requesting scene teardown.
	get_tree().quit.call_deferred()
