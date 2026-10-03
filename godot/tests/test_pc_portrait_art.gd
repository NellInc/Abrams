extends SceneTree
const Portraits = preload("res://scripts/pc_portrait_art.gd")
var view: SubViewport
var background: TextureRect
var portraits: Control
var errors: Array[String] = []
var checks := 0
var samples: Array[Dictionary] = []

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void:
	create_timer(180).timeout.connect(func(): printerr("FAIL: portrait art deadline"); quit(2))
	run.call_deferred()

func arg_value(args: PackedStringArray, flag: String) -> String:
	var index := args.find(flag)
	if index<0: return ""
	var ok := index+1<args.size() and not args[index+1].begins_with("--")
	check(ok,"missing value for "+flag)
	return args[index+1] if ok else ""

func packet(id: int, at: Vector2i) -> Dictionary:
	return {"text_runs":[{"kind":"crew_primary","speaker":id,"rect":[at.x+9,at.y+53,60,6]}]}

func paint(source: Image, item: Dictionary, at: Vector2i) -> void:
	for point in item.points: source.set_pixelv(at+point.at,Color.hex(point.rgb))

func snapshot(source: Image) -> Image:
	background.texture=ImageTexture.create_from_image(source)
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return view.get_texture().get_image()

func bilinear(image: Image, uv: Vector2) -> Color:
	var p := uv*Vector2(image.get_size())-Vector2(0.5,0.5)
	var a := Vector2i(floori(p.x),floori(p.y))
	var f := p-Vector2(a)
	var bounds := image.get_size()-Vector2i.ONE
	var c00 := image.get_pixelv(a.clamp(Vector2i.ZERO,bounds))
	var c10 := image.get_pixelv((a+Vector2i.RIGHT).clamp(Vector2i.ZERO,bounds))
	var c01 := image.get_pixelv((a+Vector2i.DOWN).clamp(Vector2i.ZERO,bounds))
	var c11 := image.get_pixelv((a+Vector2i.ONE).clamp(Vector2i.ZERO,bounds))
	return c00.lerp(c10,f.x).lerp(c01.lerp(c11,f.x),f.y)

func verify_native(source: Image, label: String, output: String) -> void:
	var active: Dictionary = portraits.active.duplicate()
	var rendered := await snapshot(source)
	var allowed := Image.create_empty(320,200,false,Image.FORMAT_L8)
	allowed.fill(Color.BLACK)
	if not active.is_empty():
		var item: Dictionary = portraits.templates[active.id]
		for point in item.points: allowed.set_pixelv(active.at+point.at,Color.WHITE)
		var donor: Image = item.texture.get_image()
		for i in range(0,item.points.size(),29):
			var p: Vector2i = item.points[i].at
			var expected := bilinear(donor,(Vector2(p)+Vector2(0.625,0.625))/Vector2(item.size))
			var actual := rendered.get_pixelv((Vector2i(active.at)+p)*4+Vector2i(2,2))
			check(absf(actual.r-expected.r)<=2.0/255 and absf(actual.g-expected.g)<=2.0/255 and absf(actual.b-expected.b)<=2.0/255,"wrong portrait donor/filter: "+label)
	var changed := 0
	for y in 800:
		for x in 1280:
			var same := rendered.get_pixel(x,y).to_rgba32()==source.get_pixel(x/4,y/4).to_rgba32()
			if allowed.get_pixel(x/4,y/4).r==0: check(same,"portrait covered source transparency/text/world: %s %d,%d"%[label,x,y])
			elif not same: changed+=1
	if not active.is_empty(): check(changed>1000,"remastered face not visibly drawn: "+label)
	check(rendered.save_png(output.path_join(label+".png"))==OK,"native capture saved: "+label)
	samples.append({"label":label,"portrait":active.get("name"),"id":active.get("id"),"changed_pixels":changed})

