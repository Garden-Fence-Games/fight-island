extends Control
## The first thing the player touches. Nothing between the button and the fight — no character
## select, no difficulty, no save slots. See docs/menus.md.
##
## The grey wash behind the menu is a placeholder for the live arena; everything else is authored
## to read on top of a moving 3D scene, so swapping it is one node.

const RUN_SCENE: String = "res://scenes/main/main.tscn"
const OPTIONS_SCENE: String = "res://scenes/ui/options_screen.tscn"
const FADE_IN: float = 0.7
const FADE_OUT: float = 0.35

var _leaving: bool = false
var _options_screen: OptionsScreen = null

@onready var play: MenuEntry = $Content/Column/Menu/Play
@onready var new_run: MenuEntry = $Content/Column/Menu/NewRun
@onready var options: MenuEntry = $Content/Column/Menu/Options
@onready var quit: MenuEntry = $Content/Column/Menu/Quit
@onready var version: Label = $Content/Column/Version
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	_apply_run_state()
	play.pressed.connect(_on_play_pressed)
	new_run.pressed.connect(_on_new_run_pressed)
	options.pressed.connect(_on_options_pressed)
	quit.pressed.connect(_on_quit_pressed)
	play.grab_focus()
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, FADE_IN)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if _options_screen != null:
		return
	if event.is_action_pressed(&"ui_cancel"):
		# The one place in the game allowed to quit, which is why back does not simply go nowhere.
		_on_quit_pressed()
		get_viewport().set_input_as_handled()
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
	if _options_screen != null:
		return
	_options_screen = (load(OPTIONS_SCENE) as PackedScene).instantiate() as OptionsScreen
	_options_screen.closed.connect(_on_options_closed)
	add_child(_options_screen)


func _on_options_closed() -> void:
	_options_screen = null
	options.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
