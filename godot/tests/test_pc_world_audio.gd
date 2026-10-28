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

func isolated_audio() -> Node:
	var audio: Node = Audio.new()
	audio.world_audio.t72_directory = ""
	audio.world_audio.tank_directory = ""
	audio.world_audio.allied_directory = ""
	audio.world_audio.detail_directory = ""
	audio.supplemental.directory = ""
	return audio

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
		var frames: int=World.ALLIED_FRAME_COUNTS[cue] if cue in World.ALLIED_CUES else World.T80_FRAME_COUNT if cue=="t80" else World.T72_FRAME_COUNT if cue=="t72" else World.TANK_FRAME_COUNT if cue=="tank" else 48000
		var bytes: PackedByteArray=PackedByteArray();bytes.resize(frames*2);stream.data=bytes
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
	var audio: Node=isolated_audio()
	audio.recorded_effect_directory=""
	audio.world_audio.directory=directory
	audio.world_audio.environment_directory=""
	audio.world_audio.soviet_directory=""
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
	await soviet_checks(directory,ui,mask)
	await tank_checks(directory,ui,mask)
	await t72_checks(directory,ui,mask)
	await allied_checks(directory,ui,mask)
	await detail_checks(directory,ui,mask)
	if native:
		await native_checks(audio,original,ui)
		if "--retained-field" in args: await retained_field_checks(args[args.find("--retained-field")+1])
	check(await audio.drain_for_shutdown(),"world playback and streams drain")
	audio.free()
	var bad: Node=isolated_audio();bad.recorded_effect_directory="";bad.world_audio.directory=directory;bad.world_audio.environment_directory=""
	bad.world_audio.soviet_directory=""
	FileAccess.open(directory.path_join("hind.wav"),FileAccess.WRITE).store_string("corrupt")
	root.add_child(bad)
	check(bad.world_audio.streams.is_empty() and bad.world_audio.players.is_empty(),"bad final cue leaves atomic silent world bank")
	check(bad.failure.is_empty(),"optional bank cannot invalidate source audio")
	await bad.drain_for_shutdown();bad.free()
	print("PC_WORLD_AUDIO: %d checks, %d errors"%[checks,errors.size()])
	for error: String in errors:printerr("FAIL: "+error)
	quit(0 if errors.is_empty() else 1)

func detail_checks(base_directory: String, ui: Image, mask: Image) -> void:
	var tree: Dictionary = source(103)
	tree.objects[0].root = 10523
	tree.objects[0].polygons[0].primitive = 10549
	tree.objects[0].polygons[0].camera_vertices.resize(3)
	var original: String = JSON.stringify(tree)
	check(World.candidates(tree).get(1, {}).get("cue") == "woodland", "exact original tree qualifies scene-owned woodland")
	for bad: Variant in [103.5, "103", 104]:
		var changed: Dictionary = tree.duplicate(true); changed.objects[0].shape_index = bad
		check(World.candidates(changed).is_empty(), "tree aliases cannot acquire woodland")
	for bad: Variant in [10523.5, 5109, "10523"]:
		var changed: Dictionary = tree.duplicate(true); changed.objects[0].root = bad
		check(World.candidates(changed).is_empty(), "exact tree source root required")
	var changed: Dictionary = tree.duplicate(true); changed.objects[0].polygons[0].primitive = 10549.5
	check(World.candidates(changed).is_empty(), "fractional tree primitive excluded")
	changed = tree.duplicate(true); changed.objects[0].polygons[0].camera_vertices[0][0] = NAN
	check(World.candidates(changed).is_empty(), "non-finite tree geometry excluded")
	ui.fill(Color.BLACK);mask.fill(Color8(1,0,8))
	var token: Dictionary = {"size":mask.get_size(),"clip":tree.camera.clip,"selected":World.candidates(tree),"ui":ui.get_data()}
	check(World.visible_cues(mask,token) == ["woodland"], "actual guarded tree-owner mask admits woodland")
	for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255)]:
		mask.fill(colour);check(World.visible_cues(mask,token).is_empty(), "foreign/line/effect pixels cannot announce woodland")
	mask.fill(Color8(1,0,8));ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(), "original UI silences tree")
	var truck: Dictionary = tank_source(159)
	check(World.candidates(truck).get(1,{}).get("cue") == "truck", "exact original moving Truck class admitted")
	for speed: Variant in [0, NAN, 1.5, "18"]:
		changed=truck.duplicate(true);changed.world.dynamic[0].speed_raw=speed
		check(World.candidates(changed).is_empty(), "stationary or invalid truck motion stays silent")
	check(World.candidates(tank_source(160)).is_empty(), "truck wreck cannot run engine")
	var directory: String = base_directory + "-detail"
	bank(directory,World.DETAIL_CUES,"private visible-world detail")
	var audio: Node = isolated_audio();audio.recorded_effect_directory=""
	audio.world_audio.directory=base_directory;audio.world_audio.environment_directory="";audio.world_audio.soviet_directory=""
	audio.world_audio.detail_directory=directory
	root.add_child(audio);audio.apply_audio(packet(1))
	check(audio.world_audio.detail_failure.is_empty() and audio.world_audio.players.has_all(World.DETAIL_CUES), "optional detail bank loads atomically")
	for cue: String in World.DETAIL_CUES: check(audio.world_audio.players[cue].bus == audio.presentation_bus, "detail shares incumbent limiter: " + cue)
	audio.world_audio.admitted.assign(["woodland","truck"]);audio.world_audio.refresh()
	check(audio.world_audio.players.woodland.playing and audio.world_audio.players.truck.playing and not audio.world_audio.players.tracks.playing, "tree/truck cannot manufacture track rolling")
	audio.world_audio.admitted.assign(["m113"]);audio.world_audio.refresh()
	check(audio.world_audio.players.tracks.playing, "already-visible source-moving tracked owner starts quiet texture")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"m113":0})
	check(not audio.world_audio.players.tracks.playing, "class Off immediately silences its track texture before next packet")
	audio.world_audio.admitted.clear();audio.world_audio.refresh()
	check(not audio.world_audio.players.tracks.playing, "hidden owners leave no track tail")
	check(JSON.stringify(tree)==original, "supplemental observation preserves original tree geometry")
	check(await audio.drain_for_shutdown(), "details drain through existing lifecycle")
	audio.free();ui.fill(Color.BLACK)

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

func tank_source(shape: int) -> Dictionary:
	var data: Dictionary = source(shape)
	data.objects[0].dynamic_instance = true
	data.objects[0].static_path = false
	return data

