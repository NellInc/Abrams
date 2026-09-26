extends Node3D
## Original authored procedural presentation model. Never participates in simulation.

var turret_root: Node3D
var wheels: Array[Node3D] = []
var barrel: Node3D
var paint: StandardMaterial3D
var dark: StandardMaterial3D
var metal: StandardMaterial3D
var recoil := 0.0

func material(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, axis := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = at
	node.rotation = axis
	parent.add_child(node)
	return node

func wedge(parent: Node3D, lower: Vector2, upper: Vector2, height: float, at: Vector3, mat: Material, offset := Vector2.ZERO) -> MeshInstance3D:
	var points: Array[Vector3] = []
	for y in [0, 1]:
		var extent: Vector2 = lower if y == 0 else upper
		var shift: Vector2 = Vector2.ZERO if y == 0 else offset
		for v in [Vector2(-1,-1), Vector2(1,-1), Vector2(1,1), Vector2(-1,1)]:
			points.append(Vector3(v.x * extent.x / 2.0 + shift.x, float(y) * height, v.y * extent.y / 2.0 + shift.y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,3,2,1], [4,5,6,7], [0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7]]:
		for index in [0,1,2,0,2,3]:
			st.add_vertex(points[face[index]])
	st.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	node.position = at
	parent.add_child(node)
	return node

func _ready() -> void:
	paint = material(Color("59634b"))
	dark = material(Color("20251f"))
	metal = material(Color("383c32"), 0.55, 0.6)
	var edge := material(Color("757b5b"))
	var rubber := material(Color("171b19"))
	var glass := material(Color("518481"), 0.18, 0.75)
	wedge(self, Vector2(3.2,6.5), Vector2(3.5,6.1), 0.8, Vector3(0,0.62,0.25), paint)
	wedge(self, Vector2(3.5,6.15), Vector2(3.25,4.85), 0.55, Vector3(0,1.4,0.25), paint, Vector2(0,0.42))
	# Broad, readable track silhouette and independently modelled road wheels.
	for side in [-1, 1]:
		var x := float(side) * 1.73
		box(self, Vector3(0.76,0.2,5.9), Vector3(x,0.24,0.15), rubber)
		box(self, Vector3(0.76,0.16,5.9), Vector3(x,1.26,0.15), rubber)
		for i in range(7):
			var w := cylinder(self, 0.48,0.64,Vector3(x,0.76,-2.25 + i * 0.78),dark,Vector3(0,0,PI/2.0))
			wheels.append(w)
			cylinder(self,0.30,0.67,Vector3(x,0.76,-2.25 + i * 0.78),paint,Vector3(0,0,PI/2.0))
			cylinder(self,0.09,0.70,Vector3(x,0.76,-2.25 + i * 0.78),metal,Vector3(0,0,PI/2.0))
		for i in range(30):
			box(self,Vector3(0.81,0.075,0.10),Vector3(x,0.14,-2.72 + float(i)*0.198),metal)
		for i in range(5):
			box(self,Vector3(0.12,0.67,1.04),Vector3(side*2.12,1.22,-2.30+i*1.13),paint)
			for z in [-0.38,0.38]:
				cylinder(self,0.035,0.135,Vector3(side*2.12,1.4,-2.30+i*1.13+z),edge,Vector3(0,0,PI/2.0))
		# Headlamp guards and towing eyes.
		box(self,Vector3(0.36,0.26,0.22),Vector3(side*1.28,1.65,-2.64),dark)
		box(self,Vector3(0.25,0.16,0.03),Vector3(side*1.28,1.65,-2.77),glass)
		cylinder(self,0.10,0.18,Vector3(side*1.08,0.92,-3.03),metal,Vector3(PI/2,0,0))
	# Engine deck grille.
	for i in range(14):
		box(self,Vector3(2.35,0.055,0.065),Vector3(0,1.99,1.3+i*0.095),dark)
	cylinder(self,1.32,0.16,Vector3(0,2.0,-0.08),dark)
	turret_root = Node3D.new()
	turret_root.name = "Turret"
	add_child(turret_root)
	turret_root.position = Vector3(0,2.0,-0.08)
	wedge(turret_root,Vector2(3.2,3.7),Vector2(2.45,2.9),0.84,Vector3(0,0,-0.10),paint,Vector2(0,0.25))
	# Sloped cheek armour, stowage bins, rear basket, smoke launchers.
	for side in [-1,1]:
		var cheek := box(turret_root,Vector3(0.9,0.58,1.30),Vector3(side*0.95,0.42,-1.0),paint)
		cheek.rotation.z = side * -0.16
		cheek.rotation.y = side * -0.13
		box(turret_root,Vector3(0.36,0.55,1.3),Vector3(side*1.38,0.39,0.65),edge)
		for i in range(3):
			cylinder(turret_root,0.065,0.29,Vector3(side*1.42,0.40,-0.73+i*0.19),dark,Vector3(0,0,side*0.8))
		cylinder(turret_root,0.016,2.0,Vector3(side*1.05,1.77,1.22),dark)
		box(turret_root,Vector3(0.07,0.42,1.6),Vector3(side*1.32,0.51,1.5),metal)
	for y in [0.35,0.75]:
		box(turret_root,Vector3(2.65,0.06,0.06),Vector3(0,y,2.18),metal)
	for i in range(9):
		box(turret_root,Vector3(0.035,0.4,0.05),Vector3(-1.28+i*0.32,0.53,2.18),metal)
	box(turret_root,Vector3(0.8,0.45,0.35),Vector3(0,0.35,-1.92),paint)
	barrel = Node3D.new()
	turret_root.add_child(barrel)
	barrel.position = Vector3(0,0.40,-1.82)
	cylinder(barrel,0.115,3.65,Vector3(0,0,-1.77),paint,Vector3(PI/2,0,0))
	cylinder(barrel,0.165,0.72,Vector3(0,0,-1.24),edge,Vector3(PI/2,0,0))
	cylinder(barrel,0.13,0.08,Vector3(0,0,-3.63),metal,Vector3(PI/2,0,0))
	cylinder(barrel,0.088,0.085,Vector3(0,0,-3.67),rubber,Vector3(PI/2,0,0))
	for x in [-0.63,0.68]:
		cylinder(turret_root,0.42,0.12,Vector3(x,0.88,0.47),dark)
		cylinder(turret_root,0.35,0.16,Vector3(x,0.96,0.47),paint)
		box(turret_root,Vector3(0.17,0.08,0.10),Vector3(x,1.06,0.5),metal)
	for i in range(5):
		box(turret_root,Vector3(0.13,0.11,0.10),Vector3(-0.90+i*0.13,0.94,0.06),glass)
	cylinder(turret_root,0.06,0.5,Vector3(-0.66,1.2,0.4),metal)
	box(turret_root,Vector3(0.16,0.14,0.56),Vector3(-0.66,1.45,0.2),dark)
	cylinder(turret_root,0.025,0.72,Vector3(-0.66,1.46,-0.38),metal,Vector3(PI/2,0,0))
	# Canvas roll and a subdued original tactical marker.
	cylinder(turret_root,0.18,1.2,Vector3(0.45,0.64,1.89),material(Color("7c775b")),Vector3(0,0,PI/2))
	var marker := Label3D.new()
	marker.text = "11"
	marker.font_size = 80
	marker.pixel_size = 0.004
	marker.modulate = Color("c4c5a0")
	marker.position = Vector3(-1.589,0.38,0.25)
	marker.rotation.y = -PI/2
	turret_root.add_child(marker)

func update_pose(relative_turret: float, delta: float) -> void:
	turret_root.rotation.y = relative_turret
	recoil = move_toward(recoil, 0.0, delta*1.8)
	barrel.position.z = -1.82 + recoil
