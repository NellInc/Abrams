extends "res://scripts/pc_bridge_viewer.gd"
## Actual production viewer/host replay from neutral START, with a fresh disk.
## Original battle, loss and END own every outcome; this test only sends keys.
var fixture: Dictionary
var boundary_samples: Dictionary = {}
var source_records: Dictionary = {}
var original_frame_zero := 0
var errors: Array[String] = []
var checks := 0
var boundaries := 0
var native_rows: Array = []
var damage_seen := false
var boot_boundary := ""
var photographing := false

class NeutralBootBridge extends "res://scripts/pc_bridge.gd":
	var neutral_state: String
	func start(python, _state, saves, log_path, backend="reference", _audit=false) -> bool:
		return super.start(python,neutral_state,saves,log_path,backend,true)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not ["--fixture","--output","--capture","--boot","--play"].all(func(flag):return flag in args):
		printerr("Combat outcome needs --fixture REPORT --output NEW --capture --boot --play")
		quit(2)
		return
	var path := args[args.find("--fixture")+1]
	var target := args[args.find("--output")+1]
	if DirAccess.dir_exists_absolute(target):
		printerr("Combat outcome needs a fresh output directory")
		quit(2)
		return
	fixture=JSON.parse_string(FileAccess.get_file_as_string(path))
	if fixture.get("mode")!="trace" or not fixture.has("damage_exit_frames") or fixture.damage_exit_frames.is_empty() or not fixture.checks.values().all(func(v):return v==true):
		printerr("Combat outcome needs a passing source-comparison fixture")
		quit(2)
		return
	var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	boot_boundary=directory.path_join("artifacts/pc-neutral-boot-01/neutral-boot/reference.state")
	if FileAccess.get_sha256(boot_boundary)!=fixture.boot_state_sha256:
		printerr("Combat outcome neutral START differs from fixture")
		quit(2)
		return
	original_frame_zero=int(fixture.samples[0].frame)
	for sample in fixture.samples: boundary_samples[int(sample.frame)]=sample
	for record in fixture.records: source_records[int(record.frame)]=record
	bridge=NeutralBootBridge.new()
	bridge.neutral_state=boot_boundary
	super._initialize()
	auto_steps=[]
	# The host's ready packet already corresponds to fixture's first ready step.
	for sample in fixture.samples.slice(1):auto_steps.append([int(sample.frames),sample.keys])
	auto_steps=capture_chunks(auto_steps)

func _capture_deadline_msec() -> int: return 360000

func _process(delta: float) -> bool:
	# Leave any next host packet queued while Godot completes this scene update.
	# No extra PC frames or keys are requested for a photograph.
	if photographing: return false
	return super._process(delta)

func photograph(label: String) -> void:
	await process_frame
	RenderingServer.force_draw(false)
	RenderingServer.force_sync()
	var rendered := root.get_texture().get_image()
	check(rendered.save_png(output.path_join(label+".png"))==OK,"native photograph saved: "+label)
	if label=="combat-debrief":
		# Summary background and border have no replacement artwork. Outside
		# verified text their exact original colours must survive the redraw.
		var original := picture.texture.get_image()
		for p in [Vector2(10,80),Vector2(310,180),Vector2(180,90)]:
			var at := Vector2i((p+Vector2(0.5,0.5))*Vector2(rendered.get_size())/Vector2(320,200))
			check(rendered.get_pixelv(at).to_rgba32()==original.get_pixelv(Vector2i(p)).to_rgba32(),"original debrief background retained")
	photographing=false
	if not errors.is_empty(): bridge.failure=errors[0]

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20:errors.append(reason)

func _apply_sample(message: Dictionary) -> void:
	super._apply_sample(message)
	var frame := original_frame_zero+int(message.sequence)
	var record: Dictionary=source_records.get(frame,{})
	var audit: Dictionary=message.get("frame_audit",{})
	check(not record.is_empty(),"source frame recorded: %d"%frame)
	check(audit.get("ram_sha256")==record.get("ram_sha256") and audit.get("ram_bytes")==655360,"full paired RAM: %d"%frame)
	check(audit.get("video_sha256")==record.get("video_sha256") and audit.get("video_bytes")==256000,"full paired video: %d"%frame)
	check(bridge.failure.is_empty(),"production presentation accepted: %d"%frame)
	check(draw_view.vehicle_art==null,"flat vehicles retained")
	if previous_program.get("name")!="SIM":
		check(previous.is_empty() and not tandem_frame.world_enabled,"no stale world/state outside SIM")
	var sample: Dictionary=boundary_samples.get(frame,{})
	if sample.is_empty():return
	boundaries+=1
	check(message.get("state")==sample.state,"original stage state: "+sample.label)
	check(message.get("program")==sample.program,"original program: "+sample.label)
	var photograph: bool=sample.label in ["combat-debrief","combat-main-menu","second-mission"] or (sample.label.begins_with("combat-review-") and not sample.label.ends_with("-press"))
	if not damage_seen and frame>=int(fixture.damage_exit_frames[0]):
		damage_seen=true
		photograph=true
	native_rows.append({"label":sample.label,"frame":frame,"program":message.program,
		"world_enabled":tandem_frame.world_enabled,"frontend":tandem_frame.frontend_art.active,
		"text":tandem_frame.frontend_art.typography.runs.map(func(r):return r.text),
		"menu_text":tandem_frame.frontend_art.flow_typography.runs.map(func(r):return r.text)})
	if photograph:
		photographing=true
		self.photograph.call_deferred(sample.label)
	if not errors.is_empty():bridge.failure=errors[0]

func _capture() -> void:
	while photographing: await process_frame
	check(boundaries==fixture.samples.size(),"every source stage delivered")
	check(previous_program.get("name")=="SIM" and tandem_frame.world_enabled,"new paired mission after original loss")
	check(pc_audio!=null and pc_audio.failure.is_empty(),"default audio survives combat/end/reentry")
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"errors":errors,"boundaries":boundaries,"packets":samples,"rows":native_rows,
		"neutral_state":boot_boundary,"neutral_sha256":fixture.boot_state_sha256,
		"scope":"Real original executable and fresh disk overlay from shared neutral START. Every received frame matches complete baseline-paired RAM/video. Production viewer, art, text and default audio exercised; batched diagnostic steps suppress stale barks."},"  "))
	for error in errors:printerr("FAIL: "+error)
	print("PC_COMBAT_OUTCOME: %d checks, %d boundaries, %d errors"%[checks,boundaries,errors.size()])
	if not errors.is_empty():bridge.failure=errors[0]
	await super._capture()
