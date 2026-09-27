extends SceneTree
## Exact 8-bit colour gate for richer art through the real spatial material.
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
const Colour = preload("res://scripts/pc_colour.gd")
var frame := {"clip":[32,13,287,109],"center":[159,61],"near_raw":16,"focal_pixels":128,
	"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}
var viewport: SubViewport
var draw: Node3D
var records: Array = []
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func expected(profile: int, n: int) -> Array:
	match profile:
		0: return [n,n,n]
		1: return [n,0,0]
		2: return [0,n,0]
		3: return [0,0,n]
	return [n,(n*73)%256,(n*151)%256]

func fixture(profile: int, group: int) -> Dictionary:
	var palette: Array = []
	var materials: Array = []
	var polygons: Array = []
	for i in 16:
		palette.append(expected(profile,group*16+i))
		materials.append([i,i])
		var points: Array = []
		for p in [Vector2(32+i*16,13),Vector2(48+i*16,13),Vector2(48+i*16,110),Vector2(32+i*16,110)]:
			points.append(Geometry.unproject(p,1024.0,frame))
		polygons.append({"camera_vertices":points,"colors":[i,i],"fill_mode":1})
	return {"camera":frame,"palette_rgb":palette,"materials":materials,
		"background":{"kind":"solid","color":0},"objects":[{"static_path":1,"polygons":polygons}]}

func _run() -> void:
	var previous := -1.0
	for n in 256:
		var rgb := [n,n,n]
		var original := Colour.input_color(rgb,false)
		if original.to_rgba32()!=Color8(n,n,n).to_rgba32(): failures.append("non-Compatibility input was changed")
		var input := Colour.input_color(rgb,true).r
		if input <= previous or input < 0.0 or input > 1.0: failures.append("colour correction is not bounded and monotone")
		previous = input
		var linear := input*(input*(input*0.305306011+0.682171111)+0.012522878)
		var output := maxi(0,roundi(255.0*(1.055*pow(linear,0.416666667)-0.055)))
		if output!=n: failures.append("correction does not invert pinned engine approximation")
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(1024,388)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	PcCamera.apply(camera,frame,Vector3.ZERO)
	camera.make_current()
	draw = DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	var native := "--native" in OS.get_cmdline_user_args()
	for profile in 5:
		for group in 16:
			draw.apply_pass(fixture(profile,group))
			if draw.polygon_count!=16 or not draw.render_warnings.is_empty(): failures.append("invalid colour geometry")
			if not native: continue
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var im := viewport.get_texture().get_image()
			for i in 16:
				var want := expected(profile,group*16+i)
				var c := im.get_pixel(i*64+32,190)
				var actual := [roundi(c.r*255),roundi(c.g*255),roundi(c.b*255)]
				records.append({"profile":profile,"input":want,"output":actual})
				if want!=actual: failures.append("RGB %s became %s" % [want,actual])
	var args := OS.get_cmdline_user_args()
	if "--output" in args:
		var file := FileAccess.open(args[args.find("--output")+1],FileAccess.WRITE)
		file.store_string(JSON.stringify({"engine":Engine.get_version_info(),
			"renderer":RenderingServer.get_current_rendering_method(),"checks":records.size(),
			"failures":failures,"records":records},"  "))
	for failure in failures.slice(0,12): printerr("FAIL: " + failure)
	print("PC_COLOUR: %d exact RGB checks; %d failures" % [records.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
