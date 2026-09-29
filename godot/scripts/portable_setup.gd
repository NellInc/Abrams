extends SceneTree
## Portable setup uses the same frozen verifier/importer as the macOS launcher.
var thread: Thread
var busy := false
var installed := false
var message: Label
var play: Button
var pc: Button
var genesis: Button
var dialog: FileDialog
var import_kind := ""
var runtime := OS.get_environment("ABRAMS_PYTHON")

func _initialize() -> void:
    root.title = ProjectSettings.get_setting("application/config/name")
    root.size = Vector2i(820, 640)
    root.min_size = Vector2i(640, 550)
    root.close_requested.connect(_close)
    auto_accept_quit = false
    var background := ColorRect.new()
    background.color = Color("172126")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 36)
    root.add_child(margin)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 18)
    margin.add_child(column)
    _label(column, root.title, 26)
    _label(column, "Remastered by Nell Watson\nOriginal game by Dynamix\nDedicated to David “Ming” Kenny", 18)
    _label(column, "A separate, supported original PC game is required. Choose its extracted folder. An original Genesis ROM is optional. Neither is included.", 16)
    message = _label(column, "Checking local installation…", 16)
    message.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    column.add_child(row)
    pc = _button(row, "Import PC folder", func(): _pick("pc"))
    genesis = _button(row, "Import Genesis ROM", func(): _pick("genesis"))
    play = _button(row, "Play", func(): _request(["--play"]))
    var about := _button(column, "About & licences", _about)
    about.alignment = HORIZONTAL_ALIGNMENT_LEFT
    var link := LinkButton.new()
    link.text = "View project on GitHub"
    link.pressed.connect(func(): OS.shell_open("https://github.com/NellInc/Abrams"))
    column.add_child(link)
    dialog = FileDialog.new()
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.size = Vector2i(720, 480)
    dialog.dir_selected.connect(func(path): _request(["--game", path]))
    dialog.file_selected.connect(func(path): _request(["--genesis", path]))
    root.add_child(dialog)
    _request(["--status"])

func _label(parent: Node, text: String, size: int) -> Label:
    var label := Label.new()
    label.text = text
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", size)
    parent.add_child(label)
    return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _pick(kind: String) -> void:
    import_kind = kind
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if kind == "pc" else FileDialog.FILE_MODE_OPEN_FILE
    dialog.title = "Choose original PC folder" if kind == "pc" else "Choose original Genesis ROM"
    dialog.popup_centered()

func _request(arguments: Array) -> void:
    if busy: return
    busy = true
    play.disabled = true
    pc.disabled = true
    genesis.disabled = true
    message.text = "Game running. Close the game window to return here." if "--play" in arguments else "Verifying originals and installation…"
    thread = Thread.new()
    thread.start(func():
        var output: Array = []
        var code := OS.execute(runtime, ["--launcher", "--invoke"] + arguments, output, true)
        _completed.call_deferred(code, "\n".join(output), "--play" in arguments))

func _completed(code: int, output: String, was_play: bool) -> void:
    thread.wait_to_finish()
    busy = false
    pc.disabled = false
    genesis.disabled = false
    if was_play and code == 0:
        _request(["--status"])
        return
    var result = JSON.parse_string(output)
    if code != 0:
        message.text = str(result.get("error", output)) if result is Dictionary else output
    elif result is Dictionary:
        installed = bool(result.get("pc_installed", false))
        message.text = "Ready. Your original files and saved profiles stay outside this installation." if installed else "Choose the supported original PC game folder to begin."
        if str(result.get("problem", "")) != "": message.text = str(result.problem)
    else:
        message.text = "Setup returned an unexpected response. Existing saves have been preserved."
    if "--setup-smoke" in OS.get_cmdline_user_args():
        if code != 0 or installed:
            quit(1)
        else:
            _about()
            create_timer(0.1).timeout.connect(func(): quit())
    play.disabled = not installed
    genesis.disabled = not installed

func _about() -> void:
    var about := AcceptDialog.new()
    about.title = "About " + str(ProjectSettings.get_setting("application/config/name"))
    about.dialog_text = "Remastered by Nell Watson\nOriginal game by Dynamix\nDedicated to David “Ming” Kenny\n\nIndependent, unofficial fan remaster. Original copyrights and trademarks remain with their respective rights holders. This project asserts no ownership or moral rights over the original game content and is not affiliated with or endorsed by its rights holders.\n\nRemaster contributions are free under the licences supplied in the notices folder. Original game content is required separately.\n\nhttps://github.com/NellInc/Abrams"
    root.add_child(about)
    about.popup_centered(Vector2i(600, 420))
    about.confirmed.connect(about.queue_free)

func _close() -> void:
    if busy:
        message.text = "Please close the game window, or wait for verification to finish, before quitting."
    else:
        quit()
