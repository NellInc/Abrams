extends "res://scripts/portable_setup.gd"
## UI-only fixture: no original game, host, import, profile or audio backend.
var checks := 0
var failures: Array[String] = []
var last_stage := "initialization"

func stage(description: String) -> void:
	last_stage=description
	print("PC_UI_STAGE: %dms %s (%d checks)"%[Time.get_ticks_msec(),description,checks])

func rendered_frame() -> Image:
	await process_frame
	# Use the existing test capture pattern when macOS occludes this window.
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	return root.get_texture().get_image()

func _request(_arguments: Array) -> void:
	installed=false
	play.disabled=true
	genesis.disabled=true
	pc.disabled=false
	message.text="Choose the supported original PC game folder to begin."

func _initialize() -> void:
	root.gui_embed_subwindows=true
	super._initialize()
	create_timer(60).timeout.connect(func(): printerr("FAIL: UI fixture deadline at "+last_stage+" (%d checks)"%checks); quit(1))
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
	stage("run begins")
	var args := OS.get_cmdline_user_args()
	var output := ""
	for i in args.size():
		if args[i]=="--output" and i+1<args.size(): output=args[i+1]
	check(not installed and play.disabled and genesis.disabled and not pc.disabled,"original-required controls")
	check(thread==null and not busy,"fixture starts no host worker")
	for size in [Vector2i(820,700),Vector2i(760,660),Vector2i(1024,800)]:
		stage("setup "+str(size))
		root.size=size
		await process_frame
		await process_frame
		_inspect(root)
		if not output.is_empty():
			var view := await rendered_frame()
			check(view.save_png(output.path_join("setup-%dx%d.png"%[size.x,size.y]))==OK,"setup screenshot")
	_about()
	await process_frame
	check(root.get_child(root.get_child_count()-1) is AcceptDialog,"About opens without the runtime")
	if not output.is_empty():
		var view := await rendered_frame()
		check(view.save_png(output.path_join("setup-about.png"))==OK,"About screenshot")
	var about := root.get_child(root.get_child_count()-1)
	about.hide()
	var reader := InterfaceTheme.show_reference(root,"keyboard-controls.html")
	stage("controls reader opened")
	await process_frame
	check(reader.visible,"reader opens inside setup")
	check(reader.call("_plain",1974.0)=="1974","whole-number year has no decimal suffix")
	check(reader.call("_plain",6.32)=="6.32","fractional specifications retain precision")
	for name in ["../manual-content.json","manual-content.json/../credits.json","/etc/passwd"]:
		check(reader.call("_read_json",name).is_empty(),"reader JSON rejects unlisted path: "+name)
	for map in reader.get("visuals").get("maps",[]):
		var native_path: String=reader.call("visual_path",map.get("native_file",""))
		check(native_path.ends_with(".png"),"native map includes rendered legend labels")
		var image := Image.load_from_file(native_path)
		check(image!=null and image.get_width()==2400,"native map is high-resolution")
	check(reader.get("visuals").get("manual_maps",[]).size()==8,"all eight original manual maps are available")
	for map in reader.get("visuals").get("manual_maps",[]):
		check(not reader.call("visual_path",map.get("file","")).is_empty(),"original manual map is manifest-listed and local")
	for path in ["../secret.png","https://remote/image.png","not-in-manifest.png","nested/image.svg","..\\secret.png"]:
		check(reader.call("visual_path",path).is_empty(),"reader rejects unsafe/unknown asset: "+path)
	for viewport in [Vector2i(760,660),Vector2i(820,700),Vector2i(1024,800)]:
		stage("viewport "+str(viewport))
		root.size=viewport
		reader.call("open_reader","Controls")
		await process_frame
		await process_frame
		check(reader.size.x<=root.size.x-48 and reader.size.y<=root.size.y-48,"reader fits setup at "+str(viewport))
		for tab in ["Controls","Scenarios","Vehicles","Credits"]:
			stage("render "+tab+" "+str(viewport))
			reader.call("show_section",tab)
			stage("render returned "+tab+" "+str(viewport))
			await process_frame
			await process_frame
			var content_stack = reader.get("body")
			var scroll := content_stack.get_parent() as ScrollContainer
			check(scroll.horizontal_scroll_mode==ScrollContainer.SCROLL_MODE_DISABLED,"reader never needs horizontal scrolling")
			check(content_stack.size.x<=scroll.size.x+1,"reader body fits width: "+tab+" "+str(viewport))
			check(content_stack.get_child_count()>0,"reader content present: "+tab)
			if not output.is_empty():
				stage("flush draw "+tab+" "+str(viewport))
				var view := await rendered_frame()
				stage("capture "+tab+" "+str(viewport))
				check(view.save_png(output.path_join("reader-%s-%dx%d.png"%[tab.to_lower(),viewport.x,viewport.y]))==OK,"reader screenshot")
				stage("captured "+tab+" "+str(viewport))
	# Inspect every scenario's two map illustrations through the actual reader.
	root.size=Vector2i(1024,960)
	reader.call("open_reader","Scenarios")
	for map in reader.get("visuals").get("manual_maps",[]):
		var scenario: String=str(map.get("name",""))
		stage("scenario map "+scenario)
		reader.get("search").text=scenario
		reader.call("_render")
		await process_frame
		await process_frame
		var pictures: Array[TextureRect]=[]
		var scenario_stack: VBoxContainer=null
		for child in reader.get("body").get_children():
			if child is VBoxContainer and child.get_child_count()>0 and child.get_child(0) is Label and child.get_child(0).text==scenario:
				scenario_stack=child
		check(scenario_stack!=null,"exact scenario entry selected: "+scenario)
		if scenario_stack!=null:
			for child in scenario_stack.get_children():
				if child is TextureRect and not child.is_queued_for_deletion():pictures.append(child)
		check(pictures.size()==2,"manual and PC terrain maps displayed: "+scenario)
		if pictures.size()==2:
			check(pictures[0].texture.get_width()==1254 and pictures[0].texture.get_height()==1254,"restored manual map resolution: "+scenario)
			check(pictures[1].texture.get_width()==2400,"PC terrain map retained: "+scenario)
		if not pictures.is_empty():
			reader.get("body").get_parent().scroll_vertical=maxi(0,int(scenario_stack.position.y+pictures[0].position.y)-12)
		await process_frame
		if not output.is_empty():
			var view := await rendered_frame()
			var filename: String=str(map.get("file","")).trim_prefix("manual-map-")
			check(view.save_png(output.path_join("scenario-"+filename))==OK,"complete scenario map screenshot: "+scenario)
	stage("vehicle illustrations reuse decoded textures")
	reader.call("show_section","Vehicles")
	var picture: TextureRect=_first_picture(reader.get("body"))
	check(picture!=null,"vehicle illustration displayed")
	reader.call("_render")
	var again: TextureRect=_first_picture(reader.get("body"))
	check(picture!=null and again!=null and again!=picture and again.texture==picture.texture,"search re-render reuses the decoded illustration")
	stage("reader recovery and held input")
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
	check(not reader.visible and reader.get("body").get_child_count()==0 and reader.get("_textures").is_empty(),"reader closes and releases textures")
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
	var tab := InputEventKey.new()
	tab.keycode=KEY_TAB;tab.pressed=true
	check(not menu.handle_shortcut(tab) and menu.speed==1,"reference Tab navigation cannot accelerate the game")
	reader.call("close_reader")
	menu.window_focused=true
	check(menu.game_keys(["space"]).is_empty(),"reader close quarantines held trigger")
	check(menu.game_keys([]).is_empty() and not menu.release_keys,"release clears quarantine")
	check(menu.game_keys(["space"])==["space"],"fresh trigger resumes")
	menu.queue_free()
	var splash := preload("res://scripts/pc_startup_splash.gd").new()
	stage("loading references")
	root.add_child(splash)
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.load_cover(ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir())
	splash.reference_selected.connect(func(name): InterfaceTheme.show_reference(root,name))
	await process_frame
	await process_frame
	check(splash.references.get_child_count()==3,"loading offers controls, field guide and original credits")
	if not output.is_empty():
		var view := await rendered_frame()
		check(view.save_png(output.path_join("loading-reference.png"))==OK,"loading screenshot")
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

func _first_picture(node: Node) -> TextureRect:
	if node is TextureRect and not node.is_queued_for_deletion():return node
	for child in node.get_children():
		var found := _first_picture(child)
		if found!=null:return found
	return null

func _has_text(node: Node, words: String) -> bool:
	if node is Label and node.text.contains(words):return true
	for child in node.get_children():
		if _has_text(child,words):return true
	return false
