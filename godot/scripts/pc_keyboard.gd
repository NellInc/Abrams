extends RefCounted
## Preserve original key identities in menus and gameplay, including digit 5.
const SPECIAL = {KEY_SHIFT: "shift", KEY_CTRL: "ctrl", KEY_ALT: "alt", KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right",
	KEY_ESCAPE: "escape", KEY_BACKSPACE: "backspace", KEY_TAB: "tab",
	KEY_SPACE: "space", KEY_ENTER: "return", KEY_KP_ENTER: "return"}
# Protocol limit; mirrors validate_command in tools/pc_bridge_host.py, which
# ends the session on a larger set. SPECIAL comes first, so modifiers and
# steering survive the cap.
const MAX_KEYS := 16
static var physical_aliases: Dictionary = {}
static var alias_window: WeakRef
static var physical_presses: Dictionary = {}
static var focus_quarantine: Dictionary = {}
static var resetting_input := false
static var focus_reset := false
static var fresh_focus_press := false

static func encode(pressed: Array) -> Array:
	var keys: Array = []
	for key in pressed:
		var name := ""
		if SPECIAL.has(key): name = SPECIAL[key]
		elif key >= KEY_A and key <= KEY_Z: name = String.chr(key).to_lower()
		elif key >= KEY_0 and key <= KEY_9: name = String.chr(key)
		elif key >= KEY_KP_0 and key <= KEY_KP_9: name = "kp%d" % (key-KEY_KP_0)
		elif key >= KEY_F1 and key <= KEY_F12: name = "f%d" % (key-KEY_F1+1)
		if not name.is_empty() and name not in keys: keys.append(name)
		if keys.size()==MAX_KEYS: break
	return keys

static func held() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree: initialize(tree.root)
	var physical: Array = []
	var genuine: Array = []
	for key in range(KEY_KP_0,KEY_KP_9+1):
		if Input.is_physical_key_pressed(key): physical.append(key)
	for key in physical_aliases.keys():
		if Input.is_physical_key_pressed(key): genuine.append(physical_aliases[key])
		else: physical_aliases.erase(key)
	for owner in physical_presses.keys():
		var press: Dictionary = physical_presses[owner]
		if not (Input.is_physical_key_pressed(press.physical) if press.physical!=0 else Input.is_key_pressed(press.key)):
			physical_presses.erase(owner)
	var logical: Array = candidates().filter(func(key): return Input.is_key_pressed(key))
	var active := resolve_pressed(logical,physical,genuine)
	return encode(active.filter(func(key): return key not in focus_quarantine.values() or physical_presses.values().any(func(press): return press.key==key)))

static func candidates() -> Array:
	var result: Array = SPECIAL.keys()
	for bounds in [[KEY_A,KEY_Z],[KEY_0,KEY_9],[KEY_KP_0,KEY_KP_9],[KEY_F1,KEY_F12]]:
		result.append_array(range(bounds[0],bounds[1]+1))
	return result

static func record_alias(event: InputEvent) -> void:
	if not event is InputEventKey or resetting_input: return
	var physical: int = event.physical_keycode
	var owner: int = physical if physical!=0 else event.keycode
	if not event.pressed:
		physical_aliases.erase(physical)
		physical_presses.erase(owner)
		focus_quarantine.erase(owner)
		return
	if focus_quarantine.has(owner):
		if event.echo: return
		focus_quarantine.erase(owner)
	if not event.echo: fresh_focus_press=true
	var canonical: int = physical if physical>=KEY_KP_0 and physical<=KEY_KP_9 else event.keycode
	physical_presses[owner]={"key":canonical,"physical":physical,"logical":event.keycode}
	if physical==0 or (physical>=KEY_KP_0 and physical<=KEY_KP_9): return
	if (event.keycode>=KEY_0 and event.keycode<=KEY_9) or event.keycode in [KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]:
		# Keep the event's actual layout identity, never assume a US digit row.
		physical_aliases[physical]=event.keycode
	else:
		physical_aliases.erase(physical)

static func clear_aliases() -> void:
	physical_aliases.clear()

static func resolve_pressed(logical: Array, physical_keypad: Array, genuine_aliases: Array) -> Array:
	var active: Array = logical.duplicate()
	var navigation := {KEY_KP_8:KEY_UP,KEY_KP_2:KEY_DOWN,KEY_KP_4:KEY_LEFT,KEY_KP_6:KEY_RIGHT}
	for key in physical_keypad:
		if key<KEY_KP_0 or key>KEY_KP_9: continue
		var aliases: Array = [KEY_0+key-KEY_KP_0]
		if navigation.has(key): aliases.append(navigation[key])
		for alias in aliases:
			if alias not in genuine_aliases: active.erase(alias)
		if key not in active: active.append(key)
	# A keypad release can clear Godot's shared logical digit/arrow state while
	# the genuine non-keypad key is still held. Its physical event survives.
	for key in genuine_aliases:
		if key not in active: active.append(key)
	# Working if keypad identity survives NumLock and either release order,
	# with the original protocol ordering, modifiers and 16-key cap retained.
	return candidates().filter(func(key): return key in active)

static func initialize(window: Window) -> void:
	var previous := alias_window.get_ref() as Window if alias_window else null
	if previous==window: return
	if previous:
		previous.window_input.disconnect(record_alias)
		previous.focus_exited.disconnect(focus_exited)
	clear_aliases()
	physical_presses.clear()
	focus_quarantine.clear()
	focus_reset=false
	fresh_focus_press=false
	alias_window=weakref(window)
	window.window_input.connect(record_alias)
	window.focus_exited.connect(focus_exited)

static func focus_exited() -> void:
	# Web key-ups are attached to the canvas. Releasing over an HTML control
	# otherwise leaves the backend pressed forever. Retain physical owners so
	# an auto-repeat on refocus cannot resume held fire, steering or modifiers.
	var captured := focus_quarantine.duplicate()
	for owner in physical_presses:
		captured[owner]=physical_presses[owner].key
	resetting_input=true
	for press in physical_presses.values():
		var release := InputEventKey.new()
		release.keycode=press.logical
		release.physical_keycode=press.physical
		Input.parse_input_event(release)
	# Clear any logical state that predates registration, without inventing a
	# physical layout mapping. The recorded events above release physical keys.
	for key in candidates():
		if Input.is_key_pressed(key):
			var release := InputEventKey.new()
			release.keycode=key
			Input.parse_input_event(release)
	Input.flush_buffered_events()
	resetting_input=false
	clear_aliases()
	physical_presses.clear()
	focus_quarantine=captured
	focus_reset=true
	fresh_focus_press=false

static func focus_rearmed(window: Window) -> bool:
	return alias_window!=null and alias_window.get_ref()==window and focus_reset and fresh_focus_press
