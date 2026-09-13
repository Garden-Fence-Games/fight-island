extends Node
## Headless proof of the three things the stick and the gun are for, and of the one rule that makes
## them a choice rather than an upgrade.
##
## **The stick's arc hits more than one body.** That is the entire reason it exists, and it is also
## the thing no diff shows: the arc is a number in a `.tres` and the sweep is geometry, so the only
## way to know 120° still means 120° is to stand two farmers inside it.
##
## **The gun's rhythm is the magazine and the reserve.** Running dry mid-wave is designed, so the
## checks here are about *when* it happens — a shot the magazine cannot pay for, a reserve that
## grows on a cleared wave and at no other moment.
##
## **Nothing carries between weapons.** A chain is a set of windows belonging to one weapon; a swap
## has to close it rather than hand it over.
##
## Whatever run is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_weapons.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
const THROWER: String = "res://data/enemies/thrower.tres"
const SETTLE_FRAMES: int = 8
## Where the sparring partners stand: inside the stick's 2.4 m, either side of straight ahead, far
## enough apart that only a wide arc reaches both.
const SIDE_STEP: float = 1.1
const AHEAD: float = 1.6

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _director: WaveDirector = null
var _kept_run: Dictionary = {}


func _ready() -> void:
	_run()


func _run() -> void:
	_kept_run = SaveManager.read_json(SaveManager.RUN_PATH)
	_check_the_tables_match()
	await _open_the_arena()
	if _player == null:
		_report()
		return
	await _check_the_stick_sweeps_two_at_once()
	await _check_the_overhead_finishes()
	_check_the_gun_comes_loaded()
	await _check_a_shot_needs_a_round()
	_check_the_double_tap_needs_two()
	_check_a_cleared_wave_hands_over_no_rounds()
	_check_the_pocket_stops_at_the_ceiling()
	_check_a_body_in_eight_leaves_a_round()
	await _check_reloading_takes_from_the_pocket()
	_check_the_wheel_only_offers_what_was_found()
	await _check_a_swap_drops_the_chain()
	await _check_a_pickup_hands_the_weapon_over()
	await _check_the_gun_on_the_ground_is_the_gun()
	await _check_a_thrower_retired_mid_throw_hands_its_token_back()
	_check_a_weapon_is_owed_from_its_wave_rather_than_offered_on_it()
	_put_the_run_back()
	_report()


## The one guard against the design document and the resources drifting apart. Written out here
## rather than read off the `.tres`: a check that agrees with whatever the data says is not a check.
func _check_the_tables_match() -> void:
	var stick := Arsenal.find(&"stick")
	var gun := Arsenal.find(&"gun")
	if stick == null or gun == null:
		_fail("the stick or the gun is missing from data/weapons/")
		return
	_expect(stick.attack_at(0).damage, 14.0, "stick backhand damage")
	_expect(stick.attack_at(0).reach, 2.4, "stick backhand reach")
	_expect(stick.attack_at(0).arc_degrees, 120.0, "stick backhand arc")
	_expect(stick.attack_at(2).damage, 30.0, "stick overhead damage")
	if not stick.attack_at(2).is_finisher():
		_fail("the overhead should be a finisher")
	_expect(gun.attack_at(0).damage, 22.0, "gun single shot damage")
	_expect(gun.attack_at(1).damage, 16.0, "gun double tap damage per round")
	_expect(gun.attack_at(2).damage, 55.0, "gun charged shot damage")
	if gun.magazine != 6 or not is_equal_approx(gun.reload_time, 1.6):
		_fail("the magazine is %d and the reload %.2f s" % [gun.magazine, gun.reload_time])
	if gun.reserve_start != 24 or gun.ammo_cap != 30:
		_fail("the pocket starts at %d and caps at %d" % [gun.reserve_start, gun.ammo_cap])
	if not is_equal_approx(gun.scavenge_chance, 0.125):
		_fail("a body leaves a round %.3f of the time, expected one in eight" % gun.scavenge_chance)
	if gun.reserve_start + gun.magazine > gun.ammo_cap:
		_fail(
			(
				"the gun arrives carrying %d rounds against a ceiling of %d"
				% [gun.reserve_start + gun.magazine, gun.ammo_cap]
			)
		)
	if gun.attack_at(1).ammo_cost != 2:
		_fail("the double tap costs %d rounds, expected 2" % gun.attack_at(1).ammo_cost)
	if not gun.attack_at(2).charges:
		_fail("the charged shot does not charge")


