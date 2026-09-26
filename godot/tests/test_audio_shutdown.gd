extends SceneTree
const Sound = preload("res://scripts/audio.gd")

func _initialize() -> void:
	run_checks.call_deferred()

func run_checks() -> void:
	var sound = Sound.new()
	root.add_child(sound)
	sound.speak("ready")
	sound.play("cannon")
	sound.update_engine(10, true)
	await process_frame
	var references: Array[WeakRef] = []
	for player in [sound.engine, sound.voice, sound.effects[0]]:
		if not player.has_stream_playback():
			push_error("Audio shutdown test did not exercise live playback")
			quit(1)
			return
		references.append(weakref(player.get_stream_playback()))
	# Match menu/scene changes: players may already be stopped when quit begins.
	# AudioServer can still retain the previous playback after stop() returns.
	sound.stop_all()
	var drained: bool = await sound.drain_for_shutdown()
	if not drained or references.any(func(reference): return reference.get_ref() != null):
		push_error("Audio playback still retained after drain")
		quit(1)
		return
	sound.queue_free()
	await process_frame
	print("AUDIO_SHUTDOWN: three live playback instances released before teardown")
	quit.call_deferred()
