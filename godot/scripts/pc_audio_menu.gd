extends MenuBar
signal mix_changed
## Presentation-only gains. No bridge, source state, key binding or pause command.
const DEFAULTS := {"master":100,"effects":100,"voice":100,"motors":100,"music":70,
	"cannon":100,"machinegun":100,"impact":100,"smoke":100,"engine":100,"turret":100,"river":100,"hind":100,"radio":100,"switch":100,"field":100,"cow":100,"t80":100,"t72":100,"brdm":100,"btr":100,"t64":100,"bmp":100,"m60":100,"t55":100,"tank":100,"m113":100,"bradley":100,"woodland":100,"truck":100,"tracks":100,"foley":100,"interface":100,"fire":100,"missileflight":100,"trackedfallback":100,"wheeledfallback":100}
const TITLES := {"master":"Master volume","effects":"Sound effects","voice":"Crew voices","motors":"Engine and turret","music":"Music",
	"cannon":"Cannons","machinegun":"Machine gun","impact":"Impacts","smoke":"Smoke","engine":"Engine","turret":"Turret","river":"Rivers","hind":"Hind engine","radio":"Radio alerts","switch":"Switches","field":"Field air","cow":"Animals","t80":"T-80 engine","t72":"T-72 engine","brdm":"BRDM engine","btr":"BTR-70 engine","t64":"T-64 engine","bmp":"BMP-1/2 engine","m60":"M60A3 engine","t55":"T-62 engine","tank":"Other tank engines","m113":"M113 engine","bradley":"Bradley engine","woodland":"Woodland air","truck":"Truck engines","tracks":"Track texture","foley":"Mechanical detail","interface":"Interface tones","fire":"Visible fire","missileflight":"Missiles","trackedfallback":"Other tracked vehicles","wheeledfallback":"Other wheeled vehicles"}
var settings: Dictionary = DEFAULTS.duplicate()
var config_path := "user://pc_audio.cfg"
var audio: Node
var menus: Dictionary = {}
var popup: PopupMenu
var open_menus: Dictionary = {}
var release_keys := false
var gated_keys: Dictionary = {}
var focus_release_keys := false
var window_focused := true
var save_error := ""
# Private native recordings are never a browser feature or bundled asset.
const BROWSER_OMITTED := ["river","hind","field","cow","t80","t72","brdm","btr","t64","bmp","m60","t55","tank","m113","bradley","woodland","truck","tracks","foley","interface","fire","missileflight","trackedfallback","wheeledfallback"]

func audio_channels() -> Array:
	return DEFAULTS.keys().filter(func(key):return not OS.has_feature("web") or key not in BROWSER_OMITTED)

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
	for name in gated_keys.keys():
		if name not in held: gated_keys.erase(name)
	if not window_focused or not open_menus.is_empty():
		for name in held: gated_keys[name]=true
		return []
	if focus_release_keys:
		if preload("res://scripts/pc_keyboard.gd").focus_rearmed(get_window()): focus_release_keys=false
		else:
			# One neutral sample satisfies every quarantine: a reader that took
			# window focus must not need a second all-keys-up frame.
			if held.is_empty():
				focus_release_keys=false
				release_keys=false
			return []
	# Each key held through a menu, reader or cover change waits for its own
	# release. A new key passes at once, so one lost key-up (a menu that
	# swallowed it) cannot withhold every other control.
	if release_keys:
		for name in held: gated_keys[name]=true
		release_keys=false
	return held.filter(func(name): return not gated_keys.has(name))

## Whether a press of `name` would reach the game now, changing no gate. A
## probe must not trim the quarantine of keys it did not list.
func key_passes(name: String) -> bool:
	if not window_focused or not open_menus.is_empty(): return false
	if focus_release_keys and not preload("res://scripts/pc_keyboard.gd").focus_rearmed(get_window()): return false
	if release_keys: return false
	return not gated_keys.has(name)

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
	# Working if: an existing wheeled gain/Off survives the dedicated recording,
	# while an explicit saved BRDM choice always wins.
	if file.has_section_key("audio","wheeledfallback") and not file.has_section_key("audio","brdm"):
		loaded.brdm=loaded.wheeledfallback
	# Preserve saved donor levels and deliberate Off until independently changed.
	# Working if: each new cue inherits only when its explicit preference is absent.
	for cue: String in {"bmp":"trackedfallback","m60":"tank","t55":"tank","btr":"wheeledfallback","t64":"tank"}:
		var donor: String = "trackedfallback" if cue == "bmp" else "wheeledfallback" if cue == "btr" else "tank"
		if file.has_section_key("audio",donor) and not file.has_section_key("audio",cue):
			loaded[cue] = loaded[donor]
	settings=loaded
	return true

## persist=false applies the gain live (a slider drag) without writing the
## settings file or rebuilding the menus; the final value is then persisted.
func choose(channel: String, percent: int, persist: bool=true) -> bool:
	if not DEFAULTS.has(channel) or percent<0 or percent>100: return false
	settings[channel]=percent
	_commit(persist)
	return true

func reset_mix() -> bool:
	settings=DEFAULTS.duplicate()
	_commit()
	return true

func _commit(persist: bool=true) -> void:
	if audio: audio.set_mix(settings)
	if persist:
		save_error=""
		if not config_path.is_empty():
			var file := ConfigFile.new()
			for key in DEFAULTS: file.set_value("audio",key,settings[key])
			if file.save(config_path)!=OK: save_error="Mix changed, but could not save it"
		refresh()
	mix_changed.emit()

func refresh() -> void:
	if popup==null: return
	# Submenus were added in audio_channels() order, so each title's item id is
	# its position there. The browser omits private channels; DEFAULTS order
	# would name a separator or a missing item instead.
	var channels := audio_channels()
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
		popup.set_item_text(popup.get_item_index(channels.find(key)),"%s (%d%%)"%[TITLES[key],settings[key]])
	popup.set_item_text(popup.get_item_index(1002),save_error if not save_error.is_empty() else "Changes are saved for next launch" if not config_path.is_empty() else "Diagnostic mix, not saved")
