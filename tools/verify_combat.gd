extends Node
## Headless proof that the combat loop does what the design says: a hit lands, a perfect hit hits
## harder, a chain only exists inside its window, and a perfect parry costs nothing.
## Runs as a scene rather than with --script, because --script starts no autoloads and every
## combat script talks to the EventBus.
## Run: godot --headless --path . res://tools/verify_combat.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const PIRATE: String = "res://data/enemies/pirate.tres"
const SETTLE_FRAMES: int = 8
## The closest the spawn search will ever put a body to the player. Written out rather than read off
## SpawnDirector, because a check that agrees with whatever that class says is not a check — and
## this is the one number that decides whether noticing exists at all.
const NEAREST_SPAWN: float = 12.0
## Far enough that nothing notices anything, near enough to walk in a couple of seconds.
const WELL_CLEAR: float = 20.0
## Two men working the same patch of field, and two men who are not. Rousing must cross the first
## gap and not the second, whatever figure the data happens to carry.
const SHOULDER_TO_SHOULDER: float = 3.0
const ACROSS_THE_FIELD: float = 25.0
## Where the second swinger stands while the first one is measured: far enough that its own swing
## reaches nobody, so the only thing it brings to the measurement is that it armed at all.
const INTERLOPER_DISTANCE: float = 20.0
## Where the player waits before stepping into a swing that is already open. Past every reach in the
## game, so the sweep has demonstrably found nothing before the step.
const WELL_OUT_OF_REACH: float = 4.0
## The least invulnerability a roll may grant and still be one. A farmhand's swing is active for
## 0.12 s; a window shorter than the blow it is meant to answer is decoration. Written out, not read
## off `PlayerDodge` — a bound taken from the thing it bounds agrees with whatever that thing says.
const LEAST_INVULNERABILITY: float = 0.2
## The longest a full bar may keep a player sprinting. A hundred stamina at the shipped drain lasts
## a little over eight seconds; twenty is generous enough that only a sprint costing nothing reaches
## it, and it is written out rather than derived from the drain for the usual reason.
const LONGEST_SPRINT: float = 20.0

var _failures: PackedStringArray = []
var _player: Player = null
var _enemy: Enemy = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	var arena := (load(ARENA) as PackedScene).instantiate()
	# From a fresh run, and the machine's own run put back at the end. `GameState` restores a
	# saved run at boot, so a developer who has picked the gun up would start this check holding
	# it — and every damage figure below is the fists'.
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	GameState.begin_run()
	add_child(arena)
	# Wave 1 belongs to the tutorial now, and a lesson holding it open would leave this check
	# waiting for a parry nobody is going to throw. This one is not about the lesson.
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	await get_tree().physics_frame

	_player = arena.get_node("Player") as Player
	# The arena runs waves now, so the sparring partner is leased rather than found: the director is
	# halted first, or the first wave would arrive in the middle of a damage measurement.
	var director := arena.get_node("WaveDirector") as WaveDirector
	director.halt()
	_enemy = director.spawner.spawn_at(load(FARMHAND) as EnemyData, Vector3(0.0, 0.0, -1.0))

	if _player == null or _enemy == null:
		_fail("arena does not hold a player and an enemy")
		_report()
		return

	await _check_weapon()
	await _check_hit_lands()
	await _check_perfect_hits_harder()
	await _check_chain_window()
	await _check_a_whole_chain_lands_on_one_body()
	await _check_a_finished_chain_locks_out_attacking()
	await _check_stopping_early_costs_nothing()
	await _check_a_perfect_finisher_waits_less()
	await _check_the_lockout_leaves_the_dodge_alone()
	await _check_a_dodge_through_a_swing_takes_nothing()
	await _check_a_dodge_that_starts_too_late_takes_everything()
	_check_a_roll_outlasts_its_own_invulnerability()
	await _check_a_roll_cannot_cover_its_own_recovery()
	await _check_a_sprint_runs_out()
	await _check_a_state_that_leaves_on_arrival_is_announced_once()
	await _check_parry_negates()
	await _check_a_parry_that_missed_is_a_hit_taken()
	await _check_enemy_closes_and_hits()
	await _check_the_token_pool_refuses_and_gives_back()
	_check_noticing_is_possible_at_all()
	await _check_a_farmer_waits_until_he_notices()
	await _check_walking_up_to_him_starts_the_chase()
	await _check_a_hit_wakes_him_from_any_distance()
	await _check_noticing_spreads_to_the_men_beside_him()
	await _check_a_sidestep_still_beats_a_farmhand()
	await _check_one_swing_never_shrinks_another()
	# Last of the checks, because it is the one that kills the sparring partner on purpose — and
	# before the run goes back, because it pays money into the wallet on its way through.
	await _check_a_finisher_pays_double()
	_put_the_run_back()
	_report()


func _check_weapon() -> void:
	var weapon := _player.weapon
	if weapon == null or weapon.chain_length() != 3:
		_fail("fists should carry three attacks")
		return
	if not weapon.attack_at(2).is_finisher():
		_fail("the uppercut should be a finisher")
	if weapon.attack_at(0).is_finisher():
		_fail("the jab should not be a finisher")
	await get_tree().physics_frame


