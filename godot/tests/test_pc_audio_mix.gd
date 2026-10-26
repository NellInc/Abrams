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

func individual_controls() -> void:
	var audio := Audio.new()
	audio.recorded_effect_directory=""
	root.add_child(audio)
	var menu := Menu.new()
	menu.config_path="";menu.audio=audio
	root.add_child(menu)
	var source := packet(10,true,true)
	source.loops.engine.amplitude=1
	source.loops.turret.period=17000
	var original := JSON.stringify(source)
	check(audio.apply_audio(source),"individual mixer uses accepted original audio")
	var sequence := [audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed]
	var pitches := [audio.engine.pitch_scale,audio.turret.pitch_scale]
	for cue in ["cannon","machinegun","impact","smoke","radio","switch"]:
		if cue!="cannon":audio.play(cue)
		var player: AudioStreamPlayer=audio.effects.filter(func(p):return p.playing and p.get_meta("effect_cue","")==cue)[0]
		var other: AudioStreamPlayer
		if cue=="cannon":
			audio.play("machinegun");other=audio.effects[audio.cursor-1]
		menu.choose(cue,40)
		gain(player,0.65*0.6*0.4,"individual gain: "+cue)
		gain(audio.voice,0.65*0.8,"individual effect leaves crew gain intact: "+cue)
		check(audio.voice.playing and audio.engine.playing and audio.turret.playing,"individual effect leaves crew and motors playing: "+cue)
		menu.choose(cue,0)
		check(not player.playing,"individual effect stops immediately: "+cue)
		if other!=null:
			check(other.playing,"cannon mute leaves simultaneous machine gun playing")
			gain(other,0.65*0.6,"cannon gain leaves simultaneous machine gun gain unchanged")
			other.stop()
		menu.choose(cue,100)
		check(not player.playing,"individual effect unmute never replays a consumed shot: "+cue)
		var cursor := audio.cursor
		menu.choose(cue,0);audio.play(cue)
		check(audio.cursor==cursor and audio.effects.all(func(p):return not p.playing),"muted effect cannot start or steal a player: "+cue)
		menu.choose(cue,100)
	menu.choose("engine",40);menu.choose("turret",30)
	gain(audio.engine,0.65*0.08/3.0*0.4,"engine user gain multiplies original amplitude")
	gain(audio.turret,0.65*0.10*0.3,"turret user gain independent of engine")
	check(pitches==[audio.engine.pitch_scale,audio.turret.pitch_scale],"individual gains preserve original motor pitch")
	menu.choose("engine",0)
	check(not audio.engine.playing and audio.turret.playing,"engine off leaves turret active")
	menu.choose("engine",67)
	check(audio.engine.playing and audio.turret.playing,"only source-active engine resumes")
	menu.choose("turret",0)
	check(audio.engine.playing and not audio.turret.playing,"turret off leaves engine active")
	check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100}),"legacy API still accepted")
	check(audio.mix.engine==67 and audio.mix.turret==0,"legacy mix updates preserve individual choices")
	check(sequence==[audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed] and JSON.stringify(source)==original,"individual settings never mutate or advance source events/loops")
	for bad in [NAN,1.5,-1,101,"loud"]:
		var invalid := menu.settings.duplicate();invalid.engine=bad
		var before := audio.mix.duplicate()
		check(not audio.set_mix(invalid) and audio.mix==before,"invalid individual gain rejected atomically")
	check(audio.apply_audio(packet(11,false)),"source mute closes individual motors")
	menu.choose("engine",100);menu.choose("turret",100)
	check(audio.muted and not audio.engine.playing and not audio.turret.playing,"individual unmute cannot bypass source mute")
	check(await audio.drain_for_shutdown(),"individual audio shuts down cleanly")
	menu.queue_free();audio.queue_free()

