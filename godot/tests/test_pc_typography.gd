extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var checks := 0
var pixels := 0
var changed := 0
var viewport: SubViewport
var view: TextureRect
var source: Image
var ui: Image
var world: Texture2D
var directory: String

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(why)
func _initialize() -> void: run.call_deferred()
func snapshot() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func digest(image: Image) -> String:
	var copy := image.duplicate()
	copy.convert(Image.FORMAT_RGB8)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(copy.get_data())
	return context.finish().hex_encode()
func words(text: String, x: int, y: int, fg := 1, bg := 0, name := "6X6.FNT") -> Dictionary:
	var bytes := FileAccess.get_file_as_bytes(directory.path_join("GAME/"+name))
	var width := int(bytes[0])
	var height := int(bytes[1])
	var box := Rect2i(x,y,text.length()*width,height)
	for i in text.length():
		for sy in height:
			for sx in width:
				var ink := (int(bytes[4+(text.unicode_at(i)-32)*height+sy])&(128>>sx))!=0
				var rgb: Array = Frame.ART_PALETTE[fg if ink else bg]
				source.set_pixel(x+i*width+sx,y+sy,Color8(rgb[0],rgb[1],rgb[2]))
	return {"kind":"instrument","text":text,"rect":[x,y,box.size.x,height],"cell_size":[width,height],
		"font_sha256":FileAccess.get_sha256(directory.path_join("GAME/"+name)),
		"foreground":fg,"uniform_background_rgb":Frame.ART_PALETTE[bg],"pixel_sha256":digest(source.get_region(box))}
