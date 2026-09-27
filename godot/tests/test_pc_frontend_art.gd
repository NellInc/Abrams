extends SceneTree
const Frontend = preload("res://scripts/pc_frontend_art.gd")
var errors: Array[String] = []
var checks := 0
var view: SubViewport
var original: TextureRect
var art: TextureRect
var samples: Array[Dictionary] = []
var native := false
var output: String

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void: run.call_deferred()

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

func render(source: Image, label: String) -> void:
	original.texture = ImageTexture.create_from_image(source)
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var image := view.get_texture().get_image()
	var height := int(art.active.get("height",0))
	var changed := 0
	for y in 800:
		for x in 1280:
			var same := image.get_pixel(x,y).to_rgba32()==source.get_pixel(x/4,y/4).to_rgba32()
			var text_pixel := false
			for run in art.typography.runs:
				if run.rect.has_point(Vector2(x/4,y/4)): text_pixel=true; break
			if text_pixel: check(same,"original office letterform changed: "+label)
			elif y>=height*4: check(same,"protected original text/fallback changed: "+label)
			elif not same: changed+=1
	if height>0:
		check(changed>100000,"restored office visibly drawn: "+label)
		var office: Image = art.material.get_shader_parameter("office").get_image()
		var face: Image = art.portraits[art.active.pose].get_image()
		var rect: Array = art.catalog.templates[art.active.pose].portrait_rect
		for y in range(0,height*4,31):
			for x in range(0,1280,29):
				var p := (Vector2(x,y)+Vector2(0.5,0.5))/4
				var expected := bilinear(office,p/Vector2(320,200))
				var q := (p-Vector2(rect[0],rect[1]))/Vector2(rect[2],rect[3])
				if q.x>=0 and q.y>=0 and q.x<1 and q.y<1:
					var fg := bilinear(face,q)
					expected = expected.lerp(Color(fg.r,fg.g,fg.b,1),fg.a)
				var actual := image.get_pixel(x,y)
				check(absf(actual.r-expected.r)<=3.0/255 and absf(actual.g-expected.g)<=3.0/255 and absf(actual.b-expected.b)<=3.0/255,"wrong Genesis donor/alpha/filter: "+label)
	check(image.save_png(output.path_join(label+".png"))==OK,"save native frame: "+label)
	samples.append({"label":label,"active":art.active.duplicate(),"changed_pixels":changed,
		"text":art.typography.runs.map(func(r):return r.text)})

func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	native = "--native" in args
	output = root_path.path_join("artifacts/pc-frontend-native")
	var fixture := root_path.path_join("artifacts/pc-live-type-lifecycle-01/report.json")
	for flag in ["--output","--fixture"]:
		if flag in args:
			var at := args.find(flag)+1
			if at>=args.size(): check(false,"missing argument: "+flag); finish(); return
			if flag=="--output": output=args[at]
			else: fixture=args[at]
	if native: check(DirAccess.make_dir_recursive_absolute(output)==OK,"native output directory")
	view=SubViewport.new()
	view.size=Vector2i(1280,800)
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	original=TextureRect.new()
	original.size=view.size
	original.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	original.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	view.add_child(original)
	art=Frontend.new()
	art.text_enabled = "--text" in args
	art.size=view.size
	view.add_child(art)
	check(art.load_sources(root_path),"pinned original templates and Genesis art loaded")
	check(FileAccess.file_exists(fixture),"fixture exists")
	if art.catalog.is_empty() or not FileAccess.file_exists(fixture): finish(); return
	var data = JSON.parse_string(FileAccess.get_file_as_string(fixture))
	check(data is Dictionary and data.get("samples") is Array,"fixture samples available")
	if not data is Dictionary or not data.get("samples") is Array: finish(); return
	var coverage := {0:0,1:0,2:0}
	for entry in data.samples:
		var source := Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
		check(source!=null and source.get_size()==Vector2i(320,200),"source image available")
		if source==null or source.get_size()!=Vector2i(320,200): continue
		var program: Dictionary = entry.program if entry.get("program") is Dictionary else {}
		var enabled: bool = art.set_frame(source,program)
		if enabled: coverage[art.active.pose]+=1
		if entry.label in ["boot-15","boot-17","boot-19","debrief"]: check(enabled,"observed office must restore: "+entry.label)
		if program.get("name") not in ["BRIEF","END"]: check(not enabled,"non-office program retains original")
		if native and program.get("name") in ["BRIEF","END"]: await render(source,entry.label)
		if entry.label=="boot-17":
			var changed := source.duplicate()
			changed.set_pixel(20,50,Color.MAGENTA)
			check(not art.set_frame(changed,program),"one changed office pixel rejects replacement")
			if native: await render(changed,"negative-overwrite")
			changed=source.duplicate()
			changed.set_pixel(20,180,Color.GREEN)
			check(art.set_frame(changed,program),"dialogue contents remain independent")
			if native: await render(changed,"negative-dialogue-retained")
			changed=source.duplicate()
			changed.set_pixel(0,167,Color.BLACK)
			check(not art.set_frame(changed,program),"partial dialogue border rejected")
			check(not art.set_frame(source,{"name":"SIM"}),"identical pixels in wrong program rejected")
			check(not art.visible and art.active.is_empty(),"fallback hides stale office")
		if entry.label=="boot-19":
			art.typography.set_office_dialogue(source,167)
			check(art.typography.runs.size()==3,"three fully displayed source dialogue lines decode")
			var words: Array = art.typography.runs.map(func(r):return r.text.strip_edges())
			check('"If we\'re gonna go down, lets do it' in words,"original dialogue words preserved exactly")
			var changed := source.duplicate()
			changed.set_pixel(8,169,Color.MAGENTA)
			art.typography.set_office_dialogue(changed,167)
			check(art.typography.runs.size()==2,"one non-glyph pixel retains its whole original line")
			check(art.typography.runs.all(func(r):return r.rect.position.y!=169),"uncertain first line is not guessed")
			art.typography.clear_runs()
	for id in coverage: check(coverage[id]>0,"real source pose coverage: "+str(id))
	# The compositor must hide a previous frontend before a SIM/menu update.
	var tandem = preload("res://scripts/pc_tandem_frame.gd").new()
	root.add_child(tandem)
	tandem.frontend_art.visible=true
	tandem.frontend_art.active={"name":"test"}
	tandem.set_frame(Image.create_empty(320,200,false,Image.FORMAT_RGB8),{},null)
	check(not tandem.frontend_art.visible and tandem.frontend_art.active.is_empty(),"tandem clears stale frontend")
	tandem.queue_free()
	check(not art.load_sources(root_path.path_join("artifacts/missing-frontends")),"missing assets rejected")
	check(art.catalog.is_empty() and not art.visible,"failed load clears old art")
	if native:
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"coverage":coverage,
			"fixture":fixture,"fixture_sha256":FileAccess.get_sha256(fixture),"samples":samples},"  "))
	finish()

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_FRONTEND_ART: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
