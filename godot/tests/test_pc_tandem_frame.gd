extends SceneTree
const TandemFrame = preload("res://scripts/pc_tandem_frame.gd")
const DrawPass = preload("res://scripts/pc_draw_pass.gd")
const PcCamera = preload("res://scripts/pc_camera.gd")
var failures: Array[String] = []
var viewport: SubViewport
var composite: TextureRect
var pixels_checked := 0
var ui_pixels_checked := 0
var world_pixels_checked := 0
var reticle_pixels_checked := 0

func check(ok: bool, message: String) -> void:
	if not ok and failures.size() < 12: failures.append(message)

func packet(mask: Image, clip: Array) -> Dictionary:
	return {"draw_pass": {"camera": {"clip": clip}}, "ui_overlay": {
		"width": 320, "height": 200, "mask_png": Marshalls.raw_to_base64(mask.save_png_to_buffer())}}

func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func matches(image: Image, source: Image, x: int, y: int, scale: int, label: String) -> void:
	pixels_checked += 1
	var actual := image.get_pixel(x*scale + scale/2, y*scale + scale/2).to_rgba32()
	var expected := source.get_pixel(x, y).to_rgba32()
	check(actual == expected, "%s pixel %d,%d: %x != %x" % [label,x,y,actual,expected])

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	var mask := Image.create_empty(320,200,false,Image.FORMAT_L8)
	for y in 200:
		for x in 320:
			source.set_pixel(x,y,Color8(x % 256,y % 256,(x+y) % 256))
			mask.set_pixel(x,y,Color.WHITE if x % 7 == 0 else Color.BLACK)
	# Explicit opaque black, and an opaque pixel identical to the old world.
	source.set_pixel(42,40,Color.BLACK)
	source.set_pixel(49,40,Color.MAGENTA)
	var replacement := Image.create_empty(256,97,false,Image.FORMAT_RGB8)
	replacement.fill(Color.CYAN)
	var world := ImageTexture.create_from_image(replacement)
	viewport = SubViewport.new()
	viewport.size = Vector2i(320,200)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	composite = TandemFrame.new()
	composite.size = Vector2(320,200)
	viewport.add_child(composite)
	var clip := [32,13,287,109]
	var presentation := packet(mask,clip)
	check(composite.set_frame(source,presentation,world), "valid paired UI refused")
	var native := "--native" in OS.get_cmdline_user_args()
	if native:
		var im := await snapshot()
		for y in 200:
			for x in 320:
				var retained: bool = x < 32 or x > 287 or y < 13 or y > 109 or x % 7 == 0
				if retained: matches(im,source,x,y,1,"synthetic retained")
				else:
					pixels_checked += 1
					check(im.get_pixel(x,y).to_rgba32() == Color.CYAN.to_rgba32(), "synthetic world replacement")
	for broken in [{}, {"draw_pass": {}}, packet(mask,[32,13,320,109]), packet(mask,[32.5,13,287,109])]:
		check(not composite.set_frame(source,broken,world) and not composite.world_enabled, "invalid attribution must fall back")
		if native:
			var im := await snapshot()
			for y in 200:
				for x in 320: matches(im,source,x,y,1,"fallback")
	mask.set_pixel(0,0,Color(0.5,0.5,0.5))
	check(not composite.set_frame(source,packet(mask,clip),world), "nonbinary mask accepted")
	mask.set_pixel(0,0,Color.WHITE)
	check(not composite.set_frame(source,packet(mask,clip),null), "missing world texture accepted")
	var color_mask := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	color_mask.fill(Color.WHITE)
	check(not composite.set_frame(source,packet(color_mask,clip),world), "colour mask accepted")
	var args := OS.get_cmdline_user_args()
	if native and "--fixture" in args:
		await _fixtures(args[args.find("--fixture")+1], args[args.find("--output")+1] if "--output" in args else "")
	for failure in failures: printerr("FAIL: " + failure)
	print("PC_TANDEM_FRAME: %s; %d exact RGB checks; %d live UI pixels; %d composited world pixels; %d original reticle-over-sprite pixels" % [
		"PASS" if failures.is_empty() else "FAIL", pixels_checked, ui_pixels_checked, world_pixels_checked, reticle_pixels_checked])
	quit(0 if failures.is_empty() else 1)

