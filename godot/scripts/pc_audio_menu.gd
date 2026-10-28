extends MenuBar
signal mix_changed
## Presentation-only gains. No bridge, source state, key binding or pause command.
const DEFAULTS := {"master":100,"effects":100,"voice":100,"motors":100,"music":70,
	"cannon":100,"machinegun":100,"impact":100,"smoke":100,"engine":100,"turret":100,"river":100,"hind":100,"radio":100,"switch":100,"field":100,"cow":100,"t80":100,"t72":100,"tank":100,"m113":100,"bradley":100,"woodland":100,"truck":100,"tracks":100,"foley":100,"interface":100,"fire":100}
const TITLES := {"master":"Master volume","effects":"Sound effects","voice":"Crew voices","motors":"Engine and turret","music":"Music",
	"cannon":"Cannons","machinegun":"Machine gun","impact":"Impacts","smoke":"Smoke","engine":"Engine","turret":"Turret","river":"Rivers","hind":"Hind engine","radio":"Radio alerts","switch":"Switches","field":"Field air","cow":"Animals","t80":"T-80 engine","t72":"T-72 engine","tank":"Other tank engines","m113":"M113 engine","bradley":"Bradley engine","woodland":"Woodland air","truck":"Truck engines","tracks":"Track texture","foley":"Mechanical detail","interface":"Interface tones","fire":"Visible fire"}
var settings: Dictionary = DEFAULTS.duplicate()
var config_path := "user://pc_audio.cfg"
var audio: Node
var menus: Dictionary = {}
var popup: PopupMenu
var open_menus: Dictionary = {}
var release_keys := false
var focus_release_keys := false
var window_focused := true
var save_error := ""

func audio_channels() -> Array:
	# Private native recordings are never a browser feature or bundled asset.
	return DEFAULTS.keys().filter(func(key):return not OS.has_feature("web") or key not in ["river","hind","field","cow","t80","t72","tank","m113","bradley","woodland","truck","tracks","foley","interface","fire"])

func _ready() -> void:
	set_disable_shortcuts(true)
	get_window().focus_exited.connect(_focus_exited)
	get_window().focus_entered.connect(_focus_entered)
	popup=PopupMenu.new()
	popup.name="Audio"
	add_child(popup)
	_watch(popup)
	for key: String in audio_channels():
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
		if id==1000: reset_mix())
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

func _focus_exited() -> void:
	window_focused=false
	focus_release_keys=true

func _focus_entered() -> void:
	window_focused=true

func game_keys(held: Array) -> Array:
	# Menu navigation must not also steer/fire in the original game. Closing
	# with Enter/Escape waits for release; there is no reserved gameplay hotkey.
	if not window_focused or not open_menus.is_empty(): return []
	if focus_release_keys:
		if preload("res://scripts/pc_keyboard.gd").focus_rearmed(get_window()): focus_release_keys=false
		else:
			# One neutral sample satisfies every quarantine: a reader that took
			# window focus must not need a second all-keys-up frame.
			if held.is_empty():
				focus_release_keys=false
				release_keys=false
			return []
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
	# Existing T72s used the generic tank gain. Preserve that saved balance until
	# the player makes a separate T72 choice, including a deliberate Off.
	# Working if: validated legacy tank gains inherit only when t72 is absent.
	if file.has_section_key("audio","tank") and not file.has_section_key("audio","t72"):
		loaded.t72=loaded.tank
	settings=loaded
	return true

func choose(channel: String, percent: int) -> bool:
	if not DEFAULTS.has(channel) or percent<0 or percent>100: return false
	settings[channel]=percent
	_commit()
	return true

func reset_mix() -> bool:
	settings=DEFAULTS.duplicate()
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
	mix_changed.emit()

func refresh() -> void:
	if popup==null: return
	for key: String in menus:
		var menu: PopupMenu=menus[key]
		# Preferences support every integer, including gains between menu steps.
		for index in range(menu.item_count-1,-1,-1):
			var percent := menu.get_item_id(index)
			if percent%10!=0 and percent!=settings[key]:menu.remove_item(index)
		if menu.get_item_index(settings[key])<0:
			menu.add_radio_check_item("%d%%"%settings[key],settings[key])
		for index in menu.item_count:
			menu.set_item_checked(index,menu.get_item_id(index)==settings[key])
		popup.set_item_text(popup.get_item_index(DEFAULTS.keys().find(key)),"%s (%d%%)"%[TITLES[key],settings[key]])
	popup.set_item_text(popup.get_item_index(1002),save_error if not save_error.is_empty() else "Changes are saved for next launch" if not config_path.is_empty() else "Diagnostic mix, not saved")
