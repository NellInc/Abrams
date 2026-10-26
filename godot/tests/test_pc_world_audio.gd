extends SceneTree
## Generated PCM and masks; native mode also reads the production owner target.
const Audio = preload("res://scripts/pc_audio.gd")
const World = preload("res://scripts/pc_world_audio.gd")
const Ownership = preload("res://scripts/pc_modern_ownership.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
const Draw = preload("res://scripts/pc_draw_pass.gd")
const Camera = preload("res://scripts/pc_camera.gd")
var errors: Array[String] = []
var checks: int = 0
var output: String
var native: bool = false

func _initialize() -> void: run.call_deferred()
func check(ok: bool, why: String) -> void:
	checks += 1
	if not ok: errors.append(why)

func packet(frame: int) -> Dictionary:
	return {"schema":3,"frame":frame,"epoch":1,"last_id":0,"active":true,"enabled":true,"events":[],"loops":{}}

func source(shape: int = 163) -> Dictionary:
	var camera: Dictionary = {"center":[159,61],"clip":[32,13,287,109],"near_raw":16,"focal_pixels":128,
		"matrix_q14_columns":[16384,0,0,0,16384,0,0,0,16384],"world_position_raw":[0,0,0]}
	var points: Array = []
	for p: Vector2 in [Vector2(80,35),Vector2(180,35),Vector2(180,95),Vector2(80,95)]: points.append(Geometry.unproject(p,512,camera))
	var object: Dictionary = {"shape_index":shape,"pointer":123,"root":4023,"dynamic_instance":shape==163,"static_path":shape!=163,
		"polygons":[{"primitive":4037,"fill_mode":1,"colors":[4,4],"camera_vertices":points}],"round_forms":[]}
	return {"camera":camera,"objects":[object],"unsupported":[],"world":{"dynamic":[{"pointer":123,"shape_index":shape,"speed_raw":10}]}}

func bank(directory: String, cues: Array = World.BASE_CUES, kind: String = "private visible-world beds") -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest: Dictionary = {"schema":1,"kind":kind,"cues":{}}
	for cue: String in cues:
		var stream: AudioStreamWAV = AudioStreamWAV.new()
		stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=48000
		var bytes: PackedByteArray=PackedByteArray();bytes.resize(96000);stream.data=bytes
		var path: String=directory.path_join(cue+".wav")
		check(stream.save_to_wav(path)==OK,"generated PCM writes")
		manifest.cues[cue]={"file":cue+".wav","sha256":FileAccess.get_sha256(path)}
	FileAccess.open(directory.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify(manifest))

func run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	output=ProjectSettings.globalize_path("res://").get_base_dir().path_join("artifacts/world-audio-test")
	if "--output" in args:output=args[args.find("--output")+1]
	native="--native" in args
	DirAccess.make_dir_recursive_absolute(output)
	if native and "--retained-only" in args and "--retained-field" in args:
		await retained_field_checks(args[args.find("--retained-field")+1])
		print("PC_WORLD_AUDIO: %d checks, %d errors"%[checks,errors.size()])
		for error: String in errors:printerr("FAIL: "+error)
		quit(0 if errors.is_empty() else 1)
		return
	var directory: String=output.path_join("generated-bank")
	bank(directory)
	var audio: Node=Audio.new()
	audio.recorded_effect_directory=""
	audio.world_audio.directory=directory
	audio.world_audio.environment_directory=""
	root.add_child(audio)
	check(audio.world_audio.streams.size()==2,"both bounded PCM cues admitted")
	for player: AudioStreamPlayer in audio.world_audio.players.values():
		check(player.bus==audio.presentation_bus,"new beds share existing limiter")
		check(player.stream.loop_end==48000 and not player.stream.stereo,"mono fixed loop bounds")
	check(audio.apply_audio(packet(1)),"source envelope accepted")
	var original: Dictionary=source()
	var digest: String=JSON.stringify(original)
	check(World.candidates(original).size()==1,"unique intact moving Hind source candidate")
	for bad: Dictionary in [{"speed_raw":0},{"speed_raw":NAN},{"speed_raw":"10"}]:
		var changed: Dictionary=original.duplicate(true);changed.world.dynamic[0].merge(bad,true)
		check(World.candidates(changed).is_empty(),"invalid/stationary Hind excluded")
	var duplicate: Dictionary=original.duplicate(true);duplicate.world.dynamic.append(duplicate.world.dynamic[0].duplicate())
	check(World.candidates(duplicate).is_empty(),"reused actor identity excluded")
	var wreck: Dictionary=source(164)
	check(World.candidates(wreck).is_empty(),"wreck cannot run Hind engine")
	check(World.candidates(source(40)).size()==1,"pinned water source admits")
	var water: Dictionary=source(40);water.objects[0].polygons.append(water.objects[0].polygons[0].duplicate(true));water.objects[0].polygons[1].primitive=1
	check(World.candidates(water).is_empty(),"mixed-owner water/land excluded")
	var unsupported: Dictionary=original.duplicate(true);unsupported.unsupported=[{"kind":"opaque"}]
	check(World.candidates(unsupported).is_empty(),"unsupported drawing silences")
	var ui: Image=Image.create(320,200,false,Image.FORMAT_L8);ui.fill(Color.BLACK)
	var mask: Image=Image.create(1280,485,false,Image.FORMAT_RGBA8);mask.fill(Color8(1,0,8))
	var token: Dictionary={"size":mask.get_size(),"clip":original.camera.clip,"selected":World.candidates(original),"ui":ui.get_data()}
	check(World.visible_cues(mask,token)==["hind"],"guarded Hind owner8 admits")
	mask.fill(Color8(2,0,8));mask.set_pixel(12,12,Color8(1,0,8))
	check(World.visible_cues(mask,token).is_empty(),"one isolated source-pixel witness cannot announce a hidden owner")
	for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.fill(colour);check(World.visible_cues(mask,token).is_empty(),"occluder/line/round/transparent mask cannot admit")
	mask.fill(Color8(1,0,8));ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(),"opaque original UI excludes world cue")
	ui.fill(Color.BLACK)
	token.ui=ui.get_data();token.selected=World.candidates(source(40));mask.fill(Color8(1,0,0))
	check(World.visible_cues(mask,token)==["river"],"ordinary source river owner admits")
	check(World.visible_cues(Image.create(256,97,false,Image.FORMAT_RGBA8),token).is_empty(),"stale resized target rejected")
	audio.world_audio.admitted.assign(["hind","river"]);audio.world_audio.refresh()
	check(audio.world_audio.players.hind.playing and audio.world_audio.players.river.playing,"admitted cues play once")
	var mix: Dictionary={"master":100,"effects":100,"voice":100,"motors":100,"hind":0,"river":100}
	check(audio.set_mix(mix) and not audio.world_audio.players.hind.playing and audio.world_audio.players.river.playing,"individual Hind off isolates river")
	audio.set_transport_muted(true)
	check(audio.world_audio.players.values().all(func(p):return not p.playing),"transport immediately silences all world players")
	audio.set_transport_muted(false)
	check(audio.world_audio.players.values().all(func(p):return not p.playing),"unmute cannot replay remembered world admission")
	check(JSON.stringify(original)==digest,"observation never mutates source")
	await environment_checks(directory,ui,mask)
	if native:
		await native_checks(audio,original,ui)
		if "--retained-field" in args: await retained_field_checks(args[args.find("--retained-field")+1])
	check(await audio.drain_for_shutdown(),"world playback and streams drain")
	audio.free()
	var bad: Node=Audio.new();bad.recorded_effect_directory="";bad.world_audio.directory=directory;bad.world_audio.environment_directory=""
	FileAccess.open(directory.path_join("hind.wav"),FileAccess.WRITE).store_string("corrupt")
	root.add_child(bad)
	check(bad.world_audio.streams.is_empty() and bad.world_audio.players.is_empty(),"bad final cue leaves atomic silent world bank")
	check(bad.failure.is_empty(),"optional bank cannot invalidate source audio")
	await bad.drain_for_shutdown();bad.free()
	print("PC_WORLD_AUDIO: %d checks, %d errors"%[checks,errors.size()])
	for error: String in errors:printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)

