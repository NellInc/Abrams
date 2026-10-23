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
var puff_material: StandardMaterial3D

# The clock is explicit so reduced motion freezes the sky and practical firelight too.
var atmosphere_time := 14.0
var _motion_enabled := true
var _sky_material: ShaderMaterial
var _fire: OmniLight3D
var motion_time := 0.0
var travel_distance := 0.0
const TRAVEL_SPEED := 0.85
var _earth_material: ShaderMaterial
var _lamp_mount: Node3D

const SKY_SHADER := """shader_type sky;
uniform float atmosphere_time = 14.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){float v=0.0;float a=0.5;for(int i=0;i<6;i++){v+=a*noise(p);p=p*2.03+vec2(1.7,9.2);a*=0.5;}return v;}
void sky(){
 vec3 d=EYEDIR;
 vec2 uv=vec2(atan(d.x,d.z)*2.2,d.y*4.0);
 float t=atmosphere_time;
 // Advection carries the entire smoke field upward and downwind. The explicit
 // lifecycle clock freezes this motion exactly under reduced motion or hidden menus.
 uv-=vec2(0.026,0.085)*t;
 // Soft, turbulent smoke volumes rather than liquid-looking nested domain warps.
 vec2 warp=vec2(fbm(uv*1.2+t*0.008),fbm(uv*1.2+vec2(5.2,1.3)-t*0.006));
 float billow=fbm(uv*2.4+warp*2.2);
 float detail=fbm(uv*9.0+warp*2.5);
 float smoke=billow*0.72+detail*0.28;
 float lit=fbm(uv*1.4-warp*1.3+3.0);
 float flank=smoothstep(-0.2,0.12,d.x);
 float band=1.0-smoothstep(0.09,0.26,d.y);
 float heat=clamp(max(flank*(0.5+0.5*smoothstep(0.05,0.25,d.y)),band*0.9*smoothstep(-0.5,-0.05,d.x)),0.0,1.0);
 vec3 soot=vec3(0.065,0.033,0.029);
 vec3 pall=vec3(0.20,0.06,0.045);
 vec3 ember=vec3(0.56,0.10,0.035);
 vec3 flame=vec3(1.08,0.24,0.055);
 vec3 core=vec3(1.32,0.52,0.14);
 vec3 c=mix(soot,pall,smoothstep(0.3,0.6,smoke));
 c=mix(c,ember,smoothstep(0.36,0.74,lit)*smoothstep(0.3,0.7,smoke)*(0.2+0.8*heat));
 c=mix(c,flame,smoothstep(0.25,0.62,smoke)*heat);
 c=mix(c,core,smoothstep(0.55,0.83,lit)*smoothstep(0.48,0.78,smoke)*flank*flank);
 float pocket=fbm(uv*3.6+warp*2.6+11.0);
 c*=mix(mix(0.48,1.0,smoothstep(0.28,0.53,pocket)),1.0,heat*0.45);
 float rim=smoothstep(0.42,0.52,smoke)*(1.0-smoothstep(0.52,0.62,smoke));
 c+=flame*rim*0.18*heat;
 c=mix(vec3(0.16,0.065,0.035),c,smoothstep(-0.1,0.06,d.y));
 COLOR=c;
}"""

const DIRT_SHADER := """shader_type spatial;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.y+=(noise(world.xz*3.0)-0.5)*0.055;
}
void fragment(){
 vec2 p=world.xz;
 float broad=noise(p*0.7+9.0);
 float clod=noise(p*8.0)*0.55+noise(p*23.0)*0.3+noise(p*79.0)*0.15;
 float grit=noise(p*165.0);
 float wet=smoothstep(0.48,0.75,broad);
 vec3 loam=vec3(0.105,0.072,0.048);
 vec3 dry=vec3(0.29,0.21,0.145);
 vec3 soil=mix(loam,dry,smoothstep(0.33,0.74,clod)*(1.0-0.5*wet));
 soil*=0.84+0.32*grit;
 // Shallow torn ridges and pressed track impressions continue behind the vehicle.
 float lane=1.0-smoothstep(0.26,0.38,abs(abs(p.x)-1.45));
 float behind=smoothstep(1.8,3.8,p.y);
 float tread=pow(0.5+0.5*sin(p.y*32.0+p.x*3.5),8.0)*lane*behind;
 ALBEDO=soil*(1.0-0.35*tread);
 vec2 slope=vec2(dFdx(clod),dFdy(clod));
 NORMAL=normalize(NORMAL+vec3(-slope.x,-slope.y,0.0)*0.65);
 ROUGHNESS=mix(0.98,0.62,wet)*(1.0-0.08*grit);
 SPECULAR=0.16+0.15*wet;
}"""

