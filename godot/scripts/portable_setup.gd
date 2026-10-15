extends SceneTree
## Portable setup uses the same frozen verifier/importer as the macOS launcher.
var thread: Thread
var busy := false
var installed := false
var message: Label
var play: Button
var pc: Button
var genesis: Button
var recheck: Button
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
    root.min_size = Vector2i(600, 420)
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
    var shell := VBoxContainer.new()
    shell.add_theme_constant_override("separation", 12)
    margin.add_child(shell)
    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    shell.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    scroll.add_child(column)
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
    recheck = _button(shell, "Recheck installation", func(): _request(["--status"]))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    shell.add_child(row)
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
    if busy: return
    import_kind = kind
    dialog.clear_filters()
    if kind == "genesis":
        dialog.add_filter("*.md, *.bin, *.gen", "Raw Genesis ROM (verified revision)")
    dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR if kind == "pc" else FileDialog.FILE_MODE_OPEN_FILE
    dialog.title = "Choose extracted folder containing ABRAMS.COM and SIM.EXE" if kind == "pc" else "Choose original raw Genesis ROM (.md, .bin, .gen)"
    dialog.popup_centered()

func _sync_controls() -> void:
    play.disabled = busy or not installed
    pc.disabled = busy
    genesis.disabled = busy or not installed
    recheck.disabled = busy
    pc_state.text="Original PC game · Verified" if installed else "Original PC game · Required"
    if not busy and root.gui_get_focus_owner() == null:
        if installed: play.grab_focus.call_deferred()
        else: pc.grab_focus.call_deferred()

func _failed(text: String) -> void:
    busy = false
    installed = false
    message.text = text
    genesis_state.text = "Genesis presentation · Optional"
    _sync_controls()
    if "--setup-smoke" in OS.get_cmdline_user_args(): quit(1)

func _runtime_available() -> bool:
    return runtime != "" and FileAccess.file_exists(runtime)

func _start_worker(work: Callable) -> Error:
    return thread.start(work)

func _request(arguments: Array) -> void:
    if busy: return
    if not _runtime_available():
        _failed("The bundled runtime is missing. Restore or reinstall the portable package, then choose Recheck installation. Your originals and saves are unchanged.")
        return
    busy = true
    _sync_controls()
    message.text = "Game running. Close the game window to return here." if "--play" in arguments else "Verifying originals and installation…"
    thread = Thread.new()
    var error := _start_worker(func():
        var result := _run_runtime(PackedStringArray(["--launcher", "--invoke"] + arguments))
        _completed.call_deferred(result[0], result[1], "--play" in arguments))
    if error != OK:
        thread = null
        _failed("Setup could not start verification (error %d). Close unused applications and choose Recheck installation." % error)

## Worker-thread request. OS.execute with an output array goes through
## /bin/sh on Linux and macOS, which would expand $, backticks and quotes in a
## chosen folder or ROM path. execute_with_pipe uses fork/exec, with no shell.
## Both pipes are drained so a full stderr pipe cannot stall the runtime.
func _run_runtime(arguments: PackedStringArray) -> Array:
    var process: Dictionary = OS.execute_with_pipe(runtime, arguments, false)
    if process.is_empty():
        return [-1, "Setup could not start the bundled runtime. Restore the portable package, then choose Recheck installation."]
    var stdio: FileAccess = process.stdio
    var errors: FileAccess = process.stderr
    var pid := int(process.pid)
    var output := PackedByteArray()
    var diagnostics := PackedByteArray()
    while true:
        var running := OS.is_process_running(pid)
        var chunk := stdio.get_buffer(65536)
        var error_chunk := errors.get_buffer(65536)
        output.append_array(chunk)
        diagnostics.append_array(error_chunk)
        if chunk.is_empty() and error_chunk.is_empty():
            # Read once more after exit, so nothing written before it is lost.
            if not running: break
            OS.delay_msec(10)
    stdio.close()
    errors.close()
    var code := OS.get_process_exit_code(pid)
    var text := output.get_string_from_utf8()
    # Success replies are JSON on stdout; a silent failure may explain itself on stderr.
    if code != 0 and text.strip_edges() == "": text = diagnostics.get_string_from_utf8()
    return [code, text]

func _valid_status(result: Variant) -> bool:
    return result is Dictionary and typeof(result.get("pc_installed")) == TYPE_BOOL and typeof(result.get("genesis_enabled")) == TYPE_BOOL

func _completed(code: int, output: String, was_play: bool) -> void:
    if thread != null:
        thread.wait_to_finish()
        thread = null
    busy = false
    if was_play and code == 0:
        _request(["--status"])
        return
    var result = JSON.parse_string(output)
    installed = false
    genesis_state.text = "Genesis presentation · Optional"
    if code != 0:
        message.text = str(result.get("error", output)) if result is Dictionary else output
        if message.text.strip_edges() == "": message.text = "Setup failed. Choose Recheck installation to try again."
    elif _valid_status(result):
        installed = result.pc_installed
        message.text = "Ready. Your original files and saved profiles stay outside this installation." if installed else "Choose the supported original PC game folder to begin."
        if str(result.get("problem", "")) != "": message.text = str(result.problem)
        genesis_state.text="Genesis presentation · Enabled" if installed and result.genesis_enabled else "Genesis presentation · Optional"
    else:
        message.text = "Setup returned an unexpected response. Choose Recheck installation. Existing saves have been preserved."
    _sync_controls()
    if "--setup-smoke" in OS.get_cmdline_user_args():
        if code != 0 or installed or not _valid_status(result):
            quit(1)
        else:
            _about()
            # CI requires this receipt: Godot exits 0 even when a script fails to parse.
            create_timer(0.1).timeout.connect(func():
                print("PORTABLE_SETUP_SMOKE: PASS")
                quit())

func _about() -> void:
    var about := AcceptDialog.new()
    about.theme=InterfaceTheme.build()
    about.dialog_autowrap=true
    about.title = "About " + str(ProjectSettings.get_setting("application/config/name"))
    about.dialog_text = "Original game by Dynamix\nPublished by Electronic Arts\nFan Remastered by Nell Watson\nDedicated to David “Ming” Kenny\n\nIndependent, unofficial fan remaster. Original copyrights and trademarks remain with their respective rights holders. This project asserts no ownership or moral rights over the original game content and is not affiliated with or endorsed by its rights holders.\n\nRemaster contributions are free under the licences supplied in the notices folder. Original game content is required separately.\n\nhttps://github.com/NellInc/Abrams"
    root.add_child(about)
    about.popup_centered(Vector2i(600, 420))
    about.confirmed.connect(about.queue_free)
    about.close_requested.connect(about.queue_free)
    about.canceled.connect(about.queue_free)
    var credits_button := about.add_button("Original game credits",false,"credits")
    credits_button.pressed.connect(func(): InterfaceTheme.show_reference(root,"credits"))

func _close() -> void:
    if busy:
        message.text = "Please close the game window, or wait for verification to finish, before quitting."
    else:
        quit()
