extends Node
## Headless proof that the combat loop does what the design says: a hit lands, a perfect hit hits
## harder, a chain only exists inside its window, and a perfect parry costs nothing.
## Runs as a scene rather than with --script, because --script starts no autoloads and every
## combat script talks to the EventBus.
## Run: godot --headless --path . res://tools/verify_combat.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const REAPER: String = "res://data/enemies/reaper.tres"
const THROWER: String = "res://data/enemies/thrower.tres"
## The least the two archetypes may differ in brightness. Hue is not enough: the camera is high, the
## bodies are small, and a player who cannot tell a bruiser from a swarm body has no way to choose
## what to do about either. Measured the way an eye weighs the channels.
const GREYSCALE_GAP: float = 0.15
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

var _failures: PackedStringArray = []
var _player: Player = null
var _enemy: Enemy = null


func _ready() -> void:
	_run()


func _run() -> void:
	var arena := (load(ARENA) as PackedScene).instantiate()
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
	await _check_a_finished_chain_locks_out_attacking()
	await _check_stopping_early_costs_nothing()
	await _check_a_perfect_finisher_waits_less()
	await _check_the_lockout_leaves_the_dodge_alone()
	await _check_parry_negates()
	await _check_enemy_closes_and_hits()
	_check_noticing_is_possible_at_all()
	await _check_a_farmer_waits_until_he_notices()
	await _check_walking_up_to_him_starts_the_chase()
	await _check_a_hit_wakes_him_from_any_distance()
	await _check_noticing_spreads_to_the_men_beside_him()
	_check_the_reaper_matches_the_table()
	_check_the_two_farmers_differ_in_greyscale()
	await _check_the_sweep_covers_the_sides_and_nothing_else()
	await _check_a_sidestep_still_beats_a_farmhand()
	_check_the_thrower_matches_the_table()
	_check_the_stone_can_be_sidestepped()
	await _check_he_backs_away_when_crowded()
	await _check_only_one_stone_is_ever_in_the_air()
	await _check_the_ranged_token_is_held_until_the_stone_lands()
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
				"combat OK — hit, perfect, chain, lockout, parry, the reaper's arc, the thrower's stone, "
				+ "and a farmer who waits until he notices you"
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


## Whatever his eyes say. Without this a thrower could plink at someone standing outside their own
## notice radius forever, and nothing would ever come after him.
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


## The reaper's row of docs/game-design.md, asserted against the resource that drives him.
func _check_the_reaper_matches_the_table() -> void:
	var data := load(REAPER) as EnemyData
	if data == null or data.attack == null:
		_fail("there is no reaper to check")
		return
	var wanted := {
		"health": 90.0,
		"move_speed": 2.4,
		"poise": 30.0,
		"attack_range": 2.8,
	}
	for field: String in wanted:
		if not is_equal_approx(data.get(field), wanted[field]):
			_fail("the reaper's %s should be %s, is %s" % [field, wanted[field], data.get(field)])
	if data.money != 5:
		_fail("a reaper should be worth 5, is worth %d" % data.money)
	var swing := data.attack
	var timing := {"damage": 16.0, "windup": 0.75, "active": 0.18, "recovery": 0.95}
	for field: String in timing:
		if not is_equal_approx(swing.get(field), timing[field]):
			_fail("the sweep's %s should be %s, is %s" % [field, timing[field], swing.get(field)])
	if not is_equal_approx(swing.reach, 2.8) or not is_equal_approx(swing.arc_degrees, 160.0):
		_fail(
			(
				"the sweep should be 2.8 m across 160°, is %.1f m across %.0f°"
				% [swing.reach, swing.arc_degrees]
			)
		)


