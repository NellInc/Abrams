extends SceneTree
const Instruments = preload("res://scripts/pc_instrument_art.gd")
const Frame = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var checks := 0
var instruments: Control
var repo: String

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void: run.call_deferred()

func fixture(spec: Dictionary, lit: int, color := Color.BLACK) -> Array:
	var source: Image = instruments.plates[spec.plate].duplicate()
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
	tags.fill(Color(float(spec.plate)/255.0,0,0))
	if spec.has("count"):
		for i in spec.count:
			var value: Color = Instruments.INACTIVE if i>=lit else Instruments.RED if i<spec.red else Instruments.GREEN
			for y in range(186,192):
				var p := Vector2i(spec.source.position.x+i*2,y)
				source.set_pixelv(p,value)
				tags.set_pixelv(p,Color.BLACK)
	else:
		if spec.plate==4:
			for y in range(189,198):
				for x in range(233,253):
					source.set_pixel(x,y,Color8(85,85,255))
					tags.set_pixel(x,y,Color.BLACK)
		for y in range(spec.source.position.y,spec.source.end.y):
			for x in range(spec.source.position.x,spec.source.end.x):
				source.set_pixel(x,y,color)
				tags.set_pixel(x,y,Color.BLACK)
	return [source,ui,tags]

func bind(images: Array) -> void: instruments.set_frame(images[0],images[1],images[2])

func reject_corruption(spec: Dictionary) -> void:
	var p: Vector2i = spec.source.position
	var g: Vector2i = spec.guard.position
	for failure in ["pixel","partial","ownership","tag","guard_pixel","guard_ui","guard_tag"]:
		var images := fixture(spec,3,Instruments.RED if spec.has("lock") else Instruments.GREEN)
		match failure:
			"pixel": images[0].set_pixelv(p,Color.CYAN)
			"partial": images[0].set_pixelv(spec.source.end-Vector2i.ONE,Color.CYAN)
			"ownership": images[1].set_pixelv(p,Color.BLACK)
			"tag": images[2].set_pixelv(p,Color(float(spec.plate)/255.0,0,0))
			"guard_pixel": images[0].set_pixelv(g,Color.CYAN)
			"guard_ui": images[1].set_pixelv(g,Color.BLACK)
			"guard_tag": images[2].set_pixelv(g,Color.BLACK)
		bind(images)
		check(instruments.gauges.is_empty(),spec.name+" rejects "+failure)
	if not spec.has("count"): return
	for failure in ["gap_pixel","gap_ui","gap_tag","hole","wrong_threshold"]:
		var images := fixture(spec,6)
		var gap := p+Vector2i(1,0)
		match failure:
			"gap_pixel": images[0].set_pixelv(gap,Color.CYAN)
			"gap_ui": images[1].set_pixelv(gap,Color.BLACK)
			"gap_tag": images[2].set_pixelv(gap,Color.BLACK)
			"hole":
				for y in range(186,192): images[0].set_pixel(p.x+2,y,Instruments.INACTIVE)
			"wrong_threshold":
				for y in range(186,192): images[0].set_pixel(p.x+8,y,Instruments.RED)
		bind(images)
		check(instruments.gauges.is_empty(),spec.name+" rejects "+failure)

