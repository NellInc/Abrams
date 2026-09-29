extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Trim = preload("res://scripts/pc_commander_trim.gd")
var errors: Array[String] = []
var checks := 0
var viewport: SubViewport
var frame: TextureRect
var trim: Control
var deadline := 0
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok and errors.size()<20: errors.append(why)
func _initialize() -> void:
	deadline = Time.get_ticks_msec()+90000
	run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()>deadline:
		printerr("FAIL: commander trim native deadline")
		quit(2)
	return false
func rendered() -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return viewport.get_texture().get_image()
func run() -> void:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var args := OS.get_cmdline_user_args()
	var path := repo.path_join("artifacts/pc-live-type-cockpit-02/report.json")
	var output := repo.path_join("artifacts/cockpit-refinement-20260929/console")
	if "--fixture" in args: path=args[args.find("--fixture")+1]
	if "--output" in args: output=args[args.find("--output")+1]
	check(FileAccess.file_exists(path),"real cockpit fixture exists")
	if errors.is_empty(): await native(repo,path,output,"--native" in args)
	for e in errors: printerr("FAIL: "+e)
	print("PC_COMMANDER_TRIM: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
func native(repo: String,path: String,output: String,native_render: bool) -> void:
	var report = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(report is Dictionary and report.get("ui_presentations") is Array,"fixture structure")
	if not errors.is_empty(): return
	viewport=SubViewport.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	frame=Frame.new()
	viewport.add_child(frame)
	check(frame.load_genesis_art(repo),"pinned original Genesis donors loaded")
	check(frame.load_graphics_sources(repo),"graphics modes loaded")
	check(frame.typography.load_sources(repo.path_join("GAME")),"original typefaces loaded")
	if not errors.is_empty(): return
	# Reuse production integration when present; before integration, exercise
	# the same helper externally below the authored instrument/text overlays.
	trim=frame.get("commander_trim")
	if trim==null:
		trim=Trim.new()
		frame.add_child(trim)
		frame.move_child(trim,3)
	DirAccess.make_dir_recursive_absolute(output)
	for stage in ["commander-settled","damage-settled"]:
		var entries: Array = report.ui_presentations.filter(func(e):return e.stage==stage)
		check(entries.size()==1,"one real fixture for "+stage)
		if entries.size()!=1: continue
		var e: Dictionary=entries[0]
		var source := Image.load_from_file(path.get_base_dir().path_join(e.image))
		var ui := Image.load_from_file(path.get_base_dir().path_join(e.mask))
		var tags := Image.load_from_file(path.get_base_dir().path_join(e.plate_mask))
		var source_bytes := source.get_data()
		var ui_bytes := ui.get_data()
		var tag_bytes := tags.get_data()
		var packet: Dictionary=report.presentations[int(e.frame_index)].duplicate(true)
		packet.draw_pass=report.render_passes.filter(func(p):return p.sequence==e.draw_sequence)[0]
		packet.ui_overlay.mask_png=Marshalls.raw_to_base64(ui.save_png_to_buffer())
		packet.plate_overlay.mask_png=Marshalls.raw_to_base64(tags.save_png_to_buffer())
		var world := ImageTexture.create_from_image(source.get_region(Trim.CAMERA))
		for dimensions in [Vector2i(1280,800),Vector2i(1280,960)]:
			viewport.size=dimensions
			frame.size=Vector2(dimensions)
			trim.size=Vector2(dimensions)
			check(frame.set_frame(source,packet,world),"real paired source accepted")
			trim.set_frame(source,ui,tags,Trim.CAMERA,world)
			check(trim.active==(stage=="commander-settled"),"commander only, STATUS remains untouched")
			if not native_render: continue
			var result := await rendered()
			result.save_png(output.path_join("%s-%dx%d.png"%[stage,dimensions.x,dimensions.y]))
			trim.hide()
			var baseline := await rendered()
			baseline.save_png(output.path_join("%s-before-%dx%d.png"%[stage,dimensions.x,dimensions.y]))
			if trim.active: trim.show()
			var scale := Vector2(dimensions)/Vector2(320,200)
			var protected_errors := 0
			var changed := 0
			for y in dimensions.y:
				for x in dimensions.x:
					if result.get_pixel(x,y)==baseline.get_pixel(x,y): continue
					changed+=1
					var p := Vector2i(Vector2(x+0.5,y+0.5)/scale)
					if roundi(tags.get_pixelv(p).r*255)!=2 or ui.get_pixelv(p).r!=1.0 or Trim.PROTECTED.any(func(r):return r.has_point(p)) or not Rect2i(187,63,121,130).has_point(p): protected_errors+=1
			check(protected_errors==0,"every map/gauge/heading/compass/miniature/world pixel immutable")
			check(changed>0 if stage=="commander-settled" else changed==0,"static commander metal changes only")
			if stage=="commander-settled":
				for p in Trim.SCREWS: circle(result,p,dimensions)
		if stage=="commander-settled": await rejection(source,ui,tags,world,native_render)
		check(source.get_data()==source_bytes and ui.get_data()==ui_bytes and tags.get_data()==tag_bytes,"all source inputs immutable")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"native":native_render,"fixture":path,"fixture_sha256":FileAccess.get_sha256(path)},"  "))
