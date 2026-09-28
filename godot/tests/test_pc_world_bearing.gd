extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var checks := 0
var repo: String
var frame: TextureRect
var viewport: SubViewport
var font: PackedByteArray
var outlines = preload("res://tests/pc_outline_oracle.gd").new()
var compared := 0
var samples := []

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(why)
func _initialize() -> void: run.call_deferred()
func digest(image: Image) -> String:
	var copy := image.duplicate()
	copy.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(copy.get_data())
	return hash.finish().hex_encode()
func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func glyph(words: String, source: Image, mask: Image, x: int, y: int, fg: int) -> Dictionary:
	var box := Rect2i(x,y,words.length()*6,6)
	for i in words.length():
		for dy in 6:
			for dx in 6:
				var bit: int = int(font[4+(words.unicode_at(i)-32)*6+dy])&(128>>dx)
				mask.set_pixel(x+i*6+dx,y+dy,Color.WHITE if bit else Color.BLACK)
				if bit: source.set_pixel(x+i*6+dx,y+dy,Color.WHITE if fg==1 else Color.BLACK)
	return {"text":words,"rect":[x,y,words.length()*6,6],"cell_size":[6,6],"font_sha256":"a1ab3119ad84f1debb4fda3a57271e08ed9f0bdf1e535a5885a92758e07d5840",
		"foreground":fg,"uniform_background_rgb":null,"transparent":true,"return_ip":0x5764 if words=="BEARING" else 0x57a2,
		"page_offset":0,"pixel_sha256":digest(source.get_region(box))}
func pattern(width: int, height: int) -> Image:
	var im := Image.create_empty(width,height,false,Image.FORMAT_RGB8)
	for y in height:
		for x in width: im.set_pixel(x,y,Color8(50+(x/7)%160,50+(y/5)%160,80+(x+y)%100))
	return im
func fixture(bearing := "280", fg := 0, y := 17) -> Array:
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color8(90,110,130))
	# Source background deliberately varies inside each glyph's counters.
	for py in range(y,y+6):
		for x in range(128,191): source.set_pixel(x,py,Color8(40+x%170,70+py,100+x%100))
	var mask := Image.create_empty(320,200,false,Image.FORMAT_L8)
	mask.fill(Color.WHITE)
	for py in range(13,110):
		for x in range(32,288): mask.set_pixel(x,py,Color.BLACK)
	var runs := [glyph("BEARING",source,mask,128,y,fg),glyph(bearing,source,mask,173,y,fg)]
	return [source,mask,{"draw_pass":{"camera":{"clip":[32,10,287,109]}},"palette_rgb":Frame.ART_PALETTE,
		"page_offset":0,"text_runs":runs,"ui_overlay":{"width":320,"height":200}}]
func bind(data: Array, world: Texture2D) -> bool:
	data[2].ui_overlay.mask_png = Marshalls.raw_to_base64(data[1].save_png_to_buffer())
	return frame.set_frame(data[0],data[2],world)
func bearings() -> Array: return frame.typography.runs.filter(func(r):return r.get("transparent_world",false))
func contracts() -> void:
	var world := ImageTexture.create_from_image(pattern(256,100))
	for value in 360:
		var data := fixture("%03d"%value, value%2,12 if value%2 else 17)
		check(bind(data,world) and bearings().size()==2,"bearing numeric source %03d"%value)
	var data := fixture()
	data[2] = JSON.parse_string(JSON.stringify(data[2]))
	check(bind(data,world) and bearings().size()==2,"JSON integral values accepted")
	for field in ["text","rect","cell_size","font_sha256","foreground","transparent","return_ip","page_offset","pixel_sha256"]:
		data=fixture();data[2].text_runs[1].erase(field)
		check(bind(data,world) and bearings().size()==1,"missing field rejected "+field)
	for fault in ["source_ink","source_background","ui_ink","ui_background","hash","caller","page","camera","string","font","outlines","unobserved"]:
		data=fixture()
		var run: Dictionary = data[2].text_runs[1]
		match fault:
			"source_ink": data[0].set_pixel(173,17,Color.MAGENTA)
			"source_background": data[0].set_pixel(190,22,Color.MAGENTA)
			"ui_ink": data[1].set_pixel(173,17,Color.BLACK)
			"ui_background": data[1].set_pixel(190,22,Color.WHITE)
			"hash": run.pixel_sha256="bad"
			"caller": run.return_ip=0x55df
			"page": run.page_offset=8192
			"camera": data[2].draw_pass.camera.clip=[32,13,172,109]
			"string": run.text="999"
			"font": run.font_sha256=frame.typography.FONT_SOURCES["8X6.FNT"]
			"outlines": frame.typography.outline_fonts.fonts.clear()
			"unobserved": data[2].text_runs=[]
		bind(data,world)
		check(bearings().all(func(r):return r.text=="BEARING"),"invalid digits rejected "+fault)
		if fault=="outlines": frame.typography.load_sources(repo.path_join("GAME"))
	data=fixture();bind(data,world)
	check(not frame.typography.world_ink.is_empty(),"original glyph removal present")
	data[2].text_runs=[];bind(data,world)
	check(frame.typography.world_ink.is_empty(),"missing text clears removal mask")
	var shader_mask: Image = frame.material.get_shader_parameter("ui_mask").get_image()
	check(shader_mask.get_data()==data[1].get_data(),"missing text restores original full UI mask")
	data=fixture();bind(data,world)
	check(not frame.set_frame(data[0],{},world) and frame.typography.world_ink.is_empty() and bearings().is_empty(),"fallback clears text and removal")