func run() -> void:
	repo = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	instruments = Instruments.new()
	root.add_child(instruments)
	check(instruments.load_sources(repo,Image.load_from_file(repo.path_join("local-art/genesis/cockpit-v2/gunner-genesis-v1.png"))),"source art loaded")
	region_checks()
	for spec in Instruments.BARS:
		for lit in range(spec.count+1):
			bind(fixture(spec,lit))
			check(instruments.gauges.size()==1 and instruments.gauges[0].name==spec.name,"one exact bar "+spec.name)
			if instruments.gauges.size()==1: check(instruments.gauges[0].lit==lit,"visible quantization "+spec.name)
		reject_corruption(spec)
	for spec in Instruments.LAMPS:
		for color in ([Instruments.RED,Color.BLACK] if spec.has("lock") else [Instruments.GREEN,Instruments.YELLOW,Instruments.RED,Color.BLACK]):
			bind(fixture(spec,0,color))
			check(instruments.gauges.size()==1 and instruments.gauges[0].color==color,"lamp colour and blink phase "+spec.name)
		reject_corruption(spec)
	var images := fixture(Instruments.BARS[0],5)
	bind(images)
	instruments.set_frame(images[0],null,images[2])
	check(instruments.gauges.is_empty(),"missing UI clears prior gauges")
	instruments.set_frame(images[0],images[1],Image.create_empty(1,1,false,Image.FORMAT_L8))
	check(instruments.gauges.is_empty(),"wrong dimensions rejected")
	var args := OS.get_cmdline_user_args()
	if "--oracle" in args: original_cases(args[args.find("--oracle")+1])
	if "--native" in args: await native(args[args.find("--fixture")+1],args[args.find("--output")+1])
	for error in errors: printerr("FAIL: "+error)
	print("PC_GAUGES: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func region_checks() -> void:
	# Independent pixel-loop oracle for all guard complements, including a guard
	# outside the dynamic cell (the driver lamp) and partial/whole intersections.
	var boxes: Array = Instruments.BARS+Instruments.LAMPS
	for inner in [Rect2i(0,0,20,20),Rect2i(2,2,3,3),Rect2i(0,0,3,3),Rect2i(8,8,4,4),Rect2i(20,20,1,1)]:
		boxes.append({"guard":Rect2i(1,1,9,9),"source":inner})
	for spec in boxes:
		var regions := Instruments._outside(spec.guard,spec.source)
		for y in range(spec.guard.position.y-1,spec.guard.end.y+1):
			for x in range(spec.guard.position.x-1,spec.guard.end.x+1):
				var p := Vector2i(x,y)
				var count := 0
				for box in regions:
					if box.has_point(p): count+=1
				check(count==int(spec.guard.has_point(p) and not spec.source.has_point(p)),"guard complement has every pixel exactly once")
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
	tags.fill(Color(1.0/255,0,0))
	var plate: Image=instruments.source_plate
	for cell in Instruments.CELLS:
		var box: Rect2i=cell.source
		check(Instruments._owned_region(ui,tags,box,1),"complete icon ownership")
		var changed: Image = plate.duplicate()
		check(Instruments._same_region(changed,plate,box),"exact original icon")
		# Every icon pixel is load bearing, including its edge and black pixels.
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				var old := changed.get_pixel(x,y)
				changed.set_pixel(x,y,Color(1.0-old.r,old.g,old.b,old.a))
				check(not Instruments._same_region(changed,plate,box),"one changed icon pixel rejects")
				changed.set_pixel(x,y,old)
				ui.set_pixel(x,y,Color.BLACK)
				check(not Instruments._owned_region(ui,tags,box,1),"one world-owned icon pixel rejects")
				ui.set_pixel(x,y,Color.WHITE)
				tags.set_pixel(x,y,Color.BLACK)
				check(not Instruments._owned_region(ui,tags,box,1),"one wrong plate pixel rejects")
				tags.set_pixel(x,y,Color(1.0/255,0,0))
		check(Instruments._same_region(changed,plate,box) and Instruments._owned_region(ui,tags,box,1),"restored source accepted without stale decision")
	var box: Rect2i=Instruments.CELLS[0].source
	# RGB/RGBA conversion preserves opaque bytes; alpha differences still reject.
	for a_format in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8,Image.FORMAT_RGBAF]:
		for b_format in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8,Image.FORMAT_RGBAF]:
			var a: Image = plate.duplicate()
			var b: Image = plate.duplicate()
			a.convert(a_format)
			b.convert(b_format)
			check(Instruments._same_region(a,b,box),"exact mixed-format pixels")
			var old := a.get_pixelv(box.position)
			a.set_pixelv(box.position,Color(1.0-old.r,old.g,old.b))
			check(not Instruments._same_region(a,b,box),"mixed-format changed pixel rejects")
	var alpha: Image = plate.duplicate()
	alpha.convert(Image.FORMAT_RGBA8)
	var old := alpha.get_pixelv(box.position)
	alpha.set_pixelv(box.position,Color(old.r,old.g,old.b,0.5))
	check(not Instruments._same_region(alpha,plate,box),"alpha is part of equality")
	for value in range(0,255):
		ui.set_pixelv(box.position,Color(float(value)/255,0,0))
		check(not Instruments._owned_region(ui,tags,box,1),"only fully UI-owned pixels qualify")
	ui.fill(Color.WHITE)
	for value in range(256):
		tags.set_pixelv(box.position,Color(float(value)/255,0,0))
		check(Instruments._owned_region(ui,tags,box,1)==(value==1),"exact plate tag byte")
	# Non-luminance masks retain the prior red-only semantics, never luminance.
	ui.convert(Image.FORMAT_RGBA8)
	tags.convert(Image.FORMAT_RGBA8)
	ui.fill(Color(1,0,0,0))
	tags.fill(Color(1.0/255,1,1,0))
	check(Instruments._owned_region(ui,tags,box,1),"non-L8 mask uses original red channel only")
	ui.set_pixelv(box.position,Color(0.99,1,1))
	check(not Instruments._owned_region(ui,tags,box,1),"non-L8 nonopaque ownership rejects")