func tank_checks(base_directory: String, ui: Image, mask: Image) -> void:
	var data: Dictionary = tank_source(115)
	var unchanged: String = JSON.stringify(data)
	for shape: int in World.TANK_SHAPES:
		var moving: Dictionary = tank_source(shape)
		check(World.candidates(moving,false).get(1,{}).get("cue")=="tank", "intact tank uses generic when dedicated bank is absent: "+str(shape))
		check(World.candidates(moving,true).get(1,{}).get("cue")==("t80" if shape==121 else "tank"), "dedicated T80 takes precedence only for exact model121")
		for speed: int in [-32768,-1,1,32767]:
			moving.world.dynamic[0].speed_raw = speed
			check(World.candidates(moving,false).get(1,{}).get("cue")=="tank", "generic accepts the same finite signed16 forward/reverse movement")
	for shape: int in [116,118,120,122,123,124,125,126,128,129,131,133,135,137,139,141,143,159,163]:
		check(not World.candidates(tank_source(shape),false).values().any(func(item):return item.cue=="tank"), "wrecks/Abrams/unverified/IFV/other identities cannot borrow generic tank recording: "+str(shape))
	for speed: Variant in [0,-32769,32768,0.5,NAN,INF,"10",true]:
		var changed: Dictionary = data.duplicate(true); changed.world.dynamic[0].speed_raw=speed
		check(World.candidates(changed,false).is_empty(), "stationary or invalid source speed cannot start generic loop")
	for mutation: Dictionary in [{"shape_index":115.5},{"shape_index":"115"},{"pointer":123.5},{"pointer":"123"},{"dynamic_instance":false}]:
		var changed: Dictionary=data.duplicate(true);changed.objects[0].merge(mutation,true)
		check(World.candidates(changed,false).is_empty(), "generic drawn identity is exact, never truncated or coerced")
	for mutation: Dictionary in [{"shape_index":115.5},{"pointer":123.5},{"pointer":"123"},{"shape_index":117},{"pointer":124}]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].merge(mutation,true)
		check(World.candidates(changed,false).is_empty(), "generic actor pointer/model must exactly match drawn owner")
	var duplicate: Dictionary=data.duplicate(true);duplicate.world.dynamic.append(duplicate.world.dynamic[0].duplicate())
	check(World.candidates(duplicate,false).is_empty(), "reused pointer/model cannot qualify generic movement")
	var missing: Dictionary=data.duplicate(true);missing.world.dynamic=[]
	check(World.candidates(missing,false).is_empty(), "generic never invents missing source movement")
	ui.fill(Color.BLACK)
	var token: Dictionary={"size":mask.get_size(),"clip":data.camera.clip,"selected":World.candidates(data,false),"ui":ui.get_data()}
	for flag: int in [0,8]:
		mask.fill(Color8(1,0,flag));check(World.visible_cues(mask,token)==["tank"], "generic inherits actual ordinary/guarded T80 ownership rules")
	for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.fill(colour);check(World.visible_cues(mask,token).is_empty(), "generic excludes occluders, lines, round forms and alpha")
	mask.fill(Color8(2,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(820,231,Color8(1,0,8))
	check(World.visible_cues(mask,token)==["tank"], "thin generic silhouette uses identical separated same-owner narrow witnesses")
	ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(), "original opaque UI silences generic exact scan")
	ui.fill(Color.BLACK);token.ui=ui.get_data()
	mask.set_pixel(820,231,Color8(2,0,8))
	check(World.visible_cues(mask,token).is_empty(), "generic cannot combine two separate tiny owners")
	for colour: Color in [Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.set_pixel(820,231,colour)
		check(World.visible_cues(mask,token).is_empty(), "generic narrow scan retains exact line/round/alpha exclusions")
	var directory: String=output.path_join("generated-tank-bank")
	bank(directory,World.TANK_CUES,"private visible-tank fallback")
	for dedicated_state: String in ["absent","valid","invalid"]:
		var dedicated: bool = dedicated_state == "valid"
		var audio: Node=isolated_audio();audio.recorded_effect_directory=""
		audio.world_audio.directory=base_directory;audio.world_audio.environment_directory=""
		audio.world_audio.soviet_directory=output.path_join("generated-soviet-bank") if dedicated_state != "absent" else ""
		audio.world_audio.tank_directory=directory
		# The earlier Soviet rejection fixture deliberately corrupts its bank.
		if dedicated_state != "absent":
			bank(audio.world_audio.soviet_directory,World.SOVIET_CUES,"private visible-soviet cues")
			if dedicated_state == "invalid": FileAccess.open(audio.world_audio.soviet_directory.path_join("t80.wav"),FileAccess.WRITE).store_string("corrupt")
		root.add_child(audio);audio.apply_audio(packet(1))
		var world: RefCounted=audio.world_audio
		var player: AudioStreamPlayer=world.players.tank
		check((not world.soviet_failure.is_empty()) == (dedicated_state == "invalid"), "dedicated failure is isolated from optional fallback")
		check(world.tank_failure.is_empty() and player.bus==audio.presentation_bus and player.stream.loop_end==World.TANK_FRAME_COUNT, "optional generic bank loads exact24s through incumbent limiter")
		check(world.cue_gain("tank")==0.65*0.30 and world.cue_gain("hind")==0.65*0.30 and world.cue_gain("river")==0.65*0.20, "generic matches accepted tank nominal level without changing incumbent factors")
		check(World.candidates(tank_source(121),world.streams.has("t80")).get(1,{}).get("cue")==("t80" if dedicated else "tank"), "validated stream availability chooses dedicated versus generic")
		world.admitted.assign(["tank","hind"]);world.refresh()
		check(player.playing and player.pitch_scale==1.0 and world.players.size()==(4 if dedicated else 3), "only one fixed-pitch centred generic player, independent of actor count")
		var clock: Array=[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)]
		check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"tank":40}) and is_equal_approx(db_to_linear(player.volume_db),0.65*0.30*0.40), "independent fallback gain applies without source pitch/RPM changes")
		if dedicated:
			world.admitted.append("t80");world.refresh()
			check(player.playing and world.players.t80.playing and is_equal_approx(db_to_linear(world.players.t80.volume_db),0.65*0.30), "different visible tank classes coexist without ducking accepted dedicated gain")
			world.admitted.erase("tank");audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"t80":0})
			check(not player.playing and not world.players.t80.playing and World.candidates(tank_source(121),world.streams.has("t80")).get(1,{}).get("cue")=="t80", "dedicated Off never substitutes generic for the same T80")
			world.admitted.append("tank");world.refresh()
			check(player.playing and not world.players.t80.playing, "separate generic owner is independent of dedicated T80 Off")
		audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"tank":0})
		check(not player.playing and world.players.hind.playing, "generic Off leaves accepted Hind playing")
		world.admitted.erase("tank");audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"tank":100})
		check(not player.playing, "generic unmute cannot invent remembered visibility")
		world.admitted.append("tank");world.refresh();audio.set_transport_muted(true)
		check(not player.playing and world.admitted.is_empty() and world.pending.is_empty(), "pause/focus/transport gate clears generic and queued ownership")
		audio.set_transport_muted(false);world.refresh();check(not player.playing,"transport recovery cannot replay generic admission")
		check(clock==[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)], "generic controls never advance original clocks/events/motors")
		world.admitted.append("tank");world.refresh()
		var disabled: Dictionary=packet(2);disabled.active=false
		check(audio.apply_audio(disabled) and not player.playing, "original inactive/pause envelope silences fallback")
		world.refresh();check(not player.playing,"retained owner proof cannot reopen inactive original source")
		check(await audio.drain_for_shutdown(),"generic uses existing clean audio shutdown");audio.free()
	var reader: RefCounted=World.new()
	var path: String=directory.path_join("tank.wav")
	var good: PackedByteArray=FileAccess.get_file_as_bytes(path)
	FileAccess.open(path,FileAccess.WRITE).store_string("corrupt")
	check(reader._read_bank(directory,"private visible-tank fallback",World.TANK_CUES).has("error"), "changed generic PCM rejected by manifest SHA")
	var isolated: Node=isolated_audio();isolated.recorded_effect_directory="";isolated.world_audio.directory=base_directory;isolated.world_audio.environment_directory="";isolated.world_audio.soviet_directory="";isolated.world_audio.tank_directory=directory
	root.add_child(isolated)
	check(not isolated.world_audio.tank_failure.is_empty() and isolated.failure.is_empty() and isolated.world_audio.streams.size()==2, "corrupt optional generic bank cannot disable accepted original or world audio")
	await isolated.drain_for_shutdown();isolated.free()
	FileAccess.open(path,FileAccess.WRITE).store_buffer(good)
	var manifest_path: String=directory.path_join("manifest.json")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var short: AudioStreamWAV=AudioStreamWAV.new();short.format=AudioStreamWAV.FORMAT_16_BITS;short.mix_rate=48000
	var short_pcm: PackedByteArray=PackedByteArray();short_pcm.resize(96000);short.data=short_pcm
	check(short.save_to_wav(path)==OK,"wrong-duration generic fixture writes")
	manifest.cues.tank.sha256=FileAccess.get_sha256(path);FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(reader._read_bank(directory,"private visible-tank fallback",World.TANK_CUES).get("error")=="invalid tank fallback frame count","matching file/manifest SHA cannot admit wrong loop duration")
	check(JSON.stringify(data)==unchanged,"fallback never mutates original drawing/actor state")

