extends RefCounted
## Genesis-derived effects. Original observed bitmaps own all animation.
## Captured normal and thermal modes share this exact RGB palette. STATUS
## occlusion belongs to original UI ownership, not an invented effect tint.
const Colour = preload("res://scripts/pc_colour.gd")
const PC_PALETTE = preload("res://scripts/pc_tandem_frame.gd").ART_PALETTE
const SOURCE_HASH := "c23a534927e8b7e433f2e86b516dbcefdb6cd36680158b753f2ff24e4e2f929f"
const ASSETS := [
	["effects-v1/impact-15-native-candidate.png", "b931d8f463483d3ff901203351cf553b4fdaa8d0df231f03ae28e9819b4fc7d4"],
	["effects-v1/impact-16-native-candidate.png", "15e46c62fc8b894b483c46129b9182e8d965284772e18f5f1520571ee79c3a85"],
	["effects-v1/smoke-17-candidate-03.png", "943bd58dddc59ebd8ed97363de1e545a96226f91d0b5d6bdc46b0511780211f4"],
	["effects-v2/effect-00.png", "cb40e4da46bba54b257ad55f75209a706cce2a3cc8dae595435725f1a6a8f3c5"],
	["effects-v2/effect-01.png", "49dc990138bcdf1c3731e1e0d342e6291ccd84bc3766ff09a3ed8bea2f5a69a5"],
	["effects-v2/effect-02.png", "8fca1bdd093be116ac90a16ac1b5fcada8fc1e711eb1dd37cefca04e53df3042"],
	["effects-v2/effect-03.png", "f9114d6e2cd4d87609ed7edede0ab94706e802b41eededb1f4b4402b0ef382f9"],
	["effects-v2/effect-04.png", "8193532a6c21cd255f1e70109d0900e894c3dd1dd59db98986ad1754049787bc"],
	["effects-v2/effect-05.png", "d82d2157d6fd6f5bd75df5fe24c49fb62efa6f33ee150057ad581b8d3341b124"],
	["effects-v2/effect-06.png", "c0f34771fd639818479a300c787aabed34e1f28c9b796358dc9c2b3cd09e69a6"],
	["effects-v2/effect-07.png", "940656c0fef93451ad9f875d6ef4338327e8a42e765bdfd52c08c5886f756757"],
	["effects-v2/effect-08.png", "d3d8eb51cc13fde9f455d54c5f1985761f7cc24d4a0741981c9ab761f6ad450c"],
	["effects-v2/effect-09-r2.png", "8c1c8890aed38ffdee2867c780f1a970ed0146e12b5800fe3b9edb4404ec8d11"],
	["effects-v2/effect-10.png", "64a3c48e7109096f71cf1feeeab765d0d1b6598120e5035739765bed0d2baf20"],
	["effects-v2/effect-11.png", "5a10086527ff0158ecae6110f78d6742651958c29e6011b5ccdc4d2391796d48"],
	["effects-v2/effect-12-r2.png", "4138dca29c239913334c9bf93fb132569f55792e633399dc41f477da88c30b3d"],
	["effects-v2/effect-13.png", "dd3ac354ed7068180717d2357df88bd34ca5a3074ad2c716b25c2a980ebebe2c"],
	["effects-v2/effect-14.png", "15501e8244265bb5b8e81d52ba5966703c32da305dc32b8d73202d67ee8f1611"],
	["effects-v2/effect-62.png", "5da29d5781fac8dfe12c105ccd23642d555cee44541ce0f56d7426941231dd70"],
	["effects-v2/effect-63.png", "84452aa08453b2ec734ab64f029040fccc0d23f2c521a3531b76d13cab4a3d96"]]
