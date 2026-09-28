extends "res://scripts/pc_audio_menu.gd"
## Remaster controls live outside the source framebuffer and claim no game keys.
signal graphics_selected(mode: String)
signal speed_selected(multiplier: int)
signal state_requested(operation: String, slot: int)
const MODES := ["ega","genesis","upscaled","modern"]
var graphics_mode := "upscaled"
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
	refresh_controls()

func _submenu(parent: PopupMenu, title: String) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name=title
	parent.add_child(menu)
	parent.add_submenu_node_item(title,menu)
	_watch(menu)
	return menu

func choose_graphics(mode: String) -> bool:
	if mode not in ["ega","genesis","upscaled"]: return false
	graphics_mode=mode
	graphics_selected.emit(mode)
	refresh_controls()
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
	state_requested.emit(operation,slot)
	return true

func _has_slot(slot: int) -> bool:
	return state_slots.any(func(entry):return entry is Dictionary and int(entry.get("slot",-1))==slot and entry.get("exists",true) and entry.get("valid",true))

func set_state_status(slots: Array, message: String="") -> void:
	state_slots=slots.duplicate(true)
	busy=false
	if not message.is_empty(): state_message=message
	refresh_controls()

func refresh_controls() -> void:
	if graphics_popup==null: return
	for index in MODES.size():graphics_popup.set_item_checked(index,MODES[index]==graphics_mode)
	for index in speed_popup.item_count:
		speed_popup.set_item_checked(index,speed_popup.get_item_id(index)==speed)
		speed_popup.set_item_disabled(index,busy)
	for slot in range(1,6):
		save_popup.set_item_disabled(save_popup.get_item_index(slot),busy)
		var available := _has_slot(slot)
		load_popup.set_item_disabled(load_popup.get_item_index(slot),busy or not available)
		var description := "Slot %d (empty)"%slot
		for entry in state_slots:
			if entry is Dictionary and int(entry.get("slot",-1))==slot and entry.get("exists",true):
				description="Slot %d (%s)"%[slot,str(entry.get("saved_at","saved")) if available else "invalid or incompatible"]
		load_popup.set_item_text(load_popup.get_item_index(slot),description)
	load_popup.set_item_disabled(load_popup.get_item_index(0),busy or not _has_slot(0))
	session_popup.set_item_text(session_popup.get_item_index(100),state_message)