func _check_hit_lands() -> void:
	var damage := await _damage_from({"index": 0, "perfect": false})
	var expected := _player.weapon.attack_at(0).damage
	if not is_equal_approx(damage, expected):
		_fail("a jab should deal %.1f, dealt %.1f" % [expected, damage])


func _check_perfect_hits_harder() -> void:
	var attack := _player.weapon.attack_at(1)
	var damage := await _damage_from({"index": 1, "perfect": true})
	var expected := attack.damage * attack.perfect_multiplier
	if not is_equal_approx(damage, expected):
		_fail("a perfect cross should deal %.1f, dealt %.1f" % [expected, damage])


## The chain is the whole game: pressing outside the window has to reset to the first attack.
func _check_chain_window() -> void:
	var jab := _player.weapon.attack_at(0)
	_player.close_chain()
	_player.open_chain(jab, 0)
	await _advance(jab.chain_window.x + 0.01)
	_player.press_attack()
	var inside := _player.take_attack_input()
	if int(inside.get("index", -1)) != 1:
		_fail("a press inside the chain window should produce attack 2")
	if bool(inside.get("perfect", true)):
		_fail("a press before the perfect window should not be perfect")

	_player.close_chain()
	_player.open_chain(jab, 0)
	await _advance(jab.perfect_window.x + 0.01)
	_player.press_attack()
	var perfect := _player.take_attack_input()
	if not bool(perfect.get("perfect", false)):
		_fail("a press inside the perfect window should be perfect")

	_player.close_chain()
	_player.press_attack()
	var fresh := _player.take_attack_input()
	if int(fresh.get("index", -1)) != 0:
		_fail("a press with no chain open should start at attack 1")


## Three hits then a beat out of the conversation. Without this the optimal play is to hold the
## button, which is the opposite of what the timing system is for.
func _check_a_finished_chain_locks_out_attacking() -> void:
	var announced := await _spend_the_chain(false)
	if is_zero_approx(announced):
		_fail("the lockout should announce itself on the bus, or nothing can show it")
	if not _player.chain_locked():
		_fail("a finished chain should leave the player unable to attack")
		return
	_player.press_attack()
	if not _player.take_attack_input().is_empty():
		_fail("attacking during the lockout should be refused")
	# Refused, not eaten: the press has to still be there when the weapon comes back.
	if not _player.buffered_attack_press():
		_fail("the lockout should refuse a press, not consume it")
	await _advance(_player.lockout_left() + 0.05)
	if _player.chain_locked():
		_fail("the lockout should have run out")
		return
	_player.press_attack()
	if _player.take_attack_input().is_empty():
		_fail("the player should be able to attack again once the lockout ends")


## The tension worth having: stopping at two and stepping out stays free, so finishing is a choice.
func _check_stopping_early_costs_nothing() -> void:
	_reset_player()
	for index: int in 2:
		var attack := _player.weapon.attack_at(index)
		_player.machine.current.transition_to(&"Attack", {"index": index, "perfect": false})
		await _advance(attack.total_duration() + 0.1)
		if _player.chain_locked():
			_fail("stopping at %d attacks should cost nothing extra" % (index + 1))
			return


## The reward for timing belongs on the thing that costs the most.
func _check_a_perfect_finisher_waits_less() -> void:
	var plain := await _spend_the_chain(false)
	await _advance(_player.lockout_left() + 0.05)
	var perfect := await _spend_the_chain(true)
	await _advance(_player.lockout_left() + 0.05)
	if perfect >= plain:
		_fail("a perfect finisher should wait %.2fs, less than %.2fs" % [perfect, plain])


## A window where every button is dead is a death sentence in a crowd, not a design.
func _check_the_lockout_leaves_the_dodge_alone() -> void:
	await _spend_the_chain(false)
	if not _player.chain_locked():
		_fail("the player should be locked out for this check to mean anything")
		return
	_player.machine.current.transition_to(&"Dodge")
	await get_tree().physics_frame
	if _player.machine.current_name != &"Dodge":
		_fail("the lockout should not stop the player dodging")
	await _advance(PlayerDodge.DURATION + _player.lockout_left() + 0.05)


## The dodge is one of the two defensive tools and **nothing was holding the half that matters**.
## Setting `IFRAME_LENGTH` to nought passed every check in the project: the roll still moved, still
## went where the keys said, still survived the lockout, and no longer avoided anything.
##
## Measured through a real blow, at the middle of the window, so it is the invulnerability being
## checked and not the fact that a rolling body has moved out of reach — the farmer's swing is
## applied straight to the hurtbox from where he stands.
func _check_a_dodge_through_a_swing_takes_nothing() -> void:
	_reset_player()
	var before := _player.health.current_health
	_player.machine.current.transition_to(&"Dodge")
	await _advance(PlayerDodge.IFRAME_START + PlayerDodge.IFRAME_LENGTH * 0.5)
	if _player.machine.current_name != &"Dodge":
		_fail("the roll was over before its own invulnerability window opened")
		return
	_swing_at_the_player()
	await get_tree().physics_frame
	if _player.health.current_health < before:
		_fail(
			(
				(
					"a swing landed for %.1f in the middle of a roll — the dodge grants no "
					+ "invulnerability at all"
				)
				% (before - _player.health.current_health)
			)
		)
	await _advance(PlayerDodge.DURATION)