const BASES := [15, 16, 17, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 62, 63]
const DONORS := {0: 3, 1: 4, 2: 5, 3: 6, 4: 7, 5: 8, 6: 9, 7: 10, 8: 11, 9: 12, 10: 13, 11: 14, 12: 15, 13: 16, 14: 17, 15: 0, 16: 1, 17: 2, 18: 3, 19: 4, 20: 5, 21: 6, 22: 7, 23: 8, 24: 9, 25: 10, 26: 11, 27: 12, 28: 13, 29: 14, 30: 15, 31: 16, 32: 17, 33: 0, 34: 1, 35: 2, 36: 3, 37: 4, 38: 5, 39: 6, 40: 7, 41: 8, 42: 9, 43: 10, 44: 11, 45: 12, 46: 13, 47: 14, 48: 15, 49: 16, 50: 17, 51: 0, 52: 1, 53: 2, 54: 18, 55: 19, 56: 18, 57: 19, 58: 18, 59: 19, 60: 18, 61: 19, 62: 18, 63: 19}
const ROOTS := {0: 33306, 1: 33332, 2: 33358, 3: 33384, 4: 33410, 5: 33436, 6: 33462, 7: 33488, 8: 33514, 9: 33540, 10: 33566, 11: 33592, 12: 33618, 13: 33644, 14: 33670, 15: 33696, 16: 33722, 17: 33748, 18: 33308, 19: 33334, 20: 33360, 21: 33386, 22: 33412, 23: 33438, 24: 33464, 25: 33490, 26: 33516, 27: 33542, 28: 33568, 29: 33594, 30: 33620, 31: 33646, 32: 33672, 33: 33698, 34: 33724, 35: 33750, 36: 33310, 37: 33336, 38: 33362, 39: 33388, 40: 33414, 41: 33440, 42: 33466, 43: 33492, 44: 33518, 45: 33544, 46: 33570, 47: 33596, 48: 33622, 49: 33648, 50: 33674, 51: 33700, 52: 33726, 53: 33752, 54: 33786, 55: 33824, 56: 33788, 57: 33826, 58: 33790, 59: 33828, 60: 33784, 61: 33822, 62: 33782, 63: 33820}
const SHAPES := {0: 168, 1: 169, 2: 170, 3: 171, 4: 172, 5: 173, 6: 174, 7: 175, 8: 176, 9: 177, 10: 178, 11: 179, 12: 180, 13: 181, 14: 182, 15: 183, 16: 184, 17: 185, 18: 168, 19: 169, 20: 170, 21: 171, 22: 172, 23: 173, 24: 174, 25: 175, 26: 176, 27: 177, 28: 178, 29: 179, 30: 180, 31: 181, 32: 182, 33: 183, 34: 184, 35: 185, 36: 168, 37: 169, 38: 170, 39: 171, 40: 172, 41: 173, 42: 174, 43: 175, 44: 176, 45: 177, 46: 178, 47: 179, 48: 180, 49: 181, 50: 182, 51: 183, 52: 184, 53: 185, 54: 186, 55: 187, 56: 186, 57: 187, 58: 186, 59: 187, 60: 186, 61: 187, 62: 186, 63: 187}
const ART_BOUNDS := [[0.021567217828900073, 0.019451812555260833, 0.9453630481667865, 0.9557913351016799], [0.006342494714587738, 0.005415162454873646, 0.9640591966173362, 0.9792418772563177], [0.004933051444679351, 0.0036101083032490976, 0.9901338971106413, 0.98014440433213], [0.10970996216897856, 0.10685483870967742, 0.7881462799495587, 0.8004032258064516], [0.08873974645786727, 0.005967604433077579, 0.8061148396718867, 0.9812446717817562], [0.0421455938697318, 0.001658374792703151, 0.9065134099616858, 0.9842454394693201], [0.1306930693069307, 0.011560693641618497, 0.7386138613861386, 0.9800899165061014], [0.19969742813918306, 0.040336134453781515, 0.5068078668683812, 0.9394957983193277], [0.21319018404907975, 0.05638474295190713, 0.5406441717791411, 0.8830845771144279], [0.03656998738965952, 0.010080645161290322, 0.9438839848675914, 0.969758064516129], [0.10946745562130178, 0.015037593984962405, 0.855621301775148, 0.9505907626208379], [0.06847545219638243, 0.09547244094488189, 0.8630490956072352, 0.8100393700787402], [0.056338028169014086, 0.06500541711809317, 0.8890845070422535, 0.8851570964247021], [0.04401408450704225, 0.030335861321776816, 0.8620892018779343, 0.9447453954496208], [0.15321849501359927, 0.008415147265077139, 0.6990027198549411, 0.9831697054698457], [0.2265625, 0.011067708333333334, 0.541015625, 0.9772135416666666], [0.050965250965250966, 0.028830313014827018, 0.9250965250965251, 0.9299835255354201], [0.014967259120673527, 0.28843537414965986, 0.9700654817586529, 0.33877551020408164], [0.0228734810578985, 0.013345195729537367, 0.954253037884203, 0.9626334519572953], [0.09292351679771266, 0.021352313167259787, 0.8141529664045747, 0.949288256227758]]
const TILE := 512
const PAD := 2
const STRIDE := TILE+PAD*2
const COLUMNS := 5
const ROWS := 4
var sources: Dictionary = {}
var bounds: Dictionary = {}
var textures: Array[Texture2D] = []
var atlas: Texture2D
var correction: Texture2D

