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
	_check_a_body_in_three_leaves_a_round()
	await _check_reloading_takes_from_the_pocket()
	_check_the_wheel_only_offers_what_was_found()
	await _check_a_swap_drops_the_chain()
	await _check_a_pickup_hands_the_weapon_over()
	await _check_a_weapon_owed_from_an_earlier_wave_still_arrives()
	await _check_the_gun_on_the_ground_is_the_gun()
	_check_every_track_names_a_weapon_that_turns_up()
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
	if not is_equal_approx(gun.scavenge_chance, 0.333):
		_fail("a body leaves a round %.3f of the time, expected one in three" % gun.scavenge_chance)
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


## One body in three leaves a round. The roll is handed in rather than made, so this asks the
## question with a known answer instead of firing ten thousand kills and squinting at the total. The
## round lands on the sand rather than in the bag — `verify_loot` holds the walking over it.
func _check_a_body_in_three_leaves_a_round() -> void:
	var bag := GameState.loadout
	var chance := Arsenal.find(&"gun").scavenge_chance
	if not bag.rolls_a_round(chance * 0.5):
		_fail("a roll inside the chance left nothing behind")
	if bag.rolls_a_round(chance):
		_fail("a roll on the chance itself left a round behind")
	if bag.rolls_a_round(1.0):
		_fail("a roll past the chance left a round behind")


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
	# Written out rather than read off the resource: a check that agrees with whatever the data says
	# is not a check. Both lie on the island from the first wave — the three weapons are a choice,
	# and the choice cannot be offered until all three are in the bag.
	if stick.found_at_wave != 1 or Arsenal.find(&"gun").found_at_wave != 1:
		_fail(
			(
				"the stick turns up on wave %d and the gun on wave %d, and both belong on wave 1"
				% [stick.found_at_wave, Arsenal.find(&"gun").found_at_wave]
			)
		)
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


## A pickup is a node in the arena and not a saved fact, and the bag records what was *found* rather
## than what is lying in the grass. So a weapon is owed from its wave onwards: a player who cleared
## wave 2 without walking over the stick and resumed at wave 3 used to play the rest of the run on
## fists, and nothing ever offered it again.
func _check_a_weapon_owed_from_an_earlier_wave_still_arrives() -> void:
	GameState.begin_run()
	var pickups := _arena.get_node_or_null("PickupDirector") as PickupDirector
	if pickups == null:
		_fail("the arena has no pickup director")
		return
	_clear_the_ground(pickups)

	# Wave 3, in a run that was never handed the stick due on wave 2.
	EventBus.wave_started.emit(3, 0)
	await get_tree().physics_frame
	if _lying_about(pickups, &"stick") != 1:
		_fail("a run resumed past wave 2 was not given the stick it never received")

	EventBus.wave_started.emit(4, 0)
	await get_tree().physics_frame
	if _lying_about(pickups, &"stick") != 1:
		_fail("the stick already lying on the island was dropped a second time")
	if _lying_about(pickups, &"gun") != 1:
		_fail("the gun due on wave 4 did not arrive with it")
	_clear_the_ground(pickups)


func _lying_about(pickups: PickupDirector, id: StringName) -> int:
	var count := 0
	for child: Node in pickups.get_children():
		var pickup := child as WeaponPickup
		if pickup != null and pickup.weapon_id == id and not pickup.is_queued_for_deletion():
			count += 1
	return count


## Freed by hand rather than with `queue_free` alone, so one case's leftovers can never be counted
## as the next case's answer a frame later.
func _clear_the_ground(pickups: PickupDirector) -> void:
	for child: Node in pickups.get_children():
		pickups.remove_child(child)
		child.queue_free()


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
	# **And big enough to be seen from where the camera is.** The gun landed in shot every time and
	# was walked past anyway: at its own scale it is a quarter of a metre of dark metal on pale sand,
	# twenty metres below a camera that cannot be moved. A pickup is an object to be noticed before
	# it is a model of anything.
	var longest := maxf(maxf(stands.size.x, stands.size.y), stands.size.z)
	if not is_equal_approx(longest, dropped.reads_at):
		_fail(
			(
				"the gun lies %.2f m long and everything on the ground is brought to %.2f"
				% [longest, dropped.reads_at]
			)
		)
	dropped.queue_free()


## The failure that sent this branch: **a track for a weapon nobody can find is money with nowhere
## to go.** The merchant refuses a weapon's upgrades until it is in the bag, so a weapon that is
## never dropped locks its own track for the whole run — and the player saving for it is saving for
## nothing. Asked of the tracks rather than of the weapons, because the track is the thing that
## makes the promise.
func _check_every_track_names_a_weapon_that_turns_up() -> void:
	for track: UpgradeTrack in Upgrades.all():
		if track.weapon.is_empty():
			continue
		var weapon := Arsenal.find(track.weapon)
		if weapon == null:
			_fail("the %s track upgrades a weapon that is not in the arsenal" % track.id)
			continue
		if weapon.id == Arsenal.STARTING:
			continue
		if weapon.found_at_wave <= 0:
			_fail(
				(
					"the %s track is for sale once the %s is carried, and the %s is never dropped"
					% [track.id, weapon.id, weapon.id]
				)
			)


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
