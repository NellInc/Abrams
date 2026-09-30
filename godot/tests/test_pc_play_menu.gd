extends SceneTree
const Menu = preload("res://scripts/pc_play_menu.gd")
var errors: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)
func _initialize() -> void:
	create_timer(60).timeout.connect(func(): printerr("FAIL: play menu fixture deadline"); quit(1))
	run.call_deferred()
func run() -> void:
	var menu := Menu.new()
	menu.config_path=""
	menu.quality_config_path=""
	root.add_child(menu)
	var choices: Array=[]
	menu.graphics_selected.connect(func(mode):choices.append(["graphics",mode]))
	menu.quality_selected.connect(func(msaa,anisotropy):choices.append(["quality",msaa,anisotropy]))
	menu.speed_selected.connect(func(speed):choices.append(["speed",speed]))
	menu.state_requested.connect(func(op,slot):choices.append([op,slot]))
	check(menu.get_menu_count()==4,"Audio, Session, Graphics and Help outside source pixels")
	check(menu.settings.music==70 and menu.menus.has("music"),"independent music mix")
	check(menu.quality=={"msaa":4,"anisotropy":16},"4x MSAA and 16x anisotropy defaults")
	for key in menu.QUALITY_LEVELS:
		for samples in menu.QUALITY_LEVELS[key]:
			check(menu.choose_quality(key,samples) and menu.quality[key]==samples,"quality selection: %s %d"%[key,samples])
			check(choices[-1]==["quality",menu.quality.msaa,menu.quality.anisotropy],"quality signal carries both settings")
	check(not menu.choose_quality("msaa",16) and not menu.choose_quality("anisotropy",3) and not menu.choose_quality("unknown",4),"unsupported quality selections rejected")
	for key in menu.quality_menus:
		menu.quality_menus[key].id_pressed.emit(0)
		check(menu.quality[key]==0 and choices[-1]==["quality",menu.quality.msaa,menu.quality.anisotropy],"submenu dispatch: "+key)
	for mode in ["ega","genesis","upscaled"]:
		check(menu.choose_graphics(mode) and choices[-1]==["graphics",mode],"live graphics signal: "+mode)
	check(not menu.choose_graphics("modern") and menu.graphics_mode=="upscaled","unavailable Modern never pretends to render")
	check(menu.graphics_popup.is_item_disabled(3),"Modern menu explicitly disabled")
	menu.modern_available=true
	menu.refresh_controls()
	check(not menu.graphics_popup.is_item_disabled(3),"preloaded Modern enables its menu item")
	check(menu.available_graphics_modes()==["ega","genesis","upscaled","modern"],"four-mode order")
	check(menu.choose_graphics("modern") and choices[-1]==["graphics","modern"],"Modern dispatches through existing controls")
	menu.genesis_available=false
	check(menu.available_graphics_modes()==["ega","upscaled","modern"],"PC-only cycle includes independent Modern")
	menu.modern_available=false
	menu.genesis_available=true
	menu.choose_graphics("upscaled")
	menu.refresh_controls()
	for speed in [2,4,8,1]:check(menu.choose_speed(speed) and choices[-1]==["speed",speed],"speed selection")
	check(not menu.choose_speed(3) and menu.speed==1,"unsupported speed rejected")
	check(not menu.request_state("load_state",1),"empty slot cannot load")
	check(not menu.request_state("save_state",0),"automatic recovery cannot be overwritten by save menu")
	check(menu.request_state("save_state",1) and choices[-1]==["save_state",1],"save request")
	check(menu.busy and not menu.choose_speed(4) and not menu.request_state("save_state",2),"one state operation at a time")
	menu.set_state_status([{"slot":0},{"slot":1}],"Saved slot 1")
	check(not menu.busy and menu.request_state("load_state",0),"pre-load recovery can be loaded")
	menu.set_state_status([{"slot":1}],"Loaded slot 1")
	check(menu.load_popup.is_item_disabled(menu.load_popup.get_item_index(0)),"missing recovery remains disabled")
	for popup in [menu.session_popup,menu.save_popup,menu.load_popup,menu.speed_popup,menu.graphics_popup,menu.help_popup]+menu.quality_menus.values():
		for i in popup.item_count:
			check(popup.get_item_accelerator(i)==0 and popup.get_item_shortcut(i)==null,"no original key intercepted")
		popup.about_to_popup.emit()
		check(menu.game_keys(["space","up"]).is_empty(),"native menu input cannot steer/fire")
		popup.popup_hide.emit()
		check(menu.game_keys(["return"]).is_empty(),"closing menu key held until release")
		menu.game_keys([])
		check(menu.game_keys(["f1"])==["f1"],"original controls restored")
	for error in errors:printerr("FAIL: "+error)
	print("PC_PLAY_MENU: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
