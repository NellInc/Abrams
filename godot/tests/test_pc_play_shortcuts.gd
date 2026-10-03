extends SceneTree
const Menu=preload("res://scripts/pc_play_menu.gd")
var checks:=0
var errors: Array[String]=[]
func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok:errors.append(why)
func key(code: int, mac: bool, pressed: bool=true, shift: bool=false, echo: bool=false) -> InputEventKey:
	var event:=InputEventKey.new()
	event.keycode=code;event.pressed=pressed;event.echo=echo;event.shift_pressed=shift
	event.meta_pressed=mac;event.ctrl_pressed=not mac;event.alt_pressed=not mac
	return event
func physical(code: int, pressed: bool) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func _initialize() -> void:
	create_timer(60).timeout.connect(func():printerr("FAIL: play shortcut fixture deadline");quit(1))
	run.call_deferred()
func run() -> void:
	var menu:=Menu.new()
	menu.config_path=""
	root.add_child(menu)
	var commands:=[]
	var modes:=[]
	var notices:=[]
	var speeds:=[]
	menu.state_requested.connect(func(op,slot):commands.append([op,slot]))
	menu.graphics_selected.connect(func(mode):modes.append(mode))
	menu.control_notice.connect(func(message):notices.append(message))
	menu.speed_selected.connect(func(multiplier):speeds.append(multiplier))
	for mac in [true,false]:
		menu.shortcut_is_macos=mac
		menu.set_state_status([])
		var before:=commands.size()
		for code in [KEY_S,KEY_L,KEY_G,KEY_F1,KEY_F12,KEY_SPACE]:
			var plain:=InputEventKey.new();plain.keycode=code;plain.pressed=true
			check(not menu.handle_shortcut(plain),"unmodified game key retained")
		check(commands.size()==before,"bare game keys never save/load")
		check(menu.handle_shortcut(key(KEY_L,mac)) and commands.size()==before,"empty quick slot cannot load")
		check(notices[-1]=="Slot 1 is empty or unavailable","empty slot has feedback")
		check(menu.handle_shortcut(key(KEY_S,mac)) and commands[-1]==["save_state",1],"quick save targets slot 1")
		check(menu.busy and notices[-1]=="Saving state...","save progress feedback")
		menu.handle_shortcut(key(KEY_S,mac))
		check(commands.size()==before+1,"busy chord cannot queue another operation")
		menu.set_state_status([{"slot":1},{"slot":0}],"Saved")
		menu.handle_shortcut(key(KEY_S,mac,true,false,true))
		menu.handle_shortcut(key(KEY_S,mac,false))
		check(commands.size()==before+1,"repeat and release never save again")
		menu.handle_shortcut(key(KEY_L,mac))
		check(commands[-1]==["load_state",1],"quick load targets slot 1")
		menu.set_state_status([{"slot":1},{"slot":0}])
		menu.handle_shortcut(key(KEY_L,mac,true,true))
		check(commands[-1]==["load_state",0],"shifted quick load uses recovery")
		menu.set_state_status([])
		menu.graphics_mode="upscaled"
		for expected in ["ega","genesis","upscaled"]:
			menu.handle_shortcut(key(KEY_G,mac))
			check(menu.graphics_mode==expected and modes[-1]==expected,"graphics cycle skips unavailable Modern")
		menu.genesis_available=false
		for expected in ["ega","upscaled","ega","upscaled"]:
			menu.handle_shortcut(key(KEY_G,mac))
			check(menu.graphics_mode==expected and modes[-1]==expected,"graphics cycle skips unloaded Genesis")
		menu.genesis_available=true
		var count:=modes.size()
		menu.handle_shortcut(key(KEY_G,mac,true,false,true))
		check(modes.size()==count,"holding graphics shortcut switches only once")
		check(not menu.handle_shortcut(key(KEY_G,mac,true,true)),"unassigned shifted chord ignored")
		var wrong:=key(KEY_S,not mac)
		check(not menu.handle_shortcut(wrong),"other platform modifier is not reserved")
		check(menu.game_keys(["s"]).is_empty(),"trailing letter suppressed after modifier releases")
		menu.game_keys([])
		check(menu.game_keys(["s","shift","3"])==["s","shift","3"],"fresh original controls return after release")
		menu.session_popup.about_to_popup.emit()
		menu.handle_shortcut(key(KEY_S,mac))
		check(not menu.busy,"open popup does not dispatch a background shortcut")
		menu.session_popup.popup_hide.emit()
		menu.game_keys([])
		# Exercise the actual Node._input route, not just the dispatcher.
		root.push_input(key(KEY_S,mac))
		check(menu.busy and commands[-1]==["save_state",1],"viewport key input reaches shortcut handler")
		root.push_input(key(KEY_S,mac,false))
		menu.set_state_status([])
		menu.game_keys([])
		var modifiers: Array=[KEY_META] if mac else [KEY_CTRL,KEY_ALT]
		for code in modifiers:
			var press:=InputEventKey.new();press.keycode=code;press.pressed=true
			Input.parse_input_event(press)
		Input.parse_input_event(key(KEY_S,mac))
		Input.flush_buffered_events()
		check(menu.busy and commands[-1]==["save_state",1],"polled physical chord dispatches save")
		check(menu.game_keys(["s"]).is_empty(),"held shortcut modifier blocks polled game input")
		for code in modifiers:
			var release:=InputEventKey.new();release.keycode=code
			Input.parse_input_event(release)
		Input.flush_buffered_events()
		check(Input.is_key_pressed(KEY_S) and menu.game_keys(["s"]).is_empty(),"modifier-first release cannot leak S into guest")
		var release:=InputEventKey.new();release.keycode=KEY_S
		Input.parse_input_event(release)
		Input.flush_buffered_events()
		menu.game_keys([])
		check(not Input.is_key_pressed(KEY_S) and menu.game_keys(["s"])==["s"],"fully released chord restores original S")
		menu.set_state_status([])
		# Host polling must preserve unrelated controls through real shortcut
		# events, both modifier-release orders, failures, and recovery loads.
		for operation in [[KEY_S,false],[KEY_L,false],[KEY_L,true]]:
			for modifier_first in [true,false]:
				menu.set_state_status([{"slot":1},{"slot":0}])
				for code in [KEY_UP,KEY_SPACE]:physical(code,true)
				for code in modifiers:physical(code,true)
				var undo:bool=operation[1]
				var letter:int=operation[0]
				if undo:physical(KEY_SHIFT,true)
				Input.parse_input_event(key(letter,mac,true,undo))
				Input.flush_buffered_events()
				var actual:=menu.game_keys(preload("res://scripts/pc_keyboard.gd").held())
				check(actual.has("up") and actual.has("space") and actual.size()==2,"shortcut preserves held movement and fire")
				menu.set_state_status([{"slot":1},{"slot":0}],"Synthetic load failure")
				check(menu.game_keys(preload("res://scripts/pc_keyboard.gd").held())==actual,"failed operation retains current controls")
				if modifier_first:
					for code in modifiers:physical(code,false)
				else:physical(letter,false)
				check(menu.game_keys(preload("res://scripts/pc_keyboard.gd").held())==actual,"partial chord release never leaks and keeps controls")
				if modifier_first:physical(letter,false)
				else:
					for code in modifiers:physical(code,false)
				if undo:physical(KEY_SHIFT,false)
				check(menu.game_keys(preload("res://scripts/pc_keyboard.gd").held())==actual,"fully released shortcut never requires gameplay keys to release")
				for code in [KEY_UP,KEY_SPACE]:physical(code,false)
				menu.game_keys([])
		# Focus signals use the production Window connection. A stale held
		# trigger stays quarantined on return until a neutral host sample.
		physical(KEY_SPACE,true)
		root.focus_exited.emit()
		check(menu.game_keys(["space"]).is_empty(),"focus loss neutralizes held fire")
		root.focus_entered.emit()
		check(menu.game_keys(["space"]).is_empty(),"focus return cannot resurrect stale trigger")
		physical(KEY_SPACE,false)
		menu.game_keys([])
		physical(KEY_SPACE,true)
		check(menu.game_keys(["space"])==["space"],"fresh press after focus recovery reaches guest")
		physical(KEY_SPACE,false)
		menu.game_keys([])
	# Bare Tab is presentation acceleration only, preserving other held controls.
	var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true
	check(menu.handle_shortcut(tab) and menu.speed==8 and speeds[-1]==8,"Tab enables 8x")
	check(menu.game_keys(["tab","space","up"])==["space","up"],"Tab never reaches guest, steering and fire remain held")
	var count:=speeds.size()
	tab.echo=true
	check(menu.handle_shortcut(tab) and speeds.size()==count,"Tab repeat cannot toggle again")
	tab.pressed=false;tab.echo=false
	check(menu.handle_shortcut(tab) and speeds.size()==count,"Tab release never changes speed")
	menu.game_keys([])
	tab.pressed=true
	root.push_input(tab)
	check(menu.speed==1 and speeds[-1]==1,"viewport Tab returns to normal speed")
	tab.pressed=false;root.push_input(tab);menu.game_keys([])
	tab.pressed=true;tab.shift_pressed=true
	check(not menu.handle_shortcut(tab) and menu.speed==1,"Shift Tab is not acceleration")
	tab.shift_pressed=false;tab.ctrl_pressed=true
	check(not menu.handle_shortcut(tab),"modified Tab is not acceleration")
	tab.ctrl_pressed=false
	menu.session_popup.about_to_popup.emit()
	check(not menu.handle_shortcut(tab) and menu.speed==1,"menu Tab navigation does not accelerate")
	menu.session_popup.popup_hide.emit()
	check(menu.handle_shortcut(tab) and menu.speed==1,"post-menu quarantine cannot accelerate a stale press")
	menu.game_keys([])
	menu.window_focused=false
	check(not menu.handle_shortcut(tab) and menu.speed==1,"unfocused Tab ignored")
	menu.window_focused=true
	menu.handle_shortcut(tab)
	check(menu.speed==8,"fresh Tab after focus recovery enables 8x")
	menu.request_state("save_state",1)
	count=speeds.size()
	menu.handle_shortcut(tab)
	check(menu.speed==8 and speeds.size()==count,"saving rejects speed changes")
	menu.set_state_status([{"slot":1}],"Saved")
	tab.echo=true;menu.handle_shortcut(tab)
	check(menu.speed==8 and speeds.size()==count,"Tab held across save completion stays at 8x")
	check(menu.game_keys(["tab","space"])==["space"],"checkpoint cannot leak held Tab to guest")
	tab.echo=false;tab.pressed=false;menu.handle_shortcut(tab);menu.game_keys([])
	tab.pressed=true;menu.handle_shortcut(tab)
	check(menu.speed==1,"released then repressed Tab restores normal after save")
	for error in errors:printerr("FAIL: "+error)
	print("PC_PLAY_SHORTCUTS: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
