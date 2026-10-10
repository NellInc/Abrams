extends RefCounted
## Browser transport for the same original-program packets consumed by Play.
## JavaScript owns a dedicated WebAssembly worker, never a replacement game.
const Keyboard = preload("res://scripts/pc_keyboard.gd")

var pending := true
var failure := ""
var waiting_id := -1
var next_id := 0
var request_started := 0
var closing := false
var connected := false
var host

static func default_python() -> String:
	return ""

func start(_python: String, _state_path: String, _save_path: String, _log_path: String,
		backend: String = "trace", _frame_audit := false) -> bool:
	if backend != "trace":
		failure = "Browser Play requires the original source-attributed trace."
		return false
	host = JavaScriptBridge.get_interface("AbramsWebHost")
	if host == null or not bool(host.attach()):
		failure = "The verified original PC game is not ready in this browser."
		return false
	connected = true
	request_started = Time.get_ticks_msec()
	return true

func step(frames: int, keys: Array) -> bool:
	if pending or closing or not failure.is_empty() or not connected or frames < 1 or frames > 600:
		return false
	waiting_id = next_id
	next_id += 1
	if not bool(host.send(JSON.stringify({"op":"step", "id":waiting_id,
			"frames":frames, "keys":keys.slice(0, Keyboard.MAX_KEYS)}))):
		failure = "Original PC browser step could not be sent."
		return false
	pending = true
	request_started = Time.get_ticks_msec()
	return true

func state_command(operation: String, slot: int) -> bool:
	if pending or closing or not failure.is_empty() or not connected: return false
	if operation not in ["save_state", "load_state"] or slot < 0 or slot > 5 or (operation == "save_state" and slot == 0): return false
	waiting_id = next_id
	next_id += 1
	if not bool(host.send(JSON.stringify({"op":operation, "id":waiting_id, "slot":slot}))):
		failure = "Original PC browser state command could not be sent."
		return false
	pending = true
	request_started = Time.get_ticks_msec()
	return true

func poll() -> Array[Dictionary]:
	var messages: Array[Dictionary] = []
	if not connected or closing: return messages
	for count in 4:
		var raw := str(host.take())
		if raw.is_empty(): break
		if raw.length() > 8 * 1024 * 1024:
			failure = "Oversized original PC browser response."
			break
		var value = JSON.parse_string(raw)
		if not value is Dictionary:
			failure = "Malformed original PC browser response."
			break
		if value.get("type") == "error":
			failure = str(value.get("message", "Original PC browser core error"))
			break
		if value.get("type") not in ["ready", "sample", "state_result"] or int(value.get("id", -2)) != waiting_id:
			failure = "Unexpected original PC browser response sequence."
			break
		if value.get("type") == "ready" and int(value.get("protocol", 0)) != 4:
			failure = "Unsupported original PC browser protocol."
			break
		pending = false
		messages.append(value)
	if failure.is_empty() and pending and Time.get_ticks_msec() - request_started > 30000:
		failure = "Original PC browser response timed out."
	return messages

func close() -> void:
	if closing: return
	closing = true
	if connected: host.close()

func has_exited() -> bool:
	return closing

func exit_code() -> int:
	return 0 if failure.is_empty() else 1
