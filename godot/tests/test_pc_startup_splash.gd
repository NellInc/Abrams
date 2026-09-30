extends SceneTree
const Splash = preload("res://scripts/pc_startup_splash.gd")
const Viewer = preload("res://scripts/pc_bridge_viewer.gd")
var checks := 0
var errors: Array[String] = []
var started := Time.get_ticks_msec()
var output := ""

func _initialize() -> void: run.call_deferred()
func _process(_delta: float) -> bool:
	if Time.get_ticks_msec()-started>120000: quit(2)
	return false

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: errors.append(reason)

func snapshot(viewport: SubViewport, name: String) -> Image:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var image := viewport.get_texture().get_image()
	check(image!=null and not image.is_empty(),"native image exists: "+name)
	if not output.is_empty(): check(image.save_png(output.path_join(name+".png"))==OK,"saved "+name)
	return image

func layout_contracts(splash: Control, extent: Vector2i) -> void:
	var bounds := Rect2(Vector2.ZERO,Vector2(extent))
	check(bounds.encloses(splash.artwork_rect),"complete uncropped artwork: "+str(extent))
	check(bounds.encloses(Rect2(splash.message.position,splash.message.size)),"caption inside window: "+str(extent))
	check(splash.artwork_rect.end.y<splash.message.position.y-12,"caption separated from artwork")
	check(splash.message.size.y>=splash.message.get_minimum_size().y,"wrapped caption height")
	if splash.cover.texture:
		var source: Vector2=splash.cover.texture.get_size()
		check(absf(splash.artwork_rect.size.aspect()-source.aspect())<0.00001,"original cover aspect ratio")
	for item in [splash,splash.cover,splash.message,splash.fallback]:
		check(item.mouse_filter==Control.MOUSE_FILTER_IGNORE,"startup never intercepts input")
		check(item.focus_mode==Control.FOCUS_NONE,"startup never takes keyboard focus")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if "--output" in args:
		output=args[args.find("--output")+1]
		DirAccess.make_dir_recursive_absolute(output)
	check(DisplayServer.get_name()!="headless","native renderer required")
	var repository := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var outer := SubViewport.new()
	outer.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(outer)
	var game := ColorRect.new()
	game.color=Color.MAGENTA
	game.mouse_filter=Control.MOUSE_FILTER_IGNORE
	outer.add_child(game)
	var splash := Splash.new()
	outer.add_child(splash)
	check(splash.load_cover(repository),"approved packaged cover loads")
	check(not splash.fallback.visible,"fallback absent when cover exists")
	var source := Image.load_from_file(repository.path_join(Splash.COVER_PATH))
	check(splash.cover.texture.get_image().get_data()==source.get_data(),"approved artwork bytes unchanged")
	var cases := [Vector2i(1280,960),Vector2i(640,480),Vector2i(1920,1080),Vector2i(960,1280)]
	for extent in cases:
		outer.size=extent;game.size=extent;splash.size=extent
		layout_contracts(splash,extent)
		var image := await snapshot(outer,"cover-%dx%d"%[extent.x,extent.y])
		check(image.get_pixelv(Vector2i(splash.artwork_rect.get_center())).r>0.15,"cover visible on first draw")
		check(image.get_pixel(0,0).r<0.3,"dark surround painted, no grey blank")
	# There is no minimum hold, tween, timer or dependency on another guest frame.
	splash.finish()
	check(not splash.visible and splash.finished,"immediate handoff")
	splash.finish()
	check(not splash.visible,"handoff idempotent")
	var rendered := await snapshot(outer,"first-game-frame")
	for point in [Vector2i(0,0),Vector2i(400,200),outer.size/2,outer.size-Vector2i.ONE]:
		check(rendered.get_pixelv(point).to_rgba32()==Color.MAGENTA.to_rgba32(),"no retained cover on game")
	var failure := "Game stopped: Could not start the local PC core host. The local host log contains more information.\nClose this window to exit."
	splash.size=Vector2i(640,480);outer.size=Vector2i(640,480)
	splash.show_error(failure)
	layout_contracts(splash,Vector2i(640,480))
	check(splash.visible and splash.message.visible and splash.message.text==failure,"actionable failure retained after handoff")
	splash.finish()
	check(splash.visible,"late frame cannot hide a failure")
	await snapshot(outer,"startup-error")
	splash.free()
	var fallback := Splash.new()
	outer.add_child(fallback)
	fallback.size=Vector2i(640,480)
	check(not fallback.load_cover(repository.path_join("absent-startup-fixture")),"missing cover is optional")
	check(fallback.fallback.visible and fallback.message.visible,"branded readable missing-art fallback")
	layout_contracts(fallback,Vector2i(640,480))
	await snapshot(outer,"missing-art-fallback")
	check(Viewer.frame_remainder(1.5,59.9227)<1.0/59.9227,"viewer retains original phase helper")
	if not output.is_empty():
		FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"cover_sha256":FileAccess.get_sha256(repository.path_join(Splash.COVER_PATH))},"  "))
	for error in errors: printerr("FAIL: "+error)
	print("PC_STARTUP_SPLASH: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
