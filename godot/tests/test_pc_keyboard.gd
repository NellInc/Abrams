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
	for error in errors: printerr("FAIL: keyboard identity " + error)
	print("PC_KEYBOARD: %d original key identity cases; %d failures" % [cases.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
