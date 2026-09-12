class_name TutorialDirector
extends Node
## Wave 1 is the tutorial. There is no tutorial scene, no training room and no mode — see
## `docs/tutorial.md`. This node hand-drives that one wave, then hands the island back to the wave
## director and never speaks again.
##
## It watches the fight on the **bus**. `attack_landed` already carries the perfect flag,
## `parry_perfect` already fires, the player already announces its own state: the tutorial observes
## the whole fight without a single system knowing it exists, and deleting this node cannot break
## combat. What it does own is the *shape* of wave 1 — which bodies stand on the island, and when
## the wave is allowed to end.
##
## The design target is a player who never sees a prompt, and it is reached by remembering rather
## than by watching. Everything the player does goes into a set of facts, and a step closes the
## moment its fact is in there — whether that happened while it was being asked for, three lessons
## earlier, or in a previous run.

## A beat of silence before a prompt appears, so a player already doing the right thing never sees
## one. It is the whole reason the prompts are bearable.
const PROMPT_DELAY: float = 1.6
## How often a missing body may be replaced. The same figure the wave director uses, and for the
## same reason: the spawn search is a navigation query and running it every frame is wasteful.
const SPAWN_INTERVAL: float = 0.6
## The one wave this node ever drives.
const WAVE: int = 1
const PROGRESS_KEY: String = "tutorial_cleared"

## The lessons, in order. Data rather than code, so re-ordering or re-wording one is an inspector
## edit — see `data/tutorial/`.
@export var steps: Array[TutorialStep] = []
## Who stands on the island during the lesson. Wave 1 is farmhands and nothing else.
@export var enemy: EnemyData = null

var _open: int = 0
var _cleared: Array = []
## Everything the player has done this wave, by the name `TutorialStep.fact()` gives it.
var _seen: Dictionary = {}
var _prompt_clock: float = 0.0
var _spawn_clock: float = 0.0
var _travelled: float = 0.0
var _last_position: Vector3 = Vector3.INF
var _running: bool = false

@onready var waves: WaveDirector = get_parent().get_node_or_null("WaveDirector")
@onready var prompt: TutorialPrompt = $Prompt


func _ready() -> void:
	if not _should_run():
		return
	_running = true
	# The formula must not also be sending wave 1. Halting is enough: the hand-over at the end
	# starts the breather, and wave 2 then arrives exactly as every later wave does.
	waves.halt()
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.dodge_evaded.connect(_on_dodge_evaded)
	EventBus.parry_perfect.connect(_on_parry_perfect)
	EventBus.player_state_changed.connect(_on_player_state_changed)
	_protect_the_player(true)
	_advance()
	EventBus.wave_started.emit(WAVE, _bodies_expected())


func _process(delta: float) -> void:
	if not _running:
		return
	_advance_travel()
	_keep_the_island_stocked(delta)
	_tick_prompt(delta)
	_finish_if_done()


## Whether this run teaches. A second run does not: the cleared steps are in `progress.json`, and
## nobody should have to sit through it twice.
func is_running() -> bool:
	return _running


## Steps aside for good, releasing everything it was holding. The headless checks that drive waves
## by hand call it: a lesson holding wave 1 open would leave every one of them waiting for a parry
## that is never coming.
func stand_down() -> void:
	_running = false
	_protect_the_player(false)
	if prompt != null:
		prompt.hide_line()


## The step being asked for, or null once there is nothing left to teach.
func current_step() -> TutorialStep:
	if _open < 0 or _open >= steps.size():
		return null
	return steps[_open]


func _should_run() -> bool:
	if steps.is_empty() or enemy == null or waves == null:
		return false
	# A resumed run is past wave 1, and one resumed *on* wave 1 was already taught in that sitting.
	if GameState.wave != 0:
		return false
	_cleared = _stored_progress()
	for step: TutorialStep in steps:
		if not _cleared.has(String(step.id)):
			return true
	return false


## Walks forward over every step that is already true — cleared in an earlier run, or answered
## earlier in this wave. This is the whole of *retroactive*: one chained perfect hit puts three
## facts in the set, and three lessons close without a word.
func _advance() -> void:
	while _open < steps.size():
		var step := steps[_open]
		var id := String(step.id)
		if not _cleared.has(id):
			var fact := step.fact()
			if fact.is_empty() or not _seen.has(fact):
				return
			_cleared.append(id)
			_write_progress()
		_open += 1
		_reset_step()


