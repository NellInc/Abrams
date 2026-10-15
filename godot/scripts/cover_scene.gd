extends Node3D
## Title-screen set dressed after the restored box cover: a backlit tank charging through
## churned earth under a burning, smoke-filled sky. Presentation only; hidden in play.

# Framing matched to the box-cover photograph: the camera, hull attitude and gun pose were
# fitted to the cover's fenders, headlights, turret slab and gun, measured in pixels of an
# 880-pixel-tall framing of the cover (FRAME). The framing is drawn right-aligned and
# full-height, so the tank sits beside the title column with the cover's own perspective.
const CAMERA_POS := Vector3(2.1954,0.9,-12.7208)
const CAMERA_ROT := Vector3(0.16113,2.92846,-0.06834)
const FOCAL := 2000.0
const FRAME := Vector2(1039.0,880.0)
const AXIS := Vector2(519.5,197.0)
const HULL_PITCH := -0.05
const TURRET := 0.7
const ELEVATION := 0.2392
const GUN_YAW := -0.5427

## Off-axis projection that places FRAME, scaled to the screen height, against the right edge.
static func frame(camera: Camera3D, size: Vector2) -> void:
	var s := size.y/FRAME.y
	var focal := FOCAL*s
	var axis := Vector2(size.x-FRAME.x*s+AXIS.x*s,AXIS.y*s)
	var near := 0.1
	camera.projection = Camera3D.PROJECTION_FRUSTUM
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_frustum(size.y/focal*near,Vector2((size.x*0.5-axis.x)/focal*near,(axis.y-size.y*0.5)/focal*near),near,camera.far)
	camera.transform = Transform3D(Basis.from_euler(CAMERA_ROT,EULER_ORDER_YXZ),CAMERA_POS)

# Render layer for the ground, which the rim light skips.
const GROUND_LAYER := 2

var environment: Environment
var _particles: Array[CPUParticles3D] = []

const SKY_SHADER := """shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0;float a=0.5;for(int i=0;i<6;i++){v+=a*noise(p);p=p*2.03+vec2(1.7,9.2);a*=0.5;}return v;}
void sky(){
 vec3 d=EYEDIR;
 // Billowing smoke: domain-warped noise over the dome, lit from below by the fires.
 vec2 uv=vec2(atan(d.x,d.z)*2.2,d.y*4.0);
 vec2 warp=vec2(fbm(uv*1.2+TIME*0.008),fbm(uv*1.2+vec2(5.2,1.3)-TIME*0.006));
 float smoke=fbm(uv*2.4+warp*2.2)*0.65+fbm(uv*7.0+warp*3.0)*0.35;
 float lit=fbm(uv*1.4-warp*1.3+3.0);
 // Fire burns off the tank's right flank, the upper left of the cover, and glows in a red
 // band low behind the tank; overhead and to the right the smoke is a dark brown-red pall.
 float flank=smoothstep(-0.2,0.12,d.x);
 float band=1.0-smoothstep(0.09,0.22,d.y);
 float heat=clamp(max(flank*(0.5+0.5*smoothstep(0.05,0.25,d.y)),band*0.9),0.0,1.0);
 vec3 soot=vec3(0.12,0.05,0.045);
 vec3 pall=vec3(0.24,0.085,0.07);
 vec3 ember=vec3(0.62,0.15,0.07);
 vec3 flame=vec3(1.1,0.27,0.09);
 vec3 core=vec3(1.25,0.48,0.15);
 vec3 c=mix(soot,pall,smoothstep(0.3,0.6,smoke));
 c=mix(c,ember,smoothstep(0.42,0.75,lit)*smoothstep(0.35,0.7,smoke)*(0.25+0.75*heat));
 c=mix(c,flame,smoothstep(0.22,0.55,smoke)*heat);
 c=mix(c,core,smoothstep(0.55,0.85,lit)*smoothstep(0.5,0.8,smoke)*flank*flank);
 c=mix(vec3(0.3,0.1,0.06),c,smoothstep(-0.08,0.06,d.y));
 COLOR=c;
}"""

const DIRT_SHADER := """shader_type spatial;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 // Churned, track-torn earth: dark wet loam broken by dry, dusty crumbs.
 float clods=noise(world.xz*2.3)*0.45+noise(world.xz*7.0+3.0)*0.3+noise(world.xz*23.0)*0.25;
 float wet=smoothstep(0.35,0.7,noise(world.xz*0.6+9.0));
 vec3 loam=vec3(0.3,0.2,0.13);
 vec3 dry=vec3(0.8,0.57,0.38);
 ALBEDO=mix(loam,dry,smoothstep(0.5,0.8,clods)*(1.0-0.6*wet));
 NORMAL_MAP=normalize(vec3(noise(world.xz*9.0)-0.5,noise(world.xz*9.0+7.0)-0.5,0.35))*0.5+0.5;
 ROUGHNESS=1.0;
 SPECULAR=0.08;
}"""

