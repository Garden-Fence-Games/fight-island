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
		print("combat OK — hit, perfect, chain window, parry")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
