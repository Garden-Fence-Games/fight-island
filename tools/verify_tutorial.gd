extends Node
## Headless proof of the one claim `docs/tutorial.md` makes that cannot be checked by playing:
## **a good player never sees a prompt.** Every step closes retroactively, so a chained perfect hit
## landed before anything was asked for has to close three lessons in one blow.
##
## The rest is the safety net around that: wave 1 belongs to the tutorial and not to the formula, a
## passive farmer really cannot swing, the player cannot die while being taught, the parry holds the
## wave open, and a second run skips the whole thing.
##
## Whatever is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_tutorial.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SETTLE_FRAMES: int = 4
## Past the prompt delay with room to spare, in frames of a sixty-hertz headless run.
const PROMPT_FRAMES: int = 150

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _director: TutorialDirector = null
var _waves: WaveDirector = null
var _player: Player = null
var _kept_run: Dictionary = {}
var _kept_progress: Dictionary = {}
var _kept_prompts: bool = true
var _cleared_waves: Array = []


func _ready() -> void:
	_run()


func _run() -> void:
	_keep_what_is_on_this_machine()
	_check_the_steps_are_data()
	await _open_a_fresh_arena()
	if _director == null:
		_report()
		return
	_check_the_tutorial_owns_wave_one()
	await _check_a_passive_farmer_cannot_swing()
	_check_the_player_cannot_die()
	await _check_one_blow_closes_three_lessons()
	_check_the_parry_holds_the_wave()
	await _check_the_wave_hands_over()
	_check_progress_persists()
	await _check_a_second_run_skips_it()
	_put_back_what_was_on_this_machine()
	_report()


## The order and the wording live in `data/tutorial/`, so the failure this catches is a step whose
## copy was never written — a prompt that reads as its own key, mid-fight.
func _check_the_steps_are_data() -> void:
	var steps := _steps()
	if steps.size() != 7:
		_fail("expected seven tutorial steps, found %d" % steps.size())
	for step: TutorialStep in steps:
		if step.id.is_empty() or step.prompt_key.is_empty():
			_fail("a tutorial step is missing its id or its prompt key")
			continue
		if tr(step.prompt_key) == step.prompt_key:
			_fail("%s has no string for %s" % [step.id, step.prompt_key])
	if steps.size() > 0 and steps[0].travel <= 0.0:
		_fail("the movement lesson has no distance to cover, so nothing can close it")


func _check_the_tutorial_owns_wave_one() -> void:
	if not _director.is_running():
		_fail("a fresh run did not start the tutorial")
		return
	if _waves.is_running():
		_fail("the wave formula is sending wave 1 alongside the tutorial")
	if GameState.wave != 1:
		_fail("wave 1 was never announced, so the HUD and the save would disagree")
	var step := _director.current_step()
	if step == null or step.id != &"move":
		_fail("the tutorial did not open on the movement lesson")


## The whole of the first two lessons: something to hit that will not hit back. The token is the one
## gate into WindUp, so refusing it is what makes a body harmless.
func _check_a_passive_farmer_cannot_swing() -> void:
	var farmhand := load("res://data/enemies/farmhand.tres") as EnemyData
	var body := _waves.spawner.spawn_at(farmhand, Vector3(4.0, 0.5, 0.0), 1.0, 1.0, 1.0, 1.0, true)
	if body == null:
		_fail("a farmer could not be placed by hand")
		return
	await get_tree().physics_frame
	if not body.passive:
		_fail("a farmer spawned harmless did not come up harmless")
	if body.claim_token():
		_fail("a harmless farmer claimed an attack token, so he is about to swing")
	body.retire()
	await get_tree().physics_frame


func _check_the_player_cannot_die() -> void:
	if _player == null or _player.health == null:
		_fail("the arena holds no player to protect")
		return
	if not is_equal_approx(_player.health.minimum_health, 1.0):
		_fail("the player is not protected during wave 1")
	var hit := HitInfo.new()
	hit.damage = _player.health.max_health * 10.0
	_player.health.apply(hit)
	if _player.health.current_health < 1.0:
		_fail("a killing blow during the lesson took the player below one")
	if not _player.is_alive():
		_fail("the player died during wave 1")
	_player.health.current_health = _player.health.max_health


## The design target, stated as a check: a chained perfect hit closes attack, chain and perfect at
## once, and the player is never asked for any of them.
func _check_one_blow_closes_three_lessons() -> void:
	# Sprinting away at the very start, six lessons before anyone asks. It has to count when the
	# sprint lesson finally comes round, or "retroactive" only means "in the right order".
	EventBus.player_state_changed.emit(&"Sprint")
	_satisfy_movement()
	await get_tree().process_frame
	if _director.current_step() == null or _director.current_step().id != &"attack":
		_fail("walking did not close the movement lesson")
		return
	# The second blow of a chain, landed inside the perfect window.
	_player.chain_index = 1
	EventBus.attack_landed.emit(_player, 10.0, true)
	await get_tree().process_frame
	var step := _director.current_step()
	if step == null:
		_fail("one blow closed every lesson, including the ones it could not answer")
		return
	if step.id != &"dodge":
		_fail("a chained perfect hit left %s open instead of closing three lessons" % step.id)
	if _prompt().is_showing():
		_fail("a player who was never asked anything still saw a prompt")


