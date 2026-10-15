extends SceneTree
const Keyboard = preload("res://scripts/pc_keyboard.gd")
const AudioMenu = preload("res://scripts/pc_audio_menu.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
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
	var physical_cases := [
		[[KEY_5],[KEY_KP_5],[],["kp5"]],
		[[],[KEY_KP_5],[],["kp5"]], # NumLock-off Clear has no encoded alias.
		[[KEY_5],[],[KEY_5],["5"]],
		[[KEY_5],[KEY_KP_5],[KEY_5],["5","kp5"]],
		[[],[],[KEY_5],["5"]], # Keypad released first, shared logical state cleared.
		[[KEY_5],[KEY_KP_5],[],["kp5"]], # Row key released first.
		[[],[],[],[]],
		[[KEY_UP],[KEY_KP_8],[],["kp8"]],
		[[KEY_UP],[KEY_KP_8],[KEY_UP],["up","kp8"]],
		[[],[],[KEY_UP],["up"]],
		[[KEY_LEFT],[KEY_KP_4],[],["kp4"]],
		[[KEY_DOWN],[KEY_KP_2],[],["kp2"]],
		[[KEY_RIGHT],[KEY_KP_6],[],["kp6"]],
		[[KEY_KP_5],[],[],["kp5"]], # Preserve backends with logical keypad only.
		[[KEY_SHIFT,KEY_3],[],[],["shift","3"]],
		[[KEY_SHIFT,KEY_3],[KEY_KP_3],[],["shift","kp3"]],
		[[KEY_CTRL,KEY_A,KEY_9,KEY_UP],[KEY_KP_9,KEY_KP_8],[],["ctrl","a","kp8","kp9"]]]
	for entry in physical_cases:
		if Keyboard.encode(Keyboard.resolve_pressed(entry[0],entry[1],entry[2]))!=entry[3]: errors.append("physical "+str(entry))
	if Keyboard.encode(Keyboard.resolve_pressed(every,range(KEY_KP_0,KEY_KP_9+1),[KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT])).slice(0,7)!=["shift","ctrl","alt","up","down","left","right"]:
		errors.append("physical recovery preserves cap priority")
	# Actual event identities preserve layout and independent release ownership.
	Keyboard.clear_aliases()
	var event := InputEventKey.new()
	event.physical_keycode=KEY_5; event.keycode=KEY_5; event.pressed=true
	Keyboard.record_alias(event)
	event.physical_keycode=KEY_KP_5
	Keyboard.record_alias(event)
	if Keyboard.physical_aliases!={KEY_5:KEY_5}: errors.append("keypad cannot replace genuine row identity")
	event.pressed=false
	Keyboard.record_alias(event)
	if Keyboard.physical_aliases!={KEY_5:KEY_5}: errors.append("keypad release cannot clear genuine row identity")
	event.physical_keycode=KEY_5; event.keycode=0
	Keyboard.record_alias(event)
	if not Keyboard.physical_aliases.is_empty(): errors.append("row release clears by physical identity")
	event.pressed=true; event.keycode=KEY_PERCENT
	Keyboard.record_alias(event)
	if not Keyboard.physical_aliases.is_empty(): errors.append("non-US physical row must not invent a digit")
	event.keycode=KEY_7
	Keyboard.record_alias(event)
	if Keyboard.physical_aliases!={KEY_5:KEY_7}: errors.append("localized digit identity retained")
	event.echo=true; event.keycode=KEY_PERCENT
	Keyboard.record_alias(event)
	if not Keyboard.physical_aliases.is_empty(): errors.append("changed logical echo clears stale alias")
	event.echo=false; event.keycode=KEY_5
	Keyboard.record_alias(event)
	event.physical_keycode=KEY_6
	Keyboard.record_alias(event)
	event.physical_keycode=KEY_5; event.pressed=false
	Keyboard.record_alias(event)
	if Keyboard.physical_aliases!={KEY_6:KEY_5}: errors.append("duplicate alias release retains other physical owner")
	Keyboard.clear_aliases()
	if not Keyboard.physical_aliases.is_empty(): errors.append("focus exit clears aliases")
	# Register before gameplay accepts input. Held keys still use Input's actual
	# physical state; missed key-up events are pruned rather than latched.
	Keyboard.initialize(root)
	event.physical_keycode=KEY_5; event.keycode=KEY_5; event.pressed=true
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events()
	root.window_input.emit(event)
	if "5" not in Keyboard.held(): errors.append("initialized actual physical row key")
	event.pressed=false
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events() # Deliberately omit the record_alias key-up.
	if "5" in Keyboard.held() or not Keyboard.physical_aliases.is_empty(): errors.append("missed key-up pruning")
	event.pressed=true
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	root.focus_exited.emit()
	if not Keyboard.physical_aliases.is_empty(): errors.append("connected focus loss clears state")
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events()
	root.window_input.emit(event)
	if "5" not in Keyboard.held(): errors.append("focus reacquisition records new press")
	event.pressed=false
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	root.gui_disable_input=true # This fixture tests polling, not GUI Space activation.
	var menu := AudioMenu.new()
	menu.config_path=""
	root.add_child(menu)
	if not menu.is_inside_tree() or not menu.is_node_ready() or menu.get_window()!=root: errors.append("focus fixture has an active owned Window")
	# A fresh press immediately on refocus must work without a neutral frame.
	event.physical_keycode=KEY_SPACE; event.keycode=KEY_SPACE; event.pressed=true
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	root.focus_exited.emit(); menu._focus_exited()
	if Input.is_key_pressed(KEY_SPACE): errors.append("focus loss clears stale backend state")
	root.focus_entered.emit(); menu._focus_entered()
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	if menu.game_keys(Keyboard.held())!=["space"]: errors.append("immediate genuine focus press rearms input: "+str({"held":Keyboard.held(),"rearm":Keyboard.focus_rearmed(menu.get_window()),"focused":menu.window_focused,"release":menu.release_keys,"focus_release":menu.focus_release_keys,"menus":menu.open_menus.size()}))
	# The same physically held trigger's repeats must remain quarantined.
	root.focus_exited.emit(); menu._focus_exited()
	root.focus_entered.emit(); menu._focus_entered()
	event.echo=true
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	if not menu.game_keys(Keyboard.held()).is_empty(): errors.append("held fire echo cannot resume on focus return")
	if not Keyboard.focus_quarantine.has(KEY_SPACE): errors.append("reset-generated releases cannot erase quarantine")
	event.echo=false; event.pressed=false
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	event.pressed=true
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	if menu.game_keys(Keyboard.held())!=["space"]: errors.append("fresh fire after held-trigger release reaches guest")
	# Menu-closing release protection is independent of focus rearming.
	menu.release_keys=true
	root.focus_exited.emit(); menu._focus_exited()
	root.focus_entered.emit(); menu._focus_entered()
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	if not menu.game_keys(Keyboard.held()).is_empty(): errors.append("focus rearm cannot bypass menu-closing release")
	event.pressed=false
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	menu.game_keys(Keyboard.held())
	event.pressed=true
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	if menu.game_keys(Keyboard.held())!=["space"]: errors.append("menu release then fresh fire remains original: "+str({"held":Keyboard.held(),"rearm":Keyboard.focus_rearmed(menu.get_window()),"focused":menu.window_focused,"release":menu.release_keys,"focus_release":menu.focus_release_keys,"menus":menu.open_menus.size()}))
	event.pressed=false
	Input.parse_input_event(event.duplicate()); Input.flush_buffered_events(); root.window_input.emit(event)
	# Two physical owners sharing one logical value cannot release each other.
	Keyboard.focus_quarantine={KEY_5:KEY_5,KEY_6:KEY_5}
	event.physical_keycode=KEY_5; event.keycode=KEY_5
	Keyboard.record_alias(event)
	if Keyboard.focus_quarantine!={KEY_6:KEY_5}: errors.append("quarantine release retains independent owner")
	event.physical_keycode=KEY_6; event.keycode=KEY_7; event.pressed=true
	Keyboard.record_alias(event)
	if not Keyboard.focus_quarantine.is_empty(): errors.append("fresh layout-changed press retires its old physical quarantine")
	menu.free()
	for error in errors: printerr("FAIL: keyboard identity " + error)
	print("PC_KEYBOARD: %d original, %d physical identity cases, event layout/release and 16-key cap; %d failures" % [cases.size(),physical_cases.size(),errors.size()])
	quit(0 if errors.is_empty() else 1)