func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	var native := "--native" in args
	var output := root_path.path_join("artifacts/pc-portrait-test")
	if "--output" in args: output=arg_value(args,"--output")
	if output.is_empty(): finish(); return
	if native: check(DirAccess.make_dir_recursive_absolute(output)==OK,"output directory")
	view=SubViewport.new()
	view.size=Vector2i(1280,800)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	background=TextureRect.new()
	background.size=view.size
	background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	view.add_child(background)
	portraits=Portraits.new()
	portraits.size=view.size
	view.add_child(portraits)
	check(portraits.load_sources(root_path),"original samples and four Genesis portraits loaded")
	if portraits.templates.size()!=4:
		finish()
		return
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var at := Vector2i(37,59)
	for id in 4:
		source.fill(Color8(85,85,85))
		var item: Dictionary = portraits.templates[id]
		paint(source,item,at)
		portraits.set_frame(source,ui,{})
		check(portraits.active.get("id")==id,"first complete face precedes caption: "+str(id))
		portraits.set_frame(source,ui,packet(id,at))
		check(portraits.active.get("id")==id,"complete source portrait accepted: "+str(id))
		if native: await verify_native(source,"synthetic-"+item.name,output)
		var p: Vector2i = at+item.points[0].at
		var saved := source.get_pixelv(p)
		source.set_pixelv(p,Color.MAGENTA)
		portraits.set_frame(source,ui,packet(id,at))
		check(portraits.active.is_empty(),"partial/overwritten portrait rejected")
		source.set_pixelv(p,saved)
		ui.set_pixelv(p,Color.BLACK)
		portraits.set_frame(source,ui,packet(id,at))
		check(portraits.active.is_empty(),"non-UI portrait pixel rejected")
		ui.fill(Color.WHITE)
		portraits.set_frame(source,ui,packet((id+1)%4,at))
		check(portraits.active.get("id")==id,"speaker hint cannot override current source identity")
		portraits.set_frame(source,ui,packet(id,Vector2i(-100,-100)))
		check(portraits.active.get("id")==id,"text cannot move the source-defined portrait anchor")
		portraits.set_frame(source,ui,{})
		check(portraits.active.get("id")==id,"caption disappearance cannot remove a still-visible face")
		source.fill(Color8(85,85,85))
		portraits.set_frame(source,ui,packet(id,at))
		check(portraits.active.is_empty(),"source erasure clears portrait even while text remains")
	portraits.set_frame(source,ui,{})
	check(portraits.active.is_empty(),"empty current source clears stale portrait")
	var hint := packet(3,at)
	paint(source,portraits.templates[3],Vector2i(190,59))
	hint.text_runs.append(packet(3,Vector2i(190,59)).text_runs[0])
	portraits.set_frame(source,ui,hint)
	check(portraits.active.is_empty(),"text cannot authorize a face outside its original position")
	paint(source,portraits.templates[3],at)
	portraits.set_frame(source,ui,hint)
	check(portraits.active.get("at")==at,"only source-defined position is eligible")
	for invalid in [{"text_runs":null},{"text_runs":[null]},
		{"text_runs":[{"kind":"crew_primary","speaker":1.5,"rect":[46,112,60,6]}]},
		{"text_runs":[{"kind":"crew_primary","speaker":3,"rect":[46.5,112,60,6]}]}]:
		portraits.set_frame(source,ui,invalid)
		check(portraits.active.get("id")==3,"malformed unrelated text cannot delay the proven face")
	# Ambiguity still fails closed; pinned production templates are distinct.
	var original_template: Dictionary = portraits.templates[0]
	portraits.templates[0] = portraits.templates[3].duplicate(true)
	portraits.templates[0].id = 0
	portraits.set_frame(source,ui,{})
	check(portraits.active.is_empty(),"ambiguous source identities retain original")
	portraits.templates[0] = original_template
	for pair in [[null,ui],[source,null],
		[Image.create_empty(640,400,false,Image.FORMAT_RGB8),ui],
		[source,Image.create_empty(320,200,false,Image.FORMAT_RGB8)]]:
		portraits.set_frame(pair[0],pair[1],{})
		check(portraits.active.is_empty(),"invalid current image or provenance clears the face")
	# Exercise the real compositor lifecycle too; a menu, missing world or
	# invalid provenance must remove yesterday's face along with its frame.
	var tandem = preload("res://scripts/pc_tandem_frame.gd").new()
	root.add_child(tandem)
	check(tandem.load_genesis_art(root_path),"tandem Genesis assets loaded")
	var presentation := packet(3,at)
	presentation.draw_pass = {"camera":{"clip":[32,13,287,109]}}
	presentation.ui_overlay = {"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(ui.save_png_to_buffer())}
	var world := ImageTexture.create_from_image(source.get_region(Rect2i(32,13,256,97)))
	check(tandem.set_frame(source,presentation,world),"tandem source accepted")
	check(tandem.portrait_art.active.get("id")==3,"tandem enables verified portrait")
	check(not tandem.set_frame(source,{},null),"menu fallback accepted")
	check(tandem.portrait_art.active.is_empty(),"menu fallback clears portrait")
	check(tandem.set_frame(source,presentation,world),"portrait restored after fallback")
	check(not tandem.set_frame(source,presentation,null),"missing world rejected")
	check(tandem.portrait_art.active.is_empty(),"missing world clears portrait")
	tandem.queue_free()
	if native:
		var fixture := root_path.path_join("artifacts/pc-live-type-crew-02/report.json")
		if "--fixture" in args: fixture=arg_value(args,"--fixture")
		check(FileAccess.file_exists(fixture),"recorded fixture exists")
		if FileAccess.file_exists(fixture): await recorded(fixture,output)
	check(not portraits.load_sources(root_path.path_join("artifacts/missing-portrait-assets")),"missing original/art set rejected")
	check(portraits.templates.is_empty() and portraits.active.is_empty(),"failed asset load clears stale state")
	if native:
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"samples":samples},"  "))
	finish()

func recorded(path: String, output: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data is Dictionary and data.get("ui_presentations") is Array,"supported recorded fixture")
	if not data is Dictionary or not data.get("ui_presentations") is Array: return
	var visible := 0
	for entry in data.ui_presentations:
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
		var presentation = entry.get("presentation")
		if not presentation is Dictionary:
			var frames = data.get("presentations")
			var index := int(entry.get("frame_index",-1))
			check(frames is Array and index>=0 and index<frames.size(),"recorded presentation is present")
			if not frames is Array or index<0 or index>=frames.size(): continue
			presentation = frames[index]
		portraits.set_frame(source,ui,presentation)
		if entry.has("expected_portrait"):
			check(portraits.active.get("id",-1)==int(entry.expected_portrait),"exact recorded portrait lifecycle: "+entry.stage)
		if not portraits.active.is_empty(): visible+=1
		await verify_native(source,"recorded-"+entry.stage,output)
	check(visible>0,"real original portraits visibly restored")

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_PORTRAIT_ART: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
