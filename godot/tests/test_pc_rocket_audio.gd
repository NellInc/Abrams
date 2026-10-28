extends SceneTree
## Controlled PCM and owner-mask fixtures. Native source proof is separate.
const Audio=preload("res://scripts/pc_audio.gd")
const World=preload("res://scripts/pc_world_audio.gd")
const Owner=preload("res://scripts/pc_modern_ownership.gd")
const Menu=preload("res://scripts/pc_audio_menu.gd")
var checks:int=0
var errors:Array[String]=[]
var guard:bool=true
var audio:Node
var target:SubViewport
var mask:Image
var proof:Dictionary
var folder:String
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:errors.append(label);printerr("FAIL: "+label)
func context(token:int=1,frame:int=10,player:bool=true)->Dictionary:
 return {"schema":1,"frame":frame,"epoch":1,"token":token,"class_index":15,"shape_index":161,"actor_pointer":0x709e,
  "controller_pointer":0xc000,"scenario_record":4,"projectile_pointer":0x70d8,"target_pointer":0x7112,"player_target":player,"backend":0,"gate":1,
  "pose":{"position":[1,2,3],"orientation":[0,0,8]},"display_pose":{"position":[0,0,0],"orientation":[0,0,0]},
  "source":{"pass_sequence":7,"start_ram_sha256":"a".repeat(64),"video_sha256":"b".repeat(64),"ui_sha256":"c".repeat(64),"owner":1}}
func packet(frame:int,id:int,events:Array=[],launches:Array=[],enabled:bool=true)->Dictionary:
 return {"schema":3,"frame":frame,"epoch":1,"last_id":id,"active":true,"enabled":enabled,"events":events,"guided_launches":launches}
func event(id:int,frame:int,ctx:Variant=null,cannon:bool=false)->Dictionary:
 var e:Dictionary={"kind":"sound","ip":0x9107,"return_ip":0x33c4 if cannon else 0x034f,"value":1 if cannon else 15,"backend":0,"enabled":true,
  "id":id,"frame":frame,"epoch":1,"sample":"cannon" if cannon else "pc_request_15","voice":"on_the_way" if cannon else null}
 if ctx!=null:e.guided_launch=ctx
 return e
func restore_proof()->void:
 audio.world_audio._rocket_proof=proof.duplicate(true)
