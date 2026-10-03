extends SceneTree
const Frame = preload("res://scripts/pc_tandem_frame.gd")
const Damage = preload("res://scripts/pc_instrument_damage_art.gd")
var checks := 0
var errors: Array[String] = []
func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok: errors.append(reason)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var repo := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var art := Damage.new()
	root.add_child(art)
	check(not art.load_sources(repo.path_join("missing-source-fixture")),"missing manifest fails quietly")
	check(art.load_sources(repo),"source and patch catalog authenticated")
	var frame := Frame.new()
	root.add_child(frame)
	check(frame.load_genesis_art(repo),"tandem assets loaded")
	var directory := repo.path_join("artifacts/finish-20260928/status-damage-oracle-02")
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var oracle_ok := true
	for bits in 32:
		var source := Image.load_from_file(directory.path_join("state-%02d.png"%bits))
		var tags := Image.load_from_file(directory.path_join("tags-%02d.png"%bits))
		# Missing local oracle images must fail promptly, not abort run() before quit().
		oracle_ok = source!=null and tags!=null and source.get_size()==Vector2i(320,200) and tags.get_size()==Vector2i(320,200)
		check(oracle_ok,"status-damage oracle state-%02d available"%bits)
		if not oracle_ok: break
		var plates := {}
		for id in Frame.COCKPIT_SOURCES:
			plates[str(id)]={"source":Frame.COCKPIT_SOURCES[id][0],"source_sha256":Frame.COCKPIT_SOURCES[id][1]}
		var packet := {"draw_pass":{"camera":{"clip":[0,0,319,135]}},"palette_rgb":Frame.ART_PALETTE,
			"ui_overlay":{"width":320,"height":200,"mask_png":Marshalls.raw_to_base64(ui.save_png_to_buffer())},
			"plate_overlay":{"width":320,"height":200,"plates":plates,"mask_png":Marshalls.raw_to_base64(tags.save_png_to_buffer())}}
		var world := ImageTexture.create_from_image(source.get_region(Rect2i(0,0,320,136)))
		check(frame.set_frame(source,packet,world),"tandem original fixture accepted")
		check(frame.damage_art.state==bits,"tandem damage art bound")
		packet.palette_rgb=[]
		check(frame.set_frame(source,packet,world) and frame.damage_art.state==-1,"wrong palette keeps original damage")
		check(not frame.set_frame(source,{},world) and frame.damage_art.state==-1,"tandem fallback clears damage")
		art.set_frame(source,ui,tags)
		check(art.state==bits,"CPU fixture accepted %d"%bits)
		for fault in ["rgb","tag","ui","partial_ui"]:
			var bad_source: Image=source.duplicate()
			var bad_tags: Image=tags.duplicate()
			var bad_ui: Image=ui.duplicate()
			if fault=="rgb": bad_source.set_pixel(125,40,Color.MAGENTA)
			if fault=="tag": bad_tags.set_pixel(125,40,Color.WHITE)
			if fault=="ui": bad_ui.set_pixel(125,40,Color.BLACK)
			if fault=="partial_ui": bad_ui.set_pixel(125,40,Color(0.75,0.75,0.75))
			art.set_frame(bad_source,bad_ui,bad_tags)
			check(art.state==-1,"unsafe variant rejected %d %s"%[bits,fault])
		art.set_frame(source,ui,tags)
		art.clear()
		check(art.state==-1,"no stale state %d"%bits)
	frame.queue_free()
	var args := OS.get_cmdline_user_args()
	if "--native" in args and oracle_ok:
		await native(art,directory,args[args.find("--output")+1])
	for error in errors: printerr("FAIL: "+error)
	print("PC_INSTRUMENT_DAMAGE: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)

func native(art: Control, directory: String, output: String) -> void:
	# Normal completion watchdog, no OS signals. GPU capture does not rely on
	# frame_post_draw, which can stop firing for an occluded macOS window.
	create_timer(120).timeout.connect(func(): printerr("FAIL: native capture deadline"); quit(1))
	DirAccess.make_dir_recursive_absolute(output)
	var viewport := SubViewport.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg=false
	root.add_child(viewport)
	root.remove_child(art)
	var background := TextureRect.new()
	background.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(background)
	viewport.add_child(art)
	var ui := Image.create_empty(320,200,false,Image.FORMAT_L8)
	ui.fill(Color.WHITE)
	var checked_pixels := 0
	var captures := 0
	for extent in [Vector2i(1280,800),Vector2i(1728,1080),Vector2i(1920,1200)]:
		viewport.size=extent
		background.size=Vector2(extent)
		art.size=Vector2(extent)
		for bits in 32:
			var source := Image.load_from_file(directory.path_join("state-%02d.png"%bits))
			var tags := Image.load_from_file(directory.path_join("tags-%02d.png"%bits))
			background.texture=ImageTexture.create_from_image(source)
			art.clear()
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var before := viewport.get_texture().get_image()
			art.set_frame(source,ui,tags)
			await process_frame
			RenderingServer.force_draw(false)
			RenderingServer.force_sync()
			var after := viewport.get_texture().get_image()
			check(art.state==bits,"native exact source state")
			var factor := Vector2(extent)/Vector2(320,200)
			var box := Rect2i(Vector2i(Damage.DRAW_BOX.position*factor)-Vector2i.ONE,Vector2i(Damage.DRAW_BOX.size*factor)+Vector2i(2,2))
			for region in [Rect2i(0,0,extent.x,box.position.y),Rect2i(0,box.end.y,extent.x,extent.y-box.end.y),Rect2i(0,box.position.y,box.position.x,box.size.y),Rect2i(box.end.x,box.position.y,extent.x-box.end.x,box.size.y)]:
				check(before.get_region(region).get_data()==after.get_region(region).get_data(),"native outside schematic unchanged")
			check(before.get_data()!=after.get_data(),"native caption and selected damage artwork bound")
			checked_pixels+=extent.x*extent.y
			captures+=1
			if extent.x==1280 and bits in [1,2,4,8,16,31]: after.save_png(output.path_join("state-%02d.png"%bits))
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"captures":captures,"pixels":checked_pixels,"checks":checks,"errors":errors},"  "))
	viewport.queue_free()
