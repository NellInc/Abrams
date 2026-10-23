extends SceneTree
const Audio=preload("res://scripts/pc_audio.gd")
const Score=preload("res://scripts/pc_suno_music.gd")
var checks:=0
var errors: Array[String]=[]
func _initialize()->void:
	create_timer(60).timeout.connect(func():printerr("PC_SUNO_MUSIC: deadline exceeded");quit(2))
	run.call_deferred()
func check(ok: bool, label: String)->void:
	checks+=1
	if not ok: errors.append(label)
func packet(frame: int, enabled: bool=true, event: bool=false)->Dictionary:
	return {"schema":3,"frame":frame,"epoch":1,"last_id":1 if event else 0,"active":true,"enabled":enabled,"loops":{},
		"events":[{"id":1,"frame":frame,"epoch":1,"kind":"sound","ip":0x9107,"return_ip":0x33c4,"value":1,"backend":0,"enabled":true,"sample":"cannon","voice":"on_the_way"}] if event else []}
func run()->void:
	var bank:=Score.new()
	var source:=Image.create(320,200,false,Image.FORMAT_RGB8);source.fill(Color.BLACK)
	var program: Dictionary={"name":"SIM","load_segment":500}
	var state: Dictionary={"basis":"original-PC-SIM-read-only","load_segment":500,"station":"gunner"}
	check(bank.gameplay_context(state,program)=="idyll","quiet baseline")
	bank.update_source(packet(100));bank.observe_event({"sample":"cannon"})
	check(bank.gameplay_context(state,program)=="battle","accepted shot raises combat")
	bank.update_source(packet(101));bank.observe_event({"voice":"pc_engine_damaged"})
	check(bank.gameplay_context(state,program)=="crisis","visible damage raises crisis")
	bank.update_source(packet(102,false));bank.update_source(packet(402,false));bank.update_source(packet(403,true))
	check(bank.gameplay_context(state,program)=="crisis" and bank.crisis_until==1003,"original pause freezes the held cue")
	bank.reset_score();bank.update_source(packet(101));bank.observe_event({"voice":"pc_hit_zero_four_three"})
	check(bank.gameplay_context(state,program)=="crisis","visible hit report selects crisis without hidden enemies")
	bank.update_source(packet(702))
	check(bank.gameplay_context(state,program)=="battle","crisis releases to held battle")
	bank.update_source(packet(1002))
	check(bank.gameplay_context(state,program)=="idyll","quiet release uses source frames")
	bank.observe_event({"sample":"cannon"})
	check(bank.gameplay_context(state,program)=="battle_flank","second engagement selects flanking arrangement")
	bank.update_source(packet(1003));bank.observe_event({"sample":"machinegun"})
	check(bank.gameplay_context(state,program)=="battle_flank","continued firing keeps arrangement stable")
	bank.update_source(packet(2000));bank.observe_event({"sample":"impact"})
	check(bank.gameplay_context(state,program)=="battle_pressure","third engagement selects sustained pressure")
	bank.update_source(packet(3000));bank.observe_event({"sample":"cannon"})
	check(bank.gameplay_context(state,program)=="battle","fourth engagement returns to authored first arrangement")
	bank.observe_event({"voice":"pc_radio_complete"})
	check(bank.gameplay_context(state,program)=="success","visible complete message selects success")
	bank.reset_score();bank.observe_event({"voice":"pc_radio_abort"})
	check(bank.gameplay_context(state,program)=="failure","abort selects failure")
	check(bank.gameplay_context({"basis":"invented","load_segment":500,"station":"gunner"},program).is_empty(),"unverified gameplay state rejected")
	state.world={"hidden_enemy_count":900}
	check(bank.gameplay_context(state,program)=="failure","hidden world contents never select score")
	bank.reset_score()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(source.get_region(Rect2i(0,0,8,8)).get_data())
	var run: Dictionary={"text":"You blew away the wrong side.","rect":[0,0,8,8],"pixel_sha256":hash.finish().hex_encode()}
	var end: Dictionary={"name":"END","load_segment":500}
	check(bank.context_for_frame(source,end,{"frontend_program":end,"text_runs":[run]})=="friendly_fire","visible original friendly-fire verdict selects doom")
	check(bank.context_for_frame(source,end,{"frontend_program":end,"text_runs":[]})=="friendly_fire","verdict holds across original END redraws")
	bank.reset_score();source.set_pixel(0,0,Color.WHITE)
	check(bank.context_for_frame(source,end,{"frontend_program":end,"text_runs":[run]}).is_empty(),"changed verdict pixels cannot assert guilt")
	bank.update_source(packet(100));bank.observe_event({"sample":"cannon"});bank.rebase_source()
	check(bank.battle_until==900 and bank.source_frame==0,"save-host restart preserves remaining hold")
	bank.reset_score();check(bank.result.is_empty() and bank.battle_until==-1,"restore clears outcome and combat holds")
	if FileAccess.file_exists(bank.directory.path_join("manifest.json")):
		bank.prewarm()
		check(bank.failure.is_empty() and bank.failures.is_empty() and bank.streams.size()==19,"nineteen actual score streams verify and decode")
		for context in Score.STINGERS:
			check(bank.track_for_context(context)==Score.STINGERS[context] and bank.followup_track(Score.STINGERS[context])=="aftermath","result stinger and aftermath route: "+context)
		check(bank.followup_track("ending_victory")=="aftermath" and bank.followup_track("ending_defeat")=="aftermath","full campaign endings release into aftermath")
		var second_bank:=Score.new();second_bank.prewarm()
		check(second_bank.get_stream("menu")==bank.get_stream("menu"),"immutable independent PCM decodes once per session")
		for context in Score.SCORE_CONTEXTS:
			var stream:=bank.get_stream(context)
			check(stream!=null and stream.get_length()>2.0,"actual playable cue: "+context)
			if stream==null:continue
			check((stream.loop_mode==AudioStreamWAV.LOOP_FORWARD)==bank.manifest.tracks[context].loop,"authored loop/one-shot policy: "+context)
			if stream.loop_mode==AudioStreamWAV.LOOP_FORWARD:
				check(stream.data.slice(-4)==stream.data.slice(stream.loop_begin*4,stream.loop_begin*4+4),"exact sample-continuous loop: "+context)
				check(int(bank.manifest.tracks[context].loop_bars) in [8,16,24,32],"complete musical phrase edit: "+context)
			if context.begins_with("stinger_"): check(stream.get_length()<=6.0,"short consequence stinger: "+context)
		var root_path:=bank.directory.get_base_dir().get_base_dir()
		for spec in [["local-art/pc-splash-aftermath-v1/catalog.json","native_asset","scene1","SIM","death"],
			["local-art/pc-newspapers-v1/newspapers.json","native","victory","END","ending_victory"],
			["local-art/pc-newspapers-v1/newspapers.json","native","defeat","END","ending_defeat"],
			["local-art/pc-newspapers-v1/newspapers.json","native","stalemate","END","aftermath"]]:
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join(spec[0])))
			for row in data.entries:
				if row.name!=spec[2]:continue
				var original: String=row.expected_path if spec[1]=="native_asset" else "local-art/pc-newspapers-v1/"+row.name+"-pc.png"
				var image:=Image.load_from_file(root_path.path_join(original));image.convert(Image.FORMAT_RGB8)
				check(bank.context_for_frame(image,{"name":spec[3]},{} )==spec[4],"actual original screen selects "+spec[4])
		# Reconstruct the original ATBASE bytes through the same pinned palette
		# used by the existing motor-pool renderer. Historical captures may be absent.
		var motor: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(root_path.path_join("local-art/pc-motor-pool-v1/motor-pool.json")))
		var pixels:=PackedByteArray()
		for byte in Marshalls.base64_to_raw(motor.packed_indices_base64):
			for index in [byte>>4,byte&15]: pixels.append_array(preload("res://scripts/pc_frontend_art.gd").MOTOR_PALETTE[index])
		var pool:=Image.create_from_data(320,200,false,Image.FORMAT_RGB8,pixels)
		check(bank.context_for_frame(pool,program,{})=="arming","original motor-pool reconstruction selects ammunition preparation")
		pool.set_pixel(50,150,Color.WHITE)
		check(bank.context_for_frame(pool,program,{})=="arming","ammunition-choice changes retain preparation cue")
		var audio:=Audio.new();root.add_child(audio)
		check(audio.music_bank.independent,"production selects installed Suno bank")
		check(audio.music_context_for_frame(null,program,{},state).is_empty(),"missing framebuffer cannot select gameplay music")
		audio.apply_music_context("menu",true);check(audio.music.playing,"actual menu starts")
		audio.apply_music_context("briefing",true)
		check(audio.music.playing and audio.music_tail.playing,"screen change crossfades two real streams")
		for i in 13:audio._process(0.05)
		check(not audio.music_tail.playing,"crossfade tail ends")
		audio.speak("on_the_way");audio._process(0.01)
		check(absf(db_to_linear(audio.music.volume_db)-0.65*0.7*0.3*0.32)<0.00001,"crew voice ducks score by about ten dB")
		audio.music_source_program="SIM"
		check(audio.apply_audio(packet(1,true,true)),"fresh source event accepted")
		check(audio.music_bank.battle_until==901,"fresh event selects held battle")
		audio.apply_music_context("battle",true)
		var snapshot: int=audio.music_bank.battle_until
		check(audio.apply_audio(packet(1,true,true)) and audio.music_bank.battle_until==snapshot,"repeated source envelope cannot refresh combat hold")
		var disabled:=packet(2,false);disabled.last_id=1
		check(audio.apply_audio(disabled) and not audio.music.playing and not audio.music_tail.playing,"original F5/pause stops both score players immediately")
		audio.music_source_program="END";audio.apply_music_context("success",true)
		check(audio.music.playing and audio.music_track=="stinger_success","END plays the short result cue despite inactive SIM sound gate")
		# Exercise an actual short PCM's natural finished signal, not a fake stop.
		var short:=AudioStreamWAV.new();short.format=AudioStreamWAV.FORMAT_16_BITS;short.mix_rate=24000;short.stereo=true
		var silence:=PackedByteArray();silence.resize(4800);short.data=silence
		audio.music.stop();audio.music_tail.stop();audio.music.stream=short;audio.music.play()
		var starts:=audio.music_starts
		await create_timer(0.6).timeout
		audio.apply_music_context("success",true)
		check(audio.music.playing and audio.music_track=="aftermath" and starts+1==audio.music_starts,"natural stinger completion starts aftermath once")
		starts=audio.music_starts;audio.apply_music_context("success",true)
		check(audio.music_track=="aftermath" and starts==audio.music_starts,"result redraw cannot replay stinger or restart aftermath")
		audio.set_transport_muted(true)
		check(not audio.music.playing,"transport mute stops aftermath")
		audio.set_transport_muted(false)
		check(audio.music_track=="aftermath" and audio.music.playing,"unmute resumes aftermath without replaying stinger")
		audio.music_source_program="SIM";audio.music_bank.game_enabled=false;audio.music_bank.source_active=false
		audio.apply_music_context("death",true)
		check(audio.music.playing and audio.music_track=="stinger_death","verified destroyed screen may play after source SIM observer detaches")
		audio.music_bank.source_active=true;audio.apply_music_context("death",true)
		check(not audio.music.playing,"active original F5 gate retains priority over destruction stinger")
		audio.reset_timeline();check(not audio.music.playing and not audio.music_tail.playing and audio.music_bank.result.is_empty(),"restore clears both score players and outcome")
		check(await audio.drain_for_shutdown(),"shutdown drains score and crossfade players")
		audio.free()
	else:print("SUNO_ASSETS_NOT_RUN: optional local masters absent")
	for error in errors:printerr("FAIL: "+error)
	print("PC_SUNO_MUSIC: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
