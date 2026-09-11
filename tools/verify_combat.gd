extends Node
## Headless proof that the combat loop does what the design says: a hit lands, a perfect hit hits
## harder, a chain only exists inside its window, and a perfect parry costs nothing.
## Runs as a scene rather than with --script, because --script starts no autoloads and every
## combat script talks to the EventBus.
## Run: godot --headless --path . res://tools/verify_combat.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const SETTLE_FRAMES: int = 8

var _failures: PackedStringArray = []
var _player: Player = null
var _enemy: Enemy = null


func _ready() -> void:
	_run()


func _run() -> void:
	var arena := (load(ARENA) as PackedScene).instantiate()
	add_child(arena)
	await get_tree().physics_frame

	_player = arena.get_node("Player") as Player
	var enemies := arena.get_node("Enemies")
	_enemy = enemies.get_child(0) as Enemy
	for index: int in range(enemies.get_child_count() - 1, 0, -1):
		enemies.get_child(index).free()

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
		print("combat OK — hit, perfect, chain window, chain lockout, parry")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
