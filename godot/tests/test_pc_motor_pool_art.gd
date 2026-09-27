extends SceneTree
const Frontend = preload("res://scripts/pc_frontend_art.gd")
var checks := 0
var errors: Array[String] = []
var samples: Array[Dictionary] = []
var viewport: SubViewport
var backdrop: TextureRect
var art: TextureRect
var output: String
var native := false

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(why)

func _initialize() -> void: run.call_deferred()

func bilinear(image: Image, uv: Vector2) -> Color:
	var p := uv*Vector2(image.get_size())-Vector2(0.5,0.5)
	var at := Vector2i(floori(p.x),floori(p.y))
	var f := p-Vector2(at)
	var limit := image.get_size()-Vector2i.ONE
	return image.get_pixelv(at.clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit)),f.x).lerp(image.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit)),f.x),f.y)

func render(source: Image, mask: Image, label: String) -> void:
	backdrop.texture=ImageTexture.create_from_image(source)
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var frame := viewport.get_texture().get_image()
	var changed := 0
	for y in 800:
		for x in 1280:
			var actual := frame.get_pixel(x,y)
			var original := source.get_pixel(x/4,y/4)
			var text_pixel := false
			for run in art.typography.runs:
				if run.rect.has_point(Vector2i(x/4,y/4)): text_pixel=true; break
			if int(round(mask.get_pixel(x/4,y/4).r*255))!=8 and not text_pixel:
				check(actual.is_equal_approx(original),"protected original menu pixel: "+label)
			elif not actual.is_equal_approx(original): changed+=1
	check(changed>600000,"Genesis background visibly replaces source: "+label)
	var donor: Image=art.material.get_shader_parameter("motor_pool").get_image()
	for y in range(1,800,17):
		for x in range(1,1280,19):
			if int(round(mask.get_pixel(x/4,y/4).r*255))!=8: continue
			var actual := frame.get_pixel(x,y)
			var expected := bilinear(donor,(Vector2(x,y)+Vector2(0.5,0.5))/Vector2(1280,800))
			check(absf(actual.r-expected.r)<=3.0/255 and absf(actual.g-expected.g)<=3.0/255 and absf(actual.b-expected.b)<=3.0/255,"exact Genesis donor/filter: "+label)
	check(frame.save_png(output.path_join(label+".png"))==OK,"native image saved")
	samples.append({"label":label,"active":art.active.duplicate(),"changed_pixels":changed,
		"text":art.typography.runs.map(func(r):return r.text)})

func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	native="--native" in args
	output=root_path.path_join("artifacts/pc-motor-pool-native")
	var fixture := root_path.path_join("artifacts/pc-motor-pool-trace-03/report.json")
	for flag in ["--output","--fixture"]:
		if flag in args:
			var at := args.find(flag)+1
			if at>=args.size(): check(false,"missing argument "+flag); finish(); return
			if flag=="--output": output=args[at]
			else: fixture=args[at]
	if native: check(DirAccess.make_dir_recursive_absolute(output)==OK,"output directory")
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	backdrop=TextureRect.new();backdrop.size=viewport.size
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(backdrop)
	art=Frontend.new();art.size=viewport.size;art.text_enabled="--text" in args;viewport.add_child(art)
	check(art.load_sources(root_path),"source assets loaded")
	check(not art.motor_catalog.is_empty(),"pinned motor-pool catalog and Genesis art loaded")
	check(FileAccess.file_exists(fixture),"fixture exists")
	if not FileAccess.file_exists(fixture) or art.motor_catalog.is_empty(): finish(); return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var coverage := 0
	for entry in data.samples:
		var source := Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
		var program: Dictionary=entry.program if entry.get("program") is Dictionary else {}
		var enabled: bool=art.set_frame(source,program,entry.presentation)
		var expected: bool=entry.label in ["boot-21","boot-22","boot-23","second-motor-pool","second-motor-pool-start"]
		expected=expected or entry.label in ["select-governor-press","select-governor","toggle-governor-press","toggle-governor","select-begin-press","select-begin"]
		if program.get("name")=="SIM": check(enabled==expected,"motor-pool lifecycle: "+entry.label)
		if not expected: continue
		coverage+=1
		check(enabled,"original pool restored: "+entry.label)
		if not enabled: continue
		check(art.active.pixels>50000,"complete background survives clipboard")
		if art.text_enabled and entry.label!="boot-21" and not entry.label.ends_with("-press"): check(art.typography.runs.size()==7,"seven original clipboard text runs: "+str(art.typography.runs.map(func(r):return r.text)))
		var mask := Image.new()
		mask.load_png_from_buffer(Marshalls.base64_to_raw(entry.presentation.plate_overlay.mask_png))
		if native: await render(source,mask,entry.label)
		if art.text_enabled and entry.label=="boot-22":
			var glyph_changed := source.duplicate();glyph_changed.set_pixel(302,138,Color.MAGENTA)
			check(art.set_frame(glyph_changed,program,entry.presentation),"unsupported glyph does not disable verified background")
			check(not art.typography.runs.any(func(r):return r.text.begins_with("HEAT")),"unsupported digit retains original pixels")
		check(not art.set_frame(source,program,{}),"unpaired source rejected")
		var bad: Dictionary=entry.presentation.duplicate(true)
		bad.plate_overlay.plates["8"].pixels+=1
		check(not art.set_frame(source,program,bad),"incorrect pixel count rejected")
		bad=entry.presentation.duplicate(true);bad.plate_overlay.plates["8"].source_sha256="wrong"
		check(not art.set_frame(source,program,bad),"incorrect source hash rejected")
		bad=entry.presentation.duplicate(true);bad.palette_rgb[4][0]=1
		check(not art.set_frame(source,program,bad),"changed source palette rejected")
		var changed := source.duplicate();changed.set_pixel(20,10,Color.MAGENTA)
		check(not art.set_frame(changed,program,entry.presentation),"one source pixel mismatch rejects replacement")
		bad=entry.presentation.duplicate(true)
		var ui := Image.new();ui.load_png_from_buffer(Marshalls.base64_to_raw(bad.ui_overlay.mask_png));ui.set_pixel(20,10,Color.BLACK)
		bad.ui_overlay.mask_png=Marshalls.raw_to_base64(ui.save_png_to_buffer())
		check(not art.set_frame(source,program,bad),"world ownership cannot be claimed as background")
		# Identical RGB is insufficient: a later PC write discards its tag.
		bad=entry.presentation.duplicate(true);mask.set_pixel(20,10,Color.BLACK)
		bad.plate_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer());bad.plate_overlay.plates["8"].pixels-=1
		check(art.set_frame(source,program,bad),"later overwritten pixel stays original")
		check(not art.set_frame(source,{"name":"START"},entry.presentation),"wrong executable rejected")
		check(not art.visible and art.active.is_empty(),"failure clears stale background")
	check(coverage==11 if data.samples.size()==58 else coverage==5,"first load, partial clipboard, complete clipboard and mission reentry covered")
	check(not art.load_sources(root_path.path_join("artifacts/missing-frontends")),"missing sources rejected")
	check(art.motor_catalog.is_empty() and not art.visible,"missing source clears stale motor pool")
	if native:
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"coverage":coverage,"samples":samples,
			"fixture":fixture,"fixture_sha256":FileAccess.get_sha256(fixture)},"  "))
	finish()

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_MOTOR_POOL_ART: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
