extends SceneTree
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var viewport: SubViewport
var composite: TextureRect
var checks := 0
var assertions := 0
var changed_pixels := 0

func check(ok: bool, why: String) -> void:
	assertions+=1
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
	# 180 s also covers the native --fixture capture mode.
	create_timer(180).timeout.connect(func(): printerr("FAIL: plate art deadline"); quit(2))
	_run.call_deferred()

func arg_value(args: PackedStringArray, flag: String) -> String:
	var index := args.find(flag)
	var ok := index >= 0 and index+1 < args.size() and not args[index+1].begins_with("--")
	check(ok,"missing value for "+flag)
	return args[index+1] if ok else ""

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
				elif eligible:
					var py := (y+0.5)/4.0
					var donor_y := py*20.0/13.0 if py<13.0 else (lerpf(20,94,(py-13)/97) if py<110 else lerpf(94,123,(py-110)/13))
					var ay := clampi(floori(donor_y*4+0.0001),0,799)
					if art.get_pixel(x,ay).a == 1.0: expected = art.get_pixel(x,ay)
				check(image.get_pixel(x,y).to_rgba32()==expected.to_rgba32(),"synthetic high-res/retained pixel %d,%d" % [x,y])
				checks += 1
	# A warm cache must still bind exact current bytes and current metadata.
	for pos in [Vector2i(3,0),Vector2i(318,199)]:
		check(composite.set_frame(source,presentation,world) and composite.gunner_art_enabled,"cache baseline")
		var missing_ui := ui.duplicate()
		missing_ui.set_pixelv(pos,Color.BLACK)
		check(composite.set_frame(source,packet(missing_ui,tags),world) and not composite.gunner_art_enabled,"warm cache rejects one missing ownership bit")
		check(composite.set_frame(source,presentation,world) and composite.gunner_art_enabled,"valid bytes recover after cache rejection")
		var invalid_tag := tags.duplicate()
		invalid_tag.set_pixelv(pos,Color(9.0/255,0,0))
		check(composite.set_frame(source,packet(ui,invalid_tag),world) and not composite.gunner_art_enabled,"warm cache rejects changed tag")
	var blank_tags := tags.duplicate()
	blank_tags.fill(Color.BLACK)
	check(composite.set_frame(source,packet(ui,blank_tags),world) and not composite.gunner_art_enabled,"empty provenance cannot reuse cached IDs")
	check(composite.set_frame(source,presentation,world) and composite.gunner_art_enabled,"restored provenance accepted")
	composite.set_gunner_art(null)
	check(composite.set_frame(source,presentation,world) and not composite.gunner_art_enabled,"cached provenance cannot restore missing artwork")
	composite.set_gunner_art(art)
	for value in [1,127,254]:
		var invalid_ui := ui.duplicate()
		invalid_ui.set_pixel(319,199,Color(value/255.0,0,0))
		check(not composite.set_frame(source,packet(invalid_ui,tags),world) and not composite.gunner_art_enabled,"bulk predicate rejects every nonbinary class")
	check(composite.set_frame(source,presentation,world) and composite.gunner_art_enabled,"original byte pair survives caller mutations")
	for kind in ["palette","source","dimensions","ids","unowned","missing"]:
		var bad := presentation.duplicate(true)
		match kind:
			"palette": bad.palette_rgb[0] = [1,0,0]
			"source": bad.plate_overlay.plates["1"].source_sha256 = "wrong"
			"dimensions": bad.plate_overlay.width = 321
			"missing": bad.erase("plate_overlay")
			_:
				# "ids": out-of-range tag 9 on an owned pixel (1,5) in a row the cache
				# cases above never touch, so only the plate-ID range rule can reject it.
				# "unowned": a valid tag on unowned (0,0), rejected by the ownership rule.
				var corrupt := tags.duplicate()
				if kind == "ids": corrupt.set_pixel(1,5,Color(9.0/255.0,0,0))
				else: corrupt.set_pixel(0,0,Color(1.0/255.0,0,0))
				bad.plate_overlay.mask_png = Marshalls.raw_to_base64(corrupt.save_png_to_buffer())
		check(composite.set_frame(source,bad,world) and not composite.gunner_art_enabled,"unsafe material accepted: "+kind)
	# A valid transport ID with no loaded art (8) on an owned pixel is ignored, not rejected.
	var unloaded_id := tags.duplicate()
	unloaded_id.set_pixel(1,5,Color(8.0/255.0,0,0))
	check(composite.set_frame(source,packet(ui,unloaded_id),world) and composite.gunner_art_enabled,"valid ID without loaded art disabled material")
	check(not composite.set_frame(source,{},world) and not composite.gunner_art_enabled,"original fallback retained stale art")
	var args := OS.get_cmdline_user_args()
	if native and "--fixture" in args:
		var fixture := arg_value(args,"--fixture")
		var art_path := arg_value(args,"--art")
		var output := arg_value(args,"--output")
		if not (fixture.is_empty() or art_path.is_empty() or output.is_empty()): await _fixtures(fixture,art_path,output)
	for error in errors: printerr("FAIL: "+error)
	print("PC_PLATE_ART: %d exact RGB checks, %d changed source samples, %d failures; %d assertions" % [checks,changed_pixels,errors.size(),assertions])
	quit(0 if errors.is_empty() else 1)

func _fixtures(path: String, art_path: String, output: String) -> void:
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	var usable: bool = report is Dictionary and report.get("ui_presentations") is Array and report.get("presentations") is Array and report.get("render_passes") is Array
	check(usable,"plate fixture unavailable")
	if not usable: return
	check(DirAccess.make_dir_recursive_absolute(output) == OK,"output directory")
	check(composite.set_gunner_art(Image.load_from_file(art_path)),"local material study unavailable")
	var summaries: Array = []
	for entry: Dictionary in report.ui_presentations:
		var passes: Array = report.render_passes.filter(func(p): return p.sequence == entry.draw_sequence)
		check(not passes.is_empty() and int(entry.frame_index) < report.presentations.size(),"paired fixture frame missing: "+entry.stage)
		if passes.is_empty() or int(entry.frame_index) >= report.presentations.size(): continue
		var paired: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
		var drawing: Dictionary = passes[0]
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
