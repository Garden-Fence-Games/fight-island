class_name TutorialDirector
extends Node
## The opening tutorial: a few lines, one after the other, on a clock — then wave 1. See
## `docs/tutorial.md`.
##
## **Nothing waits for the player.** Each line stays for its step's `seconds` and gives way to the
## next whatever the player did or did not press, so the tutorial can never be stuck on an input
## nobody makes. The island is empty while it runs: the wave director is halted, and wave 1 starts
## the moment the last line goes.
##
## After the new-run opening, not during it: `RunIntro` holds this node still while the camera
## turns, so the clock only starts once the player has a body.
##
## **And one line later, the first time a weapon is picked up** — how to switch to it and back. The
## bag has never had anything to switch between before that moment, so there is nothing to teach
## earlier. It belongs to the same runs as the opening, and waits for the opening lines to finish if
## the pickup comes while they are still up.

## The wave the tutorial hands the island to.
const FIRST_WAVE: int = 1

## The lines, in order. Data rather than code — see `data/tutorial/`.
@export var steps: Array[TutorialStep] = []
## The line shown the first time a weapon goes in the bag.
@export var on_first_weapon: TutorialStep = null

var _open: int = 0
var _clock: float = 0.0
var _running: bool = false
## Whether this run teaches at all, decided once when the run's owed tutorial is spent.
var _teaching: bool = false
var _weapon_line_owed: bool = false
var _weapon_line_clock: float = -1.0

@onready var waves: WaveDirector = get_parent().get_node_or_null("WaveDirector")
@onready var prompt: TutorialPrompt = $Prompt


func _ready() -> void:
	_teaching = _should_run()
	if _teaching and on_first_weapon != null:
		EventBus.weapon_found.connect(_on_weapon_found)
	if not _teaching or steps.is_empty():
		return
	_running = true
	# The formula must not send wave 1 underneath the lines: it starts when they are over.
	waves.halt()
	_show_open_step()


func _process(delta: float) -> void:
	_tick_the_weapon_line(delta)
	if not _running:
		return
	# Switched off mid-way is asking to skip it, and the run carries on from wave 1.
	if not _prompts_wanted():
		_finish()
		return
	_clock += delta
	var step := current_step()
	if step != null and _clock < step.seconds:
		return
	_open += 1
	_clock = 0.0
	if current_step() == null:
		_finish()
		return
	_show_open_step()


func is_running() -> bool:
	return _running


## Whether the weapon line is on screen.
func is_showing_weapon_line() -> bool:
	return _weapon_line_clock >= 0.0


## Steps aside for good without starting a wave. The headless checks that drive waves by hand call
## it: they want an empty island and a halted director, not wave 1.
func stand_down() -> void:
	_running = false
	_teaching = false
	_weapon_line_owed = false
	_weapon_line_clock = -1.0
	if prompt != null:
		prompt.hide_line()


## The line on screen, or null once there is nothing left to say.
func current_step() -> TutorialStep:
	if _open < 0 or _open >= steps.size():
		return null
	return steps[_open]


## Only a run begun from the title, like the opening it follows: a retry, a restart, a resumed run
## and every headless check go straight to the fight. Spent here so a reload does not show it twice.
func _should_run() -> bool:
	var owed := GameState.tutorial_owed
	GameState.tutorial_owed = false
	if not owed or waves == null or GameState.wave != 0:
		return false
	return _prompts_wanted()


func _show_open_step() -> void:
	var step := current_step()
	if step != null and prompt != null:
		prompt.show_line(step.prompt_key, step.prompt_actions)


## The lines are over, however they ended: the prompt goes and wave 1 starts now rather than after a
## breather. The setting is the player's and is left as it is.
func _finish() -> void:
	_running = false
	if prompt != null:
		prompt.hide_line()
	waves.start_wave(FIRST_WAVE)
	if _weapon_line_owed:
		_show_the_weapon_line()


func _on_weapon_found(_id: StringName) -> void:
	if not _teaching or on_first_weapon == null:
		return
	# Once a run: the bag only goes from nothing to switch between to something once.
	_teaching = false
	if _running:
		_weapon_line_owed = true
		return
	_show_the_weapon_line()


func _show_the_weapon_line() -> void:
	_weapon_line_owed = false
	if prompt == null or not _prompts_wanted():
		return
	_weapon_line_clock = 0.0
	# Hidden first, so a line still fading out does not keep this one from showing.
	prompt.hide_line()
	prompt.show_line(on_first_weapon.prompt_key, on_first_weapon.prompt_actions)


func _tick_the_weapon_line(delta: float) -> void:
	if _weapon_line_clock < 0.0:
		return
	_weapon_line_clock += delta
	if _weapon_line_clock < on_first_weapon.seconds and _prompts_wanted():
		return
	_weapon_line_clock = -1.0
	if prompt != null:
		prompt.hide_line()


func _prompts_wanted() -> bool:
	return bool(Settings.get_value(&"gameplay_tutorial_prompts"))
