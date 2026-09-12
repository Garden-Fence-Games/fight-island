class_name PauseMenu
extends CanvasLayer
## Resume · Options · Restart run · Quit to title, on `pause`. It stops the tree, which is why the
## camera rig and the hit feedback stop drifting with it — both inherit `PROCESS_MODE_PAUSABLE`
## from the root, and a camera still moving behind a pause menu feels broken even though nothing
## is wrong.
##
## The world behind it is blurred rather than hidden. The player is meant to remember what they
## are going back to.
##
## The cursor is visible at all times in this game, so there is nothing here to release.

const TITLE_SCENE: String = "res://scenes/ui/title_screen.tscn"
const RUN_SCENE: String = "res://scenes/main/main.tscn"
const OPTIONS_SCENE: String = "res://scenes/ui/options_screen.tscn"
const CONFIRM_SCENE: String = "res://scenes/ui/confirm_dialog.tscn"

var _overlay: Control = null

@onready var root: Control = $Root
@onready var heading: Label = $Root/Content/Column/Header/Title
@onready var resume: MenuEntry = $Root/Content/Column/Frame/Entries/Resume
@onready var options: MenuEntry = $Root/Content/Column/Frame/Entries/Options
@onready var restart: MenuEntry = $Root/Content/Column/Frame/Entries/Restart
@onready var quit: MenuEntry = $Root/Content/Column/Frame/Entries/Quit


func _ready() -> void:
	heading.text = tr("UI_PAUSED").to_upper()
	resume.pressed.connect(close)
	options.pressed.connect(_on_options_pressed)
	restart.pressed.connect(_on_restart_pressed)
	quit.pressed.connect(_on_quit_pressed)
	root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# While a dialog or the options screen is up, back belongs to them: one level at a time.
	if _overlay != null:
		return
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if root.visible:
			close()
		else:
			open()
		return
	if root.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func open() -> void:
	if root.visible:
		return
	root.visible = true
	get_tree().paused = true
	resume.grab_focus()


func close() -> void:
	if not root.visible:
		return
	root.visible = false
	get_tree().paused = false


func _open_overlay(scene: String) -> Control:
	var overlay := (load(scene) as PackedScene).instantiate() as Control
	_overlay = overlay
	root.add_child(overlay)
	return overlay


func _on_options_pressed() -> void:
	var screen := _open_overlay(OPTIONS_SCENE) as OptionsScreen
	screen.closed.connect(_on_overlay_closed.bind(options))


func _on_restart_pressed() -> void:
	var dialog := _open_overlay(CONFIRM_SCENE) as ConfirmDialog
	dialog.resolved.connect(_on_restart_resolved)
	dialog.ask("UI_RESTART_ASK", "UI_RESTART_BODY", "UI_RESTART_DANGER", "UI_RESTART")


func _on_quit_pressed() -> void:
	var dialog := _open_overlay(CONFIRM_SCENE) as ConfirmDialog
	dialog.resolved.connect(_on_quit_resolved)
	dialog.ask("UI_QUIT_ASK", "UI_QUIT_BODY", "UI_QUIT_DANGER", "UI_QUIT_TO_TITLE")


func _on_overlay_closed(focus: MenuEntry) -> void:
	_overlay = null
	focus.grab_focus()


func _on_restart_resolved(confirmed: bool) -> void:
	_on_overlay_closed(restart)
	if not confirmed:
		return
	GameState.begin_run()
	_leave(RUN_SCENE)


## Quitting to the title keeps the run: the title turns Play into Continue precisely because the
## player has one waiting. Ending it is what New run is for.
func _on_quit_resolved(confirmed: bool) -> void:
	_on_overlay_closed(quit)
	if not confirmed:
		return
	_leave(TITLE_SCENE)


func _leave(scene: String) -> void:
	close()
	get_tree().change_scene_to_file(scene)
