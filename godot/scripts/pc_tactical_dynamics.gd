extends RefCounted
## Cosmetic own-armour response. Never changes the camera, guest or save data.
const MAX_SHIFT := Vector2(0.30,1.25) # Original 320x200 source pixels.
var shift := Vector2.ZERO
var velocity := Vector2.ZERO
var target := Vector2.ZERO
var paused := false
var enabled := false
var reduced_motion := false
var shots := 0
var _epoch := -1
var _frame := -1
var _event := -1
var _render_epoch := -1
var _station := ""
var _position := Vector3.ZERO
var _speed := 0.0
var _primed := false
var _phase := 0.0
var _movement_age := 0.0

func clear_motion() -> void:
	shift=Vector2.ZERO;velocity=Vector2.ZERO;target=Vector2.ZERO
	_primed=false;_phase=0.0;_movement_age=0.0

func reset() -> void:
	clear_motion()
	_epoch=-1;_frame=-1;_event=-1;_render_epoch=-1;_station="";paused=false;enabled=false

static func position_ok(value: Variant) -> bool:
	if not value is Array or value.size()!=3:return false
	for n in value:
		if not (n is float or n is int) or not is_finite(float(n)) or absf(float(n))>1048576.0:return false
	return true

func observe(message: Dictionary, active: bool) -> void:
	# Called only after the existing audio validator accepts the complete packet.
	# Observe while disabled too: switching graphics cannot replay an old shot.
	var audio:Dictionary=message.get("audio",{})
	var state:Variant=message.get("state")
	enabled=active and not reduced_motion and state is Dictionary and message.get("program",{}).get("name")=="SIM" and audio.get("active",false)
	var epoch:=int(audio.get("epoch",-1));var frame:=int(audio.get("frame",-1))
	var render_epoch:=int(message.get("render_epoch",-1))
	var discontinuity:bool=message.get("timeline_reset",false) or epoch!=_epoch or render_epoch!=_render_epoch or frame<_frame
	if discontinuity:
		clear_motion();paused=false;_event=int(audio.get("last_id",-1))
		_epoch=epoch;_render_epoch=render_epoch
	if not enabled:
		clear_motion();_event=int(audio.get("last_id",-1));_frame=frame
		return
	if frame<=_frame and not discontinuity:return
	var station:=str(state.get("station",""))
	if station!=_station:clear_motion();_station=station
	for event:Dictionary in audio.get("events",[]):
		if int(event.get("id",-1))<=_event:continue
		if int(event.get("epoch",-2))!=epoch or frame-int(event.get("frame",-100)) not in range(0,7):continue
		# Verified original pause/resume callsites, independent of F5 sound mute.
		if event.get("kind")=="gate":
			if int(event.get("return_ip",-1))==0x4080:paused=true
			elif int(event.get("return_ip",-1))==0x4092:paused=false
		# Only the original accepted player cannon dispatch. Muting never cancels
		# a physical shot; a rejected trigger has no such dispatch.
		if not paused and event.get("kind")=="sound" and event.get("sample")=="cannon" and int(event.get("ip",-1))==0x9107 and int(event.get("return_ip",-1))==0x33c4 and int(event.get("value",-1))==1:
			velocity.y=minf(velocity.y+65.0,65.0);shots+=1
	_event=int(audio.get("last_id",_event));_frame=frame
	if paused:return
	var raw:Variant=state.get("world_position_raw")
	var speed:Variant=state.get("speed_display")
	if not position_ok(raw) or not (speed is int or speed is float) or not is_finite(float(speed)):
		clear_motion();return
	var point:=Vector3(raw[0],raw[1],raw[2])
	if _primed:
		var travel:=Vector2(point.x-_position.x,point.y-_position.y).length()
		# A checkpoint/teleport cannot masquerade as a pothole or hard braking.
		if travel>256.0 or absf(point.z-_position.z)>64.0:clear_motion()
		else:
			velocity.y+=clampf((float(speed)-_speed)*0.25,-5.0,5.0)
			if travel>0.0:
				_phase=fposmod(_phase+travel*0.075,TAU*4.0);_movement_age=0.0
				target=Vector2(sin(_phase*0.5)*0.10,sin(_phase)*0.22)
	_position=point;_speed=float(speed);_primed=true

func advance(delta: float, running: bool=true) -> bool:
	if not running or not enabled or paused or reduced_motion or not is_finite(delta) or delta<=0.0:return false
	var before:=shift
	# Finite explicit clock, no catch-up after a hidden tab, menu or focus pause.
	var elapsed:=minf(delta,0.05)
	_movement_age+=elapsed
	if _movement_age>0.10:target=Vector2.ZERO
	var steps:=ceili(elapsed/0.008)
	var dt:=elapsed/float(steps)
	for i in steps:
		velocity+=((target-shift)*1024.0-velocity*25.0)*dt
		shift+=velocity*dt
		shift=shift.clamp(-MAX_SHIFT,MAX_SHIFT)
	if target==Vector2.ZERO and shift.length_squared()<0.00000001 and velocity.length_squared()<0.000001:
		shift=Vector2.ZERO;velocity=Vector2.ZERO
	return before!=shift
