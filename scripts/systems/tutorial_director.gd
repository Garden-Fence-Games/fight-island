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

## The wave the tutorial hands the island to.
const FIRST_WAVE: int = 1

## The lines, in order. Data rather than code — see `data/tutorial/`.
@export var steps: Array[TutorialStep] = []

var _open: int = 0
var _clock: float = 0.0
var _running: bool = false

@onready var waves: WaveDirector = get_parent().get_node_or_null("WaveDirector")
@onready var prompt: TutorialPrompt = $Prompt


func _ready() -> void:
	if not _should_run():
		return
	_running = true
	# The formula must not send wave 1 underneath the lines: it starts when they are over.
	waves.halt()
	_show_open_step()


func _process(delta: float) -> void:
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


## Steps aside for good without starting a wave. The headless checks that drive waves by hand call
## it: they want an empty island and a halted director, not wave 1.
func stand_down() -> void:
	_running = false
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
	if not owed or steps.is_empty() or waves == null or GameState.wave != 0:
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


func _prompts_wanted() -> bool:
	return bool(Settings.get_value(&"gameplay_tutorial_prompts"))
