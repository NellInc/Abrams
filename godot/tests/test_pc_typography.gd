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
var outlines = preload("res://tests/pc_outline_oracle.gd").new()
var predicate_timings: Array = []

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
	outlines.load_sources(directory)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	view = Frame.new()
	view.size = viewport.size
	viewport.add_child(view)
	check(view.typography.load_sources(directory.path_join("GAME")),"original fonts verified")
	check(view.typography.outline_fonts.fonts.size()==4,"all four outline faces verified")
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
					check(outlines.matches(image.get_pixel(x,y),view.typography.runs[0],(Vector2(x,y)+Vector2(0.5,0.5))/4,Vector2(4,4)),"synthetic outline contours and colours")
					if not same: changed += 1
		check(changed>0,"outline renderer must replace bitmap stair steps")
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
	cache_contracts()
	if native: await specimen(output)
	if native: await dialogue_preview(output)
	if native and "--fixture" in args: await fixtures(args[args.find("--fixture")+1],output)
	check(not view.typography.load_sources(directory.path_join("artifacts/missing-original-font-directory")),"missing fonts accepted")
	check(view.typography.fonts.is_empty() and view.typography.font_geometry.is_empty() and view.typography.runs.is_empty() and view.typography._expected_text.is_empty(),"failed font load retained stale typography")
	for error in errors: printerr(error)
	var report := {"checks":checks,"errors":errors,"native":native,"pixels":pixels,"changed":changed,"predicate_timings":predicate_timings}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("PC_TYPOGRAPHY: ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)

func same_predicate(oracle: Control, item: Dictionary, cursor: Image=null) -> Dictionary:
	var actual: Dictionary=view.typography.verified_run(item,source,ui,Frame.ART_PALETTE,cursor)
	var expected: Dictionary=oracle.verified_run(item,source,ui,Frame.ART_PALETTE,cursor)
	check(actual==expected,"exact pre-optimization pixel-loop result")
	return actual

func cache_contracts() -> void:
	var oracle := preload("res://tests/pc_typography_pixel_oracle.gd").new()
	# Same actual font resources, separately executed frozen pixel predicate.
	oracle.fonts=view.typography.fonts
	oracle.font_geometry=view.typography.font_geometry
	oracle.outline_fonts=view.typography.outline_fonts
	for name in view.typography.FONT_SOURCES:
		for code in range(32,127):
			var label := words(String.chr(code),16,20,1,0,name)
			same_predicate(oracle,label)
			same_predicate(oracle,label) # warm expected bytes, fresh current proof
	var label := words("HEAT READY",12,165)
	var box := Rect2i(12,165,60,6)
	check(not same_predicate(oracle,label).is_empty(),"warm text accepted")
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			var old := source.get_pixel(x,y)
			source.set_pixel(x,y,Color.MAGENTA)
			# Supply the CURRENT hash: glyph equality must reject independently.
			label.pixel_sha256=digest(source.get_region(box))
			check(same_predicate(oracle,label).is_empty(),"every changed glyph/background pixel rejects after cache hit")
			source.set_pixel(x,y,old)
			label.pixel_sha256=digest(source.get_region(box))
			ui.set_pixel(x,y,Color.BLACK)
			check(same_predicate(oracle,label).is_empty(),"every missing ownership pixel rejects after cache hit")
			ui.set_pixel(x,y,Color.WHITE)
	for format in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8,Image.FORMAT_RGBAF]:
		source.convert(format)
		check(not same_predicate(oracle,label).is_empty(),"exact source format")
		if format!=Image.FORMAT_RGB8:
			var old := source.get_pixelv(box.position)
			source.set_pixelv(box.position,Color(old.r,old.g,old.b,0.5))
			check(same_predicate(oracle,label).is_empty(),"alpha mismatch rejects independently of RGB hash")
			source.set_pixelv(box.position,old)
	source.convert(Image.FORMAT_RGB8)
	ui.convert(Image.FORMAT_RGBA8)
	ui.fill(Color(1,0,0,0))
	check(not same_predicate(oracle,label).is_empty(),"non-L8 ownership retains red-channel semantics")
	ui=Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var cursor := Image.create_empty(320,200,false,Image.FORMAT_L8)
	cursor.fill(Color.BLACK)
	cursor.fill_rect(box,Color.WHITE)
	check(same_predicate(oracle,label,cursor).is_empty(),"fully covered glyph has no visible ink")
	cursor.fill(Color.BLACK)
	cursor.set_pixelv(box.position,Color.WHITE)
	source.set_pixelv(box.position,Color.MAGENTA)
	label.pixel_sha256=digest(source.get_region(box))
	check(not same_predicate(oracle,label,cursor).is_empty(),"cursor may cover its own pixel with current hash")
	ui.set_pixelv(box.position,Color.BLACK)
	check(same_predicate(oracle,label,cursor).is_empty(),"cursor never excuses missing UI ownership")
	ui.fill(Color.WHITE)
	label=words("HEAT READY",12,165)
	var sha: String=label.font_sha256
	var original: PackedByteArray=view.typography.fonts[sha].duplicate()
	check(not same_predicate(oracle,label).is_empty(),"warm font data")
	view.typography.fonts[sha][4+("H".unicode_at(0)-32)*6]^=128
	check(same_predicate(oracle,label).is_empty(),"changed font bytes invalidate expected glyph bytes")
	view.typography.fonts[sha]=original
	check(not same_predicate(oracle,label).is_empty(),"restored actual font bytes recover")
	for sequence in range(100):
		label=words("%03d"%sequence,12,165)
		label.draw_sequence=sequence
		check(same_predicate(oracle,label).draw_sequence==sequence,"current event metadata is never cached")
		check(view.typography._expected_text.size()<=view.typography.EXPECTED_TEXT_LIMIT,"expected glyph storage bounded")
	for foreground in 16:
		for background in 16:
			label=words("HEAT READY",12,165,foreground,background)
			var result := same_predicate(oracle,label)
			check(result.is_empty()==(Frame.ART_PALETTE[foreground]==Frame.ART_PALETTE[background]),"every palette/background combination and zero-contrast rejection")
	label=words("HEAT READY",12,165)
	for field in ["pixel_sha256","text"]:
		var bad := label.duplicate(true)
		bad[field]="bad"
		check(same_predicate(oracle,bad).is_empty(),"current metadata cannot inherit cached proof")
	# Alternating in-process timing, informational only. No speed threshold gate.
	for round_index in 6:
		var row := {}
		for name in (["current","oracle"] if round_index%2==0 else ["oracle","current"]):
			var target: Control=view.typography if name=="current" else oracle
			var start := Time.get_ticks_usec()
			for i in 500: target.verified_run(label,source,ui,Frame.ART_PALETTE)
			row[name+"_us"]=(Time.get_ticks_usec()-start)/500.0
		predicate_timings.append(row)
	oracle.free()

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
				var eligible: Dictionary = {}
				for run in view.typography.runs:
					if run.rect.has_point(Vector2(x+0.5,y+0.5)): eligible=run; break
				var same := image.get_pixel(x*4+2,y*4+2).to_rgba32()==source.get_pixel(x,y).to_rgba32()
				pixels += 1
				if eligible.is_empty(): check(same,"font changed protected original pixel in "+sample.stage)
				else:
					eligible = eligible.duplicate()
					if eligible.get("transparent_world",false): eligible.background=source.get_pixel(x,y)
					check(outlines.matches(image.get_pixel(x*4+2,y*4+2),eligible,Vector2(x+0.625,y+0.625),Vector2(4,4)),"live outline letterform: "+sample.stage)
					if not same: frame_changed += 1
		changed += frame_changed
		var labels := []
		for run in view.typography.runs: labels.append(run.text)
		observations.append({"stage":sample.stage,"labels":labels,"changed":frame_changed})
		image.save_png(output.path_join(sample.stage+".png"))
	check(observations.any(func(s):return s.labels.size()>3 and s.changed>0),"no visible outline instrument lettering")
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

