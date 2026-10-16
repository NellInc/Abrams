extends Control
## Every pose and credit comes from a complete PC frame. The one authored motion,
## the shot (Nell, 16 October 2026: "the animation of the tank shot is missing"),
## is timed by the original frame sequence, never by a wall clock or input.
const CATALOG_SHA := "302bf7dae0d9aa7605aaf3b849074f986ea7212bb3d9ec29bb09956b505f437f"
const Geometry = preload("res://scripts/pc_information_art.gd")
const Typography = preload("res://scripts/pc_typography.gd")
const Outlines = preload("res://scripts/pc_outline_fonts.gd")
const DEDICATION_RECT := Rect2(8,164,164,30)
const DEDICATION_LINES := [
	["Dedicated to the memory of","6X6.FNT",Vector2(12,168),Color8(170,170,170)],
	["David \"Ming\" Kenny","8X8.FNT",Vector2(18,180),Color.WHITE]
]
var catalog: Dictionary = {}
var textures: Dictionary = {}
var frames: Dictionary = {}
var overlays: Dictionary = {}
var active: Dictionary = {}
var dedication := []
var outline_fonts = Outlines.new()
var outline_text_enabled := true
# Original frame sequence of the sample being presented; -1 keeps the static,
# PC-pose-only composition (pixel oracles, comparison tools).
var source_frame := -1
var shot_start := -1
# PC frames from the first flash at which each original pose appears.
const PC_POSE_AT := [0,1,4,7]
# The same four poses at the Genesis cadence (its frames 238/243/248/254 at 60 Hz),
# in PC frames at 70 Hz. After the last pose the fireball billows, dims to smoke and
# clears before the first credit (about 110 PC frames after the first flash), as the
# Genesis does.
const SHOT_POSE_AT := [0,6,12,19]
const SHOT_CLEAR := 104
var glow := TextureRect.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)
	# Muzzle light, added over the title for the first few frames of the shot.
	var gradient := Gradient.new()
	gradient.set_color(0,Color(1,0.86,0.6,1)); gradient.set_color(1,Color(1,0.5,0.15,0))
	var texture := GradientTexture2D.new()
	texture.gradient=gradient; texture.fill=GradientTexture2D.FILL_RADIAL
	texture.fill_from=Vector2(0.5,0.5); texture.fill_to=Vector2(1,0.5); texture.width=256; texture.height=256
	glow.texture=texture
	glow.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	glow.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var additive := CanvasItemMaterial.new(); additive.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD
	glow.material=additive
	add_child(glow)
	clear()

func clear() -> void:
	active.clear()
	visible = false
	glow.visible = false
	queue_redraw()

## The authored shot at f original frames after the first flash. Pure, so the
## same frame always presents identically.
static func shot_state(f: int) -> Dictionary:
	var state := {"pose":3,"next":3,"blend":0.0,"billow":0.0,"smoke":0.0,"alpha":1.0,"glow":0.0,"shake":0.0}
	for k in 3:
		if f < SHOT_POSE_AT[k+1]:
			state.pose=k; state.next=k+1
			state.blend=smoothstep(0.0,1.0,float(f-SHOT_POSE_AT[k])/float(SHOT_POSE_AT[k+1]-SHOT_POSE_AT[k]))
			break
	var after := float(maxi(f-SHOT_POSE_AT[3],0))
	state.billow=smoothstep(0.0,1.0,after/85.0)
	state.smoke=smoothstep(0.0,1.0,clampf((after-4.0)/36.0,0.0,1.0))
	# Soot first, then it thins away: opaque until the smoke has formed.
	state.alpha=1.0-smoothstep(0.0,1.0,clampf((float(f)-56.0)/float(SHOT_CLEAR-56),0.0,1.0))
	state.glow=0.0 if f>=16 else 0.9*pow(1.0-f/16.0,2.0)
	state.shake=0.0 if f>=12 else 1.6*(1.0-f/12.0)
	return state