func run()->void:
 folder=OS.get_temp_dir().path_join("abrams-rocket-%d-%d"%[OS.get_process_id(),Time.get_ticks_usec()]);DirAccess.make_dir_recursive_absolute(folder)
 var pcm:=AudioStreamWAV.new();pcm.format=AudioStreamWAV.FORMAT_16_BITS;pcm.mix_rate=48000
 var bytes:=PackedByteArray();bytes.resize(115200*2);pcm.data=bytes
 check(pcm.save_to_wav(folder.path_join("rocketlaunch.wav"))==OK,"disposable attack PCM saved")
 FileAccess.open(folder.path_join("manifest.json"),FileAccess.WRITE).store_string(JSON.stringify({"schema":1,"kind":"private source-qualified rocket attack","cues":{"rocketlaunch":{"file":"rocketlaunch.wav","sha256":FileAccess.get_sha256(folder.path_join("rocketlaunch.wav"))}}}))
 audio=Audio.new();audio.recorded_effect_directory="";audio.prefer_independent_music=false;audio.world_audio.rocket_directory=folder;root.add_child(audio)
 check(audio.world_audio.rocket_stream!=null and audio.world_audio.rocket_stream.loop_mode==AudioStreamWAV.LOOP_DISABLED,"verified nonlooping attack loads independently")
 check(audio.effects.size()==8,"existing eight-player effect pool retained")
 target=Owner.new();root.add_child(target);target.size=Vector2i(320,200);target.mesh_node.mesh=QuadMesh.new()
 mask=Image.create(320,200,false,Image.FORMAT_RGBA8);mask.fill(Color.TRANSPARENT)
 mask.set_pixel(100,100,Color8(1,0,0,255));mask.set_pixel(104,100,Color8(1,0,0,255))
 var ui:=PackedByteArray();ui.resize(64000)
 proof={"target":target,"mesh":target.mesh_node.mesh,"size":target.size,"camera":World.camera_key(target),"clip":[0,0,319,199],"ui":ui,"epoch":1,"mask":mask,
  "owners":{1:{"pointer":0x709e,"shape":161,"pose":{"position":[0,0,0],"orientation":[0,0,0]}}},"source":context().source.duplicate()}
 proof.source.erase("owner")
 audio.world_audio.visibility_guard=func():return guard
 check(audio.apply_audio(packet(9,0)),"original empty timeline active")
 restore_proof()
 audio.world_audio._cow_epoch=-1;audio.world_audio.refresh()
 check(not audio.world_audio._rocket_proof.is_empty(),"first cow refresh preserves same-draw rocket owner cache")
 var original:String=JSON.stringify(packet(10,1,[event(1,10,context())]))
 check(audio.apply_audio(JSON.parse_string(original)),"JSON source request15 with exact cached proof accepted")
 var player:AudioStreamPlayer=audio.effects[audio.cursor-1]
 check(player.playing and player.stream==audio.world_audio.rocket_stream and player.get_meta("effect_cue")=="rocketlaunch","exactly one existing player selects rocket variant")
 check(audio.delivered==1 and audio.last_event_id==1 and audio.receipts[-1].sample=="pc_request_15","original identity/counter retained")
 check(audio.effects.filter(func(p):return p.playing).size()==1,"original tone was not played before replacement")
 check(is_equal_approx(db_to_linear(player.volume_db),0.65*0.6),"new attack uses accepted conservative shot gain")
 check(audio.apply_audio(packet(10,1,[event(1,10,context())])) and audio.delivered==1,"duplicate original request consumed once")
 audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"missileflight":0})
 check(not player.playing,"Missiles Off stops current rocket only")
 audio.set_mix({"master":100,"effects":100,"voice":100,"motors":100,"missileflight":100})
 check(not player.playing,"unmute never replays consumed launch")
 restore_proof()
 check(audio.apply_audio(packet(11,1,[],[context(2,11,false)])),"other-target launch uses separate source token")
 check(audio.last_event_id==1 and audio.delivered==1 and audio.effects[audio.cursor-1].stream==audio.world_audio.rocket_stream,"other-target launch never renumbers original events")
 var count:int=audio.cursor
 check(audio.apply_audio(packet(12,1,[],[context(2,12,false)])) and audio.cursor==count,"duplicate token cannot replay on later frame")
 audio.world_audio._rocket_proof.clear()
 check(audio.apply_audio(packet(13,2,[event(2,13,context(3,13))])) and audio.effects[audio.cursor-1].stream==audio.get_stream("pc_request_15"),"missing immediate proof retains original tone/onset")
 restore_proof()
 check(audio.world_audio.rocket_variant(context(3,13),13,1,true)==null,"later owner proof cannot rescue consumed miss")
 check(audio.apply_audio(packet(14,3,[event(3,14,context(4,14),true)])) and audio.effects[audio.cursor-1].stream==audio.get_stream("cannon"),"M1A1 round remains regular despite misplaced rocket metadata")
 audio.stop_all();audio.muted=false;restore_proof()
 var token:int=10
 for fault:String in ["owner","pose","source","gate","backend","frame","shape","class","ui","line","alpha","camera","guard"]:
  token+=1;var c:Dictionary=context(token,14);restore_proof();guard=true
  match fault:
   "owner":c.source.owner=2
   "pose":c.display_pose.position[0]=1
   "source":c.source.start_ram_sha256="d".repeat(64)
   "gate":c.gate=0
   "backend":c.backend=2
   "frame":c.frame=13
   "shape":c.shape_index=125
   "class":c.class_index=5
   "ui":audio.world_audio._rocket_proof.ui[100*320+104]=255
   "line":mask.set_pixel(104,100,Color8(1,0,64,255))
   "alpha":mask.set_pixel(104,100,Color8(1,0,0,0))
   "camera":target.camera.position.x+=1
   "guard":guard=false
  check(audio.world_audio.rocket_variant(c,14,1,true)==null,"failed immediate proof consumes: "+fault)
  guard=true;target.camera.position=Vector3.ZERO;mask.set_pixel(104,100,Color8(1,0,0,255));restore_proof()
  check(audio.world_audio.rocket_variant(c,14,1,true)==null,"no delayed rescue after: "+fault)
 for bad:Variant in [null,{},true,{"token":NAN,"epoch":1}]:check(audio.world_audio.rocket_variant(bad,14,1,true)==null,"malformed optional annotation fails closed")
 restore_proof();guard=true
 audio.set_transport_muted(true)
 check(audio.apply_audio(packet(15,4,[event(4,15,context(40,15))])) and audio.effects.all(func(p):return not p.playing),"transport mute consumes rocket")
 audio.set_transport_muted(false);restore_proof()
 check(audio.world_audio.rocket_variant(context(40,15),15,1,true)==null,"transport unmute never revives old rocket")
 check(audio.apply_audio(packet(16,5,[event(5,16,context(41,16))],[],false)) and audio.effects.all(func(p):return not p.playing),"original source mute stops and consumes")
 audio.reset_timeline();check(audio.world_audio._rocket_proof.is_empty() and audio.world_audio._rocket_seen.is_empty(),"restore resets proof/token history")
 check(await audio.drain_for_shutdown(),"all existing players drain")
 check(audio.world_audio.rocket_stream==null,"private attack reference released")
 audio.free();target.free();DirAccess.remove_absolute(folder.path_join("rocketlaunch.wav"));DirAccess.remove_absolute(folder.path_join("manifest.json"));DirAccess.remove_absolute(folder)
 print("PC_ROCKET_AUDIO: %d checks, %d errors"%[checks,errors.size()]);quit(0 if errors.is_empty() else 1)
