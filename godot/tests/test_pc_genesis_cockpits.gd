extends SceneTree
var outlines = preload("res://tests/pc_outline_oracle.gd").new()
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Rail = preload("res://scripts/pc_cupola_rail.gd")
var rail = Rail.new()
var rail_points: Dictionary = {}
const Trim = preload("res://scripts/pc_gunner_trim.gd")
const Instruments = preload("res://scripts/pc_instrument_art.gd")
var errors: Array[String] = []
var checks := 0
var corner_ink: Dictionary = {}
var viewport: SubViewport
var frame: TextureRect

func check(ok: bool, reason: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void:
	for p in Trim.corner_pixels(): corner_ink[p]=true
	for p in Rail.pixels(): rail_points[p]=true
	run.call_deferred()

func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	outlines.load_sources(root_path)
	check(rail.load_source(root_path),"verified AA source for static cupola rail")
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
	check(source!=null and source.get_size()==Vector2i(320,200),"gps-bin.png source available")
	# A missing local plate must fail promptly, not abort run() before quit().
	if source==null or source.get_size()!=Vector2i(320,200): done(); return
	var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
	tags.fill(Color(1.0/255,0,0))
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	frame.instrument_art.set_frame(source,ui,tags)
	check(frame.instrument_art.active.size()==9,"all nine unchanged source instrument cells qualify")
	icon_geometry()
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
	done()
func done() -> void:
	for error in errors: printerr("FAIL: "+error)
	print("PC_GENESIS_COCKPITS: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func material_allowed(id: int, p: Vector2i, camera: Rect2i) -> bool:
	if id==1:
		if camera.has_point(p): return frame.gunner_trim.corners_verified and corner_ink.has(p)
		if p.y<123: return true
		for box in [Rect2i(11,139,83,35),Rect2i(11,176,83,18),Rect2i(126,136,67,47),Rect2i(124,184,70,13),Rect2i(224,139,41,54),Rect2i(269,139,41,54)]:
			if (box.grow(-2) if frame.gunner_trim.active else box).has_point(p): return false
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
		# The dedicated refinement gate checks every changed output pixel and
		# poisons hidden world texels. Here permit only its narrow visible-side
		# silhouette neighbourhood, retaining every unowned UI assertion.
		var edge_world:Dictionary={}
		if frame.cockpit_edges.active:
			for profile:Dictionary in frame.cockpit_edges.profiles:
				var points:PackedVector2Array=profile.points
				for i in range(points.size()-1):
					for ex in range(maxi(0,floori(points[i].x)),mini(320,ceili(points[i+1].x))):
						var ta:=clampf((ex-points[i].x)/(points[i+1].x-points[i].x),0,1)
						var tb:=clampf((ex+1.0-points[i].x)/(points[i+1].x-points[i].x),0,1)
						var ya:=lerpf(points[i].y,points[i+1].y,ta)
						var yb:=lerpf(points[i].y,points[i+1].y,tb)
						for row in range(floori(minf(ya,yb)-1.65),ceili(maxf(ya,yb)+1.65)):
							var q:=Vector2i(ex,row)
							if camera.has_point(q) and ui.get_pixelv(q).r==0.0:edge_world[q]=true
		var changed := 0
		for y in 800:
			for x in 1280:
				var p := Vector2i(x/4,y/4)
				var id := roundi(tags.get_pixelv(p).r*255)
				var allowed: bool = ui.get_pixelv(p).r==1.0 and id in frame.cockpit_art_ids and material_allowed(id,p,camera)
				if frame.gunner_trim.corners_verified and corner_ink.has(p): allowed = true
				if edge_world.has(p): allowed=true
				if bool(frame.material.get_shader_parameter("cupola_rail_verified")) and rail_points.has(p): allowed = true
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
		if entry.stage=="commander-settled":
			commander_hardware(result)
			viewport.size=Vector2i(1280,960)
			frame.size=Vector2(1280,960)
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var corrected := viewport.get_texture().get_image()
			commander_hardware(corrected)
			corrected.save_png(output.path_join("commander-settled-4x3.png"))
			viewport.size=Vector2i(1280,800)
			frame.size=Vector2(1280,800)
		if entry.stage=="cupola-settled": await cupola_safety(source,ui,tags,packet,world,output)
		if entry.stage=="gunner-settled":
			gunner_join(result)
			icon_sampling(result,4)
			viewport.size=Vector2i(1920,1200)
			frame.size=Vector2(1920,1200)
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var large := viewport.get_texture().get_image()
			icon_sampling(large,6)
			large.save_png(output.path_join("gunner-settled-1920.png"))
			viewport.size=Vector2i(1280,800)
			frame.size=Vector2(1280,800)
		if entry.stage=="damage-settled": await damaged_schematic(source,ui,tags,packet,world,output)
	check(changed_total>100000,"real high-resolution materials are visible")
	var file := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"fixture":path,"fixture_sha256":FileAccess.get_sha256(path),"checks":checks,"errors":errors,"coverage":coverage,"changed_pixels":changed_total,"samples":samples},"  "))