func native_checks(audio: Node, data: Dictionary, ui: Image) -> void:
	var target: SubViewport=Ownership.new();root.add_child(target)
	check(target.prepare(data,Vector2i(1280,485)),"production owner mesh prepares")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"hind":100,"river":100})
	var samples: Array=[]
	for index: int in 8:
		audio.apply_audio(packet(index+2))
		audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
		await RenderingServer.frame_post_draw
		check(audio.world_audio.players.hind.playing,"postdraw production owner admits Hind")
		samples.append(audio.world_audio.last_read_usec)
	check(audio.world_audio.reads==1 and audio.world_audio.cache_hits==7,"eight unchanged source packets need only one GPU read")
	var stable_reads: int=audio.world_audio.reads
	var stable_hits: int=audio.world_audio.cache_hits
	var reads: int=audio.world_audio.reads
	ui.fill(Color.WHITE)
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	check(audio.world_audio.reads==reads and not audio.world_audio.players.hind.playing,"new UI mask reclassifies cached ownership without leaking a hidden cue")
	ui.fill(Color.BLACK)
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	check(audio.world_audio.players.hind.playing and audio.world_audio.reads==reads,"valid cached proof can resume a still visible bed")
	var hidden: Dictionary=data.duplicate(true)
	var blocker: Dictionary=hidden.objects[0].duplicate(true)
	blocker.shape_index=0;blocker.dynamic_instance=false;blocker.pointer=456
	hidden.objects.append(blocker)
	check(target.prepare(hidden,Vector2i(1280,485)),"new occluding ownership mesh prepares")
	audio.world_audio.observe(hidden,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	check(audio.world_audio.reads==reads+1 and not audio.world_audio.players.hind.playing,"new occluder invalidates cached mask and silences Hind")
	target.prepare(data,Vector2i(1280,485))
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	check(audio.world_audio.pending.has("reuse_mask"),"cached proof remains queued until postdraw")
	audio.set_transport_muted(true)
	await RenderingServer.frame_post_draw
	check(not audio.world_audio.players.hind.playing and audio.world_audio._proof_mask==null,"mute cancels queued cached proof and clears its mask")
	audio.set_transport_muted(false)
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	audio.reset_timeline()
	await RenderingServer.frame_post_draw
	check(not audio.world_audio.players.hind.playing and audio.world_audio._proof_mask==null,"restore/reset cancels queued cached proof")
	audio.apply_audio(packet(20))
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	# A newer packet without a world observation must cancel queued admission.
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch);audio.apply_audio(packet(30))
	await RenderingServer.frame_post_draw
	check(not audio.world_audio.players.hind.playing,"invalid newer presentation silences old/queued world")
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch);audio.set_transport_muted(true)
	await RenderingServer.frame_post_draw
	check(not audio.world_audio.players.hind.playing,"mute between queue and draw cannot restart")
	audio.set_transport_muted(false)
	audio.world_audio.observe(data,target,ui,audio.last_frame,audio.epoch);target.size=Vector2i(640,242)
	await RenderingServer.frame_post_draw
	check(not audio.world_audio.players.hind.playing,"resize between queue and draw cannot restart")
	target.size=Vector2i(1280,485)
	audio.apply_audio(packet(40));audio.apply_audio(packet(20))
	audio.world_audio.observe(data,target,ui,20,1)
	await RenderingServer.frame_post_draw
	check(not audio.world_audio.players.hind.playing and audio.world_audio.pending.is_empty(),"old source packet cannot borrow current audio identity")
	var visibility: Dictionary={"shown":true}
	audio.world_audio.observe(data,target,ui,40,1,func():return visibility.shown)
	visibility.shown=false;audio.world_audio.maintain()
	check(not audio.world_audio.players.hind.playing and audio.world_audio.pending.is_empty(),"hidden view clears pending admission")
	FileAccess.open(output.path_join("native-readback.json"),FileAccess.WRITE).store_string(JSON.stringify({"readback_and_probe_usec":samples,
		"unchanged_packet_gpu_reads":stable_reads,"unchanged_packet_cache_hits":stable_hits,
		"source":"generated visibility fixture, not live guest or original raster parity; cached zero entries mean no GPU read, not zero CPU work"},"  "))
	target.queue_free();await process_frame