# Recycle whole clods behind the tank; the wrap stays outside the camera view.
const EARTH_MOTION_SHADER := """shader_type spatial;
uniform float travel_distance = 0.0;
uniform vec4 soil : source_color = vec4(0.475,0.38,0.278,1.0);
void vertex(){
 float local_z=MODEL_MATRIX[3].z+travel_distance;
 float shift=mod(local_z+travel_distance+12.0,20.0)-12.0-local_z;
 VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(0.0,0.0,shift);
}
void fragment(){ALBEDO=soil.rgb*COLOR.rgb;ROUGHNESS=1.0;}
"""

func _ready() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_material = ShaderMaterial.new()
	var sky_shader := Shader.new()
	sky_shader.code = SKY_SHADER
	_sky_material.shader = sky_shader
	sky.sky_material = _sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("7c8590")
	environment.ambient_light_energy = 0.34
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.tonemap_exposure = 1.0
	environment.glow_enabled = true
	environment.glow_intensity = 1.1
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.0
	# Low key light from the cover's left, over the photographer's shoulder: it rakes across
	# the turret slab and fender faces and leaves the glacis, roof and turret front dark.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-24,123,0)
	key.light_color = Color("f6dfbd")
	key.light_energy = 1.28
	key.shadow_enabled = true
	key.shadow_opacity = 0.82
	key.directional_shadow_max_distance = 35
	add_child(key)
	# Firelight from behind the tank on the cover's right rims the gun, turret and dust.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-14,-30,0)
	rim.light_color = Color("ff7135")
	rim.light_energy = 1.35
	rim.shadow_enabled = false
	# The rim catches the tank, crew and dust, not the churned ground at the camera's feet.
	rim.light_cull_mask = 1
	add_child(rim)
	# A restrained cool bounce keeps the gun and shaded armour dimensional.
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(-32,-65,0)
	bounce.light_color = Color("9daab6")
	bounce.light_energy = 0.26
	bounce.light_specular = 0.45
	bounce.light_cull_mask = 1
	add_child(bounce)
	_fire = OmniLight3D.new()
	_fire.position = Vector3(4.5,3.3,3.0)
	_fire.light_color = Color("ff6c27")
	_fire.light_energy = 3.0
	_fire.omni_range = 11.0
	_fire.omni_attenuation = 1.5
	add_child(_fire)
	_ground()
	_lamp_glow()
	_dust()
	_rising_smoke()
	_mud_spray()
	_debris()
	_grains()
	# Fixed seeds: the title opens on the same arrangement of dust and earth every time.
	for i in range(_particles.size()):
		_particles[i].use_fixed_seed = true
		_particles[i].seed = 1988+i*7919

# Soft amber halo around each headlight, as the cover's lamps bloom in the dust.
func _lamp_glow() -> void:
	_lamp_mount = Node3D.new()
	_lamp_mount.rotation.x = HULL_PITCH
	add_child(_lamp_mount)
	var glow := GradientTexture2D.new()
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5,0.5)
	glow.fill_to = Vector2(1.0,0.5)
	glow.gradient = Gradient.new()
	glow.gradient.colors = PackedColorArray([Color(1.0,0.75,0.35,0.9),Color(1.0,0.45,0.1,0.35),Color(1.0,0.35,0.05,0.0)])
	glow.gradient.offsets = PackedFloat32Array([0.0,0.25,1.0])
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo.albedo_texture = glow
	halo.no_depth_test = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.34,0.34)
	quad.material = halo
	for side in [-1.0,1.0]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = quad
		lamp.position = Vector3(0.865*side+(0.07 if side > 0.0 else 0.0),1.26,-3.93)
		_lamp_mount.add_child(lamp)
		# Practical lamps illuminate the dust and the ground, independently of bloom support.
		var light := SpotLight3D.new()
		light.position = lamp.position+Vector3(0,-0.025,-0.12)
		light.rotation_degrees.x = -12.0
		light.light_color = Color("ffb559")
		light.light_energy = 0.6
		light.spot_range = 3.3
		light.spot_angle = 34.0
		light.spot_angle_attenuation = 1.6
		light.spot_attenuation = 1.5
		_lamp_mount.add_child(light)

