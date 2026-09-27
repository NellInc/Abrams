extends RefCounted
## Research transport only. The child runs the original PC executable.
## This class never instantiates the authored range simulation.

var process: Dictionary = {}
var pending := true
var failure := ""
var buffered := ""
var log_file: FileAccess
var next_id := 0
var waiting_id := -1
var request_started := 0
var closing := false
var expected_protocol := 2

func start(python: String, state_path: String, save_path: String, log_path: String, backend: String = "reference") -> bool:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	expected_protocol = 3 if backend == "trace" else 2
	process = OS.execute_with_pipe(python, ["-u", project_root.path_join("tools/pc_bridge_host.py"),
		"--state", state_path, "--saves", save_path, "--backend", backend], false)
	if process.is_empty():
		failure = "Could not start the local PC core host."
		return false
	request_started = Time.get_ticks_msec()
	return true

func step(frames: int, keys: Array) -> bool:
	if pending or closing or not failure.is_empty() or process.is_empty():
		return false
	waiting_id = next_id
	next_id += 1
	_write({"op": "step", "id": waiting_id, "frames": frames, "keys": keys})
	pending = true
	request_started = Time.get_ticks_msec()
	return failure.is_empty()

func _write(message: Dictionary) -> void:
	var pipe: FileAccess = process.stdio
	pipe.store_buffer((JSON.stringify(message) + "\n").to_utf8_buffer())
	if pipe.get_error() != OK:
		failure = "PC bridge command write failed: %s" % pipe.get_error()

func poll() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	if process.is_empty():
		return messages
	var errors: PackedByteArray = process.stderr.get_buffer(65536)
	if log_file and not errors.is_empty():
		log_file.store_buffer(errors)
		log_file.flush()
	var bytes: PackedByteArray = process.stdio.get_buffer(1024 * 1024)
	buffered += bytes.get_string_from_utf8()
	if buffered.length() > 2 * 1024 * 1024:
		failure = "Oversized PC bridge response."
		return messages
	while "\n" in buffered:
		var end := buffered.find("\n")
		var value = JSON.parse_string(buffered.substr(0, end))
		buffered = buffered.substr(end + 1)
		if not value is Dictionary:
			failure = "Malformed PC bridge response."
			break
		if value.get("type") == "error":
			failure = str(value.get("message", "PC core error"))
			break
		if value.get("type") not in ["ready", "sample"] or int(value.get("id", -2)) != waiting_id:
			failure = "Unexpected PC bridge response sequence."
			break
		if value.get("type") == "ready" and int(value.get("protocol", 0)) != expected_protocol:
			failure = "Unsupported original-PC bridge protocol."
			break
		pending = false
		messages.append(value)
	if pending and not closing and Time.get_ticks_msec() - request_started > 30000:
		failure = "PC bridge response timed out; see the local host log."
	if not closing and not OS.is_process_running(int(process.pid)):
		failure = "PC core host exited; see the local host log."
	return messages

func close() -> void:
	if closing or process.is_empty():
		return
	closing = true
	if OS.is_process_running(int(process.pid)):
		_write({"op": "quit"})

func has_exited() -> bool:
	return process.is_empty() or not OS.is_process_running(int(process.pid))

func exit_code() -> int:
	return OS.get_process_exit_code(int(process.pid)) if not process.is_empty() else -1