func circle(result: Image,p: Vector2,dimensions: Vector2i) -> void:
	var c: Vector2=trim.screw_center(p)
	var r: float=trim.screw_radius()
	var left := dimensions.x
	var top := dimensions.y
	var right := -1
	var bottom := -1
	for y in range(floori(c.y-r-1),ceili(c.y+r+1)):
		for x in range(floori(c.x-r-1),ceili(c.x+r+1)):
			if absf(x+0.5-c.x)>r+0.5 or absf(y+0.5-c.y)>r+0.5: continue
			var color := result.get_pixel(x,y)
			if color.r<0.23 and color.g<0.25 and color.b<0.26:
				left=mini(left,x);right=maxi(right,x);top=mini(top,y);bottom=maxi(bottom,y)
	check(right>left and bottom>top and absi((right-left)-(bottom-top))<=1,"rendered screw circular at %s in %s"%[p,dimensions])
func rejection(source: Image,ui: Image,tags: Image,world: Texture2D,native_render: bool) -> void:
	for kind in ["unknown","mixed","unowned","partial","camera","world","dimensions"]:
		var ids := tags.duplicate()
		var mask := ui.duplicate()
		var camera := Trim.CAMERA
		var scene := world
		if kind=="unknown": ids.set_pixel(190,66,Color(99.0/255,0,0))
		if kind=="mixed": ids.set_pixel(190,66,Color(5.0/255,0,0))
		if kind=="unowned": mask.set_pixel(190,66,Color.BLACK)
		if kind=="partial": ids.set_pixel(187,63,Color.BLACK)
		if kind=="camera": camera.position.y+=1
		if kind=="world": scene=null
		if kind=="dimensions": ids=Image.create_empty(319,200,false,Image.FORMAT_L8)
		trim.set_frame(source,mask,ids,camera,scene)
		check(not trim.active and not trim.visible,"fail closed on "+kind)
		if native_render:
			var rejected := await rendered()
			trim.hide()
			var baseline := await rendered()
			check(rejected.get_data()==baseline.get_data(),"native original fallback on "+kind)
	# Even forged static ownership cannot authorize painting live interiors.
	var forged := tags.duplicate()
	for box: Rect2i in Trim.PROTECTED:
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x):
				if ui.get_pixel(x,y).r==1.0: forged.set_pixel(x,y,Color(2.0/255,0,0))
	trim.set_frame(source,ui,forged,Trim.CAMERA,world)
	check(trim.active,"valid housing with mistagged live interiors accepted for guard test")
	if native_render:
		var guarded := await rendered()
		trim.hide()
		var baseline := await rendered()
		var mismatch := 0
		var scale := Vector2(viewport.size)/Vector2(320,200)
		for box: Rect2i in Trim.PROTECTED:
			for y in range(ceili(box.position.y*scale.y),floori(box.end.y*scale.y)):
				for x in range(ceili(box.position.x*scale.x),floori(box.end.x*scale.x)):
					if guarded.get_pixel(x,y)!=baseline.get_pixel(x,y): mismatch+=1
		check(mismatch==0,"all mistagged live-cell pixels immutable")
	trim.set_frame(source,ui,tags,Trim.CAMERA,world)
	check(trim.active,"valid original restores after rejection")
	trim.clear()
	check(not trim.active and not trim.visible,"clear removes stale overlay")