func set_active(active: bool) -> void:
	visible = active
	for particles in _particles:
		particles.emitting = active
		particles.speed_scale = 1.0 if active and _motion_enabled else 0.0

func advance(delta: float, motion_enabled := true) -> void:
	if _motion_enabled != motion_enabled:
		_motion_enabled = motion_enabled
		for particles in _particles:
			particles.speed_scale = 1.0 if visible and motion_enabled else 0.0
	if not visible or not motion_enabled:
		return
	atmosphere_time += delta
	motion_time += delta
	travel_distance = motion_time*TRAVEL_SPEED
	position.z = -travel_distance
	_earth_material.set_shader_parameter("travel_distance",travel_distance)
	_sky_material.set_shader_parameter("atmosphere_time",atmosphere_time)
	_fire.light_energy = 3.0+0.10*sin(atmosphere_time*2.3)+0.06*sin(atmosphere_time*5.7)
	for i in _particles.size():
		var particles := _particles[i]
		if String(particles.name).begins_with("RisingSmoke"):
			particles.direction = Vector3(0.32+0.065*sin(motion_time*0.45+i),0.94,0.16+0.06*cos(motion_time*0.38+i))

func pose(vehicle: Node3D, camera: Camera3D, size: Vector2) -> void:
	var t := motion_time
	vehicle.position = Vector3(0.012*sin(t*0.43),0.018*sin(t*2.4)+0.008*sin(t*4.1),-travel_distance)
	vehicle.rotation = Vector3(HULL_PITCH+0.004*sin(t*1.7),0.004*sin(t*0.37),0.005*sin(t*2.1))
	# A visible twelve-degree scan completes in about eleven seconds.
	# Working if a brief menu visit shows a full inward sweep with the muzzle in frame.
	vehicle.update_pose(TURRET-deg_to_rad(6.0)*(1.0-cos(t*0.55)),0.0,ELEVATION-deg_to_rad(1.6)*(1.0-cos(t*0.60)),GUN_YAW)
	vehicle.update_cover_motion(t,travel_distance)
	frame(camera,size)
	# Follow translation only, preserving the authored forward view and horizon.
	# Working if camera minus body stays CAMERA_POS, with no orbit or turret chase.
	camera.position += vehicle.position
	_lamp_mount.transform = Transform3D(vehicle.basis,vehicle.position-position)

func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	plane.subdivide_width = 150
	plane.subdivide_depth = 150
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
	# Churned clods: big lumps across the visible foreground (the frame's lower edge meets
	# the ground about 5 m from the camera), smaller crumbs out to and around the tracks.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1988
	var clod := SphereMesh.new()
	clod.radius = 0.1
	clod.height = 0.16
	clod.radial_segments = 6
	clod.rings = 3
	_earth_material = ShaderMaterial.new()
	var earth_shader := Shader.new()
	earth_shader.code = EARTH_MOTION_SHADER
	_earth_material.shader = earth_shader
	_earth_material.set_shader_parameter("soil",Color("796147"))
	# [count, x range, z range, size range]
	var fields := [[2600,Vector2(-2.5,7.5),Vector2(-7.8,-3.8),Vector2(0.14,0.55)],
		[1600,Vector2(-6.0,10.0),Vector2(-4.2,4.0),Vector2(0.18,0.65)]]
	for field in fields:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = clod
		mm.instance_count = field[0]
		for i in range(mm.instance_count):
			var p := Vector3(rng.randf_range(field[1].x,field[1].y),0.0,rng.randf_range(-12.0,8.0))
			var s := rng.randf_range(field[3].x,field[3].y)*(1.6 if rng.randf() < 0.08 else 1.0)
			var tilt := Basis(Vector3(rng.randf_range(-1,1),0,rng.randf_range(-1,1)).normalized(),rng.randf_range(0.0,0.6))
			var basis := tilt*Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s*rng.randf_range(0.7,1.3),s*rng.randf_range(0.4,0.75),s))
			mm.set_instance_transform(i,Transform3D(basis,p+Vector3(0,0.01,0)))
			# Wet dark loam, with every few crumbs dry and dusty.
			var dry := rng.randf() < 0.12
			mm.set_instance_color(i,Color(0.85,0.68,0.52) if dry else Color(0.28,0.24,0.22).lerp(Color(0.5,0.43,0.37),rng.randf()))
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		mm.custom_aabb = AABB(Vector3(-6.5,-0.3,-12.5),Vector3(17.0,1.5,21.0))
		node.material_override = _earth_material
		node.layers = GROUND_LAYER
		add_child(node)