func presentation(runs: Array) -> Dictionary:
	return {"draw_pass":{"camera":{"clip":[32,13,287,109]}},"palette_rgb":Frame.ART_PALETTE,
		"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(ui.save_png_to_buffer())},"text_runs":runs}
func run() -> void:
	directory = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	view = Frame.new()
	view.size = viewport.size
	viewport.add_child(view)
	check(view.typography.load_sources(directory.path_join("GAME")),"original fonts verified")
	source = Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color8(85,85,85))
	ui = Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	world = ImageTexture.create_from_image(source)
	var label := words("HEAT READY ",12,165)
	check(view.set_frame(source,presentation([label]),world),"valid composition")
	check(view.typography.runs.size()==1,"source text not accepted")
	check(view.typography.runs[0].font_sha256==label.font_sha256 and view.typography.runs[0].cell_size==Vector2i(6,6),"source font identity and metrics survive verification")
	verify_geometry()
	var args := OS.get_cmdline_user_args()
	var native := "--native" in args
	var output := directory.path_join("artifacts/pc-typography-test")
	if "--output" in args: output = args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	if native:
		var image := await snapshot()
		var verified_box := Rect2i(label.rect[0]*4,label.rect[1]*4,label.rect[2]*4,label.rect[3]*4)
		for y in 800:
			for x in 1280:
				var in_box := verified_box.has_point(Vector2i(x,y))
				var same := image.get_pixel(x,y).to_rgba32()==source.get_pixel(x/4,y/4).to_rgba32()
				pixels += 1
				if not in_box: check(same,"font escaped verified box")
				else:
					if not same: changed += 1
		check(changed==0,"scalable lettering differs from original glyph designs")
		image.save_png(output.path_join("synthetic.png"))
	for field in ["text","font_sha256","pixel_sha256","cell_size","uniform_background_rgb","rect"]:
		var bad := label.duplicate(true)
		bad[field] = {"text":"HEAT LOAD  ","font_sha256":"bad","pixel_sha256":"bad","cell_size":[8,8],"uniform_background_rgb":[1,2,3],"rect":[12,165,60,7]}[field]
		view.set_frame(source,presentation([bad]),world)
		check(view.typography.runs.is_empty(),"invalid "+field+" accepted")
	ui.set_pixel(12,165,Color.BLACK)
	view.set_frame(source,presentation([label]),world)
	check(view.typography.runs.is_empty(),"text covered original world pixel")
	ui.fill(Color.WHITE)
	view.set_frame(source,presentation([label,label]),world)
	check(view.typography.runs.size()==1,"duplicate label drawn twice")
	view.set_frame(source,presentation([]),world)
	check(view.typography.runs.is_empty(),"missing run kept stale label")
	view.set_frame(source,presentation([label]),world)
	view.set_frame(source,{},world)
	check(view.typography.runs.is_empty(),"fallback retained replacement text")
	var blank := words("          ",12,165)
	view.set_frame(source,presentation([blank]),world)
	check(view.typography.runs.is_empty(),"blank clearing draw became a label")
	label = words("HEAT READY ",12,165)
	view.set_frame(source,presentation([label]),world)
	view.size = Vector2(960,600)
	await process_frame
	check(view.typography.size==view.size,"typography did not follow viewport resize")
	check(view.typography.labels[0].position==Vector2(label.rect[0]*3,label.rect[1]*3) and view.typography.labels[0].size==Vector2(label.rect[2]*3,label.rect[3]*3),"resized label left original cell bounds")
	view.size = viewport.size
	await process_frame
	# Bitmap and unobserved fixed labels require the same full glyph/UI proof.
	view.typography.fixed_labels_enabled = true
	words("HDG",66,191)
	view.set_frame(source,presentation([]),world)
	check(view.typography.runs.size()==1 and view.typography.runs[0].text=="HDG","verified driver label not restored")
	source.set_pixel(66,191,Color.MAGENTA)
	view.set_frame(source,presentation([]),world)
	check(view.typography.runs.is_empty(),"overwritten fixed label replaced")
	words("HDG",66,191)
	ui.set_pixel(66,191,Color.BLACK)
	view.set_frame(source,presentation([]),world)
	check(view.typography.runs.is_empty(),"fixed label covered non-UI pixel")
	ui.fill(Color.WHITE)
	var longer := words("HDG  0",66,191)
	view.set_frame(source,presentation([longer]),world)
	check(view.typography.runs.size()==1 and view.typography.runs[0].text=="HDG  0","fixed candidate displaced original observed value")
	view.typography.fixed_labels_enabled = false
	view.typography.status_numbers_enabled = true
	for value in [0,1,9,10,80,100,999]:
		source.fill(Color8(85,85,85))
		var digits := "%3d"%value
		words(digits,83,52)
		view.typography.set_frame(source,ui,presentation([]))
		check(view.typography.runs.size()==1 and view.typography.runs[0].text==digits,"visible stores number differs: "+digits)
	words(" 10",83,52)
	ui.set_pixel(83,52,Color.BLACK)
	view.typography.set_frame(source,ui,presentation([]))
	check(view.typography.runs.is_empty(),"stores number covered non-UI pixel")
	ui.fill(Color.WHITE)
	source.set_pixel(83,52,Color.MAGENTA)
	view.typography.set_frame(source,ui,presentation([]))
	check(view.typography.runs.is_empty(),"ambiguous stores digit accepted")
	view.typography.status_numbers_enabled = false
	if native: await specimen(output)
	if native and "--fixture" in args: await fixtures(args[args.find("--fixture")+1],output)
	check(not view.typography.load_sources(directory.path_join("artifacts/missing-original-font-directory")),"missing fonts accepted")
	check(view.typography.fonts.is_empty() and view.typography.font_geometry.is_empty() and view.typography.runs.is_empty(),"failed font load retained stale typography")
	for error in errors: printerr(error)
	var report := {"checks":checks,"errors":errors,"native":native,"pixels":pixels,"changed":changed}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_TYPOGRAPHY: ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
