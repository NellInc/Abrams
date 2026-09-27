extends SceneTree
## Exercise the real cold-boot pipe and render original menu/mission transitions.
const Bridge = preload("res://scripts/pc_bridge.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var bridge = Bridge.new()
var steps: Array = []
var samples: Array = []
var errors: Array[String] = []
var programs: Array = []
var next_step := 0
var stage := "ready"
var started: int
var output: String
var closing := false
var handling := false
var native := false
var rgb_checks := 0
var paired := 0
var viewport: SubViewport
var world: SubViewport
var camera: Camera3D
var draw: Node3D
var composite: TextureRect

func _initialize() -> void:
	native = "--native" in OS.get_cmdline_user_args()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output = directory.path_join("artifacts/pc-session-native" if native else "artifacts/pc-session-headless")
	var args := OS.get_cmdline_user_args()
	if "--output" in args: output = args[args.find("--output")+1]
	if DirAccess.dir_exists_absolute(output.path_join("saves")):
		printerr("FAIL: session test needs a new output directory with a fresh disk overlay")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var boot: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_boot_steps.json"))
	for i in boot.size(): steps.append({"label":"boot-%02d" % i,"frames":boot[i][0],"keys":boot[i][1]})
	steps.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_reentry_steps.json")))
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = SubViewport.new()
	world.own_world_3d = true
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(world)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	draw = DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	composite = TandemFrame.new()
	composite.size = Vector2(1280,800)
	viewport.add_child(composite)
	var python := OS.get_environment("ABRAMS_PYTHON")
	if python.is_empty(): python = "/opt/homebrew/bin/python3"
	started = Time.get_ticks_msec()
	bridge.start(python,"",output.path_join("saves"),output.path_join("host.log"),"trace")

func check(ok: bool, reason: String) -> void:
	if not ok and errors.size() < 15: errors.append(stage + ": " + reason)

func _process(_delta: float) -> bool:
	if not handling and not closing:
		for message in bridge.poll():
			handling = true
			_accept.call_deferred(message)
	if not bridge.failure.is_empty() and not closing:
		errors.append(bridge.failure)
		_stop()
	if closing and bridge.has_exited():
		check(bridge.exit_code()==0,"host shutdown failed")
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"errors":errors,"samples":samples,"programs":programs,
			"paired":paired,"rgb_checks":rgb_checks,"host_exit":bridge.exit_code()},"  "))
		for error in errors: printerr("FAIL: " + error)
		print("PC_SESSION_BRIDGE: %d stages, %d paired worlds, %d exact RGB checks, %d failures, host exit %d" % [samples.size(),paired,rgb_checks,errors.size(),bridge.exit_code()])
		quit(0 if errors.is_empty() else 1)
	if not closing and Time.get_ticks_msec()-started > 240000:
		errors.append("session deadline")
		_stop()
	return false

func _accept(message: Dictionary) -> void:
	var source := Image.new()
	check(source.load_png_from_buffer(Marshalls.base64_to_raw(message.png))==OK,"invalid original PNG")
	var program: String = message.program.name if message.get("program") is Dictionary else ""
	if programs.is_empty() or programs[-1] != program: programs.append(program)
	var presentation: Dictionary = message.get("presentation",{})
	var drawing = presentation.get("draw_pass")
	var state = message.get("state")
	if program != "SIM": check(state==null and drawing==null,"stale SIM state/geometry outside SIM")
	var enabled := state is Dictionary and drawing is Dictionary
	if enabled:
		check(drawing.unsupported.is_empty(),"unsupported original drawing commands")
		var displayed: Dictionary = drawing.duplicate(false)
		displayed.palette_rgb = presentation.palette_rgb
		draw.apply_pass(displayed)
		check(draw.render_warnings.is_empty(),"unsupported Godot drawing")
		var frame: Dictionary = drawing.camera.duplicate(true)
		frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
		frame.world_position_raw = [0,0,0]
		world.size = PcCamera.apply(camera,frame,Vector3.ZERO)*4
		check(composite.set_frame(source,presentation,world.get_texture()),"paired UI rejected")
		paired += 1
	else:
		draw.apply_pass({"objects":[]})
		composite.set_frame(source,{},null)
		check(not composite.world_enabled,"original fallback retained old world")
	if stage == "quit-dialog": check(presentation.get("ui_overlay",{}).get("ui_pixels")==64000,"quit dialog contains scenery holes")
	if native:
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var result := viewport.get_texture().get_image()
		var world_image := world.get_texture().get_image() if enabled else null
		var mask := Image.new()
		var rect := Rect2i()
		if enabled:
			check(mask.load_png_from_buffer(Marshalls.base64_to_raw(presentation.ui_overlay.mask_png))==OK,"invalid mask")
			var clip: Array = drawing.camera.clip
			rect = Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)
		for y in 200:
			for x in 320:
				var expected: Color = source.get_pixel(x,y)
				if enabled and rect.has_point(Vector2i(x,y)) and mask.get_pixel(x,y).r<0.5:
					expected = world_image.get_pixel((x-rect.position.x)*4+2,(y-rect.position.y)*4+2)
				check(result.get_pixel(x*4+2,y*4+2).to_rgba32()==expected.to_rgba32(),"RGB differs at %d,%d" % [x,y])
				rgb_checks += 1
		result.save_png(output.path_join(stage+".png"))
	samples.append({"stage":stage,"program":program,"render_epoch":message.render_epoch,"paired":enabled,"sequence":message.sequence})
	if next_step < steps.size() and errors.is_empty():
		var step: Dictionary = steps[next_step]
		next_step += 1
		stage = step.label
		bridge.step(step.frames,step.keys)
	else:
		check(programs==["START","BRIEF","SIM","END","START","BRIEF","SIM"],"program lifecycle differs")
		check(int(message.render_epoch)==2 and enabled,"second mission has no new paired epoch")
		check(state is Dictionary and state.get("scenario_resource_index")==6,"second mission state missing")
		_stop()
	handling = false

func _stop() -> void:
	closing = true
	bridge.close()
