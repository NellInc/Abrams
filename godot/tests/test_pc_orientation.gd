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

func grid_spans() -> void:
	# Horizontal calls end inclusively at box.end.x-1; vertical calls exclude box.end.y.
	for station in [0,1]:
		check(bind(synthetic(station)),"grid span fixture "+str(station))
		var panel: Control = instruments.orientation
		for line in panel.packet.grid:
			var p: Array = line.points
			var span: PackedVector2Array = panel._grid_span(p)
			var local := Vector2(p[0],p[1])-Vector2(panel.source_rect.position)+Vector2(0.5,0.5)
			var expected := [Vector2(0,local.y),Vector2(62,local.y)] if p[1]==p[3] else [Vector2(local.x,0),Vector2(local.x,44)]
			check(span[0].is_equal_approx(expected[0]) and span[1].is_equal_approx(expected[1]),"grid stroke span follows original endpoints %s"%[p])

# Frozen pre-optimization predicate, independent of the packed-byte path.
func original_guard(source: Image, ui: Image, tags: Image, original: Image, guard: Rect2i, box: Rect2i, plate: int) -> bool:
	for y in range(guard.position.y,guard.end.y):
		for x in range(guard.position.x,guard.end.x):
			if ui.get_pixel(x,y).r!=1.0: return false
			if box.has_point(Vector2i(x,y)):
				if tags.get_pixel(x,y).r!=0.0: return false
			elif roundi(tags.get_pixel(x,y).r*255)!=plate or source.get_pixel(x,y).to_rgba32()!=original.get_pixel(x,y).to_rgba32(): return false
	return true

func guard_parity() -> void:
	for station in [0,1]:
		var images := synthetic(station)
		var box := Rect2i(images[3].rect[0],images[3].rect[1],62,44)
		var guard := Rect2i(126,136,67,47) if station==0 else Rect2i(214,81,66,49)
		for format in [Image.FORMAT_RGB8,Image.FORMAT_RGBA8,Image.FORMAT_RGBAF]:
			for mask_format in [Image.FORMAT_L8,Image.FORMAT_RGB8,Image.FORMAT_RGBAF]:
				var source: Image = images[0].duplicate()
				var ui: Image = images[1].duplicate()
				var tags: Image = images[2].duplicate()
				var original: Image = instruments.plates[station+1].duplicate()
				source.convert(format)
				ui.convert(mask_format)
				tags.convert(mask_format)
				# Deliberately retain the donor's different byte format.
				for fault in ["valid","ui_first","ui_last","ui_inner","tag_inner","tag_top","tag_bottom","tag_left","tag_right","source_top","source_bottom","source_left","source_right","alpha","ignored_inner","ignored_outside","mask_green","tiny_inner_tag"]:
					var a := source.duplicate()
					var u := ui.duplicate()
					var t := tags.duplicate()
					var top := guard.position
					var bottom := guard.end-Vector2i.ONE
					var left := Vector2i(guard.position.x,box.position.y+10)
					var right := Vector2i(guard.end.x-1,box.position.y+10)
					match fault:
						"ui_first": u.set_pixelv(top,Color.BLACK)
						"ui_last": u.set_pixelv(bottom,Color.BLACK)
						"ui_inner": u.set_pixelv(box.position,Color.BLACK)
						"tag_inner": t.set_pixelv(box.position,Color.WHITE)
						"tag_top": t.set_pixelv(top,Color.BLACK)
						"tag_bottom": t.set_pixelv(bottom,Color.BLACK)
						"tag_left": t.set_pixelv(left,Color.BLACK)
						"tag_right": t.set_pixelv(right,Color.BLACK)
						"source_top": a.set_pixelv(top,Color.MAGENTA)
						"source_bottom": a.set_pixelv(bottom,Color.MAGENTA)
						"source_left": a.set_pixelv(left,Color.MAGENTA)
						"source_right": a.set_pixelv(right,Color.MAGENTA)
						"alpha":
							var color: Color = a.get_pixelv(top)
							color.a=0.4
							a.set_pixelv(top,color)
						"ignored_inner": a.set_pixelv(box.position,Color.MAGENTA)
						"ignored_outside": a.set_pixel(0,0,Color.MAGENTA)
						"mask_green":
							if mask_format!=Image.FORMAT_L8: u.set_pixelv(top,Color(1,0,0))
						"tiny_inner_tag": t.set_pixelv(box.position,Color(0.0001,0,0))
					var expected := original_guard(a,u,t,original,guard,box,station+1)
					check(Orientation._guard_matches(a,u,t,original,guard,box,station+1)==expected,"guard predicate parity %s/%s/%s/%s"%[station,format,mask_format,fault])
		# A repeated identical packet must not conceal subsequent provenance loss.
		check(bind(images),"valid repeated before mutation")
		images[1].set_pixelv(guard.end-Vector2i.ONE,Color.BLACK)
		check(not bind(images),"current image mutation never uses stale validity")

