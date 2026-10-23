extends SceneTree
const Art = preload("res://scripts/pc_splash_aftermath_art.gd")
var failures := 0

func expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	create_timer(60.0).timeout.connect(func(): printerr("FAIL: splash capture deadline"); quit(1))
	var project := ProjectSettings.globalize_path("res://").get_base_dir()
	var root_path := project.get_base_dir()
	var art = Art.new()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,800)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(art)
	art.size = Vector2(1280,800)
	expect(art.load_sources(root_path),"catalog loads")
	var output := root_path.path_join("artifacts/finish-20260928/splash-aftermath")
	var args := OS.get_cmdline_user_args()
	if "--output" in args:
		var at := args.find("--output")+1
		if at>=args.size(): printerr("FAIL: missing output path"); quit(1); return
		output=args[at]
	DirAccess.make_dir_recursive_absolute(output)
	for row in art.entries.values():
		var source := Image.load_from_file(root_path.path_join(row.expected_path))
		source.convert(Image.FORMAT_RGB8)
		expect(art.set_frame(source,{"name":row.program}),row.name+" exact match")
		expect(art.active.name==row.name,row.name+" identity")
		var native: Image = art.native_frame(source,{"name":row.program})
		expect(native.get_size()==Vector2i(320,200),row.name+" native shape")
		if row.name=="publisher": expect(native==source,"publisher retains PC identity in native mode")
		elif art.native_images.has(row.name): expect(native.get_data()!=source.get_data(),row.name+" Genesis native donor")
		else: expect(native==source,row.name+" missing optional donor retains PC pixels")
		var phase: float=art.smoke_phase
		expect(art.advance(0.1)==(row.name!="publisher"),row.name+" ending-only motion")
		if row.name!="publisher":
			expect(art.smoke_phase>phase,row.name+" smoke advances")
			var advanced: float=art.smoke_phase
			art.set_frame(source,{"name":row.program})
			expect(art.smoke_phase==advanced,row.name+" repeated source does not restart smoke")
			art.motion_enabled=false
			expect(not art.advance(0.1) and art.smoke_phase==advanced,row.name+" reduced-motion stops phase")
			art.motion_enabled=true
		art.reset_motion()
		await process_frame
		await process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			viewport.get_texture().get_image().save_png(output.path_join(row.name+"-rendered.png"))
		var changed := source.duplicate()
		changed.set_pixel(17,19,Color.MAGENTA)
		expect(not art.set_frame(changed,{"name":row.program}),row.name+" changed pixel rejected")
		expect(not art.visible and art.active.is_empty(),row.name+" rejection clears art")
		expect(not art.set_frame(source,{"name":"WRONG"}),row.name+" wrong program rejected")
		expect(art.native_frame(changed,{"name":row.program})==changed,row.name+" native fallback untouched")
		expect(not art.set_frame(null,{"name":row.program}),row.name+" null rejected")
	art.clear()
	expect(not art.visible,"clear hides art")
	print("SPLASH_AFTERMATH_TEST: failures=",failures," entries=",art.entries.size())
	viewport.queue_free()
	quit(1 if failures else 0)
