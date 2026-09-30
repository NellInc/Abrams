extends "res://scripts/pc_bridge_viewer.gd"
## Diagnostic only: ordinary live presentation from the shared START boundary.
## Original Return input, source frames and every displayed title pose retained.
var running := false
var ready_seen := false
var focus_since := 0
var deadline := Time.get_ticks_msec()+240000
var phase := ""
var rows: Array = []
var drawn := {}
var preview_vertices := {}
var preview_samples := 0
var report_written := false
var errors: Array[String] = []

class IntroBridge extends "res://scripts/pc_bridge.gd":
	var requests: Array = []
	func start(python: String, _state: String, saves: String, log_path: String, backend: String = "reference", audit := false) -> bool:
		var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
		return super.start(python,directory.path_join("artifacts/pc-neutral-boot-01/neutral-boot/reference.state"),saves,log_path,backend,audit)
	func step(frames: int, keys: Array) -> bool:
		var accepted := super.step(frames,keys)
		if accepted: requests.append({"frames":frames,"keys":keys.duplicate()})
		return accepted

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not ["--play","--trace","--no-audio","--output"].all(func(flag):return flag in args) or "--capture" in args:
		printerr("Intro probe requires ordinary --play --trace --no-audio --output")
		quit(2)
		return
	bridge=IntroBridge.new()
	RenderingServer.frame_post_draw.connect(_post_draw)
	super._initialize()
	# Persistent settings are read by ordinary Play; no menu setting is saved.

func _advance_live_frame() -> bool:
	return super._advance_live_frame() if running else false

func return_key(pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode=KEY_ENTER;event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _apply_sample(message: Dictionary) -> void:
	if running: return_key(int(message.sequence)<3)
	super._apply_sample(message)
	ready_seen=true
	phase=str(tandem_frame.frontend_art.intro_art.active.get("name",""))
	rows.append({"sequence":int(message.sequence),"phase":phase,"time_usec":Time.get_ticks_usec(),"focused":root.has_focus(),"program":previous_program.get("name","")})
	var drawing=previous_presentation.get("draw_pass")
	if drawing is Dictionary and drawing.get("frontend_scene")=="START/ANIM":
		var polygons: Array = []
		for object: Dictionary in drawing.objects:
			for polygon: Dictionary in object.get("polygons",[]):polygons.append(polygon.camera_vertices)
		preview_vertices[JSON.stringify(polygons).sha256_text()]=true
		preview_samples+=1
		if preview_samples>=120: _close()

func _post_draw() -> void:
	if not ready_seen or closing: return
	var label:=phase
	if label.is_empty() and preview_samples>0: label="main-menu"
	if label.is_empty() or drawn.has(label): return
	var image:=root.get_texture().get_image()
	if image.save_png(output.path_join(label+".png"))!=OK:errors.append("Failed screenshot: "+label)
	var hash:=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256);hash.update(image.get_data())
	drawn[label]={"sequence":rows[-1].sequence,"time_usec":Time.get_ticks_usec(),"rgba_sha256":hash.finish().hex_encode()}

func write_report() -> void:
	if report_written: return
	report_written=true
	for name in ["title","flash-1","flash-2","flash-3","flash-4","credit-8","main-menu"]:
		if not drawn.has(name):errors.append("Not displayed: "+name)
	var hashes := {}
	for name in ["flash-1","flash-2","flash-3","flash-4"]:
		if drawn.has(name):hashes[drawn[name].rgba_sha256]=true
	if hashes.size()!=4:errors.append("Four title flash images must differ")
	if preview_vertices.size()<2:errors.append("3D menu camera vertices never changed")
	var mismatches: Array = []
	for i in bridge.requests.size():
		if bridge.requests[i].frames!=1 or bridge.requests[i].keys!=(["return"] if i<3 else []):mismatches.append(i)
	if not mismatches.is_empty():errors.append("Original input route differs")
	FileAccess.open(output.path_join("intro-play.json"),FileAccess.WRITE).store_string(JSON.stringify({"errors":errors,"displayed":drawn,"rows":rows,"requests":bridge.requests,"input_mismatches":mismatches,"preview_samples":preview_samples,"distinct_preview_vertices":preview_vertices.size(),"bridge_failure":bridge.failure,"child_exited":bridge.has_exited(),"scope":"Ordinary production presentation and one-frame source requests. Neutral START checkpoint and Return-only diagnostic input; no authored animation clock."},"  "))
	print("PC_INTRO_PLAY: %d displayed poses/cards, %d preview transforms, %d errors"%[drawn.size(),preview_vertices.size(),errors.size()])
	for error in errors:printerr("FAIL: "+error)

func _process(delta: float) -> bool:
	if closing and bridge.has_exited():
		write_report()
		if not errors.is_empty():quit(3);return false
	if Time.get_ticks_msec()>deadline and not closing:
		errors.append("Intro probe deadline")
		_close()
	if ready_seen and not running and not closing:
		if not root.has_focus():focus_since=0
		elif focus_since==0:focus_since=Time.get_ticks_msec()
		elif Time.get_ticks_msec()-focus_since>=250:
			# Play quarantines keys across a native focus boundary. Release that
			# quarantine with an empty physical set before the first test press,
			# exactly as the interactive profiler does.
			return_key(false)
			if audio_menu:audio_menu.game_keys([])
			running=true;elapsed=0.0;return_key(true)
	return super._process(delta)
