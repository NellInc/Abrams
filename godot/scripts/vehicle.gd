extends Node3D
## Original authored procedural M1A1 presentation model, built to published M1A1 proportions
## (7.9 m hull, 3.66 m over skirts, 2.44 m to the turret roof). Never participates in simulation.
## Geometry is batched per frame and material, so a vehicle costs a few draw calls.

var turret_root: Node3D
var barrel: Node3D
var paint: ShaderMaterial
var turret_paint: ShaderMaterial
var bustle_paint: ShaderMaterial
var fender_paint: ShaderMaterial
var dark: ShaderMaterial
var metal: StandardMaterial3D
var crew: Node3D
var recoil := 0.0
var _batches: Dictionary = {}

# Hull roof, and the turret ring plane raised on its bearing above it. From the low box-cover
# camera the roof sits just below the nose line, so only the dark ring gap shows.
const DECK := 1.3
const RING_Y := 1.4
const RING_Z := -0.1
# Where the gun leaves the mantlet, in the turret frame.
const GUN_ROOT := Vector3(0,0.74,-1.67)
# Front plane of the fenders and nose.
const NOSE := -3.86
# Outward splay of the front skirt plates.
const FLARE := 0.3

# Box-cover finish: a single coat of worn olive drab under heavy field dust, grime and
# rain streaks. Weathering lives in the hull (or turret) frame through to_local, so it rides
# with the vehicle instead of swimming across it as the tank moves.
const PAINT_SHADER := """shader_type spatial;
uniform mat4 to_local;
uniform float height_offset = 0.0;
uniform vec3 base_color : source_color = vec3(0.30,0.29,0.21);
uniform vec3 grime : source_color = vec3(0.10,0.09,0.07);
uniform vec3 dust : source_color = vec3(0.41,0.37,0.30);
uniform vec3 mud : source_color = vec3(0.17,0.13,0.1);
uniform float dust_reach = 1.4;
uniform float dust_amount = 1.0;
varying vec3 lp;
varying vec3 ln;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*0.6+noise(p*2.1+7.3)*0.28+noise(p*4.3-3.1)*0.12;}
void vertex(){
 lp=(to_local*(MODEL_MATRIX*vec4(VERTEX,1.0))).xyz;
 ln=normalize((to_local*(MODEL_MATRIX*vec4(NORMAL,0.0))).xyz);
}
void fragment(){
 vec3 colour=base_color;
 // Sun-faded and touched-up panels mottled with grime, projected onto each face's own
 // plane, then fine paint grain on every face orientation.
 vec3 w=abs(ln);
 float mott=(fbm(lp.zy*1.8+3.0)*w.x+fbm(lp.xy*1.8+7.0)*w.z+fbm(lp.xz*1.8)*w.y)/(w.x+w.y+w.z);
 colour*=0.72+0.5*mott;
 float grit=(noise(lp.zy*55.0)*w.x+noise(lp.xy*55.0+3.0)*w.z+noise(lp.xz*55.0)*w.y)/(w.x+w.y+w.z);
 colour*=0.95+0.1*grit;
 // Spattered mud flecks and dried dust specks, as on the cover's armour.
 float fleck=(noise(lp.zy*90.0)*w.x+noise(lp.xy*90.0+7.0)*w.z+noise(lp.xz*90.0+1.0)*w.y)/(w.x+w.y+w.z);
 float speck=(noise(lp.zy*70.0+3.0)*w.x+noise(lp.xy*70.0+9.0)*w.z+noise(lp.xz*70.0+5.0)*w.y)/(w.x+w.y+w.z);
 colour=mix(colour,mud*0.6,smoothstep(0.92,0.97,fleck)*0.45);
 colour=mix(colour,dust*1.3,smoothstep(0.95,0.99,speck)*0.35);
 colour*=0.95+0.05*noise(lp.xy*26.0)+0.05*noise(lp.zy*26.0+5.0)-0.05*noise(lp.xz*26.0);
 // Oily grime and rain streaks running down the flanks.
 float streak=smoothstep(0.55,0.95,noise(vec2(lp.x*6.0+lp.z*4.5,lp.y*0.7)));
 colour=mix(colour,grime,streak*0.15*(1.0-abs(ln.y)));
 colour=mix(colour,grime,smoothstep(0.62,0.8,fbm(lp.xz*3.1-lp.y*1.4))*0.3);
 // Faces turned to the ground sit in the hull's own shadow.
 colour*=mix(0.55,1.0,smoothstep(-0.6,0.2,ln.y));
 // Road dust kicked up from the tracks: caked low on the hull, settled on upward faces.
 float height=lp.y+height_offset;
 float caked=(1.0-smoothstep(0.0,dust_reach,height))*(0.45+0.45*fbm(lp.xz*2.4+lp.y*3.0));
 float settled=smoothstep(0.55,0.95,ln.y)*0.25*fbm(lp.xz*1.3);
 float film=0.14*fbm(lp.xz*3.4-lp.y*2.0)+0.1*smoothstep(0.4,0.9,fbm(lp.xz*0.6));
 // Wet mud cakes the lowest plates; dry dust settles on top faces and films the rest.
 colour=mix(colour,mud,clamp(caked*dust_amount,0.0,0.85));
 colour=mix(colour,dust,clamp((settled+film)*dust_amount,0.0,0.6));
 ALBEDO=colour;
 // Hammered, pitted armour: jitter the shading normal with fine noise in the vehicle's frame.
 vec3 bump=vec3(noise(lp.zy*24.0)-0.5,noise(lp.xz*24.0+2.0)-0.5,noise(lp.xy*24.0+4.0)-0.5);
 // to_local is rigid, so its transposed rotation carries vehicle-frame directions to world.
 NORMAL=normalize(NORMAL+mat3(VIEW_MATRIX)*(transpose(mat3(to_local))*(bump*0.35)));
 ROUGHNESS=0.8+0.16*caked;
 SPECULAR=0.3;
 RIM=0.08;
 RIM_TINT=0.7;
}"""