func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER
	sky_material.shader = sky_shader
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("5a4a44")
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.0
	# Low key light from the cover's left, over the photographer's shoulder: it rakes across
	# the turret slab and fender faces and leaves the glacis, roof and turret front dark.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-17,128,0)
	key.light_color = Color("ffe7cf")
	key.light_energy = 1.1
	key.shadow_enabled = true
	key.shadow_opacity = 0.85
	key.directional_shadow_max_distance = 60
	add_child(key)
	# Firelight from behind the tank on the cover's right rims the gun, turret and dust.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-14,-30,0)
	rim.light_color = Color("ff5a24")
	rim.light_energy = 1.0
	rim.shadow_enabled = false
	# The rim catches the tank, crew and dust, not the churned ground at the camera's feet.
	rim.light_cull_mask = 1
	add_child(rim)
	_ground()
	_dust()
	_debris()

func set_active(active: bool) -> void:
	visible = active
	for particles in _particles:
		particles.emitting = active

func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(700,700)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var dirt := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = DIRT_SHADER
	dirt.shader = shader
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	ground.material_override = dirt
	ground.position = Vector3(0,0.03,0)
	ground.layers = GROUND_LAYER
	add_child(ground)
	# Churned clods, densest in the foreground before the camera and around the tracks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1988
	var clod := SphereMesh.new()
	clod.radius = 0.09
	clod.height = 0.1
	clod.radial_segments = 4
	clod.rings = 2
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("4a3626")
	earth.roughness = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = clod
	mm.instance_count = 3200
	for i in range(mm.instance_count):
		var p := Vector3(rng.randf_range(-9,12),0.0,rng.randf_range(-12.2,6))
		var s := rng.randf_range(0.2,0.9)*(2.0 if rng.randf() < 0.05 else 1.0)
		var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s,s*rng.randf_range(0.45,0.8),s))
		mm.set_instance_transform(i,Transform3D(basis,p+Vector3(0,0.02,0)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = earth
	node.layers = GROUND_LAYER
	add_child(node)

# Billowing cloud sprite: fractal noise under a soft round falloff, so overlapping puffs
# read as lumpy dust rather than smooth fog.
func _cloud_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 88
	noise.frequency = 0.045
	noise.fractal_octaves = 5
	var size := 128
	var image := Image.create(size,size,false,Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x-size*0.5+0.5,y-size*0.5+0.5).length()/(size*0.5)
			var falloff := clampf(1.0-d,0.0,1.0)
			var n := noise.get_noise_2d(x,y)*0.5+0.5
			var a := clampf((n-0.42)*4.0,0.0,1.0)*pow(falloff,0.7)
			# Brighter, sunlit tops on each lump; darker undersides.
			var shade := 0.75+0.35*clampf(n*1.4-0.2,0.0,1.0)-0.2*float(y)/size
			image.set_pixel(x,y,Color(shade,shade,shade,a))
	return ImageTexture.create_from_image(image)

func _dust() -> void:
	# Plumes thrown off the tracks, as on the cover: bright and fire-lit off the right flank,
	# dark brown under the nose, an orange haze behind the far side reaching turret height.
	var puff_material := StandardMaterial3D.new()
	puff_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff_material.vertex_color_use_as_albedo = true
	puff_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff_material.albedo_texture = _cloud_texture()
	# [centre, extents, amount, lifetime, size, colour]
	var plumes := [
		[Vector3(2.4,0.25,-3.6),Vector3(0.4,0.2,0.4),100,2.6,1.0,Color(0.5,0.33,0.22,0.45)],
		[Vector3(1.9,0.2,-1.0),Vector3(0.3,0.15,2.4),80,2.6,1.1,Color(0.28,0.18,0.12,0.75)],
		[Vector3(-1.9,0.2,-1.5),Vector3(0.3,0.15,2.2),70,2.6,1.1,Color(0.26,0.17,0.11,0.75)],
		[Vector3(-3.0,1.75,-1.2),Vector3(0.6,0.45,0.9),50,4.0,2.6,Color(0.38,0.14,0.08,0.65)],
		[Vector3(3.4,0.45,-0.5),Vector3(0.9,0.35,3.0),140,3.6,2.1,Color(0.85,0.56,0.37,0.8)],
		[Vector3(2.8,0.4,-4.3),Vector3(0.6,0.3,0.5),90,2.8,1.5,Color(0.82,0.54,0.35,0.8)],
		[Vector3(0.0,0.18,-4.3),Vector3(2.0,0.1,0.3),110,2.4,0.9,Color(0.3,0.19,0.12,0.85)],
		[Vector3(0.3,0.12,-5.2),Vector3(3.0,0.08,0.8),90,3.0,0.8,Color(0.45,0.28,0.18,0.5)],
		[Vector3(-2.0,0.25,-3.9),Vector3(0.4,0.2,0.4),90,2.4,1.1,Color(0.6,0.37,0.24,0.8)],
		[Vector3(-2.7,0.3,-3.0),Vector3(0.6,0.25,1.0),70,3.0,1.4,Color(0.8,0.5,0.32,0.7)],
		[Vector3(-3.6,1.0,0.0),Vector3(1.0,0.9,2.6),60,4.0,2.6,Color(0.6,0.28,0.14,0.4)],
		[Vector3(1.0,0.15,-7.0),Vector3(4.5,0.06,2.2),70,4.0,1.2,Color(0.55,0.37,0.24,0.45)]]
	for spec in plumes:
		var dust := CPUParticles3D.new()
		var puff := QuadMesh.new()
		puff.size = Vector2(spec[4],spec[4])
		puff.material = puff_material
		dust.mesh = puff
		dust.amount = spec[2]
		dust.lifetime = spec[3]
		dust.preprocess = spec[3]
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = spec[1]
		dust.position = spec[0]
		# Low plumes roll along the ground; only the tall ones billow upward.
		var low: bool = spec[0].y < 0.5
		dust.direction = Vector3(0.3,0.25 if low else 1.0,0.6)
		dust.spread = 45.0
		dust.gravity = Vector3(0,-0.05 if low else -0.2,0)
		dust.initial_velocity_min = 0.1 if low else 0.3
		dust.initial_velocity_max = 0.3 if low else 0.8
		dust.angle_min = -180.0
		dust.angle_max = 180.0
		dust.angular_velocity_min = -12.0
		dust.angular_velocity_max = 12.0
		dust.scale_amount_min = 0.6
		dust.scale_amount_max = 1.4
		var colour: Color = spec[5]
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(colour,0.0),Color(colour,colour.a),Color(colour.darkened(0.35),0.0)])
		ramp.offsets = PackedFloat32Array([0.0,0.15,1.0])
		dust.color_ramp = ramp
		# Per-puff variation between shadowed and fire-lit dust.
		var tint := Gradient.new()
		tint.colors = PackedColorArray([Color(0.7,0.66,0.62),Color(1.15,1.08,1.0)])
		dust.color_initial_ramp = tint
		add_child(dust)
		_particles.append(dust)

