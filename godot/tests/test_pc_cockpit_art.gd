extends SceneTree
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var viewport: SubViewport
var composite: TextureRect
var errors: Array[String] = []
var checks := 0

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok and errors.size() < 20: errors.append(reason)

func protected(id: int, p: Vector2) -> bool:
	if id == 2:
		return Rect2(15,62,146,98).has_point(p) or Rect2(0,166,170,34).has_point(p) or Rect2(190,66,115,129).has_point(p)
	if id == 4: return Rect2(53,187,214,13).has_point(p)
	return false

func image_of(format: Image.Format, colour: Color, size := Vector2i(320,200)) -> Image:
	var image := Image.create_empty(size.x,size.y,false,format)
	image.fill(colour)
	return image

func packet(ui: Image, tags: Image) -> Dictionary:
	var plates := {}
	for id in TandemFrame.COCKPIT_SOURCES:
		plates[str(id)] = {"source":TandemFrame.COCKPIT_SOURCES[id][0],"source_sha256":TandemFrame.COCKPIT_SOURCES[id][1]}
	return {"draw_pass":{"camera":{"clip":[0,0,319,135]}},"palette_rgb":TandemFrame.ART_PALETTE,
		"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(ui.save_png_to_buffer())},
		"plate_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(tags.save_png_to_buffer()),"plates":plates}}

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func _initialize() -> void: run.call_deferred()

func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	composite = TandemFrame.new()
	composite.size = Vector2(1280,800)
	viewport.add_child(composite)
	var source := image_of(Image.FORMAT_RGB8,Color8(85,85,85))
	var world := ImageTexture.create_from_image(image_of(Image.FORMAT_RGB8,Color.CYAN,Vector2i(320,136)))
	var ui := image_of(Image.FORMAT_L8,Color.WHITE)
	var tags := image_of(Image.FORMAT_L8,Color.BLACK)
	for y in 200:
		for x in 320:
			var opaque := x%7 != 0
			ui.set_pixel(x,y,Color.WHITE if opaque else Color.BLACK)
			if opaque: tags.set_pixel(x,y,Color(float(2+x%3)/255.0,0,0))
	for id in [2,3,4]:
		var art := image_of(Image.FORMAT_RGBA8,Color.BLACK,Vector2i(1280,800))
		for y in 800:
			for x in 1280: art.set_pixel(x,y,Color8((x%4)*70,50*id,100,0 if x%17 == 0 else 255))
		check(composite.set_cockpit_art(id,art),"load generated station "+str(id))
	var presentation: Dictionary = JSON.parse_string(JSON.stringify(packet(ui,tags)))
	check(composite.set_frame(source,presentation,world),"station composition")
	check(composite.cockpit_art_ids.size() == 3 and not composite.gunner_art_enabled,"three source IDs, no gunner substitution")
	var native := "--native" in OS.get_cmdline_user_args()
	if native:
		var output := await snapshot()
		for y in 800:
			for x in 1280:
				var sx := x/4
				var sy := y/4
				var id := 2+sx%3
				var expected := Color8(85,85,85)
				if sx%7 == 0 and sy <= 135: expected = Color.CYAN
				elif sx%7 != 0 and not protected(id,Vector2((x+0.5)/4.0,(y+0.5)/4.0)) and x%17 != 0:
					expected = Color8((x%4)*70,50*id,100)
				check(output.get_pixel(x,y).to_rgba32() == expected.to_rgba32(),"wrong original/high-res pixel %d,%d"%[x,y])
	# Per-pixel original moving-assembly offset, including both sides of zero.
	for offset in [-37,0,51]:
		var roof := image_of(Image.FORMAT_RGB8,Color.BLACK)
		for y in range(18,77):
			for x in 320:
				if x-offset >= 72 and x-offset < 248 and x%7 != 0:
					roof.set_pixel(x,y,Color8((offset+16384)&255,(offset+16384)>>8,255))
		var moving := packet(ui,image_of(Image.FORMAT_L8,Color.BLACK))
		moving.driver_overlay = {"width":320,"height":200,"source":"SIM.EXE:5ba1..5da3",
			"source_sha256":"9ee5a5898ddcb8192d30b4083981419515eb3ca220e6cbcd214df628bb164099",
			"mask_png":Marshalls.raw_to_base64(roof.save_png_to_buffer())}
		check(composite.set_frame(source,moving,world) and composite.driver_assembly_enabled,"original moving assembly accepted")
		if native:
			var rendered := await snapshot()
			for y in 800:
				for x in 1280:
					var expected := Color8(85,85,85)
					if x/4%7 == 0 and y/4 <= 135: expected = Color.CYAN
					elif roof.get_pixel(x/4,y/4).b == 1.0:
						var ax: int = x-int(offset)*4
						if ax%17 != 0: expected = Color8((ax%4)*70,200,100)
					check(rendered.get_pixel(x,y).to_rgba32()==expected.to_rgba32(),"moving roof offset %d at %d,%d"%[offset,x,y])
		moving.driver_overlay.source_sha256 = "wrong"
		check(composite.set_frame(source,moving,world) and not composite.driver_assembly_enabled,"wrong driver code rejected")
	for id in [2,3,4]:
		var bad := presentation.duplicate(true)
		bad.plate_overlay.plates[str(id)].source_sha256 = "wrong"
		check(composite.set_frame(source,bad,world) and composite.cockpit_art_ids.is_empty(),"wrong source disables every material")
	check(not composite.set_frame(source,{},world) and composite.cockpit_art_ids.is_empty(),"missing provenance clears all station art")
	check(not composite.set_cockpit_art(5,source),"STATUS cannot receive station artwork")
	check(not composite.set_cockpit_art(4,source),"low-res donor rejected")
	var args := OS.get_cmdline_user_args()
	if native and "--fixture" in args:
		await fixtures(args[args.find("--fixture")+1],args[args.find("--art-dir")+1],args[args.find("--output")+1])
	for error in errors: printerr(error)
	print("PC_COCKPIT_ART: %d checks, %d failures"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func fixtures(path: String, art_dir: String, output: String) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.make_dir_recursive_absolute(output)
	for id in [2,3,4]:
		var filename: String = {2:"commander",3:"cupola",4:"driver"}[id]+"-plate-v1.png"
		check(composite.set_cockpit_art(id,Image.load_from_file(art_dir.path_join(filename))),"real high-res donor loaded")
	var summaries := []
	var coverage := {2:0,3:0,4:0}
	for entry in report.ui_presentations:
		var paired: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
		var drawing: Dictionary = report.render_passes.filter(func(p): return p.sequence == entry.draw_sequence)[0]
		paired.draw_pass = drawing
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
		var tags := Image.load_from_file(path.get_base_dir().path_join(entry.plate_mask))
		paired.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
		paired.plate_overlay.mask_png = Marshalls.raw_to_base64(tags.save_png_to_buffer())
		var clip: Array = drawing.camera.clip
		var world := ImageTexture.create_from_image(source.get_region(Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)))
		check(composite.set_frame(source,paired,world),"real paired original frame")
		var rendered := await snapshot()
		var assembly := Image.new()
		if composite.driver_assembly_enabled:
			assembly.load_png_from_buffer(Marshalls.base64_to_raw(paired.driver_overlay.mask_png))
		var changed := 0
		for y in 200:
			for x in 320:
				var id := roundi(tags.get_pixel(x,y).r*255)
				var eligible: bool = id in composite.cockpit_art_ids and not protected(id,Vector2(x+0.5,y+0.5))
				if not assembly.is_empty() and assembly.get_pixel(x,y).b == 1.0: eligible = true; id = 4
				var same := rendered.get_pixel(x*4+2,y*4+2).to_rgba32() == source.get_pixel(x,y).to_rgba32()
				if not eligible: check(same,"protected original pixel changed in "+entry.stage)
				elif not same:
					changed += 1
					coverage[id] += 1
		if entry.stage.ends_with("settled") or entry.stage == "gunner-restored" or entry.stage.begins_with("driver-"): rendered.save_png(output.path_join(entry.stage+".png"))
		summaries.append({"stage":entry.stage,"active_ids":composite.cockpit_art_ids.duplicate(),"changed":changed})
	for id in ([2,4] if report.profile == "driver" else [2,3,4]): check(coverage[id]>1000,"live original coverage for plate "+str(id))
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"coverage":coverage,"samples":summaries},"  "))
