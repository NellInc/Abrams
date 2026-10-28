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
	audio.world_audio.t72_directory=""
	audio.world_audio.flight_directory=""
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
	menu.choose("m113",23);menu.choose("bradley",0);menu.choose("t72",37)
	check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100}),"legacy API still accepted")
	check(audio.mix.engine==67 and audio.mix.turret==0,"legacy mix updates preserve individual choices")
	check(audio.mix.m113==23 and audio.mix.bradley==0,"legacy mix updates preserve independent allied gain and Off")
	check(audio.mix.t72==37,"legacy mix updates preserve independent T72 gain")
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
	audio.world_audio.t72_directory=""
	audio.world_audio.flight_directory=""
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

func detail_audio(folder: String) -> Node:
	var audio: Node=Audio.new()
	audio.recorded_effect_directory="";audio.supplemental.directory=folder
	for key: String in ["directory","environment_directory","soviet_directory","t72_directory","flight_directory","tank_directory","allied_directory","detail_directory"]: audio.world_audio.set(key,"")
	root.add_child(audio)
	return audio

func detail_fixture(folder: String) -> bool:
	var created: bool=DirAccess.make_dir_recursive_absolute(folder)==OK
	check(created,"task-local supplemental fixture directory writes")
	if not created: return false
	var manifest: Dictionary={"schema":1,"kind":"private source-qualified detail","cues":{}}
	for cue: String in Audio.SupplementalAudio.CUES:
		var stream: AudioStreamWAV=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=48000
		var bytes: PackedByteArray=PackedByteArray();bytes.resize(9600);stream.data=bytes
		var path: String=folder.path_join(cue+".wav")
		var saved: bool=stream.save_to_wav(path)==OK
		check(saved,"tiny mono48k16 supplemental fixture writes: "+cue)
		if not saved: return false
		manifest.cues[cue]={"file":cue+".wav","sha256":FileAccess.get_sha256(path)}
	var file: FileAccess=FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE)
	check(file!=null,"fixed seven-cue supplemental manifest writes")
	if file==null: return false
	file.store_string(JSON.stringify(manifest))
	return true

func detail_event(audio: Node, cue: String, id: int, frame: int) -> Dictionary:
	var event: Dictionary={"id":id,"frame":frame,"epoch":1,"enabled":true,"kind":"sound","ip":0x9107,"return_ip":0,"value":0,"backend":0,"sample":null,"voice":null}
	if cue=="reload":
		event.merge({"kind":"readiness_visible","ip":0x35ee,"voice":"loaded","completion_frame":frame-3,
			"text_sequence":10,"text_draw_sequence":11,"text_return_ip":0x55df,"text_pointer":0x0aca,"text_pixel_sha256":"a".repeat(64)},true)
	elif cue in ["ui_accept","ui_back","ui_error"]:
		var voice: String={"ui_accept":"pc_radio_complete","ui_back":"pc_radio_abort","ui_error":"pc_out_of_fuel"}[cue]
		var spec: Dictionary=audio.crew_catalogue[voice] if cue=="ui_error" else audio.radio_catalogue[voice]
		event.merge({"kind":"crew_visible" if cue=="ui_error" else "radio_visible","voice":voice,"text":spec.caption,
			"message_id":id,"speaker":spec.speaker if cue=="ui_error" else null,"ip":spec.assignment_ip if cue=="ui_error" else spec.assignment_ips[0],"parts":[]},true)
		for index: int in spec.source_variants[0].size():
			event.parts.append({"rect":[46+18*index,112,18,6],"draw_sequence":index+1,"source_pointer":spec.source_variants[0][index],"pixel_sha256":"a".repeat(64)})
	else:
		event.merge({"sample":"impact" if cue=="debris" else "smoke","voice":null if cue=="debris" else "smoke",
			"return_ip":0x6b25 if cue=="debris" else 0x7c07,"value":6 if cue=="debris" else 3},true)
	return event

func detail_packet(frame: int, id: int, events: Array) -> Dictionary:
	var source: Dictionary=packet(frame);source.last_id=id;source.events=events
	return source