# Billowing cloud sprite: fractal noise under a soft round falloff, so overlapping puffs
# read as lumpy dust rather than smooth fog.
func _cloud_texture() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 88
	noise.frequency = 0.045
	noise.fractal_octaves = 5
	var grit := FastNoiseLite.new()
	grit.seed = 7
	grit.frequency = 0.45
	var size := 128
	var image := Image.create(size,size,false,Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var d := Vector2(x-size*0.5+0.5,y-size*0.5+0.5).length()/(size*0.5)
			var falloff := clampf(1.0-d,0.0,1.0)
			var n := noise.get_noise_2d(x,y)*0.5+0.5
			# Fine grit through each puff, as the cover's dust is full of sand and crumbs.
			var grain := grit.get_noise_2d(x,y)*0.5+0.5
			var a := smoothstep(0.24,0.72,n)*pow(falloff,1.4)
			# Brighter, sunlit tops on each lump; darker undersides.
			var shade := (0.72+0.4*n-0.16*float(y)/size)*(0.94+0.12*grain)
			image.set_pixel(x,y,Color(shade,shade,shade,a))
	return ImageTexture.create_from_image(image)

func _dust() -> void:
	# Plumes thrown off the tracks, as on the cover: bright and fire-lit off the right flank,
	# dark brown under the nose, an orange haze behind the far side reaching turret height.
	puff_material = StandardMaterial3D.new()
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
		[Vector3(-2.3,1.62,-2.2),Vector3(0.35,0.2,0.3),70,3.0,1.4,Color(0.45,0.25,0.15,0.8)],
		# Fire-lit dust rising across the far cheek, right of the gun root.
		[Vector3(-1.45,1.75,-2.75),Vector3(0.15,0.15,0.15),40,3.0,0.65,Color(0.72,0.48,0.33,0.6)],
		[Vector3(3.4,0.45,-0.5),Vector3(0.9,0.35,3.0),140,3.6,2.1,Color(0.66,0.43,0.29,0.8)],
		# Fire-lit dust billowing high behind the rear of the tank, left of the bustle.
		[Vector3(2.8,2.2,3.6),Vector3(0.4,0.35,0.7),70,4.0,2.2,Color(1.0,0.56,0.26,0.6)],
		# Dark, shadowed dust rolling along the right flank under the turret overhang.
		[Vector3(2.4,1.3,1.4),Vector3(0.35,0.2,1.6),130,3.6,1.5,Color(0.24,0.15,0.1,0.9)],
		[Vector3(2.8,0.3,-4.3),Vector3(0.6,0.2,0.5),90,2.8,1.1,Color(0.7,0.46,0.3,0.75)],
		[Vector3(0.0,0.1,-4.3),Vector3(2.0,0.06,0.3),85,2.4,0.72,Color(0.24,0.16,0.10,0.64)],
		[Vector3(-0.5,0.04,-5.9),Vector3(1.4,0.02,0.4),200,3.0,0.42,Color(0.88,0.58,0.38,0.75)],
		[Vector3(0.6,0.04,-6.3),Vector3(2.4,0.02,0.5),160,3.0,0.4,Color(0.8,0.52,0.34,0.65)],
		[Vector3(-2.35,0.25,-3.9),Vector3(0.35,0.2,0.4),90,2.4,0.9,Color(0.6,0.37,0.24,0.8)],
		[Vector3(-3.0,0.3,-3.0),Vector3(0.5,0.25,1.0),70,3.0,1.2,Color(0.8,0.5,0.32,0.7)],
		[Vector3(-3.6,1.0,0.0),Vector3(1.0,0.9,2.6),60,4.0,2.6,Color(0.3,0.12,0.07,0.4)],
		[Vector3(1.0,0.06,-7.0),Vector3(4.5,0.03,1.2),160,4.0,0.55,Color(0.75,0.5,0.33,0.6)]]
	for spec in plumes:
		var dust := CPUParticles3D.new()
		var puff := QuadMesh.new()
		puff.size = Vector2(spec[4],spec[4])
		puff.material = puff_material
		dust.mesh = puff
		dust.amount = maxi(16,int(spec[2]*0.65))
		dust.lifetime = spec[3]
		dust.preprocess = spec[3]
		dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		dust.emission_box_extents = spec[1]
		dust.position = spec[0]
		# Low plumes roll along the ground; only the tall ones billow upward.
		var low: bool = spec[0].y < 0.5 or spec[1].y < 0.25
		dust.direction = Vector3(0.6,0.08,-0.3) if low else Vector3(0.3,1.0,0.6)
		dust.spread = 45.0
		dust.gravity = Vector3(0,0.0 if low else -0.2,0)
		dust.initial_velocity_min = 0.05 if low else 0.3
		dust.initial_velocity_max = 0.2 if low else 0.8
		dust.angle_min = -180.0
		dust.angle_max = 180.0
		dust.angular_velocity_min = -12.0
		dust.angular_velocity_max = 12.0
		dust.scale_amount_min = 0.7
		dust.scale_amount_max = 1.7
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

