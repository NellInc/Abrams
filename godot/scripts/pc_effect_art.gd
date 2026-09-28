extends RefCounted
## Genesis-derived impact artwork. Original observed bitmaps own all animation.
const Colour = preload("res://scripts/pc_colour.gd")
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
const SOURCE_HASH := "c23a534927e8b7e433f2e86b516dbcefdb6cd36680158b753f2ff24e4e2f929f"
const ASSETS := [
	["impact-15-native-candidate.png", "b931d8f463483d3ff901203351cf553b4fdaa8d0df231f03ae28e9819b4fc7d4"],
	["impact-16-native-candidate.png", "15e46c62fc8b894b483c46129b9182e8d965284772e18f5f1520571ee79c3a85"],
	["smoke-17-candidate-03.png", "943bd58dddc59ebd8ed97363de1e545a96226f91d0b5d6bdc46b0511780211f4"]]
const DONORS := {15:0, 16:1, 17:2, 33:0, 34:1, 35:2, 51:0, 52:1, 53:2}
const ROOTS := {15:33696, 33:33698, 51:33700, 16:33722, 34:33724, 52:33726, 17:33748, 35:33750, 53:33752}
var sources: Dictionary = {}
var bounds: Dictionary = {}
var textures: Array[Texture2D] = []
var correction: Texture2D

func load_assets(root_path: String) -> bool:
	sources.clear()
	bounds.clear()
	textures.clear()
	correction = null
	var path := root_path.path_join("local-art/genesis/source/effects-v1/effects.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SOURCE_HASH: return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("images") is Array or data.images.size() != 64: return false
	var loaded: Array[Texture2D] = []
	for asset: Array in ASSETS:
		path = root_path.path_join("local-art/genesis/remastered/effects-v1/"+asset[0])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != asset[1]: return false
		var image := Image.load_from_file(path)
		if image == null or image.is_empty(): return false
		loaded.append(ImageTexture.create_from_image(image))
	for index: int in DONORS:
		var source: Dictionary = data.images[index]
		if int(source.index) != index: return false
		sources[index] = source
		var box := Rect2i(int(source.width),int(source.height),0,0)
		var lo := box.position
		var hi := Vector2i.ZERO
		for at in source.opaque.size():
			if source.opaque[at]:
				var p := Vector2i(at % int(source.width),at / int(source.width))
				lo = lo.min(p)
				hi = hi.max(p+Vector2i.ONE)
		bounds[index] = Rect2(Vector2(lo),Vector2(hi-lo))
	# Float lookup preserves the existing Compatibility colour correction while
	# keeping high-resolution image loading in the native engine, not a pixel loop.
	var lut := Image.create(256,1,false,Image.FORMAT_RGBAF)
	var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for n in 256: lut.set_pixel(n,0,Colour.input_color([n,n,n],compatibility))
	correction = ImageTexture.create_from_image(lut)
	textures = loaded
	return true

func mapping(object: Dictionary, camera: Dictionary, palette: Array) -> Dictionary:
	if textures.size()!=3 or palette.size()!=16: return {}
	# JSON numbers arrive as floats; nested Array equality is type-sensitive.
	# Compare the actual channels rather than rejecting an identical live palette.
	for i in 16:
		if not palette[i] is Array or palette[i].size()!=3: return {}
		for c in 3:
			if palette[i][c]!=PC_PALETTE[i][c]: return {}
	if object.get("kind","")!="sprite" or object.get("sprite_status","")!="observed": return {}
	var sprite = object.get("sprite")
	if not sprite is Dictionary: return {}
	var index := int(sprite.get("index",-1))
	if index not in sources or int(object.get("bitmap_index",-1))!=index: return {}
	if int(object.get("shape_index",-1))!=183+int(DONORS[index]) or int(object.get("root",-1))!=ROOTS[index]: return {}
	var source: Dictionary = sources[index]
	for field in ["width","height","pixels","opaque"]:
		if sprite.get(field)!=source[field]: return {}
	if int(sprite.get("flags",-1))!=8: return {}
	for value in [sprite.get("origin"),sprite.get("clip"),camera.get("clip")]:
		if not value is Array: return {}
		for n in value:
			if not (n is int or n is float) or not is_finite(float(n)) or float(n)!=floorf(float(n)): return {}
	if sprite.origin.size()!=2 or sprite.clip.size()!=4 or camera.clip.size()!=4: return {}
	var clip: Array = sprite.clip
	var left := maxi(int(clip[0]),int(camera.clip[0]))
	var top := maxi(int(clip[1]),int(camera.clip[1]))
	var right := mini(int(clip[2]),int(camera.clip[2]))+1
	var bottom := mini(int(clip[3]),int(camera.clip[3]))+1
	if right<=left or bottom<=top: return {}
	var donor: int = DONORS[index]
	var base: Dictionary = sources[15+donor]
	var source_box: Rect2 = bounds[15+donor]
	var target: Rect2 = bounds[index]
	target.position += Vector2(sprite.origin[0],sprite.origin[1])
	var visible := target.intersection(Rect2(left,top,right-left,bottom-top))
	if not visible.has_area(): return {}
	var base_size := Vector2(base.width,base.height)
	return {"index":index,"donor":donor,"rect":visible,"target":target,
		"source_uv":Rect2(source_box.position/base_size,source_box.size/base_size)}
