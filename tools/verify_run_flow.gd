extends Node
## Headless proof of who outranks whom between two waves. `RunFlow` owns two screens and they can be
## asked for at the same moment: a wave clears while the player is still going under.
##
## **A death outranks everything.** It is the one thing that ends a run, and a run that cannot end
## is the only unrecoverable state the game has — no summary, no `end_run`, and a `run.json` that
## outlives the player and offers Continue into a corpse.
## Run: godot --headless --path . res://tools/verify_run_flow.tscn

const FLOW_SCENE: String = "res://scenes/main/main.tscn"
## Comfortably past `RunFlow.DELAY`, so a screen that was going to open has opened.
const PAST_THE_BEAT: float = 1.6

var _failures: PackedStringArray = []
var _flow: RunFlow = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	await _check_a_death_refuses_a_merchant_that_has_not_opened()
	await _check_a_death_takes_down_a_merchant_that_has()
	_put_the_run_back()
	_report()


## The race as it actually happens: the wave clock runs out while the player is drowning. Both
## screens are asked for within the same beat, and the merchant's beat started first.
func _check_a_death_refuses_a_merchant_that_has_not_opened() -> void:
	_start_a_run_with_money()
	EventBus.wave_cleared.emit(2, 50)
	EventBus.player_died.emit()
	await _wait(PAST_THE_BEAT)
	if _screen_is(MerchantScreen):
		_fail("the merchant opened over a dead player, and the run can no longer be ended")
	if not _screen_is(RunSummary):
		_fail("a death that was seen did not bring up the summary")
	_check_the_run_is_over("after a death raced a cleared wave")
	_tear_down()


## The wider window: the merchant is already up when the blow lands. Deferring to it is what left a
## run nothing could finish.
func _check_a_death_takes_down_a_merchant_that_has() -> void:
	_start_a_run_with_money()
	EventBus.wave_cleared.emit(2, 50)
	await _wait(PAST_THE_BEAT)
	if not _screen_is(MerchantScreen):
		_fail("the merchant did not open on a cleared wave, so this check proves nothing")
		_tear_down()
		return
	EventBus.player_died.emit()
	await _wait(PAST_THE_BEAT)
	if _screen_is(MerchantScreen):
		_fail("a merchant already open survived the player's death")
	if not _screen_is(RunSummary):
		_fail("a death under an open merchant never reached the summary")
	_check_the_run_is_over("after a death under an open merchant")
	_tear_down()


func _check_the_run_is_over(when: String) -> void:
	if GameState.run_in_progress:
		GameState.end_run()
		_fail("the run was still in progress %s" % when)
	if SaveManager.has_run():
		SaveManager.clear_run()
		_fail("run.json outlived the player %s, so the title would offer Continue" % when)


func _start_a_run_with_money() -> void:
	GameState.begin_run()
	EventBus.wave_started.emit(2, 8)
	GameState.earn(1000)
	if not GameState.can_buy_anything():
		_fail("the player cannot afford anything, so no merchant would open either way")
	var main := (load(FLOW_SCENE) as PackedScene).instantiate()
	add_child(main)
	_flow = main.get_node_or_null(^"RunFlow") as RunFlow
	if _flow == null:
		_fail("the run scene holds no RunFlow")


func _screen_is(type: Variant) -> bool:
	if _flow == null:
		return false
	for child: Node in _flow.get_children():
		if is_instance_of(child, type):
			return true
	return false


func _tear_down() -> void:
	get_tree().paused = false
	if _flow != null and _flow.get_parent() != null:
		_flow.get_parent().queue_free()
	_flow = null
	await get_tree().process_frame


## Unscaled and running while paused: both screens stop the tree, and this check has to outlive it.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _put_the_run_back() -> void:
	get_tree().paused = false
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _fail(message: String) -> void:
	_failures.append("  " + message)


func _report() -> void:
	if _failures.is_empty():
		print("run flow OK — a death outranks the merchant, and the run it ends stays ended")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
