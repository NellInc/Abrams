extends SceneTree
## Native shader ownership/palette check, without gameplay or audio.
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const CupolaMaterial = preload("res://scripts/pc_cupola_material.gd")
var failures: Array[String] = []
var viewport: SubViewport
var material: ShaderMaterial
var started := Time.get_ticks_msec()
func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>60000: printerr("FAIL: cupola test deadline");quit(2)
	return false
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func run() -> void:
	if DisplayServer.get_name()=="headless": printerr("FAIL: cupola palette needs native rendering");quit(2);return
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args:=OS.get_cmdline_user_args()
	var output:=directory.path_join("artifacts/modern-environment-polish-20260929/cupola")
	if "--output" in args: output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	# Exercise the actual mode binding, including a Modern-to-Upscaled return.
	var frame=Frame.new()
	frame.modern_available=true
	for mode in ["modern","upscaled","ega","modern","upscaled"]:
		frame.set_graphics_mode(mode)
		frame.set_frame(null,{},null)
		check(bool(frame._upscaled_material.get_shader_parameter("modern_armour_palette"))==(mode=="modern"),"palette binding "+mode)
	frame.free()
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var rect:=TextureRect.new();rect.size=Vector2(1280,800)
	rect.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var source:=Image.create(320,200,false,Image.FORMAT_RGBA8);source.fill(Color(0.2,0.3,0.6,1))
	rect.texture=ImageTexture.create_from_image(source)
	var mask:=Image.create(320,200,false,Image.FORMAT_RGB8);mask.fill(Color.WHITE)
	mask.fill_rect(Rect2i(0,150,40,10),Color.BLACK)
	var plates:=Image.create(320,200,false,Image.FORMAT_RGB8);plates.fill(Color8(3,0,0))
	plates.fill_rect(Rect2i(0,160,20,20),Color8(2,0,0))
	material=ShaderMaterial.new();material.shader=Frame.COMPOSITOR
	material.set_shader_parameter("genesis_art",true)
	material.set_shader_parameter("station_art_enabled",Vector3(0,1,0))
	material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(plates))
	var donor:=Image.load_from_file(directory.path_join("local-art/genesis/cockpit-v2/cupola-genesis-v1.png"))
	check(donor!=null,"existing donor available")
	var prepared:=CupolaMaterial.prepare(donor)
	check(prepared!=null,"contour material mask built")
	var original_rgb:=donor.duplicate();original_rgb.convert(Image.FORMAT_RGB8)
	var prepared_rgb:=prepared.duplicate();prepared_rgb.convert(Image.FORMAT_RGB8)
	check(original_rgb.get_data()==prepared_rgb.get_data(),"material preparation leaves every donor RGB byte unchanged")
	check(CupolaMaterial.prepare(Image.create(1,1,false,Image.FORMAT_RGBA8))==null,"wrong-size donor rejected")
	var transparent:=donor.duplicate();transparent.convert(Image.FORMAT_RGBA8);transparent.set_pixel(0,0,Color.TRANSPARENT)
	check(CupolaMaterial.prepare(transparent)==null,"unexpected transparency rejected")
	material.set_shader_parameter("cupola_art",ImageTexture.create_from_image(prepared))
	rect.material=material;viewport.add_child(rect)
	var before:=await capture()
	material.set_shader_parameter("modern_armour_palette",true)
	var after:=await capture()
	before.save_png(output.path_join("cupola-palette-before.png"))
	after.save_png(output.path_join("cupola-palette-after.png"))
	var changed:=0;var olive:=0;var escaped:=0;var black_changed:=0
	var bright_changed:=0;var bright_olive:=0
	for y in after.get_height():
		for x in after.get_width():
			var a:=before.get_pixel(x,y);var b:=after.get_pixel(x,y)
			if a==b:continue
			changed+=1
			if b.g>b.r and b.r>b.b*1.2:olive+=1
			if minf(a.r,minf(a.g,a.b))>0.35:
				bright_changed+=1
				if b.g>b.r and b.r>b.b*1.2:bright_olive+=1
			if mask.get_pixel(x/4,y/4).r<0.5 or plates.get_pixel(x/4,y/4).r<2.5/255.0:escaped+=1
			if maxf(a.r,maxf(a.g,a.b))<0.09:black_changed+=1
	check(bright_changed>100000 and bright_olive>bright_changed*0.99,"large armour panels become shaded olive")
	check(escaped==0,"source/world and other-station ownership unchanged")
	check(black_changed==0,"deep shadows and black illustration lines unchanged")
	for point in [Vector2i(85,112),Vector2i(156,112),Vector2i(202,145),Vector2i(117,169),Vector2i(255,165)]:
		check(before.get_pixelv(point*4)==after.get_pixelv(point*4),"metal fixture preserved "+str(point))
	material.set_shader_parameter("modern_armour_palette",false)
	check((await capture()).get_data()==before.get_data(),"Upscaled restoration byte-identical")
	if "--baseline-shader" in args:
		var baseline:=Shader.new();baseline.code=FileAccess.get_file_as_string(args[args.find("--baseline-shader")+1])
		material.shader=baseline
		material.set_shader_parameter("cupola_art",ImageTexture.create_from_image(donor))
		check((await capture()).get_data()==before.get_data(),"disabled palette byte-identical to original compositor")
	# Inspect actual donor texels at 1:1. These interior and adjacent-paint
	# witnesses are independent of the production scan windows/edge finder.
	material.shader=Frame.COMPOSITOR
	material.set_shader_parameter("cupola_art",ImageTexture.create_from_image(prepared))
	mask.fill(Color.WHITE);plates.fill(Color8(3,0,0))
	material.set_shader_parameter("ui_mask",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("plate_mask",ImageTexture.create_from_image(plates))
	viewport.size=CupolaMaterial.SIZE;rect.size=CupolaMaterial.SIZE
	material.set_shader_parameter("modern_armour_palette",false)
	var original_detail:=await capture()
	material.set_shader_parameter("modern_armour_palette",true)
	var painted_detail:=await capture()
	for point in [Vector2i(420,550),Vector2i(776,553),Vector2i(434,636),Vector2i(769,637),
		Vector2i(325,692),Vector2i(879,693),Vector2i(373,918),Vector2i(584,832),
		Vector2i(811,787),Vector2i(1266,820),Vector2i(1205,900),Vector2i(1551,920),
		Vector2i(546,962),Vector2i(1363,960),Vector2i(955,650),Vector2i(969,718),Vector2i(950,788)]:
		check(prepared.get_pixelv(point).a==1.0,"outlined hardware selected "+str(point))
		check(original_detail.get_pixelv(point)==painted_detail.get_pixelv(point),"hardware colour retained "+str(point))
	var halo_probes:=0
	for point in [Vector2i(420,563),Vector2i(776,563),Vector2i(435,644),Vector2i(777,644),
		Vector2i(325,687),Vector2i(879,699),Vector2i(372,910),Vector2i(584,825),
		Vector2i(809,803),Vector2i(1266,830),Vector2i(1206,914),Vector2i(1551,935),
		Vector2i(545,979),Vector2i(1361,975),Vector2i(945,716),Vector2i(920,778)]:
		check(prepared.get_pixelv(point).a==0.0,"adjacent armour excluded from metal mask "+str(point))
		var colour:=painted_detail.get_pixelv(point)
		check(colour.g>colour.r and colour.r>colour.b*1.2,"paint meets hardware without silver halo "+str(point))
		halo_probes+=1
	painted_detail.save_png(output.path_join("cupola-hardware-native.png"))
	var report:={"changed":changed,"olive":olive,"bright_changed":bright_changed,"bright_olive":bright_olive,"escaped":escaped,"black_changed":black_changed,"failures":failures}
	report.halo_probes=halo_probes
	var file:=FileAccess.open(output.path_join("palette-report.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	if failures.is_empty():print("PASS: Modern cupola palette, ownership, fixtures and restoration")
	else:
		for failure in failures:printerr("FAIL: "+failure)
	quit(0 if failures.is_empty() else 1)