func load_sources(root_path: String) -> bool:
	clear(); catalog.clear(); textures.clear(); frames.clear(); overlays.clear(); dedication.clear()
	var path := root_path.path_join("local-art/pc-intro-v2/intro.json")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=CATALOG_SHA: return false
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for name in data.sources:
		path=root_path.path_join("GAME/"+name)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=data.sources[name]: return false
	var loaded := {}
	for name in data.assets:
		var asset: Dictionary=data.assets[name]
		path=root_path.path_join("local-art/genesis/remastered/"+asset.path)
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=asset.sha256: return false
		var image := Image.load_from_file(path)
		if image==null or image.get_size()!=Vector2i(asset.size[0],asset.size[1]): return false
		loaded[name]=ImageTexture.create_from_image(image)
		if name=="flash":
			# Grey smoke for the shot's tail: the same billow shapes, desaturated and dimmed.
			var smoke := image.duplicate() as Image
			smoke.adjust_bcs(0.62,0.8,0.0)
			loaded.smoke=ImageTexture.create_from_image(smoke)
	var memorial := []
	for line in DEDICATION_LINES:
		path=root_path.path_join("GAME/"+line[1])
		if not FileAccess.file_exists(path) or FileAccess.get_sha256(path)!=Typography.FONT_SOURCES[line[1]]: return false
		var font:=FileAccess.get_file_as_bytes(path)
		var mesh:=Typography.RunLabel.make_mesh({"text":line[0],"cell_size":Vector2(font[0],font[1]),"glyphs":Typography.glyph_geometry(font)})
		memorial.append({"mesh":mesh,"position":line[2],"colour":line[3]})
	for entry in data.entries:
		frames[entry.rgb_sha256]=entry
		var items := []
		for overlay in entry.overlays:
			items.append({"mesh":Geometry.span_mesh(overlay.rects),"colour":Color8(overlay.rgb[0],overlay.rgb[1],overlay.rgb[2])})
		overlays[entry.name]=items
	outline_fonts.load_sources(root_path)
	catalog=data; textures=loaded; dedication=memorial
	return true

func set_frame(source: Image, program: Dictionary) -> bool:
	clear()
	if catalog.is_empty() or program.get("name")!="START": return false
	if source==null or source.get_size()!=Vector2i(320,200) or source.get_format()!=Image.FORMAT_RGB8: return false
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256);hash.update(source.get_data())
	var fingerprint := hash.finish().hex_encode()
	if not frames.has(fingerprint): return false
	active=frames[fingerprint].duplicate(true)
	active.dedication=active.name=="credit-8"
	if int(active.flash)==0 or source_frame<0: shot_start=-1
	elif shot_start<0 or source_frame<shot_start:
		# First pose seen, or the timeline moved back (a state load). Fast-forward can
		# skip early poses; credits seen first mean the shot is already over.
		var index:=["flash-1","flash-2","flash-3","flash-4"].find(str(active.name))
		shot_start=source_frame-(PC_POSE_AT[index] if index>=0 else SHOT_CLEAR)
	visible=true
	queue_redraw()
	return true

static func rect(value: Array) -> Rect2:
	return Rect2(value[0],value[1],value[2],value[3])