func environment_checks(base_directory: String, ui: Image, mask: Image) -> void:
	var field: Dictionary = source(48)
	field.objects[0].root = 5109
	field.objects[0].polygons[0].merge({"primitive":5123,"fill_mode":1,"colors":[8,8]},true)
	check(World.candidates(field).get(1,{}).get("cue") == "field", "exact original static green field admits candidate")
	json_field_checks(field)
	for mutation: Dictionary in [{"root":5110},{"dynamic_instance":true},{"sprite":{}},{"draw_order":[]}]:
		var changed: Dictionary = field.duplicate(true); changed.objects[0].merge(mutation,true)
		check(World.candidates(changed).is_empty(), "inexact/sprite/dynamic field cannot gain ambience")
	var changed: Dictionary = field.duplicate(true); changed.objects[0].polygons[0].colors = [9,9]
	check(World.candidates(changed).is_empty(), "unverified field palette cannot imply weather")
	var farm: Dictionary = source(157)
	farm.objects[0].root = 28643; farm.objects[0].dynamic_instance = true
	check(World.candidates(farm).get(1,{}).get("cue") == "cow", "observed dualflag farm is only a component-proof candidate")
	mask.fill(Color8(1,0,8))
	var token: Dictionary = {"size":mask.get_size(),"clip":farm.camera.clip,"selected":World.candidates(farm),"ui":ui.get_data()}
	check(World.visible_cues(mask,token).is_empty(), "whole farm ownership never authorizes a moo")
	token.selected = World.candidates(field); mask.fill(Color8(1,0,0))
	check(World.visible_cues(mask,token) == ["field"], "ordinary whole field owner admits air")
	mask.fill(Color8(1,0,8))
	check(World.visible_cues(mask,token).is_empty(), "vehicle coverage cannot borrow field authority")
	mask.fill(Color.TRANSPARENT)
	for x: int in range(200,800): mask.set_pixel(x,247,Color8(1,0,0))
	check(World.visible_cues(mask,token)==["field"], "narrow original field between sparse rows admits through exact owner scan")
	ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(), "exact narrow-field witnesses still obey opaque source UI")
	ui.fill(Color.BLACK);token.ui=ui.get_data()
	var collisions: Image=Image.create(1280,485,false,Image.FORMAT_RGBA8);collisions.fill(Color8(2,1,0))
	for x: int in range(200,800):collisions.set_pixel(x,247,Color8(1,0,0))
	check(World.visible_cues(collisions,token).is_empty(), "field exact scan stops after8192 candidate-byte hits per owner")
	token.selected=World.candidates(farm)
	check(World.visible_cues(mask,token).is_empty(), "dense field scan cannot become whole-farm or cow authority")
	var directory: String = output.path_join("generated-environment-bank")
	bank(directory,World.ENVIRONMENT_CUES,"private visible-environment cues")
	var audio: Node = Audio.new(); audio.recorded_effect_directory = ""
	audio.world_audio.directory = base_directory; audio.world_audio.environment_directory = directory
	root.add_child(audio)
	check(audio.world_audio.streams.size() == 4, "independent optional environment bank adds exactly two cues")
	var world: RefCounted = audio.world_audio
	check(world.players.cow.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and world.players.field.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "cow is one call, field is a fixed loop")
	check(world.cue_gain("hind") == 0.65*0.30 and world.cue_gain("river") == 0.65*0.20, "accepted Hind/river factors remain exact")
	check(world.cue_gain("field") == 0.65*0.08, "rejected storm-like field candidate remains reduced to0.08 pending listening")
	for frame: int in [1,61,121,180]:
		audio.apply_audio(packet(frame));world.admitted.assign(["cow","field"]);world.refresh()
	check(not world.players.cow.playing and world.players.field.playing, "one call waits for continuous source exposure")
	audio.apply_audio(packet(181));world.admitted.assign(["cow","field"]);world.refresh()
	check(world.players.cow.playing and world._cow_fired == 181, "first moo begins after180 source frames, no source event injection")
	world.players.cow.stop();world.refresh()
	check(not world.players.cow.playing and world._cow_fired == 181, "held frame never repeats a consumed call")
	check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"cow":0}), "Animals off gain accepted");world.admitted.assign(["cow","field"]);world.refresh()
	check(not world.players.cow.playing and world.players.field.playing, "Animals off leaves field and incumbent players independent")
	check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"cow":100}), "Animals restored gain accepted")
	for frame: int in range(200,2700,60):
		audio.apply_audio(packet(frame));world.admitted.assign(["cow","field"]);world.refresh()
		if frame < 2581: check(world._cow_fired == 181, "no early moo during source cooldown")
	check(world._cow_fired >= 2581, "sparse call can repeat only after2400 source frames")
	var last_call: int = world._cow_fired
	world.admitted.clear();world.refresh()
	check(not world.players.cow.playing and not world.players.field.playing, "lost current visibility immediately silences both new cues")
	world.admitted.assign(["cow"]);world.refresh()
	check(not world.players.cow.playing and world._cow_fired == last_call, "visibility re-entry cannot replay same-frame moo")
	audio.apply_audio(packet(6000));world.admitted.assign(["cow"]);world.refresh()
	check(not world.players.cow.playing and world._cow_exposure == 6000, "long source gaps restart exposure without catchup")
	audio.set_transport_muted(true);audio.set_transport_muted(false);world.admitted.assign(["cow"]);world.refresh()
	check(not world.players.cow.playing, "pause/mute release cannot replay a consumed call")
	audio.reset_timeline()
	check(world._cow_fired == -1 and world._cow_exposure == -1, "checkpoint reset clears source-only scheduler")
	check(await audio.drain_for_shutdown(), "new environment players drain through existing audio shutdown")
	audio.free()
	FileAccess.open(directory.path_join("cow.wav"),FileAccess.WRITE).store_string("corrupt")
	var bad: Node = Audio.new();bad.recorded_effect_directory = ""
	bad.world_audio.directory = base_directory;bad.world_audio.environment_directory = directory
	root.add_child(bad)
	check(bad.world_audio.streams.size() == 2 and bad.world_audio.streams.has("hind") and not bad.world_audio.environment_failure.is_empty(), "invalid optional environment bank cannot disable accepted Hind/river bank")
	check(bad.failure.is_empty(), "optional environment failure cannot invalidate original source audio")
	await bad.drain_for_shutdown();bad.free()

