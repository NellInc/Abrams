extends SceneTree
const Menu = preload("res://scripts/pc_play_menu.gd")
var errors: Array[String] = []
var checks := 0
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: errors.append(label)
func _initialize() -> void:
	root.gui_embed_subwindows=true
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
	var restored_theme:=preload("res://scripts/pc_interface_theme.gd").build()
	for cycle in 2:
		check(menu.choose_hud_style("tactical"),"Tactical HUD selection")
		var themed:Array=[menu.popup,menu.session_popup,menu.save_popup,menu.load_popup,menu.speed_popup,menu.graphics_popup,menu.hud_popup,menu.help_popup]+menu.menus.values()+menu.quality_menus.values()
		for child:PopupMenu in themed:
			check(child.get_theme_stylebox("hover","PopupMenu")==menu.theme.get_stylebox("hover","PopupMenu"),"all submenus inherit Tactical focus: "+child.name)
			check(child.get_theme_color("font_disabled_color","PopupMenu")==Color("a7b09a"),"readable olive secondary text: "+child.name)
			check(child.get_theme_constant("v_separation","PopupMenu")==10,"consistent submenu spacing: "+child.name)
		var hover:=menu.theme.get_stylebox("hover","PopupMenu") as StyleBoxFlat
		check(hover.bg_color==Color("253827") and hover.border_color==Color("65764e"),"pointer and keyboard use the same olive focus well")
		check(menu.theme.get_stylebox("separator","PopupMenu") is StyleBoxLine,"quiet aligned section separators")
		check(menu.theme.get_stylebox("normal","MenuBar").content_margin_top==5 and menu.theme.get_font_size("font_size","MenuBar")==18,"game viewport allocation preserved")
		for name in ["radio_checked","radio_unchecked","radio_checked_disabled","submenu","submenu_mirrored"]:
			var original_icon:=ThemeDB.get_default_theme().get_icon(name,"PopupMenu").get_image()
			var icon:=menu.theme.get_icon(name,"PopupMenu").get_image()
			check(icon.get_size()==original_icon.get_size(),"engine icon dimensions retained: "+name)
			var valid:=true
			var maximum_error:=0.0
			var tint:=Color("e7b566") if name=="radio_checked" else Color("a7b09a")
			for y in icon.get_height():
				for x in icon.get_width():
					var pixel:=icon.get_pixel(x,y)
					var original_pixel:=original_icon.get_pixel(x,y)
					var luminance:=original_pixel.r*0.2126+original_pixel.g*0.7152+original_pixel.b*0.0722
					var expected:=Color(tint.r*luminance,tint.g*luminance,tint.b*luminance,original_pixel.a)
					maximum_error=maxf(maximum_error,maxf(absf(pixel.r-expected.r),maxf(absf(pixel.g-expected.g),absf(pixel.b-expected.b))))
					if pixel.a!=original_pixel.a:valid=false
			# The texture is RGBA8, so float-derived tint channels quantize to bytes.
			valid=valid and maximum_error<=1.0/255.0+0.000001
			print("MENU_ICON_QUANTIZATION: %s %.6f (limit %.6f)"%[name,maximum_error,1.0/255.0])
			check(valid,"selection tint preserves the engine icon's tones and antialiased mask: "+name)
		menu.load_popup.about_to_popup.emit()
		check(menu.load_popup.is_item_separator(5) and menu.load_popup.is_item_disabled(5),"empty Tactical Load menu cannot focus its separator")
		menu.load_popup.popup_hide.emit();menu.game_keys([])
		check(menu.choose_hud_style("restored"),"Restored HUD selection")
		menu.load_popup.about_to_popup.emit()
		check(not menu.load_popup.is_item_disabled(5),"Restored retains the incumbent separator flags")
		menu.load_popup.popup_hide.emit();menu.game_keys([])
		check(not menu._tactical_bar.visible and not menu.theme.has_stylebox("hover","PopupMenu") and not menu.theme.has_icon("radio_checked","PopupMenu") and not menu.theme.has_constant("v_separation","PopupMenu"),"Restored clears every Tactical-only override")
		check(menu.theme.get_color("font_disabled_color","PopupMenu")==restored_theme.get_color("font_disabled_color","PopupMenu") and menu.theme.get_stylebox("panel","PopupMenu").bg_color==restored_theme.get_stylebox("panel","PopupMenu").bg_color,"Restored returns the exact incumbent colours")
	check(not menu.choose_hud_style("unknown") and menu.hud_style=="restored","unsupported HUD rejected")
	# The reusable reader follows the HUD independently of the 3D graphics mode.
	menu.choose_hud_style("tactical")
	menu.open_reference("keyboard-controls.html")
	var reader := root.get_node("PlayerReference")
	check(reader.tactical and reader.visible and reader.search.clear_button_enabled,"Tactical Help inherits its HUD and offers clear search")
	check(reader.theme.get_color("caret_color","LineEdit")==Color("e7b566") and reader.theme.get_color("font_placeholder_color","LineEdit")==Color("a7b09a"),"Tactical search caret and placeholder use the reader palette")
	check(reader.theme.get_stylebox("pressed","Button").border_color==Color("e7b566"),"active reference section has an amber border")
	reader.content={"remaster_controls":[{"name":"Ctrl+Alt+Shift+L","description":"Undo the most recent load without changing any original game key."}],"vehicles":[{"name":"Abrams","description":"Vehicle reference","specs":{"maximum_speed_kmh":72,"primary_armament":"105 mm gun"}}]}
	reader._render()
	for extent in [Vector2i(1440,810),Vector2i(850,478),Vector2i(640,360)]:
		root.size=extent
		await process_frame
		await process_frame
		check(reader.size.x<=extent.x-32 and reader.size.y<=extent.y-64,"Tactical reader fits with title bar: "+str(extent))
		check(reader.body.size.x<=reader.scroll.size.x+1 and reader.scroll.size.y>=48,"Tactical content fits and stays scrollable: "+str(extent))
	reader.scroll.scroll_vertical=100
	reader.show_section("Vehicles")
	check(reader.scroll.scroll_vertical==0 and reader.tabs.get_child(2).button_pressed,"section changes reset Tactical scroll and select the correct tab")
	reader.search.text="__no_match__";reader._render()
	check(reader.body.get_child_count()==1 and reader.body.get_child(0).text.begins_with("No matching entries"),"Tactical empty search retains recovery guidance")
	reader.search.text="";reader._render()
	check(reader.body.get_child_count()>1,"clearing search restores reference entries")
	menu.window_focused=true;menu.release_keys=false
	check(menu.game_keys(["space"]).is_empty(),"Tactical reader blocks held game input")
	var tab_key:=InputEventKey.new();tab_key.keycode=KEY_TAB;tab_key.pressed=true
	check(not menu.handle_shortcut(tab_key) and menu.speed==1,"reader keyboard navigation cannot accelerate gameplay")
	root.size=Vector2i(1440,1080)
	menu.choose_hud_style("restored")
	check(not reader.tactical and not reader.search.clear_button_enabled and reader.min_size==Vector2i(640,480),"open reader switches back to incumbent sizing and search")
	check(reader.position==(root.size-reader.size)/2,"switching the open reader back recentres its original layout")
	root.size=Vector2i(1280,960)
	await process_frame
	check(reader.position==(root.size-reader.size)/2,"asynchronous Web canvas resize completes the open reader switchback")
	check(not reader.theme.has_color("caret_color","LineEdit") and not reader.theme.has_stylebox("scroll","VScrollBar") and reader.theme.get_stylebox("panel","PanelContainer").bg_color==restored_theme.get_stylebox("panel","PanelContainer").bg_color,"Modernized reader clears every Tactical-only theme override")
	reader.close_reader()
	check(not reader._restore_on_resize,"closing the reader clears transition-only resize handling")
	menu.window_focused=true
	check(menu.game_keys(["space"]).is_empty(),"reader close quarantines the held trigger")
	menu.game_keys([])
	check(menu.game_keys(["space"])==["space"],"fresh trigger resumes after reader close")
	menu.choose_hud_style("tactical")
	menu.open_reference("credits")
	check(reader.tactical and reader.section=="Credits","reopening the retained reader uses the current HUD")
	reader.close_reader()
	preload("res://scripts/pc_interface_theme.gd").show_reference(root,"keyboard-controls.html")
	check(not reader.tactical,"setup caller without a style explicitly restores the incumbent reader")
	reader.close_reader()
	menu.choose_hud_style("restored");menu.game_keys([])
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
	for mode in ["ega","ega_upscaled","genesis","upscaled"]:
		check(menu.choose_graphics(mode) and choices[-1]==["graphics",mode],"live graphics signal: "+mode)
	check(not menu.choose_graphics("modern") and not menu.choose_graphics("tactical") and menu.graphics_mode=="upscaled","unavailable Modern and Tactical never pretend to render")
	check(menu.default_graphics_mode()=="upscaled","without the Modern catalogue the default view falls back to Genesis Upscaled")
	check(menu.DEFAULT_HUD_STYLE=="tactical","Tactical HUD is the out-of-the-box HUD style")
	check(menu.graphics_popup.is_item_disabled(menu.MODES.find("modern")) and menu.graphics_popup.is_item_disabled(menu.MODES.find("tactical")),"Modern and Tactical menu items explicitly disabled")
	menu.modern_available=true
	menu.refresh_controls()
	check(not menu.graphics_popup.is_item_disabled(menu.MODES.find("modern")) and not menu.graphics_popup.is_item_disabled(menu.MODES.find("tactical")),"preloaded Modern assets enable both graphics profiles")
	check(menu.available_graphics_modes()==["ega","ega_upscaled","genesis","upscaled","modern","tactical"],"six-mode order with original-palette upscaling")
	check(menu.default_graphics_mode()=="tactical","Tactical is the default view whenever the Modern catalogue loads")
	check(menu.graphics_popup.get_item_text(menu.MODES.find("upscaled"))=="Genesis Upscaled (remastered)","generated Genesis upscaling has explicit label and stable id")
	check(menu.graphics_popup.get_item_text(menu.MODES.find("ega_upscaled"))=="EGA Upscaled (original colours)","original-palette EGA upscaling remains independently labelled")
	check(menu.choose_graphics("modern") and choices[-1]==["graphics","modern"],"Modern dispatches through existing controls")
	check(menu.choose_graphics("tactical") and choices[-1]==["graphics","tactical"],"Tactical dispatches independently of HUD Style")
	menu.genesis_available=false
	check(menu.available_graphics_modes()==["ega","ega_upscaled","upscaled","modern","tactical"],"PC-only cycle includes EGA upscaling, Modern and Tactical")
	menu.refresh_controls()
	check(menu.graphics_popup.get_item_text(menu.MODES.find("genesis"))=="Genesis (requires optional import)","native PC-only install asks for the optional import")
	check(menu.genesis_label(false,true,true)=="Genesis (desktop edition only)" and menu.genesis_label(false,false,true)=="Genesis (requires optional import)","web ROM owners are not asked to import again")
	check(menu.genesis_label(false,true,false)=="Genesis (requires optional import)" and menu.genesis_label(true,true,true)=="Genesis (original artwork)","desktop damaged import and loaded pack keep their labels")
	menu.presentation_note="Genesis cockpit art disabled: cockpit-v2 gunner-genesis-v1.png hash mismatch"
	menu.refresh_controls()
	check(menu.graphics_popup.get_item_text(menu.graphics_popup.get_item_index(101))==menu.presentation_note,"damaged import reason visible in the Graphics menu")
	menu.presentation_note=""
	menu.refresh_controls()
	check(menu.graphics_popup.get_item_text(menu.graphics_popup.get_item_index(101)).begins_with("Antialiasing applies"),"ordinary quality footer restored")
	menu.modern_available=false
	menu.genesis_available=true
	menu.choose_graphics("upscaled")
	menu.refresh_controls()
	# A viewer that cannot show a mode resets graphics_mode; callers must see the rejection.
	var notices: Array=[]
	menu.control_notice.connect(func(message):notices.append(message))
	var reject := func(_mode):menu.graphics_mode="upscaled"
	menu.graphics_selected.connect(reject)
	check(not menu.choose_graphics("genesis") and menu.graphics_mode=="upscaled" and notices[-1]=="Genesis graphics are unavailable","viewer rejection is reported, not claimed")
	menu.graphics_selected.disconnect(reject)
	for speed in [8,1]:check(menu.choose_speed(speed) and choices[-1]==["speed",speed],"speed selection")
	check(menu.speed_popup.item_count==2,"only normal and 8x speeds offered")
	check(not menu.choose_speed(2) and not menu.choose_speed(4) and not menu.choose_speed(3) and menu.speed==1,"unsupported speed rejected")
	check(not menu.request_state("load_state",1),"empty slot cannot load")
	check(not menu.request_state("save_state",0),"automatic recovery cannot be overwritten by save menu")
	check(menu.request_state("save_state",1) and choices[-1]==["save_state",1],"save request")
	check(menu.busy and not menu.choose_speed(8) and not menu.request_state("save_state",2),"one state operation at a time")
	menu.set_state_status([{"slot":0},{"slot":1}],"Saved slot 1")
	check(not menu.busy and menu.request_state("load_state",0),"pre-load recovery can be loaded")
	menu.set_state_status([{"slot":1}],"Loaded slot 1")
	check(menu.load_popup.is_item_disabled(menu.load_popup.get_item_index(0)),"missing recovery remains disabled")
	# An overwritten archive is offered only while the host lists it.
	var plain_items:=menu.load_popup.item_count
	check(menu.load_popup.get_item_index(menu.PREVIOUS_ID+1)<0 and not menu.request_state("load_previous",1),"unlisted overwritten archive is neither shown nor requested")
	menu.set_state_status([{"slot":1,"saved_at":"2026-10-15 10:00:00","previous_saved_at":"2026-10-15 09:00:00"},{"slot":3,"exists":false,"previous_saved_at":"2026-10-14 08:00:00"}],"Saved slot 1")
	var previous_index:=menu.load_popup.get_item_index(menu.PREVIOUS_ID+1)
	check(previous_index>=0 and menu.load_popup.get_item_text(previous_index)=="Overwritten slot 1 (2026-10-15 09:00:00)" and not menu.load_popup.is_item_disabled(previous_index),"listed overwritten archive names its save time")
	check(menu.load_popup.get_item_index(menu.PREVIOUS_ID+3)>=0 and menu.load_popup.get_item_index(menu.PREVIOUS_ID+2)<0,"only listed archives appear")
	check(menu.load_popup.is_item_separator(menu.load_popup.get_item_index(menu.PREVIOUS_ID)) and menu.load_popup.item_count==plain_items+3,"archives sit after one divider")
	menu.refresh_controls()
	check(menu.load_popup.item_count==plain_items+3,"refresh never duplicates archive items")
	check(not menu.request_state("load_previous",0) and not menu.request_state("load_previous",2),"recovery and unlisted slots have no archive request")
	menu.load_popup.id_pressed.emit(menu.PREVIOUS_ID+1)
	check(choices[-1]==["load_previous",1] and menu.busy and menu.state_message=="Loading state...","archive item requests that slot's overwritten save")
	check(menu.load_popup.is_item_disabled(menu.load_popup.get_item_index(menu.PREVIOUS_ID+1)),"archive item disabled while busy")
	menu.load_popup.id_pressed.emit(1)
	check(choices[-1]==["load_previous",1],"busy menu cannot queue a second load")
	menu.set_state_status([{"slot":1}],"Loaded slot 1")
	check(menu.load_popup.item_count==plain_items and menu.load_popup.get_item_index(menu.PREVIOUS_ID)<0,"archives disappear when the host stops listing them")
	menu.load_popup.id_pressed.emit(1)
	check(choices[-1]==["load_state",1],"numbered load item still loads its slot")
	menu.set_state_status([{"slot":1}],"Loaded slot 1")
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