func _fixtures(path: String, output: String) -> void:
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary and report.get("ui_presentations", []).size() >= 23, "UI fixture unavailable")
	if not report is Dictionary or not report.has("ui_presentations"): return
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var world_viewport := SubViewport.new()
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(world_viewport)
	var camera := Camera3D.new()
	world_viewport.add_child(camera)
	camera.make_current()
	var draw = DrawPass.new()
	draw.solid_enabled = true
	camera.add_child(draw)
	var summaries: Array = []
	for entry: Dictionary in report.ui_presentations:
		var drawing: Dictionary = report.render_passes.filter(func(p): return p.sequence == entry.draw_sequence)[0].duplicate(true)
		drawing.palette_rgb = report.presentations[int(entry.frame_index)].palette_rgb
		var clip: Array = drawing.camera.clip
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var mask := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
		var presentation := packet(mask,clip)
		presentation.draw_pass = drawing
		# Using source scenery must reconstruct the entire original framebuffer.
		var region := Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1)
		viewport.size = Vector2i(320,200)
		composite.size = Vector2(320,200)
		check(composite.set_frame(source,presentation,ImageTexture.create_from_image(source.get_region(region))), "recorded mask refused")
		var im := await snapshot()
		for y in 200:
			for x in 320: matches(im,source,x,y,1,"source reconstruction " + entry.stage)
		var frame: Dictionary = drawing.camera.duplicate(true)
		frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384]
		frame.world_position_raw = [0,0,0]
		world_viewport.size = PcCamera.apply(camera,frame,Vector3.ZERO)*4
		draw.apply_pass(drawing)
		check(draw.render_warnings.is_empty(), "recorded draw warnings")
		viewport.size = Vector2i(1280,800)
		composite.size = Vector2(1280,800)
		check(composite.set_frame(source,presentation,world_viewport.get_texture()), "native world refused")
		im = await snapshot()
		var world_image := world_viewport.get_texture().get_image()
		for y in 200:
			for x in 320:
				if not region.has_point(Vector2i(x,y)) or mask.get_pixel(x,y).r > 0.5:
					matches(im,source,x,y,4,"native retained " + entry.stage)
					ui_pixels_checked += 1
				else:
					var expected := world_image.get_pixel((x-region.position.x)*4+2,(y-region.position.y)*4+2).to_rgba32()
					var actual := im.get_pixel(x*4+2,y*4+2).to_rgba32()
					check(actual == expected,"native world composite %s pixel %d,%d: %x != %x" % [entry.stage,x,y,actual,expected])
					world_pixels_checked += 1
					pixels_checked += 1
		for object: Dictionary in drawing.objects:
			if not object.get("sprite") is Dictionary: continue
			var sprite: Dictionary = object.sprite
			for y in int(sprite.height):
				for x in int(sprite.width):
					var px: int = sprite.origin[0]+x
					var py: int = sprite.origin[1]+y
					if region.has_point(Vector2i(px,py)) and sprite.opaque[y*int(sprite.width)+x] and mask.get_pixel(px,py).r > 0.5:
						matches(im,source,px,py,4,"reticle over original sprite")
						reticle_pixels_checked += 1
		if not output.is_empty() and (entry.stage in ["driver","gunner","commander","cupola"] or entry.stage.begins_with("sprite-")):
			check(im.save_png(output.path_join(entry.stage+"-tandem.png")) == OK, "capture failed")
			check(world_viewport.get_texture().get_image().save_png(output.path_join(entry.stage+"-world.png")) == OK, "world capture failed")
		summaries.append({"stage": entry.stage, "draw_sequence": entry.draw_sequence, "frame_index": entry.frame_index,
			"clip": clip, "source_reconstruction_pixels": 64000})
	check(reticle_pixels_checked > 0, "fixture never tested an original UI-over-effect overlap")
	if not output.is_empty():
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"cases": summaries, "rgb_checks": pixels_checked,
			"ui_pixel_checks": ui_pixels_checked, "reticle_pixels": reticle_pixels_checked,
			"world_pixel_checks": world_pixels_checked,
			"failures": failures, "scope": "source reconstruction and original UI RGB retention; world raster parity remains separate"},"  "))