## And the other half, or the check above would pass on a player who is simply never hurt. A blow
## that arrives before the window opens has to land.
func _check_a_dodge_that_starts_too_late_takes_everything() -> void:
	_reset_player()
	var before := _player.health.current_health
	_player.machine.current.transition_to(&"Dodge")
	await get_tree().physics_frame
	_swing_at_the_player()
	await get_tree().physics_frame
	if is_equal_approx(_player.health.current_health, before):
		_fail("a swing on the first frame of a roll was refused — the window opens late on purpose")
	await _advance(PlayerDodge.DURATION)


## A roll that ends before its own invulnerability opens is a roll with none, and the figures are
## far enough apart that nothing but a mistake closes the gap. Written out rather than compared to
## each other, so shrinking the roll to nothing fails here rather than moving the bound with it.
func _check_a_roll_outlasts_its_own_invulnerability() -> void:
	var opens := PlayerDodge.IFRAME_START
	var closes := opens + PlayerDodge.IFRAME_LENGTH
	if closes > PlayerDodge.DURATION:
		_fail(
			(
				(
					"the roll lasts %.2f s and its invulnerability runs to %.2f s — it ends inside "
					+ "the window it is supposed to contain"
				)
				% [PlayerDodge.DURATION, closes]
			)
		)
	if PlayerDodge.IFRAME_LENGTH < LEAST_INVULNERABILITY:
		_fail(
			(
				(
					"a roll is invulnerable for %.2f s, and a farmer's swing is active for %.2f s — "
					+ "a window shorter than the blow is not a dodge"
				)
				% [PlayerDodge.IFRAME_LENGTH, LEAST_INVULNERABILITY]
			)
		)


## **The roll's vulnerable tail has to be reachable.** Its invulnerability runs to
## `IFRAME_START + IFRAME_LENGTH` of a `DURATION`-long roll, so the rest of it is exposed on purpose
## — and a second roll starting the instant the first ends opens new frames exactly over that
## window, which makes the weakness the table describes impossible to meet.
##
## Measured as a gap in seconds rather than as a flag, because that is what an enemy has to hit: the
## tail plus the cooldown has to be worth something against a committed swing.
func _check_a_roll_cannot_cover_its_own_recovery() -> void:
	var exposed := PlayerDodge.DURATION - (PlayerDodge.IFRAME_START + PlayerDodge.IFRAME_LENGTH)
	var gap := exposed + PlayerDodge.COOLDOWN
	if gap < LEAST_INVULNERABILITY:
		_fail(
			(
				(
					"between two rolls a player is open for %.2f s, and a farmer's blow is active "
					+ "for %.2f s — a gap shorter than the blow cannot be punished"
				)
				% [gap, LEAST_INVULNERABILITY]
			)
		)

	# And the gate is real, not just tabled. Rolled once, the next one has to be refused.
	_player.machine.current.transition_to(&"Idle")
	_player.roll_cooldown = 0.0
	if _player.stamina != null:
		_player.stamina.refund(_player.stamina.max_stamina)
	_player.machine.current.transition_to(&"Dodge")
	await _advance(PlayerDodge.DURATION + 0.02)
	if _player.roll_cooldown <= 0.0:
		_fail(
			"a finished roll left no cooldown behind, so the next one can start on the same frame"
		)
	if _player.machine.current_name == &"Dodge":
		_fail("the player was still rolling after the roll's own duration")


## Sprinting has to end on its own. The design rests on it: a walking player cannot break away from
## a farmhand, so retreat costs breath rather than being the default state — and `SPRINT_DRAIN` set
## to nought passed every check in the project, leaving a player who outruns the wave for ever.
##
## Measured by running until the state gives up rather than by reading the drain rate back, so the
## figure being held is the one the player feels.
func _check_a_sprint_runs_out() -> void:
	_reset_player()
	# Both held for the whole run. The state asks `move_direction` and `wants_sprint` every frame and
	# drops back to Move the instant either says no — a first version pressed neither and reported a
	# sprint that ended with a full bar, which is a check testing its own missing input.
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	await get_tree().physics_frame
	_player.machine.current.transition_to(&"Sprint")
	var ran := 0.0
	while _player.machine.current_name == &"Sprint" and ran < LONGEST_SPRINT:
		await get_tree().physics_frame
		ran += 1.0 / 60.0
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	if ran >= LONGEST_SPRINT:
		_fail(
			(
				(
					"the player sprinted for %.0f s without running out of breath — a sprint that "
					+ "costs nothing is a walk speed"
				)
				% LONGEST_SPRINT
			)
		)
	if _player.stamina != null and _player.stamina.has(1.0):
		_fail(
			(
				"the sprint ended with %.0f stamina left, so something other than breath ended it"
				% _player.stamina.current_stamina
			)
		)


