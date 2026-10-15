extends "res://scripts/pc_audio_menu.gd"
## Remaster controls live outside the source framebuffer; Tab toggles acceleration.
signal graphics_selected(mode: String)
signal hud_style_selected(style: String)
signal quality_selected(msaa_samples: int, anisotropic_samples: int)
signal speed_selected(multiplier: int)
signal state_requested(operation: String, slot: int)
signal control_notice(message: String)
var shortcut_is_macos := _uses_macos_shortcuts()
var shortcut_keys: Array = []
const MODES := ["ega","ega_upscaled","genesis","upscaled","modern","tactical"]
var graphics_mode := "upscaled"
# Saved intent stays independent of temporary startup overrides and fallback.
var preferred_graphics_mode := ""
var hud_style := "restored"
const HUD_STYLES := ["restored","tactical"]
const QUALITY_DEFAULTS := {"msaa":4,"anisotropy":16}
const QUALITY_LEVELS := {"msaa":[0,2,4,8],"anisotropy":[0,2,4,8,16]}
var quality: Dictionary = QUALITY_DEFAULTS.duplicate()
var quality_config_path := "user://pc_graphics.cfg"
var quality_menus: Dictionary = {}
var quality_error := ""
var genesis_available := true
var modern_available := false
var speed := 1
var busy := false
var graphics_popup: PopupMenu
var hud_popup: PopupMenu
var session_popup: PopupMenu
var speed_popup: PopupMenu
var save_popup: PopupMenu
var load_popup: PopupMenu
var state_slots: Array = []
var state_message := "Save states include the campaign disk. Loading rewinds both."
var help_popup: PopupMenu
var _styled_hud := ""
var _tactical_bar := ColorRect.new()

func _init() -> void:
	# Off-tree menu instances own this child too, including settings readers.
	add_child(_tactical_bar)