func supplemental_source_controls() -> void:
	var folder: String=ProjectSettings.globalize_path("user://pc-audio-mix-detail-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()])
	if not detail_fixture(folder): return
	var audio: Node=detail_audio(folder)
	var detail: RefCounted=audio.supplemental
	check(detail.failure.is_empty() and detail.streams.size()==7 and detail.players.size()==7,"valid optional supplemental bank publishes exactly seven independent players")
	for cue: String in Audio.SupplementalAudio.CUES:
		var player: AudioStreamPlayer=detail.players[cue]
		check(player.bus==audio.presentation_bus and player.stream.mix_rate==48000 and player.stream.format==AudioStreamWAV.FORMAT_16_BITS and not player.stream.stereo and player.stream.loop_end==4800 and player.stream.loop_mode==(AudioStreamWAV.LOOP_FORWARD if cue=="fire" else AudioStreamWAV.LOOP_DISABLED),"supplemental exact format, loop mode and incumbent limiter: "+cue)
	var menu: MenuBar=Menu.new();menu.config_path="";menu.audio=audio;root.add_child(menu)
	var id: int=0
	for cue: String in ["reload","ui_error","ui_accept","ui_back","debris","pressure"]:
		id+=1
		var source: Dictionary=JSON.parse_string(JSON.stringify(detail_packet(10+id,id,[detail_event(audio,cue,id,10+id)])))
		var original: String=JSON.stringify(source)
		check(audio.apply_audio(source) and detail.starts.get(cue,0)==1 and detail.players[cue].playing,"complete source-qualified event adds one detail start: "+cue)
		var delivered: int=audio.delivered
		check(audio.apply_audio(source) and detail.starts.get(cue,0)==1 and audio.delivered==delivered,"repeated source identity cannot replay supplemental detail: "+cue)
		check(JSON.stringify(source)==original,"supplemental dispatch never mutates source envelope: "+cue)
	check(audio.delivered==6 and audio.cursor==2 and audio.last_voice=="smoke" and audio.engine.playing and audio.turret.playing,"detail leaves original effect/crew delivery, cadence and loops intact")
	detail.play("fire")
	var sequence: Array=[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)]
	menu.choose("foley",0)
	check(not detail.players.reload.playing and not detail.players.debris.playing and not detail.players.pressure.playing and detail.players.ui_accept.playing and detail.players.ui_back.playing and detail.players.ui_error.playing and detail.players.fire.playing,"Mechanical detail Off stops only reload/debris/pressure immediately")
	check(audio.effects.any(func(player):return player.playing) and audio.voice.playing and audio.engine.playing,"detail mute never cuts original effects, crew or motor")
	menu.choose("foley",40)
	check(not detail.players.reload.playing and not detail.players.debris.playing and not detail.players.pressure.playing,"mechanical unmute cannot replay consumed one-shots")
	gain(detail.players.debris,0.65*0.12*0.4,"Mechanical detail gain multiplies impact debris only")
	gain(detail.players.pressure,0.65*0.10*0.4,"Mechanical detail gain multiplies smoke pressure only")
	check(sequence==[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)],"detail controls never advance original source clocks or events")
	check(audio.apply_audio(detail_packet(20,7,[detail_event(audio,"reload",7,20)])),"fresh readiness after detail gain change accepted")
	gain(detail.players.reload,0.65*0.35*0.4,"Mechanical detail gain multiplies authored reload level")
	menu.choose("interface",0)
	check(["ui_accept","ui_back","ui_error"].all(func(cue):return not detail.players[cue].playing) and detail.players.reload.playing and detail.players.fire.playing,"Interface Off isolates all UI detail from mechanical and fire")
	menu.choose("interface",35)
	check(["ui_accept","ui_back","ui_error"].all(func(cue):return not detail.players[cue].playing),"interface unmute cannot replay consumed tones")
	gain(detail.players.ui_accept,0.65*0.22*0.35,"Interface gain multiplies UI detail independently")
	menu.choose("fire",0)
	check(not detail.players.fire.playing and detail.players.reload.playing,"Visible fire Off leaves mechanical detail untouched")
	menu.choose("fire",100)
	check(not detail.players.fire.playing,"fire gain alone cannot invent current source visibility")
	var starts: Dictionary=detail.starts.duplicate()
	check(audio.apply_audio(detail_packet(40,8,[detail_event(audio,"reload",8,30)])) and detail.starts==starts and audio.receipts[-1].reason=="stale-diagnostic-step","stale source readiness cannot add supplemental detail")
	var raw: Dictionary=detail_event(audio,"reload",9,41);raw.kind="reload_complete";raw.voice=null
	check(audio.apply_audio(detail_packet(41,9,[raw])) and detail.starts==starts,"raw completion without visible readiness cannot add reload detail")
	audio.set_transport_muted(true)
	var transported: Dictionary=detail_packet(42,10,[detail_event(audio,"reload",10,42)])
	check(audio.apply_audio(transported) and detail.starts==starts and detail.players.values().all(func(player):return not player.playing),"transport gate consumes source event without supplemental playback")
	audio.set_transport_muted(false);audio.apply_audio(transported)
	check(detail.starts==starts and detail.players.values().all(func(player):return not player.playing),"transport recovery cannot replay consumed detail")
	var muted: Dictionary=detail_packet(43,11,[detail_event(audio,"reload",11,43)]);muted.enabled=false
	check(audio.apply_audio(muted) and detail.starts==starts,"original source mute suppresses supplemental event")
	menu.choose("foley",100)
	check(audio.muted and detail.players.values().all(func(player):return not player.playing),"supplemental gain cannot override original source mute")
	var disabled: Dictionary=detail_event(audio,"reload",12,44);disabled.enabled=false
	check(audio.apply_audio(detail_packet(44,12,[disabled])) and detail.starts==starts,"individual original event gate suppresses detail")
	var previous: Dictionary=detail_event(audio,"reload",13,45);previous.epoch=0
	check(audio.apply_audio(detail_packet(45,13,[previous])) and detail.starts==starts,"previous source epoch cannot add current detail")
	var crew: Dictionary={"kind":"crew_visible","sample":null,"voice":"pc_hit_zero_four_three","ip":0x3d6a,"return_ip":0,"value":0,"backend":0,"enabled":true,"epoch":1,
		"id":14,"frame":46,"message_id":14,"speaker":3,"text":"We've been hit! Bearing 043","parts":[
			{"rect":[46,112,144,6],"draw_sequence":1,"source_pointer":0x95d,"pixel_sha256":"a".repeat(64)},
			{"rect":[190,112,18,6],"draw_sequence":2,"source_pointer":0x6472,"pixel_sha256":"b".repeat(64)}]}
	check(audio.apply_audio(detail_packet(46,14,[crew])) and detail.starts==starts and audio.last_voice=="pc_hit_zero_four_three","qualified non-warning crew report never acquires warning interface tone")
	# Inject only an already-admitted loop for lifecycle checks. Real source-image
	# hash qualification is deliberately not claimed by this synthetic fixture.
	detail.fire_visible=true;detail.fire_frame=audio.last_frame;detail.fire_epoch=audio.epoch;detail.fire_guard=func():return true
	detail.after_draw()
	var fire_starts: int=detail.starts.get("fire",0)
	check(detail.players.fire.playing and fire_starts==int(starts.get("fire",0))+1,"already-admitted diagnostic fire starts one retained loop")
	audio.continue_timeline()
	check(audio.apply_audio({"schema":3,"frame":46,"epoch":0,"last_id":0,"events":[],"active":false,"enabled":false}),"supplemental save-continuation primer accepted")
	detail.after_draw()
	check(detail.players.fire.playing and detail.starts.get("fire",0)==fire_starts,"save primer retains admitted fire without restarting or inventing image qualification")
	detail.observe_frame(Image.create(320,200,false,Image.FORMAT_RGB8),{"name":"SIM"},func():return true)
	detail.after_draw()
	check(not detail.players.fire.playing and detail.starts.get("fire",0)==fire_starts,"actual nonmatching source image silences retained fire without a new start")
	audio.reset_timeline()
	check(not detail.fire_visible and not detail.fire_guard.is_valid() and detail.players.values().all(func(player):return not player.playing),"timeline reset clears supplemental fire admission and playback")
	check(await audio.drain_for_shutdown(),"supplemental and original streams drain together");menu.free();audio.free()
	var invalid: Node=detail_audio(folder)
	var bad: Dictionary=detail_event(invalid,"reload",2,10);bad.text_pixel_sha256="x".repeat(64)
	var attempt: Dictionary=detail_packet(10,2,[detail_event(invalid,"debris",1,10),bad])
	var original: String=JSON.stringify(attempt)
	check(not invalid.apply_audio(attempt) and invalid.supplemental.starts.is_empty() and invalid.cursor==0 and invalid.delivered==0,"invalid final readiness proof rejects complete packet before any original or supplemental onset")
	check(JSON.stringify(attempt)==original,"rejected complete packet remains unmodified")
	await invalid.drain_for_shutdown();invalid.free()
	FileAccess.open(folder.path_join("fire.wav"),FileAccess.WRITE).store_string("corrupt")
	for bank: String in [folder,folder.path_join("absent")]:
		var isolated: Node=detail_audio(bank)
		check(isolated.supplemental.players.is_empty() and isolated.supplemental.streams.is_empty() and (not isolated.supplemental.failure.is_empty() if bank==folder else isolated.supplemental.failure.is_empty()),"last-cue hash failure rejects entire optional bank; absent bank stays optional")
		check(isolated.apply_audio(packet(10,true,true)) and isolated.failure.is_empty() and isolated.effects[0].playing and isolated.voice.playing and isolated.engine.playing,"invalid/absent supplemental bank leaves incumbent source audio intact")
		await isolated.drain_for_shutdown();isolated.free()
	for name: String in Audio.SupplementalAudio.CUES: DirAccess.remove_absolute(folder.path_join(name+".wav"))
	DirAccess.remove_absolute(folder.path_join("manifest.json"));DirAccess.remove_absolute(folder)