func original_cases(path: String) -> void:
	if not FileAccess.file_exists(path):
		check(false,"original-instruction oracle file is missing: "+path)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		check(false,"original-instruction oracle is malformed")
		return
	var report: Dictionary = parsed
	check(report.case_count==1332,"complete original-instruction oracle")
	var checked := 0
	for item in report.cases:
		if item.mode!=16 or item.rectangles.is_empty(): continue
		var specs: Array = Instruments.BARS if item.kind in ["speed","fuel"] else Instruments.LAMPS
		var spec: Dictionary = specs.filter(func(s): return s.source.position==Vector2i(item.rectangles[0][0],item.rectangles[0][1]))[0]
		var images := fixture(spec,0)
		var lit := 0
		for rect in item.rectangles:
			var rgb: Array = Frame.ART_PALETTE[int(rect[4])]
			var color := Color8(rgb[0],rgb[1],rgb[2])
			if spec.has("count") and color!=Instruments.INACTIVE: lit += 1
			for y in range(rect[1],rect[1]+rect[3]):
				for x in range(rect[0],rect[0]+rect[2]): images[0].set_pixel(x,y,color)
		bind(images)
		check(instruments.gauges.size()==1,"original CPU pixels accepted: "+item.kind)
		if instruments.gauges.size()==1 and spec.has("count"): check(instruments.gauges[0].lit==lit,"exact CPU segment count")
		checked += 1
	check(checked==507,"all applicable original CPU cases, including overflow")

