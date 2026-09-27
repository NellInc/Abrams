extends SceneTree
const Frontend = preload("res://scripts/pc_frontend_art.gd")
var checks := 0
var errors: Array[String] = []
var art: TextureRect
var tandem: TextureRect
var viewport: SubViewport
var backdrop: TextureRect
var native := false
var output: String
var samples: Array = []

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void: run.call_deferred()

func bilinear(image: Image, point: Vector2) -> Color:
	var at := Vector2i(floori(point.x),floori(point.y))
	var f := point-Vector2(at)
	var limit := image.get_size()-Vector2i.ONE
	return image.get_pixelv(at.clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.RIGHT).clamp(Vector2i.ZERO,limit)),f.x).lerp(image.get_pixelv((at+Vector2i.DOWN).clamp(Vector2i.ZERO,limit)).lerp(image.get_pixelv((at+Vector2i.ONE).clamp(Vector2i.ZERO,limit)),f.x),f.y)

func render(source: Image, label: String) -> void:
	backdrop.texture=ImageTexture.create_from_image(source)
	await process_frame
	RenderingServer.force_draw(false); RenderingServer.force_sync()
	var image := viewport.get_texture().get_image()
	var item: Dictionary=art.information_art.active
	var area := Rect2i()
	if not item.is_empty(): area=Rect2i(item.rect[0],item.rect[1],item.rect[2],item.rect[3])
	var changed := 0
	for y in 800:
		for x in 1280:
			var p := Vector2i(x/4,y/4)
			if not area.has_point(p): check(image.get_pixel(x,y)==source.get_pixelv(p),"protected source information: "+label)
			elif image.get_pixel(x,y)!=source.get_pixelv(p): changed+=1
	if not item.is_empty() and item.name!="crew":
		check(changed>int(area.get_area()*4),"illustration visibly restored: "+label)
		check(image.get_pixelv(area.position*4+Vector2i(2,2))==Color8(238,68,65),"Genesis red frame: "+label)
		var donor: Image=art.information_art.textures[item.name].get_image()
		var target := Rect2(area).grow(-1)
		var height := donor.get_width()*target.size.y/target.size.x
		var crop := Rect2(0,(donor.get_height()-height)/2,donor.get_width(),height)
		if height>donor.get_height():
			var width := donor.get_height()*target.size.x/target.size.y
			crop=Rect2((donor.get_width()-width)/2,0,width,donor.get_height())
		for fraction in [Vector2(0.23,0.27),Vector2(0.51,0.53),Vector2(0.81,0.71)]:
			var pixel := Vector2i((target.position+target.size*fraction)*4)
			var uv := ((Vector2(pixel)+Vector2(0.5,0.5))/4-target.position)/target.size
			var expected := bilinear(donor,crop.position+crop.size*uv-Vector2(0.5,0.5))
			var actual := image.get_pixelv(pixel)
			check(absf(actual.r-expected.r)<=3.0/255 and absf(actual.g-expected.g)<=3.0/255 and absf(actual.b-expected.b)<=3.0/255,"independent Genesis donor probe: "+label)
	if item.get("name")=="crew": verify_crew(source,image)
	check(image.save_png(output.path_join(label+".png"))==OK,"native output saved")
	samples.append({"label":label,"art":item.get("name",""),"changed_pixels":changed})

func verify_crew(source: Image, image: Image) -> void:
	# Independent full-frame oracle: no original text exists underneath the black
	# page. Expected glyph/callout shapes come directly from the reference pixels,
	# never the generated overlay spans. Each image uses its explicit donor crop.
	var portrait_boxes: Array[Rect2i]=[Rect2i(18,23,49,48),Rect2i(18,121,49,48),Rect2i(253,121,49,48),Rect2i(253,24,49,47)]
	var layers: Array=art.information_art.active.layers
	check(layers.map(func(l):return l.name)==["crew-diagram","crew-gunner","crew-driver","crew-loader","crew-commander"],"original crew-role placement/order")
	var images := {}
	for layer in layers: images[layer.name]=art.information_art.textures[layer.name].get_image()
	for y in 800:
		for x in 1280:
			var p:=Vector2i(x/4,y/4)
			var centre:=(Vector2(x,y)+Vector2(0.5,0.5))/4
			var expected:=Color.BLACK
			for layer in layers:
				var r: Array=layer.rect
				var box:=Rect2(r[0],r[1],r[2],r[3])
				if not box.has_point(centre): continue
				var donor: Image=images[layer.name]
				var area:=Rect2(Vector2.ZERO,Vector2(donor.get_size()))
				if layer.name=="crew-diagram": area=Rect2(33,62,2106,560)
				expected=bilinear(donor,area.position+(centre-box.position)/box.size*area.size-Vector2(0.5,0.5))
			if not portrait_boxes.any(func(box):return box.has_point(p)):
				var rgb:=source.get_pixelv(p).to_rgba32()
				if Rect2i(16,10,288,8).has_point(p) and rgb==0x00aa00ff: expected=Color8(238,238,238)
				elif Rect2i(68,62,61,21).has_point(p) and rgb in [0xffffffff,0x555555ff]:
					expected=Color8(172,170,172) if rgb==0xffffffff else Color8(65,68,65)
				elif Rect2i(8,20,304,150).has_point(p):
					if rgb==0xffff55ff: expected=Color8(238,238,65)
					elif rgb==0x55ffffff: expected=Color8(65,238,238)
					elif rgb==0xff5555ff: expected=Color8(238,0,0)
					elif rgb==0xaa5500ff:
						expected=Color8(98,32,0) if Rect2i(59,60,202,61).has_point(p) else Color8(205,101,32)
			var actual:=image.get_pixel(x,y)
			check(absf(actual.r-expected.r)<=3.0/255 and absf(actual.g-expected.g)<=3.0/255 and absf(actual.b-expected.b)<=3.0/255,"complete crew donor/label/callout composition")

