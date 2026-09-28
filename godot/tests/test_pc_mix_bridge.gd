extends "res://tests/profile_pc_play.gd"
## Exercise live gain choices during the existing single-frame control replay.
var mix_rows: Array = []
var mix_errors: Array[String] = []

func _apply_sample(message: Dictionary) -> void:
	super._apply_sample(message)
	if profile_begin==0 or not audio_menu: return
	var offset := int(message.sequence)-warmup_sequence
	var choices := {100:["voice",0],200:["effects",30],300:["motors",20],400:["master",0],
		500:["master",80],600:["voice",60],700:["effects",100],800:["motors",100]}
	if choices.has(offset):
		var choice: Array=choices[offset]
		audio_menu.menus[choice[0]].id_pressed.emit(choice[1])
	elif offset==900: audio_menu.popup.id_pressed.emit(1000)
	else: return
	mix_rows.append({"sequence":message.sequence,"mix":pc_audio.mix.duplicate(),"source_muted":pc_audio.muted})
	if not audio_menu.config_path.is_empty(): mix_errors.append("diagnostic changed user preferences")
	if not audio_menu.save_error.is_empty(): mix_errors.append(audio_menu.save_error)

func _capture() -> void:
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var reference := directory.path_join("artifacts/pc-play-final-controls-02/pacing.json")
	var prior: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(reference))
	var checks := {"1020_frames":sample_hashes.size()==1020 and prior.sample_hashes.size()==1020,
		"nine_mix_changes":mix_rows.size()==9,"audio_healthy":pc_audio.failure.is_empty(),
		"default_mix_restored":pc_audio.mix==audio_menu.DEFAULTS,
		"all_current_inputs_equal":bridge.requests.size()==prior.requests.size(),
		"all_paired_RAM_video_equal":sample_hashes.size()==prior.sample_hashes.size(),
		"no_errors":mix_errors.is_empty()}
	for i in mini(bridge.requests.size(),prior.requests.size()):
		checks.all_current_inputs_equal=checks.all_current_inputs_equal and bridge.requests[i].frames==prior.requests[i].frames and bridge.requests[i].keys==prior.requests[i].keys
	for i in mini(sample_hashes.size(),prior.sample_hashes.size()):
		checks.all_paired_RAM_video_equal=checks.all_paired_RAM_video_equal and sample_hashes[i].sequence==prior.sample_hashes[i].sequence and sample_hashes[i].frame_audit==prior.sample_hashes[i].frame_audit
	FileAccess.open(output.path_join("mix-report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"errors":mix_errors,"changes":mix_rows,"native_menu":audio_menu.is_native_menu(),
		"reference":reference,"reference_sha256":FileAccess.get_sha256(reference),
		"scope":"Actual original host, single-frame production input path and renderer; gain callbacks only. RAM/video/input comparison covers 1020 frames, not historical pacing."},"  "))
	if not checks.values().all(func(v):return v==true): bridge.failure="live mix comparison failed"
	print("PC_MIX_BRIDGE: "+JSON.stringify(checks))
	await super._capture()
