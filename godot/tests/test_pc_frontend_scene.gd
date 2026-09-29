extends SceneTree
## Live-observer fixture replay across all original selector choices and modes.
const Draw = preload("res://scripts/pc_draw_pass.gd")
const Tandem = preload("res://scripts/pc_tandem_frame.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var errors: Array[String]=[]
var checks:=0
var native:=false
var display: SubViewport
var world: SubViewport
var frame: TextureRect
var draw: Node3D
var camera: Camera3D
var output: String
var menu_views:=0
var started:=Time.get_ticks_msec()
func _process(_delta: float)->bool:
	if Time.get_ticks_msec()-started>120000: printerr("FAIL: scene test deadline");quit(2)
	return false
func check(ok: bool, why: String)->void:
	checks+=1
	if not ok and errors.size()<20: errors.append(why)
func _initialize()->void: run.call_deferred()
func snap()->Image:
	await process_frame
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	return display.get_texture().get_image()
func run()->void:
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	native="--native" in args
	if not "--fixture" in args:
		printerr("Supply --fixture from tools.capture_pc_menu_text --mode trace");quit(2);return
	if native and DisplayServer.get_name()=="headless":
		printerr("Native image checks require a renderer");quit(2);return
	var fixture:String=args[args.find("--fixture")+1]
	output=args[args.find("--output")+1] if "--output" in args else directory.path_join("artifacts/pc-frontend-scene-native")
	if native:check(DirAccess.make_dir_recursive_absolute(output)==OK,"output")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	display=SubViewport.new();display.size=Vector2i(1280,960);display.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(display)
	world=SubViewport.new();world.own_world_3d=true;world.render_target_update_mode=SubViewport.UPDATE_ALWAYS;display.add_child(world)
	camera=Camera3D.new();world.add_child(camera);camera.make_current()
	draw=Draw.new();world.add_child(draw);draw.solid_enabled=true
	check(draw.load_modern_assets(directory),"Modern assets")
	var terrain=preload("res://scripts/pc_terrain_style.gd").new()
	check(terrain.load_assets(directory.path_join("local-art/pc-terrain-remastered/detail-v1")),"terrain")
	check(terrain.load_hills(directory),"hills");draw.terrain_style=terrain
	frame=Tandem.new();frame.size=display.size;display.add_child(frame)
	frame.modern_available=true
	check(frame.load_genesis_art(directory),"frontend art")
	check(frame.load_graphics_sources(directory),"native graphics")
	var count:=0
	var missions:=0
	var records:Array=[]
	for entry: Dictionary in data.samples:
		if entry.label.ends_with("-press"):continue
		var source:=Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
		var presentation:Dictionary=entry.presentation
		var program:Dictionary=entry.program if entry.program is Dictionary else {}
		var drawing=presentation.get("draw_pass")
		if not drawing is Dictionary:
			frame.set_frame(source,presentation,null,program);frame.present_frontend(program)
			check(not frame.world_enabled,"no stale scene: "+entry.label)
			check(not bool(frame.frontend_art.material.get_shader_parameter("scene_enabled")),"no stale cutout: "+entry.label)
			continue
		count+=1
		if drawing.get("frontend_view")=="menu":menu_views+=1
		if entry.label.begins_with("mission-") and entry.label!="mission-select":missions+=1
		check(program.get("name")=="START" and drawing.get("frontend_scene")=="START/ANIM","original START provenance")
		check(entry.state==null,"no counterfeit SIM state")
		var cam:Dictionary=drawing.camera.duplicate(true)
		cam.matrix_q14_columns=[16384,0,0,0,16384,0,0,0,16384];cam.world_position_raw=[0,0,0]
		world.size=PcCamera.apply(camera,cam,Vector3.ZERO)*5
		var rendered:Dictionary=drawing.duplicate(true);rendered.palette_rgb=presentation.palette_rgb
		var upscaled: Image
		for mode in ["ega","genesis","upscaled","modern"]:
			draw.modern_enabled=mode=="modern";draw.apply_pass(rendered)
			check(frame.set_graphics_mode(mode),"mode "+mode)
			frame.set_frame(source,presentation,world.get_texture(),program);frame.present_frontend(program)
			check(frame.world_enabled==(mode in ["upscaled","modern"]),"scene follows mode "+mode)
			if mode=="modern":
				check(draw._modern_active and draw.terrain_active,"Modern preview active")
				check(draw.ownership.size==world.size,"ownership extent matches on first frame")
				check(draw.hill_polygon_count>0,"source hills upgraded")
				check(draw.modern_assets.max_anchor_error<=0.25,"source geometry anchors")
			if not native:continue
			var result:=await snap()
			if count==1 or mode=="modern":result.save_png(output.path_join(entry.label+"-"+mode+".png"))
			if mode=="ega":
				var expected:=source.duplicate();expected.resize(1280,960,Image.INTERPOLATE_NEAREST);expected.convert(result.get_format())
				check(expected.get_data()==result.get_data(),"EGA pixel exact")
			if mode=="upscaled":upscaled=result
			if mode=="modern" and upscaled!=null:
				# The selector panel, cursor and controls are identical between
				# both high-resolution modes; only the observed scenery changes.
				var panel_height:=106 if drawing.get("frontend_view")=="menu" else 374
				check(upscaled.get_region(Rect2i(0,0,1280,panel_height)).get_data()==result.get_region(Rect2i(0,0,1280,panel_height)).get_data(),"panel unchanged by Modern")
				check(upscaled.get_data()!=result.get_data(),"Modern changes the preview")
		if count==1:
			frame.frontend_art.text_enabled=false
			frame.present_frontend(program)
			check(bool(frame.frontend_art.material.get_shader_parameter("scene_enabled")),"original text option retains upgraded preview")
			check(frame.frontend_art.flow_typography.runs.is_empty(),"original text option removes font overlay")
			frame.frontend_art.text_enabled=true
			frame.present_frontend(program)
		if native:records.append({"label":entry.label,"triangles":draw.modern_triangle_count,"trees":draw.modern_tree_count,"hills":draw.hill_polygon_count,"anchor_error_pixels":draw.modern_assets.max_anchor_error})
	check(count>=16,"selector states covered")
	check(missions==8,"all eight original mission choices")
	if data.get("route")=="menus":check(menu_views>=3,"opening menu and returns replayed at high resolution")
	if native:
		var file:=FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"samples":records},"\t")+"\n")
	for error in errors:printerr("FAIL: "+error)
	print("PC_FRONTEND_SCENE: %d checks, %d errors, %d selectors, %d missions"%[checks,errors.size(),count,missions])
	quit(0 if errors.is_empty() else 1)
