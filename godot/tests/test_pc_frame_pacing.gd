extends SceneTree
const Viewer = preload("res://scripts/pc_bridge_viewer.gd")
var errors: Array[String] = []
var checks := 0

func check(ok: bool, reason: String) -> void:
	checks+=1
	if not ok and errors.size()<20: errors.append(reason)

func _initialize() -> void:
	var fps := 59.9227256774902
	var period := 1.0/fps
	for render_rate in [30.0,59.9227256774902,60.0,75.0,90.0,120.0,144.0,240.0]:
		var phase := 0.0
		var emitted := 0
		var count := int(render_rate*60)
		for i in count:
			phase+=1.0/render_rate
			if phase>=period:
				phase=Viewer.frame_remainder(phase,fps)
				emitted+=1
			check(phase>=0.0 and phase<period,"fractional phase stays bounded")
		var expected := floori(count*minf(fps/render_rate,1.0))
		check(absi(emitted-expected)<=1,"steady redraw must retain original rate: %s got %d expected %d"%[render_rate,emitted,expected])
	# This reproduces the old reset-to-zero bug independently of the new helper.
	var old_phase := 0.0
	var new_phase := 0.0
	var old_steps := 0
	var new_steps := 0
	for i in 3600:
		old_phase+=1.0/60;new_phase+=1.0/60
		if old_phase>=period: old_phase=0;old_steps+=1
		if new_phase>=period: new_phase=Viewer.frame_remainder(new_phase,fps);new_steps+=1
	check(old_steps==1800 and new_steps>=3595,"reset bug reproduces and phase-preserving path fixes it")
	for elapsed in [period,period*1.5,period*2.5,0.2,1.5,30.123,90.0]:
		var phase: float=Viewer.frame_remainder(elapsed,fps)
		check(phase>=0 and phase<period,"stalls cannot create a catch-up backlog")
		check(absf(phase-(elapsed-floorf(elapsed/period)*period))<0.000001,"remainder preserves exact fractional time")
	# Irregular render and transport stalls: at most one ordinary request per
	# available loop, and elapsed periods partition into sent/dropped/remainder.
	var phase := 0.0
	var seconds := 0.0
	var sent := 0
	var dropped := 0
	for i in 6000:
		var delta: float=[1.0/144,1.0/60,1.0/75,0.04,0.005][i%5]
		phase+=delta;seconds+=delta
		var pending := i%17<3
		if not pending and phase>=period:
			dropped+=floori(phase/period)-1
			sent+=1
			phase=Viewer.frame_remainder(phase,fps)
	check(absf(seconds/period-float(sent+dropped)-phase/period)<0.000001,"busy intervals partition without extra simulation frames")
	for error in errors: printerr("FAIL: "+error)
	print("PC_FRAME_PACING: %d checks, %d errors; old 60 Hz count %d, corrected %d"%[checks,errors.size(),old_steps,new_steps])
	quit(0 if errors.is_empty() else 1)