func run() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	output=directory.path_join("artifacts/pc-audio-mix-unit")
	var args := OS.get_cmdline_user_args()
	if "--output" in args: output=args[args.find("--output")+1]
	DirAccess.make_dir_recursive_absolute(output)
	var audio := Audio.new()
	audio.world_audio.t72_directory=""
	audio.world_audio.flight_directory=""
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
	check(menu.get_menu_count()==1 and menu.menus.size()==31,"one external Audio menu, thirty-one independently specified gain groups")
	check(Menu.DEFAULTS.t72==100 and Menu.TITLES.t72=="T-72 engine" and menu.audio_channels().has("t72") and menu.menus.has("t72"),"native T72 has its own100% default and exact title")
	var t72_choices: PopupMenu=menu.menus.t72
	check(t72_choices.get_item_text(t72_choices.get_item_index(0))=="Off" and t72_choices.get_item_index(100)>=0,"native T72 exposes independent Off through100%")
	for cue: String in ["m113","bradley","trackedfallback","wheeledfallback"]:
		check(Menu.DEFAULTS[cue]==100 and Menu.TITLES.has(cue) and menu.audio_channels().has(cue) and menu.menus.has(cue),"native allied control has an independent title and unchanged100% default: "+cue)
		var choices: PopupMenu=menu.menus[cue]
		check(choices.get_item_text(choices.get_item_index(0))=="Off" and choices.get_item_index(100)>=0,"native allied control exposes Off through100%: "+cue)
	for cue: String in ["woodland","truck","tracks","foley","interface","fire"]:
		check(Menu.DEFAULTS[cue]==100 and Menu.TITLES.has(cue) and menu.menus.has(cue),"new native private control has independent title and100% default: "+cue)
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
	menu.choose("hind",0);menu.choose("river",37);menu.choose("radio",23);menu.choose("switch",0);menu.choose("field",41);menu.choose("cow",0);menu.choose("t80",27);menu.choose("tank",43)
	check(reload.load_settings() and reload.settings.hind==0 and reload.settings.river==37 and reload.settings.radio==23 and reload.settings.switch==0 and reload.settings.field==41 and reload.settings.cow==0 and reload.settings.t80==27 and reload.settings.tank==43,"world and auxiliary controls persist independent mute and intermediate gain")
	menu.choose("m113",0);menu.choose("bradley",37)
	check(reload.load_settings() and reload.settings.m113==0 and reload.settings.bradley==37,"allied controls persist independent Off and intermediate gain")
	menu.choose("m113",43);menu.choose("bradley",0)
	check(reload.load_settings() and reload.settings.m113==43 and reload.settings.bradley==0,"each allied class independently retains saved gain and mute")
	for cue: String in ["t72","missileflight","woodland","truck","tracks","foley","interface","fire","trackedfallback","wheeledfallback"]:
		menu.choose(cue,0)
		check(reload.load_settings() and reload.settings[cue]==0,"new private control saves Off independently: "+cue)
		menu.choose(cue,37)
		check(reload.load_settings() and reload.settings[cue]==37,"new private control saves exact intermediate gain: "+cue)
	var legacy := ConfigFile.new()
	legacy.set_value("audio","effects",40);legacy.set_value("audio","motors",30)
	legacy.save(menu.config_path)
	check(reload.load_settings() and reload.settings.effects==40 and reload.settings.motors==30 and reload.settings.hind==100 and reload.settings.river==100 and reload.settings.field==100 and reload.settings.cow==100 and reload.settings.t80==100 and reload.settings.tank==100 and reload.settings.m113==100 and reload.settings.bradley==100 and Audio.EFFECT_CUES.all(func(cue):return reload.settings[cue]==100),"old preferences keep original mix and acquire unchanged individual defaults")
	check(["woodland","truck","tracks","foley","interface","fire"].all(func(cue):return reload.settings[cue]==100),"old saved preferences acquire all six private defaults without changing incumbent mix")
	check(reload.settings.t72==100,"preferences missing both tank and T72 retain the new100% default")
	for saved: Dictionary in [{"tank":0},{"tank":40},{"tank":90,"t72":0},{"tank":0,"t72":37},{"t72":37},{}]:
		var previous: ConfigFile=ConfigFile.new()
		for key: String in saved: previous.set_value("audio",key,saved[key])
		check(previous.save(menu.config_path)==OK,"T72 migration fixture writes")
		var expected_t72: int=int(saved.get("t72",saved.get("tank",100)))
		check(reload.load_settings() and reload.settings.t72==expected_t72 and reload.settings.tank==int(saved.get("tank",100)),"saved T72 wins; legacy generic balance inherits only when T72 is absent: "+str(saved))
	for saved: Dictionary in [{"tank":-1},{"tank":"bad"},{"tank":0.5},{"t72":101},{"t72":NAN},{"tank":40,"effects":"bad"},{"tank":40,"t72":0,"voice":"bad"}]:
		var previous: ConfigFile=ConfigFile.new()
		for key: String in saved: previous.set_value("audio",key,saved[key])
		check(previous.save(menu.config_path)==OK,"invalid T72 migration fixture writes")
		check(not reload.load_settings() and reload.settings==Menu.DEFAULTS and not reload.save_error.is_empty(),"invalid tank/T72/unrelated field rejects complete preferences before migration")
	var invalid_allied := ConfigFile.new()
	invalid_allied.set_value("audio","m113",101);invalid_allied.save(menu.config_path)
	check(not reload.load_settings() and reload.settings==Menu.DEFAULTS and not reload.save_error.is_empty(),"invalid saved allied gain rejects complete preference file atomically")
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
	resumed.world_audio.t72_directory=""
	resumed.world_audio.flight_directory=""
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
	await supplemental_source_controls()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors,"native_menu":menu.is_native_menu()},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_AUDIO_MIX: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
