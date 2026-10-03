extends SceneTree
## Native AA proof uses an internal facet edge, with exact source ownership.
const Display = preload("res://scripts/pc_play_display.gd")
const Draw = preload("res://scripts/pc_draw_pass.gd")
const Camera = preload("res://scripts/pc_camera.gd")
const Menu = preload("res://scripts/pc_play_menu.gd")
const Modern = preload("res://scripts/pc_modern_assets.gd")
var errors: Array[String] = []
var checks := 0
var output: String
var display: Control
var draw: Node3D
var frame := {"clip":[0,0,319,199],"center":[160,100],"focal_pixels":192,"near_raw":16,
	"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return display.world_viewport.get_texture().get_image()

func settings_contract() -> void:
	var menu := Menu.new()
	menu.config_path=""
	# Disposable config outside the documented receipts folder; must start absent.
	var path:=OS.get_temp_dir().path_join("abrams-render-quality-%d.cfg"%OS.get_process_id())
	DirAccess.remove_absolute(path)
	menu.quality_config_path=path
	root.add_child(menu)
	check(menu.load_quality_settings() and menu.quality==Menu.QUALITY_DEFAULTS,"missing config defaults")
	check(menu.choose_quality("msaa",2) and menu.choose_quality("anisotropy",8),"write both preferences")
	var loaded := Menu.new()
	loaded.config_path=""
	loaded.quality_config_path=menu.quality_config_path
	check(loaded.load_quality_settings() and loaded.quality=={"msaa":2,"anisotropy":8},"next launch restores quality")
	var cfg := ConfigFile.new()
	cfg.load(menu.quality_config_path)
	cfg.set_value("graphics","msaa",16)
	cfg.save(menu.quality_config_path)
	check(not loaded.load_quality_settings() and loaded.quality==Menu.QUALITY_DEFAULTS,"invalid sample count falls back to complete defaults")
	for value in [4.0,"4",true]:
		cfg.set_value("graphics","msaa",value);cfg.save(menu.quality_config_path)
		check(not loaded.load_quality_settings(),"wrong preference type rejected")
	menu.quality_config_path=OS.get_temp_dir().path_join("abrams-render-quality-absent-%d/graphics.cfg"%OS.get_process_id())
	check(menu.choose_quality("msaa",0) and not menu.quality_error.is_empty(),"save failure retains live choice and reports it")
	DirAccess.remove_absolute(path)
	check(not FileAccess.file_exists(path),"scratch quality config removed")
	loaded.free();menu.free()

func packet() -> Dictionary:
	var data := {"camera":frame.duplicate(true),"palette_rgb":Modern.PC_PALETTE.duplicate(true),
		"materials":[],"background":{"kind":"solid","color":0},"objects":[]}
	for index in 32: data.materials.append([index%16,index%16])
	data.objects.append({"shape_index":115,"root":1,"dynamic_instance":true,"static_path":0,"pointer":99,
		"polygons":[{"primitive":10,"fill_mode":1,"colors":[3,3],
		"camera_vertices":[[-70,240,-50],[70,240,-50],[70,240,50],[-70,240,50]]}]})
	return data

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output=directory.path_join("artifacts/render-quality-20260930/"+("native" if "--native" in args else "headless"))
	if "--output" in args: output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	settings_contract()
	display=Display.new();root.add_child(display);display.size=Vector2(640,480)
	var camera := Camera3D.new();display.world_viewport.add_child(camera);camera.make_current()
	display.set_camera_dimensions(Camera.apply(camera,frame,Vector3.ZERO))
	check(display.world_viewport.msaa_3d==Viewport.MSAA_4X,"actual scenery viewport defaults to 4x")
	check(display.world_viewport.anisotropic_filtering_level==Viewport.ANISOTROPY_16X,"actual scenery viewport defaults to 16x")
	check(display.tandem_viewport.msaa_3d==Viewport.MSAA_DISABLED and display.tandem_viewport.msaa_2d==Viewport.MSAA_DISABLED,"compositor and text never multisampled")
	draw=Draw.new();camera.add_child(draw);draw.solid_enabled=true;draw.modern_enabled=true
	var points := [[-70,0,-50],[70,0,-50],[70,0,50],[-70,0,50]]
	check(draw.modern_assets.configure({"schema":1,"models":[{"shape_index":115,"source_primitives":{"10":points},
		"roots":[{"offset":1,"group_pointers":[2]}],"groups":[{"offset":2,"primitive_pointers":[10]}],
		"triangles":[{"source_primitive":10,"vertices":[points[0],points[1],points[2]],"color":[220,40,40]},
		{"source_primitive":10,"vertices":[points[0],points[2],points[3]],"color":[200,200,150]}]}]}),"source-owned two-facet fixture")
	var data := packet()
	var original := JSON.stringify(data)
	draw.apply_pass(data)
	var off: Image
	var mask: PackedByteArray
	for mode in ["ega","genesis","upscaled","modern"]:
		for samples in Display.MSAA_LEVELS:
			for anisotropy in Display.ANISOTROPY_LEVELS:
				check(display.set_graphics_quality(mode,samples,anisotropy),"valid live quality")
				check(display.world_viewport.msaa_3d==(Display.MSAA_LEVELS[samples] if mode in ["upscaled","modern"] else Viewport.MSAA_DISABLED),"legacy stays crisp, remaster selects AA")
				check(draw.ownership.msaa_3d==Viewport.MSAA_DISABLED and draw.ownership.screen_space_aa==Viewport.SCREEN_SPACE_AA_DISABLED,"visibility ID mask is never smoothed")
				check(display.description().anisotropic_samples==anisotropy,"quality receipt reports sample count")
	check(not display.set_graphics_quality("modern",16,16) and not display.set_graphics_quality("modern",4,3),"invalid renderer quality rejected")
	if "--native" in args:
		display.set_graphics_quality("modern",0,16)
		off=await snapshot();off.save_png(output.path_join("aa-off.png"))
		mask=draw.ownership.get_texture().get_image().get_data()
		display.world_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		display.tandem_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		display.set_graphics_quality("modern",4,16)
		check(display.world_viewport.render_target_update_mode==SubViewport.UPDATE_ONCE and display.tandem_viewport.render_target_update_mode==SubViewport.UPDATE_ONCE,"quality redraws a retained stationary frame immediately")
		var antialiased: Image=await snapshot();antialiased.save_png(output.path_join("aa-4x.png"))
		var changed := 0
		for y in off.get_height():
			for x in off.get_width():
				if off.get_pixel(x,y)!=antialiased.get_pixel(x,y): changed+=1
		check(changed>100,"native MSAA visibly smooths the paired facet edge (%d pixels)"%changed)
		check(mask==draw.ownership.get_texture().get_image().get_data(),"AA leaves source-ownership bytes exact")
		display.set_graphics_quality("modern",0,16)
		check((await snapshot()).get_data()==off.get_data(),"AA off restores original renderer output exactly")
	check(JSON.stringify(data)==original,"quality leaves original packet untouched")
	check(draw.mesh_build_count==1,"quality never rebuilds original geometry")
	check(draw.modern_assets.disk_io_count==0,"quality never reloads assets")
	for error in errors: printerr("FAIL: "+error)
	print("PC_RENDER_QUALITY: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
