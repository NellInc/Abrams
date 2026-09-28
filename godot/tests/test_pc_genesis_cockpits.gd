extends SceneTree
var outlines = preload("res://tests/pc_outline_oracle.gd").new()
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Instruments = preload("res://scripts/pc_instrument_art.gd")
var errors: Array[String] = []
var checks := 0
var viewport: SubViewport
var frame: TextureRect

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	outlines.load_sources(root_path)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	frame = Frame.new()
	frame.size = Vector2(1280,800)
	viewport.add_child(frame)
	check(frame.load_genesis_art(root_path),"verified Genesis set loaded")
	check(frame.genesis_art_enabled,"Genesis rendering profile selected")
	var source := Image.load_from_file(root_path.path_join("local-art/pc-ui-v2/gps-bin.png"))
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
	tags.fill(Color(1.0/255,0,0))
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	frame.instrument_art.set_frame(source,ui,tags)
	check(frame.instrument_art.active.size()==9,"all nine unchanged source instrument cells qualify")
	for kind in ["pixel","ownership","plate"]:
		var changed := source.duplicate()
		var mask := ui.duplicate()
		var ids := tags.duplicate()
		if kind=="pixel": changed.set_pixel(244,144,Color.MAGENTA)
		if kind=="ownership": mask.set_pixel(244,144,Color.BLACK)
		if kind=="plate": ids.set_pixel(244,144,Color.BLACK)
		frame.instrument_art.set_frame(changed,mask,ids)
		check(frame.instrument_art.active.size()==8,"one changed bit rejects the entire illustrated cell: "+kind)
		check(frame.instrument_art.active.all(func(c): return c.name!="heat_icon"),"unsafe shell icon retained: "+kind)
	frame.set_frame(source,{},null)
	check(frame.instrument_art.active.is_empty(),"unsupported frame clears cell art")
	var args := OS.get_cmdline_user_args()
	if "--text" in args: check(frame.typography.load_sources(root_path.path_join("GAME")),"source fonts for live labels")
	if "--native" in args:
		var fixture_arg := args.find("--fixture")
		var output_arg := args.find("--output")
		var valid_args := fixture_arg>=0 and fixture_arg+1<args.size() and output_arg>=0 and output_arg+1<args.size()
		check(valid_args,"native run requires --fixture and --output paths")
		if valid_args: await fixtures(args[fixture_arg+1],args[output_arg+1])
	for error in errors: printerr("FAIL: "+error)
	print("PC_GENESIS_COCKPITS: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func material_allowed(id: int, p: Vector2i, camera: Rect2i) -> bool:
	if id==1:
		if camera.has_point(p): return false
		if p.y<123: return true
		for box in [Rect2i(11,139,83,35),Rect2i(11,176,83,18),Rect2i(126,136,67,47),Rect2i(124,184,70,13),Rect2i(224,139,41,54),Rect2i(269,139,41,54)]:
			if box.has_point(p): return false
		return true
	if id==2:
		for box in [Rect2i(15,62,146,98),Rect2i(14,176,80,18),Rect2i(102,176,61,18),Rect2i(214,81,66,49),Rect2i(212,131,70,12),Rect2i(207,148,82,39)]:
			if box.has_point(p): return false
		return true
	if id==3: return true
	if id==4: return not Rect2i(53,187,214,13).has_point(p)
	if id==5:
		if Rect2i(82,37,23,63).has_point(p): return false
		if not frame.status_diagram_verified and Rect2i(123,37,182,63).has_point(p): return false
		if p.y>=108 and p.y<182 and (p.y-108)%13<9:
			if (p.x>=9 and p.x<23) or (p.x>=32 and p.x<156) or (p.x>=164 and p.x<289) or (p.x>=298 and p.x<313): return false
		return true
	return false

func fixtures(path: String, output: String) -> void:
	check(FileAccess.file_exists(path),"fixture file exists: "+path)
	if not FileAccess.file_exists(path): return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	var supported := parsed is Dictionary and parsed.get("ui_presentations") is Array and parsed.get("presentations") is Array and parsed.get("render_passes") is Array
	check(supported,"fixture has recorded UI, presentation and draw-pass arrays")
	if not supported: return
	var report: Dictionary = parsed
	DirAccess.make_dir_recursive_absolute(output)
	var samples := []
	var coverage := {1:0,2:0,3:0,4:0,5:0}
	var changed_total := 0
	for entry in report.ui_presentations:
		var packet: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
		var drawing: Dictionary = report.render_passes.filter(func(p): return p.sequence==entry.draw_sequence)[0]
		packet.draw_pass = drawing
		var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
		var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
		var tags := Image.load_from_file(path.get_base_dir().path_join(entry.plate_mask))
		packet.ui_overlay.mask_png = Marshalls.raw_to_base64(ui.save_png_to_buffer())
		packet.plate_overlay.mask_png = Marshalls.raw_to_base64(tags.save_png_to_buffer())
		var c: Array = drawing.camera.clip
		var camera := Rect2i(c[0],c[1],c[2]-c[0]+1,c[3]-c[1]+1)
		var world := ImageTexture.create_from_image(source.get_region(camera))
		check(frame.set_frame(source,packet,world),"paired original source accepted: "+entry.stage)
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var result := viewport.get_texture().get_image()
		if entry.stage=="damage-settled":
			check(frame.status_diagram_verified,"pristine source schematic is eligible")
			if not frame.typography.fonts.is_empty():
				check(frame.typography.runs.size()==18,"all twelve system labels and six visible stores values redraw")
			# Exact donor probes catch an unbound extra sampler, which can render
			# white while every protected original value still passes its checks.
			var art: Image = frame.status_art_texture.get_image()
			for p: Vector2i in [Vector2i(40,33),Vector2i(170,27),Vector2i(200,25)]:
				var px := p.x+0.625
				var py := 2.0+((p.y+0.625)-20.0)*84.0/85.0
				if p==Vector2i(40,33): px=110.0; py=40.0
				var expected := art.get_pixel(floori(px*1586/320),floori(py*992/200))
				check(result.get_pixel(p.x*4+2,p.y*4+2).to_rgba32()==expected.to_rgba32(),"status artwork sampler/registration: "+str(p))
		var assembly := Image.new()
		if frame.driver_assembly_enabled: assembly.load_png_from_buffer(Marshalls.base64_to_raw(packet.driver_overlay.mask_png))
		var changed := 0
		for y in 800:
			for x in 1280:
				var p := Vector2i(x/4,y/4)
				var id := roundi(tags.get_pixelv(p).r*255)
				var allowed: bool = ui.get_pixelv(p).r==1.0 and id in frame.cockpit_art_ids and material_allowed(id,p,camera)
				if not assembly.is_empty() and assembly.get_pixelv(p).b==1.0: allowed = true
				for cell in frame.instrument_art.active+frame.instrument_art.gauges:
					if cell.source.has_point(p): allowed = true
				if frame.instrument_art.orientation.source_rect.has_point(p): allowed = true
				for label in frame.typography.runs:
					if label.rect.has_point(Vector2(p)):
						allowed = true
						var expected_label: Dictionary = label.duplicate()
						if label.get("transparent_world",false): expected_label.background=source.get_pixelv(p)
						check(outlines.matches(result.get_pixel(x,y),expected_label,Vector2(x+0.5,y+0.5)/4,Vector2(4,4)),"outline cockpit letterform: "+entry.stage)
				var same := result.get_pixel(x,y).to_rgba32()==source.get_pixelv(p).to_rgba32()
				if not allowed: check(same,"protected source pixel changed: %s %d,%d"%[entry.stage,x,y])
				elif not same: changed+=1
		for id in frame.cockpit_art_ids: coverage[id]+=1
		changed_total += changed
		result.save_png(output.path_join(entry.stage+".png"))
		samples.append({"stage":entry.stage,"plates":frame.cockpit_art_ids.duplicate(),"instrument_cells":frame.instrument_art.active.map(func(cell): return cell.name),"gauges":frame.instrument_art.gauges.map(func(cell): return cell.name),"labels":frame.typography.runs.map(func(label):return label.text),"changed_pixels":changed})
		if entry.stage=="damage-settled": await damaged_schematic(source,ui,tags,packet,world,output)
	check(changed_total>100000,"real high-resolution materials are visible")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":path,"fixture_sha256":FileAccess.get_sha256(path),"checks":checks,"errors":errors,"coverage":coverage,"changed_pixels":changed_total,"samples":samples},"  "))

func damaged_schematic(source: Image, ui: Image, tags: Image, packet: Dictionary, world: Texture2D, output: String) -> void:
	# A single original overwrite must retain the ENTIRE original schematic,
	# including unchanged surrounding cells. A partial pristine tank would lie.
	var changed := source.duplicate()
	changed.set_pixel(160,60,Color.RED)
	var modified_tags := tags.duplicate()
	modified_tags.set_pixel(160,60,Color.BLACK)
	var damaged := packet.duplicate(true)
	damaged.plate_overlay.mask_png=Marshalls.raw_to_base64(modified_tags.save_png_to_buffer())
	check(frame.set_frame(changed,damaged,world),"damaged schematic frame composes")
	check(not frame.status_diagram_verified,"one original write rejects the whole pristine diagram")
	check(5 in frame.cockpit_art_ids,"other verified STATUS artwork stays enabled")
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var rendered := viewport.get_texture().get_image()
	for y in range(37*4,100*4):
		for x in range(123*4,305*4):
			check(rendered.get_pixel(x,y).to_rgba32()==changed.get_pixel(x/4,y/4).to_rgba32(),"damaged source schematic hidden at %d,%d"%[x,y])
	rendered.save_png(output.path_join("damage-synthetic-overwrite.png"))
