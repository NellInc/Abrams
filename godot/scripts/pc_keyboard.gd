extends RefCounted
## Preserve original key identities in menus and gameplay, including digit 5.
const SPECIAL = {KEY_SHIFT: "shift", KEY_CTRL: "ctrl", KEY_ALT: "alt", KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right",
	KEY_ESCAPE: "escape", KEY_BACKSPACE: "backspace", KEY_TAB: "tab",
	KEY_SPACE: "space", KEY_ENTER: "return", KEY_KP_ENTER: "return"}
# Protocol limit; mirrors validate_command in tools/pc_bridge_host.py, which
# ends the session on a larger set. SPECIAL comes first, so modifiers and
# steering survive the cap.
const MAX_KEYS := 16

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
	var candidates: Array = SPECIAL.keys()
	for bounds in [[KEY_A,KEY_Z],[KEY_0,KEY_9],[KEY_KP_0,KEY_KP_9],[KEY_F1,KEY_F12]]:
		candidates.append_array(range(bounds[0],bounds[1]+1))
	return encode(candidates.filter(func(key): return Input.is_key_pressed(key)))
