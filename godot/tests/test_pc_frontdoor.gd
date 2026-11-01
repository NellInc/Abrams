extends SceneTree
const Route=preload("res://scripts/pc_frontdoor_route.gd")
const Menu=preload("res://scripts/pc_play_menu.gd")
var checks:=0
var errors:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label)
func run(source:Image,text:String,rect:Array,foreground:=1)->Dictionary:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	hash.update(source.get_region(Rect2i(rect[0],rect[1],rect[2],rect[3])).get_data())
	return {"text":text,"rect":rect.map(func(value):return float(value)),"foreground":foreground,"pixel_sha256":hash.finish().hex_encode()}
func check_settings_slider()->void:
	# A drag applies gains live but writes the mix and rebuilds the menus once.
	var path:="user://frontdoor-slider-check-%d.cfg"%OS.get_process_id()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var menu:=Menu.new();menu.config_path=path;menu.quality_config_path=""
	root.add_child(menu)
	var mixes:=[0]
	menu.mix_changed.connect(func():mixes[0]+=1)
	var cover:=preload("res://scripts/pc_frontdoor.gd").new()
	cover.menu=menu
	var title:=Label.new()
	var slider:HSlider=cover.audio_slider("master",title)
	# Range emits value_changed only inside the tree, as on the Settings page.
	root.add_child(slider)
	slider.drag_started.emit()
	slider.value=40;slider.value=30
	check(menu.settings.master==30 and mixes[0]==2 and title.text.ends_with(": 30%"),"dragging applies each gain live")
	check(not FileAccess.file_exists(path) and menu.popup.get_item_text(0)=="Master volume (100%)","dragging neither writes the mix nor rebuilds menus")
	slider.drag_ended.emit(true)
	var saved:=ConfigFile.new()
	check(saved.load(path)==OK and saved.get_value("audio","master")==30 and menu.popup.get_item_text(0)=="Master volume (30%)","release saves the final gain once and refreshes menus")
	slider.value=55
	saved=ConfigFile.new()
	check(saved.load(path)==OK and saved.get_value("audio","master")==55,"a click or key change without a drag saves at once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	root.remove_child(slider)
	cover.free();title.free();slider.free()
	root.remove_child(menu);menu.free()

func check_artwork_viewer()->void:
	# The Web edition ships remasters without the original Genesis captures.
	var empty:="user://frontdoor-art-check-%d"%OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(empty)
	var scene:=load("res://scenes/art_review.tscn")
	var web=scene.instantiate();web.embedded=true;web.art_root=ProjectSettings.globalize_path(empty)
	root.add_child(web)
	check(not web.can_compare and not web.controls[2].node.visible,"no originals: Extras hides the compare toggle")
	web._toggle()
	check(not web.original,"no originals: Tab cannot show missing captures")
	check(web.errors.values().all(func(text):return text=="This artwork is not included in this edition."),"players never see a developer file path")
	root.remove_child(web);web.free()
	var review=scene.instantiate();review.art_root=ProjectSettings.globalize_path(empty)
	root.add_child(review)
	check(review.can_compare and str(review.errors.values()[0]).begins_with("Local artwork missing:"),"standalone review tool keeps its diagnostic")
	root.remove_child(review);review.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(empty))
	var directory:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	if FileAccess.file_exists(directory.path_join("local-art/genesis/source/title-original.png")):
		var local=scene.instantiate();local.embedded=true
		root.add_child(local)
		check(local.can_compare and local.controls[2].node.visible,"originals present: Extras keeps the compare toggle")
		root.remove_child(local);local.free()

