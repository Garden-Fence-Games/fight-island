extends Node
## The fight, with **every accessibility switch at its most reductive at once**, and the three
## things a player has to read still readable.
##
## Each switch is already held on its own: `verify_vfx` proves the shake slider means nought at
## nought and that reduce-flashing damps the flare without taking the debris, `verify_feel` proves a
## hitstop never eats a press, `verify_settings` proves no switch is dead. What none of them asks is
## the question a player who needs all of them asks: **is the game still legible with all of them
## turned down together?** A signal that survives each switch alone can still be the only one left,
## and then be taken by the next.
##
## So the switches go to their extremes and stay there for the whole run of this, and what is
## checked is what remains: the telegraph, the difference between a perfect hit and an ordinary one,
## and a clock that is never left stopped.
##
## Run: godot --headless --path . res://tools/verify_access.tscn

## **The whole game, not the arena.** `HitFeedback` — the one thing that turns a hitstop request
## into a slowed clock — is a child of `main.tscn`, so a check that loaded the arena would emit into
## a bus nobody is listening on and pass without testing anything. `verify_feel` says the same in
## its own docstring, and this check made the mistake anyway before the mutation caught it.
const MAIN: String = "res://scenes/main/main.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const IMPACT: String = "res://scenes/fx/impact.tscn"
## A wind-up stretched, so the lean can be sampled over frames rather than caught between two.
const SLOW_WINDUP: float = 2.0
## How far into a wind-up the body must have leaned before it counts as a telegraph. Well under the
## full lean, because what is being asked is whether it happens at all with the switches down.
const LEANS_AT_LEAST: float = 0.05
## Hitstops thrown at the clock in a row. One proves the switch, a burst proves nothing accumulates
## behind it — a counter that only ever goes up is how a clock ends up stopped for good.
const A_BURST: int = 12
## What a perfect hit has to differ by, beyond colour and beyond the flare. Both of those are the
## two things these switches touch, so neither may be the whole of the difference.
const TELLS: int = 2

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _pool: EffectPool = null
var _kept: Dictionary = {}
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	# A fresh run, and whatever this machine had goes back at the end. Without it the bag is the one
	# left in `run.json` — the first version of this check swung a gun with an empty magazine and
	# reported that the accessibility switches had broken combat.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	GameState.begin_run()
	var main := (load(MAIN) as PackedScene).instantiate()
	add_child(main)
	_arena = main.get_node_or_null(^"Arena") as Node3D
	if _arena == null:
		_fail("the game has no arena")
		_leave_the_machine_as_it_was()
		_report()
		return
	_stand_everything_down()
	_turn_everything_down()
	await get_tree().process_frame
	_pool = _arena.get_node_or_null("Effects") as EffectPool
	if _pool == null:
		_fail("the arena has no effect pool")
		_leave_the_machine_as_it_was()
		_report()
		return

	await _check_the_telegraph_survives_every_switch()
	_check_a_perfect_hit_still_says_so()
	await _check_the_clock_is_never_left_stopped()
	await _check_the_player_can_still_fight()
	_put_the_switches_back()
	_put_the_run_back()
	_report()


## **The telegraph is geometry**, so nothing here should be able to touch it — which is exactly why
## it is worth asking. It is the one signal the game cannot be played without, and every switch that
## exists was written to remove something visual.
func _check_the_telegraph_survives_every_switch() -> void:
	var farmer := _a_farmer_winding_up()
	if farmer == null:
		return
	var leaned := 0.0
	for _frame: int in int(farmer.windup() * 60.0) + 2:
		await get_tree().physics_frame
		if farmer.machine.current is EnemyWindUp:
			leaned = maxf(leaned, EnemyWindUp.REARS_BACK * farmer.visual.rotation.x)
	if leaned < LEANS_AT_LEAST:
		_fail(
			(
				"with every switch down a farmer leaned %.3f rad into his swing, and a telegraph is %.3f"
				% [leaned, LEANS_AT_LEAST]
			)
		)
	_stand_him_down(farmer)


## Damage numbers are off by default and the design says the effect carries the difference. With
## reduce-flashing on, the flare is damped and the colour is the thing a colourblind player cannot
## read — so what is left has to be **motion and quantity**, and more than one of it.
func _check_a_perfect_hit_still_says_so() -> void:
	var scene := load(IMPACT) as PackedScene
	var plain := _pool.lease(scene) as Impact
	var perfect := _pool.lease(scene) as Impact
	if plain == null or perfect == null:
		_fail("the pool would not lease two impacts")
		return
	plain.play(Vector3.ZERO, false)
	perfect.play(Vector3.ZERO, true)
	var tells := 0
	if perfect.debris.amount > plain.debris.amount:
		tells += 1
	if perfect.debris.initial_velocity_max > plain.debris.initial_velocity_max:
		tells += 1
	if perfect.debris.lifetime > plain.debris.lifetime:
		tells += 1
	if tells < TELLS:
		_fail(
			(
				(
					"with the flare damped, a perfect hit differs from an ordinary one in %d ways that "
					+ "are not colour, and it needs %d"
				)
				% [tells, TELLS]
			)
		)
	if not perfect.debris.emitting:
		_fail("with the switches down a perfect hit threw no debris at all")
	plain.finish_now()
	perfect.finish_now()