func t72_checks(base_directory: String, ui: Image, mask: Image) -> void:
	var data: Dictionary=tank_source(119)
	var original: String=JSON.stringify(data)
	check(World.T72_CUES==["t72"] and World.T72_FRAME_COUNT==627720, "T72 bank has exactly one verified-length cue")
	check(World.candidates(data).get(1,{}).get("cue")=="tank" and World.candidates(data,false).get(1,{}).get("cue")=="tank", "legacy one/two-argument classification keeps T72 generic")
	check(World.candidates(JSON.parse_string(original),true,true).get(1,{}).get("cue")=="t72", "exact JSON moving model119 gets available dedicated T72")
	for shape: int in World.TANK_SHAPES:
		check(World.candidates(tank_source(shape),true,true).get(1,{}).get("cue")==("t72" if shape==119 else "t80" if shape==121 else "tank"), "dedicated T72 changes only intact119: "+str(shape))
		check(World.candidates(tank_source(shape),false,true).get(1,{}).get("cue")==("t72" if shape==119 else "tank"), "T72 availability does not change T80 fallback: "+str(shape))
	for shape: int in [120,122,123,129,131,159,163]:
		check(World.candidates(tank_source(shape),true,true)==World.candidates(tank_source(shape),true), "wreck and other class classifications unchanged: "+str(shape))
	for speed: int in [-32768,-1,1,32767]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].speed_raw=speed
		check(World.candidates(changed,true,true).get(1,{}).get("cue")=="t72", "T72 accepts exact signed16 forward/reverse movement")
	for speed: Variant in [0,-32769,32768,0.5,NAN,INF,"10",true]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].speed_raw=speed
		check(World.candidates(changed,true,true).is_empty(), "stopped or malformed T72 motion stays silent")
	for mutation: Dictionary in [{"shape_index":119.5},{"shape_index":"119"},{"pointer":123.5},{"pointer":"123"},{"pointer":-1},{"pointer":65536},{"dynamic_instance":false}]:
		var changed: Dictionary=data.duplicate(true);changed.objects[0].merge(mutation,true)
		check(World.candidates(changed,true,true).is_empty(), "T72 drawn identity cannot be coerced or made static")
	for mutation: Dictionary in [{"shape_index":119.5},{"shape_index":120},{"pointer":124},{"pointer":123.5},{"pointer":"123"}]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].merge(mutation,true)
		check(World.candidates(changed,true,true).is_empty(), "T72 actor must exactly join drawn pointer/model")
	var duplicate: Dictionary=data.duplicate(true);duplicate.world.dynamic.append(duplicate.world.dynamic[0].duplicate())
	check(World.candidates(duplicate,true,true).is_empty(), "duplicate T72 actor join stays silent")
	duplicate.world.dynamic=[]
	check(World.candidates(duplicate,true,true).is_empty(), "missing T72 actor cannot invent motion")
	ui.fill(Color.BLACK)
	var token: Dictionary={"size":mask.get_size(),"clip":data.camera.clip,"selected":World.candidates(data,true,true),"ui":ui.get_data()}
	for flag: int in [0,8]:
		mask.fill(Color8(1,0,flag));check(World.visible_cues(mask,token)==["t72"], "ordinary/guarded actual T72 owner admits")
	for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.fill(colour);check(World.visible_cues(mask,token).is_empty(), "foreign/line/round/alpha T72 pixels remain silent")
	mask.fill(Color8(2,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(820,231,Color8(1,0,8))
	check(World.visible_cues(mask,token)==["t72"], "narrow separated actual same-owner T72 pixels qualify")
	ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(), "original opaque UI blocks narrow T72 proof")
	ui.fill(Color.BLACK);token.ui=ui.get_data()
	for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.set_pixel(820,231,colour)
		check(World.visible_cues(mask,token).is_empty(), "narrow T72 proof excludes foreign/line/round/alpha endpoints")
	mask.fill(Color8(2,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(815,241,Color8(1,0,8))
	check(World.visible_cues(mask,token).is_empty(), "narrow T72 retains four-source-pixel minimum separation")
	token.selected[2]={"cue":"t72"};mask.fill(Color8(0,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(820,231,Color8(2,0,8))
	check(World.visible_cues(mask,token).is_empty(), "two selected T72 owners cannot pool isolated witnesses")
	var directory: String=output.path_join("generated-t72-bank")
	var fallback: String=output.path_join("t72-tank-control")
	var soviet: String=output.path_join("t72-soviet-control")
	var detail: String=output.path_join("t72-detail-control")
	bank(directory,World.T72_CUES,"private visible-t72 cue")
	bank(fallback,World.TANK_CUES,"private visible-tank fallback")
	bank(soviet,World.SOVIET_CUES,"private visible-soviet cues")
	bank(detail,World.DETAIL_CUES,"private visible-world detail")
	var path: String=directory.path_join("t72.wav")
	var good: PackedByteArray=FileAccess.get_file_as_bytes(path)
	for state: String in ["valid","absent","corrupt"]:
		if state=="corrupt": FileAccess.open(path,FileAccess.WRITE).store_string("corrupt")
		var audio: Node=isolated_audio();audio.recorded_effect_directory=""
		audio.world_audio.directory=base_directory;audio.world_audio.environment_directory="";audio.world_audio.soviet_directory=soviet
		audio.world_audio.tank_directory=fallback;audio.world_audio.detail_directory=detail;audio.world_audio.t72_directory=directory if state!="absent" else output.path_join("missing-t72-bank")
		root.add_child(audio);audio.apply_audio(packet(1))
		var world: RefCounted=audio.world_audio
		var dedicated: bool=state=="valid"
		check(world.streams.size()==(8 if dedicated else 7) and world.players.size()==world.streams.size() and audio.failure.is_empty(), "T72 availability preserves every incumbent cue atomically: "+state)
		check((not world.t72_failure.is_empty())==(state=="corrupt") and world.tank_failure.is_empty() and world.soviet_failure.is_empty(), "T72 errors are isolated and absence is optional: "+state)
		var selected: Dictionary=World.candidates(data,world.streams.has("t80"),world.streams.has("t72"))
		var cue: String="t72" if dedicated else "tank"
		check(selected.get(1,{}).get("cue")==cue and World.candidates(tank_source(121),world.streams.has("t80"),world.streams.has("t72")).get(1,{}).get("cue")=="t80", "validated availability alone routes119 while121 stays T80: "+state)
		world.admitted.assign([cue,"hind"]);world.refresh()
		check(world.players[cue].playing and world.players.tracks.playing, "selected visible moving class and dependent tracks play: "+state)
		if dedicated:
			var player: AudioStreamPlayer=world.players.t72
			check(player.bus==audio.presentation_bus and player.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and player.stream.loop_begin==0 and player.stream.loop_end==627720 and not player.stream.stereo and player.pitch_scale==1.0, "one centred fixed-pitch T72 loops exact mono length through incumbent limiter")
			check(world.cue_gain("t72")==0.65*0.30 and not world.players.tank.playing, "T72 nominal factor is0.30 without simultaneous generic fallback")
			var clock: Array=[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)]
			check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"t72":0}) and not player.playing and not world.players.tracks.playing and world.players.hind.playing and not world.players.tank.playing, "T72 Off silences dependent tracks and never substitutes generic")
			check(World.candidates(data,world.streams.has("t80"),world.streams.has("t72")).get(1,{}).get("cue")=="t72", "T72 Off keeps dedicated classification")
			check(audio.set_mix({"master":50,"effects":20,"voice":100,"motors":100,"t72":40}) and player.playing and world.players.tracks.playing and is_equal_approx(db_to_linear(player.volume_db),0.65*0.50*0.20*0.30*0.40) and player.pitch_scale==1.0, "T72 user/effects/master gains multiply without RPM or pitch changes")
			check(clock==[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)], "T72 controls leave original clocks/events/motors unchanged")
			world.admitted.erase("t72");world.refresh()
			check(not player.playing and not world.players.tracks.playing and world.players.hind.playing, "loss of T72 proof stops its bed and tracks only")
			world.admitted.append("t72");world.refresh();audio.set_transport_muted(true)
			check(not player.playing and world.pending.is_empty() and world.admitted.is_empty(), "transport clears T72 playback and stale admission")
			audio.set_transport_muted(false);world.refresh();check(not player.playing, "transport recovery cannot replay remembered T72 proof")
			world.admitted.append("t72");world.refresh();audio.reset_timeline()
			check(not player.playing and world.admitted.is_empty(), "source timeline reset clears T72 playback")
			audio.apply_audio(packet(2));world.admitted.append("t72");world.refresh()
			var disabled: Dictionary=packet(3);disabled.enabled=false
			check(audio.apply_audio(disabled) and not player.playing, "original sound gate silences T72")
		check(await audio.drain_for_shutdown(), "T72 optional state drains cleanly: "+state);audio.free()
	var reader: RefCounted=World.new()
	var manifest_path: String=directory.path_join("manifest.json")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	check(reader._read_bank(directory,"private visible-t72 cue",World.T72_CUES).has("error"), "T72 PCM hash mismatch rejects the whole bank")
	FileAccess.open(path,FileAccess.WRITE).store_buffer(good)
	manifest.cues.extra=manifest.cues.t72.duplicate(true)
	FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(reader._read_bank(directory,"private visible-t72 cue",World.T72_CUES).has("error"), "T72 manifest rejects an extra cue")
	manifest.cues.erase("extra")
	for frames: int in [627719,627721]:
		var stream: AudioStreamWAV=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=48000
		var bytes: PackedByteArray=PackedByteArray();bytes.resize(frames*2);stream.data=bytes
		check(stream.save_to_wav(path)==OK, "one-frame T72 negative fixture writes")
		manifest.cues.t72.sha256=FileAccess.get_sha256(path);FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
		check(reader._read_bank(directory,"private visible-t72 cue",World.T72_CUES).get("error")=="invalid T72 frame count", "matching manifest SHA cannot admit wrong T72 duration")
	for format: Array in [[44100,false,AudioStreamWAV.FORMAT_16_BITS],[48000,true,AudioStreamWAV.FORMAT_16_BITS],[48000,false,AudioStreamWAV.FORMAT_8_BITS]]:
		var stream: AudioStreamWAV=AudioStreamWAV.new();stream.mix_rate=format[0];stream.stereo=format[1];stream.format=format[2]
		var bytes: PackedByteArray=PackedByteArray();bytes.resize(627720*2);stream.data=bytes
		check(stream.save_to_wav(path)==OK, "wrong-format T72 negative fixture writes")
		manifest.cues.t72.sha256=FileAccess.get_sha256(path);FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
		check(reader._read_bank(directory,"private visible-t72 cue",World.T72_CUES).has("error"), "T72 rejects wrong rate/channels/bit depth even with matching SHA")
	check(JSON.stringify(data)==original, "T72 eligibility, masks and controls preserve original source")

