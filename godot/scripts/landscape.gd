extends Node3D
## Presentation-only range landscape. Seed isolated from gameplay state.

var materials: Array[StandardMaterial3D] = []

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

func _ready() -> void:
	var ground_mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
varying vec3 ground;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){ground=VERTEX;}
void fragment(){
 float patch=noise(ground.xz*0.09)*0.55+noise(ground.xz*0.7)*0.3+noise(ground.xz*6.0)*0.15;
 vec3 grass=mix(vec3(0.055,0.080,0.031),vec3(0.18,0.205,0.095),patch);
 float rut=(1.0-smoothstep(0.55,0.85,abs(abs(ground.x)-1.72)))*(1.0-smoothstep(20.0,40.0,ground.z));
 ALBEDO=mix(grass,vec3(0.15,0.12,0.074)*(0.7+patch*0.5),rut);
 ROUGHNESS=0.98;
}"""
	ground_mat.shader = shader
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
			var shade := rng.randf_range(-0.028,0.028)
			var c := Color(0.28+shade,0.31+shade,0.22+shade)
			if absf(x) < 12 and z < 25 and z > -900:
				c = Color(0.33+shade,0.31+shade,0.25+shade)
			for v in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var xx: float = x+v.x*step
				var zz: float = z+v.y*step
				st.set_color(c)
				st.add_vertex(Vector3(xx,height_at(xx,zz)-0.05,zz))
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = st.commit()
	terrain.material_override = ground_mat
	add_child(terrain)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.17
	trunk.bottom_radius = 0.26
	trunk.height = 5.0
	trunk.radial_segments = 5
	var crown := SphereMesh.new()
	crown.radius = 2.8
	crown.height = 8.0
	crown.radial_segments = 7
	crown.rings = 4
	var positions: Array[Vector3] = []
	for i in range(460):
		var x := rng.randf_range(-1200,1200)
		var z := rng.randf_range(-1200,600)
		if absf(x) < 450:
			continue
		positions.append(Vector3(x,height_at(x,z),z))
	instances(trunk,mat(Color("383c2d")),positions,Vector3(0,2.5,0),rng)
	instances(crown,mat(Color("374431")),positions,Vector3(0,7.1,0),rng)
	# Small tufts supply near-field scale without external textures.
	var grass := PrismMesh.new()
	grass.size = Vector3(0.10,0.32,0.09)
	var grass_positions: Array[Vector3] = []
	for i in range(3300):
		var p := Vector3(rng.randf_range(-80,80),0,rng.randf_range(-90,70))
		if absf(p.x)<3.0:
			continue
		p.y = height_at(p.x,p.z)
		grass_positions.append(p)
	instances(grass,mat(Color("767b4c")),grass_positions,Vector3(0,0.13,0),rng)
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
