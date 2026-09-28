extends MenuBar
## Presentation-only gains. No bridge, source state, key binding or pause command.
const DEFAULTS := {"master":100,"effects":100,"voice":100,"motors":100,"music":70}
const TITLES := {"master":"Master volume","effects":"Sound effects","voice":"Crew voices","motors":"Engine and turret","music":"Music"}
var settings: Dictionary = DEFAULTS.duplicate()
var config_path := "user://pc_audio.cfg"
var audio: Node
var menus: Dictionary = {}
var popup: PopupMenu
var open_menus: Dictionary = {}
var release_keys := false
var save_error := ""

func _ready() -> void:
	set_disable_shortcuts(true)
	popup=PopupMenu.new()
	popup.name="Audio"
	add_child(popup)
	_watch(popup)
	for key: String in DEFAULTS:
		var menu := PopupMenu.new()
		menu.name=key
		popup.add_child(menu)
		_watch(menu)
		for percent in range(0,101,10):
			menu.add_radio_check_item("Off" if percent==0 else "%d%%"%percent,percent)
		menu.id_pressed.connect(func(percent):choose(key,percent))
		menus[key]=menu
		popup.add_submenu_node_item(TITLES[key],menu)
	popup.add_separator()
	popup.add_item("Restore default mix",1000)
	popup.id_pressed.connect(func(id):
		if id==1000:
			settings=DEFAULTS.duplicate()
			_commit())
	popup.add_separator()
	popup.add_item("Original F5 / pause still control sound",1001)
	popup.set_item_disabled(popup.get_item_index(1001),true)
	popup.add_item("",1002)
	popup.set_item_disabled(popup.get_item_index(1002),true)
	refresh()

func _watch(menu: PopupMenu) -> void:
	menu.allow_search=false
	menu.about_to_popup.connect(func():
		open_menus[menu]=true
		release_keys=true)
	menu.popup_hide.connect(func():open_menus.erase(menu))

func game_keys(held: Array) -> Array:
	# Menu navigation must not also steer/fire in the original game. Closing
	# with Enter/Escape waits for release; there is no reserved gameplay hotkey.
	if not open_menus.is_empty(): return []
	if release_keys:
		if held.is_empty(): release_keys=false
		return []
	return held

func load_settings() -> bool:
	settings=DEFAULTS.duplicate()
	save_error=""
	if config_path.is_empty(): return true # deterministic diagnostics, no writes
	var file := ConfigFile.new()
	var error := file.load(config_path)
	if error==ERR_FILE_NOT_FOUND: return true
	if error!=OK:
		save_error="Could not read saved mix; using defaults"
		return false
	var loaded := {}
	for key: String in DEFAULTS:
		var value=file.get_value("audio",key,DEFAULTS[key])
		if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)) or value<0 or value>100:
			save_error="Invalid saved mix; using defaults"
			return false
		loaded[key]=int(value)
	settings=loaded
	return true

func choose(channel: String, percent: int) -> bool:
	if not DEFAULTS.has(channel) or percent<0 or percent>100: return false
	settings[channel]=percent
	_commit()
	return true

func _commit() -> void:
	if audio: audio.set_mix(settings)
	save_error=""
	if not config_path.is_empty():
		var file := ConfigFile.new()
		for key in DEFAULTS: file.set_value("audio",key,settings[key])
		if file.save(config_path)!=OK: save_error="Mix changed, but could not save it"
	refresh()

func refresh() -> void:
	if popup==null: return
	for key: String in menus:
		var menu: PopupMenu=menus[key]
		for index in menu.item_count:
			menu.set_item_checked(index,menu.get_item_id(index)==settings[key])
		popup.set_item_text(popup.get_item_index(DEFAULTS.keys().find(key)),"%s (%d%%)"%[TITLES[key],settings[key]])
	popup.set_item_text(popup.get_item_index(1002),save_error if not save_error.is_empty() else "Changes are saved for next launch" if not config_path.is_empty() else "Diagnostic mix, not saved")