## A farmer's swing, applied where he stands rather than by walking him into range: this is about
## what the hurtbox does with a blow, not about whether he can reach.
## **All three attacks of a chain land on the same body.**
##
## The one thing every other check here is arranged not to ask. `_damage_from` and
## `_spend_the_chain` both call `_place_enemy_in_front`, which teleports the farmer back to a metre
## away and resets his state before each measured swing — so a finisher that could never reach a
## man the first two blows had thrown was measured against a man who had been put back. That is
## exactly the bug this guards: every hit used to send him into a full tumble, and the third swung
## through the space he left.
##
## Run without touching him between the blows, which is the only way the question gets asked.
func _check_a_whole_chain_lands_on_one_body() -> void:
	_place_enemy_in_front()
	if _player.stamina != null:
		_player.stamina.refund(_player.stamina.max_stamina)
	await _advance(0.2)
	var landed: Array[int] = []
	var listener := func(
		_target: Node3D, _damage: float, _perfect: bool, attack: AttackData
	) -> void:
		for index: int in _player.weapon.chain_length():
			if _player.weapon.attack_at(index) == attack:
				landed.append(index)
	EventBus.attack_landed.connect(listener)
	for index: int in _player.weapon.chain_length():
		var attack := _player.weapon.attack_at(index)
		_player.machine.current.transition_to(&"Attack", {"index": index, "perfect": false})
		await _advance(attack.windup + attack.active + attack.recovery + 0.05)
	EventBus.attack_landed.disconnect(listener)
	for index: int in _player.weapon.chain_length():
		if landed.has(index):
			continue
		_fail(
			(
				"attack %d of the fist chain never landed on the man the blows before it hit"
				% (index + 1)
			)
		)


func _swing_at_the_player() -> void:
	_player.hurtbox.take_hit(HitInfo.new(_enemy.data.attack, _enemy, false, 1.0))


## Plays a finisher through to its recovery and returns what the bus announced, so the check reads
## the same seam the presentation does rather than a private field.
func _spend_the_chain(perfect: bool) -> float:
	_reset_player()
	var announced: Array = []
	var listener := func(seconds: float) -> void: announced.append(seconds)
	EventBus.chain_spent.connect(listener, CONNECT_ONE_SHOT)
	var finisher := _player.weapon.attack_at(2)
	_player.machine.current.transition_to(&"Attack", {"index": 2, "perfect": perfect})
	await _advance(finisher.windup + finisher.active + 0.05)
	if EventBus.chain_spent.is_connected(listener):
		EventBus.chain_spent.disconnect(listener)
	return announced[0] if not announced.is_empty() else 0.0


func _reset_player() -> void:
	_enemy.machine.current.transition_to(&"Idle")
	_enemy.global_position = Vector3(0.0, 0.0, -40.0)
	_player.global_position = Vector3.ZERO
	_player.health.current_health = _player.health.max_health
	_player.machine.current.transition_to(&"Idle")
	_player.close_chain()
	_player.consume_press()
	if _player.stamina != null:
		_player.stamina.refund(_player.stamina.max_stamina)


## **A state may leave from inside its own `enter`.** Pulling the trigger on an empty gun is the
## everyday case: `Attack` enters, finds no round, and goes straight back to `Idle` — re-entering
## the machine while the first call is still on the stack.
##
## The announcement is what breaks. The nested call moves `current_name` out from under the outer
## one, so the outer call announced the **inner** state a second time and the outer state never at
## all. Anything listening for what the body is doing — the animation, the HUD — heard a state it
## had already been told about and missed one entirely.
func _check_a_state_that_leaves_on_arrival_is_announced_once() -> void:
	_player.machine.current.transition_to(&"Idle")
	await get_tree().physics_frame
	# Borrowed and put back: every check after this one fights with whatever is in hand.
	var held := GameState.loadout.equipped
	var rounds := GameState.loadout.rounds
	GameState.loadout.find_weapon(&"gun")
	GameState.loadout.equip(&"gun")
	GameState.loadout.rounds = 0
	await get_tree().physics_frame
	if _player.stamina != null:
		_player.stamina.refund(_player.stamina.max_stamina)

	var heard: Array[StringName] = []
	var listener := func(named: StringName) -> void: heard.append(named)
	_player.machine.transitioned.connect(listener)
	_player.machine.current.transition_to(&"Attack", {"index": 0})
	await get_tree().physics_frame
	_player.machine.transitioned.disconnect(listener)

	if _player.machine.current_name != &"Idle":
		_fail(
			"a trigger pulled on an empty gun left the player in %s" % _player.machine.current_name
		)
	if heard.size() != 1:
		_fail(
			(
				(
					"leaving a state from inside its own enter announced %d transitions, and one thing "
					+ "happened: %s"
				)
				% [heard.size(), ", ".join(heard)]
			)
		)
	elif heard[0] != &"Idle":
		_fail("the machine announced %s and the player is in Idle" % heard[0])
	GameState.loadout.rounds = rounds
	GameState.loadout.equip(held)
	_player.machine.current.transition_to(&"Idle")
	await get_tree().physics_frame


