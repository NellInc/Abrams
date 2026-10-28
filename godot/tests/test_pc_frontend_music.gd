extends SceneTree
const Audio=preload("res://scripts/pc_audio.gd")
const Music=preload("res://scripts/pc_frontend_music.gd")
var checks:=0
var errors:Array[String]=[]
func _initialize()->void: run.call_deferred()
func check(value:bool,label:String)->void:
	checks+=1
	if not value:errors.append(label)
func packet(frame:int,event:bool=false)->Dictionary:
	return {"schema":3,"frame":frame,"epoch":1,"last_id":1 if event or frame>1 else 0,"active":true,"enabled":true,"loops":{},
		"events":[{"id":1,"frame":frame,"epoch":1,"kind":"sound","ip":0x9107,"return_ip":0x33c4,"value":1,"backend":0,"enabled":true,"sample":"cannon","voice":"on_the_way"}] if event else []}
func run()->void:
	# The session hash cache is static; start empty so the hash_count==4 check
	# below does not depend on this being the first Audio in the process.
	Music.verified.clear()
	var audio=Audio.new()
	audio.prefer_independent_music=false # This test retains the historical donor-bank contract.
	root.add_child(audio)
	var local_music:=FileAccess.file_exists(audio.music_bank.directory.path_join("manifest.json"))
	if local_music:
		check(audio.music_bank.streams.size()==4 and audio.music_bank.hash_count==4,"startup prewarm verifies and decodes every local track once")
		var second=Audio.new()
		second.prefer_independent_music=false
		root.add_child(second)
		check(second.music_bank.streams.size()==4 and second.music_bank.hash_count==0,"verified tracks are hashed once per session")
		second.free()
	else:
		check(audio.music_bank.streams.is_empty() and audio.music_bank.failures.is_empty(),"absent optional music prewarms quietly")
	var source:=Image.create(320,200,false,Image.FORMAT_RGB8)
	source.fill(Color.BLACK)
	var region:=source.get_region(Rect2i(0,0,8,8))
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(region.get_data())
	var run:Dictionary={"text":"READY","rect":[0,0,8,8],"pixel_sha256":hash.finish().hex_encode()}
	for program_name in ["START","BRIEF","END"]:
		var program:Dictionary={"name":program_name,"load_segment":500}
		var presentation:Dictionary={"frontend_program":program,"text_runs":[run]}
		check(audio.music_context_for_frame(source,program,presentation)=={"START":"menu","BRIEF":"briefing","END":"debrief"}[program_name],"pixel-qualified frontend context: "+program_name)
		check(audio.music_context_for_frame(source,program,{"frontend_program":{"name":"OTHER"},"text_runs":[run]}).is_empty(),"wrong source program stays quiet")
		check(audio.music_context_for_frame(source,program,{"frontend_program":program,"text_runs":[]}).is_empty(),"hidden text cannot start frontend music")
	check(audio.music_context_for_frame(source,{"name":"SIM"},{"text_runs":[run]}).is_empty(),"SIM cannot get musical context")
	source.set_pixel(0,0,Color.WHITE)
	check(audio.music_context_for_frame(source,{"name":"START"},{"frontend_program":{"name":"START"},"text_runs":[run]}).is_empty(),"changed source pixels rejected")
	var project_root:=ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var title_path:=project_root.path_join("artifacts/pc-intro-trace-01/frame-0403.png")
	if FileAccess.file_exists(title_path):
		var title:=Image.load_from_file(title_path)
		title.convert(Image.FORMAT_RGB8)
		check(audio.music_context_for_frame(title,{"name":"START"},{} )=="intro","actual original title fingerprint chooses intro")
		check(audio.music_context_for_frame(title,{"name":"SIM"},{} ).is_empty(),"same image cannot impersonate a frontend program")
	for context in ["intro","menu","briefing","debrief"]:
		audio.apply_music_context(context,true)
		check(audio.music.playing,"native stream starts: "+context)
		check(audio.music.stream.loop_end==roundi(audio.music.stream.get_length()*24000),"full PCM loop: "+context)
		var starts=audio.music_starts
		audio.apply_music_context(context,true)
		check(audio.music_starts==starts,"context redraw cannot restart: "+context)
	audio.apply_music_context("briefing",true,true)
	check(not audio.music.playing,"pause stops music")
	audio.apply_music_context("briefing",false)
	check(not audio.music.playing,"original mute stops music")
	audio.apply_music_context("unknown",true)
	check(not audio.music.playing,"unknown frontend stays quiet")
	audio.apply_music_context("menu",true)
	check(audio.set_mix({"master":50,"effects":100,"voice":100,"motors":100,"music":20}),"five-channel mix")
	check(absf(db_to_linear(audio.music.volume_db)-0.65*0.5*0.2*0.3)<0.00001,"music gain uses master and music only")
	check(audio.set_music_mix(0) and not audio.music.playing,"music mute")
	check(audio.set_music_mix(70) and audio.music.playing,"music gain resumes context")
	check(not audio.set_music_mix(101),"invalid gain rejected")
	check(audio.apply_audio(packet(1)),"source gameplay packet accepted")
	check(not audio.music.playing,"gameplay is quiet")
	audio.set_transport_muted(true)
	check(audio.apply_audio(packet(2,true)),"fast-forward still consumes validated events")
	check(audio.last_event_id==1 and audio.suppressed==1,"fast-forward consumed silently")
	check(not audio.voice.playing and not audio.effects[0].playing,"no fast-forward burst")
	audio.set_transport_muted(false)
	check(not audio.voice.playing and not audio.effects[0].playing,"release never catches up")
	audio.apply_music_context("menu",true)
	await create_timer(0.15).timeout
	audio.set_transport_muted(true)
	var position=audio.music_resume_position
	check(not audio.music.playing and position>0,"transport retains music cursor")
	audio.set_transport_muted(false)
	check(audio.music.playing and audio.music_resume_position==position,"music resumes without rewind")
	var motor_packet:=packet(3)
	motor_packet.loops={"engine":{"active":true,"channel":3,"ticks":85,"program":0xbf8,"period":0x4584,"amplitude":3,"idle_period":0x4584,"amplitude_reference":3}}
	check(audio.apply_audio(motor_packet) and audio.engine.playing,"current original motor loop sounds")
	audio.set_transport_muted(true)
	check(not audio.engine.playing,"transport silences motors")
	audio.set_transport_muted(false)
	check(audio.engine.playing and not audio.voice.playing,"transport restores only currently active loop")
	audio.reset_timeline()
	check(not audio.music.playing and audio.last_event_id==0 and audio.last_frame==-1 and audio.epoch==0,"restore resets audio timeline and stops music")
	check(audio.apply_audio(packet(1,true)) and audio.delivered==1,"restored host can begin a fresh event sequence")
	check(await audio.drain_for_shutdown(),"all streams drain including music")
	if local_music:
		audio.music_bank.streams.clear() # as release_streams() leaves it
		var hashes:int=audio.music_bank.hash_count
		check(audio.music_bank.get_stream("briefing")!=null and audio.music_bank.hash_count==hashes,"reload after release decodes without re-hashing")
	# START without intro fingerprints never hashes the full frame; an unchanged
	# frame reuses its exact-byte result; any changed pixel is hashed again.
	var quiet=preload("res://scripts/pc_frontend_music.gd").new()
	quiet.intro_checked=true
	source.fill(Color.BLACK)
	quiet.context_for_frame(source,{"name":"START"},{})
	check(quiet.full_frame_hashes==0,"no intro catalogue, no full-frame hash")
	var black_hash:=HashingContext.new();black_hash.start(HashingContext.HASH_SHA256);black_hash.update(source.get_data())
	quiet.intro_frames[black_hash.finish().hex_encode()]="title"
	check(quiet.context_for_frame(source,{"name":"START"},{})=="intro" and quiet.full_frame_hashes==1,"pinned frame selects intro")
	check(quiet.context_for_frame(source,{"name":"START"},{})=="intro" and quiet.full_frame_hashes==1,"unchanged frame reuses its result")
	source.set_pixel(5,5,Color.WHITE)
	check(quiet.context_for_frame(source,{"name":"START"},{}).is_empty() and quiet.full_frame_hashes==2,"changed frame is hashed again")
	# One bad local track silences only its own context and records why.
	var bank=preload("res://scripts/pc_frontend_music.gd").new()
	check(bank.IntroArt.CATALOG_SHA==preload("res://scripts/pc_intro_art.gd").CATALOG_SHA,"intro music shares the intro art pin")
	var folder:=project_root.path_join("artifacts/pc-frontend-music-latch")
	DirAccess.make_dir_recursive_absolute(folder)
	var pcm:=AudioStreamWAV.new()
	pcm.format=AudioStreamWAV.FORMAT_16_BITS;pcm.stereo=true;pcm.mix_rate=24000
	var silence:=PackedByteArray();silence.resize(9600);pcm.data=silence
	for context in ["menu","briefing"]:check(pcm.save_to_wav(folder.path_join(context+".wav"))==OK,"temporary track written: "+context)
	var good:=FileAccess.get_sha256(folder.path_join("briefing.wav"))
	var manifest:=FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"schema":1,"tracks":{"menu":{"file":"menu.wav","sha256":"0".repeat(64)},"briefing":{"file":"briefing.wav","sha256":good},"debrief":{"file":"debrief.wav","sha256":good}}}))
	manifest.close()
	bank.directory=folder
	check(bank.get_stream("menu")==null and str(bank.failures.get("menu","")).contains("hash mismatch: menu"),"bad menu hash recorded")
	check(bank.get_stream("debrief")==null and str(bank.failures.get("debrief","")).contains("missing: debrief"),"missing debrief file recorded")
	check(bank.get_stream("briefing")!=null,"bad menu track leaves briefing music available")
	check(bank.failure.is_empty() and bank.failures.size()==2,"track failures stay per context")
	for error in errors:printerr("FAIL: "+error)
	print("PC_FRONTEND_MUSIC: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