func _record(fact: StringName) -> void:
	if not _running or fact.is_empty():
		return
	_seen[fact] = true
	_advance()


func _reset_step() -> void:
	_prompt_clock = 0.0
	_travelled = 0.0
	_last_position = Vector3.INF
	if prompt != null:
		prompt.hide_line()


## The step states how many bodies should be standing, and this keeps that true.
func _keep_the_island_stocked(delta: float) -> void:
	var step := current_step()
	if step == null or waves.spawner == null:
		return
	_spawn_clock -= delta
	if _spawn_clock > 0.0 or waves.spawner.alive_count() >= step.enemies:
		return
	_spawn_clock = SPAWN_INTERVAL
	# Never an elite: a lesson is not the place to meet one, and the tutorial owns its own numbers.
	waves.spawner.spawn(
		enemy, step.health_multiplier, 1.0, 1.0, step.windup_multiplier, null, step.passive
	)


## Movement is the one lesson with no event behind it: nothing else in this game cares that the
## player walked, so there is nothing on the bus to hear and the distance is measured here.
func _advance_travel() -> void:
	var step := current_step()
	if step == null or step.trigger != TutorialStep.Trigger.NONE or step.travel <= 0.0:
		return
	var body := _player()
	if body == null:
		return
	if _last_position == Vector3.INF:
		_last_position = body.global_position
		return
	var moved := Vector2(
		body.global_position.x - _last_position.x, body.global_position.z - _last_position.z
	)
	_last_position = body.global_position
	_travelled += moved.length()
	if _travelled < step.travel:
		return
	if not _cleared.has(String(step.id)):
		_cleared.append(String(step.id))
		_write_progress()
	_open += 1
	_reset_step()
	_advance()


func _tick_prompt(delta: float) -> void:
	var step := current_step()
	if step == null or prompt == null:
		return
	if not bool(Settings.get_value(&"gameplay_tutorial_prompts")):
		return
	_prompt_clock += delta
	if _prompt_clock >= PROMPT_DELAY:
		prompt.show_line(step.prompt_key, step.prompt_actions)


## Wave 1 ends when there is nothing left to teach and nobody left standing — the same rule as every
## other wave, with the parry step allowed to hold it open until it lands.
func _finish_if_done() -> void:
	if current_step() != null:
		return
	if waves.spawner != null and waves.spawner.alive_count() > 0:
		return
	_running = false
	_protect_the_player(false)
	if prompt != null:
		prompt.hide_line()
	# Nobody should have to sit through it twice, and nobody should have to hunt for the switch
	# when a friend tries the game on their machine.
	Settings.set_value(&"gameplay_tutorial_prompts", false)
	var reward := waves.config.reward_for(WAVE, false) if waves.config != null else 0
	EventBus.wave_cleared.emit(WAVE, reward)
	waves.hand_over(WAVE)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


## Silently, and only for this wave. See `HealthComponent.minimum_health`.
func _protect_the_player(protect: bool) -> void:
	var body := _player() as Player
	if body == null or body.health == null:
		return
	body.health.minimum_health = 1.0 if protect else 0.0


func _stored_progress() -> Array:
	var stored: Variant = SaveManager.read_progress().get(PROGRESS_KEY, [])
	return stored as Array if stored is Array else []


func _write_progress() -> void:
	var progress := SaveManager.read_progress()
	progress[PROGRESS_KEY] = _cleared
	SaveManager.write_progress(progress)


## What the HUD is told is coming. The steps say how many stand at once rather than how many
## arrive, so the honest figure is the largest of them.
func _bodies_expected() -> int:
	var most := 0
	for step: TutorialStep in steps:
		most = maxi(most, step.enemies)
	return most


func _on_attack_landed(_target: Node3D, _damage: float, perfect: bool, _attack: AttackData) -> void:
	var body := _player() as Player
	# The chain index is the player's own bookkeeping, and the second blow of a chain is index 1.
	if body != null and body.chain_index > 0:
		_record(&"hit_chained")
	if perfect:
		_record(&"hit_perfect")
	_record(&"hit")


func _on_dodge_evaded() -> void:
	_record(&"evaded")


func _on_parry_perfect() -> void:
	_record(&"parried")


func _on_player_state_changed(state: StringName) -> void:
	_record(StringName("state:%s" % state))