func dialogue_preview(output: String) -> void:
	# The reported dialogue uses the same verified-run and fixed-cell draw path.
	var blue := Color8(85,85,255)
	source.fill(blue)
	ui.fill(Color.WHITE)
	var lines := ["\"What can I say...the odds look like",
		"twenty to one and we aren't the", "favorites.\""]
	var candidates := []
	for row in lines.size():
		candidates.append(words(lines[row],6,6+row*8,1,4,"8X8.FNT"))
	world = ImageTexture.create_from_image(source)
	view.typography.fixed_labels_enabled = false
	check(view.set_frame(source,presentation(candidates),world),"dialogue frame accepted")
	check(view.typography.runs.size()==3,"all reported dialogue rows restored")
	var result := await snapshot()
	if result.is_empty():
		check(false,"native dialogue renderer returned no image")
		return
	var difference := 0
	for y in 144:
		for x in 1200:
			var point := (Vector2(x,y)+Vector2(0.5,0.5))/4
			var eligible := {}
			for run in view.typography.runs:
				if run.rect.has_point(point): eligible=run;break
			var actual := result.get_pixel(x,y)
			if eligible.is_empty():
				check(actual.to_rgba32()==blue.to_rgba32(),"dialogue font escaped its original rows")
			else:
				check(outlines.matches(actual,eligible,point,Vector2(4,4)),"reported dialogue native outlines")
				if actual.to_rgba32()!=source.get_pixel(x/4,y/4).to_rgba32(): difference+=1
	check(difference>0,"reported dialogue must visibly replace source pixel steps")
	check(result.get_region(Rect2i(0,0,1200,144)).save_png(output.path_join("dialogue-refined.png"))==OK,"save native dialogue preview")
	var original := source.get_region(Rect2i(0,0,300,36))
	original.resize(1200,144,Image.INTERPOLATE_NEAREST)
	check(original.save_png(output.path_join("dialogue-original.png"))==OK,"save source dialogue comparison")

func specimen(output: String) -> void:
	# Draw on an empty backdrop so an invisible renderer cannot pass by showing
	# the original framebuffer. An independent contour oracle supplies expectations.
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
		for run in lettering.runs:
			check(run.outline_font is Font,"specimen uses real outline face")
			var box: Rect2=Rect2(run.rect.position*factor,run.rect.size*factor)
			for y in range(ceili(box.position.y),floori(box.end.y)):
				for x in range(ceili(box.position.x),floori(box.end.x)):
					check(outlines.matches(result.get_pixel(x,y),run,Vector2(x+0.5,y+0.5)/factor,Vector2(factor,factor)),"native outline fidelity at scale "+str(factor))
		result.save_png(output.path_join("four-outline-faces-"+str(factor)+"x.png"))
	lettering.free()
	backdrop.free()
	view.show()
	viewport.size=Vector2i(1280,800)
	view.size=viewport.size
