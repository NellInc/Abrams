extends RefCounted
## Local sample-based authored score. Proprietary percussion never enters res://.
const CONTEXTS := ["intro", "menu", "briefing", "debrief"]
const IntroArt = preload("res://scripts/pc_intro_art.gd")
var directory := ""
var streams: Dictionary = {}
var failure := "" # Manifest failure: disables every context.
var failures: Dictionary = {} # context -> reason; one bad track silences only itself.
var manifest: Dictionary = {}

func _init() -> void:
	directory = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir().path_join("local-audio/frontend-music-v1")

func get_stream(context: String) -> AudioStreamWAV:
	if context not in CONTEXTS or not failure.is_empty() or failures.has(context): return null
	if streams.has(context): return streams[context]
	if manifest.is_empty():
		var path := directory.path_join("manifest.json")
		if not FileAccess.file_exists(path): return null # optional local assets
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("schema")!=1 or not data.get("tracks") is Dictionary:
			failure="Invalid local frontend music manifest"
			push_warning(failure)
			return null
		manifest=data
	var track = manifest.tracks.get(context)
	if not track is Dictionary or track.get("file")!=context+".wav" or not track.get("sha256") is String:
		return _fail(context,"Invalid local frontend music track: "+context)
	var path := directory.path_join(context+".wav")
	if not FileAccess.file_exists(path): return _fail(context,"Local frontend music file missing: "+context)
	if FileAccess.get_sha256(path)!=track.sha256: return _fail(context,"Local frontend music hash mismatch: "+context)
	var stream := AudioStreamWAV.load_from_file(path)
	if stream==null or stream.mix_rate!=24000 or not stream.stereo:
		return _fail(context,"Invalid local frontend music PCM: "+context)
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	streams[context]=stream
	return stream

func _fail(context: String, reason: String) -> AudioStreamWAV:
	failures[context]=reason
	push_warning(reason)
	return null

var intro_frames: Dictionary = {}
var intro_checked := false

func context_for_frame(source: Image, program: Dictionary, presentation: Dictionary) -> String:
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8: return ""
	var name: String=program.get("name","")
	if name not in ["START","BRIEF","END"]: return ""
	if name=="START":
		_load_intro_fingerprints()
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256);hash.update(source.get_data())
		if intro_frames.has(hash.finish().hex_encode()): return "intro"
	if presentation.get("frontend_program")!=program: return ""
	var runs= presentation.get("text_runs")
	if not runs is Array: return ""
	for run in runs:
		if not run is Dictionary or not run.get("text") is String or run.text.strip_edges().is_empty(): continue
		var box=run.get("rect")
		if not box is Array or box.size()!=4 or not run.get("pixel_sha256") is String: continue
		var valid := true
		for value in box:
			if not (value is int or value is float) or not is_finite(float(value)) or float(value)!=floorf(float(value)): valid=false
		if not valid: continue
		var rect:=Rect2i(int(box[0]),int(box[1]),int(box[2]),int(box[3]))
		if rect.size.x<=0 or rect.size.y<=0 or not Rect2i(0,0,320,200).encloses(rect): continue
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256);hash.update(source.get_region(rect).get_data())
		if hash.finish().hex_encode()!=run.pixel_sha256: continue
		return {"START":"menu","BRIEF":"briefing","END":"debrief"}[name]
	return ""

func _load_intro_fingerprints() -> void:
	if intro_checked: return
	intro_checked=true
	var root_path := directory.get_base_dir().get_base_dir()
	var path := root_path.path_join("local-art/pc-intro-v2/intro.json")
	if not FileAccess.file_exists(path): return # optional local art
	if FileAccess.get_sha256(path)!=IntroArt.CATALOG_SHA:
		push_warning("Local intro catalogue does not match the pinned intro art; intro music disabled")
		return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	for name in data.sources:
		var original := root_path.path_join("GAME/"+name)
		if not FileAccess.file_exists(original) or FileAccess.get_sha256(original)!=data.sources[name]: return
	for entry in data.entries: intro_frames[entry.rgb_sha256]=true
