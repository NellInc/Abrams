extends SceneTree
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var viewport: SubViewport
var composite: TextureRect
var checks := 0
var changed_pixels := 0

func check(ok: bool, why: String) -> void:
	if not ok and errors.size() < 15: errors.append(why)

func packet(ui: Image, tags: Image) -> Dictionary:
	return {"draw_pass":{"camera":{"clip":[32,13,287,109]}},"palette_rgb":TandemFrame.ART_PALETTE.duplicate(true),
		"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(ui.save_png_to_buffer())},
		"plate_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(tags.save_png_to_buffer()),
			"plates":{"1":{"source":"GPS.BIN","source_sha256":TandemFrame.GUNNER_SOURCE_SHA256}}}}

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	composite = TandemFrame.new()
	composite.size = Vector2(1280,800)
	viewport.add_child(composite)
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color8(85,85,85))
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
	for y in 200:
		for x in 320:
			var opaque := x % 7 != 0
			ui.set_pixel(x,y,Color.WHITE if opaque else Color.BLACK)
			var tag := 1 if x % 3 == 0 else 2
			tags.set_pixel(x,y,Color(float(tag)/255.0,0,0) if opaque else Color.BLACK)
	var art := Image.create_empty(1280,800,false,Image.FORMAT_RGBA8)
	for y in 800:
		for x in 1280: art.set_pixel(x,y,Color8(x % 256,y % 256,(x+y) % 256,0 if x % 17 == 0 else 255))
	check(composite.set_gunner_art(art),"high-resolution material rejected")
	var world_image := Image.create_empty(256,97,false,Image.FORMAT_RGB8)
	world_image.fill(Color.CYAN)
	var world := ImageTexture.create_from_image(world_image)
	var presentation := packet(ui,tags)
	check(composite.set_frame(source,presentation,world) and composite.gunner_art_enabled,"valid material mask refused")
	presentation = JSON.parse_string(JSON.stringify(presentation))
	check(composite.set_frame(source,presentation,world) and composite.gunner_art_enabled,"JSON wire numbers disabled material mask")
	var native := "--native" in OS.get_cmdline_user_args()
	if native:
		var image := await snapshot()
		for y in 800:
			for x in 1280:
				var sx := x / 4
				var sy := y / 4
				var inside := sx >= 32 and sx <= 287 and sy >= 13 and sy <= 109
				var original := sx % 7 != 0
				var eligible := not inside and sy < 123 and original and sx % 3 == 0
				var expected := source.get_pixel(sx,sy)
				if inside and not original: expected = Color.CYAN
				elif eligible and art.get_pixel(x,y).a == 1.0: expected = art.get_pixel(x,y)
				check(image.get_pixel(x,y).to_rgba32()==expected.to_rgba32(),"synthetic high-res/retained pixel %d,%d" % [x,y])
				checks += 1
	for kind in ["palette","source","dimensions","ids","world","missing"]:
		var bad := presentation.duplicate(true)
		match kind:
			"palette": bad.palette_rgb[0] = [1,0,0]
			"source": bad.plate_overlay.plates["1"].source_sha256 = "wrong"
			"dimensions": bad.plate_overlay.width = 321
			"missing": bad.erase("plate_overlay")
			_:
				var corrupt := tags.duplicate()
				corrupt.set_pixel(0,0,Color(float(8 if kind == "ids" else 1)/255.0,0,0))
				bad.plate_overlay.mask_png = Marshalls.raw_to_base64(corrupt.save_png_to_buffer())
		check(composite.set_frame(source,bad,world) and not composite.gunner_art_enabled,"unsafe material accepted: "+kind)
	check(not composite.set_frame(source,{},world) and not composite.gunner_art_enabled,"original fallback retained stale art")
	var args := OS.get_cmdline_user_args()
	if native and "--fixture" in args:
		await _fixtures(args[args.find("--fixture")+1],args[args.find("--art")+1],args[args.find("--output")+1])
	for error in errors: printerr("FAIL: "+error)
	print("PC_PLATE_ART: %d exact RGB checks, %d changed source samples, %d failures" % [checks,changed_pixels,errors.size()])
	quit(0 if errors.is_empty() else 1)

func _fixtures(path: String, art_path: String, output: String) -> void:
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary,"plate fixture unavailable")
	if not report is Dictionary: return
	DirAccess.make_dir_recursive_absolute(output)
	check(composite.set_gunner_art(Image.load_from_file(art_path)),"local material study unavailable")
	var summaries: Array = []
	for entry: Dictionary in report.ui_presentations:
		var paired: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
		var drawing: Dictionary = report.render_passes.filter(func(p): return p.sequence == entry.draw_sequence)[0]
		paired.draw_pass = drawing
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
		var tags := Image.load_from_file(path.get_base_dir().path_join(entry.plate_mask))
		var tag_bytes := tags.get_data()
		paired.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
		paired.plate_overlay.mask_png = Marshalls.raw_to_base64(tags.save_png_to_buffer())
		var clip: Array = drawing.camera.clip
		var bounds := Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)
		var world := ImageTexture.create_from_image(source.get_region(bounds))
		check(composite.set_frame(source,paired,world),"paired fixture refused: "+entry.stage)
		var result := await snapshot()
		var retained := 0
		var changed := 0
		for y in 200:
			for x in 320:
				var eligible: bool = composite.gunner_art_enabled and not bounds.has_point(Vector2i(x,y)) and y < 123 and tag_bytes[y*320+x] == 1
				var same := result.get_pixel(x*4+2,y*4+2).to_rgba32() == source.get_pixel(x,y).to_rgba32()
				if not eligible:
					check(same,"original instrument/camera changed: %s at %d,%d" % [entry.stage,x,y])
					retained += 1
					checks += 1
				elif not same: changed += 1
		changed_pixels += changed
		if entry.stage in ["after-fire","damage","commander","return-gunner"]:
			result.save_png(output.path_join(entry.stage+".png"))
		summaries.append({"stage":entry.stage,"enabled":composite.gunner_art_enabled,"reason":composite.gunner_art_reason,
			"retained_samples":retained,"changed_samples":changed})
	check(changed_pixels>10000,"material pilot changed too little of the observed gunner surround")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"errors":errors,"samples":summaries,"exact_RGB_checks":checks,"changed_samples":changed_pixels},"  "))