func report_at(path: String, field: String) -> Variant:
	var report = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	check(report is Dictionary and report.get(field) is Array,"unreadable report "+path)
	return report if report is Dictionary and report.get(field) is Array else null

func arg_value(args: PackedStringArray, flag: String) -> String:
	var index := args.find(flag)
	if index<0: return ""
	var ok := index+1<args.size() and not args[index+1].begins_with("--")
	check(ok,"missing value for "+flag)
	return args[index+1] if ok else ""

func oracle(path: String) -> void:
	var report = report_at(path,"cases")
	if report==null: return
	check(report.case_count==1024,"full original CPU sweep")
	for item in report.cases:
		var pixels: PackedByteArray = item.pixels_hex.hex_decode()
		check(bind(fixture(item.presentation,pixels)),"original CPU case %s/%s/%s"%[item.station,item.theme,item.heading])
		if not instruments.orientation.packet.is_empty():
			check(instruments.orientation.packet.quads==item.presentation.quads,"source geometry and damage colours retained")
			# Each grid stroke's end cells are lit in the original, and the original
			# lit run does not continue past either end inside the 62x44 box.
			for line in instruments.orientation.packet.grid:
				var span: PackedVector2Array = instruments.orientation._grid_span(line.points)
				var step := (span[1]-span[0]).normalized()*0.5
				for end in [[span[0]+step,span[0]-step],[span[1]-step,span[1]+step]]:
					var inside := Vector2i(end[0].floor())
					var beyond := Vector2i(end[1].floor())
					check(pixels[inside.y*62+inside.x]==8,"grid stroke end matches original pixel %s"%[line.points])
					check(not Rect2i(0,0,62,44).has_point(beyond) or pixels[beyond.y*62+beyond.x]!=8,"grid stroke stops short of original pixel %s"%[line.points])

func capture(viewport: SubViewport) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()

func native(path: String, output: String, oracle_path: String) -> void:
	var report = report_at(path,"ui_presentations")
	if report==null: return
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
	var cases = null if oracle_path.is_empty() else report_at(oracle_path,"cases")
	if cases!=null:
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
			# Horizontal grid calls light the final source column (61) to the edge.
			for line in images[3].grid:
				if line.points[1]!=line.points[3]: continue
				var at: Color = picture.get_pixel(160+61*12+6,80+(int(line.points[1])-int(images[3].rect[1]))*12+6)
				check(at.g>0.5 and at.r<0.2 and at.b<0.2,"horizontal grid reaches final source column %d"%index)
	check(coverage.size()==2,"both live stations rendered")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"coverage":coverage,"all_pixels_compared":compared,"samples":samples},"  "))

func run() -> void:
	repo = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	instruments = Instruments.new()
	root.add_child(instruments)
	check(instruments.load_sources(repo,Image.load_from_file(repo.path_join("local-art/genesis/cockpit-v2/gunner-genesis-v1.png"))),"original and Genesis sources loaded")
	corruption()
	grid_spans()
	guard_parity()
	var args := OS.get_cmdline_user_args()
	var oracle_path := arg_value(args,"--oracle")
	if not oracle_path.is_empty(): oracle(oracle_path)
	if "--native" in args:
		var fixture_path := arg_value(args,"--fixture")
		var output := arg_value(args,"--output")
		check(not fixture_path.is_empty() and not output.is_empty(),"native run needs --fixture and --output")
		if not fixture_path.is_empty() and not output.is_empty(): await native(fixture_path,output,oracle_path)
	for error in errors: printerr("FAIL: "+error)
	print("PC_ORIENTATION: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
