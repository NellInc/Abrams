extends SceneTree
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1:quit(2);return
	var file := FileAccess.open(args[0],FileAccess.WRITE)
	if file==null:quit(1);return
	file.store_string(JSON.stringify({"godot":Engine.get_license_text(),"components":Engine.get_copyright_info(),"licenses":Engine.get_license_info()},"  "))
	quit()