## Told apart at a glance from a high camera, which means told apart with the colour taken out.
func _check_the_two_farmers_differ_in_greyscale() -> void:
	var archetypes := [FARMHAND, REAPER, THROWER]
	for first: int in archetypes.size():
		for second: int in range(first + 1, archetypes.size()):
			var one := load(archetypes[first]) as EnemyData
			var other := load(archetypes[second]) as EnemyData
			if one == null or other == null:
				continue
			var gap := absf(_brightness(one.tint) - _brightness(other.tint))
			if gap < GREYSCALE_GAP:
				_fail(
					(
						"%s and %s are %.2f apart in greyscale, they need %.2f"
						% [one.display_name, other.display_name, gap, GREYSCALE_GAP]
					)
				)


func _brightness(colour: Color) -> float:
	return colour.r * 0.2126 + colour.g * 0.7152 + colour.b * 0.0722


## The character, in three positions.
##
## A body that steps to the side stays inside the sweep where the same step would take it clear of a
## farmhand — that is the whole reason the reaper exists, and it is the reason the parry has to have
## been taught by wave 3. The second is the edge the box got wrong: its corner is not the weapon's
## reach.
##
## The third is the far side: a body behind him is not swept, because a sweep is not a spin.
func _check_the_sweep_covers_the_sides_and_nothing_else() -> void:
	var reaper := _lease(REAPER)
	if reaper == null:
		_fail("could not lease a reaper")
		return
	_hold_still(reaper, true)
	if not await _swing_reaches(reaper, 70.0, 2.0):
		_fail("stepping to the side should not take the player out of a 160° sweep")
	if await _swing_reaches(reaper, 170.0, 2.0):
		_fail("the sweep reached behind the reaper — it is a sweep, not a spin")
	if await _swing_reaches(reaper, 45.0, 3.4):
		_fail("the sweep reached 3.4 m on a 2.8 m weapon — the corner of the box, not the scythe")
	_hold_still(reaper, false)
	reaper.retire()


## And the contrast that gives the reaper its meaning: against 60° of farmhand, the same sidestep
## works. Without this the check above would pass on any arc wide enough, including every arc.
func _check_a_sidestep_still_beats_a_farmhand() -> void:
	_hold_still(_enemy, true)
	if await _swing_reaches(_enemy, 70.0, 1.2):
		_fail("a sidestep should still take the player clear of a farmhand's 60°")
	_hold_still(_enemy, false)


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


func _lease(archetype: String) -> Enemy:
	var director := get_child(0).get_node_or_null("WaveDirector") as WaveDirector
	if director == null:
		return null
	return director.spawner.spawn_at(load(archetype) as EnemyData, Vector3(0.0, 0.0, -3.0))


## The thrower's row of docs/game-design.md, asserted against the resource that drives him.
func _check_the_thrower_matches_the_table() -> void:
	var data := load(THROWER) as EnemyData
	if data == null or data.attack == null:
		_fail("there is no thrower to check")
		return
	if not is_equal_approx(data.health, 40.0) or not is_equal_approx(data.move_speed, 2.8):
		_fail(
			(
				"the thrower should be 40 health at 2.8 m/s, is %.0f at %.1f"
				% [data.health, data.move_speed]
			)
		)
	if not data.is_ranged or data.projectile == null:
		_fail("the thrower should be ranged and should have something to throw")
	if not is_equal_approx(data.retreat_range, 5.0):
		_fail(
			"the thrower should back away inside 5 m, backs away inside %.1f" % data.retreat_range
		)
	if not is_equal_approx(data.attack.reach, 14.0):
		_fail("a stone should carry 14 m, carries %.1f" % data.attack.reach)
	if data.money != 4 or not is_equal_approx(data.attack.damage, 10.0):
		_fail("the thrower's damage or worth does not match the table")


## The claim that makes him fair: a stone can be stepped out of. Asserted as arithmetic on the
## shipped figures rather than by driving a dodge, because what has to be true is that the flight
## lasts longer than the roll — and a dodge that only just makes it is not a dodge the player can
## be asked to find under pressure.
func _check_the_stone_can_be_sidestepped() -> void:
	var data := load(THROWER) as EnemyData
	var stone := data.projectile.instantiate() as Projectile if data != null else null
	if stone == null:
		_fail("the thrower throws something that is not a projectile")
		return
	var flight := data.attack.reach / stone.speed
	stone.free()
	if flight < PlayerDodge.DURATION * 2.0:
		_fail(
			(
				"a stone crosses its range in %.2f s against a %.2f s roll — too quick to read"
				% [flight, PlayerDodge.DURATION]
			)
		)