func json_field_checks(field: Dictionary) -> void:
	var explicit: Dictionary=field.duplicate(true)
	explicit.objects[0].draw_order=[{"kind":"polygon","index":0}]
	var decoded: Dictionary=JSON.parse_string(JSON.stringify(explicit))
	check(decoded.objects[0].polygons[0].colors[0] is float and decoded.objects[0].draw_order[0].index is float, "JSON fixture actually exercises float-valued nested numeric fields")
	check(World.candidates(decoded).get(1,{}).get("cue")=="field", "JSON-roundtripped exact source field survives typed scalar identity checks")
	for mutation: Dictionary in [{"shape_index":48.5},{"shape_index":"48"},{"root":5109.5},{"static_path":"1"},{"static_path":-1},{"dynamic_instance":0.1},{"draw_order":[{"kind":"polygon","index":0.1}]},{"draw_order":[{"kind":"polygon","index":false}]},{"draw_order":[0]}]:
		var changed: Dictionary=decoded.duplicate(true);changed.objects[0].merge(mutation,true)
		check(World.candidates(changed).is_empty(), "new field classifier rejects fractional/string/invalid source flags or commands")
	for mutation: Dictionary in [{"primitive":5123.5},{"primitive":"5123"},{"fill_mode":1.5},{"colors":[8.5,8.0]},{"colors":["8",8]},{"colors":{}},{"camera_vertices":[[0,1,0],[1,1,NAN],[2,1,0]]}]:
		var changed: Dictionary=decoded.duplicate(true);changed.objects[0].polygons[0].merge(mutation,true)
		check(World.candidates(changed).is_empty(), "new field classifier rejects nonexact polygon identity or malformed numeric containers")
	var farm: Dictionary=source(157);farm.objects[0].root=28643;farm.objects[0].dynamic_instance=true
	for mutation: Dictionary in [{"shape_index":157.5},{"root":28643.5},{"static_path":"1"}]:
		var changed: Dictionary=farm.duplicate(true);changed.objects[0].merge(mutation,true)
		check(World.candidates(changed).is_empty(), "new cow candidate cannot truncate or coerce source identity")
	var root_path: String=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var path: String=root_path.path_join("artifacts/finish-abrams-20261025/campaign-source-guided-26-01/campaign-first-original-battle-26-actual.json")
	if not FileAccess.file_exists(path):
		print("PC_WORLD_AUDIO_RETAINED_JSON: NOT RUN, optional private capture absent")
		return
	var capture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	var data: Dictionary=capture.presentation.draw_pass
	var before: String=JSON.stringify(data)
	var selected: Dictionary=World.candidates(data)
	check(selected.get(1,{}).get("cue")=="field", "actual retained original JSON field owner1 qualifies before rendering")
	check(JSON.stringify(data)==before, "actual JSON candidate inspection preserves original source data")
	var owner_path: String=root_path.path_join("artifacts/environment-bindings-20261026/field-native-v2/retained-field-ownership.png")
	if not FileAccess.file_exists(owner_path): return
	var owners: Image=Image.load_from_file(owner_path)
	var ui: Image=Image.new()
	check(ui.load_png_from_buffer(Marshalls.base64_to_raw(capture.presentation.ui_overlay.mask_png))==OK, "actual retained original field UI decodes for CPU admission check")
	var token: Dictionary={"size":owners.get_size(),"clip":data.camera.clip,"selected":selected,"ui":ui.get_data()}
	check(World.visible_cues(owners,token)==["field"], "actual retained production mask admits JSON field through exact narrow-strip scan")
	ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(owners,token).is_empty(), "actual retained field mask stays silent under opaque original UI")
	print("PC_WORLD_AUDIO_RETAINED_JSON: exact original candidate and captured ownership CPU admission passed")