func fixtures(path: String, output: String) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var observations := []
	for sample in report.ui_presentations:
		var item: Dictionary = report.presentations[sample.frame_index].duplicate(true)
		var pass_data: Dictionary = report.render_passes.filter(func(p):return p.sequence==sample.draw_sequence)[0]
		item.draw_pass = pass_data
		source = Image.load_from_file(path.get_base_dir().path_join(sample.image))
		ui = Image.load_from_file(path.get_base_dir().path_join(sample.mask))
		item.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
		var clip: Array = pass_data.camera.clip
		var crop := source.get_region(Rect2i(clip[0],clip[1],clip[2]-clip[0]+1,clip[3]-clip[1]+1))
		check(view.set_frame(source,item,ImageTexture.create_from_image(crop)),"real paired typography frame")
		var image := await snapshot()
		var frame_changed := 0
		for y in 200:
			for x in 320:
				var eligible := false
				for run in view.typography.runs:
					if run.rect.has_point(Vector2(x+0.5,y+0.5)): eligible=true; break
				var same := image.get_pixel(x*4+2,y*4+2).to_rgba32()==source.get_pixel(x,y).to_rgba32()
				pixels += 1
				if not eligible: check(same,"font changed protected original pixel in "+sample.stage)
				else:
					check(same,"live original letterform changed: "+sample.stage)
					if not same: frame_changed += 1
		changed += frame_changed
		var labels := []
		for run in view.typography.runs: labels.append(run.text)
		observations.append({"stage":sample.stage,"labels":labels,"changed":frame_changed})
		image.save_png(output.path_join(sample.stage+".png"))
	check(observations.any(func(s):return s.labels.size()>3 and s.changed==0),"no faithful actual instrument lettering")
	FileAccess.open(output.path_join("samples.json"),FileAccess.WRITE).store_string(JSON.stringify(observations,"  "))

func verify_geometry() -> void:
	# An independent direct bit oracle covers every printable glyph of each face.
	for name in view.typography.FONT_SOURCES:
		var sha: String = view.typography.FONT_SOURCES[name]
		var bytes := FileAccess.get_file_as_bytes(directory.path_join("GAME/"+name))
		for code in range(32,127):
			var spans: Array = view.typography.font_geometry[sha][code]
			for y in int(bytes[1]):
				for x in int(bytes[0]):
					var ink := (int(bytes[4+(code-32)*int(bytes[1])+y])&(128>>x))!=0
					var count := 0
					for rect: Rect2 in spans:
						check(Rect2(0,0,bytes[0],bytes[1]).encloses(rect),"glyph geometry exceeds its original cell")
						if rect.has_point(Vector2(x+0.5,y+0.5)): count+=1
					check(count==int(ink),"glyph geometry differs/overlaps: %s code %d"%[name,code])
		check(not view.typography.font_geometry[sha].has(127),"unsupported character enters replacement face")

func specimen(output: String) -> void:
	# Draw on an empty backdrop so an invisible renderer cannot pass by showing
	# the original framebuffer. Only the independent bit oracle supplies expected pixels.
	view.hide()
	var backdrop := ColorRect.new()
	backdrop.color=Color8(85,85,85)
	viewport.add_child(backdrop)
	var lettering = preload("res://scripts/pc_typography.gd").new()
	viewport.add_child(lettering)
	check(lettering.load_sources(directory.path_join("GAME")),"standalone original faces loaded")
	source.fill(Color8(85,85,85))
	ui.fill(Color.WHITE)
	var candidates := []
	var index := 0
	for name in view.typography.FONT_SOURCES:
		var origin := Vector2i(4+(index%2)*160,4+(index/2)*100)
		for row in 6:
			var text := ""
			for code in range(32+row*16,mini(48+row*16,127)): text+=String.chr(code)
			candidates.append(words(text,origin.x,origin.y+row*10,1,0,name))
		index+=1
	world = ImageTexture.create_from_image(source)
	source.save_png(output.path_join("four-original-faces-source.png"))
	for factor in [1.0,3.0,3.5,4.0,8.0]:
		viewport.size=Vector2i(Vector2(320,200)*factor)
		backdrop.size=viewport.size
		lettering.size=viewport.size
		lettering.set_frame(source,ui,presentation(candidates))
		check(lettering.runs.size()==24,"all four original faces and printable characters are visible")
		var result := await snapshot()
		for y in result.get_height():
			for x in result.get_width():
				var p := Vector2i(floori((x+0.5)/factor),floori((y+0.5)/factor))
				check(result.get_pixel(x,y).to_rgba32()==source.get_pixelv(p).to_rgba32(),"native font fidelity at scale "+str(factor))
		result.save_png(output.path_join("four-original-faces-"+str(factor)+"x.png"))
	lettering.free()
	backdrop.free()
	view.show()
	viewport.size=Vector2i(1280,800)
	view.size=viewport.size
