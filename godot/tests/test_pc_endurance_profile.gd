extends "res://tests/profile_pc_play.gd"
## Uses the unchanged production process loop. Measures convenience-test packet
## copying only after the timed run; never substitutes a lighter render path.
func _capture() -> void:
	var elapsed_ms:float=(profile_previous-profile_begin)/1000.0
	var copy_ms:=measure(func():last_profile_message.duplicate(true))
	FileAccess.open(output.path_join("endurance-profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"samples":profile_rows.size(),"wall_ms":elapsed_ms,"fps":profile_rows.size()*1000.0/elapsed_ms,"final_audit":last_profile_message.get("frame_audit",{}),"final_sequence":last_profile_message.get("sequence"),"convenience_packet_copy_mean_ms":copy_ms,"audio_failure":pc_audio.failure,"static_memory_bytes":OS.get_static_memory_usage(),"scope":"Existing profiler around unchanged production loop; current packet deep-copy microbenchmark runs after timed playback. No checkpoint operations during timed run."},"  "))
	await super._capture()