## A switch that is off has to leave the clock alone — and leave it alone **after a burst**, because
## the thing that stops a clock for good is a counter that goes up without coming back down.
func _check_the_clock_is_never_left_stopped() -> void:
	for _stop: int in A_BURST:
		EventBus.hitstop_requested.emit(0.05)
	await get_tree().process_frame
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fail("hitstop is off and the clock is running at %.2f" % Engine.time_scale)
	# Long enough for anything that did start to have ended.
	await get_tree().create_timer(0.3, true, false, true).timeout
	if not is_equal_approx(Engine.time_scale, 1.0):
		_fail("the clock settled at %.2f with hitstop off" % Engine.time_scale)


## The floor under all of it: the switches are meant to take away *emphasis*, never the fight. A
## body that cannot be hit is not an accessible game, it is a broken one.
func _check_the_player_can_still_fight() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		_fail("the arena has no player to swing")
		return
	var farmer := _a_farmer_winding_up(1.0)
	if farmer == null:
		return
	# Placed and swung the way `verify_combat` does it: the player faces -Z and the fist reaches a
	# little over a metre, and the swing is asked for through the state rather than through a press
	# the machine has to be running to pick up.
	# Fists, and said out loud: a bag carrying the gun would swing an empty magazine and land nothing
	# for a reason that has nothing to do with what is being checked.
	GameState.loadout.equip(Arsenal.STARTING)
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	farmer.global_position = Vector3(0.0, 0.0, -1.0)
	farmer.machine.current.transition_to(&"Idle")
	await get_tree().physics_frame
	var before := farmer.health.current_health
	var jab := player.weapon.attack_at(0)
	player.machine.current.transition_to(&"Attack", {"index": 0, "perfect": false})
	var elapsed := 0.0
	while elapsed < jab.windup + jab.active + 0.1:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0
	if farmer.health.current_health >= before:
		_fail("with every switch down a swing took nothing off a farmer standing in front of it")
	_stand_him_down(farmer)


## Every accessibility switch at the end of its travel, all at once: no shake, no hitstop, flashing
## reduced, and a hold asked for on every confirmation.
func _turn_everything_down() -> void:
	for key: StringName in [
		&"access_screen_shake",
		&"access_hitstop",
		&"access_hold_to_confirm",
		&"access_reduce_flashing",
	]:
		_kept[key] = Settings.get_value(key)
	Settings.set_value(&"access_screen_shake", 0)
	Settings.set_value(&"access_hitstop", false)
	Settings.set_value(&"access_hold_to_confirm", true)
	Settings.set_value(&"access_reduce_flashing", true)


## Both halves, from one place. Each early return used to undo one of them and not the other, and
## the expensive one is the run: `begin_run()` has already written a fresh `run.json` by the time
## either branch is reached, so bailing out without putting it back **deletes the player's saved
## game** — a check that eats a run is worse than no check.
func _leave_the_machine_as_it_was() -> void:
	_put_the_switches_back()
	_put_the_run_back()


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.erase(SaveManager.RUN_PATH)
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _put_the_switches_back() -> void:
	for key: StringName in _kept:
		Settings.set_value(key, _kept[key])


func _stand_everything_down() -> void:
	var director := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if director != null:
		director.halt()
		director.process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial := _arena.get_node_or_null("TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
		tutorial.process_mode = Node.PROCESS_MODE_DISABLED


## A body leased straight from the pool and told to wind up. Set to process always, because the pool
## lives under a director that has been stood down and a revived body inherits that.
func _a_farmer_winding_up(windup: float = SLOW_WINDUP) -> Enemy:
	var director := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if director == null:
		_fail("the arena has no wave director to lease a body from")
		return null
	var farmer := director.spawner.spawn_at(
		load(FARMHAND) as EnemyData, Vector3(0.0, 0.0, -6.0), 1.0, 1.0, 1.0, windup
	)
	if farmer == null or farmer.visual == null:
		_fail("could not lease a farmer to watch")
		return null
	farmer.process_mode = Node.PROCESS_MODE_ALWAYS
	farmer.machine.current.transition_to(&"WindUp")
	return farmer


func _stand_him_down(farmer: Enemy) -> void:
	if farmer != null and is_instance_valid(farmer):
		farmer.retire()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"access OK — with the shake at nought, the hitstop off and the flashing reduced, "
				+ "the telegraph still leans, a perfect hit still says so, the clock is never left "
				+ "stopped and a swing still lands"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