func _apply_hud_theme() -> void:
	if _styled_hud==hud_style: return
	_styled_hud=hud_style
	var reader := get_tree().root.get_node_or_null("PlayerReference") if is_inside_tree() else null
	if reader!=null:reader.call("set_hud_style",hud_style)
	theme=preload("res://scripts/pc_interface_theme.gd").build()
	_tactical_bar.visible=hud_style=="tactical"
	if hud_style!="tactical": return
	for type in ["MenuBar","PopupMenu"]:
		theme.set_font("font",type,preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf"))
		theme.set_font_size("font_size",type,18)
		for name in ["font_color","font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:
			theme.set_color(name,type,Color("e3e4cd"))
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=Color("253827") if state in ["hover","pressed","hover_pressed"] else Color("0c1812")
		style.content_margin_left=12;style.content_margin_right=12
		style.content_margin_top=5;style.content_margin_bottom=5
		style.border_width_bottom=1
		style.border_color=Color("e7b566") if state in ["hover","pressed","hover_pressed"] else Color("344733")
		theme.set_stylebox(state,"MenuBar",style)
	var panel:=preload("res://scripts/pc_interface_theme.gd").surface()
	panel.bg_color=Color("101e16");panel.border_color=Color("61785b")
	panel.content_margin_left=14;panel.content_margin_right=14
	panel.content_margin_top=12;panel.content_margin_bottom=12
	theme.set_stylebox("panel","PopupMenu",panel)
	# One popup theme is inherited by every audio/session/graphics/help submenu.
	# Preserve the bar's 32px allocation and all original menu IDs/input routing.
	theme.set_color("font_hover_color","PopupMenu",Color("f3cf8e"))
	for name in ["font_disabled_color","font_accelerator_color","font_separator_color"]:
		theme.set_color(name,"PopupMenu",Color("a7b09a"))
	theme.set_constant("v_separation","PopupMenu",10)
	theme.set_constant("h_separation","PopupMenu",10)
	theme.set_constant("item_start_padding","PopupMenu",4)
	theme.set_constant("item_end_padding","PopupMenu",6)
	var hover:=StyleBoxFlat.new()
	hover.bg_color=Color("253827");hover.border_color=Color("65764e")
	hover.set_border_width_all(1);hover.set_corner_radius_all(4)
	theme.set_stylebox("hover","PopupMenu",hover)
	var separator:=StyleBoxLine.new()
	separator.color=Color("3c4e35");separator.thickness=1
	separator.content_margin_top=5;separator.content_margin_bottom=5
	for name in ["separator","labeled_separator_left","labeled_separator_right"]:
		theme.set_stylebox(name,"PopupMenu",separator)
	var tooltip_panel:=panel.duplicate() as StyleBoxFlat
	tooltip_panel.content_margin_left=10;tooltip_panel.content_margin_right=10
	tooltip_panel.content_margin_top=8;tooltip_panel.content_margin_bottom=8
	theme.set_stylebox("panel","TooltipPanel",tooltip_panel)
	theme.set_font("font","TooltipLabel",preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf"))
	theme.set_font_size("font_size","TooltipLabel",18)
	theme.set_color("font_color","TooltipLabel",Color("e3e4cd"))
	for name in ["checked","radio_checked","unchecked","radio_unchecked","checked_disabled","radio_checked_disabled","unchecked_disabled","radio_unchecked_disabled","submenu","submenu_mirrored"]:
		var tint:=Color("e7b566") if name in ["checked","radio_checked"] else Color("a7b09a")
		_tint_menu_icon(name,tint)

func _tint_menu_icon(name: String, tint: Color) -> void:
	# Recolour the engine's existing glyphs once per theme change, retaining their
	# tonal detail, antialiased alpha and dimensions. No per-frame work.
	var source:=get_theme_icon(name,"PopupMenu").get_image()
	if source==null or source.is_empty(): return
	# Some backends return the engine icon Image itself. Never tint shared
	# default-theme data; Restored must retain the original icon colours.
	source=source.duplicate() as Image
	source.convert(Image.FORMAT_RGBA8)
	for y in source.get_height():
		for x in source.get_width():
			var pixel:=source.get_pixel(x,y)
			var luminance:=pixel.r*0.2126+pixel.g*0.7152+pixel.b*0.0722
			source.set_pixel(x,y,Color(tint.r*luminance,tint.g*luminance,tint.b*luminance,pixel.a))
	theme.set_icon(name,"PopupMenu",ImageTexture.create_from_image(source))

func _watch(menu: PopupMenu) -> void:
	super._watch(menu)
	menu.about_to_popup.connect(func():
		# An empty Load menu otherwise focuses its only enabled item: a divider.
		# Restored receives the incumbent separator flags when reopened.
		for index in menu.item_count:
			if menu.is_item_separator(index):menu.set_item_disabled(index,hud_style=="tactical"))

func _place_tactical_bar() -> void:
	_tactical_bar.size=Vector2(get_viewport_rect().size.x,size.y)

static func _uses_macos_shortcuts() -> bool:
	# Browser Cmd chords are intercepted or stripped before Godot receives them,
	# even on macOS. Keep the browser's in-game shortcuts on Ctrl+Alt.
	if OS.has_feature("web"): return false
	return OS.get_name()=="macOS"

func _ready() -> void:
	_tactical_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
	_tactical_bar.show_behind_parent=true
	_tactical_bar.color=Color("0c1812")
	resized.connect(_place_tactical_bar)
	get_viewport().size_changed.connect(_place_tactical_bar)
	_apply_hud_theme()
	super._ready()
	session_popup=PopupMenu.new()
	session_popup.name="Session"
	add_child(session_popup)
	_watch(session_popup)
	save_popup=_submenu(session_popup,"Save state")
	load_popup=_submenu(session_popup,"Load state")
	for slot in range(1,6):
		save_popup.add_item("Slot %d"%slot,slot)
		load_popup.add_item("Slot %d (empty)"%slot,slot)
	load_popup.add_separator()
	load_popup.add_item("Undo last load",0)
	save_popup.id_pressed.connect(func(slot):request_state("save_state",slot))
	load_popup.id_pressed.connect(func(slot):request_state("load_state",slot))
	session_popup.add_separator()
	speed_popup=_submenu(session_popup,"Fast forward")
	for multiplier in [1,8]:
		speed_popup.add_radio_check_item("Normal speed" if multiplier==1 else "8x (Tab, sound muted)",multiplier)
	speed_popup.id_pressed.connect(choose_speed)
	session_popup.add_separator()
	session_popup.add_item(state_message,100)
	session_popup.set_item_disabled(session_popup.get_item_index(100),true)
	graphics_popup=PopupMenu.new()
	graphics_popup.name="Graphics"
	add_child(graphics_popup)
	_watch(graphics_popup)
	for index in MODES.size():
		graphics_popup.add_radio_check_item(["EGA (original PC)","EGA Upscaled (original colours)","Genesis (original artwork)","Genesis Upscaled (remastered)","Modern (not available yet)","Tactical (not available yet)"][index],index)
	graphics_popup.set_item_disabled(MODES.find("modern"),true)
	graphics_popup.set_item_disabled(MODES.find("tactical"),true)
	graphics_popup.id_pressed.connect(func(index):
		if index>=0 and index<MODES.size():choose_graphics(MODES[index])
		elif index==102:reset_quality())
	graphics_popup.add_separator()
	hud_popup=_submenu(graphics_popup,"HUD Style")
	for index in HUD_STYLES.size():
		hud_popup.add_radio_check_item("Restored (original layout)" if index==0 else "Tactical (modern olive)",index)
	hud_popup.id_pressed.connect(func(index):choose_hud_style(HUD_STYLES[index]))
	graphics_popup.add_separator()
	graphics_popup.add_item("Cycle graphics: "+shortcut_prefix()+"G",100)
	graphics_popup.set_item_disabled(graphics_popup.get_item_index(100),true)
	graphics_popup.add_separator()
	for key in QUALITY_LEVELS:
		var menu := _submenu(graphics_popup,"Antialiasing" if key=="msaa" else "Anisotropic filtering")
		for samples in QUALITY_LEVELS[key]:
			menu.add_radio_check_item("Off" if samples==0 else "%d× MSAA"%samples if key=="msaa" else "%d×"%samples,samples)
		menu.id_pressed.connect(func(samples):choose_quality(key,samples))
		quality_menus[key]=menu
	graphics_popup.add_item("Restore full-quality defaults (4× / 16×)",102)
	graphics_popup.add_item("",101)
	graphics_popup.set_item_disabled(graphics_popup.get_item_index(101),true)
	help_popup=PopupMenu.new()
	help_popup.name="Help"
	add_child(help_popup)
	_watch(help_popup)
	help_popup.add_item("Keyboard controls",0)
	help_popup.add_item("Scenarios & vehicles",1)
	help_popup.add_item("Original game credits",2)
	help_popup.id_pressed.connect(func(index):
		open_reference("keyboard-controls.html" if index==0 else "credits" if index==2 else "field-guide.html"))
	var existing_reader := get_tree().root.get_node_or_null("PlayerReference")
	if existing_reader!=null:
		existing_reader.connect("reader_changed",_reader_changed)
		if existing_reader.visible:_reader_changed(true)
	refresh_controls()

func open_reference(name: String) -> void:
	var reader := preload("res://scripts/pc_interface_theme.gd").show_reference(get_tree().root,name,hud_style)
	if not reader.is_connected("reader_changed",_reader_changed):reader.connect("reader_changed",_reader_changed)
	_reader_changed(true)

func _reader_changed(open: bool) -> void:
	release_keys=true
	if open:open_menus["reference"]=true
	else:open_menus.erase("reference")

func load_quality_settings() -> bool:
	quality=QUALITY_DEFAULTS.duplicate()
	hud_style="restored"
	preferred_graphics_mode=""
	quality_error=""
	if quality_config_path.is_empty(): return true
	var file := ConfigFile.new()
	var error := file.load(quality_config_path)
	if error==ERR_FILE_NOT_FOUND: return true
	if error!=OK:
		quality_error="Could not read saved graphics settings; using defaults"
		return false
	var loaded := {}
	for key in QUALITY_LEVELS:
		var value=file.get_value("graphics",key,QUALITY_DEFAULTS[key])
		if not value is int or value not in QUALITY_LEVELS[key]:
			quality_error="Invalid saved graphics settings; using defaults"
			return false
		loaded[key]=value
	quality=loaded
	var saved_style=file.get_value("graphics","hud_style","restored")
	hud_style=saved_style if saved_style is String and saved_style in HUD_STYLES else "restored"
	if file.has_section_key("graphics","graphics_mode"):
		var saved_mode=file.get_value("graphics","graphics_mode")
		if not saved_mode is String or saved_mode not in MODES:
			quality_error="Invalid saved graphics mode; using the launch default"
			return false
		preferred_graphics_mode=saved_mode
	return true

func _save_graphics_settings(failure_message: String) -> void:
	quality_error=""
	if quality_config_path.is_empty(): return
	var file := ConfigFile.new()
	for setting in quality: file.set_value("graphics",setting,quality[setting])
	file.set_value("graphics","hud_style",hud_style)
	if not preferred_graphics_mode.is_empty():
		file.set_value("graphics","graphics_mode",preferred_graphics_mode)
	if file.save(quality_config_path)!=OK: quality_error=failure_message

func choose_quality(key: String, samples: int) -> bool:
	if not QUALITY_LEVELS.has(key) or samples not in QUALITY_LEVELS[key]: return false
	quality[key]=samples
	_save_graphics_settings("Graphics changed, but could not save settings")
	quality_selected.emit(quality.msaa,quality.anisotropy)
	refresh_controls()
	return true

func choose_hud_style(style: String) -> bool:
	if style not in HUD_STYLES: return false
	hud_style=style
	_save_graphics_settings("HUD changed, but could not save settings")
	hud_style_selected.emit(style)
	refresh_controls()
	control_notice.emit("HUD: " + ("Tactical" if style=="tactical" else "Restored"))
	return true

func reset_quality() -> bool:
	quality=QUALITY_DEFAULTS.duplicate()
	_save_graphics_settings("Quality restored, but could not save settings")
	quality_selected.emit(quality.msaa,quality.anisotropy)
	refresh_controls()
	control_notice.emit("Full-quality defaults: 4× MSAA / 16× anisotropic filtering")
	return true

func shortcut_prefix() -> String:
	return "Cmd+" if shortcut_is_macos else "Ctrl+Alt+"

func _input(event: InputEvent) -> void:
	if handle_shortcut(event):get_viewport().set_input_as_handled()

func handle_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey:return false
	var code: int=event.keycode if event.keycode!=0 else event.physical_keycode
	if code==KEY_TAB:
		# Reference and native-menu Tab navigation belongs to their own controls.
		var reader := get_tree().root.get_node_or_null("PlayerReference") if is_inside_tree() else null
		if not window_focused or not open_menus.is_empty() or (reader!=null and reader.visible):return false
		if event.meta_pressed or event.ctrl_pressed or event.alt_pressed or event.shift_pressed:return false
		if "tab" not in shortcut_keys:shortcut_keys.append("tab")
		if event.pressed and not event.echo and not release_keys:choose_speed(8 if speed==1 else 1)
		return true
	var modifier: bool=event.meta_pressed and not event.ctrl_pressed and not event.alt_pressed if shortcut_is_macos else event.ctrl_pressed and event.alt_pressed and not event.meta_pressed
	if not modifier:return false
	if code not in [KEY_S,KEY_L,KEY_G] or (event.shift_pressed and code!=KEY_L):return false
	# Claim the entire chord, including repeats and its release. The bridge polls
	# Input directly, so marking the event handled alone cannot protect the guest.
	for name in preload("res://scripts/pc_keyboard.gd").encode([code]):
		if name not in shortcut_keys: shortcut_keys.append(name)
	if not shortcut_is_macos:
		for name in ["ctrl","alt"]:
			if name not in shortcut_keys: shortcut_keys.append(name)
	if event.shift_pressed and "shift" not in shortcut_keys: shortcut_keys.append("shift")
	if not event.pressed or event.echo or not open_menus.is_empty():return true
	match code:
		KEY_S:request_state("save_state",1)
		KEY_L:
			var slot := 0 if event.shift_pressed else 1
			if not busy and not request_state("load_state",slot):
				control_notice.emit("No recovery state available" if slot==0 else "Slot 1 is empty or unavailable")
		KEY_G:cycle_graphics()
	return true

func game_keys(held: Array) -> Array:
	var reader := get_tree().root.get_node_or_null("PlayerReference") if is_inside_tree() else null
	if reader!=null and reader.visible:
		release_keys=true
		return []
	var modifier := Input.is_key_pressed(KEY_META) if shortcut_is_macos else Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_ALT)
	# Quarantine only the shortcut chord. A held trigger or steering key must
	# survive save/load, including failures; menu/focus quarantine is separate.
	if modifier:
		for name in held:
			if name in ["s","l","g","ctrl","alt"] or (name=="shift" and "l" in held):
				if name not in shortcut_keys: shortcut_keys.append(name)
	shortcut_keys=shortcut_keys.filter(func(name):return name in held)
	return super.game_keys(held).filter(func(name):return name!="tab" and name not in shortcut_keys)

func _submenu(parent: PopupMenu, title: String) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name=title
	parent.add_child(menu)
	parent.add_submenu_node_item(title,menu)
	_watch(menu)
	return menu

func available_graphics_modes() -> Array:
	var modes: Array = ["ega","ega_upscaled","genesis","upscaled"] if genesis_available else ["ega","ega_upscaled","upscaled"]
	if modern_available: modes.append_array(["modern","tactical"])
	return modes

func cycle_graphics() -> bool:
	var modes := available_graphics_modes()
	return choose_graphics(modes[(modes.find(graphics_mode)+1)%modes.size()])

func choose_graphics(mode: String, persist: bool=true) -> bool:
	if mode not in available_graphics_modes(): return false
	graphics_mode=mode
	graphics_selected.emit(mode)
	# Signal handlers synchronously resolve the actual mode or revert on failure.
	if graphics_mode==mode and persist:
		preferred_graphics_mode=mode
		_save_graphics_settings("Graphics changed, but could not save settings")
	refresh_controls()
	# The viewer may reject a mode whose assets failed to load; report what is shown.
	var names := {"ega":"EGA","ega_upscaled":"EGA Upscaled","genesis":"Genesis","upscaled":"Genesis Upscaled","modern":"Modern","tactical":"Tactical"}
	control_notice.emit("Graphics: "+names[graphics_mode] if graphics_mode==mode else names[mode]+" graphics are unavailable")
	return graphics_mode==mode

func choose_speed(multiplier: int) -> bool:
	if busy or multiplier not in [1,8]: return false
	speed=multiplier
	speed_selected.emit(multiplier)
	refresh_controls()
	control_notice.emit("8x fast forward (sound muted)" if multiplier==8 else "Normal speed")
	return true

func request_state(operation: String, slot: int) -> bool:
	if busy or operation not in ["save_state","load_state"]: return false
	if operation=="save_state" and (slot<1 or slot>5): return false
	if operation=="load_state" and not _has_slot(slot): return false
	busy=true
	state_message="Saving state..." if operation=="save_state" else "Loading state..."
	refresh_controls()
	control_notice.emit(state_message)
	state_requested.emit(operation,slot)
	return true

func _has_slot(slot: int) -> bool:
	return state_slots.any(func(entry):return entry is Dictionary and int(entry.get("slot",-1))==slot and entry.get("exists",true) and entry.get("valid",true))

func set_state_status(slots: Array, message: String="") -> void:
	state_slots=slots.duplicate(true)
	busy=false
	if not message.is_empty(): state_message=message
	refresh_controls()
	if not message.is_empty():control_notice.emit(message)

func _refresh_tactical_tooltips() -> void:
	# Presentation copy is reversible with the HUD. IDs, modes, accelerators,
	# original keys and all underlying artwork/colour settings remain unchanged.
	var descriptions:= [
		"Exact original PC pixels at 320 x 200.",
		"High-resolution EGA art with the original PC colours.",
		"Original Genesis artwork in the PC layout. Requires the ROM.",
		"Generated high-resolution remaster artwork and rebuilt lettering.",
		"Refined low-poly scenery. Original view and visibility.",
		"Range-inspired scenery. Choose HUD Style separately."]
	for index in MODES.size():
		graphics_popup.set_item_tooltip(index,descriptions[index] if hud_style=="tactical" else "")
	for index in HUD_STYLES.size():
		hud_popup.set_item_tooltip(index,("Original cockpit layout and lettering." if index==0 else "Olive instruments and menus. Original readings and gameplay.") if hud_style=="tactical" else "")
	for key in quality_menus:
		var menu: PopupMenu=quality_menus[key]
		for index in menu.item_count:
			menu.set_item_tooltip(index,("Smooths 3D scenery edges. Original HUD pixels unchanged." if key=="msaa" else "Keeps angled ground textures clear. Geometry unchanged.") if hud_style=="tactical" else "")

func refresh_controls() -> void:
	if graphics_popup==null: return
	_apply_hud_theme()
	_refresh_tactical_tooltips()
	graphics_popup.set_item_disabled(MODES.find("genesis"),not genesis_available)
	graphics_popup.set_item_text(MODES.find("genesis"),"Genesis (original artwork)" if genesis_available else "Genesis (requires optional import)")
	graphics_popup.set_item_disabled(MODES.find("modern"),not modern_available)
	graphics_popup.set_item_text(MODES.find("modern"),"Modern (refined low-poly)" if modern_available else "Modern (assets unavailable)")
	graphics_popup.set_item_disabled(MODES.find("tactical"),not modern_available)
	graphics_popup.set_item_text(MODES.find("tactical"),"Tactical (Range-inspired 3D)" if modern_available else "Tactical (assets unavailable)")
	for index in MODES.size():graphics_popup.set_item_checked(index,MODES[index]==graphics_mode)
	for index in HUD_STYLES.size():hud_popup.set_item_checked(index,HUD_STYLES[index]==hud_style)
	for key in quality_menus:
		var menu: PopupMenu=quality_menus[key]
		for index in menu.item_count: menu.set_item_checked(index,menu.get_item_id(index)==quality[key])
	graphics_popup.set_item_text(graphics_popup.get_item_index(101),quality_error if not quality_error.is_empty() else "Antialiasing applies to Genesis Upscaled, Modern and Tactical scenery")
	for index in speed_popup.item_count:
		speed_popup.set_item_checked(index,speed_popup.get_item_id(index)==speed)
		speed_popup.set_item_disabled(index,busy)
	for slot in range(1,6):
		save_popup.set_item_disabled(save_popup.get_item_index(slot),busy)
		save_popup.set_item_text(save_popup.get_item_index(slot),"Slot %d"%slot+(" ("+shortcut_prefix()+"S)" if slot==1 else ""))
		var available := _has_slot(slot)
		load_popup.set_item_disabled(load_popup.get_item_index(slot),busy or not available)
		var description := "Slot %d (empty)"%slot
		for entry in state_slots:
			if entry is Dictionary and int(entry.get("slot",-1))==slot and entry.get("exists",true):
				description="Slot %d (%s)"%[slot,str(entry.get("saved_at","saved")) if available else "invalid or incompatible"]
		load_popup.set_item_text(load_popup.get_item_index(slot),description+(" ("+shortcut_prefix()+"L)" if slot==1 else ""))
	load_popup.set_item_disabled(load_popup.get_item_index(0),busy or not _has_slot(0))
	load_popup.set_item_text(load_popup.get_item_index(0),"Undo last load ("+shortcut_prefix()+"Shift+L)")
	session_popup.set_item_text(session_popup.get_item_index(100),state_message)