func _draw() -> void:
	if active.is_empty(): return
	var factor:=size/Vector2(320,200)
	draw_set_transform(Vector2.ZERO,0,factor)
	glow.visible=false
	if int(active.flash)>0 and shot_start>=0:
		_draw_shot(factor,shot_state(source_frame-shot_start))
	else:
		draw_texture_rect(textures.title,Rect2(0,0,320,200),false)
		if int(active.flash)>0:
			var flash: Dictionary=catalog.flashes[int(active.flash)-1]
			draw_texture_rect_region(textures.flash,rect(flash.rect),rect(flash.source_rect))
	draw_set_transform(Vector2.ZERO,0,factor)
	for overlay in overlays[active.name]:
		draw_mesh(overlay.mesh,null,Transform2D.IDENTITY,overlay.colour)
	if outline_text_enabled:
		for run in active.text_runs:
			if not outline_fonts.names.has(run.font): continue
			var box:=rect(run.rect)
			draw_set_transform(Vector2.ZERO,0,factor)
			draw_rect(box,Color.BLACK)
			Outlines.draw_text(self,outline_fonts.names[run.font],run.text,Rect2(box.position*factor,box.size*factor),Vector2(run.cell[0],run.cell[1]),Color8(run.foreground[0],run.foreground[1],run.foreground[2]))
	# Nell's dedication accompanies the final original copyright card. It never
	# replaces an original credit or delays the PC-owned transition to the menu.
	if active.dedication:
		draw_set_transform(Vector2.ZERO,0,factor)
		draw_rect(DEDICATION_RECT,Color8(255,85,85))
		draw_rect(DEDICATION_RECT.grow(-1),Color.BLACK)
		for index in dedication.size():
			var line: Dictionary=dedication[index]
			var spec: Array=DEDICATION_LINES[index]
			if outline_text_enabled and outline_fonts.names.has(spec[1]):
				var cell:=Vector2(6,6) if spec[1]=="6X6.FNT" else Vector2(8,8)
				Outlines.draw_text(self,outline_fonts.names[spec[1]],spec[0],Rect2(line.position*factor,Vector2(spec[0].length()*cell.x,cell.y)*factor),cell,line.colour)
			else:
				draw_set_transform(Vector2.ZERO,0,factor)
				draw_mesh(line.mesh,null,Transform2D(0,line.position),line.colour)

func _draw_shot(factor: Vector2, state: Dictionary) -> void:
	var f:=source_frame-shot_start
	# A short recoil shake, drawn slightly enlarged so no edge shows.
	var offset:=Vector2(sin(f*2.7),cos(f*3.3)*0.6)*float(state.shake)
	var zoom:=1.0+0.012*float(state.shake)/1.6
	draw_set_transform(offset*factor-Vector2(160,100)*(zoom-1.0)*factor,0,factor*zoom)
	draw_texture_rect(textures.title,Rect2(0,0,320,200),false)
	if float(state.alpha)<=0.0: return
	var a: Rect2=rect(catalog.flashes[int(state.pose)].rect)
	var b: Rect2=rect(catalog.flashes[int(state.next)].rect)
	var box:=Rect2(a.position.lerp(b.position,float(state.blend)),a.size.lerp(b.size,float(state.blend)))
	# Billow outward from the muzzle (the poses' left middle) and rise a little.
	var grow:=1.0+0.22*float(state.billow)
	var anchor:=Vector2(box.position.x,box.position.y+box.size.y*0.5)
	box=Rect2(anchor+(box.position-anchor)*grow-Vector2(0,10.0*float(state.billow)),box.size*grow)
	var alpha:=float(state.alpha)
	var smoke:=float(state.smoke)
	var source:=rect(catalog.flashes[int(state.pose)].source_rect)
	# Fire cross-fades into smoke of the same shape, which then thins away.
	if smoke>0.0: draw_texture_rect_region(textures.smoke,box,source,Color(1,1,1,alpha))
	if smoke<1.0: draw_texture_rect_region(textures.flash,box,source,Color(1,1,1,alpha*(1.0-smoke)))
	if int(state.next)!=int(state.pose):
		draw_texture_rect_region(textures.flash,box,rect(catalog.flashes[int(state.next)].source_rect),Color(1,1,1,alpha*float(state.blend)))
	if float(state.glow)>0.0:
		var first: Rect2=rect(catalog.flashes[0].rect)
		var muzzle:=Vector2(first.position.x,first.position.y+first.size.y*0.5)
		glow.position=(muzzle-Vector2(72,72))*factor
		glow.size=Vector2(144,144)*factor
		glow.modulate=Color(1,1,1,float(state.glow))
		glow.visible=true