func auxiliary_source_controls() -> void:
	var audio: Node = Audio.new()
	audio.recorded_effect_directory = ""
	root.add_child(audio)
	var menu: MenuBar = Menu.new()
	menu.config_path = ""; menu.audio = audio
	root.add_child(menu)
	var id: int = 0
	for cue: String in ["radio", "switch"]:
		id += 1
		menu.choose(cue, 0)
		var source: Dictionary = packet(100 + id)
		source.last_id = id
		source.events = [{"id":id,"frame":100 + id,"epoch":1,"kind":"sound","ip":0x9107,
			"return_ip":0x3c97 if cue == "radio" else 0x15e4,"value":11 if cue == "radio" else 14,
			"backend":0,"enabled":true,"sample":cue,"voice":null}]
		check(audio.apply_audio(source), "muted qualified auxiliary event accepted: " + cue)
		check(audio.effects.all(func(player): return not player.playing), "muted auxiliary has no audible side effect: " + cue)
		var delivered: int = audio.delivered
		menu.choose(cue, 100)
		check(audio.apply_audio(source) and audio.delivered == delivered and audio.effects.all(func(player): return not player.playing), "unmute cannot replay consumed auxiliary request: " + cue)
	check(await audio.drain_for_shutdown(), "auxiliary source controls drain")
	menu.queue_free(); audio.queue_free()

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
	var notifications: Array[Dictionary]=[]
	menu.mix_changed.connect(func():notifications.append(menu.settings.duplicate()))
	check(menu.get_menu_count()==1 and menu.menus.size()==15,"one external Audio menu, fifteen gain groups")
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
	for choice in [["master",50],["effects",20],["voice",70],["motors",30],["music",60]]:
		menu.menus[choice[0]].id_pressed.emit(choice[1])
	var expected := Menu.DEFAULTS.duplicate()
	expected.merge({"master":50,"effects":20,"voice":70,"motors":30,"music":60},true)
	check(menu.settings==expected,"every callback controls its own channel")
	check(notifications.size()==5 and notifications[-1]==menu.settings,"native mixer emits the complete current mix for browser synchronization")
	gain(audio.effects[0],0.65*0.5*0.2*0.6,"existing effect gain updates")
	gain(audio.voice,0.65*0.5*0.7*0.8,"existing voice gain updates")
	gain(audio.engine,0.65*0.5*0.3*0.08,"existing engine gain updates")
	gain(audio.turret,0.65*0.5*0.3*0.10,"existing turret gain updates")
	check(sequence==[audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed],"mix cannot advance or replay source sequence")
	check(JSON.stringify(first)==source_json,"source packet never mutated")
	for key in Menu.DEFAULTS:
		var choices: PopupMenu=menu.menus[key]
		check(choices.is_item_checked(choices.get_item_index(menu.settings[key])),"current radio selection: "+key)
	for percent in [67,63,70]:
		check(menu.choose("voice",percent),"exact integral mix accepted")
		var choices: PopupMenu=menu.menus.voice
		var checked := 0
		for index in choices.item_count:
			if choices.is_item_checked(index):checked+=1
		check(checked==1 and choices.is_item_checked(choices.get_item_index(percent)),"one exact checked radio for irregular gain")
		check(choices.item_count==(11 if percent==70 else 12),"no stale irregular radio entries")
	menu.choose("voice",70)
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
	var reset_sequence := [audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed]
	menu.choose("music",20)
	check(menu.reset_mix() and menu.settings==Menu.DEFAULTS and audio.mix==Menu.DEFAULTS,"direct reset shares every native menu gain default")
	check(audio.muted and not audio.engine.playing and not audio.voice.playing and reset_sequence==[audio.last_frame,audio.last_event_id,audio.epoch,audio.delivered,audio.suppressed],"direct reset preserves source mute and event sequence")
	check(audio.apply_audio(packet(12)),"source gate reopens")
	check(audio.engine.playing and not audio.voice.playing and audio.delivered==1,"source resumes motors without stale one-shots")
	audio.set_transport_muted(true)
	menu.choose("music",20)
	check(menu.reset_mix() and audio.transport_muted and not audio.engine.playing and not audio.voice.playing,"reset preserves fast-forward transport mute")
	audio.set_transport_muted(false)
	menu.config_path=output.path_join("preferences.cfg")
	menu.choose("effects",40)
	check(menu.save_error.is_empty(),"explicit choice saved")
	var reload := Menu.new()
	reload.config_path=menu.config_path
	check(reload.load_settings() and reload.settings.effects==40,"cold settings load retains preference")
	check(menu.reset_mix() and reload.load_settings() and reload.settings==Menu.DEFAULTS,"reset persists every default gain")
	menu.choose("engine",0);menu.choose("cannon",67);menu.choose("turret",20)
	check(reload.load_settings() and reload.settings.engine==0 and reload.settings.cannon==67 and reload.settings.turret==20,"individual settings persist, including Off and irregular gains")
	menu.choose("hind",0);menu.choose("river",37);menu.choose("radio",23);menu.choose("switch",0)
	check(reload.load_settings() and reload.settings.hind==0 and reload.settings.river==37 and reload.settings.radio==23 and reload.settings.switch==0,"world and auxiliary controls persist independent mute and intermediate gain")
	var legacy := ConfigFile.new()
	legacy.set_value("audio","effects",40);legacy.set_value("audio","motors",30)
	legacy.save(menu.config_path)
	check(reload.load_settings() and reload.settings.effects==40 and reload.settings.motors==30 and reload.settings.hind==100 and reload.settings.river==100 and Audio.EFFECT_CUES.all(func(cue):return reload.settings[cue]==100),"old preferences keep original mix and acquire unchanged individual defaults")
	var malformed := ConfigFile.new()
	malformed.set_value("audio","effects","loud")
	malformed.save(menu.config_path)
	check(not reload.load_settings() and reload.settings==Menu.DEFAULTS and not reload.save_error.is_empty(),"malformed saved mix is visible and falls back atomically")
	menu.config_path=output.path_join("missing-parent/preferences.cfg")
	menu.choose("effects",60)
	check(not menu.save_error.is_empty() and audio.effects_volume==0.6,"save failure reported without losing session mix")
	check(menu.reset_mix() and menu.settings==Menu.DEFAULTS and audio.mix==Menu.DEFAULTS and not menu.save_error.is_empty(),"failed reset save reports failure while retaining live defaults")
	reload.free()
	# A save restarts the worker without rewinding the guest: sounds already
	# started keep playing while the resumed observer restarts at epoch 0/id 0.
	var resumed := Audio.new()
	root.add_child(resumed)
	check(resumed.apply_audio(packet(20,true,true)) and resumed.effects[0].playing and resumed.voice.playing and resumed.engine.playing,"cue before save plays")
	resumed.continue_timeline()
	check(resumed.apply_audio({"schema":3,"frame":20,"epoch":0,"last_id":0,"events":[],"active":false,"enabled":false}),"resumed primer accepted")
	check(resumed.effects[0].playing and resumed.voice.playing and resumed.engine.playing and not resumed.muted,"primer neither cuts sound nor toggles mute")
	var after_save := packet(21)
	after_save.events=[{"id":1,"frame":21,"epoch":1,"kind":"sound","ip":0x9107,"return_ip":0x32fa,
		"value":2,"backend":0,"enabled":true,"sample":"machinegun","voice":null}]
	var crew_position := resumed.voice.get_playback_position()
	check(resumed.apply_audio(after_save) and resumed.failure.is_empty(),"resumed worker's epoch 1 / id 1 accepted: "+resumed.failure)
	check(resumed.effects[0].playing and resumed.voice.playing and resumed.effects[1].playing and resumed.effects[1].stream!=resumed.effects[0].stream and resumed.voice.get_playback_position()>=crew_position and resumed.delivered==2,"save keeps the started cannon and crew line, then plays new events")
	check(resumed.engine.playing and resumed.turret.playing and resumed.loop_transitions.is_empty(),"engine loop never toggles across the save")
	check(resumed.epoch==1 and resumed.last_event_id==1 and not resumed.continuing_timeline,"first active packet adopts the resumed epoch")
	check(resumed.apply_audio(packet(22,false)) and not resumed.effects[0].playing and not resumed.engine.playing,"source gates still stop after a resumed save")
	resumed.continue_timeline()
	check(resumed.apply_audio({"schema":3,"frame":22,"epoch":0,"last_id":0,"events":[],"active":false,"enabled":false}),"second primer accepted")
	check(resumed.apply_audio(packet(23,true,true)) and resumed.effects[0].playing and resumed.voice.playing,"resumed cue plays")
	resumed.reset_timeline()
	check(not resumed.continuing_timeline and not resumed.effects[0].playing and not resumed.voice.playing and not resumed.engine.playing and not resumed.turret.playing,"load reset still stops everything")
	check(resumed.apply_audio(packet(1,true,true)) and resumed.failure.is_empty(),"load reset accepts a fresh timeline")
	check(await resumed.drain_for_shutdown(),"resumed audio drains without residual playback")
	check(await audio.drain_for_shutdown(),"audio drains without residual playback")
	await individual_controls()
	await auxiliary_source_controls()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"native_menu":menu.is_native_menu()},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_AUDIO_MIX: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