func allied_checks(base_directory: String, ui: Image, mask: Image) -> void:
	check(World.ALLIED_CUES==["m113","bradley"] and World.ALLIED_SHAPES=={129:"m113",131:"bradley"}, "allied bank and exact intact original roster stay bounded")
	for shape: int in [129,131]:
		var data: Dictionary=tank_source(shape)
		var original: String=JSON.stringify(data)
		var cue: String="m113" if shape==129 else "bradley"
		check(World.candidates(JSON.parse_string(original)).get(1,{}).get("cue")==cue, "exact JSON allied identity maps to its own recording: "+cue)
		var actors: Dictionary={};actors[[123,shape]]=[data.world.dynamic[0],1]
		check(World.moving_vehicle_candidate(data.objects[0],actors,shape) and not World.moving_tank_candidate(data.objects[0],actors,shape), "allied eligibility never widens strict tank helper: "+cue)
		for speed: int in [-32768,-1,1,32767]:
			var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].speed_raw=speed
			check(World.candidates(changed,false).get(1,{}).get("cue")==cue, "allied forward/reverse signed16 movement retains exact class: "+cue)
		for speed: Variant in [0,-32769,32768,0.5,NAN,INF,"10",true]:
			var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].speed_raw=speed
			check(World.candidates(changed).is_empty(), "stationary or malformed allied motion stays silent: "+cue)
		for mutation: Dictionary in [{"shape_index":shape+0.5},{"shape_index":str(shape)},{"pointer":123.5},{"pointer":"123"},{"pointer":-1},{"pointer":65536},{"dynamic_instance":false}]:
			var changed: Dictionary=data.duplicate(true);changed.objects[0].merge(mutation,true)
			check(World.candidates(changed).is_empty(), "allied drawn identity cannot be coerced or made static: "+cue)
		for mutation: Dictionary in [{"shape_index":shape+1},{"shape_index":shape+0.5},{"pointer":124},{"pointer":123.5},{"pointer":"123"}]:
			var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].merge(mutation,true)
			check(World.candidates(changed).is_empty(), "allied actor must exactly match drawn pointer and model: "+cue)
		var duplicate: Dictionary=data.duplicate(true);duplicate.world.dynamic.append(duplicate.world.dynamic[0].duplicate())
		check(World.candidates(duplicate).is_empty(), "ambiguous reused allied actor cannot supply movement: "+cue)
		var missing: Dictionary=data.duplicate(true);missing.world.dynamic=[]
		check(World.candidates(missing).is_empty(), "allied drawing never invents absent movement: "+cue)
		ui.fill(Color.BLACK)
		var token: Dictionary={"size":mask.get_size(),"clip":data.camera.clip,"selected":World.candidates(data),"ui":ui.get_data()}
		for flag: int in [0,8]:
			mask.fill(Color8(1,0,flag));check(World.visible_cues(mask,token)==[cue], "ordinary/guarded actual allied owner qualifies: "+cue)
		for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0),Color.TRANSPARENT]:
			mask.fill(colour);check(World.visible_cues(mask,token).is_empty(), "occluded/offscreen/line/round/alpha allied owners remain silent: "+cue)
		mask.fill(Color8(2,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(820,231,Color8(1,0,8))
		check(World.visible_cues(mask,token)==[cue], "thin allied silhouette uses separated actual same-owner pixels: "+cue)
		ui.fill(Color.WHITE);token.ui=ui.get_data()
		check(World.visible_cues(mask,token).is_empty(), "opaque original UI blocks narrow allied proof: "+cue)
		ui.fill(Color.BLACK);token.ui=ui.get_data()
		mask.set_pixel(820,231,Color8(2,0,8))
		check(World.visible_cues(mask,token).is_empty(), "different allied owners cannot combine tiny fragments: "+cue)
		var pair: Dictionary=data.duplicate(true)
		var second: Dictionary=data.objects[0].duplicate(true);second.pointer=124;pair.objects.append(second)
		pair.world.dynamic.append({"pointer":124,"shape_index":shape,"speed_raw":-10});token.selected=World.candidates(pair)
		# Both owners are now eligible: the background must belong to neither.
		mask.fill(Color8(0,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(820,231,Color8(2,0,8))
		check(token.selected.size()==2 and World.visible_cues(mask,token).is_empty(), "two selected allied owners of the same class still cannot combine isolated witnesses: "+cue)
		token.selected=World.candidates(data)
		mask.set_pixel(815,241,Color8(1,0,8))
		check(World.visible_cues(mask,token).is_empty(), "allied witnesses retain four-source-pixel separation: "+cue)
		mask.set_pixel(815,241,Color8(2,0,8));mask.set_pixel(800,241,Color8(2,0,0));mask.set_pixel(800,236,Color8(1,0,0));mask.set_pixel(790,241,Color8(1,0,8));mask.set_pixel(810,241,Color8(1,0,0))
		check(World.visible_cues(mask,token)==[cue], "complete allied scan finds separated endpoints around an intermediate first witness: "+cue)
		check(World.visible_cues(Image.create(256,97,false,Image.FORMAT_RGBA8),token).is_empty(), "stale allied target size cannot lend visibility: "+cue)
		check(JSON.stringify(data)==original, "allied qualification never mutates source: "+cue)
	for shape: int in [130,132,115,117,119,121,127,133,163]:
		check(not World.candidates(tank_source(shape)).values().any(func(item):return item.cue in World.ALLIED_CUES), "wrecks and other model classes cannot borrow allied recordings: "+str(shape))
	var directory: String=output.path_join("generated-allied-bank")
	bank(directory,World.ALLIED_CUES,"private visible-allied cues")
	var audio: Node=isolated_audio();audio.recorded_effect_directory=""
	audio.world_audio.directory=base_directory
	audio.world_audio.environment_directory=output.path_join("allied-environment-control")
	audio.world_audio.soviet_directory=output.path_join("allied-soviet-control")
	audio.world_audio.tank_directory=output.path_join("allied-tank-control")
	audio.world_audio.allied_directory=directory
	bank(audio.world_audio.environment_directory,World.ENVIRONMENT_CUES,"private visible-environment cues")
	bank(audio.world_audio.soviet_directory,World.SOVIET_CUES,"private visible-soviet cues")
	bank(audio.world_audio.tank_directory,World.TANK_CUES,"private visible-tank fallback")
	root.add_child(audio);audio.apply_audio(packet(1))
	var world: RefCounted=audio.world_audio
	check(world.streams.size()==8 and world.players.size()==8 and world.allied_failure.is_empty(), "valid allied bank adds exactly two independent players without replacing incumbents")
	for cue: String in World.ALLIED_CUES:
		var player: AudioStreamPlayer=world.players[cue]
		check(player.bus==audio.presentation_bus and player.stream.mix_rate==48000 and player.stream.format==AudioStreamWAV.FORMAT_16_BITS and not player.stream.stereo and player.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and player.stream.loop_begin==0 and player.stream.loop_end==World.ALLIED_FRAME_COUNTS[cue], "allied exact per-cue mono16 loop uses incumbent limiter: "+cue)
		check(world.cue_gain(cue)==0.65*0.30, "allied fixed authored gain: "+cue)
	check(world.cue_gain("river")==0.65*0.20 and world.cue_gain("hind")==0.65*0.30 and world.cue_gain("field")==0.65*0.08 and world.cue_gain("cow")==0.65*0.80 and world.cue_gain("t80")==0.65*0.30 and world.cue_gain("tank")==0.65*0.30, "allied bank leaves all incumbent gain factors exact")
	world.admitted.assign(["m113","bradley","hind","t80"]);world.refresh()
	check(world.players.m113.playing and world.players.bradley.playing and world.players.m113.pitch_scale==1.0 and world.players.bradley.pitch_scale==1.0 and not world.players.tank.playing, "both allied classes coexist at fixed pitch without generic fallback")
	world.admitted.append("m113");world.refresh()
	check(world.players.size()==8 and is_equal_approx(db_to_linear(world.players.m113.volume_db),0.65*0.30) and world.players.m113.pitch_scale==1.0, "additional allied admission never multiplies players, gain or pitch")
	var clock: Array=[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)]
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"m113":0,"bradley":40})
	check(not world.players.m113.playing and world.players.bradley.playing and is_equal_approx(db_to_linear(world.players.bradley.volume_db),0.65*0.30*0.40) and world.players.hind.playing and world.players.t80.playing and not world.players.tank.playing, "independent allied Off/gain leaves other classes intact and never substitutes tank")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"m113":30,"bradley":0})
	check(world.players.m113.playing and not world.players.bradley.playing and is_equal_approx(db_to_linear(world.players.m113.volume_db),0.65*0.30*0.30) and not world.players.tank.playing, "Bradley Off remains independent from M113 and cannot enable fallback")
	world.admitted.clear();world.refresh();audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"m113":100,"bradley":100})
	check(not world.players.m113.playing and not world.players.bradley.playing, "allied unmute cannot invent remembered visibility")
	check(clock==[audio.last_frame,audio.epoch,audio.last_event_id,audio.delivered,audio.current_loops.duplicate(true)], "allied gain controls never advance original events/clocks/motors")
	if native: await allied_native_checks(audio,ui)
	check(await audio.drain_for_shutdown(), "both allied streams use clean incumbent shutdown");audio.free()
	var reader: RefCounted=World.new()
	var manifest_path: String=directory.path_join("manifest.json")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	var extra: Dictionary=manifest.duplicate(true);extra.cues.extra=extra.cues.m113.duplicate(true)
	FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(extra))
	check(reader._read_bank(directory,"private visible-allied cues",World.ALLIED_CUES).has("error"), "allied manifest rejects an extra cue")
	FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	for cue: String in World.ALLIED_CUES:
		var path: String=directory.path_join(cue+".wav")
		var good: PackedByteArray=FileAccess.get_file_as_bytes(path)
		FileAccess.open(path,FileAccess.WRITE).store_string("corrupt")
		check(reader._read_bank(directory,"private visible-allied cues",World.ALLIED_CUES).has("error"), "allied hash mismatch rejects entire two-cue bank: "+cue)
		for delta: int in [-1,1]:
			var stream: AudioStreamWAV=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=48000
			var bytes: PackedByteArray=PackedByteArray();bytes.resize((World.ALLIED_FRAME_COUNTS[cue]+delta)*2);stream.data=bytes
			check(stream.save_to_wav(path)==OK, "wrong-length allied fixture writes")
			manifest.cues[cue].sha256=FileAccess.get_sha256(path);FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
			check(reader._read_bank(directory,"private visible-allied cues",World.ALLIED_CUES).has("error"), "matching allied SHA cannot admit a one-frame duration mismatch: "+cue)
		FileAccess.open(path,FileAccess.WRITE).store_buffer(good);manifest.cues[cue].sha256=FileAccess.get_sha256(path)
		FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var path: String=directory.path_join("bradley.wav")
	for format: Dictionary in [{"rate":44100,"stereo":false,"bits":AudioStreamWAV.FORMAT_16_BITS},{"rate":48000,"stereo":true,"bits":AudioStreamWAV.FORMAT_16_BITS},{"rate":48000,"stereo":false,"bits":AudioStreamWAV.FORMAT_8_BITS}]:
		var stream: AudioStreamWAV=AudioStreamWAV.new();stream.format=format.bits;stream.mix_rate=format.rate;stream.stereo=format.stereo
		var bytes: PackedByteArray=PackedByteArray();bytes.resize(World.ALLIED_FRAME_COUNTS.bradley*2);stream.data=bytes
		check(stream.save_to_wav(path)==OK, "wrong-format allied fixture writes")
		manifest.cues.bradley.sha256=FileAccess.get_sha256(path);FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
		check(reader._read_bank(directory,"private visible-allied cues",World.ALLIED_CUES).has("error"), "matching allied SHA cannot admit wrong sample rate/channels/bit depth")
	for folder: String in [directory,output.path_join("missing-allied-bank")]:
		var isolated: Node=isolated_audio();isolated.recorded_effect_directory=""
		isolated.world_audio.directory=base_directory;isolated.world_audio.environment_directory=output.path_join("allied-environment-control")
		isolated.world_audio.soviet_directory=output.path_join("allied-soviet-control");isolated.world_audio.tank_directory=output.path_join("allied-tank-control");isolated.world_audio.allied_directory=folder
		root.add_child(isolated)
		check(isolated.world_audio.streams.size()==6 and isolated.world_audio.players.size()==6 and not isolated.world_audio.streams.has("m113") and not isolated.world_audio.streams.has("bradley") and isolated.failure.is_empty(), "invalid/absent allied bank atomically preserves all six incumbent cues")
		check(not isolated.world_audio.allied_failure.is_empty() if folder==directory else isolated.world_audio.allied_failure.is_empty(), "invalid allied bank reports separately while absence stays optional")
		await isolated.drain_for_shutdown();isolated.free()

