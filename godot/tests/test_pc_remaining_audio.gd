extends SceneTree
const Audio=preload("res://scripts/pc_audio.gd")
var checks:=0
var errors:Array[String]=[]
func _initialize()->void: run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:errors.append(label)
func packet(id:int,event:Dictionary)->Dictionary:
	return {"schema":3,"frame":id,"epoch":1,"last_id":id,"active":true,"enabled":true,"events":[event],"loops":{}}
func run()->void:
	var audio=Audio.new();root.add_child(audio)
	var script:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_remaining_voice_script.json"))
	var id:=0
	for name in script.cues:
		id+=1
		var cue:Dictionary=script.cues[name]
		var pointers:Array=cue.source_variants[0] if cue.has("source_variants") else [45056]
		var parts:Array=[]
		for index in pointers.size():parts.append({"source_pointer":pointers[index],"draw_sequence":id,"rect":[index*100,140,100,8],"pixel_sha256":"a".repeat(64)})
		var event:Dictionary={"id":id,"frame":id,"epoch":1,"ip":cue.assignment_ip,"return_ip":0,"value":0,"backend":0,"enabled":true,
			"kind":"crew_visible","sample":null,"voice":name,"message_id":id,"speaker":cue.speaker,"text":cue.caption,"parts":parts}
		check(audio.apply_audio(packet(id,event)),"valid original message accepted: "+name)
		check(audio.voice.playing and audio.voice.stream==audio.get_stream("voice_"+name),"own generated native stream starts: "+name)
		var delivered:int=audio.delivered
		check(audio.apply_audio(packet(id,event)) and audio.delivered==delivered,"duplicate silent: "+name)
	for source in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/pc_request_sound_oracle.json")).rows:
		id+=1
		var event:Dictionary={"id":id,"frame":id,"epoch":1,"ip":0x9107,"return_ip":source.return_ip,"value":source.request,"backend":0,"enabled":true,
			"kind":"sound","sample":source.sample,"voice":null}
		check(audio.apply_audio(packet(id,event)),"original additional request accepted")
		check(audio.effects[(audio.cursor-1)%audio.effects.size()].playing,"isolated sample starts: "+source.sample)
	check(await audio.drain_for_shutdown(),"new samples drain")
	for error in errors:printerr("FAIL: "+error)
	print("PC_REMAINING_AUDIO: %d checks, %d errors"%[checks,errors.size()])
	quit(0 if errors.is_empty() else 1)