func _check_parry_negates() -> void:
	var health := _player.health
	var before := health.current_health
	_player.machine.current.transition_to(&"Parry")
	await get_tree().physics_frame
	if _player.machine.current_name != &"Parry":
		_fail("the player should be parrying")
		return
	var info := HitInfo.new(_enemy.data.attack, _enemy, false)
	_player.hurtbox.take_hit(info)
	if not info.negated:
		_fail("a perfect parry should negate the hit")
	if not is_equal_approx(health.current_health, before):
		_fail("a perfect parry should cost no health")


## **Only a perfect parry negates.** Late halves the blow, and anything past that takes it whole —
## so both of those are hits taken, and both have to be written down like any other.
##
## What reads them is the fall. `PlayerDead` throws the body along `last_hit_from` at
## `last_hit_push`, and those are set when a blow lands. A parried-too-late killing blow that never
## wrote them left the body to fall by whatever hit it last — a jab from the other side of the wave,
## or on a run where every other blow was parried, by nothing at all: no direction, no push, a man
## who crumples where he stands after taking a club to the head.
func _check_a_parry_that_missed_is_a_hit_taken() -> void:
	_player.machine.current.transition_to(&"Idle")
	await get_tree().physics_frame
	_player.health.current_health = _player.health.max_health

	# A blow from an earlier exchange, still on the books. The fall used to read this one.
	var stale := Vector3.FORWARD
	_player.last_hit_from = stale
	_player.last_hit_push = 0.01

	_player.machine.current.transition_to(&"Parry")
	await get_tree().physics_frame
	if _player.machine.current_name != &"Parry":
		_fail("the player should be parrying")
		return
	# Past `LATE_END` so the blow is taken whole, and short of `RECOVERY_END` so the player is still
	# in `Parry` when it lands. Derived from the two constants rather than counted in frames: aim at
	# the middle and neither of them moving can quietly make this check test the ordinary path.
	var window := (PlayerParry.LATE_END + PlayerParry.RECOVERY_END) * 0.5
	var waited := 0.0
	while waited < window:
		await get_tree().physics_frame
		waited += get_physics_process_delta_time()
	if _player.machine.current_name != &"Parry":
		_fail("the parry ended before the blow landed, so this check is not testing a parry at all")
		return

	var info := HitInfo.new(_enemy.data.attack, _enemy, false)
	var thrown := info.direction
	var weight := info.stagger
	_player.hurtbox.take_hit(info)
	if info.negated:
		_fail("a parry thrown long before the blow still negated it")
		return
	if _player.last_hit_from.is_equal_approx(stale):
		_fail("a missed parry left the body to fall by a blow from an earlier exchange")
	if not _player.last_hit_from.is_equal_approx(thrown):
		_fail("a missed parry wrote down a direction that was not the blow's")
	if not is_equal_approx(_player.last_hit_push, weight):
		_fail(
			(
				"a missed parry wrote down a push of %.2f for a blow of %.2f"
				% [_player.last_hit_push, weight]
			)
		)
	_player.machine.current.transition_to(&"Idle")
	_player.health.current_health = _player.health.max_health
	await get_tree().physics_frame


## The end-to-end one: left alone, the farmhand crosses the arena, telegraphs, and connects.
func _check_enemy_closes_and_hits() -> void:
	_player.machine.current.transition_to(&"Idle")
	_player.health.current_health = _player.health.max_health
	_player.global_position = Vector3.ZERO
	_enemy.health.current_health = _enemy.health.max_health
	_enemy.global_position = Vector3(0.0, 0.0, -8.0)
	_enemy.machine.current.transition_to(&"Chase")
	var before := _player.health.current_health
	await _advance(6.0)
	if _enemy.distance_to_target() > _enemy.data.attack_range + 1.0:
		_fail(
			(
				"the farmhand should have closed the distance, stopped at %.1f m"
				% _enemy.distance_to_target()
			)
		)
	if is_equal_approx(_player.health.current_health, before):
		_fail("the farmhand should have landed a hit within six seconds")


## Three claims on one body, measured on the bus because the bus is what the wallet hears.
##
## The third is the one worth spelling out. A body is leased and returned, and `last_hit_worth` is
## written by every hit that lands — so killing with a jab after an uppercut proves only that the
## jab overwrote it, not that the pool cleans up. The case that proves the reset is a body killed by
## **no swing at all**: damage applied straight to the health, the way the wave checks do it.
## Without the reset in `revive()` that body would still be paying for somebody else's combo.
func _check_a_finisher_pays_double() -> void:
	var uppercut := _player.weapon.attack_at(2)
	if uppercut == null or not uppercut.is_finisher():
		_fail("the third fist attack should be the chain's finisher")
		return
	if is_equal_approx(uppercut.money_multiplier, 1.0):
		_fail("the finisher should be worth more money than the swings before it")
		return

	var paid: Array[int] = []
	var purse := func(_body: Node3D, _archetype: StringName, money: int) -> void: paid.append(money)
	EventBus.enemy_died.connect(purse)
	await _kill_with(0)
	await _kill_with(2)
	await _kill_with(0)
	await _kill_with(2)
	await _kill_without_a_swing()
	EventBus.enemy_died.disconnect(purse)

	if paid.size() != 5:
		_fail("five dead farmhands should pay five times, paid %d" % paid.size())
		return
	var wanted := roundi(float(paid[0]) * uppercut.money_multiplier)
	if paid[1] != wanted:
		_fail("a finisher should pay %d against a jab's %d, paid %d" % [wanted, paid[0], paid[1]])
	if paid[2] != paid[0]:
		_fail("a jab after a finisher paid %d, and a jab is worth %d" % [paid[2], paid[0]])
	if paid[4] != paid[0]:
		_fail(
			(
				"a recycled body killed by no swing paid %d, and it should pay a plain %d"
				% [paid[4], paid[0]]
			)
		)


