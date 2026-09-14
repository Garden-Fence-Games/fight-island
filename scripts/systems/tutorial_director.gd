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
## **And one line per weapon, the first time that weapon is picked up** — what its own keys do. A
## weapon teaches itself when it reaches the hand rather than in an opening nobody can practise
## against: the stick is the first thing in the bag, so it carries the switch as well. The lines
## belong to the same runs as the opening, wait for it to finish if the pickup lands while it is
## still up, and queue behind each other if two weapons are found within a few seconds.

## The wave the tutorial hands the island to.
const FIRST_WAVE: int = 1

## The lines, in order. Data rather than code — see `data/tutorial/`.
@export var steps: Array[TutorialStep] = []
## One line per weapon, matched by `TutorialStep.id` against the weapon's own id. A weapon with no
## line here simply teaches nothing.
@export var weapon_lines: Array[TutorialStep] = []

var _open: int = 0
var _clock: float = 0.0
var _running: bool = false
## Whether this run teaches at all, decided once when the run's owed tutorial is spent.
var _teaching: bool = false
## The weapons already taught this run, so a weapon dropped twice only ever explains itself once.
var _taught: Dictionary = {}
## Lines found but not yet shown — during the opening, or behind one already on screen.
var _queue: Array[TutorialStep] = []
var _weapon_line: TutorialStep = null
var _weapon_line_clock: float = -1.0

@onready var waves: WaveDirector = get_parent().get_node_or_null("WaveDirector")
@onready var prompt: TutorialPrompt = $Prompt


func _ready() -> void:
	_teaching = _should_run()
	if _teaching and not weapon_lines.is_empty():
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


## Whether a weapon's line is on screen.
func is_showing_weapon_line() -> bool:
	return _weapon_line_clock >= 0.0


## The line a weapon would teach, or null for one that teaches nothing.
func line_for_weapon(id: StringName) -> TutorialStep:
	for line: TutorialStep in weapon_lines:
		if line.id == id:
			return line
	return null


## Steps aside for good without starting a wave. The headless checks that drive waves by hand call
## it: they want an empty island and a halted director, not wave 1.
func stand_down() -> void:
	_running = false
	_teaching = false
	_queue.clear()
	_weapon_line = null
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
	_show_the_next_weapon_line()


func _on_weapon_found(id: StringName) -> void:
	if not _teaching or _taught.has(id):
		return
	var line := line_for_weapon(id)
	if line == null:
		return
	# Once a run per weapon: the same stick found again has nothing left to say.
	_taught[id] = true
	_queue.append(line)
	if _running or _weapon_line_clock >= 0.0:
		return
	_show_the_next_weapon_line()


func _show_the_next_weapon_line() -> void:
	if _queue.is_empty() or prompt == null or not _prompts_wanted():
		return
	_weapon_line = _queue.pop_front()
	_weapon_line_clock = 0.0
	# Hidden first, so a line still fading out does not keep this one from showing.
	prompt.hide_line()
	prompt.show_line(_weapon_line.prompt_key, _weapon_line.prompt_actions)


func _tick_the_weapon_line(delta: float) -> void:
	if _weapon_line_clock < 0.0:
		return
	_weapon_line_clock += delta
	if _weapon_line_clock < _weapon_line.seconds and _prompts_wanted():
		return
	_weapon_line_clock = -1.0
	_weapon_line = null
	if prompt != null:
		prompt.hide_line()
	_show_the_next_weapon_line()


func _prompts_wanted() -> bool:
	return bool(Settings.get_value(&"gameplay_tutorial_prompts"))
