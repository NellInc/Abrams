extends "res://scripts/pc_audio_menu.gd"
## Remaster controls live outside the source framebuffer and claim no game keys.
signal graphics_selected(mode: String)
signal quality_selected(msaa_samples: int, anisotropic_samples: int)
signal speed_selected(multiplier: int)
signal state_requested(operation: String, slot: int)
signal control_notice(message: String)
var shortcut_is_macos := OS.get_name()=="macOS"
var shortcut_keys: Array = []
const MODES := ["ega","genesis","upscaled","modern"]
var graphics_mode := "upscaled"
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
var session_popup: PopupMenu
var speed_popup: PopupMenu
var save_popup: PopupMenu
var load_popup: PopupMenu
var state_slots: Array = []
var state_message := "Save states include the campaign disk. Loading rewinds both."

func _ready() -> void:
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
	for multiplier in [1,2,4,8]:
		speed_popup.add_radio_check_item("Normal speed" if multiplier==1 else "%dx (sound muted)"%multiplier,multiplier)
	speed_popup.id_pressed.connect(choose_speed)
	session_popup.add_separator()
	session_popup.add_item(state_message,100)
	session_popup.set_item_disabled(session_popup.get_item_index(100),true)
	graphics_popup=PopupMenu.new()
	graphics_popup.name="Graphics"
	add_child(graphics_popup)
	_watch(graphics_popup)
	for index in MODES.size():
		graphics_popup.add_radio_check_item(["EGA (original PC)","Genesis (original artwork)","Upscaled (remastered)","Modern (not available yet)"][index],index)
	graphics_popup.set_item_disabled(3,true)
	graphics_popup.id_pressed.connect(func(index):choose_graphics(MODES[index]))
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
	graphics_popup.add_item("",101)
	graphics_popup.set_item_disabled(graphics_popup.get_item_index(101),true)
	refresh_controls()

func load_quality_settings() -> bool:
	quality=QUALITY_DEFAULTS.duplicate()
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
	return true

func choose_quality(key: String, samples: int) -> bool:
	if not QUALITY_LEVELS.has(key) or samples not in QUALITY_LEVELS[key]: return false
	quality[key]=samples
	quality_error=""
	if not quality_config_path.is_empty():
		var file := ConfigFile.new()
		for setting in quality: file.set_value("graphics",setting,quality[setting])
		if file.save(quality_config_path)!=OK: quality_error="Graphics changed, but could not save settings"
	quality_selected.emit(quality.msaa,quality.anisotropy)
	refresh_controls()
	return true

func shortcut_prefix() -> String:
	return "Cmd+" if shortcut_is_macos else "Ctrl+Alt+"

func _input(event: InputEvent) -> void:
	if handle_shortcut(event):get_viewport().set_input_as_handled()

func handle_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey:return false
	var modifier: bool=event.meta_pressed and not event.ctrl_pressed and not event.alt_pressed if shortcut_is_macos else event.ctrl_pressed and event.alt_pressed and not event.meta_pressed
	if not modifier:return false
	var code: int=event.keycode if event.keycode!=0 else event.physical_keycode
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
	var modifier := Input.is_key_pressed(KEY_META) if shortcut_is_macos else Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_ALT)
	# Quarantine only the shortcut chord. A held trigger or steering key must
	# survive save/load, including failures; menu/focus quarantine is separate.
	if modifier:
		for name in held:
			if name in ["s","l","g","ctrl","alt"] or (name=="shift" and "l" in held):
				if name not in shortcut_keys: shortcut_keys.append(name)
	shortcut_keys=shortcut_keys.filter(func(name):return name in held)
	return super.game_keys(held).filter(func(name):return name not in shortcut_keys)

func _submenu(parent: PopupMenu, title: String) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name=title
	parent.add_child(menu)
	parent.add_submenu_node_item(title,menu)
	_watch(menu)
	return menu

func available_graphics_modes() -> Array:
	var modes: Array = ["ega","genesis","upscaled"] if genesis_available else ["ega","upscaled"]
	if modern_available: modes.append("modern")
	return modes

func cycle_graphics() -> bool:
	var modes := available_graphics_modes()
	return choose_graphics(modes[(modes.find(graphics_mode)+1)%modes.size()])

func choose_graphics(mode: String) -> bool:
	if mode not in available_graphics_modes(): return false
	graphics_mode=mode
	graphics_selected.emit(mode)
	refresh_controls()
	control_notice.emit("Graphics: "+{"ega":"EGA","genesis":"Genesis","upscaled":"Upscaled","modern":"Modern"}[graphics_mode])
	return true

func choose_speed(multiplier: int) -> bool:
	if busy or multiplier not in [1,2,4,8]: return false
	speed=multiplier
	speed_selected.emit(multiplier)
	refresh_controls()
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

func refresh_controls() -> void:
	if graphics_popup==null: return
	graphics_popup.set_item_disabled(1,not genesis_available)
	graphics_popup.set_item_text(1,"Genesis (original artwork)" if genesis_available else "Genesis (requires optional import)")
	graphics_popup.set_item_disabled(3,not modern_available)
	graphics_popup.set_item_text(3,"Modern (refined low-poly)" if modern_available else "Modern (assets unavailable)")
	for index in MODES.size():graphics_popup.set_item_checked(index,MODES[index]==graphics_mode)
	for key in quality_menus:
		var menu: PopupMenu=quality_menus[key]
		for index in menu.item_count: menu.set_item_checked(index,menu.get_item_id(index)==quality[key])
	graphics_popup.set_item_text(graphics_popup.get_item_index(101),quality_error if not quality_error.is_empty() else "Antialiasing applies to Upscaled and Modern scenery")
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