func apply_frame(source: Image, program: Dictionary, presentation: Dictionary={}) -> bool:
	if tandem!=null: tandem.set_frame(source,{},null)
	return art.set_frame(source,program,presentation)

func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	native="--native" in args
	var fixture := root_path.path_join("artifacts/pc-information-baseline-02/report.json")
	output=root_path.path_join("artifacts/pc-information-native")
	for flag in ["--fixture","--output"]:
		if flag in args:
			var at := args.find(flag)+1
			if at>=args.size(): check(false,"missing "+flag); finish(); return
			if flag=="--fixture": fixture=args[at]
			else: output=args[at]
	viewport=SubViewport.new(); viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	backdrop=TextureRect.new(); backdrop.size=viewport.size
	backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; backdrop.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(backdrop)
	if "--tandem" in args:
		tandem=preload("res://scripts/pc_tandem_frame.gd").new()
		tandem.size=viewport.size;viewport.add_child(tandem)
		check(tandem.load_genesis_art(root_path),"complete live tandem material set loaded")
		art=tandem.frontend_art
	else:
		art=Frontend.new(); art.size=viewport.size; viewport.add_child(art)
	check(art.load_sources(root_path),"frontend source set loaded")
	check(not art.information_art.catalog.is_empty(),"pinned information catalog loaded")
	check(FileAccess.file_exists(fixture),"fixture exists")
	if not FileAccess.file_exists(fixture) or art.information_art.catalog.is_empty(): finish(); return
	if native: check(DirAccess.make_dir_recursive_absolute(output)==OK,"output directory")
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(fixture))
	var pages := ["crew","ax","sabot","coax","cannon","smoke"]
	var coverage := {}
	for entry in report.samples:
		var source := Image.load_from_file(fixture.get_base_dir().path_join(entry.image))
		var program: Dictionary=entry.program if entry.get("program") is Dictionary else {}
		var enabled: bool=apply_frame(source,program,entry.presentation)
		if entry.label in pages or entry.label.trim_suffix("-wait") in pages:
			check(enabled and art.active.get("scene")=="information","known page enabled: "+entry.label)
			check(art.information_art.active.get("name")==entry.label.trim_suffix("-wait"),"correct illustration identity")
			coverage[entry.label.trim_suffix("-wait")]=true
		elif entry.label in ["heat","information-close"]:
			check(not enabled,"unsupported pages and menus remain original: "+entry.label)
		if native and entry.label in pages+["heat","information-close"]: await render(source,entry.label)
		if entry.label=="crew":
			check(art.information_art.active.layers.size()==5,"diagram plus four crew portraits")
			for at in [Vector2i(16,10),Vector2i(18,23),Vector2i(70,35),Vector2i(170,83),Vector2i(10,190)]:
				var changed:=source.duplicate();changed.set_pixelv(at,Color.MAGENTA)
				check(not apply_frame(changed,program,{}),"changed crew page pixel rejects full composition: "+str(at))
				if native: await render(changed,"crew-rejected-%d-%d"%[at.x,at.y])
			check(not apply_frame(source,{"name":"SIM"},{}),"crew image in wrong program rejected")
		if entry.label=="coax":
			for at in [Vector2i(0,0),Vector2i(18,143),Vector2i(151,95)]:
				var changed := source.duplicate(); changed.set_pixelv(at,Color.MAGENTA)
				check(not apply_frame(changed,program,{}),"one changed prefix pixel rejects whole illustration")
				check(not art.visible and art.information_art.active.is_empty(),"failure clears stale illustration")
				if native: await render(changed,"rejected-%d-%d"%[at.x,at.y])
			var border := source.duplicate(); border.set_pixel(200,175,Color.MAGENTA)
			check(apply_frame(border,program,{}),"variable untouched lower border permits correct illustration")
			if native: await render(border,"preserved-border")
			check(not apply_frame(source,{"name":"SIM"},{}),"wrong executable rejects information")
	check(coverage.size()==6,"all six supported pages and settled waits covered")
	check(not art.load_sources(root_path.path_join("artifacts/missing-information")),"missing sources rejected")
	check(art.information_art.catalog.is_empty() and not art.visible,"missing source clears stale information")
	if native:
		var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"errors":errors,"coverage":coverage.keys(),"samples":samples,
			"fixture":fixture,"fixture_sha256":FileAccess.get_sha256(fixture)},"  "))
	finish()

func finish() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_INFORMATION_ART: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