## He is the reason a corner is not a plan. Crowded, he gives ground rather than trading.
func _check_he_backs_away_when_crowded() -> void:
	var thrower := _lease(THROWER)
	if thrower == null:
		_fail("could not lease a thrower")
		return
	_player.global_position = Vector3.ZERO
	_player.machine.current.transition_to(&"Idle")
	thrower.global_position = Vector3(0.0, 0.0, -3.0)
	thrower.rouse()
	var before := thrower.distance_to_target()
	await _advance(2.0)
	var after := thrower.distance_to_target()
	if after <= before:
		_fail(
			(
				"a thrower three metres from the player should have given ground, went %.1f to %.1f"
				% [before, after]
			)
		)
	if after < load(THROWER).retreat_range:
		_fail("a thrower should end up outside the range he backs away from, is %.1f m out" % after)
	thrower.retire()


## Three throwers, eight seconds, and never two stones at once.
##
## Honest about what this proves: with the figures as they ship, a stone crosses its range in 1.17 s
## while the next thrower needs 1.4 s to claim the token and wind up, so **two stones could not
## overlap even without the rule**. This check would pass with the token released early. It earns
## its place by proving stones fly at all from three bodies at once — the mechanism itself is proven
## by the check below it.
func _check_only_one_stone_is_ever_in_the_air() -> void:
	var throwers: Array[Enemy] = []
	for index: int in 3:
		var thrower := _lease(THROWER)
		if thrower == null:
			continue
		thrower.global_position = Vector3(float(index) * 2.0 - 2.0, 0.0, -9.0)
		thrower.rouse()
		throwers.append(thrower)
	if throwers.size() < 3:
		_fail("could not lease three throwers")
		return
	_player.global_position = Vector3.ZERO
	var most := 0
	for _step: int in 480:
		await get_tree().physics_frame
		most = maxi(most, get_tree().get_nodes_in_group(&"projectiles").size())
	if most == 0:
		_fail("three throwers stood at nine metres for eight seconds and threw nothing")
	if most > 1:
		_fail("%d stones were in the air at once, the ranged pool holds one" % most)
	for thrower: Enemy in throwers:
		thrower.retire()


## The rule itself, rather than a timing that happens to satisfy it.
##
## The ranged pool holds one, and a thrower keeps that one until its stone lands — not until the
## throw finishes. Today the two are the same thing because a stone lands before the next thrower
## could possibly wind up, so nothing in a running fight distinguishes them. Shorten the recovery or
## slow the stone and it would matter, and nobody would find out from watching.
func _check_the_ranged_token_is_held_until_the_stone_lands() -> void:
	var tokens := get_tree().get_first_node_in_group(&"attack_tokens") as AttackTokens
	var thrower := _lease(THROWER)
	if tokens == null or thrower == null:
		_fail("could not lease a thrower and its token pool")
		return
	_hold_still(thrower, true)
	thrower.global_position = Vector3(0.0, 0.0, -9.0)
	_player.global_position = Vector3.ZERO
	thrower.claim_token()
	thrower.throw_at(_player.global_position)
	thrower.release_token()
	if not tokens.holds(thrower, true):
		_fail("a thrower let go of the ranged token with its stone still in the air")
	var waited := 0.0
	while not get_tree().get_nodes_in_group(&"projectiles").is_empty() and waited < 4.0:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
	await get_tree().physics_frame
	if tokens.holds(thrower, true):
		_fail("a thrower kept the ranged token after its stone had landed")
	_hold_still(thrower, false)
	thrower.retire()
