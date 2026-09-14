extends Control
## The first thing the player touches. Nothing between the button and the fight — no character
## select, no difficulty, no save slots. See docs/menus.md.
##
## Behind the menu is the island itself, blurred and dimmed — the same scene the fight happens on
## and the same shader the pause menu uses, so the title can never look like a different game than
## the one that follows, and the two treatments cannot drift apart.

const RUN_SCENE: String = "res://scenes/main/main.tscn"
const OPTIONS_SCENE: String = "res://scenes/ui/options_screen.tscn"
const CREDITS_SCENE: String = "res://scenes/ui/credits_screen.tscn"
const VISTA_SCENE: String = "res://scenes/world/vista.tscn"
const HEADLESS: String = "headless"
const FADE_IN: float = 0.7
const FADE_OUT: float = 0.35

var _leaving: bool = false
var _options_screen: OptionsScreen = null
var _credits_screen: CreditsScreen = null

@onready var play: MenuEntry = $Content/Column/Menu/Play
@onready var new_run: MenuEntry = $Content/Column/Menu/NewRun
@onready var options: MenuEntry = $Content/Column/Menu/Options
@onready var quit: MenuEntry = $Content/Column/Menu/Quit
@onready var version: Label = $Content/Column/Footer/Version
@onready var credits: MenuEntry = $Content/Column/Footer/Credits
@onready var fade: ColorRect = $Fade


func _ready() -> void:
	_raise_the_island()
	version.text = "v%s" % UpdateCheck.current_version()
	_ask_whether_there_is_a_newer_build()
	_apply_run_state()
	play.pressed.connect(_on_play_pressed)
	new_run.pressed.connect(_on_new_run_pressed)
	options.pressed.connect(_on_options_pressed)
	quit.pressed.connect(_on_quit_pressed)
	credits.pressed.connect(_on_credits_pressed)
	play.grab_focus()
	fade.color.a = 1.0
	create_tween().tween_property(fade, "color:a", 0.0, FADE_IN)
	UiSounds.arm(self)


## The only network request the game makes, and it is allowed to come to nothing. Nothing here
## waits on it: the title is up and playable before it is sent, and a failure of any kind — offline,
## itch down, a reply nobody can parse — leaves the footer exactly as it was.
func _ask_whether_there_is_a_newer_build() -> void:
	var check := UpdateCheck.new()
	check.name = "UpdateCheck"
	add_child(check)
	check.newer_version_found.connect(_on_newer_version_found)
	check.ask()


func _on_newer_version_found(published: String) -> void:
	# Beside the version rather than over the menu. A player who came here to play should not have
	# to dismiss anything, and one who came here to check will read the footer.
	version.text = (
		"v%s — %s" % [UpdateCheck.current_version(), tr("UI_UPDATE_AVAILABLE").format([published])]
	)


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if _options_screen != null or _credits_screen != null:
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


## In code rather than in the scene, for one reason: a headless boot has no renderer to draw an
## island with, and the dummy one answers a material query on it with an error that is about the
## absence of a GPU rather than about the game. It is decoration — everything the boot check is
## actually checking is the menu in front of it.
func _raise_the_island() -> void:
	if DisplayServer.get_name() == HEADLESS:
		return
	var vista := (load(VISTA_SCENE) as PackedScene).instantiate()
	add_child(vista)
	# Behind everything, including the blur that softens it.
	move_child(vista, 0)


func _apply_run_state() -> void:
	var resuming: bool = GameState.run_in_progress
	play.label_key = "UI_CONTINUE" if resuming else "UI_PLAY"
	new_run.visible = resuming
	# Y is spent on New run once there is a run to leave behind, so Options stops claiming it.
	options.action = "" if resuming else "menu_options"


func _start_run(fresh: bool) -> void:
	if _leaving:
		return
	_leaving = true
	if fresh:
		# A run begun here is the only kind that opens on the player waking up.
		GameState.begin_run(true)
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


## The credits sit beside the version rather than in the menu: the column holds three rows without
## crowding the logo, and a fourth that nobody opens twice is not worth the height. See
## `docs/menus.md`.
func _on_credits_pressed() -> void:
	if _credits_screen != null:
		return
	_credits_screen = (load(CREDITS_SCENE) as PackedScene).instantiate() as CreditsScreen
	_credits_screen.closed.connect(_on_credits_closed)
	add_child(_credits_screen)


func _on_credits_closed() -> void:
	_credits_screen = null
	credits.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
