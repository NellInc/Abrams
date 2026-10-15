extends Node3D
## Presentation-only range landscape. Seed isolated from gameplay state.

var materials: Array[StandardMaterial3D] = []

const NOISE := """
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
"""

static func height_at(x: float, z: float) -> float:
	# The complete simulation bounds are flat. Decorative hills cannot bury actors.
	var outside := Vector2(maxf(absf(x)-1250.0,0.0),maxf(absf(z+750.0)-1100.0,0.0)).length()
	var outer := smoothstep(0.0,500.0,outside)
	return outer * (32.0 + sin(x*0.004)*cos(z*0.003)*26.0 + sin(z*0.011+x*0.008)*8.0)

func mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func shader_material(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var m := ShaderMaterial.new()
	m.shader = shader
	return m

func _ready() -> void:
	# Meadow: broad lush and dry patches, mid-scale clumping and fine speckle; the rut term draws the lane.
	var ground_mat := shader_material("""shader_type spatial;
varying vec3 ground;
""" + NOISE + """
void vertex(){ground=VERTEX;}
void fragment(){
 float macro=noise(ground.xz*0.012)*0.6+noise(ground.xz*0.035)*0.4;
 float patch=noise(ground.xz*0.09)*0.55+noise(ground.xz*0.7)*0.3+noise(ground.xz*6.0)*0.15;
 vec3 lush=mix(vec3(0.085,0.125,0.045),vec3(0.20,0.25,0.09),patch);
 vec3 dry=mix(vec3(0.22,0.21,0.10),vec3(0.36,0.32,0.16),patch);
 vec3 grass=mix(lush,dry,smoothstep(0.52,0.78,macro));
 grass*=0.85+0.3*noise(ground.xz*2.3);
 float rut=(1.0-smoothstep(0.55,0.85,abs(abs(ground.x)-1.72)))*(1.0-smoothstep(20.0,40.0,ground.z));
 ALBEDO=mix(grass,vec3(0.19,0.17,0.12)*(0.7+patch*0.5),rut);
 ROUGHNESS=0.97;
 SPECULAR=0.15;
}""")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 198803
	var n := 100
	var step := 60.0
	for zi in range(n):
		for xi in range(n):
			var x := (float(xi)-n/2.0)*step
			var z := (float(zi)-n/2.0)*step
			# The ground shader ignores vertex colour (its rut term draws the lane); keep this draw so the seeded placement below stays stable.
			rng.randf_range(-0.028,0.028)
			for v in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var xx: float = x+v.x*step
				var zz: float = z+v.y*step
				st.add_vertex(Vector3(xx,height_at(xx,zz)-0.05,zz))
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = ground_mat
	add_child(terrain)
	# Trees grow in groves rather than an even scatter, with a dense belt on the outer hills.
	# The range lane (|x| < 450) stays open so trees never screen the practice targets.
	var groves: Array[Vector2] = []
	for i in range(70):
		groves.append(Vector2(rng.randf_range(-1250,1250),rng.randf_range(-2300,650)))
	var broadleaf: Array[Vector3] = []
	var conifer: Array[Vector3] = []
	for i in range(1100):
		var p: Vector2
		if i < 760:
			var grove: Vector2 = groves[i%groves.size()]
			var spread := rng.randf_range(0.0,1.0)
			p = grove + Vector2.from_angle(rng.randf()*TAU)*spread*spread*110.0
		else:
			# Outer belt on the decorative hills frames the horizon.
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			p = Vector2(side*rng.randf_range(1320,2100),rng.randf_range(-2600,900))
		if absf(p.x) < 450:
			continue
		var at := Vector3(p.x,height_at(p.x,p.y),p.y)
		if rng.randf() < 0.36:
			conifer.append(at)
		else:
			broadleaf.append(at)
	var trunks: Array[Vector3] = []
	trunks.append_array(broadleaf)
	trunks.append_array(conifer)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.17
	trunk.bottom_radius = 0.28
	trunk.height = 5.0
	trunk.radial_segments = 6
	instances(trunk,mat(Color("2f2a20")),trunks,Vector3(0,2.5,0),rng)
	var foliage := shader_material("""shader_type spatial;
uniform vec3 shade_color;
uniform vec3 light_color;
varying vec3 world;
varying float variant;
""" + NOISE + """
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 variant=hash(MODEL_MATRIX[3].xz*0.37);
}
void fragment(){
 float leaf=noise(world.xz*1.7+world.y*1.3)*0.6+noise(world.xy*4.1)*0.4;
 vec3 base=mix(shade_color,light_color,leaf*0.7+variant*0.3);
 base*=mix(0.8,1.15,variant);
 // Self-shadowed underside gives the crowns volume under the low sun.
 float up=clamp((INV_VIEW_MATRIX*vec4(NORMAL,0.0)).y*0.5+0.5,0.0,1.0);
 ALBEDO=base*mix(0.45,1.05,up);
 ROUGHNESS=0.95;
 SPECULAR=0.1;
}""")
	foliage.set_shader_parameter("shade_color",Vector3(0.10,0.15,0.06))
	foliage.set_shader_parameter("light_color",Vector3(0.27,0.33,0.12))
	instances(_broadleaf_crown(),foliage,broadleaf,Vector3(0,7.0,0),rng)
	# Near-field meadow: swaying grass clumps with dry tips and patch variation.
	var grass_positions: Array[Vector3] = []
	for i in range(30000):
		# Bias density towards the vehicle so the foreground reads as a meadow, thinning outward.
		var radius := pow(rng.randf(),0.85)*130.0
		var p := Vector3.ZERO
		var angle := rng.randf()*TAU
		p.x = cos(angle)*radius
		p.z = sin(angle)*radius*1.15 - 10.0
		if absf(p.x)<3.0 and p.z > -60.0:
			continue
		p.y = height_at(p.x,p.z)
		grass_positions.append(p)
	var grass := shader_material("""shader_type spatial;
render_mode cull_disabled;
varying float tip;
varying float dryness;
varying float shade;
""" + NOISE + """
void vertex(){
 vec3 origin=MODEL_MATRIX[3].xyz;
 tip=UV.y;
 float gust=sin(TIME*1.3+origin.x*0.09+origin.z*0.05)*0.5+0.5;
 float sway=sin(TIME*2.1+origin.x*0.43+origin.z*0.31)*(0.5+gust);
 VERTEX.xz+=vec2(0.03,0.016)*sway*tip*tip;
 // Light grass as a canopy so blade backsides never read as black slivers.
 NORMAL=vec3(0.0,1.0,0.0);
 dryness=smoothstep(0.45,0.8,noise(origin.xz*0.05)*0.7+noise(origin.xz*0.4)*0.3);
 shade=0.75+0.35*hash(origin.xz);
}
void fragment(){
 vec3 base=vec3(0.06,0.09,0.03);
 vec3 green=vec3(0.20,0.27,0.07);
 vec3 straw=vec3(0.46,0.40,0.18);
 vec3 tipc=mix(green,straw,dryness);
 ALBEDO=mix(base,tipc,pow(tip,0.8))*shade;
 ROUGHNESS=0.85;
 SPECULAR=0.25;
}""")
	instances(_grass_clump(),grass,grass_positions,Vector3.ZERO,rng)
	var needles := foliage.duplicate()
	needles.set_shader_parameter("shade_color",Vector3(0.05,0.09,0.06))
	needles.set_shader_parameter("light_color",Vector3(0.13,0.21,0.11))
	instances(_conifer_crown(),needles,conifer,Vector3(0,3.2,0),rng)
	# Wildflower heads sit inside the grass so they read as blooms, not floating dots.
	for colour in [Color("c9a23a"),Color("b9b49c"),Color("94667c")]:
		var heads: Array[Vector3] = []
		for i in range(900):
			var p := Vector3(rng.randf_range(-70,70),0,rng.randf_range(-90,60))
			if absf(p.x)<3.5 and p.z > -60.0:
				continue
			p.y = height_at(p.x,p.z)+rng.randf_range(0.12,0.26)
			heads.append(p)
		var head := SphereMesh.new()
		head.radius = 0.028
		head.height = 0.05
		head.radial_segments = 6
		head.rings = 3
		var bloom := mat(colour)
		bloom.roughness = 0.7
		instances(head,bloom,heads,Vector3.ZERO,rng)
	# Weathered boulders give the foreground scale and shadow detail.
	var rocks: Array[Vector3] = []
	for i in range(90):
		var p := Vector3(rng.randf_range(-160,160),0,rng.randf_range(-260,80))
		if absf(p.x) < 8.0:
			continue
		p.y = height_at(p.x,p.z)-0.15
		rocks.append(p)
	var rock := SphereMesh.new()
	rock.radius = 0.6
	rock.height = 0.55
	rock.radial_segments = 5
	rock.rings = 2
	var stone := mat(Color("3d3c34"))
	stone.roughness = 0.92
	instances(rock,stone,rocks,Vector3.ZERO,rng)
	# Range stakes and lateral lane markings are decorative, never hit blockers.
	for z in [-80,-160,-260,-400]:
		for x in [-30,30]:
			var stake := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.18,1.8,0.18)
			stake.mesh = b
			stake.material_override = mat(Color("c2b58b"))
			stake.position = Vector3(x,0.9,z)
			add_child(stake)