func allied_native_checks(audio: Node, ui: Image) -> void:
	var data: Dictionary=tank_source(129)
	var second: Dictionary=tank_source(131).objects[0]
	second.pointer=124
	for point: Array in second.polygons[0].camera_vertices: point[0]+=400.0
	data.objects.append(second);data.world.dynamic.append({"pointer":124,"shape_index":131,"speed_raw":-10})
	var target: SubViewport=Ownership.new();root.add_child(target)
	check(target.prepare(data,Vector2i(1280,485)), "production owner mesh prepares both allied classes")
	var world: RefCounted=audio.world_audio
	ui.fill(Color.BLACK);audio.apply_audio(packet(2));world.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	check(world.players.m113.playing and world.players.bradley.playing, "postdraw actual separate owners admit both allied classes simultaneously")
	ui.fill(Color.WHITE);world.observe(data,target,ui,audio.last_frame,audio.epoch)
	await RenderingServer.frame_post_draw
	check(not world.players.m113.playing and not world.players.bradley.playing, "postdraw opaque original UI silences both allied classes")
	ui.fill(Color.BLACK);world.observe(data,target,ui,audio.last_frame,audio.epoch);audio.apply_audio(packet(3))
	await RenderingServer.frame_post_draw
	check(not world.players.m113.playing and not world.players.bradley.playing, "new source frame cancels queued allied owner proof")
	world.observe(data,target,ui,audio.last_frame,audio.epoch);audio.reset_timeline()
	await RenderingServer.frame_post_draw
	check(not world.players.m113.playing and not world.players.bradley.playing and world.pending.is_empty(), "timeline epoch/reset cancels queued allied admission")
	audio.apply_audio(packet(4));world.observe(data,target,ui,3,audio.epoch)
	check(world.pending.is_empty() and not world.players.m113.playing and not world.players.bradley.playing, "old allied source frame cannot borrow current packet identity")
	world.observe(data,target,ui,audio.last_frame,audio.epoch+1)
	check(world.pending.is_empty(), "wrong allied source epoch never queues ownership")
	world.observe(data,target,ui,audio.last_frame,audio.epoch);audio.set_transport_muted(true)
	await RenderingServer.frame_post_draw
	check(not world.players.m113.playing and not world.players.bradley.playing and world.pending.is_empty(), "transport mute between queue/draw cancels both allied classes")
	audio.set_transport_muted(false);world.refresh()
	check(not world.players.m113.playing and not world.players.bradley.playing, "transport recovery cannot replay stale allied visibility")
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
	var audio: Node = isolated_audio(); audio.recorded_effect_directory = ""
	audio.world_audio.directory = base_directory; audio.world_audio.environment_directory = directory
	audio.world_audio.soviet_directory=""
	root.add_child(audio)
	check(audio.world_audio.streams.size() == 4, "independent optional environment bank adds exactly two cues")
	var world: RefCounted = audio.world_audio
	check(world.players.cow.stream.loop_mode == AudioStreamWAV.LOOP_DISABLED and world.players.field.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "cow is one call, field is a fixed loop")
	check(world.cue_gain("hind") == 0.65*0.30 and world.cue_gain("river") == 0.65*0.20, "accepted Hind/river factors remain exact")
	check(world.cue_gain("field") == 0.65*0.08, "accepted gentle field level remains0.08")
	check(world.cue_gain("cow") == 0.65*0.80, "cow avoids double attenuation while accepted beds remain unchanged")
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
	var bad: Node = isolated_audio();bad.recorded_effect_directory = ""
	bad.world_audio.directory = base_directory;bad.world_audio.environment_directory = directory
	bad.world_audio.soviet_directory=""
	root.add_child(bad)
	check(bad.world_audio.streams.size() == 2 and bad.world_audio.streams.has("hind") and not bad.world_audio.environment_failure.is_empty(), "invalid optional environment bank cannot disable accepted Hind/river bank")
	check(bad.failure.is_empty(), "optional environment failure cannot invalidate original source audio")
	await bad.drain_for_shutdown();bad.free()

