extends "res://scripts/portable_setup.gd"
## UI-only fixture: no original game, host, import, profile or audio backend.
var checks := 0
var failures: Array[String] = []

func _request(_arguments: Array) -> void:
	installed=false
	play.disabled=true
	genesis.disabled=true
	pc.disabled=false
	message.text="Choose the supported original PC game folder to begin."

func _initialize() -> void:
	root.gui_embed_subwindows=true
	super._initialize()
	create_timer(60).timeout.connect(func(): printerr("FAIL: UI fixture deadline"); quit(1))
	_run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks+=1
	if not ok: failures.append(description)

func _inspect(node: Node) -> void:
	if node is Window and node!=root and not node.visible: return
	if node is Control and node.is_visible_in_tree() and node is not ColorRect and node is not TextureRect:
		var rect: Rect2 = node.get_global_rect()
		check(rect.position.x>=-1 and rect.position.y>=-1 and rect.end.x<=root.size.x+1 and rect.end.y<=root.size.y+1,"within viewport: "+str(node.get_path()))
	for child in node.get_children():_inspect(child)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var output := ""
	for i in args.size():
		if args[i]=="--output" and i+1<args.size(): output=args[i+1]
	check(InterfaceTheme.reference_path("../elsewhere").is_empty(),"reference path rejects traversal")
	check(InterfaceTheme.reference_path("missing.html").is_empty(),"unknown reference never resolves")
	check(InterfaceTheme.reference_path("field-guide.html").ends_with("docs/player-reference/field-guide.html"),"reference path uses installed sibling payload")
	check(not installed and play.disabled and genesis.disabled and not pc.disabled,"original-required controls")
	check(thread==null and not busy,"fixture starts no host worker")
	for size in [Vector2i(820,700),Vector2i(760,660),Vector2i(1024,800)]:
		root.size=size
		await process_frame
		await process_frame
		_inspect(root)
		if not output.is_empty():
			await RenderingServer.frame_post_draw
			var view := root.get_texture().get_image()
			check(view.save_png(output.path_join("setup-%dx%d.png"%[size.x,size.y]))==OK,"setup screenshot")
	_about()
	await process_frame
	check(root.get_child(root.get_child_count()-1) is AcceptDialog,"About opens without the runtime")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("setup-about.png"))==OK,"About screenshot")
	var about := root.get_child(root.get_child_count()-1)
	about.hide()
	var reader := InterfaceTheme.show_reference(root,"keyboard-controls.html")
	await process_frame
	check(reader.visible,"reader opens inside setup")
	check(reader.call("_plain",1974.0)=="1974","whole-number year has no decimal suffix")
	check(reader.call("_plain",6.32)=="6.32","fractional specifications retain precision")
	for map in reader.get("visuals").get("maps",[]):
		var native_path: String=reader.call("visual_path",map.get("native_file",""))
		check(native_path.ends_with(".png"),"native map includes rendered legend labels")
		var image := Image.load_from_file(native_path)
		check(image!=null and image.get_width()==2400,"native map is high-resolution")
	for path in ["../secret.png","https://remote/image.png","not-in-manifest.png","nested/image.svg","..\\secret.png"]:
		check(reader.call("visual_path",path).is_empty(),"reader rejects unsafe/unknown asset: "+path)
	for viewport in [Vector2i(760,660),Vector2i(820,700),Vector2i(1024,800)]:
		root.size=viewport
		reader.call("open_reader","Controls")
		await process_frame
		await process_frame
		check(reader.size.x<=root.size.x-48 and reader.size.y<=root.size.y-48,"reader fits setup at "+str(viewport))
		for tab in ["Controls","Scenarios","Vehicles","Credits"]:
			reader.call("show_section",tab)
			await process_frame
			await process_frame
			var content_stack = reader.get("body")
			var scroll := content_stack.get_parent() as ScrollContainer
			check(scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"reader never needs horizontal scrolling")
			check(content_stack.size.x<=scroll.size.x+1,"reader body fits width: "+tab+" "+str(viewport))
			check(content_stack.get_child_count()>0,"reader content present: "+tab)
			if not output.is_empty():
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(output.path_join("reader-%s-%dx%d.png"%[tab.to_lower(),viewport.x,viewport.y]))==OK,"reader screenshot")
	reader.call("show_section","Controls")
	reader.get("search").text="__no_such_entry__"
	reader.call("_render")
	check(_has_text(reader.get("body"),"No matching entries"),"search no-results is actionable")
	reader.set("visuals",{"models":[{"name":"missing","file":"missing-local.png","caption":"Unavailable study"}]})
	check(reader.call("visual_path","missing-local.png").is_empty(),"missing manifest asset rejected gracefully")
	reader.get("content").clear()
	reader.call("_render")
	check(_has_text(reader.get("body"),"missing or unreadable"),"missing manual gives reinstall recovery")
	reader.call("close_reader")
	check(not reader.visible and reader.get("body").get_child_count()==0,"reader closes and releases textures")
	var menu := preload("res://scripts/pc_play_menu.gd").new()
	menu.config_path=""
	menu.quality_config_path=""
	root.add_child(menu)
	menu.hide()
	menu.window_focused=true
	menu.release_keys=false
	check(menu.game_keys(["space"])==["space"],"held trigger normally passes")
	menu.open_reference("keyboard-controls.html")
	check(menu.game_keys(["space"]).is_empty(),"reader open releases held trigger")
	reader.call("close_reader")
	menu.window_focused=true
	check(menu.game_keys(["space"]).is_empty(),"reader close quarantines held trigger")
	check(menu.game_keys([]).is_empty() and not menu.release_keys,"release clears quarantine")
	check(menu.game_keys(["space"])==["space"],"fresh trigger resumes")
	menu.queue_free()
	var splash := preload("res://scripts/pc_startup_splash.gd").new()
	root.add_child(splash)
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.load_cover(ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir())
	splash.reference_selected.connect(func(name): InterfaceTheme.show_reference(root,name))
	await process_frame
	await process_frame
	check(splash.references.get_child_count()==3,"loading offers controls, field guide and original credits")
	if not output.is_empty():
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("loading-reference.png"))==OK,"loading screenshot")
	for index in 3:
		splash.references.get_child(index).pressed.emit()
		check(reader.visible and reader.section==["Controls","Scenarios","Credits"][index],"loading reference button: "+str(index))
		reader.close_reader()
	splash.references.get_child(2).pressed.emit()
	splash.finish()
	check(not splash.visible and reader.visible,"first guest frame cannot close an open loading guide")
	reader.close_reader()
	splash.queue_free()
	for error in failures:printerr("FAIL: "+error)
	print("PC_INTERFACE_REFERENCE: %d checks, %d errors"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

func _has_text(node: Node, words: String) -> bool:
	if node is Label and node.text.contains(words):return true
	for child in node.get_children():
		if _has_text(child,words):return true
	return false
