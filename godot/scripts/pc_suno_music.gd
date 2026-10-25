extends "res://scripts/pc_frontend_music.gd"
## Independent score. Only visible source screens and accepted source events.
const SCORE_CONTEXTS := ["menu","briefing","arming","idyll","battle","crisis","success","failure","friendly_fire","death","ending_victory","ending_defeat","battle_flank","battle_pressure","aftermath","stinger_success","stinger_failure","stinger_friendly_fire","stinger_death"]
const BATTLE_TRACKS := ["battle","battle_flank","battle_pressure"]
const GAME_CONTEXTS := ["idyll","battle","battle_flank","battle_pressure","crisis","success","failure"]
const STINGERS := {"success":"stinger_success","failure":"stinger_failure","friendly_fire":"stinger_friendly_fire","death":"stinger_death"}
var damage_cues: Dictionary = {}
var source_frame := -1
var battle_until := -1
var crisis_until := -1
var battle_index := -1
var result := ""
var end_context := ""
var last_program := ""
var fingerprints: Array = []
var _screen_bytes := PackedByteArray()
var _screen_program := ""
var _screen_context := ""

func _init() -> void:
	super._init()
	directory=directory.get_base_dir().path_join("suno-score-v1")
	contexts=SCORE_CONTEXTS.duplicate()
	contexts.append_array(["intro","debrief"])
	independent=true
	damage_cues=JSON.parse_string(FileAccess.get_file_as_string("res://data/pc_damage_voice_script.json")).cues

func get_stream(context: String) -> AudioStreamWAV:
	return super.get_stream({"intro":"menu","debrief":"briefing"}.get(context,context))

func track_for_context(context: String) -> String:
	# Older local packs remain playable until the polished assets are installed.
	var selected: String=STINGERS.get(context,context)
	return selected if manifest.get("tracks",{}).has(selected) else context

func followup_track(track: String) -> String:
	if manifest.get("tracks",{}).has("aftermath") and (track in STINGERS.values() or track in ["ending_victory","ending_defeat"]): return "aftermath"
	return ""

func prewarm() -> void:
	super.prewarm()
	if manifest.get("kind")!="independent Suno score" or not manifest.get("classification_sources") is Dictionary or not manifest.get("fingerprints") is Array:
		failure="Invalid independent Suno score manifest"
		return
	var root_path:=directory.get_base_dir().get_base_dir()
	for name in manifest.classification_sources:
		var path:=root_path.path_join("GAME/"+str(name))
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=manifest.classification_sources[name]:
			failure="Suno scene recognition source differs: "+str(name)
			return
	fingerprints=manifest.fingerprints

func update_source(packet: Dictionary) -> void:
	# Original pause/F5 stop playback and freeze its held musical context.
	# The emulator still produces VGA frames while the game is paused.
	if packet.active and source_frame>=0 and (not game_enabled or not packet.enabled):
		var elapsed:=maxi(0,int(packet.frame)-source_frame)
		if battle_until>source_frame: battle_until+=elapsed
		if crisis_until>source_frame: crisis_until+=elapsed
	source_frame=int(packet.frame)
	source_active=packet.active
	game_enabled=packet.active and packet.enabled

func observe_event(event: Dictionary) -> void:
	# Called after original IP/caller, visible-message, age and identity checks.
	if event.get("sample") in ["cannon","machinegun","impact"]:
		_hold_battle()
	var cue: String=str(event.get("voice",""))
	if damage_cues.has(cue) or cue.begins_with("pc_hit_") or cue in ["pc_engine_overheating","pc_out_of_fuel"]:
		crisis_until=source_frame+600
		_hold_battle()
	if cue=="pc_radio_complete": result="success"
	elif cue=="pc_radio_abort": result="failure"

func _hold_battle() -> void:
	# Rotate once per fresh encounter, never for each shell or redraw.
	if source_frame>=battle_until: battle_index=(battle_index+1)%BATTLE_TRACKS.size()
	battle_until=source_frame+900

func reset_score() -> void:
	game_enabled=false;source_active=false;source_frame=-1;battle_until=-1;crisis_until=-1
	battle_index=-1
	result="";end_context="";last_program=""
	_screen_bytes.clear();_screen_program="";_screen_context=""

func rebase_source() -> void:
	battle_until=maxi(-1,battle_until-source_frame)
	crisis_until=maxi(-1,crisis_until-source_frame)
	source_frame=0

func gameplay_context(state: Variant, program: Dictionary) -> String:
	if not state is Dictionary or state.get("basis")!="original-PC-SIM-read-only" or state.get("load_segment")!=program.get("load_segment") or state.get("station") not in ["gunner","commander","cupola","driver"]: return ""
	if not result.is_empty(): return result
	if source_frame<crisis_until: return "crisis"
	if source_frame<battle_until: return BATTLE_TRACKS[maxi(0,battle_index)]
	return "idyll"

func context_for_frame(source: Image, program: Dictionary, presentation: Dictionary) -> String:
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8 or not failure.is_empty(): return ""
	var name: String=program.get("name","")
	if name!=last_program:
		end_context=""
		last_program=name
	var screen:=_fingerprint(source,name)
	if not screen.is_empty(): return screen
	var legacy:=super.context_for_frame(source,program,presentation)
	if name=="END":
		if presentation.get("frontend_program")==program:
			var text: String=" ".join(verified_text(source,presentation)).to_lower().replace('"','').strip_edges()
			# Exact phrases observed in the original END executable. A generic
			# kill report, hidden unit identity or Wilson pose proves no guilt.
			if "you blew away the wrong side" in text or "your career is over" in text: end_context="friendly_fire"
			elif end_context!="friendly_fire":
				if "partial success" in text: end_context="aftermath"
				elif "complete failure" in text or "mission was a failure" in text: end_context="failure"
				elif "complete success" in text or "completely successful" in text or "great success" in text or "superior skill" in text: end_context="success"
		if not end_context.is_empty(): return end_context
		if legacy=="debrief": return result if not result.is_empty() else "aftermath"
	return {"intro":"menu","debrief":"briefing"}.get(legacy,legacy)

func _fingerprint(source: Image, program: String) -> String:
	var bytes:=source.get_data()
	if bytes==_screen_bytes and program==_screen_program: return _screen_context
	_screen_bytes=bytes;_screen_program=program;_screen_context=""
	var hashes: Dictionary={}
	for row in fingerprints:
		if not row is Dictionary or row.get("program")!=program or row.get("context") not in SCORE_CONTEXTS: continue
		var height:=int(row.get("height",0))
		if height not in [72,80,200]: continue
		if not hashes.has(height):
			var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
			hash.update(bytes.slice(0,320*height*3));hashes[height]=hash.finish().hex_encode()
		if hashes[height]==row.get("sha256"):
			_screen_context=row.context
			break
	return _screen_context