# Independently measured illustration bounds, excluding the blank donor count
# wells. The old full-cell crops squeezed the actual shells into stubby bullets.
const ICON_CROPS = [Rect2(1182,652,126,44),Rect2(1182,736,116,40),
	Rect2(1182,812,119,43),Rect2(1182,893,124,48),Rect2(1461,651,58,44),
	Rect2(1451,739,85,32),Rect2(1440,817,102,38),Rect2(1438,892,98,52)]

func icon_geometry() -> void:
	for i in ICON_CROPS.size():
		var item: Dictionary = Instruments.CELLS[i]
		var box := Instruments.fitted_icon_rect(item)
		check(item.donor==ICON_CROPS[i],"tight original-aspect illustration crop: "+item.name)
		check(Rect2(item.source).grow(-1).encloses(box),"icon fits with one-pixel inset: "+item.name)
		check(box.get_center().is_equal_approx(Rect2(item.source).get_center()),"icon centred: "+item.name)
		check(is_equal_approx(box.size.x/box.size.y,ICON_CROPS[i].size.x/ICON_CROPS[i].size.y),"no anisotropic icon stretch: "+item.name)

func gunner_join(result: Image) -> void:
	var art: Image = frame.gunner_art_texture.get_image()
	# Independently calculated continuous UVs across the row-123 join. These
	# remain outside the registered console panels and fastener patches.
	for p: Vector2i in [Vector2i(68,491),Vector2i(68,492),Vector2i(76,491),Vector2i(76,492),Vector2i(92,492),Vector2i(1208,491),Vector2i(1208,492),Vector2i(1248,492)]:
		var q := Vector2(p)+Vector2(0.5,0.5)
		q/=4.0
		var y := 111.0+(q.y-110.0)*7.0/13.0
		var x := q.x
		if q.y>=123.0:
			y=118.0+(q.y-123.0)*(18.4 if q.x<103.0 else 10.5)/16.0
			var lower_x := 5.5+(q.x-11.0)*95.5/83.0 if q.x<103.0 else (270.0+(q.x-269.0)*44.3/41.0 if q.x<310.0 else 314.3+(q.x-310.0)*5.7/10.0)
			var t := (q.y-123.0)/13.0
			x=lerpf(q.x,lower_x,t*t*(3.0-2.0*t))
		var donor := Vector2(x*1586.0/320.0,y*992.0/200.0)-Vector2(0.5,0.5)
		var a := Vector2i(donor.floor())
		var f := donor-Vector2(a)
		var expected := art.get_pixelv(a).lerp(art.get_pixelv(a+Vector2i(1,0)),f.x).lerp(art.get_pixelv(a+Vector2i(0,1)).lerp(art.get_pixelv(a+Vector2i(1,1)),f.x),f.y)
		var actual := result.get_pixelv(p)
		check(absf(expected.r-actual.r)<=3.0/255 and absf(expected.g-actual.g)<=3.0/255 and absf(expected.b-actual.b)<=3.0/255,"continuous linearly sampled gunner shell join: "+str(p))
	check(frame.gunner_trim.active,"registered straight console trim visible")
	check(frame.gunner_trim.corners_verified,"whole source aperture corner proof")