# Low-density practical smoke climbs from behind the flanks and drifts downwind.
# It shares the dust texture and explicit particle lifecycle, never a shader TIME clock.
func _rising_smoke() -> void:
	for side in [-1.0,1.0]:
		var smoke := CPUParticles3D.new()
		smoke.name = "RisingSmokeLeft" if side < 0.0 else "RisingSmokeRight"
		var puff := QuadMesh.new()
		puff.size = Vector2(1.65,1.65)
		puff.material = puff_material
		smoke.mesh = puff
		smoke.amount = 56
		smoke.lifetime = 6.0
		smoke.preprocess = 6.0
		smoke.position = Vector3(side*2.8,0.65,2.6)
		smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		smoke.emission_box_extents = Vector3(0.45,0.2,0.65)
		smoke.direction = Vector3(0.42,1.0,0.12)
		smoke.spread = 16.0
		smoke.gravity = Vector3(0.025,0.035,0.0)
		smoke.initial_velocity_min = 0.55
		smoke.initial_velocity_max = 0.9
		smoke.angle_min = -180.0
		smoke.angle_max = 180.0
		smoke.angular_velocity_min = -7.0
		smoke.angular_velocity_max = 7.0
		smoke.scale_amount_min = 0.75
		smoke.scale_amount_max = 1.15
		var growth := Curve.new()
		growth.max_value = 2.0
		growth.add_point(Vector2(0.0,0.52))
		growth.add_point(Vector2(1.0,1.65))
		smoke.scale_amount_curve = growth
		var colour := Color(0.24,0.14,0.105,0.34) if side < 0.0 else Color(0.48,0.26,0.15,0.32)
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(colour,0.0),colour,Color(colour.lightened(0.1),0.0)])
		ramp.offsets = PackedFloat32Array([0.0,0.22,1.0])
		smoke.color_ramp = ramp
		add_child(smoke)
		_particles.append(smoke)

