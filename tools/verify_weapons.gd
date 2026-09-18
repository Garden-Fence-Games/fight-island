extends Node
## Headless proof of the three things the stick and the gun are for, and of the one rule that makes
## them a choice rather than an upgrade.
##
## **The stick's arc hits more than one body.** That is the entire reason it exists, and it is also
## the thing no diff shows: the arc is a number in a `.tres` and the sweep is geometry, so the only
## way to know 120° still means 120° is to stand two farmers inside it.
##
## **The gun's rhythm is its rounds.** One count, no magazine and no reload: every round fires, and
## running dry mid-wave is designed — so the checks here are about *when* it happens, a shot the
## rounds cannot pay for, and a count that nothing refills on a clock.
##
## **Nothing carries between weapons.** A chain is a set of windows belonging to one weapon; a swap
## has to close it rather than hand it over.
##
## Whatever run is on this machine is put back at the end.
## Run: godot --headless --path . res://tools/verify_weapons.tscn

## The least a weapon on the ground may measure across and still survive the pixel filter. The
## carved stick was 0.09 — about one fat pixel at seventeen metres — and a run went past it twice.
const THICK_ENOUGH: float = 0.15
## How many drawn frames the lamp is watched over. Enough that `_process` has certainly run on a
## pickup added this frame, so the reading is the breath's rather than the scene's opening value.
const BREATHS_SAMPLED: int = 10
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
	_check_a_body_in_three_leaves_rounds()
	await _check_there_is_no_reload()
	_check_the_wheel_only_offers_what_was_found()
	await _check_a_swap_drops_the_chain()
	await _check_a_pickup_hands_the_weapon_over()
	await _check_a_weapon_owed_from_an_earlier_wave_still_arrives()
	await _check_the_gun_on_the_ground_is_the_gun()
	await _check_a_weapon_on_the_ground_can_be_found()
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
	if gun.rounds_start != 30 or gun.ammo_cap != 30:
		_fail("the gun arrives with %d rounds and caps at %d" % [gun.rounds_start, gun.ammo_cap])
	if not is_equal_approx(gun.scavenge_chance, 0.333):
		_fail("a body leaves rounds %.3f of the time, expected one in three" % gun.scavenge_chance)
	if gun.scavenge_most != 3:
		_fail("a body that drops rounds drops up to %d, expected 3" % gun.scavenge_most)
	if gun.rounds_start > gun.ammo_cap:
		_fail(
			(
				"the gun arrives carrying %d rounds against a ceiling of %d"
				% [gun.rounds_start, gun.ammo_cap]
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
	if bag.rounds != gun.rounds_start:
		_fail("the gun arrived with %d rounds, expected %d" % [bag.rounds, gun.rounds_start])
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
	var rounds := bag.rounds
	_player.hitscan.fire(_player.weapon.attack_at(0), _player, false, 1.0)
	await get_tree().physics_frame
	if target.health.current_health >= before:
		_fail("a shot at a farmer six metres away missed")
	bag.rounds = 0
	_player.close_chain()
	_player.machine.current.transition_to(&"Attack", {"index": 0, "perfect": false})
	await get_tree().physics_frame
	if _player.machine.current is PlayerAttack:
		_fail("the trigger fired with no rounds left")
	bag.rounds = rounds
	target.retire()
	await get_tree().physics_frame


func _check_the_double_tap_needs_two() -> void:
	var bag := GameState.loadout
	bag.rounds = 1
	if bag.spend(2):
		_fail("the double tap fired with one round left")
	bag.rounds = 2
	if not bag.spend(2):
		_fail("the double tap was refused with two rounds left")
	if bag.rounds != 0:
		_fail("the double tap left %d rounds behind" % bag.rounds)


## The gun's rhythm, stated as a check: **nothing refills on a clock.** A cleared wave pays money
## and nothing else, and the gun is exactly where the last fight left it.
func _check_a_cleared_wave_hands_over_no_rounds() -> void:
	var bag := GameState.loadout
	bag.rounds = 0
	EventBus.wave_cleared.emit(3, 0)
	if bag.carried() != 0:
		_fail("a cleared wave handed over %d rounds; nothing should" % bag.carried())


## The ceiling. A bag that could be topped up past it would make the number on the panel a
## suggestion.
func _check_the_pocket_stops_at_the_ceiling() -> void:
	var bag := GameState.loadout
	var gun := Arsenal.find(&"gun")
	bag.rounds = 0
	var taken := bag.take(gun.ammo_cap * 2)
	if bag.carried() != gun.ammo_cap:
		_fail("the bag holds %d rounds against a ceiling of %d" % [bag.carried(), gun.ammo_cap])
	if taken != gun.ammo_cap:
		_fail("a full top-up reported %d rounds taken, expected %d" % [taken, gun.ammo_cap])
	if bag.take(1) != 0:
		_fail("a full bag took another round")


## One body in three leaves rounds, and one that does leaves one, two or three, each a third of the
## time. The rolls are handed in rather than made, so this asks the question with known answers
## instead of firing ten thousand kills. The rounds land on the sand — `verify_loot` holds the rest.
func _check_a_body_in_three_leaves_rounds() -> void:
	var bag := GameState.loadout
	var chance := Arsenal.find(&"gun").scavenge_chance
	if bag.rounds_dropped(chance * 0.5, 0.0) == 0:
		_fail("a roll inside the chance left nothing behind")
	if bag.rounds_dropped(chance, 0.0) != 0:
		_fail("a roll on the chance itself left rounds behind")
	if bag.rounds_dropped(1.0, 0.5) != 0:
		_fail("a roll past the chance left rounds behind")
	# The count splits the unit into three equal thirds: one, two, three.
	var inside := chance * 0.5
	for pair: Array in [[0.0, 1], [0.32, 1], [0.34, 2], [0.65, 2], [0.67, 3], [0.999, 3], [1.0, 3]]:
		var dropped := bag.rounds_dropped(inside, pair[0])
		if dropped != pair[1]:
			_fail(
				"a count roll of %.3f dropped %d rounds, expected %d" % [pair[0], dropped, pair[1]]
			)


## The magazine and the reload are gone together: there is no `Reload` state, no `reload` action,
## and a gun with rounds fires every one of them in a row without stopping.
func _check_there_is_no_reload() -> void:
	if _player.machine.get_node_or_null(^"Reload") != null:
		_fail("the player still has a Reload state")
	if InputMap.has_action(&"reload"):
		_fail("the reload action is still bound")
	var bag := GameState.loadout
	var gun := Arsenal.find(&"gun")
	bag.rounds = gun.ammo_cap
	var single := gun.attack_at(0)
	var fired := 0
	while bag.spend(single.ammo_cost):
		fired += 1
		if fired > gun.ammo_cap:
			break
	if fired != gun.ammo_cap:
		_fail("a full gun fired %d single shots in a row, expected all %d" % [fired, gun.ammo_cap])
	bag.rounds = gun.ammo_cap
	await get_tree().physics_frame


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
## **Both weapons can be picked out of the sand**, which is a different question from whether the
## gun is the gun and is the one that was never asked.
##
## A stick is a bar of brown on sand and a revolver a palm of dark metal, under a camera fixed
## seventeen metres up and behind a filter that quantises the frame to fat pixels. The old carved
## stick was nine centimetres across — about one of those pixels — and both were walked past for a
## whole run. The coconut had this exact problem and its answer is the one copied here, so this
## check is `verify_coconut`'s, asked of the two weapons: light **on** the thing, a lamp under it,
## and no billboard, because a billboard renders as the square it is.
func _check_a_weapon_on_the_ground_can_be_found() -> void:
	var pickups := _arena.get_node_or_null("PickupDirector") as PickupDirector
	if pickups == null:
		return
	for id: StringName in [&"stick", &"gun"]:
		var weapon := Arsenal.find(id)
		var dropped := pickups.drop(weapon) if weapon != null else null
		if dropped == null:
			_fail("nowhere on the island would take a %s" % id)
			continue
		await get_tree().physics_frame
		var view := dropped.get_node_or_null(^"Mesh") as MeshInstance3D
		var glow := (
			view.get_surface_override_material(0) as StandardMaterial3D if view != null else null
		)
		if glow == null or not glow.emission_enabled or glow.emission_energy_multiplier <= 0.0:
			_fail("the %s does not light itself — it cannot be picked out of the sand" % id)
		# **Sampled over several drawn frames, never one.** The pulse writes this every `_process`, so
		# a single reading catches either the scene's opening value or the breath's, depending on
		# whether `_process` has run on a node added this frame — which is how this check passed for
		# one weapon and failed for the other on the same dark lamp. The dimmest it ever gets is the
		# honest question, and a lamp driven to nothing answers zero on every frame.
		var lamp := dropped.get_node_or_null(^"Glow") as OmniLight3D
		var dimmest := INF
		for _frame: int in BREATHS_SAMPLED:
			await get_tree().process_frame
			dimmest = minf(dimmest, lamp.light_energy if lamp != null else 0.0)
		if lamp == null or dimmest <= 0.0:
			_fail("the %s throws no light on the sand it lies on" % id)
		for node: Node in dropped.get_children():
			var quad := node as MeshInstance3D
			if quad != null and quad.mesh is QuadMesh:
				_fail("the %s carries a quad — a billboard reads as a square, not as a glow" % id)
		# Thin enough to vanish is the whole complaint, so the cross-section is held as well as the
		# length. Measured on the **transformed** bounds and at its thinnest: a bar tipped onto its
		# corner is as findable as its narrowest face, which is the one the filter eats.
		if view != null and view.mesh != null:
			var lies := (view.transform * view.mesh.get_aabb()).size
			var across := minf(lies.x, minf(lies.y, lies.z))
			if across < THICK_ENOUGH:
				_fail(
					(
						"the %s is %.2f m across, and %.2f is the least that survives the filter"
						% [id, across, THICK_ENOUGH]
					)
				)
		dropped.queue_free()


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
	#
	# The pickup does now carry an override of its own, to make the thing glow, so "no override at
	# all" has stopped being the way to ask. **The texture is** — it is the one thing the stick's
	# brown wood does not have and cannot fake, so holding the paint to the rig's own texture is the
	# same question with the answer that survived the glow.
	var worn := view.get_active_material(0) as StandardMaterial3D
	if worn == null or worn.albedo_texture == null:
		_fail("the gun on the ground carries no painted texture, and the rig's gun does")
	elif worn.albedo_texture != _the_rigs_guns_paint():
		_fail(
			"the gun on the ground is painted with something other than the rig gun's own texture"
		)

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
## The texture the rig's own gun is drawn with, which is what "wearing its own paint" means once the
## pickup is allowed a material of its own. Null when the rig carries no gun to read.
func _the_rigs_guns_paint() -> Texture2D:
	var mesh := _the_rigs_gun()
	if mesh == null:
		return null
	var worn := mesh.surface_get_material(0) as StandardMaterial3D
	return worn.albedo_texture if worn != null else null


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
