extends SceneTree
## Synthetic PCM only; no game audio is captured or written to disk.
const Audio=preload("res://scripts/pc_audio.gd")
var checks:=0
var errors:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok: errors.append(label)
func synthetic(level:float)->AudioStreamWAV:
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=48000
	var bytes:=PackedByteArray()
	bytes.resize(48000*2)
	for i in 48000:
		var t:=float(i)/48000.0
		var envelope:=clampf((t-0.04)/0.005,0.0,1.0)*clampf((0.9-t)/0.005,0.0,1.0)
		bytes.encode_s16(i*2,roundi(32767*level*envelope*sin(TAU*440.0*t)))
	stream.data=bytes
	return stream
func peak(buffer:PackedVector2Array)->float:
	var value:=0.0
	for frame in buffer: value=maxf(value,maxf(absf(frame.x),absf(frame.y)))
	return value
func onset(buffer:PackedVector2Array)->int:
	for i in buffer.size():
		if absf(buffer[i].x)>0.001: return i
	return -1
func run()->void:
	var original_buses:=AudioServer.bus_count
	var master_effects:=AudioServer.get_bus_effect_count(0)
	var audio:=Audio.new()
	root.add_child(audio)
	var bus:=AudioServer.get_bus_index(audio.presentation_bus)
	check(bus>0 and AudioServer.bus_count==original_buses+1,"owned presentation bus created")
	check(AudioServer.get_bus_effect_count(0)==master_effects,"Master effects unchanged")
	check(AudioServer.get_bus_effect_count(bus)==1,"only dedicated limiter installed")
	var limiter=AudioServer.get_bus_effect(bus,0)
	check(limiter is AudioEffectHardLimiter and limiter.ceiling_db==-1.0,"minus one dB ceiling")
	for player in [audio.engine,audio.voice,audio.turret,audio.music]+audio.effects:
		check(player.bus==audio.presentation_bus,"every existing PC player routes through limiter")
	var other:=Audio.new()
	root.add_child(other)
	var other_bus:=other.presentation_bus
	check(other_bus!=audio.presentation_bus,"concurrent instances never borrow a bus")
	check(await other.drain_for_shutdown(),"second instance drains")
	other.queue_free();await process_frame
	check(AudioServer.get_bus_index(other_bus)==-1,"second instance removes only its bus")
	var before:=AudioEffectCapture.new()
	before.buffer_length=3.0
	var after:=AudioEffectCapture.new()
	after.buffer_length=3.0
	AudioServer.add_bus_effect(bus,before,0)
	AudioServer.add_bus_effect(bus,after,2)
	# Eight identical dry waveforms stress coherent effect overlap; one voice
	# uses the ordinary authored gains and the same shared limiter.
	var tone:=synthetic(0.8)
	audio.cache.cannon=tone
	audio.cache.voice_on_the_way=tone
	for i in 8: audio.play("cannon")
	audio.speak("on_the_way")
	await create_timer(0.5).timeout
	var raw:=before.get_buffer(before.get_frames_available())
	var limited:=after.get_buffer(after.get_frames_available())
	check(raw.size()>1000 and raw.size()==limited.size(),"actual matching pre/post mixer PCM acquired")
	check(before.get_discarded_frames()==0 and after.get_discarded_frames()==0,"capture has no missing frames")
	var input_peak:=peak(raw)
	var output_peak:=peak(limited)
	check(input_peak>1.5,"synthetic overlap actually exceeds full scale before limiter")
	check(output_peak>0.1 and output_peak<=db_to_linear(-1.0)+0.00002,"non-silent mix remains below dedicated ceiling")
	var clipped:=0
	for frame in limited:
		if absf(frame.x)>=1.0 or absf(frame.y)>=1.0: clipped+=1
	check(clipped==0,"no full-scale output frames")
	var first_in:=onset(raw)
	var first_out:=onset(limited)
	var delay:=float(first_out-first_in)/AudioServer.get_mix_rate()
	check(first_in>=0 and first_out>=first_in and delay<=0.015,"added synthetic onset delay bounded to 15 ms")
	metrics={"driver":AudioServer.get_driver_name(),"mix_rate":AudioServer.get_mix_rate(),"frames":limited.size(),
		"input_peak":input_peak,"output_peak":output_peak,"clipped_frames":clipped,"added_onset_seconds":delay}
	# Transport silence stops all existing players. Measure limiter tail relative to the pre-effect mixer, so Godot driver
	# buffering is not mislabeled as added limiter delay. No resume catchup.
	# Keep the test bus processing a known -40 dB synthetic probe after
	# production players stop. Godot elides all-zero input before bus effects;
	# an empty capture is not tail evidence. This probe is test-only.
	var silence:=AudioStreamPlayer.new()
	root.add_child(silence)
	silence.bus=audio.presentation_bus
	silence.stream=synthetic(0.01)
	silence.play()
	audio._remember_playback(silence)
	audio.set_transport_muted(true)
	check(not audio.voice.playing and not audio.effects.any(func(p):return p.playing),"transport stops players")
	await create_timer(0.35).timeout
	var tail_raw:=before.get_buffer(before.get_frames_available())
	var tail:=after.get_buffer(after.get_frames_available())
	check(tail.size()>1000 and tail.size()==tail_raw.size(),"actual paired stop-transition PCM acquired")
	var last_raw_loud:=-1
	var last_out_loud:=-1
	for i in tail.size():
		if absf(tail_raw[i].x)>0.02: last_raw_loud=i
		if absf(tail[i].x)>0.02: last_out_loud=i
	var tail_delay:=float(last_out_loud-last_raw_loud)/AudioServer.get_mix_rate()
	check(last_raw_loud>=0 and last_out_loud>=0 and tail_delay>=0 and tail_delay<=0.015,"limiter adds at most 15 ms to observed stop tail")
	var settled:=tail.slice(tail.size()-1024)
	check(peak(settled)>0.001 and peak(settled)<0.0101,"overload settles to known probe level")
	metrics["post_stop_frames"]=tail.size()
	metrics["settled_probe_peak"]=peak(settled)
	metrics["added_stop_tail_seconds"]=tail_delay
	silence.stop();silence.queue_free()
	audio.set_transport_muted(false)
	check(not audio.voice.playing and not audio.effects.any(func(p):return p.playing),"resume cannot restart consumed samples")
	check(await audio.drain_for_shutdown(),"limited playback drains")
	var name:=audio.presentation_bus
	audio.queue_free();await process_frame
	check(AudioServer.get_bus_index(name)==-1 and AudioServer.bus_count==original_buses,"owned bus fully removed at teardown")
	check(AudioServer.get_bus_effect_count(0)==master_effects,"Master preserved after teardown")
	print("PC_AUDIO_LIMITER_METRICS: "+JSON.stringify(metrics))
	for error in errors: printerr("FAIL: "+error)
	print("PC_AUDIO_LIMITER: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