func soviet_checks(base_directory: String, ui: Image, mask: Image) -> void:
	var data: Dictionary=source(121)
	data.objects[0].dynamic_instance=true;data.objects[0].static_path=false
	var original: String=JSON.stringify(data)
	check(World.candidates(JSON.parse_string(original)).get(1,{}).get("cue")=="t80", "exact JSON intact moving T80 joins its one source actor")
	for speed: int in [-32768,-1,1,32767]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].speed_raw=speed
		check(World.candidates(changed).get(1,{}).get("cue")=="t80", "finite nonzero signed16 forward/reverse T80 movement qualifies")
	for speed: Variant in [0,-32769,32768,0.5,NAN,INF,"10",true]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].speed_raw=speed
		check(World.candidates(changed).is_empty(), "stationary/nonintegral/nonfinite/out-of-range T80 movement stays silent")
	for shape: int in [122,115,117,119]:
		var changed: Dictionary=data.duplicate(true);changed.objects[0].shape_index=shape;changed.world.dynamic[0].shape_index=shape
		check(World.candidates(changed).get(1,{}).get("cue") != "t80", "wreck and other Soviet models cannot borrow exact T80 recording")
	for mutation: Dictionary in [{"shape_index":121.5},{"shape_index":"121"},{"pointer":123.5},{"pointer":"123"},{"dynamic_instance":false}]:
		var changed: Dictionary=data.duplicate(true);changed.objects[0].merge(mutation,true)
		check(World.candidates(changed).is_empty(), "T80 source identity cannot be truncated/coerced/static")
	for mutation: Dictionary in [{"shape_index":121.5},{"pointer":123.5},{"shape_index":122},{"pointer":124}]:
		var changed: Dictionary=data.duplicate(true);changed.world.dynamic[0].merge(mutation,true)
		check(World.candidates(changed).is_empty(), "T80 actor identity must exactly match the drawn pointer/model")
	var duplicate: Dictionary=data.duplicate(true);duplicate.world.dynamic.append(duplicate.world.dynamic[0].duplicate())
	check(World.candidates(duplicate).is_empty(), "reused T80 actor pointer/model rejects ambiguous movement")
	var missing: Dictionary=data.duplicate(true);missing.world.dynamic=[]
	check(World.candidates(missing).is_empty(), "allocation-free T80 drawing cannot invent actor movement")
	ui.fill(Color.BLACK)
	var token: Dictionary={"size":mask.get_size(),"clip":data.camera.clip,"selected":World.candidates(data),"ui":ui.get_data()}
	for flag: int in [0,8]:
		mask.fill(Color8(1,0,flag));check(World.visible_cues(mask,token)==["t80"], "ordinary/guarded actual T80 ownership admits the one class bed")
	for colour: Color in [Color8(2,0,8),Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.fill(colour);check(World.visible_cues(mask,token).is_empty(), "occluding/line/round/transparent T80 pixels remain silent")
	mask.fill(Color8(1,0,8));ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(), "original UI cannot lend T80 visibility")
	ui.fill(Color.BLACK)
	token.ui=ui.get_data();mask.fill(Color8(2,0,0))
	mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(820,231,Color8(1,0,8))
	check(World.visible_cues(mask,token)==["t80"], "thin T80 actual same-owner witnesses qualify between sparse grid points")
	ui.fill(Color.WHITE);token.ui=ui.get_data()
	check(World.visible_cues(mask,token).is_empty(), "exact T80 scan retains original UI exclusion")
	ui.fill(Color.BLACK);token.ui=ui.get_data()
	mask.set_pixel(820,231,Color8(2,0,8))
	check(World.visible_cues(mask,token).is_empty(), "exact T80 scan cannot combine different owners")
	for colour: Color in [Color8(1,0,64),Color8(1,0,255),Color8(1,0,8,0)]:
		mask.set_pixel(820,231,colour)
		check(World.visible_cues(mask,token).is_empty(), "exact T80 scan retains protected/round/alpha exclusion")
	mask.fill(Color8(2,0,0));mask.set_pixel(800,241,Color8(1,0,0));mask.set_pixel(815,241,Color8(1,0,8))
	check(World.visible_cues(mask,token).is_empty(), "exact T80 scan retains four-original-pixel minimum separation")
	var directory: String=output.path_join("generated-soviet-bank")
	var environment: String=output.path_join("soviet-environment-control")
	bank(directory,World.SOVIET_CUES,"private visible-soviet cues")
	bank(environment,World.ENVIRONMENT_CUES,"private visible-environment cues")
	var audio: Node=isolated_audio();audio.recorded_effect_directory=""
	audio.world_audio.directory=base_directory;audio.world_audio.environment_directory=environment;audio.world_audio.soviet_directory=directory
	root.add_child(audio);audio.apply_audio(packet(1))
	var world: RefCounted=audio.world_audio
	check(world.streams.size()==5 and world.players.size()==5 and world.soviet_failure.is_empty(), "independent optional T80 bank adds exactly one player without replacing incumbent banks")
	var player: AudioStreamPlayer=world.players.t80
	check(player.bus==audio.presentation_bus and player.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and player.stream.loop_end==1062930 and not player.stream.stereo, "verified full source length loops once in mono through existing limiter")
	check(world.cue_gain("t80")==0.65*0.30 and world.cue_gain("river")==0.65*0.20 and world.cue_gain("hind")==0.65*0.30 and world.cue_gain("field")==0.65*0.08 and world.cue_gain("cow")==0.65*0.80, "new T80 fixed factor preserves all four accepted gain factors")
	world.admitted.assign(["river","hind","field","cow","t80"]);world.refresh()
	check(player.playing and player.pitch_scale==1.0, "one centred fixed-pitch T80 bed plays after class admission")
	var source_clock: Array=[audio.last_frame,audio.epoch,audio.last_event_id]
	check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"t80":0}) and not player.playing and world.players.hind.playing, "independent T80 Off preserves admitted Hind")
	check(audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"t80":40}) and player.playing and is_equal_approx(db_to_linear(player.volume_db),0.65*0.30*0.40), "independent T80 gain applies only to valid current admission")
	check(source_clock==[audio.last_frame,audio.epoch,audio.last_event_id], "T80 gain cannot advance source clocks or consume events")
	audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"t80":100})
	world.admitted.erase("t80");world.refresh()
	check(not player.playing and world.players.hind.playing and world.players.river.playing and world.players.field.playing, "loss of T80 admission stops only that bed")
	world.admitted.append("t80");world.refresh();audio.set_transport_muted(true)
	check(not player.playing and world.pending.is_empty() and world.admitted.is_empty(), "transport clears T80 playback and stale proof with incumbent gate")
	audio.set_transport_muted(false);world.refresh();check(not player.playing, "transport recovery cannot replay remembered T80 visibility")
	check(await audio.drain_for_shutdown(), "optional T80 drains through existing shutdown")
	audio.free()
	var manifest_path: String=directory.path_join("manifest.json")
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	manifest.cues.extra=manifest.cues.t80.duplicate(true)
	FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var reader: RefCounted=World.new()
	check(reader._read_bank(directory,"private visible-soviet cues",World.SOVIET_CUES).has("error"), "optional Soviet manifest accepts exactly one t80 cue")
	manifest.cues.erase("extra");FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	var truncated: AudioStreamWAV=AudioStreamWAV.new();truncated.format=AudioStreamWAV.FORMAT_16_BITS;truncated.mix_rate=48000
	var bytes: PackedByteArray=PackedByteArray();bytes.resize(1062912*2);truncated.data=bytes
	var path: String=directory.path_join("t80.wav");check(truncated.save_to_wav(path)==OK,"generated provisional-length T80 negative fixture writes")
	manifest.cues.t80.sha256=FileAccess.get_sha256(path);FileAccess.open(manifest_path,FileAccess.WRITE).store_string(JSON.stringify(manifest))
	check(reader._read_bank(directory,"private visible-soviet cues",World.SOVIET_CUES).get("error")=="invalid T80 frame count", "provisional18-frame-short count cannot silently replace verified original length")
	for folder: String in [directory,output.path_join("missing-soviet-bank")]:
		var isolated: Node=isolated_audio();isolated.recorded_effect_directory=""
		isolated.world_audio.directory=base_directory;isolated.world_audio.environment_directory=environment;isolated.world_audio.soviet_directory=folder
		root.add_child(isolated)
		check(isolated.world_audio.streams.size()==4 and not isolated.world_audio.streams.has("t80") and isolated.failure.is_empty(), "missing/invalid optional T80 bank cannot disable any incumbent cue")
		check(not isolated.world_audio.soviet_failure.is_empty() if folder==directory else isolated.world_audio.soviet_failure.is_empty(), "invalid Soviet bank is reported separately; absent bank remains optional")
		await isolated.drain_for_shutdown();isolated.free()
	check(JSON.stringify(data)==original,"T80 qualification never mutates paired source")

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
	var actual_visible: Array[String] = World.visible_cues(owners,token)
	actual_visible.sort()
	check(actual_visible==["field","woodland"], "actual retained production mask admits exact JSON field and newly qualified tree")
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
	var audio: Node = isolated_audio();audio.recorded_effect_directory = ""
	# Keep unrelated145MB score prewarm out of this focused field fixture.
	audio.prefer_independent_music = false
	audio.music_bank.directory = output.path_join("absent-fixture-score")
	audio.world_audio.directory = "";audio.world_audio.environment_directory = output.path_join("retained-generated-environment-bank")
	audio.world_audio.soviet_directory=""
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
