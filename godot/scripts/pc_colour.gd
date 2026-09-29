extends RefCounted
## Compensate Godot Compatibility's approximate unshaded colour round trip.
## Source bytes remain untouched. Native RGB tests are required after upgrades.
static var compatibility_inputs := PackedFloat32Array()
const FRONTEND_PALETTE = [[0,0,0],[255,255,255],[170,170,170],[85,85,85],[85,85,255],[85,255,255],
	[255,85,85],[170,85,0],[0,170,0],[85,255,85],[255,255,85],[0,0,0],
	[255,85,85],[255,85,255],[255,255,85],[255,255,255]]

static func is_frontend_palette(palette: Array) -> bool:
	if palette.size()!=16: return false
	for i in 16:
		if not palette[i] is Array or palette[i].size()!=3: return false
		for c in 3:
			if palette[i][c]!=FRONTEND_PALETTE[i][c]: return false
	return true

static func input_color(rgb: Array, compatibility: bool) -> Color:
	if not compatibility: return Color8(int(rgb[0]),int(rgb[1]),int(rgb[2]))
	if compatibility_inputs.is_empty():
		compatibility_inputs.resize(256)
		for n in range(1,256):
			# Invert the output power curve, then the monotone input cubic from
			# Godot 4.7.2 drivers/gles3/shaders/tonemap_inc.glsl. Float storage
			# avoids requantizing the corrected values into another 8-bit palette.
			var linear := pow((float(n)/255.0+0.055)/1.055,2.4)
			var low := 0.0
			var high := 1.0
			for _iteration in 32:
				var x := (low+high)*0.5
				var curve := x*(x*(x*0.305306011+0.682171111)+0.012522878)
				if curve < linear: low = x
				else: high = x
			compatibility_inputs[n] = (low+high)*0.5
	return Color(compatibility_inputs[int(rgb[0])],compatibility_inputs[int(rgb[1])],compatibility_inputs[int(rgb[2])])