func _check_the_parry_holds_the_wave() -> void:
	EventBus.dodge_evaded.emit()
	var step := _director.current_step()
	if step == null or step.id != &"parry":
		_fail("rolling through a swing did not open the parry lesson")
		return
	if not step.holds_wave:
		_fail("the parry lesson does not hold the wave, so it can be skipped")
	_waves.spawner.clear()
	_director._process(0.1)
	if not _cleared_waves.is_empty():
		_fail("wave 1 ended before a parry ever landed")
	if not _director.is_running():
		_fail("the tutorial gave up with the parry still unanswered")


## The parry is the last thing actually asked for: the sprint was answered before the wave started
## and must close on its own the moment it comes round.
func _check_the_wave_hands_over() -> void:
	EventBus.parry_perfect.emit()
	if _director.current_step() != null:
		_fail(
			(
				"the sprint from before the wave was not credited, %s is still open"
				% _director.current_step().id
			)
		)
	_waves.spawner.clear()
	await get_tree().process_frame
	if _director.is_running():
		_fail("every lesson was answered and the tutorial kept the island")
	if not _cleared_waves.has(1):
		_fail("wave 1 never announced itself cleared, so nothing paid out")
	if _player != null and not is_zero_approx(_player.health.minimum_health):
		_fail("the player is still protected after wave 1")


func _check_progress_persists() -> void:
	var stored: Variant = SaveManager.read_progress().get(TutorialDirector.PROGRESS_KEY, [])
	var cleared := stored as Array if stored is Array else []
	for step: TutorialStep in _steps():
		if not cleared.has(String(step.id)):
			_fail("%s was answered but not written to progress.json" % step.id)


## A second run spawns wave 1 on the formula like any other wave. Checked by building the arena
## again with the progress the first one just wrote.
func _check_a_second_run_skips_it() -> void:
	_close_the_arena()
	GameState.begin_run()
	await _open_a_fresh_arena()
	if _director == null:
		return
	if _director.is_running():
		_fail("a second run taught the tutorial again")
	if not _waves.is_running() and _waves.wave != 0:
		_fail("the wave formula did not take wave 1 back")


func _satisfy_movement() -> void:
	var step := _director.current_step()
	if step == null or _player == null:
		return
	# Two frames of walking, told as one stride: the director measures the distance itself.
	_director._process(0.016)
	_player.global_position += Vector3(step.travel * 2.0, 0.0, 0.0)
	_director._process(0.016)


func _steps() -> Array[TutorialStep]:
	if _director != null:
		return _director.steps
	var out: Array[TutorialStep] = []
	for name: String in [
		"01_move", "02_attack", "03_chain", "04_perfect", "05_dodge", "06_parry", "07_sprint"
	]:
		var step := load("res://data/tutorial/%s.tres" % name) as TutorialStep
		if step != null:
			out.append(step)
	return out


func _prompt() -> TutorialPrompt:
	return _director.prompt


func _open_a_fresh_arena() -> void:
	GameState.begin_run()
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	_director = _arena.get_node_or_null("TutorialDirector") as TutorialDirector
	_waves = _arena.get_node_or_null("WaveDirector") as WaveDirector
	_player = _arena.get_node_or_null("Player") as Player
	if _director == null or _waves == null:
		_fail("the arena is missing its tutorial or its wave director")


func _close_the_arena() -> void:
	if _arena == null:
		return
	remove_child(_arena)
	_arena.free()
	_arena = null
	_director = null
	_waves = null
	_player = null


func _keep_what_is_on_this_machine() -> void:
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	_kept_progress = SaveManager.read_json(SaveManager.PROGRESS_PATH)
	_kept_prompts = bool(Settings.get_value(&"gameplay_tutorial_prompts"))
	SaveManager.write_progress({})
	Settings.set_value(&"gameplay_tutorial_prompts", true)
	EventBus.wave_cleared.connect(_on_wave_cleared)


func _put_back_what_was_on_this_machine() -> void:
	Settings.set_value(&"gameplay_tutorial_prompts", _kept_prompts)
	_write_or_erase(SaveManager.RUN_PATH, _kept_run)
	_write_or_erase(SaveManager.PROGRESS_PATH, _kept_progress)


func _write_or_erase(path: String, data: Dictionary) -> void:
	if data.is_empty():
		SaveManager.erase(path)
		return
	SaveManager.write_json(path, data)


func _on_wave_cleared(wave: int, _reward: int) -> void:
	_cleared_waves.append(wave)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print("tutorial OK — wave 1 teaches, closes retroactively, and never asks twice")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