func _debris() -> void:
	# Earth flung up by the tracks: small dark clods arcing out and falling back.
	var chunk := SphereMesh.new()
	chunk.radius = 0.016
	chunk.height = 0.026
	chunk.radial_segments = 4
	chunk.rings = 2
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("140e0a")
	chunk.material = earth
	# [centre, extents, direction]: along each track run, and ahead of each idler where the
	# tracks throw earth toward the camera.
	var throws := [
		[Vector3(1.6,0.3,0.4),Vector3(0.3,0.2,2.8),Vector3(0.6,1.0,0.7)],
		[Vector3(-1.6,0.3,0.4),Vector3(0.3,0.2,2.8),Vector3(-0.6,1.0,0.7)],
		[Vector3(1.5,0.4,-3.6),Vector3(0.35,0.2,0.3),Vector3(0.3,1.0,-0.8)],
		[Vector3(-1.5,0.4,-3.6),Vector3(0.35,0.2,0.3),Vector3(-0.3,1.0,-0.8)]]
	for spec in throws:
		var debris := CPUParticles3D.new()
		debris.mesh = chunk
		debris.amount = 300
		debris.lifetime = 1.4
		debris.preprocess = 1.4
		debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		debris.emission_box_extents = spec[1]
		debris.position = spec[0]
		debris.direction = spec[2]
		debris.spread = 35.0
		debris.gravity = Vector3(0,-9.8,0)
		debris.initial_velocity_min = 1.5
		debris.initial_velocity_max = 3.8
		debris.angular_velocity_min = -400.0
		debris.angular_velocity_max = 400.0
		debris.scale_amount_min = 0.3
		debris.scale_amount_max = 1.1
		add_child(debris)
		_particles.append(debris)
