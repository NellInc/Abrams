extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Reticle = preload("res://scripts/pc_reticle_target_art.gd")
var frame: TextureRect
var viewport: SubViewport
var checks := 0
var compared := 0
var errors: Array[String] = []
var samples := []

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(why)
func _initialize() -> void: run.call_deferred()
func digest(im: Image) -> String:
	var rgb := im.duplicate()
	rgb.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(rgb.get_data())
	return hash.finish().hex_encode()
func fixture(center := Vector2i(159,60), color := 0) -> Array:
	var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color8(90,110,130))
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	for y in range(13,110):
		for x in range(32,288): ui.set_pixel(x,y,Color.BLACK)
	for box in Reticle.target_geometry(center.x,center.y):
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				source.set_pixel(x,y,Color.BLACK if color==0 else Color.WHITE)
				ui.set_pixel(x,y,Color.WHITE)
	var item := {"schema":1,"source_sha256":Reticle.SIM_SHA,
		"page_offset":0,"rect":[32,13,256,97],"center":[center.x,center.y],"color":color,
		"lines":Reticle.target_lines(center.x,center.y),"pixel_sha256":digest(source.get_region(Reticle.TARGET_BOX))}
	return [source,ui,{"page_offset":0,"target_box":item,"palette_rgb":Frame.ART_PALETTE,
		"draw_pass":{"camera":{"clip":[32,13,287,109]}},"ui_overlay":{"width":320,"height":200}}]
func bind(data: Array, world: Texture2D) -> bool:
	data[2].ui_overlay.mask_png=Marshalls.raw_to_base64(data[1].save_png_to_buffer())
	return frame.set_frame(data[0],data[2],world)
func capture() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func contracts() -> void:
	var world := ImageTexture.create_from_image(fixture()[0])
	var data := fixture()
	data[2]=JSON.parse_string(JSON.stringify(data[2]))
	check(bind(data,world) and frame.target_box_art.ink.size()==40,"JSON target retains original 40-pixel box")
	for field in ["schema","source_sha256","page_offset","rect","center","color","lines","pixel_sha256"]:
		data=fixture();data[2].target_box.erase(field);bind(data,world)
		check(frame.target_box_art.packet.is_empty(),"missing field fails closed: "+field)
	for fault in ["ink","ink_color","ink_color_white","background","ownership","line","page","palette","camera","fraction","color","hash"]:
		data=fixture()
		match fault:
			# Re-hash so the declared-colour ink guard, not the crop hash, must reject these.
			"ink":
				data[0].set_pixel(154,55,Color.MAGENTA)
				data[2].target_box.pixel_sha256=digest(data[0].get_region(Reticle.TARGET_BOX))
			"ink_color": data[2].target_box.color=1
			"ink_color_white":
				data=fixture(Vector2i(159,60),1)
				data[2].target_box.color=0
			"background": data[0].set_pixel(32,13,Color.MAGENTA)
			"ownership": data[1].set_pixel(154,55,Color.BLACK)
			"line": data[2].target_box.lines[0][0]+=1
			"page": data[2].target_box.page_offset=8192
			"palette": data[2].palette_rgb=[]
			"camera": data[2].draw_pass.camera.clip[1]=12
			"fraction": data[2].target_box.center[0]=159.5
			"color": data[2].target_box.color=2
			"hash": data[2].target_box.pixel_sha256="bad"
		bind(data,world)
		check(frame.target_box_art.ink.is_empty(),"unsafe target preserves original: "+fault)
	data=fixture(Vector2i(159,60),1)
	check(bind(data,world) and frame.target_box_art.ink.size()==40,"white original target binds when declared white")
	data=fixture();bind(data,world)
	check(not frame.target_box_art.ink.is_empty(),"visible target before clear")
	data[2].erase("target_box");bind(data,world)
	var mask: Image=frame.material.get_shader_parameter("ui_mask").get_image()
	check(frame.target_box_art.ink.is_empty() and mask.get_data()==data[1].get_data(),"absent target restores original mask")
	data=fixture();bind(data,world)
	check(not frame.set_frame(data[0],{},world) and frame.target_box_art.ink.is_empty(),"fallback clears target")

