extends SceneTree
const Instruments = preload("res://scripts/pc_instrument_art.gd")
const Orientation = preload("res://scripts/pc_orientation_art.gd")
const Frame = preload("res://scripts/pc_tandem_frame.gd")
var errors: Array[String] = []
var checks := 0
var repo: String
var instruments: Control

func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(why)

func _initialize() -> void: run.call_deferred()

func fixture(item: Dictionary, pixels: PackedByteArray) -> Array:
	var p: Dictionary = item.duplicate(true)
	var station: int = p.station
	var source: Image = instruments.plates[station+1].duplicate()
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
	tags.fill(Color(float(station+1)/255.0,0,0))
	var box := Rect2i(p.rect[0],p.rect[1],p.rect[2],p.rect[3])
	for y in box.size.y:
		for x in box.size.x:
			source.set_pixel(x+box.position.x,y+box.position.y,Orientation.PALETTE[pixels[y*62+x]])
			tags.set_pixel(x+box.position.x,y+box.position.y,Color.BLACK)
	var crop := source.get_region(box)
	crop.convert(Image.FORMAT_RGB8)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(crop.get_data())
	p.pixel_sha256 = hash.finish().hex_encode()
	return [source,ui,tags,p]

func bind(images: Array) -> bool:
	instruments.set_frame(images[0],images[1],images[2],images[3])
	return not instruments.orientation.packet.is_empty()

func synthetic(station: int) -> Array:
	# Constructed protocol fixture. Original raster coverage is tested separately.
	var x := 128 if station==0 else 216
	var y := 137 if station==0 else 83
	var p := {"schema":1,"source_sha256":Orientation.SIM_SHA,"station":station,"page_offset":0,
		"rect":[x,y,62,44],"grid":[],"quads":[]}
	for i in range(4): p.grid.append({"points":[x+i*16,y,x+i*16,y+44],"color":8})
	for i in range(3): p.grid.append({"points":[x,y+i*16,x+61,y+i*16],"color":8})
	for i in range(4):
		var length := 16 if i<2 else 8
		var width := 10 if i<2 else 6
		var q := {"basis":[0,width*16384,length*16384,0,0,0],"points":[],"vertices_q14":[],
			"fill":0,"filled":true,"border":1 if i<2 else 2,"edges":[2,8,10,6] if i==2 else []}
		for signs in [Vector2i(1,1),Vector2i(-1,1),Vector2i(-1,-1),Vector2i(1,-1)]:
			q.points.append([x+32+signs.y*width,y+21-signs.x*length])
			q.vertices_q14.append([q.points[-1][0]*16384,q.points[-1][1]*16384])
		p.quads.append(q)
	var pixels := PackedByteArray()
	pixels.resize(62*44)
	return fixture(p,pixels)

func corruption() -> void:
	for station in [0,1]:
		check(bind(synthetic(station)),"constructed supported station "+str(station))
		var roundtrip := synthetic(station)
		roundtrip[3] = JSON.parse_string(JSON.stringify(roundtrip[3]))
		check(bind(roundtrip),"JSON numeric transport accepted "+str(station))
		for field in ["schema","source_sha256","pixel_sha256","page_offset","station","rect","grid","quads"]:
			var images := synthetic(station)
			images[3].erase(field)
			check(not bind(images),"missing field clears previous "+field)
		for fault in ["pixel","last_pixel","ui","tag","guard","guard_ui","guard_tag","basis","vertex","point","color","fill","filled","edges","grid_end"]:
			var images := synthetic(station)
			var p: Dictionary = images[3]
			var a := Vector2i(p.rect[0],p.rect[1])
			var g := a-Vector2i.ONE
			match fault:
				"pixel": images[0].set_pixelv(a,Color.MAGENTA)
				"last_pixel": images[0].set_pixelv(a+Vector2i(61,43),Color.MAGENTA)
				"ui": images[1].set_pixelv(a,Color.BLACK)
				"tag": images[2].set_pixelv(a,Color.WHITE)
				"guard": images[0].set_pixelv(g,Color.MAGENTA)
				"guard_ui": images[1].set_pixelv(g,Color.BLACK)
				"guard_tag": images[2].set_pixelv(g,Color.BLACK)
				"basis": p.quads[0].basis[0]+=1
				"vertex": p.quads[0].vertices_q14[0][0]+=1
				"point": p.quads[0].points[0][0]+=1
				"color": p.quads[0].border=16
				"fill": p.quads[0].fill=1
				"filled": p.quads[0].filled="true"
				"edges": p.quads[0].edges=[1,2,3,4]
				"grid_end": p.grid[0].points[3]-=1
			check(not bind(images),"corruption rejected "+fault)
	check(bind(synthetic(0)),"valid before clear")
	instruments.clear()
	check(instruments.orientation.packet.is_empty() and not instruments.orientation.visible,"fallback clears diagram")