func icon_sampling(result: Image, scale: int) -> void:
	var art: Image = frame.gunner_art_texture.get_image()
	for i in ICON_CROPS.size():
		var cell: Rect2i = Instruments.CELLS[i].source
		var crop: Rect2 = ICON_CROPS[i]
		var factor := minf((cell.size.x-2.0)/crop.size.x,(cell.size.y-2.0)/crop.size.y)
		var extent := crop.size*factor
		var start := Vector2(cell.position)+Vector2(cell.size)/2.0-extent/2.0
		for fraction in [0.15,0.35,0.55,0.75,0.85]:
			var p := Vector2i((start+extent*Vector2(fraction,0.5))*scale)
			var uv := ((Vector2(p)+Vector2(0.5,0.5))/scale-start)/extent
			var donor_point := crop.position+uv*crop.size-Vector2(0.5,0.5)
			var a := Vector2i(donor_point.floor())
			var f := donor_point-Vector2(a)
			var expected := art.get_pixelv(a).lerp(art.get_pixelv(a+Vector2i(1,0)),f.x).lerp(art.get_pixelv(a+Vector2i(0,1)).lerp(art.get_pixelv(a+Vector2i(1,1)),f.x),f.y)
			var actual := result.get_pixelv(p)
			check(absf(expected.r-actual.r)<=3.0/255 and absf(expected.g-actual.g)<=3.0/255 and absf(expected.b-actual.b)<=3.0/255,"uniform native icon sampling %dx %s at %s"%[scale,Instruments.CELLS[i].name,p])

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

func commander_hardware(result: Image) -> void:
	var scale := Vector2(result.get_size())/Vector2(320,200)
	for p in [Vector2(11,175),Vector2(166,175),Vector2(11,193.5),Vector2(166,193.5)]:
		var c := Vector2i(p*scale)
		var extent := []
		for axis in [Vector2i(1,0),Vector2i(0,1)]:
			var lo := 100
			var hi := -100
			for delta in range(-11,11):
				var color := result.get_pixelv(c+axis*delta)
				if color.r<0.3 and color.g<0.3 and color.b<0.3:
					lo=mini(lo,delta)
					hi=maxi(hi,delta)
			extent.append(hi-lo+1)
		check(extent[0]>=18 and abs(extent[0]-extent[1])<=2,"round output-space commander screw %s at %s: %s"%[p,result.get_size(),extent])

func cupola_safety(source: Image, ui: Image, tags: Image, packet: Dictionary, world: Texture2D, output: String) -> void:
	check(rail.verify(source,ui,tags,Rail.CAMERA,true),"whole static cupola rail source proof")
	check(bool(frame.material.get_shader_parameter("cupola_rail_verified")),"runtime enables exactly verified cupola rail")
	check(not rail.verify(source,ui,tags,Rect2i(0,0,320,118),true),"wrong cupola camera rejects rail")
	check(not rail.verify(source,ui,tags,Rail.CAMERA,false),"wrong station rejects rail")
	for kind in ["pixel","ownership","plate","context"]:
		var changed := source.duplicate()
		var mask := ui.duplicate()
		var ids := tags.duplicate()
		if kind=="pixel": changed.set_pixel(180,113,Color.MAGENTA)
		if kind=="ownership": mask.set_pixel(180,113,Color.BLACK)
		if kind=="plate": ids.set_pixel(180,113,Color(3.0/255,0,0))
		if kind=="context": ids.set_pixel(180,117,Color.BLACK)
		check(not rail.verify(changed,mask,ids,Rail.CAMERA,true),"one mismatched bit rejects whole rail: "+kind)
		var damaged := packet.duplicate(true)
		damaged.ui_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
		damaged.plate_overlay.mask_png=Marshalls.raw_to_base64(ids.save_png_to_buffer())
		check(frame.set_frame(changed,damaged,world),"cupola negative frame composes: "+kind)
		check(not bool(frame.material.get_shader_parameter("cupola_rail_verified")),"runtime clears cupola rail: "+kind)
		await process_frame
		RenderingServer.force_draw(false)
		RenderingServer.force_sync()
		var rendered := viewport.get_texture().get_image()
		for p in Rail.pixels():
			if p==Vector2i(180,113) and kind in ["ownership","plate"]: continue
			for y in 4:
				for x in 4:
					check(rendered.get_pixel(p.x*4+x,p.y*4+y).to_rgba32()==changed.get_pixelv(p).to_rgba32(),"cupola rejected whole rail retains source: "+kind)
		if kind=="pixel": rendered.save_png(output.path_join("cupola-synthetic-overwrite.png"))