func paint_material(base: Color, offset := 0.0, dust_reach := 1.4, dust_amount := 1.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = PAINT_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("base_color",base)
	m.set_shader_parameter("height_offset",offset)
	m.set_shader_parameter("dust_reach",dust_reach)
	m.set_shader_parameter("dust_amount",dust_amount)
	return m

func _process(_delta: float) -> void:
	# Keep the weathering anchored to the hull and turret frames (five uniforms per vehicle).
	var hull_inverse := global_transform.affine_inverse()
	paint.set_shader_parameter("to_local",Projection(hull_inverse))
	dark.set_shader_parameter("to_local",Projection(hull_inverse))
	fender_paint.set_shader_parameter("to_local",Projection(hull_inverse))
	var turret_inverse := Projection(turret_root.global_transform.affine_inverse())
	turret_paint.set_shader_parameter("to_local",turret_inverse)
	bustle_paint.set_shader_parameter("to_local",turret_inverse)

func material(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

# ---- Batched geometry -------------------------------------------------------------------

func _batch(frame: Node3D, mat: Material, tag := "") -> SurfaceTool:
	# Faceted custom geometry carries no UVs, so it batches apart from primitive meshes.
	var key := "%d:%d:%s" % [frame.get_instance_id(), mat.get_instance_id(), tag]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = {"st":st,"frame":frame,"mat":mat}
	return _batches[key].st

func _add(frame: Node3D, mesh: Mesh, xform: Transform3D, mat: Material, tag := "") -> void:
	_batch(frame,mat,tag).append_from(mesh,0,xform)

func _commit() -> void:
	for entry in _batches.values():
		var node := MeshInstance3D.new()
		node.mesh = entry.st.commit()
		node.material_override = entry.mat
		entry.frame.add_child(node)
	_batches.clear()

func box(frame: Node3D, size: Vector3, at: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(frame,mesh,Transform3D(Basis.from_euler(rot),at),mat)

func cylinder(frame: Node3D, radius: float, height: float, at: Vector3, mat: Material, rot := Vector3.ZERO, segments := 16, top := -1.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top < 0.0 else top
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	_add(frame,mesh,Transform3D(Basis.from_euler(rot),at),mat)

func sphere(frame: Node3D, radius: float, scale_by: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_add(frame,mesh,Transform3D(Basis().scaled(scale_by),at),mat)

# Flat-shaded solid between a bottom and a top ring of points (same count, same order).
func loft(frame: Node3D, bottom: Array, top: Array, mat: Material, xform := Transform3D()) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := bottom.size()
	var centre_b := Vector3.ZERO
	var centre_t := Vector3.ZERO
	for i in range(n):
		centre_b += bottom[i]
		centre_t += top[i]
	centre_b /= n
	centre_t /= n
	for i in range(n):
		var j := (i+1)%n
		_quad(st,bottom[i],bottom[j],top[j],top[i],(bottom[i]+bottom[j])*0.5-centre_b)
		_tri(st,centre_t,top[i],top[j],Vector3.UP)
		_tri(st,centre_b,bottom[j],bottom[i],Vector3.DOWN)
	st.generate_normals()
	_add(frame,st.commit(),xform,mat,"facet")

# Side-profile polygon in (z, y) extruded across x from x0 to x1.
func extrude_x(frame: Node3D, profile: Array, x0: float, x1: float, mat: Material) -> void:
	var bottom: Array = []
	var top: Array = []
	for p in profile:
		bottom.append(Vector3(x0,p.y,p.x))
		top.append(Vector3(x1,p.y,p.x))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n := profile.size()
	var centre := Vector3.ZERO
	for p in bottom:
		centre += p
	centre /= n
	for i in range(n):
		var j := (i+1)%n
		var mid: Vector3 = (bottom[i]+bottom[j])*0.5
		_quad(st,bottom[i],bottom[j],top[j],top[i],Vector3(0,mid.y-centre.y,mid.z-centre.z))
		_tri(st,Vector3(x0,centre.y,centre.z),bottom[j],bottom[i],Vector3.LEFT)
		_tri(st,Vector3(x1,centre.y,centre.z),top[i],top[j],Vector3.RIGHT)
	st.generate_normals()
	_add(frame,st.commit(),Transform3D(),mat,"facet")

# Emit a triangle facing the intended outward direction. Godot front faces wind clockwise
# seen from outside, so the counter-clockwise normal (b-a)x(c-a) must point inward.
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var normal := (b-a).cross(c-a)
	if normal.dot(outward) < 0.0:
		for v in [a,b,c]:
			st.add_vertex(v)
	else:
		for v in [a,c,b]:
			st.add_vertex(v)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(st,a,b,c,outward)
	_tri(st,a,c,d,outward)

# ---- Model -------------------------------------------------------------------------------

func _ready() -> void:
	paint = paint_material(Color("4a483c"),0.0,1.2,0.4)
	# Fenders and front skirts wear the thickest coat of pale road dust.
	fender_paint = paint_material(Color("6b6352"),0.0,1.5,0.7)
	turret_paint = paint_material(Color("4a483c"),RING_Y,1.2,0.15)
	# Running gear: dark rubber and steel under the heaviest coat of road dust.
	dark = paint_material(Color("1f1e1a"),0.0,1.5,0.55)
	metal = material(Color("1d1e1b"),0.55,0.5)
	var rubber := material(Color("151513"),0.95)
	var glass := material(Color("1d2422"),0.12,0.8)
	var lamp := material(Color("ff9a3a"),0.3)
	lamp.emission_enabled = true
	lamp.emission = Color("c84a08")
	lamp.emission_energy_multiplier = 2.6
	_hull(rubber,lamp)
	turret_root = Node3D.new()
	turret_root.name = "Turret"
	add_child(turret_root)
	turret_root.position = Vector3(0,RING_Y,RING_Z)
	barrel = Node3D.new()
	turret_root.add_child(barrel)
	barrel.position = GUN_ROOT
	_turret(rubber,glass)
	_gun(rubber)
	crew = Node3D.new()
	crew.visible = false
	turret_root.add_child(crew)
	_crew()
	_commit()

func _hull(rubber: Material, lamp: Material) -> void:
	# Main hull between the tracks: rear plate, long deck, almost flat upper glacis ending
	# in a shallow nose lip, then the lower glacis raking back under the nose to the belly.
	var body := [Vector2(3.9,0.5),Vector2(3.95,1.2),Vector2(3.88,DECK),Vector2(-2.2,DECK),
		Vector2(-3.8,1.34),Vector2(NOSE+0.02,1.2),Vector2(-3.3,0.95),Vector2(-3.0,0.48),Vector2(3.7,0.48)]
	extrude_x(self,body,-1.1,1.1,paint)
	# Upper glacis caked dark with wet earth thrown up by the tracks.
	extrude_x(self,[Vector2(-2.2,DECK+0.01),Vector2(-3.8,1.35),Vector2(-3.8,1.33),Vector2(-2.2,DECK-0.01)],-1.08,1.08,dark)
	# Lower glacis: a mud-blackened plate raking back under the nose lip.
	extrude_x(self,[Vector2(NOSE+0.02,1.2),Vector2(-3.35,0.62),Vector2(-3.0,0.48),Vector2(-3.3,0.95)],-1.1,1.1,material(Color("2a231e"),0.95))
	# Rounded, dust-coated nose lip between the headlights, which catches the key light as a
	# bright band across the cover's hull front.
	cylinder(self,0.075,2.2,Vector3(0,1.235,NOSE+0.05),fender_paint,Vector3(0,0,PI/2),14)
	for side in [-1.0,1.0]:
		# Sponson and front fender over each track: a square-faced fender whose lower band
		# rakes back below a seam, carried the full length of the hull.
		# The fender top falls slightly toward the rear, so from the low cover camera only its
		# rolled front edge catches the light.
		var fender := [Vector2(NOSE+0.09,1.36),Vector2(NOSE,1.28),Vector2(NOSE,1.13),Vector2(NOSE+0.07,0.97),
			Vector2(3.92,0.97),Vector2(3.92,1.14),Vector2(3.8,1.18),Vector2(-2.6,1.33)]
		extrude_x(self,fender,minf(1.1*side,1.76*side),maxf(1.1*side,1.76*side),fender_paint)
		box(self,Vector3(0.66,0.012,0.012),Vector3(1.43*side,1.13,NOSE-0.004),dark)
		_running_gear(side,rubber)
		_skirts(side)
		_headlight(side,lamp)
		# Rear grille louvre per side.
		box(self,Vector3(0.95,0.6,0.05),Vector3(0.62*side,0.92,3.95),dark)
		# Fender stowage boxes behind the turret.
		box(self,Vector3(0.5,0.2,1.1),Vector3(1.45*side,1.2,2.7),paint)
	# Driver's hatch and periscopes at the front centre of the deck.
	cylinder(self,0.34,0.06,Vector3(0,DECK+0.02,-2.45),paint,Vector3.ZERO,16)
	for px in [-0.22,0.0,0.22]:
		box(self,Vector3(0.14,0.07,0.06),Vector3(px,DECK+0.05,-2.78),dark)
	# Engine deck: grille doors and the exhaust louvre.
	for i in range(9):
		box(self,Vector3(2.0,0.03,0.07),Vector3(0,DECK+0.015,1.6+i*0.24),dark)
	box(self,Vector3(2.2,0.28,0.08),Vector3(0,1.22,3.96),metal)

func _headlight(side: float, lamp: Material) -> void:
	# Armoured headlight cluster on the glacis, tucked against the inside of each fender:
	# a dark housing, one amber lamp, a sloped hood and a bar guard.
	# The cover shows the right-hand cluster set further outboard than the left one.
	var lx: float = 0.885*side+(0.07 if side > 0.0 else 0.0)
	box(self,Vector3(0.35,0.15,0.3),Vector3(lx,1.24,-3.72),dark)
	sphere(self,0.048,Vector3(1,1,0.5),Vector3(lx-0.02*side,1.26,NOSE-0.01),lamp)
	box(self,Vector3(0.17,0.1,0.22),Vector3(lx+0.06*side,1.37,-3.74),dark,Vector3(-0.35,0,0))
	box(self,Vector3(0.4,0.022,0.022),Vector3(lx,1.325,NOSE-0.04),metal)
	for gx in [-0.19,0.19]:
		box(self,Vector3(0.022,0.17,0.022),Vector3(lx+gx,1.24,NOSE-0.04),metal)
	box(self,Vector3(0.4,0.022,0.022),Vector3(lx,1.16,NOSE-0.04),metal)

func _running_gear(side: float, rubber: Material) -> void:
	# Mud-caked steel shoes and grey-violet rubber pads, which the cover shows catching the
	# dust light under the fenders.
	var track := material(Color("3a3431"),0.95)
	var pad := material(Color("4b4450"),0.85)
	var x: float = 1.45*side
	# Seven dual road wheels, front idler, rear drive sprocket and two return rollers.
	for i in range(7):
		var z := -2.55+i*0.82
		for half in [-0.15,0.15]:
			cylinder(self,0.32,0.13,Vector3(x+half,0.4,z),dark,Vector3(0,0,PI/2),18)
			cylinder(self,0.14,0.14,Vector3(x+half,0.4,z),metal,Vector3(0,0,PI/2),10)
		box(self,Vector3(0.34,0.12,0.55),Vector3(x,0.6,z+0.2),dark,Vector3(-0.35,0,0))
	for half in [-0.15,0.15]:
		cylinder(self,0.31,0.13,Vector3(x+half,0.55,-3.3),dark,Vector3(0,0,PI/2),18)
		cylinder(self,0.36,0.11,Vector3(x+half,0.56,3.5),metal,Vector3(0,0,PI/2),18)
	for t in range(12):
		var angle := TAU*t/12.0
		box(self,Vector3(0.36,0.09,0.09),Vector3(x,0.56+sin(angle)*0.39,3.5+cos(angle)*0.39),dark,Vector3(angle,0,0))
	for z in [-1.3,1.0]:
		cylinder(self,0.1,0.3,Vector3(x,0.8,z),dark,Vector3(0,0,PI/2),10)
	# Track: shoes along the ground run, up and over the idler and sprocket, and the top run.
	var path: Array = []
	path.append_array(_track_line(Vector2(-2.9,0.07),Vector2(2.9,0.07),15))
	path.append_array(_track_line(Vector2(2.9,0.07),Vector2(3.72,0.44),3))
	path.append_array(_track_arc(Vector2(3.5,0.56),0.42,-0.75,1.75,5))
	path.append_array(_track_line(Vector2(3.3,0.96),Vector2(-3.1,0.92),16))
	path.append_array(_track_arc(Vector2(-3.3,0.55),0.39,1.75,4.2,6))
	path.append_array(_track_line(Vector2(-3.55,0.38),Vector2(-2.9,0.07),3))
	for shoe in path:
		var pitch: float = shoe.pitch
		var p: Vector2 = shoe.p
		var n: Vector2 = shoe.n
		box(self,Vector3(0.64,0.07,0.36),Vector3(x,p.y,p.x),track,Vector3(pitch,0,0))
		# Rubber pads, two per shoe, standing proud of the mud-caked shoe.
		for px in [-0.17,0.17]:
			box(self,Vector3(0.24,0.06,0.26),Vector3(x+px,p.y+n.y*0.055,p.x+n.x*0.055),pad,Vector3(pitch,0,0))
		# Steel grouser on the outer face of every shoe.
		box(self,Vector3(0.66,0.035,0.06),Vector3(x,p.y+n.y*0.045,p.x+n.x*0.045),metal,Vector3(pitch,0,0))

# Track shoes as {p: (z, y) centre, pitch: rotation about x, n: outward normal in (z, y)}.
# A box's long axis (+z) pitched by atan2(-dy, dz) follows the direction (dz, dy).
const TRACK_CENTRE := Vector2(0.0,0.55)

func _track_line(a: Vector2, b: Vector2, count: int) -> Array:
	var shoes: Array = []
	var d := (b-a).normalized()
	var n := Vector2(-d.y,d.x)
	var mid := (a+b)*0.5
	if n.dot(mid-TRACK_CENTRE) < 0.0:
		n = -n
	for i in range(count):
		shoes.append({"p":a.lerp(b,(i+0.5)/count),"pitch":atan2(-d.y,d.x),"n":n})
	return shoes

func _track_arc(centre: Vector2, radius: float, from: float, to: float, count: int) -> Array:
	var shoes: Array = []
	for i in range(count):
		var t := from+(to-from)*(i+0.5)/count
		var n := Vector2(cos(t),sin(t))
		shoes.append({"p":centre+n*radius,"pitch":atan2(-n.x,-n.y),"n":n})
	return shoes

func _skirts(side: float) -> void:
	var x: float = 1.8*side
	# Heavy front skirt plate hinged at the fender's outer edge and splayed out, as on the box
	# cover, with a rolled top lip and a raked lower edge; then ballistic panels butted with
	# dark seams and bolted along the top.
	var flare := Node3D.new()
	add_child(flare)
	flare.transform = Transform3D(Basis(Vector3.UP,FLARE*side),Vector3(1.83*side,0,NOSE))
	var plate := [Vector2(0,1.34),Vector2(0,1.12),Vector2(0.08,0.72),Vector2(1.35,0.5),Vector2(1.35,1.27)]
	extrude_x(flare,plate,minf(0.0,-0.06*side),maxf(0.0,-0.06*side),paint)
	cylinder(flare,0.035,1.35,Vector3(-0.02*side,1.3,0.675),fender_paint,Vector3(PI/2,0,0),8)
	var flare_end := 1.83+1.35*sin(FLARE)
	box(self,Vector3(flare_end-1.78,0.62,0.05),Vector3((flare_end+1.78)*0.5*side,0.97,NOSE+1.35*cos(FLARE)),fender_paint)
	for i in range(6):
		var z0 := -2.55+i*1.05
		box(self,Vector3(0.05,0.64,1.03),Vector3(x,0.92,z0+0.52),paint)
		box(self,Vector3(0.055,0.64,0.02),Vector3(x,0.92,z0+1.04),dark)
		for bz in [0.15,0.5,0.85]:
			cylinder(self,0.022,0.03,Vector3(x+0.03*side,1.18,z0+bz),metal,Vector3(0,0,PI/2),6)
	box(self,Vector3(0.08,0.05,6.3),Vector3(x,1.25,0.6),paint)

func _turret(rubber: Material, glass: Material) -> void:
	var t := turret_root
	bustle_paint = paint_material(Color("24231d"),RING_Y,1.2,0.15)
	# Side profile (z, y) of the M1 cheeks and slab sides: the roof edge, the armour nose
	# jutting ahead of it, the deep undercut, the flat skirt line and the raked rear edge
	# where the bustle box begins.
	var cheek := [Vector2(-2.36,0.75),Vector2(-2.4,0.37),Vector2(-1.92,0.15),Vector2(-0.3,0.13),
		Vector2(0.3,0.17),Vector2(0.3,0.3),Vector2(-0.02,0.78)]
	extrude_x(t,cheek,0.55,1.7,turret_paint)
	extrude_x(t,cheek,-1.7,-0.55,turret_paint)
	# Worn, dust-polished roof edge along each slab side, which catches the light on the cover.
	var edge_paint := material(Color("625b4a"),0.7)
	for side in [-1.0,1.0]:
		box(t,Vector3(0.05,0.04,2.21),Vector3(side*1.69,0.765,-1.12),edge_paint,Vector3(0.0136,0,0))
	# Centre section, recessed behind the cheeks so the mantlet sits in a slot.
	var centre := [Vector2(-1.55,0.76),Vector2(-1.55,0.2),Vector2(-0.3,0.13),Vector2(0.3,0.17),Vector2(0.3,0.78)]
	extrude_x(t,centre,-0.55,0.55,turret_paint)
	# Gun shield across the slot.
	box(t,Vector3(1.0,0.5,0.24),Vector3(0,0.53,-1.62),dark)
	box(t,Vector3(0.6,0.36,0.08),Vector3(0,0.59,-1.76),turret_paint)
	# Turret ring skirt in the shadowed gap between the turret floor and the deck.
	cylinder(t,1.15,0.34,Vector3(0,-0.02,-0.1),dark,Vector3.ZERO,24)
	# Bustle: the stowage box behind the slab sides, its side bins flush with the armour.
	box(t,Vector3(3.24,0.66,1.62),Vector3(0,0.53,0.72),bustle_paint)
	# The deep shadowed well under the bustle overhang, which reads as one dark band below the
	# turret side on the cover rather than showing sky through to the far side.
	box(t,Vector3(3.1,0.34,1.5),Vector3(0,0.03,0.72),dark)
	# The bustle's lower skirt flares out below the rear of the side bins in a sloped,
	# dust-lit plate; ahead of it the side stays in shadow.
	for side in [-1.0,1.0]:
		var inner: float = 1.62*side
		var outer: float = 1.74*side
		loft(t,[Vector3(inner,0.2,0.7),Vector3(inner,0.2,1.53),Vector3(outer,-0.05,1.53),Vector3(outer,-0.05,0.7)],[Vector3(inner,0.22,0.7),Vector3(inner,0.22,1.53),Vector3(outer,-0.03,1.53),Vector3(outer,-0.03,0.7)],turret_paint)
	box(t,Vector3(3.26,0.02,1.5),Vector3(0,0.7,0.75),dark)
	# Tactical marking on the right bin, as on the box cover: two discs and a triangle.
	var ink := material(Color("b8934a"),0.8)
	for i in range(2):
		cylinder(t,0.06,0.012,Vector3(1.626,0.59,1.36-i*0.135),ink,Vector3(0,0,PI/2),14)
	_flat(t,[Vector3(1.627,0.54,1.15),Vector3(1.627,0.54,1.03),Vector3(1.627,0.645,1.09)],Vector3.RIGHT,ink)
	# Bustle rack: three rails down each side, sagging slightly toward the back as on the
	# cover, across the back, with posts at the rear.
	for y in [0.23,0.48,0.765]:
		for side in [-1.0,1.0]:
			box(t,Vector3(0.035,0.035,2.36),Vector3(side*1.78,y,0.93),metal,Vector3(0.035,0,0))
		box(t,Vector3(3.56,0.035,0.035),Vector3(0,y-0.04,2.1),metal)
	for side in [-1.0,1.0]:
		for z in [1.83,2.1]:
			box(t,Vector3(0.05,0.66,0.05),Vector3(side*1.78,0.46,z),metal)
	# Kit stowed in the rack: bedrolls and boxes.
	cylinder(t,0.17,1.3,Vector3(-0.7,0.4,1.95),material(Color("4f4a36")),Vector3(0,0,PI/2),10)
	box(t,Vector3(0.9,0.36,0.4),Vector3(0.75,0.4,1.95),material(Color("2f2e25")))
	# Gunner's primary sight "doghouse" on the right front roof.
	box(t,Vector3(0.5,0.22,0.68),Vector3(0.75,0.88,-0.94),turret_paint)
	box(t,Vector3(0.38,0.14,0.03),Vector3(0.75,0.87,-1.29),glass)
	# Commander's weapon station (right) with vision blocks, loader's hatch (left).
	cylinder(t,0.44,0.2,Vector3(0.75,0.87,0.45),turret_paint,Vector3.ZERO,18)
	# Raised weapon-station ring around the commander and his open hatch lid standing behind.
	cylinder(t,0.4,0.22,Vector3(0.75,1.08,0.45),dark,Vector3.ZERO,18)
	cylinder(t,0.36,0.06,Vector3(0.82,1.4,0.98),dark,Vector3(-1.25,0,0.25),18)
	# Bedroll and pack strapped against the lid.
	sphere(t,0.3,Vector3(1.0,1.15,0.8),Vector3(0.98,1.38,0.86),material(Color("1c1d19"),0.95))
	for i in range(6):
		var a := TAU*i/6.0+0.3
		box(t,Vector3(0.13,0.09,0.05),Vector3(0.75+cos(a)*0.43,0.91,0.45+sin(a)*0.43),glass,Vector3(0,-a+PI/2,0))
	cylinder(t,0.4,0.08,Vector3(-0.7,0.81,0.1),turret_paint,Vector3.ZERO,16)
	box(t,Vector3(0.74,0.05,0.5),Vector3(-0.7,1.02,0.52),turret_paint,Vector3(1.0,0,0))
	# Loader's M240 on its skate mount, raised.
	box(t,Vector3(0.09,0.12,0.42),Vector3(-0.95,1.06,-0.62),metal,Vector3(0.5,0,0))
	cylinder(t,0.04,0.42,Vector3(-0.95,1.19,-0.89),metal,Vector3(-1.08,0,0),8)
	cylinder(t,0.055,0.08,Vector3(-0.95,1.27,-1.04),metal,Vector3(-1.08,0,0),8)
	cylinder(t,0.028,0.26,Vector3(-0.95,0.9,-0.45),metal,Vector3.ZERO,6)
	# Antenna mount and crosswind sensor mast.
	cylinder(t,0.03,0.5,Vector3(1.0,1.02,1.42),metal,Vector3.ZERO,6)
	cylinder(t,0.025,0.5,Vector3(0,1.02,1.4),metal,Vector3.ZERO,6)
	box(t,Vector3(0.06,0.06,0.26),Vector3(0,1.27,1.4),metal)

func _gun(rubber: Material) -> void:
	var b := barrel
	# M256 120 mm as the box cover shows it: a heavy boot at the mantlet, a long tapering
	# thermal sleeve with one bore-evacuator bulge a third of the way out, a single sleeve
	# joint, and the muzzle reference sensor on top at the end. (Cylinder tops face the root.)
	var sleeve := material(Color("23241f"),0.75,0.2)
	var along := Vector3(PI/2,0,0)
	cylinder(b,0.17,0.36,Vector3(0,0,-0.18),dark,along,18,0.19)
	cylinder(b,0.115,1.04,Vector3(0,0,-0.88),sleeve,along,18,0.125)
	cylinder(b,0.15,0.06,Vector3(0,0,-1.43),sleeve,along,18,0.115)
	cylinder(b,0.15,0.36,Vector3(0,0,-1.64),sleeve,along,18)
	cylinder(b,0.105,0.08,Vector3(0,0,-1.86),sleeve,along,18,0.15)
	cylinder(b,0.086,1.73,Vector3(0,0,-2.765),sleeve,along,18,0.105)
	cylinder(b,0.098,0.03,Vector3(0,0,-2.7),dark,along,18)
	cylinder(b,0.095,0.1,Vector3(0,0,-3.67),sleeve,along,18)
	cylinder(b,0.055,0.02,Vector3(0,0,-3.72),rubber,along,14)
	box(b,Vector3(0.06,0.07,0.12),Vector3(0,0.13,-3.6),metal)

func _crew() -> void:
	var c := crew
	var shirt := material(Color("b9b7b0"),0.9)
	var vest := material(Color("1a1b18"),0.85)
	var khaki := material(Color("8c7454"),0.9)
	var helmet := material(Color("2a2b27"),0.6)
	var skin := material(Color("3a281f"),0.85)
	var lens := material(Color("0b0c0b"),0.08,0.7)
	var glove := material(Color("121210"),0.7)
	# Commander standing in the weapon station in a white shirt under a black flak vest, left arm
	# down by his side and both gloved hands on the M2's grips, facing the camera.
	_man(c,{"hip":Vector3(0.7,0.98,0.48),"sh_l":Vector3(0.87,1.45,0.6),"sh_r":Vector3(0.58,1.4,0.26),
		"el_l":Vector3(0.96,1.17,0.58),"hand_l":Vector3(0.98,1.34,0.3),"el_r":Vector3(0.52,1.24,0.02),"hand_r":Vector3(0.74,1.36,0.02),
		"head":Vector3(0.76,1.65,0.4)},Vector3(0.72,-0.05,-0.69),shirt,vest,glove,skin,helmet,lens)
	# The M2's spade grips and back plate across his chest, between his hands.
	_limb(c,Vector3(0.98,1.34,0.3),Vector3(0.74,1.36,0.02),0.03,material(Color("121311"),0.5,0.4))
	box(c,Vector3(0.1,0.14,0.08),Vector3(0.86,1.35,0.16),material(Color("121311"),0.5,0.4),Vector3(0,0.85,0))
	# Weapon-station housing at chest height ahead of him, under the gun.
	box(c,Vector3(0.62,0.3,0.42),Vector3(0.82,1.06,0.0),dark,Vector3(0,-0.5,0))
	# M2 .50 cal pointed high, with its sight box and ammunition belt.
	# Swung toward the camera so its receiver side and ammunition belt show, as on the cover.
	var gun := Transform3D(Basis(Vector3.UP,-0.35)*Basis(Vector3.RIGHT,1.38),Vector3(0.75,1.2,-0.33))
	var receiver := material(Color("121311"),0.5,0.4)
	# Receiver with its feed cover, the perforated barrel jacket, barrel and flash hider.
	_add(c,_box_mesh(Vector3(0.2,0.26,0.66)),gun.translated_local(Vector3(0,0,-0.12)),receiver)
	_add(c,_box_mesh(Vector3(0.17,0.05,0.3)),gun.translated_local(Vector3(0,0.13,-0.05)),receiver)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.048
	tube.bottom_radius = 0.048
	tube.height = 0.32
	tube.radial_segments = 10
	_add(c,tube,gun*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.55)),receiver)
	var muzzle := CylinderMesh.new()
	muzzle.top_radius = 0.022
	muzzle.bottom_radius = 0.022
	muzzle.height = 0.18
	muzzle.radial_segments = 8
	_add(c,muzzle,gun*Transform3D(Basis(Vector3.RIGHT,PI/2),Vector3(0,0,-0.8)),receiver)
	_add(c,_box_mesh(Vector3(0.05,0.05,0.07)),gun.translated_local(Vector3(0,0,-0.9)),receiver)
	_add(c,_box_mesh(Vector3(0.025,0.04,0.42)),gun.translated_local(Vector3(-0.1,0.02,-0.2)),material(Color("b08a3a"),0.4,0.6))
	# The sight box turns its glass toward the cover's right, so it reads as a lit side face.
	var sight := Basis(Vector3.UP,0.15)
	_add(c,_box_mesh(Vector3(0.3,0.24,0.3)),Transform3D(sight,Vector3(0.64,1.62,-0.66)),material(Color("2c2e2f"),0.5,0.3))
	_add(c,_box_mesh(Vector3(0.24,0.18,0.02)),Transform3D(sight,Vector3(0.64,1.62,-0.66)+sight*Vector3(0,0,-0.155)),_glow(Color("9fd0dc"),0.35))
	# Bracket carrying the sight box off the gun cradle.
	_limb(c,Vector3(0.74,1.3,-0.4),Vector3(0.66,1.5,-0.62),0.025,metal)
	_add(c,_box_mesh(Vector3(0.12,0.18,0.28)),Transform3D(Basis(),Vector3(0.93,1.2,-0.3)),material(Color("1d1e1a")))
	# Loader in desert khaki, risen out of the left hatch and bent forward over the roof toward
	# the main gun, head down, one arm reaching along the roof.
	_man(c,{"hip":Vector3(-0.72,1.0,0.5),"sh_l":Vector3(-0.47,1.52,0.25),"sh_r":Vector3(-0.84,1.5,0.32),
		"el_l":Vector3(-0.47,1.26,-0.04),"hand_l":Vector3(-0.52,1.13,-0.27),"el_r":Vector3(-0.86,1.22,0.1),"hand_r":Vector3(-0.8,1.08,-0.14),
		"head":Vector3(-0.6,1.32,-0.1)},Vector3(0.2,-0.75,-0.65),khaki,null,glove,skin,helmet,lens,false)

# Capsule spanning two points.
func _limb(c: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = a.distance_to(b)+radius*2.0
	capsule.radial_segments = 10
	capsule.rings = 2
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	_add(c,capsule,Transform3D(Basis(side,up,side.cross(up)),(a+b)*0.5),mat)

# ---- Crew --------------------------------------------------------------------------------
# Joint positions (turret frame) were back-projected from the box cover's two crewmen.

## A crewman from the waist up, built from explicit joints: a loft torso from hip to the
## shoulder line, an optional vest over the chest, jointed sleeves and gloved hands, a neck and
## a head under a CVC helmet with goggles. `j` holds hip, sh_l, sh_r, el_l, el_r, hand_l,
## hand_r and head; `look` is the direction the face points.
func _man(c: Node3D, j: Dictionary, look: Vector3, shirt: Material, vest: Material, glove: Material, skin: Material, helmet: Material, lens: Material, goggles := true) -> void:
	var hip: Vector3 = j.hip
	var sh_l: Vector3 = j.sh_l
	var sh_r: Vector3 = j.sh_r
	var sh_c := (sh_l+sh_r)*0.5
	var up := (sh_c-hip).normalized()
	var side := (sh_l-sh_r)
	side = (side-up*side.dot(up)).normalized()
	var fwd := side.cross(up).normalized()
	if fwd.dot(look) < 0.0:
		fwd = -fwd
	var half := sh_l.distance_to(sh_r)*0.5
	var length := hip.distance_to(sh_c)
	var ring := func(t: float, w: float, d: float, push: float) -> Array:
		var pts: Array = []
		var centre := hip.lerp(sh_c,t)+fwd*push
		for i in range(14):
			var a := TAU*i/14.0
			pts.append(centre+side*cos(a)*w+fwd*sin(a)*d)
		return pts
	# Waist, belly, chest, upper chest, shoulder yoke.
	var shape := [[0.0,0.72,0.8,0.0],[0.35,0.78,0.88,0.02],[0.68,0.92,0.95,0.03],[0.88,0.96,0.85,0.0],[1.0,0.62,0.62,-0.01]]
	var depth := half*0.74
	for r in range(shape.size()-1):
		loft(c,ring.call(shape[r][0],half*shape[r][1],depth*shape[r][2],shape[r][3]),ring.call(shape[r+1][0],half*shape[r+1][1],depth*shape[r+1][2],shape[r+1][3]),shirt)
	if vest != null:
		# Flak vest over the shirt: open at the arms, so the sleeves and shoulders stay white.
		var v := [[0.02,0.76,0.86,0.0],[0.4,0.82,0.95,0.02],[0.72,0.84,1.02,0.04],[0.9,0.7,0.95,0.02]]
		for r in range(v.size()-1):
			loft(c,ring.call(v[r][0],half*v[r][1],depth*v[r][2],v[r][3]),ring.call(v[r+1][0],half*v[r+1][1],depth*v[r+1][2],v[r+1][3]),vest)
		# Open shirt collar either side of the neck.
		for s in [-1.0,1.0]:
			_limb(c,sh_c+side*s*0.05+fwd*0.06+up*0.02,sh_c+side*s*0.1+fwd*0.08-up*0.05,0.025,shirt)
	# Shoulders, sleeves and gloved hands.
	for k in [["sh_l","el_l","hand_l"],["sh_r","el_r","hand_r"]]:
		var s_at: Vector3 = j[k[0]]
		var e_at: Vector3 = j[k[1]]
		var h_at: Vector3 = j[k[2]]
		var cap := SphereMesh.new()
		cap.radius = 0.09
		cap.height = 0.18
		_add(c,cap,Transform3D(Basis(),s_at),shirt)
		# Loose sleeves: a full upper arm narrowing to the cuff.
		_limb(c,s_at,e_at,0.085,shirt)
		_limb(c,e_at,h_at,0.068,shirt)
		# Glove: a fist wrapped around the grip.
		var dir := (h_at-e_at).normalized()
		var fist := SphereMesh.new()
		fist.radius = 0.046
		fist.height = 0.09
		_add(c,fist,Transform3D(Basis(),h_at+dir*0.04),glove)
		_limb(c,h_at-dir*0.02,h_at+dir*0.03,0.05,glove)
	# Neck and head, tipped toward the look direction.
	var head_at: Vector3 = j.head
	var neck_base := sh_c+up*0.02
	_limb(c,neck_base,head_at-up*0.12,0.06,skin)
	_head(c,head_at,(head_at-neck_base).normalized(),look,skin,helmet,lens,goggles)

## Head under a CVC helmet: a rounded shell deeper at the back, a brow rim, large ear cups,
## and goggles with two round lenses on the brow, strapped round the shell.
func _head(c: Node3D, at: Vector3, up: Vector3, look: Vector3, skin: Material, helmet: Material, lens: Material, goggles := true) -> void:
	var fwd := (look-up*look.dot(up)).normalized()
	var right := up.cross(fwd).normalized()
	# Right-handed (right x up = fwd), so mirrored meshes never turn inside out.
	var basis := Basis(right,up,fwd)
	var place := func(v: Vector3) -> Vector3: return at+right*v.x+up*v.y+fwd*v.z
	# Face: cranium, jaw and nose, in shadow under the helmet.
	var skull := SphereMesh.new()
	skull.radius = 0.1
	skull.height = 0.22
	_add(c,skull,Transform3D(basis.scaled(Vector3(0.92,1.0,1.0)),place.call(Vector3(0,-0.02,0))),skin)
	var jaw := SphereMesh.new()
	jaw.radius = 0.07
	jaw.height = 0.12
	_add(c,jaw,Transform3D(basis.scaled(Vector3(0.9,0.7,0.85)),place.call(Vector3(0,-0.075,0.03))),skin)
	_add(c,_box_mesh(Vector3(0.026,0.04,0.035)),Transform3D(basis,place.call(Vector3(0,-0.035,0.095))),skin)
	# Shell: a squashed dome sitting low over the ears and back of the neck.
	var shell := SphereMesh.new()
	shell.radius = 0.165
	shell.height = 0.33
	shell.radial_segments = 20
	shell.rings = 10
	_add(c,shell,Transform3D(basis.scaled(Vector3(0.95,0.85,1.08)),place.call(Vector3(0,0.07,-0.015))),helmet)
	_add(c,_ring_mesh(0.162,0.02),Transform3D(basis.scaled(Vector3(0.95,1,1.08)),place.call(Vector3(0,0.0,-0.015))),helmet)
	# Big round ear cups.
	var cup := CylinderMesh.new()
	cup.top_radius = 0.06
	cup.bottom_radius = 0.07
	cup.height = 0.06
	cup.radial_segments = 14
	for s in [-1.0,1.0]:
		_add(c,cup,Transform3D(basis*Basis(Vector3.FORWARD,PI/2*s),place.call(Vector3(s*0.145,-0.04,-0.01))),helmet)
	if not goggles:
		return
	# Goggles: a frame with two round lenses, on the brow.
	_add(c,_box_mesh(Vector3(0.2,0.06,0.04)),Transform3D(basis,place.call(Vector3(0,0.02,0.11))),helmet)
	var eye := CylinderMesh.new()
	eye.top_radius = 0.04
	eye.bottom_radius = 0.045
	eye.height = 0.035
	eye.radial_segments = 14
	for s in [-1.0,1.0]:
		_add(c,eye,Transform3D(basis*Basis(Vector3.RIGHT,PI/2),place.call(Vector3(s*0.048,0.02,0.125))),lens)

## Flat band (a short open cylinder) used for helmet rims and straps.
func _ring_mesh(radius: float, width: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = width
	m.radial_segments = 20
	m.cap_top = false
	m.cap_bottom = false
	return m

# Flat convex polygon facing the given direction (markings and small plates).
func _flat(frame: Node3D, pts: Array, outward: Vector3, mat: Material) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(1,pts.size()-1):
		_tri(st,pts[0],pts[i],pts[i+1],outward)
	st.generate_normals()
	_add(frame,st.commit(),Transform3D(),mat,"facet")

func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var m := material(color,0.2)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func update_pose(relative_turret: float, delta: float, elevation := 0.0, gun_yaw := 0.0) -> void:
	turret_root.rotation.y = relative_turret
	recoil = move_toward(recoil, 0.0, delta*1.8)
	barrel.position = GUN_ROOT + barrel.basis.z*recoil
	barrel.rotation = Vector3(elevation,gun_yaw,0)
