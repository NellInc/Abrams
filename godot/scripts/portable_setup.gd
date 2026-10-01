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
const InterfaceTheme = preload("res://scripts/pc_interface_theme.gd")
var pc_state: Label
var genesis_state: Label

func _initialize() -> void:
    root.title = ProjectSettings.get_setting("application/config/name")
    # Setup uses native-sized controls, independent of the game canvas stretch.
    root.content_scale_size=Vector2i.ZERO
    root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
    root.size = Vector2i(820, 700)
    root.min_size = Vector2i(760, 660)
    root.close_requested.connect(_close)
    auto_accept_quit = false
    var background := ColorRect.new()
    background.color = Color("172126")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.add_child(background)
    var directory := ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
    var cover_path := directory.path_join("branding/abrams-cover-remastered.png")
    if FileAccess.file_exists(cover_path):
        var image := Image.load_from_file(cover_path)
        if image!=null:
            var cover := TextureRect.new()
            cover.texture=ImageTexture.create_from_image(image)
            cover.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
            cover.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
            cover.modulate=Color(0.38,0.38,0.38,0.48)
            cover.mouse_filter=Control.MOUSE_FILTER_IGNORE
            cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
            root.add_child(cover)
    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left", "top", "right", "bottom"]:
        margin.add_theme_constant_override("margin_" + side, 28)
    root.add_child(margin)
    margin.theme=InterfaceTheme.build()
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 12)
    margin.add_child(column)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation",20)
    column.add_child(header)
    var icon_path := directory.path_join("branding/abrams-icon.png")
    if FileAccess.file_exists(icon_path):
        var icon := TextureRect.new()
        var icon_image := Image.load_from_file(icon_path)
        if icon_image!=null: icon.texture=ImageTexture.create_from_image(icon_image)
        icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.custom_minimum_size=Vector2(100,100)
        header.add_child(icon)
    var titles := VBoxContainer.new()
    titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    header.add_child(titles)
    _label(titles, root.title, 28)
    var subtitle := _label(titles, "The original PC simulation, with remastered presentation.", 15)
    subtitle.add_theme_color_override("font_color",InterfaceTheme.MUTED)
    _label(titles,"Original game by Dynamix · Published by Electronic Arts",15)
    _label(titles,"Version "+str(ProjectSettings.get_setting("application/config/version","development")),14)
    var pc_card := _card(column)
    pc_state=_label(pc_card, "Original PC game · Required", 19)
    _label(pc_card,"Choose the extracted folder containing ABRAMS.COM and SIM.EXE. Supported files are verified and copied; your source stays unchanged.",15)
    pc = _button(pc_card, "Choose PC folder…", func(): _pick("pc"))
    var genesis_card := _card(column)
    genesis_state=_label(genesis_card,"Genesis presentation · Optional",19)
    _label(genesis_card,"Add an original Genesis ROM for its artwork. Import the PC game first. Neither original game is bundled.",15)
    genesis = _button(genesis_card, "Add Genesis ROM…", func(): _pick("genesis"))
    message = _label(column, "Checking local installation…", 16)
    message.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    column.add_child(row)
    _button(row,"Keyboard controls",func(): _reference("keyboard-controls.html"))
    _button(row,"Field guide",func(): _reference("field-guide.html"))
    _button(row,"About",_about)
    play = _button(row, "Play", func(): _request(["--play"]))
    play.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    var link := LinkButton.new()
    link.text = "View project on GitHub"
    link.pressed.connect(func(): OS.shell_open("https://github.com/NellInc/Abrams"))
    column.add_child(link)
    dialog = FileDialog.new()
    dialog.theme=InterfaceTheme.build()
    dialog.access = FileDialog.ACCESS_FILESYSTEM
    dialog.size = Vector2i(720, 480)
    dialog.dir_selected.connect(func(path): _request(["--game", path]))
    dialog.file_selected.connect(func(path): _request(["--genesis", path]))
    root.add_child(dialog)
    _request(["--status"])

func _card(parent: Node) -> VBoxContainer:
    var panel := PanelContainer.new()
    parent.add_child(panel)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",8)
    panel.add_child(stack)
    return stack

func _reference(name: String) -> void:
    InterfaceTheme.show_reference(root,name)

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
    pc_state.text="Original PC game · Verified" if installed else "Original PC game · Required"
    if result is Dictionary:
        genesis_state.text="Genesis presentation · Enabled" if result.get("genesis_enabled",false) else "Genesis presentation · Optional"

func _about() -> void:
    var about := AcceptDialog.new()
    about.theme=InterfaceTheme.build()
    about.dialog_autowrap=true
    about.title = "About " + str(ProjectSettings.get_setting("application/config/name"))
    about.dialog_text = "Original game by Dynamix\nPublished by Electronic Arts\nFan Remastered by Nell Watson\nDedicated to David “Ming” Kenny\n\nIndependent, unofficial fan remaster. Original copyrights and trademarks remain with their respective rights holders. This project asserts no ownership or moral rights over the original game content and is not affiliated with or endorsed by its rights holders.\n\nRemaster contributions are free under the licences supplied in the notices folder. Original game content is required separately.\n\nhttps://github.com/NellInc/Abrams"
    root.add_child(about)
    about.popup_centered(Vector2i(600, 420))
    about.confirmed.connect(about.queue_free)
    var credits_button := about.add_button("Original game credits",false,"credits")
    credits_button.pressed.connect(func(): InterfaceTheme.show_reference(root,"credits"))

func _close() -> void:
    if busy:
        message.text = "Please close the game window, or wait for verification to finish, before quitting."
    else:
        quit()
