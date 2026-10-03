extends SceneTree
const Keyboard = preload("res://scripts/pc_keyboard.gd")

func _initialize() -> void:
	var errors: Array[String] = []
	var cases := [
		[[KEY_5,KEY_KP_5],["5","kp5"]],
		[[KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT],["up","down","left","right"]],
		[[KEY_KP_8,KEY_KP_2,KEY_KP_4,KEY_KP_6],["kp8","kp2","kp4","kp6"]],
		[[KEY_Q,KEY_A,KEY_Z,KEY_0,KEY_9],["q","a","z","0","9"]],
		[[KEY_ENTER,KEY_KP_ENTER,KEY_ENTER],["return"]],
		[[KEY_ESCAPE,KEY_BACKSPACE,KEY_TAB],["escape","backspace","tab"]],
		[[KEY_F1,KEY_F4,KEY_F12],["f1","f4","f12"]],
		[[KEY_SHIFT,KEY_3],["shift","3"]],
		[[KEY_CTRL,KEY_ALT,KEY_META],["ctrl","alt"]]]
	for entry in cases:
		if Keyboard.encode(entry[0]) != entry[1]: errors.append(str(entry))
	# Every candidate held at once must stay within the host's 16-key protocol limit.
	var every: Array = [KEY_SHIFT,KEY_CTRL,KEY_ALT,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT,KEY_ESCAPE,KEY_BACKSPACE,KEY_TAB,KEY_SPACE,KEY_ENTER]
	for bounds in [[KEY_A,KEY_Z],[KEY_0,KEY_9],[KEY_KP_0,KEY_KP_9],[KEY_F1,KEY_F12]]: every.append_array(range(bounds[0],bounds[1]+1))
	var capped := Keyboard.encode(every)
	var unique := {}
	for name in capped: unique[name]=true
	if capped.size()!=Keyboard.MAX_KEYS or unique.size()!=capped.size() or capped.slice(0,7)!=["shift","ctrl","alt","up","down","left","right"]:
		errors.append("16-key cap keeps modifiers and steering: "+str(capped))
	var below: Array = range(KEY_A,KEY_A+Keyboard.MAX_KEYS)
	if Keyboard.encode(below).size()!=Keyboard.MAX_KEYS: errors.append("16 keys pass through unchanged")
	for error in errors: printerr("FAIL: keyboard identity " + error)
	print("PC_KEYBOARD: %d original key identity cases and the 16-key cap; %d failures" % [cases.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
