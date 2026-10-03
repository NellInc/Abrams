extends RefCounted
## Research transport only. The child runs the original PC executable.
## This class never instantiates the authored range simulation.
const Keyboard = preload("res://scripts/pc_keyboard.gd")

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
var python_path := ""
var killed := false

## Same interpreter rule as PC Bridge.command: ABRAMS_PYTHON, else python3 on PATH.
static func default_python() -> String:
	var python := OS.get_environment("ABRAMS_PYTHON")
	return "python3" if python.is_empty() else python

func start(python: String, state_path: String, save_path: String, log_path: String, backend: String = "reference", frame_audit := false) -> bool:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	expected_protocol = 4 if backend == "trace" else 2
	var arguments := ["-u",project_root.path_join("tools/pc_bridge_host.py"),"--saves",save_path,"--backend",backend]
	if not state_path.is_empty(): arguments.append_array(["--state",state_path])
	if frame_audit: arguments.append("--frame-audit")
	python_path = python
	process = OS.execute_with_pipe(python, arguments, false)
	if process.is_empty():
		failure = "Could not start the local PC core host (python: %s; set ABRAMS_PYTHON to a Python 3 interpreter)." % python
		return false
	request_started = Time.get_ticks_msec()
	return true

func step(frames: int, keys: Array) -> bool:
	if pending or closing or not failure.is_empty() or process.is_empty():
		return false
	waiting_id = next_id
	next_id += 1
	# Safety net for every caller: the host treats an oversized key set as fatal.
	_write({"op": "step", "id": waiting_id, "frames": frames, "keys": keys.slice(0, Keyboard.MAX_KEYS)})
	pending = true
	request_started = Time.get_ticks_msec()
	return failure.is_empty()

func state_command(operation: String, slot: int) -> bool:
	if pending or closing or not failure.is_empty() or process.is_empty(): return false
	if operation not in ["save_state","load_state"] or slot<0 or slot>5 or (operation=="save_state" and slot==0): return false
	waiting_id=next_id
	next_id+=1
	_write({"op":operation,"id":waiting_id,"slot":slot})
	pending=true
	request_started=Time.get_ticks_msec()
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
		if value.get("type") not in ["ready", "sample", "state_result"] or int(value.get("id", -2)) != waiting_id:
			failure = "Unexpected PC bridge response sequence."
			break
		if value.get("type") == "ready" and int(value.get("protocol", 0)) != expected_protocol:
			failure = "Unsupported original-PC bridge protocol."
			break
		pending = false
		messages.append(value)
	# Keep the first, most specific failure (a host error line precedes its exit).
	if failure.is_empty() and pending and not closing and Time.get_ticks_msec() - request_started > 30000:
		failure = "PC bridge response timed out; see the local host log."
	if failure.is_empty() and not closing and not OS.is_process_running(int(process.pid)):
		failure = "PC core host exited%s; see the local host log." % ("" if python_path.is_empty() else " (python: %s)" % python_path)
	return messages

func close() -> void:
	if closing or process.is_empty():
		return
	closing = true
	if OS.is_process_running(int(process.pid)):
		_write({"op": "quit"})

## Test harnesses only: end our own wedged host after a bounded quit. The viewer
## never signals it (exit closes the pipes and the supervisor shuts down on EOF).
## Godot reaps a killed child and forgets its pid, so later queries use the flag.
func kill() -> void:
	if not has_exited() and OS.kill(int(process.pid)) == OK: killed = true

func has_exited() -> bool:
	return process.is_empty() or killed or not OS.is_process_running(int(process.pid))

func exit_code() -> int:
	return OS.get_process_exit_code(int(process.pid)) if not process.is_empty() and not killed else -1