func verify_native(data: Array, stage: String, scale: int, output: String, save: bool) -> void:
	var c: Array = data[2].draw_pass.camera.clip
	var box := Rect2i(c[0],c[1],c[2]-c[0]+1,c[3]-c[1]+1)
	var backdrop := pattern(box.size.x*scale,box.size.y*scale)
	var world := ImageTexture.create_from_image(backdrop)
	viewport.size = Vector2i(320,200)*scale
	frame.size = viewport.size
	check(bind(data,world),"paired native world "+stage)
	var runs := bearings().duplicate(true)
	check(runs.size()==2,"both bearing source calls native "+stage)
	var after := await capture()
	var without: Array = [data[0],data[1],data[2].duplicate(true)]
	without[2].text_runs = without[2].text_runs.filter(func(r):return int(r.get("return_ip",0)) not in [0x5764,0x57a2])
	check(bind(without,world),"native baseline without replacement")
	var before := await capture()
	var changed := 0
	for y in viewport.size.y:
		for x in viewport.size.x:
			var p := Vector2(x+0.5,y+0.5)/scale
			var inside: Array = runs.filter(func(r):return r.rect.has_point(p))
			compared+=1
			var actual := after.get_pixel(x,y)
			if inside.is_empty():
				if actual.to_rgba32()!=before.get_pixel(x,y).to_rgba32(): check(false,"world lettering changed unrelated pixel "+stage)
			else:
				var run: Dictionary = inside[0].duplicate()
				run.background=backdrop.get_pixel(x-box.position.x*scale,y-box.position.y*scale)
				check(outlines.matches(actual,run,p,Vector2(scale,scale)),"transparent original-style contour over moving scenery "+stage)
				if actual.to_rgba32()!=before.get_pixel(x,y).to_rgba32():changed+=1
	check(changed>100,"native bearing removed source ink and draws polished outlines "+stage)
	if save: after.save_png(output.path_join(stage+"-%dx.png"%scale))
	samples.append({"stage":stage,"scale":scale,"labels":runs.map(func(r):return r.text),"changed_pixels":changed})

func run() -> void:
	repo=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	font=FileAccess.get_file_as_bytes(repo.path_join("GAME/6X6.FNT"))
	outlines.load_sources(repo)
	viewport=SubViewport.new();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);frame=Frame.new();viewport.add_child(frame)
	check(frame.typography.load_sources(repo.path_join("GAME")),"pinned original faces")
	contracts()
	var args:=OS.get_cmdline_user_args()
	if "--native" in args:
		var output: String = args[args.find("--output")+1]
		DirAccess.make_dir_recursive_absolute(output)
		var path: String = args[args.find("--fixture")+1]
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		for scale in [4,6]:
			for fg in [0,1]: await verify_native(fixture("280",fg),"synthetic-"+str(fg),scale,output,true)
			for entry in report.ui_presentations:
				var packet: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
				packet.draw_pass=report.render_passes.filter(func(p):return p.sequence==entry.draw_sequence)[0]
				var source:=Image.load_from_file(path.get_base_dir().path_join(entry.image))
				var mask:=Image.load_from_file(path.get_base_dir().path_join(entry.mask))
				await verify_native([source,mask,packet],entry.stage,scale,output,entry.stage in ["gunner-settled","turret-right","commander-settled"])
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"all_pixels_compared":compared,"samples":samples},"  "))
	for error in errors: printerr("FAIL: "+error)
	print("PC_WORLD_BEARING: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