func _initialize()->void:
	var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.BLUE)
	var program:={"name":"START","psp":477,"load_segment":493}
	var packet:={"frontend_program":program,"text_runs":[]}
	for i in 4:packet.text_runs.append(run(source,Route.ROOT_LABELS[i],Route.ROOT_RECTS[i],4 if i==0 else 1))
	var route:=Route.new()
	check(route.classify(source,program,packet).selected==0,"verified root highlight")
	var malformed:=packet.duplicate(true)
	malformed.text_runs[0].pixel_sha256="bad"
	check(route.classify(source,program,malformed).selected==-1,"pixel mismatch rejected")
	malformed=packet.duplicate(true);malformed.text_runs[0].rect=[21,12,64,8]
	check(route.classify(source,program,malformed).selected==-1,"wrong root position rejected")
	malformed=packet.duplicate(true);malformed.text_runs[1].foreground=4
	check(route.classify(source,program,malformed).selected==-1,"two highlights rejected")
	malformed=packet.duplicate(true);malformed.frontend_program={"name":"START","psp":999}
	check(route.classify(source,program,malformed).selected==-1,"unpaired program rejected")
	var campaign:=packet.duplicate(true)
	campaign.text_runs.append(run(source,"BEGIN",[116,24,40,8],4))
	check(route.classify(source,program,campaign)=={"selected":-1,"submenu":"campaign"},"Campaign dropdown never counts as root")
	campaign.text_runs[-1].pixel_sha256="bad"
	check(route.classify(source,program,campaign).selected==-1,"invalid extra modal run prevents root recognition")
	var name:=packet.duplicate(true);name.text_runs.append(run(source,"NAME:",[84,24,40,8]))
	check(route.classify(source,program,name).selected==-1,"campaign name input never counts as root")
	route.phase="playing"
	route.observe(source,program,packet,100)
	route.observe(source,program,packet,189)
	check(not route.return_ready,"transitional root remains original")
	route.observe(source,program,packet,190)
	check(route.return_ready,"settled source root may return to cover")
	# A load restoring an earlier sequence on the same root restarts the dwell.
	route.observe(source,program,packet,40)
	check(not route.return_ready,"restored earlier sequence never counts backwards")
	route.observe(source,program,packet,129)
	check(not route.return_ready,"restored root still waits its full dwell")
	route.observe(source,program,packet,130)
	check(route.return_ready,"restored root returns after its own dwell")
	route.reset_observation()
	route.observe(source,program,packet,5000)
	check(not route.return_ready,"a timeline reset restarts the dwell at a later sequence")
	route.rest()
	check(route.begin("campaign"),"campaign selection begins")
	check(route.next_step()==[3,["right"]],"moves toward observed selection")
	check(route.next_step()==[30,[]],"releases arrow before re-observation")
	packet.text_runs[0].foreground=1;packet.text_runs[1].foreground=4
	route.observe(source,program,packet,220)
	check(route.next_step()==[3,["return"]],"opens only verified selected Campaign")
	check(route.next_step()==[60,[]],"releases Enter without selecting Begin")
	campaign=packet.duplicate(true);campaign.text_runs.append(run(source,"BEGIN",[116,24,40,8],4))
	route.observe(source,program,campaign,283)
	check(route.next_step().is_empty() and route.phase=="playing","hands original Campaign dropdown to player")
	var boot:=Route.new();boot.begin("scenario")
	var canonical:Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_boot_steps.json"))
	check(Route.BOOT_STEPS.size()==10,"runtime bootstrap has exactly the observed prefix")
	for i in 10:check(Route.BOOT_STEPS[i][0]==int(canonical[i][0]) and Route.BOOT_STEPS[i][1]==canonical[i][1],"runtime bootstrap matches observed fixture")
	while not boot.steps.is_empty():check(boot.next_step()[0]<=60,"bounded original-frame batch")
	boot.next_step()
	check(boot.phase=="fallback" and boot.steps.is_empty(),"boot mismatch stops keys without retry")
	var menu:=Menu.new()
	menu.config_path="";menu.quality_config_path="";menu.frontdoor_active=true
	var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true
	check(not menu.handle_shortcut(tab),"Tab belongs to cover keyboard focus")
	check(not menu.request_state("save_state",1) and not menu.busy,"cover blocks save mutations")
	check(not menu.request_state("load_state",0),"cover blocks hidden loads")
	check(not menu.choose_speed(8),"cover blocks hidden fast-forward")
	menu.free()
	# Scene-tree checks need _ready, which runs only after initialization.
	finish.call_deferred()

func finish()->void:
	check_settings_slider()
	check_artwork_viewer()
	print("PC_FRONTDOOR: %d checks, %d errors"%[checks,errors.size()])
	for error in errors:printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)
