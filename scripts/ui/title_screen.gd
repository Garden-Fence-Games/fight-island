extends Control
## The first thing the player touches. Four entries and nothing between the button and the fight —
## no character select, no difficulty, no save slots. See docs/menus.md.
##
## The grey wash behind the menu is a placeholder for the live arena; everything else is authored
## to read on top of a moving 3D scene, so swapping it is one node.

const RUN_SCENE: String = "res://scenes/main/main.tscn"
const FADE_IN: float = 0.7
const FADE_OUT: float = 0.35
const FOCUS_POP: float = 1.035
const FOCUS_TWEEN: float = 0.12

## Mirrors the "Engine and tools" table of docs/credits.md. A file with no row there does not ship.
const CREDITS_LINES: Array[String] = [
	"Godot Engine 4.7.2 — MIT",
	"Jolt Physics — MIT",
	"icon.svg, Godot project template — MIT",
]

var _leaving: bool = false
var _panel_caller: Button = null

@onready var entries: VBoxContainer = $Content/Column/Menu
@onready var play: Button = $Content/Column/Menu/Play
@onready var new_run: Button = $Content/Column/Menu/NewRun
@onready var options: Button = $Content/Column/Menu/Options
@onready var credits: Button = $Content/Column/Menu/Credits
@onready var quit: Button = $Content/Column/Menu/Quit
@onready var version: Label = $Version
@onready var fade: ColorRect = $Fade
@onready var panel: Control = $Panel
@onready var panel_heading: Label = $Panel/Center/Frame/Rows/Heading
@onready var panel_body: Label = $Panel/Center/Frame/Rows/Body
@onready var panel_back: Button = $Panel/Center/Frame/Rows/Back


func _ready() -> void:
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "")
	_dress_buttons()
	_apply_run_state()
	panel_back.pressed.connect(_close_panel)
	play.pressed.connect(_on_play_pressed)
	new_run.pressed.connect(_on_new_run_pressed)
	options.pressed.connect(_on_options_pressed)
	credits.pressed.connect(_on_credits_pressed)
	quit.pressed.connect(_on_quit_pressed)
	play.grab_focus()
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, FADE_IN)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	# Swallowed even with nothing open: back on the title screen must never reach the desktop.
	if panel.visible:
		_close_panel()
	get_viewport().set_input_as_handled()


func _dress_buttons() -> void:
	for entry: Button in _focusable_buttons():
		entry.resized.connect(_on_entry_resized.bind(entry))
		entry.focus_entered.connect(_on_entry_focus_entered.bind(entry))
		entry.focus_exited.connect(_on_entry_focus_exited.bind(entry))
		entry.mouse_entered.connect(entry.grab_focus)


func _focusable_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in entries.get_children():
		if child is Button:
			buttons.append(child as Button)
	buttons.append(panel_back)
	return buttons


func _apply_run_state() -> void:
	var resuming: bool = GameState.run_in_progress
	play.text = tr("UI_CONTINUE") if resuming else tr("UI_PLAY")
	new_run.visible = resuming


func _open_panel(heading: String, body: String, caller: Button) -> void:
	_panel_caller = caller
	panel_heading.text = heading
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


func _on_entry_resized(entry: Button) -> void:
	# Pivot on the left edge so the focus pop pushes the word outwards, never off its column.
	entry.pivot_offset = Vector2(0.0, entry.size.y * 0.5)


func _on_entry_focus_entered(entry: Button) -> void:
	create_tween().tween_property(entry, "scale", Vector2(FOCUS_POP, FOCUS_POP), FOCUS_TWEEN)


func _on_entry_focus_exited(entry: Button) -> void:
	create_tween().tween_property(entry, "scale", Vector2.ONE, FOCUS_TWEEN)


func _on_play_pressed() -> void:
	_start_run(not GameState.run_in_progress)


func _on_new_run_pressed() -> void:
	_start_run(true)


func _on_options_pressed() -> void:
	_open_panel(tr("UI_OPTIONS"), tr("UI_OPTIONS_EMPTY"), options)


func _on_credits_pressed() -> void:
	_open_panel(tr("UI_CREDITS"), "\n".join(CREDITS_LINES), credits)


func _on_quit_pressed() -> void:
	get_tree().quit()
