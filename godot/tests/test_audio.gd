extends SceneTree
## Load the actual generated crew samples and compare their imported metadata.

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var script_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/crew_voice_script.json"))
	var receipt = JSON.parse_string(FileAccess.get_file_as_string("res://assets/audio/provenance.json"))
	var checked := 0
	for cue in script_data.cues:
		var path := "res://assets/audio/voice_%s.wav" % cue
		var stream = load(path) as AudioStreamWAV
		if stream == null or not receipt.voices.has(cue):
			push_error("Missing generated voice: " + cue)
			quit(1)
			return
		var entry: Dictionary = receipt.voices[cue]
		if stream.mix_rate != int(entry.sample_rate) or stream.stereo or stream.data.is_empty():
			push_error("Imported voice metadata mismatch: " + cue)
			quit(1)
			return
		if absf(stream.get_length() - float(entry.duration_seconds)) > 0.001:
			push_error("Imported voice duration mismatch: " + cue)
			quit(1)
			return
		if entry.generator not in [script_data.preferred_model, script_data.fallback_model] or entry.text != script_data.cues[cue].caption:
			push_error("Voice script/provider mismatch: " + cue)
			quit(1)
			return
		stream = null
		checked += 1
	print("AUDIO: %d generated crew samples loaded with matching format, duration and captions" % checked)
	quit(0)