func _grains() -> void:
	# Countless sand grains hanging in the dust: most dark, some glinting in the firelight, as
	# the cover's dust is peppered with tiny orange sparks of sand.
	var grain := QuadMesh.new()
	grain.size = Vector2(0.006,0.006)
	var lit := StandardMaterial3D.new()
	lit.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lit.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	lit.vertex_color_use_as_albedo = true
	grain.material = lit
	# [centre, extents, amount, colour]
	var clouds := [
		[Vector3(2.4,0.35,-3.2),Vector3(0.7,0.35,1.0),500,Color(1.0,0.55,0.2)],
		[Vector3(-2.4,0.35,-3.4),Vector3(0.7,0.35,1.0),400,Color(1.0,0.55,0.2)],
		[Vector3(2.8,0.6,-0.5),Vector3(0.7,0.6,3.0),500,Color(1.0,0.6,0.25)],
		[Vector3(0.0,0.25,-4.6),Vector3(3.2,0.25,0.8),1600,Color(0.12,0.08,0.06)]]
	for spec in clouds:
		var grains := CPUParticles3D.new()
		grains.mesh = grain
		grains.amount = int(spec[2]*0.35)
		grains.lifetime = 2.0
		grains.preprocess = 2.0
		grains.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		grains.emission_box_extents = spec[1]
		grains.position = spec[0]
		grains.direction = Vector3(0.2,0.6,-0.4)
		grains.spread = 60.0
		grains.gravity = Vector3(0,-1.5,0)
		grains.initial_velocity_min = 0.2
		grains.initial_velocity_max = 1.2
		grains.scale_amount_min = 0.5
		grains.scale_amount_max = 1.6
		grains.color = spec[3]
		add_child(grains)
		_particles.append(grains)

func _mud_spray() -> void:
	# Wet earth sprayed off the front of each track as clumpy dark mist, as on the cover.
	# [centre, extents, direction]
	var sprays := [
		[Vector3(1.45,0.25,-3.95),Vector3(0.35,0.15,0.15),Vector3(0.35,0.35,-1.0)],
		[Vector3(-1.45,0.25,-3.95),Vector3(0.35,0.15,0.15),Vector3(-0.35,0.35,-1.0)],
		[Vector3(2.0,0.3,-2.6),Vector3(0.15,0.25,1.0),Vector3(1.0,0.6,-0.4)]]
	for spec in sprays:
		var spray := CPUParticles3D.new()
		var clump := QuadMesh.new()
		clump.size = Vector2(0.42,0.42)
		clump.material = puff_material
		spray.mesh = clump
		spray.amount = 100
		spray.lifetime = 1.0
		spray.preprocess = 1.0
		spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		spray.emission_box_extents = spec[1]
		spray.position = spec[0]
		spray.direction = spec[2]
		spray.spread = 30.0
		spray.gravity = Vector3(0,-4.0,0)
		spray.initial_velocity_min = 1.0
		spray.initial_velocity_max = 2.6
		spray.angle_min = -180.0
		spray.angle_max = 180.0
		spray.scale_amount_min = 0.5
		spray.scale_amount_max = 1.6
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(0.16,0.1,0.07,0.0),Color(0.14,0.09,0.06,1.0),Color(0.26,0.17,0.11,0.0)])
		ramp.offsets = PackedFloat32Array([0.0,0.12,1.0])
		spray.color_ramp = ramp
		add_child(spray)
		_particles.append(spray)

func _debris() -> void:
	# Earth flung up by the tracks: small dark clods arcing out and falling back.
	var chunk := SphereMesh.new()
	chunk.radius = 0.012
	chunk.height = 0.019
	# Coarse, angular clumps rather than smooth beads.
	chunk.radial_segments = 4
	chunk.rings = 1
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color("140e0a")
	chunk.material = earth
	# [centre, extents, direction]: along each track run, and ahead of each idler where the
	# tracks throw earth toward the camera.
	var throws := [
		[Vector3(1.6,0.3,0.4),Vector3(0.3,0.2,2.8),Vector3(0.6,1.0,0.7)],
		[Vector3(-1.6,0.3,0.4),Vector3(0.3,0.2,2.8),Vector3(-0.6,1.0,0.7)],
		[Vector3(1.5,0.4,-3.6),Vector3(0.35,0.2,0.3),Vector3(0.3,1.0,-0.8)],
		[Vector3(-1.5,0.4,-3.6),Vector3(0.35,0.2,0.3),Vector3(-0.3,1.0,-0.8)],
		[Vector3(0.0,0.15,-4.2),Vector3(2.2,0.1,0.3),Vector3(0.0,0.7,-1.0)],
		[Vector3(2.8,0.2,-2.5),Vector3(0.5,0.15,1.5),Vector3(0.8,0.8,-0.4)]]
	for spec in throws:
		var debris := CPUParticles3D.new()
		debris.mesh = chunk
		debris.amount = 260
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
		debris.scale_amount_min = 0.25
		debris.scale_amount_max = 1.2
		add_child(debris)
		_particles.append(debris)