# Seven to nine tapered blades fanned around the root, each leaning outward.
func _grass_clump() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = 4417
	var blades := 9
	for b in range(blades):
		var angle := TAU*b/blades + r.randf_range(-0.35,0.35)
		var dir := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-dir.z,0,dir.x)
		var height := r.randf_range(0.16,0.44)
		var width := r.randf_range(0.011,0.022)
		var root := dir*r.randf_range(0.0,0.05)
		var lean := dir*r.randf_range(0.03,0.13)
		var mid := root+lean*0.35+Vector3(0,height*0.55,0)
		var top := root+lean+Vector3(0,height,0)
		var quad := [[root-side*width,0.0],[root+side*width,0.0],[mid+side*width*0.65,0.55],[mid-side*width*0.65,0.55]]
		for index in [0,1,2,0,2,3]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0,quad[index][1]))
			st.add_vertex(quad[index][0])
		for v in [[mid-side*width*0.65,0.55],[mid+side*width*0.65,0.55],[top,1.0]]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(0,v[1]))
			st.add_vertex(v[0])
	return st.commit()

# Several overlapping lobes read as a leafy canopy instead of a single ball.
func _broadleaf_crown() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lobe := SphereMesh.new()
	lobe.radial_segments = 8
	lobe.rings = 5
	for spec in [[Vector3(0,0,0),2.7],[Vector3(1.5,-0.9,0.6),1.9],[Vector3(-1.4,-0.6,-0.8),2.0],[Vector3(0.3,1.4,-0.4),1.8],[Vector3(-0.5,-1.3,1.4),1.7]]:
		lobe.radius = spec[1]
		lobe.height = spec[1]*1.8
		st.append_from(lobe,0,Transform3D(Basis(),spec[0]))
	st.generate_normals()
	return st.commit()

# Stacked cones give a fir silhouette that breaks up the broadleaf groves.
func _conifer_crown() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.radial_segments = 8
	cone.rings = 1
	for spec in [[0.0,2.4,4.2],[2.6,1.9,3.6],[4.9,1.3,3.0]]:
		cone.bottom_radius = spec[1]
		cone.height = spec[2]
		st.append_from(cone,0,Transform3D(Basis(),Vector3(0,spec[0]+spec[2]*0.5,0)))
	return st.commit()

func instances(mesh: Mesh, material: Material, points: Array[Vector3], offset: Vector3, rng: RandomNumberGenerator) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in range(points.size()):
		var scale_factor := rng.randf_range(0.8,1.3)
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale_factor)
		mm.set_instance_transform(i,Transform3D(basis,points[i]+offset*scale_factor))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material
	add_child(node)
