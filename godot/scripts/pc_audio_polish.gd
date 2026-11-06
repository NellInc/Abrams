extends RefCounted
## Accepted one-second onboard engine and shell impact. No extra players.
const PrivateAudio = preload("res://scripts/pc_private_audio.gd")
const FRAMES := {"impact":134400,"engine":48000}
var directory: String = PrivateAudio.bank_directory(PrivateAudio.root_directory(),"pc-restrained-polish-v1")
var streams: Dictionary = {}
var failure: String = ""

func pcm_hash(stream: AudioStreamWAV) -> String:
	var hash: HashingContext = HashingContext.new()
	hash.start(HashingContext.HASH_SHA256); hash.update(stream.data)
	return hash.finish().hex_encode()

func setup(host: Node) -> void:
	if OS.has_feature("web") or directory.is_empty(): return
	var path: String = directory.path_join("manifest.json")
	if not FileAccess.file_exists(path): return
	if FileAccess.get_size(path)>16384: failure="manifest too large"; return
	var bank: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bank is Dictionary or bank.get("schema")!=1 or bank.get("kind")!="private restrained polish" or not bank.get("cues") is Dictionary or bank.cues.size()!=FRAMES.size():
		failure="invalid manifest"; return
	for cue: String in FRAMES:
		if not host.recorded_effect_streams.has(cue) or bank.get(cue+"_pcm_sha256")!=pcm_hash(host.recorded_effect_streams[cue]):
			failure="accepted parent master unavailable or changed"; return
	var pending: Dictionary = {}
	for cue: String in FRAMES:
		var entry: Variant = bank.cues.get(cue)
		if not entry is Dictionary or entry.get("file")!=cue+".wav" or not entry.get("sha256") is String:
			failure="invalid entry"; return
		path=directory.path_join(cue+".wav")
		if not FileAccess.file_exists(path) or FileAccess.get_size(path)>1048576 or FileAccess.get_sha256(path)!=entry.sha256:
			failure="missing or changed PCM"; return
		var stream: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if stream==null or stream.format!=AudioStreamWAV.FORMAT_16_BITS or stream.mix_rate!=48000 or stream.stereo or stream.data.size()!=int(FRAMES[cue])*2:
			failure="invalid PCM format/duration"; return
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if cue=="engine" else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin=0; stream.loop_end=int(FRAMES[cue])
		pending[cue]=stream
	# Working if: a bad final file leaves both incumbent streams intact;
	# accepted timbres retain original players, source gates and throttle rules.
	streams=pending
	host.engine.stream=streams.engine

func release() -> void:
	streams.clear()
