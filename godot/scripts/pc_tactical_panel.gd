extends RefCounted
## Concept-derived equipment skin. Only static housing is painted; apertures
## and unverified source panels are never covered by a skin's centre.
const ENAMEL := Color("343c2d")
const EDGE := Color("68705a")
const SHADOW := Color("111710")
const RUBBER := Color("090f0c")
const FACE := Color("0c1210")
const ASSETS := {
	"housing":"f9aa666b1c9556fa20050167d7c8fcf099d79a8d239b8cc0d78b9200b6419c3f",
	"driver":"a76cb48f484a4cb60dfd992c5ffa1c09e176ebc0736882b4cdaf695bb1814854",
	"cupola":"6bae3fcb05734d3e16b58e36e287bf427eb39ce338390acb9adfd2952bf22ce5"}
static var textures: Dictionary = {}

static func load_sources(root: String) -> void:
	textures.clear()
	var loaded: Dictionary={}
	for key in ASSETS:
		var path:=root.path_join("local-art/pc-tactical-interior-v1/"+key+".png")
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=ASSETS[key]: return
		var image:=Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(1672,941): return
		image.generate_mipmaps()
		loaded[key]=ImageTexture.create_from_image(image)
	textures=loaded

static func region(ink: CanvasItem, key: String, box: Rect2, source: Rect2) -> bool:
	if not textures.has(key): return false
	ink.draw_texture_rect_region(textures[key],box,source)
	return true

static func _nine(ink: CanvasItem, key: String, source: Rect2, margins: Vector4, box: Rect2, edges: Vector4, centre: bool=true) -> bool:
	if not textures.has(key): return false
	var sx: Array[float]=[source.position.x,source.position.x+margins.x,source.end.x-margins.z,source.end.x]
	var sy: Array[float]=[source.position.y,source.position.y+margins.y,source.end.y-margins.w,source.end.y]
	var dx: Array[float]=[box.position.x,box.position.x+edges.x,box.end.x-edges.z,box.end.x]
	var dy: Array[float]=[box.position.y,box.position.y+edges.y,box.end.y-edges.w,box.end.y]
	for y in 3:
		for x in 3:
			if not centre and x==1 and y==1: continue
			region(ink,key,Rect2(dx[x],dy[y],dx[x+1]-dx[x],dy[y+1]-dy[y]),Rect2(sx[x],sy[y],sx[x+1]-sx[x],sy[y+1]-sy[y]))
	return true

static func optic(ink: CanvasItem, aperture: Rect2) -> void:
	# The complete continuous housing, including its long engraved title rail.
	var outer:=Rect2(0,0,1600,aperture.end.y+38)
	if _nine(ink,"housing",Rect2(0,30,1672,647),Vector4(95,95,96,39),outer,Vector4(aperture.position.x,aperture.position.y,1600-aperture.end.x,38),false): return
	bezel(ink,aperture,28)
	plate(ink,Rect2(0,0,1600,aperture.position.y-28))

static func mount(ink: CanvasItem, box: Rect2, scale: float=1.0) -> void:
	var outer:=Rect2(box.position-Vector2(14,42),box.size+Vector2(28,55))
	if _nine(ink,"housing",Rect2(94,674,339,196),Vector4(40,39,40,17),outer,Vector4(36,42,36,13),false): return
	plate(ink,outer,scale)
	bezel(ink,box,6,scale)

static func side_rail(ink: CanvasItem, box: Rect2) -> void:
	_nine(ink,"housing",Rect2(0,706,63,164),Vector4(12,44,12,44),box,Vector4(9,35,9,35))

static func footer(ink: CanvasItem, id: int) -> void:
	var key: String="cupola" if id==3 else "driver" if id==4 else "housing"
	var crop:=Rect2(0,894,1672,47) if id in [3,4] else Rect2(0,875,1672,66)
	if not region(ink,key,Rect2(0,851,1600,49),crop): plate(ink,Rect2(0,851,1600,49))

static func plate(ink: CanvasItem, box: Rect2, scale: float=1.0) -> void:
	if _nine(ink,"housing",Rect2(136,48,1389,47),Vector4(10,8,10,8),box,Vector4(7,5,7,5)): return
	var stroke:=maxf(1.0,1.0/maxf(scale,0.01))
	ink.draw_rect(box,ENAMEL)
	ink.draw_rect(box.grow(-stroke),SHADOW,false,stroke,true)
	ink.draw_line(box.position+Vector2(2,2),Vector2(box.end.x-2,box.position.y+2),EDGE,stroke,true)
	ink.draw_line(Vector2(box.position.x+2,box.end.y-2),box.end-Vector2(2,2),Color("080d09"),stroke*2,true)

static func fastener(ink: CanvasItem, at: Vector2, radius: float=4.0) -> void:
	if region(ink,"housing",Rect2(at-Vector2.ONE*(radius+2),Vector2.ONE*(radius+2)*2),Rect2(42,61,30,31)): return
	ink.draw_circle(at+Vector2(0,1),radius+1,Color("080c09"))
	ink.draw_circle(at,radius,Color("68705d"))
	ink.draw_circle(at+Vector2(0,0.6),radius-1,Color("252d23"))
	ink.draw_line(at-Vector2(radius*0.5,0),at+Vector2(radius*0.5,0),Color("0a100c"),1.4,true)

static func bezel(ink: CanvasItem, aperture: Rect2, width: float=12.0, scale: float=1.0) -> void:
	var outer:=aperture.grow(width)
	if _nine(ink,"housing",Rect2(64,96,1545,570),Vector4(31,29,32,28),outer,Vector4.ONE*width,false): return
	# Square inner corners preserve every source pixel even without the art bank.
	for step in range(maxi(4,roundi(width)),0,-1):
		var depth:=float(step)/maxf(4,width)
		var colour:=ENAMEL.lerp(EDGE,(1.0-depth)*2.0) if depth>0.78 else RUBBER
		ink.draw_rect(aperture.grow(width*depth+1.0/maxf(scale,0.01)),colour,false,1.3,false)

static func recess(ink: CanvasItem, box: Rect2, scale: float=1.0) -> void:
	if _nine(ink,"housing",Rect2(105,709,312,147),Vector4(7,7,7,7),box,Vector4.ONE*minf(5,box.size.y*0.12)): return
	var stroke:=maxf(1.0,1.0/maxf(scale,0.01))
	ink.draw_rect(box,FACE)
	ink.draw_rect(box.grow(-stroke),Color("3d4938"),false,stroke,true)
	ink.draw_line(box.position+Vector2(2,2),Vector2(box.end.x-2,box.position.y+2),Color("050b08"),stroke*2,true)