func capture(viewport: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func packet_for(images: Array) -> Dictionary:
	var plates := {}
	for id in Frame.COCKPIT_SOURCES:
		plates[str(id)] = {"source":Frame.COCKPIT_SOURCES[id][0],"source_sha256":Frame.COCKPIT_SOURCES[id][1]}
	return {"draw_pass":{"camera":{"clip":[0,0,319,135]}},"palette_rgb":Frame.ART_PALETTE,
		"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(images[1].save_png_to_buffer())},
		"plate_overlay":{"width":320,"height":200,"plates":plates,"mask_png":Marshalls.raw_to_base64(images[2].save_png_to_buffer())}}

func synthetic_native(viewport: SubViewport, frame: TextureRect, output: String, scale: int) -> void:
	# Original-instruction tests prove these warning colours; these constructed
	# presentation fixtures exercise drawing, not live warning reachability.
	for spec in Instruments.LAMPS:
		for color in ([Instruments.RED,Color.BLACK] if spec.has("lock") else [Instruments.GREEN,Instruments.YELLOW,Instruments.RED,Color.BLACK]):
			var images := fixture(spec,0,color)
			var packet := packet_for(images)
			var world := ImageTexture.create_from_image(images[0].get_region(Rect2i(0,0,320,136)))
			check(frame.set_frame(images[0],packet,world),"synthetic warning composes")
			var picture := await capture(viewport)
			check(frame.instrument_art.gauges.size()==1,"one synthetic warning lamp")
			check(picture.get_pixelv(spec.source.get_center()*scale).to_rgba32()==color.to_rgba32(),"native warning centre and off phase")
			if scale==6: picture.save_png(output.path_join("fixture-"+spec.name+"-"+color.to_html(false)+".png"))
	var images := fixture(Instruments.BARS[0],19)
	var packet := packet_for(images)
	var world := ImageTexture.create_from_image(images[0].get_region(Rect2i(0,0,320,136)))
	check(frame.set_frame(images[0],packet,world) and frame.instrument_art.gauges.size()==1,"valid integrated gauge")
	packet.palette_rgb = packet.palette_rgb.duplicate(true)
	packet.palette_rgb[8][1] = 169
	check(frame.set_frame(images[0],packet,world) and frame.instrument_art.gauges.is_empty(),"wrong palette clears integrated gauges")
	check(not frame.set_frame(images[0],{},world) and frame.instrument_art.gauges.is_empty(),"fallback clears integrated gauges")

func native(path: String, output: String) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var frame := Frame.new()
	viewport.add_child(frame)
	check(frame.load_genesis_art(repo),"native Genesis set")
	check(frame.typography.load_sources(repo.path_join("GAME")),"native original-style fonts")
	var samples := []
	var coverage := {}
	var compared := 0
	for scale in [4,6]:
		viewport.size = Vector2i(320,200)*scale
		frame.size = Vector2(320,200)*scale
		await synthetic_native(viewport,frame,output,scale)
		for entry in report.ui_presentations:
			var packet: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
			packet.draw_pass = report.render_passes.filter(func(p): return p.sequence==entry.draw_sequence)[0]
			var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
			var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
			var tags := Image.load_from_file(path.get_base_dir().path_join(entry.plate_mask))
			packet.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
			packet.plate_overlay.mask_png = Marshalls.raw_to_base64(tags.save_png_to_buffer())
			var c: Array = packet.draw_pass.camera.clip
			var world := ImageTexture.create_from_image(source.get_region(Rect2i(c[0],c[1],c[2]-c[0]+1,c[3]-c[1]+1)))
			check(frame.set_frame(source,packet,world),"recorded paired original frame "+entry.stage)
			var gauges: Array = frame.instrument_art.gauges.duplicate(true)
			var after := await capture(viewport)
			frame.instrument_art.gauges.clear()
			frame.instrument_art.queue_redraw()
			var before := await capture(viewport)
			var changed := 0
			compared += viewport.size.x*viewport.size.y
			for y in viewport.size.y:
				for x in viewport.size.x:
					if before.get_pixel(x,y).to_rgba32()==after.get_pixel(x,y).to_rgba32(): continue
					changed += 1
					check(gauges.any(func(g): return g.source.has_point(Vector2i(x/scale,y/scale))),"gauge painted outside verified bounds "+entry.stage)
			for gauge in gauges:
				coverage[gauge.name] = coverage.get(gauge.name,0)+1
				if gauge.kind=="bar":
					for i in gauge.count:
						var x: int = (gauge.source.position.x+2*i)*scale+scale/2
						check(after.get_pixel(x,189*scale).to_rgba32()==gauge.colors[i].to_rgba32(),"exact strip colour "+gauge.name)
				else:
					var p := Vector2i((Vector2(gauge.source.position)+Vector2(gauge.source.size)*0.5)*scale)
					check(after.get_pixelv(p).to_rgba32()==gauge.color.to_rgba32(),"exact lamp colour "+gauge.name)
			check(gauges.is_empty() or changed>0,"native gauge geometry is visible "+entry.stage)
			if entry.stage.ends_with("settled") or entry.stage=="gunner-restored":
				after.save_png(output.path_join("%s-%dx.png"%[entry.stage,scale]))
			samples.append({"stage":entry.stage,"scale":scale,"gauges":gauges.map(func(g): return g.name),"changed_pixels":changed})
	for spec in Instruments.BARS+Instruments.LAMPS: check(coverage.get(spec.name,0)>0,"recorded native coverage "+spec.name)
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"fixture_sha256":FileAccess.get_sha256(path),"checks":checks,"errors":errors,"coverage":coverage,"all_pixels_compared":compared,"samples":samples},"  "))