func oracle(path: String) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report.case_count==1024,"full original CPU sweep")
	for item in report.cases:
		check(bind(fixture(item.presentation,item.pixels_hex.hex_decode())),"original CPU case %s/%s/%s"%[item.station,item.theme,item.heading])
		if not instruments.orientation.packet.is_empty():
			check(instruments.orientation.packet.quads==item.presentation.quads,"source geometry and damage colours retained")

func capture(viewport: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func native(path: String, output: String, oracle_path: String) -> void:
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var frame := Frame.new()
	viewport.add_child(frame)
	check(frame.load_genesis_art(repo),"native Genesis set")
	check(frame.typography.load_sources(repo.path_join("GAME")),"native original typography")
	var compared := 0
	var samples := []
	var coverage := {}
	for scale in [4,6]:
		viewport.size = Vector2i(320,200)*scale
		frame.size = Vector2(320,200)*scale
		for entry in report.ui_presentations:
			var p: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
			p.draw_pass = report.render_passes.filter(func(v):return v.sequence==entry.draw_sequence)[0]
			var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
			var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
			var tags := Image.load_from_file(path.get_base_dir().path_join(entry.plate_mask))
			p.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
			p.plate_overlay.mask_png = Marshalls.raw_to_base64(tags.save_png_to_buffer())
			var c: Array = p.draw_pass.camera.clip
			var world := ImageTexture.create_from_image(source.get_region(Rect2i(c[0],c[1],c[2]-c[0]+1,c[3]-c[1]+1)))
			check(frame.set_frame(source,p,world),"live frame accepted "+entry.stage)
			var panel: Control = frame.instrument_art.orientation
			var box: Rect2i = panel.source_rect
			var expected: bool = int(p.orientation.station)+1 in frame.cockpit_art_ids
			check(panel.packet.is_empty()!=expected,"live orientation follows plate provenance "+entry.stage)
			var after := await capture(viewport)
			panel.hide()
			var before := await capture(viewport)
			var changed := 0
			compared += viewport.size.x*viewport.size.y
			for y in viewport.size.y:
				for x in viewport.size.x:
					if before.get_pixel(x,y).to_rgba32()==after.get_pixel(x,y).to_rgba32(): continue
					changed += 1
					check(box.has_point(Vector2i(x/scale,y/scale)),"drawing escaped source rectangle "+entry.stage)
			check(changed>100 if expected else changed==0,"native replacement or original fallback "+entry.stage)
			if expected: coverage[str(p.orientation.station)] = coverage.get(str(p.orientation.station),0)+1
			if entry.stage in ["gunner-settled","commander-stopped","turret-right","turret-left"]:
				after.save_png(output.path_join("%s-%dx.png"%[entry.stage,scale]))
			samples.append({"stage":entry.stage,"scale":scale,"changed_pixels":changed})
			if entry.stage=="gunner-settled":
				var wrong: Dictionary = p.duplicate(true)
				wrong.palette_rgb[8][1]=169
				check(frame.set_frame(source,wrong,world) and panel.packet.is_empty(),"unsupported palette clears orientation")
				check(not frame.set_frame(source,{},world) and panel.packet.is_empty(),"fallback clears orientation")
	# Source CPU cases demonstrate warning-edge variants and outline-only mode.
	if not oracle_path.is_empty():
		var cases: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(oracle_path))
		viewport.size = Vector2i(1280,800)
		frame.hide()
		var panel: Control = Orientation.new()
		viewport.add_child(panel)
		for index in [0,1,2,32,255,256,513,770]:
			var item: Dictionary = cases.cases[index]
			var images := fixture(item.presentation,item.pixels_hex.hex_decode())
			check(panel.set_frame(images[0],images[1],images[2],instruments.plates,images[3]),"original CPU native variant")
			panel.position = Vector2(160,80)
			panel.size = Vector2(62,44)*12
			var picture := await capture(viewport)
			picture.save_png(output.path_join("cpu-variant-%04d.png"%index))
	check(coverage.size()==2,"both live stations rendered")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"coverage":coverage,"all_pixels_compared":compared,"samples":samples},"  "))

func run() -> void:
	repo = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	instruments = Instruments.new()
	root.add_child(instruments)
	check(instruments.load_sources(repo,Image.load_from_file(repo.path_join("local-art/genesis/cockpit-v2/gunner-genesis-v1.png"))),"original and Genesis sources loaded")
	corruption()
	var args := OS.get_cmdline_user_args()
	var oracle_path := args[args.find("--oracle")+1] if "--oracle" in args else ""
	if not oracle_path.is_empty(): oracle(oracle_path)
	if "--native" in args: await native(args[args.find("--fixture")+1],args[args.find("--output")+1],oracle_path)
	for error in errors: printerr("FAIL: "+error)
	print("PC_ORIENTATION: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