func retained_audio_state(audio: Node) -> Dictionary:
	var world: RefCounted=audio.world_audio
	return {"pending_keys":world.pending.keys(),"pending_selected":world.pending.get("selected",{}).duplicate(true),"pending_frame":world.pending.get("frame"),"pending_epoch":world.pending.get("epoch"),
		"armed_keys":world.armed.keys(),"reads":world.reads,"cache_hits":world.cache_hits,"admitted":world.admitted.duplicate(),"playing":world.players.field.playing,
		"muted":audio.muted,"transport_muted":audio.transport_muted,"failure":audio.failure,"world_failure":world.failure,"environment_failure":world.environment_failure,"field_gain":world.cue_gain("field")}

func retained_field_checks(path: String) -> void:
	var capture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var data: Dictionary = capture.presentation.draw_pass
	var ui: Image = Image.new()
	check(ui.load_png_from_buffer(Marshalls.base64_to_raw(capture.presentation.ui_overlay.mask_png)) == OK, "retained original field UI decodes")
	var source_bytes: String = JSON.stringify(data)
	var world: SubViewport = SubViewport.new();world.own_world_3d = true
	world.msaa_3d = Viewport.MSAA_4X;world.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(world)
	var camera: Camera3D = Camera3D.new();world.add_child(camera);camera.make_current()
	var draw: Node3D = Draw.new();camera.add_child(draw)
	draw.solid_enabled = true;draw.modern_enabled = true;draw.tactical_landscape = true
	print("FIELD_STAGE: assets_load")
	check(draw.load_modern_assets(ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()), "retained field production assets load")
	print("FIELD_STAGE: assets_ready")
	var frame: Dictionary = data.camera.duplicate(true)
	frame.matrix_q14_columns = [16384,0,0,0,16384,0,0,0,16384];frame.world_position_raw = [0,0,0]
	world.size = Camera.apply(camera,frame,Vector3.ZERO)*5;draw.apply_pass(data)
	print("FIELD_STAGE: source_ready")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	print("FIELD_STAGE: baseline_drawn")
	var before: Image = world.get_texture().get_image()
	print("FIELD_STAGE: world_readback_done ms="+str(Time.get_ticks_msec()))
	var owners: Image = draw.ownership.get_texture().get_image()
	print("FIELD_STAGE: owner_readback_done ms="+str(Time.get_ticks_msec()))
	var audio: Node = Audio.new();audio.recorded_effect_directory = ""
	# Keep unrelated145MB score prewarm out of this focused field fixture.
	audio.prefer_independent_music = false
	audio.music_bank.directory = output.path_join("absent-fixture-score")
	audio.world_audio.directory = "";audio.world_audio.environment_directory = output.path_join("retained-generated-environment-bank")
	bank(audio.world_audio.environment_directory,World.ENVIRONMENT_CUES,"private visible-environment cues")
	print("FIELD_STAGE: bank_created ms="+str(Time.get_ticks_msec()))
	root.add_child(audio);audio.apply_audio(packet(1))
	print("FIELD_STAGE: audio_ready ms="+str(Time.get_ticks_msec()))
	var selected: Dictionary=World.candidates(data)
	var direct_token: Dictionary={"size":owners.get_size(),"clip":data.camera.clip,"selected":selected,"ui":ui.get_data()}
	var direct_visible: Array[String]=World.visible_cues(owners,direct_token)
	print("FIELD_STAGE: direct_classification ms="+str(Time.get_ticks_msec()))
	var stages: Dictionary={"before_observe":retained_audio_state(audio)}
	audio.world_audio.observe(data,draw.ownership,ui,1,1)
	stages.queued=retained_audio_state(audio)
	print("FIELD_STAGE: observed ms="+str(Time.get_ticks_msec()))
	await RenderingServer.frame_post_draw
	stages.after_draw=retained_audio_state(audio)
	print("FIELD_STAGE: proof_drawn "+JSON.stringify(stages.after_draw))
	check(audio.world_audio.admitted == ["field"] and audio.world_audio.players.field.playing, "retained original field admits through full production painter target")
	check(world.get_texture().get_image().get_data() == before.get_data() and draw.ownership.get_texture().get_image().get_data() == owners.get_data() and JSON.stringify(data) == source_bytes, "field sound observation preserves production world, source and ownership bytes")
	ui.fill(Color.WHITE);audio.world_audio.observe(data,draw.ownership,ui,1,1)
	await RenderingServer.frame_post_draw
	stages.after_ui_cover=retained_audio_state(audio)
	check(not audio.world_audio.players.field.playing, "original opaque UI silences retained field without source edits")
	before.save_png(output.path_join("retained-field-world.png"));owners.save_png(output.path_join("retained-field-ownership.png"))
	FileAccess.open(output.path_join("retained-field.json"),FileAccess.WRITE).store_string(JSON.stringify({"source":path,"sha256":FileAccess.get_sha256(path),"scene":"unchanged captured source, generated silent PCM, no guest/audio timeline or device listening claim",
		"selected_candidates":selected,"direct_visible_cues_before_ui_cover":direct_visible,"stages":stages,"checks":checks,"errors":errors},"  "))
	await audio.drain_for_shutdown();audio.free();world.queue_free();await process_frame
