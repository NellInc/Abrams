extends "res://tests/test_pc_audio_mix.gd"
## Accepted timbres, original players and clocks, no hull/debris layer.
func wav(frames: int, value: int = 0) -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.mix_rate=48000; stream.format=AudioStreamWAV.FORMAT_16_BITS
	var pcm: PackedByteArray = PackedByteArray(); pcm.resize(frames*2); pcm.fill(value)
	stream.data=pcm
	return stream

func fixture_audio(folder: String) -> Node:
	var audio: Node = Audio.new()
	audio.recorded_effect_directory=""; audio.polish.directory=""; audio.supplemental.directory=folder
	root.add_child(audio)
	audio.recorded_effect_streams.impact=wav(134400)
	audio.recorded_effect_streams.engine=wav(96000)
	return audio

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output=args[args.find("--output")+1]; DirAccess.make_dir_recursive_absolute(output)
	var folder: String = output.path_join("detail"); detail_fixture(folder)
	var audio: Node = fixture_audio(folder)
	var polish: RefCounted = audio.polish
	polish.directory=output.path_join("bank"); DirAccess.make_dir_recursive_absolute(polish.directory)
	var bank: Dictionary = {"schema":1,"kind":"private restrained polish","cues":{}}
	for cue: String in polish.FRAMES:
		bank[cue+"_pcm_sha256"]=polish.pcm_hash(audio.recorded_effect_streams[cue])
		var path: String = polish.directory.path_join(cue+".wav")
		check(wav(polish.FRAMES[cue],2).save_to_wav(path)==OK,"fixed accepted PCM fixture writes: "+cue)
		bank.cues[cue]={"file":cue+".wav","sha256":FileAccess.get_sha256(path)}
	var manifest: String = polish.directory.path_join("manifest.json")
	var writer: FileAccess = FileAccess.open(manifest,FileAccess.WRITE)
	writer.store_string(JSON.stringify(bank)); writer.close()
	var child_count: int = audio.get_child_count()
	var incumbent_engine: AudioStream = audio.engine.stream
	polish.setup(audio)
	check(polish.failure.is_empty() and polish.streams.size()==1,"only accepted shell impact publishes")
	if polish.streams.size()!=1: printerr(polish.failure); audio.free(); quit(1); return
	check(audio.get_child_count()==child_count,"timbre bank adds no hull or other playback nodes")
	check(audio.engine.stream==incumbent_engine and audio.engine.stream.loop_end==96000 and not polish.streams.has("engine"),"shell bank leaves original recorded engine untouched")
	check(audio.get_stream("impact")==polish.streams.impact and polish.streams.impact.loop_mode==AudioStreamWAV.LOOP_DISABLED,"approved shell impact uses existing logical cue and exact one-shot")
	check(not audio.supplemental.players.has("debris"),"debris has no player even when the historical bank exists")
	for id: int in range(1,4):
		var source: Dictionary = detail_packet(10+id,id,[detail_event(audio,"debris",id,10+id)])
		var original: String = JSON.stringify(source)
		check(audio.apply_audio(source) and audio.delivered==id,"one qualified original impact remains one delivered event")
		var effect: AudioStreamPlayer = audio.effects[(audio.cursor-1)%audio.effects.size()]
		check(effect.stream==polish.streams.impact and effect.playing,"accepted shell sound starts in original pool slot")
		gain(effect,audio.effect_gain("impact"),"shell gain retains saved logical impact control")
		audio.supplemental.play("debris")
		check(not audio.supplemental.starts.has("debris") and not audio.supplemental.players.has("debris"),"neither source impacts nor direct calls can play debris")
		check(audio.apply_audio(source) and audio.delivered==id and JSON.stringify(source)==original,"duplicate identity neither replays nor mutates source")
	var motor: Dictionary = packet(20); motor.last_id=3
	motor.loops.engine.amplitude=1; motor.loops.engine.period*=2
	check(audio.apply_audio(motor),"original motor channel accepted with long presentation stream")
	gain(audio.engine,.65*.08/3,"original amplitude owns long engine gain")
	check(is_equal_approx(audio.engine.pitch_scale,.5) and audio.engine.stream.loop_end==96000,"original period owns pitch without changing the WAV endpoint")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"impact":0})
	check(audio.effects.all(func(p):return not p.playing) and audio.engine.playing,"impact Off isolates the source engine")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"impact":100,"engine":0})
	check(not audio.engine.playing and audio.effects.all(func(p):return not p.playing),"engine Off stops long loop; unmuting impact never replays shots")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"engine":100})
	check(audio.engine.playing,"engine resumes only the still-active original channel")
	var off: Dictionary = packet(21,false); off.last_id=3
	check(audio.apply_audio(off) and not audio.engine.playing,"source mute stops long loop immediately")
	audio.reset_timeline()
	var restored: Dictionary = packet(1); restored.last_id=0
	check(audio.apply_audio(restored) and audio.engine.playing and audio.engine.stream==incumbent_engine,"restore retains the earlier engine and resets original timeline")
	audio.continue_timeline()
	check(audio.apply_audio({"schema":3,"frame":1,"epoch":0,"last_id":0,"events":[],"active":false,"enabled":false}) and audio.engine.playing,"save primer preserves the original active engine")
	var invalid: Node = fixture_audio(folder)
	var original_engine: AudioStream = invalid.engine.stream
	bank.cues.impact.sha256="bad"; writer=FileAccess.open(manifest,FileAccess.WRITE); writer.store_string(JSON.stringify(bank)); writer.close()
	invalid.polish.directory=polish.directory; invalid.polish.setup(invalid)
	check(not invalid.polish.failure.is_empty() and invalid.polish.streams.is_empty() and invalid.engine.stream==original_engine and invalid.get_stream("impact")==invalid.recorded_effect_streams.impact,"bad last file preserves both incumbent streams atomically")
	check(await invalid.drain_for_shutdown(),"invalid optional bank leaves ordinary shutdown intact"); invalid.free()
	check(await audio.drain_for_shutdown(),"accepted long stream stops and drains without waiting for loop end"); audio.free()
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"errors":errors},"  "))
	for error: String in errors: printerr("FAIL: "+error)
	print("PC_AUDIO_POLISH: %d checks, %d errors"%[checks,errors.size()]); quit(0 if errors.is_empty() else 1)
