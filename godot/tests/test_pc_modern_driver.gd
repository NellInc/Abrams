extends "res://tests/test_pc_modern_cupola.gd"
## Both driver sampling paths use the same donor-space material mask.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	if DisplayServer.get_name()=="headless":printerr("FAIL: native driver renderer required");quit(2);return
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	var output:=directory.path_join("artifacts/modern-palette-balance-20260929/driver")
	if "--output" in args:output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var frame=Frame.new()
	check(frame.load_genesis_art(directory),"all verified cockpit donors load")
	var donor:=Image.load_from_file(directory.path_join("local-art/genesis/cockpit-v2/driver-genesis-v1.png"))
	var prepared:Image=frame.cockpit_art_textures[4].get_image()
	frame.free()
	var rgb:=donor.duplicate();rgb.convert(Image.FORMAT_RGB8)
	var masked_rgb:=prepared.duplicate();masked_rgb.convert(Image.FORMAT_RGB8)
	check(rgb.get_data()==masked_rgb.get_data(),"every driver donor RGB byte unchanged")
	check(CupolaMaterial.prepare_driver(Image.create(1,1,false,Image.FORMAT_RGBA8))==null,"wrong-size donor rejected")
	var transparent:=donor.duplicate();transparent.convert(Image.FORMAT_RGBA8);transparent.set_pixel(0,0,Color.TRANSPARENT)
	check(CupolaMaterial.prepare_driver(transparent)==null,"unexpected donor transparency rejected")
	for point in [Vector2i(335,582),Vector2i(1250,582),Vector2i(150,742),Vector2i(1435,742),Vector2i(95,880),Vector2i(339,788),Vector2i(500,721),Vector2i(1080,721),Vector2i(1244,788),Vector2i(1488,880),Vector2i(320,899),Vector2i(500,960)]:
		check(prepared.get_pixelv(point).a==1.0,"hardware / instrument metal selected "+str(point))
	for point in [Vector2i(335,649),Vector2i(1250,649),Vector2i(150,716),Vector2i(1435,716),Vector2i(70,792),Vector2i(222,794),Vector2i(1360,794),Vector2i(1510,792),Vector2i(95,902),Vector2i(339,803),Vector2i(500,733),Vector2i(1080,733),Vector2i(1244,803),Vector2i(1488,902),Vector2i(261,950),Vector2i(1325,950)]:
		check(prepared.get_pixelv(point).a==0.0,"adjacent armour outside metal contour "+str(point))
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var rect:=TextureRect.new();rect.size=viewport.size;rect.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var source:=Image.create(320,200,false,Image.FORMAT_RGB8);source.fill(Color8(51,77,153))
	rect.texture=ImageTexture.create_from_image(source)
	var mask:=Image.create(320,200,false,Image.FORMAT_RGB8);mask.fill(Color.WHITE);mask.fill_rect(Rect2i(0,150,40,10),Color.BLACK)
	var plates:=Image.create(320,200,false,Image.FORMAT_RGB8);plates.fill(Color8(4,0,0));plates.fill_rect(Rect2i(0,160,20,20),Color8(2,0,0))
	material=ShaderMaterial.new();material.shader=Frame.COMPOSITOR
	material.set_shader_parameter("genesis_art",true)
	material.set_shader_parameter("station_art_enabled",Vector3(0,0,1))
	material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(plates))
	material.set_shader_parameter("driver_art",ImageTexture.create_from_image(prepared))
	rect.material=material;viewport.add_child(rect)
	var before:=await capture()
	material.set_shader_parameter("modern_armour_palette",true)
	var after:=await capture()
	before.save_png(output.path_join("driver-before.png"));after.save_png(output.path_join("driver-after.png"))
	var changed:=0;var bright_olive:=0;var escaped:=0;var black_changed:=0
	for y in 800:
		for x in 1280:
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if a==b:continue
			changed+=1
			if a.r>0.35 and b.g>b.r and b.r>b.b*1.2:bright_olive+=1
			if mask.get_pixel(x/4,y/4).r<0.5 or plates.get_pixel(x/4,y/4).r<3.5/255.0 or Rect2i(212,748,856,52).has_point(Vector2i(x,y)):escaped+=1
			if maxf(a.r,maxf(a.g,a.b))<0.09:black_changed+=1
	check(bright_olive>100000,"large driver armour panels become olive")
	check(escaped==0,"world, other plates and live instruments unchanged")
	check(black_changed==0,"black ink and deep shadows retained")
	material.set_shader_parameter("modern_armour_palette",false)
	check((await capture()).get_data()==before.get_data(),"Upscaled restored exactly")
	var baseline:=Shader.new();baseline.code=FileAccess.get_file_as_string(directory.path_join("artifacts/modern-palette-balance-20260929/before/godot/scripts/pc_tandem_frame.gdshader"))
	material.shader=baseline;material.set_shader_parameter("driver_art",ImageTexture.create_from_image(donor))
	check((await capture()).get_data()==before.get_data(),"pre-pass Upscaled pixels unchanged")
	# Moving turret/barrel: exercise signed donor offsets in both directions,
	# compare the complete output against the same offset under the old shader.
	var assembly:=Image.create(320,200,false,Image.FORMAT_RGB8)
	for offset in [-16,0,16]:
		assembly.fill(Color.BLACK);assembly.fill_rect(Rect2i(64,18,192,58),Color8((16384+offset)&255,(16384+offset)>>8,255))
		material.shader=Frame.COMPOSITOR
		material.set_shader_parameter("driver_art",ImageTexture.create_from_image(prepared))
		material.set_shader_parameter("driver_assembly_mask",ImageTexture.create_from_image(assembly));material.set_shader_parameter("driver_assembly_enabled",true)
		material.set_shader_parameter("modern_armour_palette",true)
		var painted:=await capture()
		material.set_shader_parameter("modern_armour_palette",false)
		var unpainted:=await capture()
		check(painted.get_region(Rect2i(256,72,768,232)).get_data()!=unpainted.get_region(Rect2i(256,72,768,232)).get_data(),"moving turret painted at offset "+str(offset))
		material.shader=baseline;material.set_shader_parameter("driver_art",ImageTexture.create_from_image(donor))
		check((await capture()).get_data()==unpainted.get_data(),"original moving donor sampling retained at offset "+str(offset))
	var report:={"changed":changed,"bright_olive":bright_olive,"escaped":escaped,"black_changed":black_changed,"errors":failures}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	for failure in failures:printerr("FAIL: "+failure)
	print("PC_DRIVER_PALETTE: %d errors"%failures.size());quit(0 if failures.is_empty() else 1)