func load_assets(root_path: String) -> bool:
	sources.clear()
	bounds.clear()
	textures.clear()
	correction = null
	atlas = null
	var path := root_path.path_join("local-art/genesis/source/effects-v1/effects.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != SOURCE_HASH: return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("images") is Array or data.images.size() != 64: return false
	var loaded: Array[Texture2D] = []
	var packed := Image.create(STRIDE*COLUMNS,STRIDE*ROWS,false,Image.FORMAT_RGBA8)
	packed.fill(Color(0,0,0,0))
	for asset: Array in ASSETS:
		path = root_path.path_join("local-art/genesis/remastered/"+asset[0])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != asset[1]: return false
		var image := Image.load_from_file(path)
		if image == null or image.is_empty(): return false
		image.convert(Image.FORMAT_RGBA8)
		# A bounded 512-square tile exceeds the largest original 56x45 sprite at
		# tested 5x scale. Two transparent texels isolate linear filter footprints.
		image.resize(TILE,TILE,Image.INTERPOLATE_LANCZOS)
		var n := loaded.size()
		packed.blit_rect(image,Rect2i(0,0,TILE,TILE),Vector2i((n%COLUMNS)*STRIDE+PAD,(n/COLUMNS)*STRIDE+PAD))
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
	atlas = ImageTexture.create_from_image(packed)
	textures = loaded
	return true

func mapping(object: Dictionary, camera: Dictionary, palette: Array) -> Dictionary:
	if textures.size()!=ASSETS.size() or atlas==null or palette.size()!=16: return {}
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
	if int(object.get("shape_index",-1))!=SHAPES[index] or int(object.get("root",-1))!=ROOTS[index]: return {}
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
	var base: Dictionary = sources[BASES[donor]]
	var source_box: Rect2 = bounds[BASES[donor]]
	var target: Rect2 = bounds[index]
	target.position += Vector2(sprite.origin[0],sprite.origin[1])
	var visible := target.intersection(Rect2(left,top,right-left,bottom-top))
	if not visible.has_area(): return {}
	var base_size := Vector2(base.width,base.height)
	var local_uv := Rect2(source_box.position/base_size,source_box.size/base_size)
	# Generated canvas padding is not source padding. Register each new donor's
	# alpha-cutout bounds to the original opaque bounds; retain curated v1 UVs.
	if donor>=3:
		var box: Array = ART_BOUNDS[donor]
		local_uv = Rect2(box[0],box[1],box[2],box[3])
	var tile_origin := Vector2((donor%COLUMNS)*STRIDE+PAD,(donor/COLUMNS)*STRIDE+PAD)
	var atlas_size := Vector2(STRIDE*COLUMNS,STRIDE*ROWS)
	return {"index":index,"donor":donor,"rect":visible,"target":target,"local_uv":local_uv,
		"source_uv":Rect2((tile_origin+local_uv.position*TILE)/atlas_size,local_uv.size*TILE/atlas_size)}