func native(data: Array, name: String, output: String) -> void:
	var backdrop := Image.create_empty(256,97,false,Image.FORMAT_RGB8)
	# Deliberately unrelated to the low-res frame: uncovered ink must reveal
	# this scanout-paired world rather than smearing source scenery around it.
	for y in 97:
		for x in 256: backdrop.set_pixel(x,y,Color8(30+x%190,45+y%160,50+(x+y)%170))
	var world := ImageTexture.create_from_image(backdrop)
	for extent: Vector2i in [Vector2i(1280,800),Vector2i(1728,1080),Vector2i(1920,1200)]:
		viewport.size=extent;frame.size=extent
		check(bind(data,world),"native source accepted "+name)
		var ink := {}
		for point in frame.target_box_art.ink: ink[point]=true
		var boxes: Array = frame.target_box_art.rectangles.duplicate()
		var color := Color.BLACK if data[2].target_box.color==0 else Color.WHITE
		check(not ink.is_empty(),"native reticle bound "+name)
		var after := await capture()
		var disabled: Array=[data[0],data[1],data[2].duplicate(true)]
		disabled[2].erase("target_box");bind(disabled,world)
		var before := await capture()
		var scale := Vector2(extent)/Vector2(320,200)
		var changed := 0
		var outside := 0
		var failures := 0
		for y in extent.y:
			for x in extent.x:
				var p := (Vector2(x,y)+Vector2(0.5,0.5))/scale
				var pixel := Vector2i(p.floor())
				var same := after.get_pixel(x,y).to_rgba32()==before.get_pixel(x,y).to_rgba32()
				compared+=1
				if pixel not in ink:
					if not same: outside+=1
					continue
				var alpha := 0.0
				var footprint := Vector2.ONE/scale
				for rect: Rect2i in boxes:
					var low: Vector2=(p-footprint/2).max(Vector2(rect.position))
					var high: Vector2=(p+footprint/2).min(Vector2(rect.end))
					var coverage: Vector2=((high-low)/footprint).clamp(Vector2.ZERO,Vector2.ONE)
					alpha=maxf(alpha,coverage.x*coverage.y)
				var bg := backdrop.get_pixel(pixel.x-32,pixel.y-13)
				var expected := bg.lerp(color,alpha)
				var actual := after.get_pixel(x,y)
				if absf(actual.r-expected.r)>3.0/255 or absf(actual.g-expected.g)>3.0/255 or absf(actual.b-expected.b)>3.0/255: failures+=1
				if not same: changed+=1
		check(outside==0,"no repaint outside original reticle ink %s %s: %d"%[name,extent,outside])
		check(failures==0,"analytic original stroke coverage %s %s: %d"%[name,extent,failures])
		check(extent.x==1728 or changed==0,"integer pixel parity %s %s: %d"%[name,extent,changed])
		after.save_png(output.path_join("%s-%d.png"%[name,extent.x]))
		samples.append({"stage":name,"size":[extent.x,extent.y],"changed":changed,"outside":outside,"sampling_failures":failures})

func run() -> void:
	viewport=SubViewport.new();viewport.size=Vector2i(1280,800)
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	frame=Frame.new();frame.size=viewport.size;viewport.add_child(frame)
	contracts()
	var args:=OS.get_cmdline_user_args()
	var oi:=args.find("--oracle")
	if oi>=0 and oi+1<args.size():
		var report=JSON.parse_string(FileAccess.get_file_as_string(args[oi+1]))
		check(report is Dictionary and report.get("cases") is Array,"CPU oracle present")
		if report is Dictionary and report.get("cases") is Array:
			for item in report.cases+report.get("raster_cases",[]):
				var expected := {}
				for p in item.ink_pixels: expected[Vector2i(p[0],p[1])]=true
				var actual := {}
				for box in Reticle.target_geometry(int(item.center[0]),int(item.center[1])):
					for y in range(box.position.y,box.end.y):
						for x in range(box.position.x,box.end.x): actual[Vector2i(x,y)]=true
				check(expected==actual,"geometry equals original CPU raster")
	if "--native" in args:
		var fi:=args.find("--fixture");var out:=args.find("--output")
		var valid:=fi>=0 and fi+1<args.size() and out>=0 and out+1<args.size()
		check(valid,"native arguments present")
		if valid:
			var path:=args[fi+1];var output:=args[out+1]
			DirAccess.make_dir_recursive_absolute(output)
			var report=JSON.parse_string(FileAccess.get_file_as_string(path))
			check(report is Dictionary and report.get("ui_presentations") is Array,"recorded fixture present")
			if report is Dictionary and report.get("ui_presentations") is Array:
				for entry in report.ui_presentations:
					if entry.stage not in ["selected","locked","zoom","thermal","thermal-off","next"]: continue
					var packet: Dictionary=report.presentations[int(entry.frame_index)].duplicate(true)
					packet.erase("reticle")
					if packet.get("target_box",{}).is_empty(): continue
					packet.draw_pass=report.render_passes.filter(func(p):return p.sequence==entry.draw_sequence)[0]
					var source:=Image.load_from_file(path.get_base_dir().path_join(entry.image))
					var ui:=Image.load_from_file(path.get_base_dir().path_join(entry.mask))
					await native([source,ui,packet],entry.stage,output)
			check(samples.size()>=9,"multiple live centres/modes rendered")
			for center in [Vector2i(32,13),Vector2i(287,109),Vector2i(27,60),Vector2i(159,114)]: await native(fixture(center,1),"isolated-clip-%d-%d"%[center.x,center.y],output)
			check(samples.any(func(s):return s.size[0]==1728 and s.changed>0),"fractional edges exercised where original ownership permits coverage")
			FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"compared_pixels":compared,"samples":samples},"  "))
	for error in errors: printerr("FAIL: "+error)
	print("PC_RETICLE_TARGET: %d checks, %d errors; %d full-frame pixels compared"%[checks,errors.size(),compared])
	quit(0 if errors.is_empty() else 1)
