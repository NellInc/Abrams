extends SceneTree
## Generated PCM and masks; native mode also reads the production owner target.
const Audio = preload("res://scripts/pc_audio.gd")
const World = preload("res://scripts/pc_world_audio.gd")
const Ownership = preload("res://scripts/pc_modern_ownership.gd")
const Geometry = preload("res://scripts/pc_surface_geometry.gd")
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

func bank(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var manifest: Dictionary = {"schema":1,"kind":"private visible-world beds","cues":{}}
	for cue: String in World.CUES:
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
	var directory: String=output.path_join("generated-bank")
	bank(directory)
	var audio: Node=Audio.new()
	audio.recorded_effect_directory=""
	audio.world_audio.directory=directory
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
	if native: await native_checks(audio,original,ui)
	check(await audio.drain_for_shutdown(),"world playback and streams drain")
	audio.free()
	var bad: Node=Audio.new();bad.recorded_effect_directory="";bad.world_audio.directory=directory
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
