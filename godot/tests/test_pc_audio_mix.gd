extends SceneTree
const Audio = preload("res://scripts/pc_audio.gd")
const Menu = preload("res://scripts/pc_audio_menu.gd")
var errors: Array[String] = []
var checks := 0
var output: String

func _initialize() -> void: run.call_deferred()

func check(ok: bool, why: String) -> void:
	checks+=1
	if not ok: errors.append(why)

func gain(player: AudioStreamPlayer, expected: float, why: String) -> void:
	check(absf(db_to_linear(player.volume_db)-expected)<0.00001,why)

func packet(frame: int, enabled: bool=true, event: bool=false) -> Dictionary:
	return {"schema":3,"frame":frame,"epoch":1,"last_id":1,"active":true,"enabled":enabled,
		"events":[{"id":1,"frame":frame,"epoch":1,"kind":"sound","ip":0x9107,"return_ip":0x33c4,
			"value":1,"backend":0,"enabled":true,"sample":"cannon","voice":"on_the_way"}] if event else [],
		"loops":{"engine":{"active":true,"channel":3,"ticks":85,"program":0xbf8,"period":0x4584,
			"amplitude":3,"idle_period":0x4584,"amplitude_reference":3},
			"turret":{"active":true,"channel":2,"ticks":20,"program":0xc4c,"period":8500,
			"amplitude":3,"idle_period":8500,"amplitude_reference":3}}}

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output=directory.path_join("artifacts/pc-audio-mix-unit")
	var args := OS.get_cmdline_user_args()
	if "--output" in args: output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var audio := Audio.new()
	check(audio.set_mix({"master":100,"effects":100,"voice":30,"motors":100}),"launch preferences accepted before players exist")
	root.add_child(audio)
	gain(audio.voice,0.65*0.3*0.8,"launch preference applied after player construction")
	check(audio.set_mix(Menu.DEFAULTS),"restore untouched diagnostic defaults")
	var menu := Menu.new()
	menu.audio=audio
	menu.config_path=""
	check(menu.load_settings() and menu.settings==Menu.DEFAULTS,"diagnostics ignore user preferences")
	root.add_child(menu)
	check(menu.get_menu_count()==1 and menu.menus.size()==4,"one external Audio menu, four gain groups")
	check(menu.get_menu_title(0)=="Audio","menu title")
	for child in [menu.popup]+menu.menus.values():
		for i in child.item_count:
			check(child.get_item_accelerator(i)==0 and child.get_item_shortcut(i)==null,"no original key claimed")
	check(menu.game_keys(["p","space"])==["p","space"],"closed menu preserves game input")
	menu.popup.about_to_popup.emit()
	check(menu.game_keys(["up","return"]).is_empty(),"menu navigation never drives original")
	menu.popup.popup_hide.emit()
	check(menu.game_keys(["return"]).is_empty(),"menu closing key waits for release")
	check(menu.game_keys([]).is_empty() and menu.game_keys(["space"])==["space"],"fresh original keys restored after release")
	var first := packet(10,true,true)
	var source_json := JSON.stringify(first)
	check(audio.apply_audio(first),"original packet accepted")
	check(audio.effects[0].playing and audio.voice.playing and audio.engine.playing and audio.turret.playing,"default streams start")
	gain(audio.effects[0],0.65*0.6,"unchanged default effect gain")
	gain(audio.voice,0.65*0.8,"unchanged default voice gain")
	gain(audio.engine,0.65*0.08,"unchanged default engine gain")
	var sequence := [audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed]
	for choice in [["master",50],["effects",20],["voice",70],["motors",30]]:
		menu.menus[choice[0]].id_pressed.emit(choice[1])
	check(menu.settings=={"master":50,"effects":20,"voice":70,"motors":30},"every callback controls its own channel")
	gain(audio.effects[0],0.65*0.5*0.2*0.6,"existing effect gain updates")
	gain(audio.voice,0.65*0.5*0.7*0.8,"existing voice gain updates")
	gain(audio.engine,0.65*0.5*0.3*0.08,"existing engine gain updates")
	gain(audio.turret,0.65*0.5*0.3*0.10,"existing turret gain updates")
	check(sequence==[audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed],"mix cannot advance or replay source sequence")
	check(JSON.stringify(first)==source_json,"source packet never mutated")
	for key in Menu.DEFAULTS:
		var choices: PopupMenu=menu.menus[key]
		check(choices.is_item_checked(choices.get_item_index(menu.settings[key])),"current radio selection: "+key)
	var before := audio.mix.duplicate()
	for invalid in [{},{"master":-1,"effects":100,"voice":100,"motors":100},
		{"master":100,"effects":101,"voice":100,"motors":100},
		{"master":100,"effects":1.5,"voice":100,"motors":100},
		{"master":100,"effects":NAN,"voice":100,"motors":100}]:
		check(not audio.set_mix(invalid) and audio.mix==before,"invalid mix rejected atomically")
	menu.choose("voice",0)
	check(not audio.voice.playing and audio.effects[0].playing,"voice mute leaves effects alone")
	menu.choose("voice",100)
	check(not audio.voice.playing,"restoring voice gain never replays old speech")
	menu.choose("master",0)
	check(not audio.voice.playing and not audio.engine.playing and not audio.turret.playing and not audio.effects[0].playing,"master zero immediately stops every stream")
	menu.choose("master",100)
	check(audio.engine.playing and audio.turret.playing and not audio.voice.playing and not audio.effects[0].playing,"only active source loops resume after master unmute")
	check(audio.apply_audio(packet(11,false)),"original F5/pause mute")
	menu.popup.id_pressed.emit(1000)
	check(menu.settings==Menu.DEFAULTS and audio.muted and not audio.engine.playing and not audio.voice.playing,"default reset cannot override source mute")
	check(audio.apply_audio(packet(12)),"source gate reopens")
	check(audio.engine.playing and not audio.voice.playing and audio.delivered==1,"source resumes motors without stale one-shots")
	menu.config_path=output.path_join("preferences.cfg")
	menu.choose("effects",40)
	check(menu.save_error.is_empty(),"explicit choice saved")
	var reload := Menu.new()
	reload.config_path=menu.config_path
	check(reload.load_settings() and reload.settings.effects==40,"cold settings load retains preference")
	var malformed := ConfigFile.new()
	malformed.set_value("audio","effects","loud")
	malformed.save(menu.config_path)
	check(not reload.load_settings() and reload.settings==Menu.DEFAULTS and not reload.save_error.is_empty(),"malformed saved mix is visible and falls back atomically")
	menu.config_path=output.path_join("missing-parent/preferences.cfg")
	menu.choose("effects",60)
	check(not menu.save_error.is_empty() and audio.effects_volume==0.6,"save failure reported without losing session mix")
	reload.free()
	check(await audio.drain_for_shutdown(),"audio drains without residual playback")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"native_menu":menu.is_native_menu()},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_AUDIO_MIX: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
