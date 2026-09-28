extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Trim = preload("res://scripts/pc_gunner_trim.gd")
var errors: Array[String] = []
var checks := 0
var viewport: SubViewport
var frame: TextureRect
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(why)
func _initialize() -> void: run.call_deferred()
func rendered() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func run() -> void:
	var root_path := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	if "--native" not in args:
		check(Trim.corner_pixels().size()==84,"all original rounded corner pixels enumerated")
		check(Trim.corner_pixels().all(func(p): return Trim.CAMERA.has_point(p)),"corner geometry stays within original aperture")
		var trim := Trim.new()
		root.add_child(trim)
		trim.size=Vector2(1280,960)
		var source := Image.create_empty(320,200,false,Image.FORMAT_RGB8)
		var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
		var tags := Image.create_empty(320,200,false,Image.FORMAT_L8)
		ui.fill(Color.WHITE)
		tags.fill(Color(1.0/255,0,0))
		for p in Trim.corner_pixels(): source.set_pixelv(p,Color8(85,85,85));tags.set_pixelv(p,Color.BLACK)
		var world := ImageTexture.create_from_image(source.get_region(Trim.CAMERA))
		trim.set_frame(source,ui,tags,Trim.CAMERA,world)
		check(trim.active and trim.corners_verified,"complete verified corner shape qualifies")
		for kind in ["pixel","ui","plate"]:
			var a := source.duplicate()
			var b := ui.duplicate()
			var c := tags.duplicate()
			if kind=="pixel":a.set_pixel(32,13,Color.MAGENTA)
			if kind=="ui":b.set_pixel(32,13,Color.BLACK)
			if kind=="plate":c.set_pixel(32,13,Color(1.0/255,0,0))
			trim.set_frame(a,b,c,Trim.CAMERA,world)
			check(trim.active and not trim.corners_verified,"whole corner rejects "+kind)
		trim.set_frame(source,ui,tags,Rect2i(31,13,256,97),world)
		check(not trim.active,"wrong camera clears hardware")
		trim.set_frame(source,ui,tags,Trim.CAMERA)
		check(not trim.active,"missing paired world clears hardware")
		trim.set_frame(source,ui,tags,Trim.CAMERA,world)
		trim.clear()
		check(not trim.active and not trim.corners_verified,"explicit clear removes stale trim")
	else:
		var i := args.find("--fixture")
		var j := args.find("--output")
		check(i>=0 and j>=0 and i+1<args.size() and j+1<args.size(),"fixture and output arguments required")
		if errors.is_empty(): await native(root_path,args[i+1],args[j+1])
	for e in errors: printerr("FAIL: "+e)
	print("PC_GUNNER_TRIM: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
func native(root_path: String,path: String,output: String) -> void:
	check(FileAccess.file_exists(path),"fixture exists")
	if not errors.is_empty(): return
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary and report.get("ui_presentations") is Array,"fixture structure")
	if not errors.is_empty(): return
	var entries: Array = report.ui_presentations.filter(func(e): return e.stage=="gunner-settled")
	check(entries.size()==1,"one settled gunner")
	if not errors.is_empty(): return
	var entry: Dictionary = entries[0]
	var source := Image.load_from_file(path.get_base_dir().path_join(entry.image))
	var ui := Image.load_from_file(path.get_base_dir().path_join(entry.mask))
	var tags := Image.load_from_file(path.get_base_dir().path_join(entry.plate_mask))
	var packet: Dictionary = report.presentations[int(entry.frame_index)].duplicate(true)
	packet.draw_pass=report.render_passes.filter(func(p): return p.sequence==entry.draw_sequence)[0]
	packet.ui_overlay.mask_png=Marshalls.raw_to_base64(ui.save_png_to_buffer())
	packet.plate_overlay.mask_png=Marshalls.raw_to_base64(tags.save_png_to_buffer())
	var world := ImageTexture.create_from_image(source.get_region(Trim.CAMERA))
	viewport=SubViewport.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	frame=Frame.new()
	viewport.add_child(frame)
	check(frame.load_genesis_art(root_path),"pinned original Genesis-derived donors loaded")
	check(frame.load_graphics_sources(root_path),"native graphics modes loaded")
	check(frame.typography.load_sources(root_path.path_join("GAME")),"source-derived typefaces loaded")
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1280,800),Vector2i(1280,960),Vector2i(1920,1200)]:
		viewport.size=dimensions
		frame.size=Vector2(dimensions)
		check(frame.set_frame(source,packet,world),"paired source accepted")
		check(frame.gunner_trim.active and frame.gunner_trim.corners_verified,"verified trim and 84 original corner pixels")
		var result := await rendered()
		result.save_png(output.path_join("gunner-%dx%d.png"%[dimensions.x,dimensions.y]))
		# No world visibility or live UI data may change under the new trim.
		frame.gunner_trim.hide()
		var without := await rendered()
		frame.gunner_trim.show()
		var scale := Vector2(dimensions)/Vector2(320,200)
		var corners := Trim.corner_pixels()
		for y in dimensions.y:
			for x in dimensions.x:
				var p := Vector2i(Vector2(x+0.5,y+0.5)/scale)
				if (ui.get_pixelv(p).r==0.0 or tags.get_pixelv(p).r==0.0) and p not in corners:
					check(result.get_pixel(x,y).to_rgba32()==without.get_pixel(x,y).to_rgba32(),"trim covers world/live source: "+str(p))
		# Circle bounds measured from rendered metal colours, not draw arguments.
		for p in Trim.SCREWS:
			var c: Vector2 = frame.gunner_trim.screw_center(p)
			var radius: float = frame.gunner_trim.screw_radius()
			var left: int = dimensions.x
			var top: int = dimensions.y
			var right := 0
			var bottom := 0
			for y in range(floori(c.y-radius-1),ceili(c.y+radius+1)):
				for x in range(floori(c.x-radius-1),ceili(c.x+radius+1)):
					if x<0 or y<0 or x>=dimensions.x or y>=dimensions.y: continue
					var color := result.get_pixel(x,y)
					if color.r<0.23 and color.g<0.25 and color.b<0.26:
						left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
			check(right>left and bottom>top and absi((right-left)-(bottom-top))<=1,"round visible screw at %s in %s"%[p,dimensions])
	# A bright sentinel behind the original corner cannot leak into the trim:
	# antialiasing may reuse already-visible colours only.
	var baseline := await rendered()
	var hidden := source.get_region(Trim.CAMERA)
	for p in Trim.corner_pixels(): hidden.set_pixelv(p-Trim.CAMERA.position,Color.MAGENTA)
	check(frame.set_frame(source,packet,ImageTexture.create_from_image(hidden)),"hidden-world sentinel frame")
	var sentinel := await rendered()
	for p in Trim.corner_pixels():
		for y in range(p.y*6,(p.y+1)*6):
			for x in range(p.x*6,(p.x+1)*6):
				check(sentinel.get_pixel(x,y).to_rgba32()==baseline.get_pixel(x,y).to_rgba32(),"concealed world leaked into aperture trim")
	check(frame.set_frame(source,packet,world),"original world restored")
	# Any unowned or recoloured aperture pixel rejects the entire corner trim.
	for kind in ["pixel","ui","plate"]:
		var changed := source.duplicate()
		var mask := ui.duplicate()
		var ids := tags.duplicate()
		if kind=="pixel":changed.set_pixel(32,13,Color.MAGENTA)
		if kind=="ui":mask.set_pixel(32,13,Color.BLACK)
		if kind=="plate":ids.set_pixel(32,13,Color(1.0/255,0,0))
		var modified := packet.duplicate(true)
		modified.ui_overlay.mask_png=Marshalls.raw_to_base64(mask.save_png_to_buffer())
		modified.plate_overlay.mask_png=Marshalls.raw_to_base64(ids.save_png_to_buffer())
		check(frame.set_frame(changed,modified,world),"mutated corner presentation accepted safely")
		check(not frame.gunner_trim.corners_verified,"single mismatched corner rejects whole shape: "+kind)
		var rejected := await rendered()
		for p in Trim.corner_pixels():
			if p==Vector2i(32,13) and kind=="ui": continue
			check(rejected.get_pixel(p.x*6+2,p.y*6+2).to_rgba32()==changed.get_pixelv(p).to_rgba32(),"whole-corner original fallback: "+kind)
	check(frame.set_frame(source,packet,world),"restore unchanged packet")
	var upscaled := await rendered()
	for mode in ["ega","genesis","upscaled"]:
		check(frame.set_graphics_mode(mode),"instant switch "+mode)
		var actual := await rendered()
		if mode=="ega":
			for p in [Vector2i(24,124),Vector2i(224,131),Vector2i(32,13)]:
				check(actual.get_pixel(p.x*6+2,p.y*6+2).to_rgba32()==source.get_pixelv(p).to_rgba32(),"EGA trim restored: "+str(p))
		if mode=="upscaled":check(actual.get_data()==upscaled.get_data(),"same-frame Upscaled restore is byte-identical")
		else:check(not frame.gunner_trim.active,"trim cleared in "+mode)
	frame.set_frame(source,{},null)
	check(not frame.gunner_trim.active,"unsupported source clears trim")
	var f := FileAccess.open(output.path_join("report.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"errors":errors,"fixture":path,"fixture_sha256":FileAccess.get_sha256(path)},"  "))
