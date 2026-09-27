extends RefCounted
## Presentation palette from the verified, locally extracted Genesis CRAM.
## Original PC material indices, geometry, draw ordering and UI are unchanged.
const PALETTE_SHA256 = "aabb29495777c4cd15b2a7f0c7ca89d67e4a2fda70b6bb0d2411c0c8b5206169"
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
# Explicit visual mapping. The dark road uses Genesis bank-3 entry 13.
const SWATCHES = [48,49,50,61,52,53,54,55,56,57,58,59,60,61,62,63]
var palette: Array = []

func load_palette(path: String) -> bool:
	palette.clear()
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != PALETTE_SHA256: return false
	var entries := []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if not "\tIndex " in line: continue
		var values := line.split("\t")[0].strip_edges().split(" ",false)
		if values.size() != 3: return false
		entries.append([int(values[0]),int(values[1]),int(values[2])])
	if entries.size() != 64: return false
	for index in SWATCHES: palette.append(entries[index].duplicate())
	return true

func for_original(source: Array) -> Array:
	if palette.size() != 16 or source.size() != 16: return source
	for i in 16:
		if not source[i] is Array or source[i].size() != 3: return source
		for channel in 3:
			if source[i][channel] != PC_PALETTE[i][channel]: return source
	return palette.duplicate(true)