## One body, brought back and knocked down by the attack asked for. Revived rather than replaced,
## because reuse is exactly what the second claim above is about.
func _kill_with(index: int) -> void:
	_enemy.revive(Vector3(0.0, 0.0, -1.0))
	await _advance(0.1)
	_place_enemy_in_front()
	# One point of health, so whichever swing lands is the one that killed him.
	_enemy.health.current_health = 1.0
	await _advance(0.1)
	_player.machine.current.transition_to(&"Attack", {"index": index, "perfect": false})
	var attack := _player.weapon.attack_at(index)
	await _advance(attack.windup + attack.active + 0.1)


## Killed by nothing the player threw, which is how the wave checks and a drowning would do it. The
## body has just been brought back from a life that ended on a finisher, so what it pays here is the
## whole question.
func _kill_without_a_swing() -> void:
	_enemy.revive(Vector3(0.0, 0.0, -1.0))
	await _advance(0.1)
	var killing := HitInfo.new()
	killing.damage = _enemy.health.max_health * 2.0
	_enemy.health.apply(killing)
	await _advance(0.1)


## Drives one attack to completion and returns the health the enemy lost.
func _damage_from(message: Dictionary) -> float:
	_place_enemy_in_front()
	await _advance(0.2)
	var before := _enemy.health.current_health
	_player.machine.current.transition_to(&"Attack", message)
	var attack := _player.weapon.attack_at(int(message["index"]))
	await _advance(attack.windup + attack.active + 0.1)
	return before - _enemy.health.current_health


func _place_enemy_in_front() -> void:
	_enemy.health.current_health = _enemy.health.max_health
	_enemy.machine.current.transition_to(&"Idle")
	_player.global_position = Vector3.ZERO
	_player.rotation.y = 0.0
	# The player faces -Z, and the hitbox reaches a little over a metre.
	_enemy.global_position = Vector3(0.0, 0.0, -1.0)


