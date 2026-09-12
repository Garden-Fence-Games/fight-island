extends Control
## The first thing the player touches. Nothing between the button and the fight — no character
## select, no difficulty, no save slots. See docs/menus.md.
##
## The grey wash behind the menu is a placeholder for the live arena; everything else is authored
## to read on top of a moving 3D scene, so swapping it is one node.

const RUN_SCENE: String = "res://scenes/main/main.tscn"
const FADE_IN: float = 0.7
const FADE_OUT: float = 0.35

var _leaving: bool = false
var _panel_caller: MenuEntry = null

@onready var play: MenuEntry = $Content/Column/Menu/Play
@onready var new_run: MenuEntry = $Content/Column/Menu/NewRun
@onready var options: MenuEntry = $Content/Column/Menu/Options
@onready var quit: MenuEntry = $Content/Column/Menu/Quit
@onready var version: Label = $Content/Column/Version
@onready var fade: ColorRect = $Fade
@onready var panel: Control = $Panel
@onready var panel_heading: Label = $Panel/Center/Frame/Rows/Heading
@onready var panel_body: Label = $Panel/Center/Frame/Rows/Body
@onready var panel_back: MenuEntry = $Panel/Center/Frame/Rows/Back


func _ready() -> void:
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	_apply_run_state()
	play.pressed.connect(_on_play_pressed)
	new_run.pressed.connect(_on_new_run_pressed)
	options.pressed.connect(_on_options_pressed)
	quit.pressed.connect(_on_quit_pressed)
	panel_back.pressed.connect(_close_panel)
	play.grab_focus()
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, FADE_IN)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed(&"ui_cancel"):
		# The one place in the game allowed to quit, which is why back does not simply go nowhere.
		if panel.visible:
			_close_panel()
		else:
			_on_quit_pressed()
		get_viewport().set_input_as_handled()
		return
	if panel.visible:
		return
	# Y sits on both shortcuts; the run state decides which badge is on screen, so it also decides
	# which one answers.
	var resuming: bool = GameState.run_in_progress
	if resuming and event.is_action_pressed(&"menu_new_run"):
		_on_new_run_pressed()
		get_viewport().set_input_as_handled()
	elif not resuming and event.is_action_pressed(&"menu_options"):
		_on_options_pressed()
		get_viewport().set_input_as_handled()


func _apply_run_state() -> void:
	var resuming: bool = GameState.run_in_progress
	play.label_key = "UI_CONTINUE" if resuming else "UI_PLAY"
	new_run.visible = resuming
	# Y is spent on New run once there is a run to leave behind, so Options stops claiming it.
	options.key_hint = "" if resuming else "[Y / O]"


func _open_panel(heading_key: String, body: String, caller: MenuEntry) -> void:
	_panel_caller = caller
	panel_heading.text = tr(heading_key).to_upper()
	panel_body.text = body
	panel.visible = true
	panel_back.grab_focus()


func _close_panel() -> void:
	if not panel.visible:
		return
	panel.visible = false
	if _panel_caller != null:
		_panel_caller.grab_focus()
	_panel_caller = null


func _start_run(fresh: bool) -> void:
	if _leaving:
		return
	_leaving = true
	if fresh:
		GameState.begin_run()
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE_OUT)
	tween.tween_callback(_change_to_run)


func _change_to_run() -> void:
	get_tree().change_scene_to_file(RUN_SCENE)


func _on_play_pressed() -> void:
	_start_run(not GameState.run_in_progress)


func _on_new_run_pressed() -> void:
	_start_run(true)


func _on_options_pressed() -> void:
	_open_panel("UI_OPTIONS", tr("UI_OPTIONS_EMPTY"), options)


func _on_quit_pressed() -> void:
	get_tree().quit()