## The stick's whole reason to exist. Two farmers, one swing, both hit — and the fists standing in
## the same place reach only one, which is what makes it a choice rather than a straight upgrade.
func _check_the_stick_sweeps_two_at_once() -> void:
	var left := _stand_a_farmer_at(Vector3(-SIDE_STEP, 0.0, -AHEAD))
	var right := _stand_a_farmer_at(Vector3(SIDE_STEP, 0.0, -AHEAD))
	if left == null or right == null:
		_fail("could not stand two farmers in front of the player")
		return
	await get_tree().physics_frame
	GameState.loadout.found.append(&"stick")
	GameState.loadout.equip(&"stick")
	await get_tree().physics_frame
	var before := [left.health.current_health, right.health.current_health]
	var swing := _player.weapon.attack_at(0)
	_player.hitbox.arm(swing, _player, false, 1.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player.hitbox.disarm()
	if left.health.current_health >= before[0] or right.health.current_health >= before[1]:
		_fail("one 120° sweep did not reach both farmers standing inside it")
	# And never twice in the same swing, which is what `_already_hit` is for.
	var after := left.health.current_health
	_player.hitbox.arm(swing, _player, false, 1.0)
	await get_tree().physics_frame
	_player.hitbox.disarm()
	if left.health.current_health < after - swing.damage - 0.01:
		_fail("a single swing hit the same farmer more than once")
	left.retire()
	right.retire()


func _check_the_overhead_finishes() -> void:
	GameState.loadout.equip(&"stick")
	await get_tree().physics_frame
	var overhead := _player.weapon.attack_at(2)
	_player.close_chain()
	_player.machine.current.transition_to(&"Attack", {"index": 2, "perfect": false})
	await _wait(overhead.windup + overhead.active + 0.05)
	if not _player.chain_locked():
		_fail("the stick's finisher did not spend the chain")
	await _wait(_player.lockout_left() + 0.1)


func _check_the_gun_comes_loaded() -> void:
	var bag := GameState.loadout
	bag.find_weapon(&"gun")
	var gun := Arsenal.find(&"gun")
	if bag.magazine != gun.magazine:
		_fail("the gun arrived with %d rounds in it, expected %d" % [bag.magazine, gun.magazine])
	if bag.reserve != gun.reserve_start:
		_fail("the pocket started at %d, expected %d" % [bag.reserve, gun.reserve_start])
	if bag.equipped != &"gun":
		_fail("picking the gun up did not put it in hand")


## A ray, not a box: the shot resolves the instant the windup ends, so a farmer standing in front
## takes it and one standing aside does not.
func _check_a_shot_needs_a_round() -> void:
	var target := _stand_a_farmer_at(Vector3(0.0, 0.0, -6.0))
	if target == null:
		_fail("could not stand a farmer in front of the gun")
		return
	await get_tree().physics_frame
	var bag := GameState.loadout
	var before := target.health.current_health
	var rounds := bag.magazine
	_player.hitscan.fire(_player.weapon.attack_at(0), _player, false, 1.0)
	await get_tree().physics_frame
	if target.health.current_health >= before:
		_fail("a shot at a farmer six metres away missed")
	bag.magazine = 0
	_player.close_chain()
	_player.machine.current.transition_to(&"Attack", {"index": 0, "perfect": false})
	await get_tree().physics_frame
	if _player.machine.current is PlayerAttack:
		_fail("the trigger fired on an empty magazine")
	bag.magazine = rounds
	target.retire()
	await get_tree().physics_frame


func _check_the_double_tap_needs_two() -> void:
	var bag := GameState.loadout
	bag.magazine = 1
	if bag.spend(2):
		_fail("the double tap fired with one round in the magazine")
	bag.magazine = 2
	if not bag.spend(2):
		_fail("the double tap was refused with two rounds in the magazine")
	if bag.magazine != 0:
		_fail("the double tap left %d rounds behind" % bag.magazine)


## The gun's rhythm, stated as a check: **nothing refills on a clock.** A cleared wave pays money
## and nothing else, and the pocket is exactly where the last fight left it.
func _check_a_cleared_wave_hands_over_no_rounds() -> void:
	var bag := GameState.loadout
	bag.magazine = 0
	bag.reserve = 0
	EventBus.wave_cleared.emit(3, 0)
	if bag.carried() != 0:
		_fail("a cleared wave handed over %d rounds; nothing should" % bag.carried())


## The ceiling, and the fact that it counts the magazine. A bag that could be topped up past it
## would make the number on the panel a suggestion.
func _check_the_pocket_stops_at_the_ceiling() -> void:
	var bag := GameState.loadout
	var gun := Arsenal.find(&"gun")
	bag.magazine = gun.magazine
	bag.reserve = 0
	var taken := bag.take(gun.ammo_cap * 2)
	if bag.carried() != gun.ammo_cap:
		_fail("the bag holds %d rounds against a ceiling of %d" % [bag.carried(), gun.ammo_cap])
	if taken != gun.ammo_cap - gun.magazine:
		_fail("a full top-up reported %d rounds taken, expected %d" % [taken, bag.room()])
	if bag.take(1) != 0:
		_fail("a full bag took another round")


## One body in eight leaves a round. The roll is handed in rather than made, so this asks the
## question with a known answer instead of firing ten thousand kills and squinting at the total.
func _check_a_body_in_eight_leaves_a_round() -> void:
	var bag := GameState.loadout
	var chance := Arsenal.find(&"gun").scavenge_chance
	bag.magazine = 0
	bag.reserve = 0
	if bag.scavenge(chance * 0.5) != 1:
		_fail("a roll inside the chance left nothing behind")
	if bag.scavenge(chance) != 0:
		_fail("a roll on the chance itself left a round behind")
	if bag.scavenge(1.0) != 0:
		_fail("a roll past the chance left a round behind")
	if bag.carried() != 1:
		_fail("three rolls left %d rounds in the bag, expected one" % bag.carried())


func _check_reloading_takes_from_the_pocket() -> void:
	var bag := GameState.loadout
	bag.magazine = 1
	bag.reserve = 10
	_player.machine.current.transition_to(&"Reload")
	await _wait(_player.weapon.reload_time + 0.15)
	if bag.magazine != Arsenal.find(&"gun").magazine:
		_fail("the reload left %d rounds in the magazine" % bag.magazine)
	if bag.reserve != 5:
		_fail("the reload took the wrong number out of the pocket, leaving %d" % bag.reserve)
	# Nothing to gain, nothing to start: a full magazine is not a reload.
	if bag.can_reload():
		_fail("a full magazine still offered a reload")


func _check_the_wheel_only_offers_what_was_found() -> void:
	var only_fists: Array = []
	if Arsenal.next_owned(&"fists", only_fists, 1) != &"fists":
		_fail("the wheel offered a weapon that had not been found")
	var both: Array = [&"stick", &"gun"]
	var after := Arsenal.next_owned(&"fists", both, 1)
	if after != &"stick":
		_fail("cycling forward from the fists reached %s, expected the stick" % after)
	if Arsenal.next_owned(&"fists", both, -1) != &"gun":
		_fail("cycling back from the fists did not wrap round to the gun")


## A chain is a set of windows belonging to one weapon. Carrying it across a swap would let a player
## open with a jab and finish with an overhead, on the jab's timing.
func _check_a_swap_drops_the_chain() -> void:
	GameState.loadout.equip(&"fists")
	await get_tree().physics_frame
	_player.open_chain(_player.weapon.attack_at(0), 0)
	if _player.chain_index != 0:
		_fail("the chain did not open")
		return
	GameState.loadout.equip(&"stick")
	await get_tree().physics_frame
	if _player.chain_index >= 0:
		_fail("swapping weapons carried the chain over")
	if _player.weapon.id != &"stick":
		_fail("the body is still holding %s after a swap" % _player.weapon.id)


func _check_a_pickup_hands_the_weapon_over() -> void:
	GameState.begin_run()
	var pickups := _arena.get_node_or_null("PickupDirector") as PickupDirector
	if pickups == null:
		_fail("the arena has no pickup director")
		return
	var stick := Arsenal.find(&"stick")
	if stick.found_at_wave != 2 or Arsenal.find(&"gun").found_at_wave != 4:
		_fail("the stick and the gun do not turn up on waves 2 and 4")
	var dropped := pickups.drop(stick)
	if dropped == null:
		_fail("nowhere on the island would take a pickup")
		return
	await get_tree().physics_frame
	dropped.take()
	if not GameState.loadout.owns(&"stick"):
		_fail("taking the pickup did not put the stick in the bag")
	if GameState.loadout.equipped != &"stick":
		_fail("taking the pickup did not put the stick in hand")
	# A second pickup of something already carried must not re-arm anything.
	var again := pickups.drop(stick)
	if again != null:
		_fail("a weapon already in the bag was dropped again")


## A gun lying on the sand has to be the gun. It was a carved brown box the same shape as the stick
## — one placeholder serving both weapons — while the model itself sat in the player's rig, textured
## and unused. Nothing failed, because nothing was asking.
##
## What is asserted is that the pickup **borrows the rig's mesh** rather than that it looks like any
## particular thing: the number of triangles and the size are read off the rig at run time, so a
## regunned player moves the pickup with him and this check goes on holding the pair together.
func _check_the_gun_on_the_ground_is_the_gun() -> void:
	var pickups := _arena.get_node_or_null("PickupDirector") as PickupDirector
	if pickups == null:
		return
	var gun := Arsenal.find(&"gun")
	var dropped := pickups.drop(gun)
	if dropped == null:
		_fail("nowhere on the island would take a gun")
		return
	await get_tree().physics_frame
	var view := dropped.get_node_or_null("Mesh") as MeshInstance3D
	if view == null or view.mesh == null:
		_fail("the gun pickup has nothing to look at")
		return
	var in_the_rig := _the_rigs_gun()
	if in_the_rig == null:
		_fail("the player rig no longer carries a mesh called Gun, so a pickup cannot borrow one")
		return
	var on_the_ground := view.mesh.get_faces().size()
	if on_the_ground != in_the_rig.get_faces().size():
		_fail(
			(
				(
					"the gun on the ground is %d triangles against the rig's %d — it is not the same "
					+ "model, which means there are two of them"
				)
				% [on_the_ground / 3, in_the_rig.get_faces().size() / 3]
			)
		)
	# **And wearing its own paint.** The scene overrides surface 0 with the brown wood that makes the
	# carved placeholder read as a stick. Borrowing the mesh without clearing that override leaves
	# the gun lying there the same colour as the stick, which is most of what was wrong to begin
	# with — and the triangle count above passes happily while it happens.
	for surface: int in view.get_surface_override_material_count():
		if view.get_surface_override_material(surface) != null:
			_fail(
				(
					(
						"the gun on the ground is repainted by the pickup's own override on surface %d, "
						+ "so it is the gun wearing the stick's colour"
					)
					% surface
				)
			)
	var worn := view.get_active_material(0) as StandardMaterial3D
	if worn == null or worn.albedo_texture == null:
		_fail("the gun on the ground carries no painted texture, and the rig's gun does")

	# Standing where the director put it rather than buried or hovering. The mesh comes out of the
	# rig in the space it was modelled in, so a pickup that forgot to recentre it reads as a gun
	# half underground.
	var stands := view.transform * view.mesh.get_aabb()
	if stands.position.y < 0.0 or stands.position.y > WeaponPickup.RESTING_HEIGHT * 2.0:
		_fail(
			(
				(
					"the gun's lowest point sits at %.2f m, and a weapon on the ground belongs between "
					+ "0 and %.2f"
				)
				% [stands.position.y, WeaponPickup.RESTING_HEIGHT * 2.0]
			)
		)
	if stands.size.y > stands.size.x and stands.size.y > stands.size.z:
		_fail(
			(
				"the gun is standing on end — %.2f m tall against %.2f × %.2f on the floor"
				% [stands.size.y, stands.size.x, stands.size.z]
			)
		)
	dropped.queue_free()


## The ranged pool is one token wide, so a token nobody hands back is every later thrower standing
## in the field politely waiting its turn — for the rest of the run, with nothing saying so.
##
## `Enemy.release_token` refuses to let go while this body still has a stone in the air, which is
## right for a living thrower and wrong for one leaving the fight: `sleep()` went through the same
## call, so a body retired by `spawner.clear()` at the end of a wave only managed to *owe* the
## token, and `revive()` then cleared the debt on the way out of the pool.
##
## The commonest way in is the ordinary one — a wave ending while a stone is still travelling — so
## that is what this stages.
func _check_a_thrower_retired_mid_throw_hands_its_token_back() -> void:
	var tokens := get_tree().get_first_node_in_group(&"attack_tokens") as AttackTokens
	if tokens == null or _director == null or _director.spawner == null:
		_fail("the arena has no attack tokens or no spawner")
		return
	var data := load(THROWER) as EnemyData
	var thrower := _director.spawner.spawn_at(
		data, _player.global_position + Vector3(0.0, 0.0, 12.0)
	)
	if thrower == null:
		_fail("no thrower could be stood up")
		return
	await get_tree().physics_frame
	if not thrower.claim_token():
		_fail("a lone thrower could not claim the one ranged token")
		return
	# Aimed far enough away that the stone is unquestionably still in the air on the next line.
	thrower.throw_at(_player.global_position)
	if not tokens.holds(thrower, true):
		_fail("a thrower with a stone in the air is not holding the ranged token")
		return
	thrower.retire()
	if tokens.holds(thrower, true):
		_fail(
			(
				"a thrower retired with a stone in the air kept the ranged token — every later "
				+ "thrower will close, circle, and never commit"
			)
		)
		return
	# And the body that comes out of the pool next can actually use it. Checked separately, because
	# `claim` answers yes to an id the pool already holds: a stale entry is invisible to the body
	# that left it and only ever bites the next one.
	var second := _director.spawner.spawn_at(
		data, _player.global_position + Vector3(0.0, 0.0, 13.0)
	)
	if second == null:
		_fail("no second thrower could be stood up")
		return
	await get_tree().physics_frame
	if not second.claim_token():
		_fail("the next thrower out of the pool could not claim the ranged token")
	second.retire()


## A pickup is a node in the arena and nothing saves it, so a weapon offered on exactly one wave is
## a weapon a resumed run never sees. The stick is due on wave 2; a run that comes back on wave 3
## with an empty bag still has to be given one.
func _check_a_weapon_is_owed_from_its_wave_rather_than_offered_on_it() -> void:
	var pickups := _arena.get_node_or_null("PickupDirector") as PickupDirector
	if pickups == null:
		_fail("the arena has no pickup director")
		return
	var stick := Arsenal.find(&"stick")
	if stick == null or stick.found_at_wave <= 0:
		_fail("the stick has no wave to turn up on")
		return
	# A clean bag, which is what a resumed run that never found the stick has.
	GameState.begin_run()
	EventBus.wave_started.emit(stick.found_at_wave + 1, 0)
	if _stick_on_the_island(pickups) != 1:
		_fail(
			(
				(
					"the stick is due on wave %d and a run resumed on wave %d was given %d of them — "
					+ "a weapon nobody picked up is lost for the whole run"
				)
				% [stick.found_at_wave, stick.found_at_wave + 1, _stick_on_the_island(pickups)]
			)
		)
	# And exactly one. Owed-from-here without a memory of what has been dropped is a stick a wave.
	EventBus.wave_started.emit(stick.found_at_wave + 2, 0)
	if _stick_on_the_island(pickups) != 1:
		_fail(
			(
				(
					"the island carries %d sticks after two waves — a weapon already lying there must "
					+ "not be dropped again"
				)
				% _stick_on_the_island(pickups)
			)
		)


func _stick_on_the_island(pickups: PickupDirector) -> int:
	var found := 0
	for child: Node in pickups.get_children():
		var pickup := child as WeaponPickup
		if pickup != null and pickup.weapon_id == &"stick":
			found += 1
	return found


## The mesh the player rig carries, read straight out of the model rather than through the pickup,
## so the two are compared rather than one being asked about itself.
func _the_rigs_gun() -> Mesh:
	var packed := load(WeaponPickup.RIG) as PackedScene
	if packed == null:
		return null
	var rig := packed.instantiate()
	var found: Mesh = null
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh != null and mesh.name == "Gun":
			found = mesh.mesh
			break
	rig.free()
	return found


func _stand_a_farmer_at(offset: Vector3) -> Enemy:
	if _director == null or _director.spawner == null:
		return null
	var data := load(FARMHAND) as EnemyData
	# Never an elite: these are targets for measuring a swing, and a rolled rank would move the
	# health the measurement is taken against. Harmless, so nobody swings back mid-check.
	return _director.spawner.spawn_at(
		data, _player.global_position + offset, 20.0, 1.0, 1.0, 1.0, null, true
	)


func _open_the_arena() -> void:
	GameState.begin_run()
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	await get_tree().physics_frame
	_player = _arena.get_node_or_null("Player") as Player
	_director = _arena.get_node_or_null("WaveDirector") as WaveDirector
	var tutorial := _arena.get_node_or_null("TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	if _director != null:
		_director.halt()
	if _player == null:
		_fail("the arena holds no player")


## Counted in physics frames, never in real seconds. A headless run of the whole island simulates
## far slower than the clock on the wall, so a real-time wait would return after two ticks and read
## a state that has barely started.
func _wait(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().physics_frame
		elapsed += 1.0 / 60.0


func _expect(got: float, wanted: float, what: String) -> void:
	if not is_equal_approx(got, wanted):
		_fail("%s is %.2f, the table says %.2f" % [what, got, wanted])


func _put_the_run_back() -> void:
	if _kept_run.is_empty():
		SaveManager.clear_run()
		return
	SaveManager.write_json(SaveManager.RUN_PATH, _kept_run)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if _failures.is_empty():
		print(
			(
				"weapons OK — the stick sweeps two, the gun rations against a ceiling the bodies "
				+ "refill, nothing carries across a swap, and the gun on the ground is the gun"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