func _advance(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"combat OK — hit, perfect, chain, lockout, parry, one swing through a second "
				+ "man's swing, a combo finished for double money, and a "
				+ "farmer who waits until he notices you"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


## The rule that makes every other rule here matter. A notice radius at or past the distance the
## spawn search keeps bodies away from the player means every farmer arrives already awake, and
## nothing below would fail — the feature would simply not exist, silently.
## **The one rule that keeps a crowd a fight.** Only so many bodies may commit at once and the rest
## circle — the pool's own docstring says that without it a wave *stops being a fight and becomes an
## unreadable pile*. Nothing ever asked it for one token too many, and nothing ever watched one come
## back.
##
## Both failures are silent and neither is visible in a diff: a cap that never refuses puts all
## twenty-eight bodies of a late wave on the player at once, and a token never released leaks until
## nobody can swing and the wave stands around doing nothing.
func _check_the_token_pool_refuses_and_gives_back() -> void:
	var pool := get_tree().get_first_node_in_group(&"attack_tokens") as AttackTokens
	if pool == null:
		_fail("the arena has no attack token pool, so the crowd rule is not being tested")
		return

	var holders: Array[Node] = []
	for index: int in pool.melee_tokens + 1:
		var holder := Node.new()
		holder.name = "Claimant%d" % index
		add_child(holder)
		holders.append(holder)

	# Counted as "somebody was turned away", not as an exact tally: the sparring partner in this
	# arena may already hold one, and what must be true is that the pool says no — not that it says
	# no at a particular number.
	var taken := 0
	var refused := false
	for holder: Node in holders:
		if pool.claim(holder):
			taken += 1
		else:
			refused = true
	if not refused:
		_fail(
			(
				"%d fresh bodies all got a token from a pool of %d, so a crowd commits as one"
				% [holders.size(), pool.melee_tokens]
			)
		)
	if taken > pool.melee_tokens:
		_fail("a pool of %d handed out %d" % [pool.melee_tokens, taken])

	# Asking twice is not asking again. A body already committed re-claims every frame it swings.
	if not pool.claim(holders[0]):
		_fail("a body that already holds a token was refused its own")

	# And letting go has to let somebody else in, or the pool leaks until nobody can swing.
	pool.release(holders[0])
	if not pool.claim(holders[holders.size() - 1]):
		_fail("a token was let go of and the next body still could not have it")

	for holder: Node in holders:
		pool.release(holder)
		holder.queue_free()
	await get_tree().process_frame


func _check_noticing_is_possible_at_all() -> void:
	var radius := _enemy.data.notice_radius
	if radius >= NEAREST_SPAWN:
		_fail(
			(
				"a farmer notices at %.1f m and spawns no closer than %.1f — he arrives awake"
				% [radius, NEAREST_SPAWN]
			)
		)


## Left well clear, he stands where he was put. He also never telegraphs from out there: a wind-up
## that starts on the approach is a swing at nobody.
func _check_a_farmer_waits_until_he_notices() -> void:
	_park_enemy_at(WELL_CLEAR)
	var before := _apart()
	await _advance(2.0)
	var moved := absf(before - _apart())
	if moved > 0.5:
		_fail("a farmer nobody has noticed closed %.1f m on his own" % moved)
	if _enemy.machine.current_name != &"Idle":
		_fail("a farmer out of range should be idle, is %s" % _enemy.machine.current_name)


## The player walks up to him. The approach is sampled rather than only its end, because the thing
## worth proving about a wind-up is that it never starts on the way in.
func _check_walking_up_to_him_starts_the_chase() -> void:
	_park_enemy_at(WELL_CLEAR)
	await _advance(0.2)
	_player.global_position = _enemy.global_position + Vector3(0.0, 0.0, 1.2)
	var telegraphed_early := false
	for _step: int in 180:
		await get_tree().physics_frame
		var winding: bool = _enemy.machine.current_name == &"WindUp"
		if winding and _apart() > _enemy.data.attack_range + 0.5:
			telegraphed_early = true
	if not _enemy.roused:
		_fail("walking up to a farmer should rouse him")
	if telegraphed_early:
		_fail("the farmer telegraphed a swing from outside his own reach")


## Whatever his eyes say. Without this a farmer hit from outside his own notice radius would stand
## there forever, and nothing would ever come after the player.
func _check_a_hit_wakes_him_from_any_distance() -> void:
	_park_enemy_at(40.0)
	await _advance(0.2)
	if _enemy.roused:
		_fail("a farmer forty metres away should not have noticed anything")
		return
	_enemy.hurtbox.take_hit(HitInfo.new(_player.weapon.attack_at(0), _player, false))
	if not _enemy.roused:
		_fail("being hit should rouse a farmer at any distance")


## A group turns together, and only the group. Both distances are written out rather than derived
## from the radius under test: placing the far man at twice whatever the data says would put him
## outside it for any value at all, and the check could never fail. It is the design bound that is
## being asserted — rousing is local — not the number.
func _check_noticing_spreads_to_the_men_beside_him() -> void:
	_park_enemy_at(WELL_CLEAR)
	var near := _spawn_extra(_enemy.global_position + Vector3(SHOULDER_TO_SHOULDER, 0.0, 0.0))
	var far := _spawn_extra(_enemy.global_position + Vector3(ACROSS_THE_FIELD, 0.0, 0.0))
	if near == null or far == null:
		_fail("could not lease two more farmers")
		return
	await _advance(0.2)
	_enemy.rouse()
	if not near.roused:
		_fail(
			"a farmer %.0f m from a roused one should have been roused too" % SHOULDER_TO_SHOULDER
		)
	if far.roused:
		_fail(
			(
				"rousing carried %.0f m across the field — it is meant to turn a group, not the island"
				% ACROSS_THE_FIELD
			)
		)
	near.retire()
	far.retire()


## Put down on the ground rather than at y = 0. The fighting core is flat, but twenty metres out the
## island has relief, and a body dropped into the air falls — which reads as closing the distance to
## anything measuring in three dimensions. Hence `_apart`, which measures in two.
func _park_enemy_at(metres: float) -> void:
	_player.global_position = Vector3.ZERO
	_player.machine.current.transition_to(&"Idle")
	_enemy.roused = false
	_enemy.health.current_health = _enemy.health.max_health
	var world := _enemy.get_world_3d()
	_enemy.global_position = Ground.closest_point(world, Vector3(0.0, 0.0, -metres))
	_enemy.velocity = Vector3.ZERO
	_enemy.machine.current.transition_to(&"Idle")


## How far apart they stand, ignoring height. Falling is not walking.
func _apart() -> float:
	var offset := _enemy.global_position - _player.global_position
	return Vector2(offset.x, offset.z).length()


func _spawn_extra(where: Vector3) -> Enemy:
	var director := get_node("Arena/WaveDirector") as WaveDirector if has_node("Arena") else null
	if director == null:
		director = get_child(0).get_node_or_null("WaveDirector") as WaveDirector
	if director == null:
		return null
	return director.spawner.spawn_at(load(FARMHAND) as EnemyData, where)


## A sidestep beats the farmhand, and it has to keep beating him. His arc is 60° and it is the
## narrowest in the game — widen it by accident and the one answer the tutorial teaches stops
## working, which is the kind of change nobody notices until a player is cornered by a swarm.
func _check_a_sidestep_still_beats_a_farmhand() -> void:
	_hold_still(_enemy, true)
	if await _swing_reaches(_enemy, 70.0, 1.2):
		_fail("a sidestep should still take the player clear of a farmhand's 60°")
	_hold_still(_enemy, false)


## **Two bodies swinging at once, and neither one's reach is the other's.** The pool is two by day
## and three at night, so from wave 4 — where the pirate joins the band beside the farmhand — this
## is an ordinary fight rather than a corner of one.
##
## It is the one case a check that arms a single hitbox cannot see, and it is the case that was
## broken: the box `_fit_to` resizes came out of the enemy scene as a sub-resource, and a scene
## sub-resource is handed to every instance rather than copied, so all thirty-two pooled bodies
## shared one. A farmhand arming during a longer body's active frames pulled that box in to its own
## 1.6 m, and a player stepping inside the longer reach after that was never reported to it.
func _check_one_swing_never_shrinks_another() -> void:
	var pirate := _lease(PIRATE)
	if pirate == null:
		_fail("could not lease a pirate")
		return
	_hold_still(pirate, true)
	_hold_still(_enemy, true)
	var caught := await _swing_catches_a_player_who_steps_in(pirate, 1.9, _enemy)
	_hold_still(_enemy, false)
	_hold_still(pirate, false)
	pirate.retire()
	if not caught:
		_fail("a farmhand arming mid-swing took the pirate's reach down to its own")


## Stops a body thinking for the length of a measurement, and it has to cover **all** of it rather
## than one bearing at a time. Left running between two bearings, a farmer two metres away notices
## the player, closes and lands a swing of his own — which grants the player i-frames, so the next
## bearing reads as a miss for a reason that has nothing to do with where it stood.
##
## That cost an afternoon and a wrongly-filed engine bug. A measurement is only independent if
## nothing else is allowed to touch the player between two of them.
func _hold_still(enemy: Enemy, still: bool) -> void:
	if enemy == null or enemy.machine == null:
		return
	enemy.machine.process_mode = (
		Node.PROCESS_MODE_DISABLED if still else Node.PROCESS_MODE_INHERIT
	)


## Parks the body at a bearing and a distance from a swing, and reports whether it is hit. The
## hitbox is armed directly rather than through the state machine, which would turn the enemy to
## face the player and destroy the one thing being measured.
func _swing_reaches(enemy: Enemy, degrees: float, metres: float) -> bool:
	_reset_player()
	# The i-frames from the previous bearing outlast the gap between two of these, and a swing
	# negated by them reads exactly like a swing that missed. Waiting them out is what makes each
	# bearing an independent measurement instead of a measurement of the one before it.
	await _advance(_player.health.hit_invulnerability + 0.1)
	enemy.global_position = Vector3.ZERO
	enemy.rotation.y = 0.0
	var bearing := deg_to_rad(degrees)
	# A Node3D faces -Z, so a bearing off its nose swings from there.
	_player.global_position = Vector3(sin(bearing) * metres, 0.0, -cos(bearing) * metres)
	await get_tree().physics_frame
	var before := _player.health.current_health
	enemy.hitbox.arm(enemy.data.attack, enemy, false)
	await _advance(enemy.data.attack.active + 0.05)
	enemy.hitbox.disarm()
	return _player.health.current_health < before


## Whether a swing already open catches a player who walks into it, while a second body arms a swing
## of its own in between.
##
## The arrival is the point. A player standing in the arc when the hitbox opens is hit on the first
## frame, before anything else has had a chance to touch the swing — so that ordering proves
## nothing. `_within_the_swing` deliberately keeps a missed body eligible for the rest of the sweep,
## and this is the window in which the reach the weapon claims has to still be the reach it has.
##
## The interloper is parked where nothing it does can reach anybody: the only thing it contributes
## to the measurement is the fact of having armed.
func _swing_catches_a_player_who_steps_in(enemy: Enemy, metres: float, interloper: Enemy) -> bool:
	_reset_player()
	await _advance(_player.health.hit_invulnerability + 0.1)
	enemy.global_position = Vector3.ZERO
	enemy.rotation.y = 0.0
	interloper.global_position = Vector3(0.0, 0.0, INTERLOPER_DISTANCE)
	_player.global_position = Vector3(0.0, 0.0, -WELL_OUT_OF_REACH)
	await get_tree().physics_frame
	var before := _player.health.current_health
	enemy.hitbox.arm(enemy.data.attack, enemy, false)
	# Two frames with nobody in range, so the swing is unambiguously open and has already found
	# nothing — one is not enough to tell an empty arc from an overlap the server has yet to report.
	await get_tree().physics_frame
	await get_tree().physics_frame
	interloper.hitbox.arm(interloper.data.attack, interloper, false)
	_player.global_position = Vector3(0.0, 0.0, -metres)
	await _advance(enemy.data.attack.active)
	interloper.hitbox.disarm()
	enemy.hitbox.disarm()
	return _player.health.current_health < before


func _lease(archetype: String) -> Enemy:
	var director := get_child(0).get_node_or_null("WaveDirector") as WaveDirector
	if director == null:
		return null
	return director.spawner.spawn_at(load(archetype) as EnemyData, Vector3(0.0, 0.0, -3.0))


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)
