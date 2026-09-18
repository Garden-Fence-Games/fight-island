extends Node
## Headless proof that a knockdown begins, ends, and gives the body back.
##
## A ragdoll is the one thing in the game that takes a skeleton away from the animation and has to
## hand it over again, and **the handing back is what nothing else would catch**: a tumble left
## running when a corpse goes into the pool comes out of it still tumbling, several waves later, in
## front of a player who has no idea why the farmer who just spawned is lying down. It is invisible
## in a diff, it survives every other check in this folder, and it only ever shows up in a build.
## Run: godot --headless --path . res://tools/verify_knockdown.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## Where a leased body is put, clear of the player so nothing walks into the measurement.
const SPARRING_SPOT: Vector3 = Vector3(0.0, 0.0, -3.0)
## Frames to let a settle be reported and the body node catch up with it.
const SETTLE_FRAMES: int = 8
## How long a knockdown is given to run its course before the check stops waiting. Comfortably past
## the ceiling the heaviest blow in the game buys itself.
const KNOCKDOWN_PATIENCE: float = 6.0
## How far a farmer has to have been thrown for the blow to have been a knockdown rather than a
## nudge. A body that moves less than this was not sent anywhere.
## How far the hit volume may sit from the hips while the ragdoll drives, measured on the ground
## plane. Not zero: the capsule is centred on the hips and the hips swing under a tumbling body, so
## a little slack is the shape of the thing rather than a defect. A metre is not slack, it is a
## different place.
const HURTBOX_DRIFT: float = 0.35
## A recoil, as the gun tables it: a tenth of a second, and a nudge rather than a throw.
const A_RECOIL: float = 0.10
const A_RECOIL_PUSH: float = 2.0
const SENT_SPRAWLING: float = 0.5
## The heaviest stagger figure the fists carry, and the push it buys. Written out rather than loaded
## off the uppercut, so a check measuring a knockdown does not quietly stop measuring one the day
## somebody retunes the attack.
const A_HEAVY_BLOW: float = 0.6
## How far the measured rise may sit from the figure the resource carries. Generous — this is here
## to prove the state reads that figure at all, not to time it to the frame.
const RISE_SLACK: float = 0.4
## The longest a knockdown may keep a man down and still be a knockdown, whatever the resource says.
## **This one does not scale with the figure**, and that is the point: a bound derived from the
## number being checked passes for every number, including a rise set to half a minute.
const LONGEST_SENSIBLE_RISE: float = 2.0
## The gun, the shot fired to measure its recoil, and the joint the measurement is read off.
const GUN: StringName = &"gun"
const SHOT: int = 0
const STILL_BONE: StringName = &"mixamorig_Hips"

var _failures: PackedStringArray = []
var _arena: Node3D = null


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	var tutorial := _arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
	await get_tree().physics_frame
	var director := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if director == null:
		_fail("the arena runs no waves, so there is no pool to lease a body from")
		_report()
		return
	director.halt()
	await _check_a_knockdown_ends_and_hands_the_body_back(director)
	await _check_a_shot_kicks_the_arm_and_nothing_else()
	await _check_a_knockdown_outranks_a_recoil()
	_report()


## The recoil, which is the other way a skeleton is taken from the animation — and the interesting
## half is everything it must **not** do.
##
## A shot throws the shooting arm at the ragdoll for a tenth of a second and the simulator eases it
## back onto the clip. So `is_running` stays false for the whole of it — a recoil is not a
## knockdown, and everything that stops animating when the body is taken over has to go on getting
## no — the hips are never handed over, and when it is done the simulation is stopped, or the next
## shot would start from a modifier that is already half off.
func _check_a_shot_kicks_the_arm_and_nothing_else() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var gun := Arsenal.find(GUN)
	if player == null or gun == null or player.ragdoll == null:
		_fail("the arena has no player with a ragdoll, or no gun to fire")
		return
	if not player.ragdoll.is_ready():
		_fail("the player carries no rigged skeleton to kick")
		return
	GameState.loadout.find_weapon(GUN)
	GameState.loadout.equip(GUN)
	await get_tree().physics_frame

	var attack := gun.attack_at(SHOT)
	player.machine.current.transition_to(&"Attack", {"index": SHOT})
	var fired := false
	var clock := 0.0
	while clock < attack.windup + attack.recoil_lasts:
		await get_tree().physics_frame
		clock += get_physics_process_delta_time()
		if not player.ragdoll.is_kicking():
			continue
		fired = true
		if player.ragdoll.is_running():
			_fail("a shot put the whole body in the physics — a recoil is not a knockdown")
			return
		# Whether the bone is simulating at all, rather than how far it turned: a body taken over
		# from rest barely moves in a tenth of a second, so measuring the pose would pass a recoil
		# that had quietly taken the whole skeleton.
		var waist := player.ragdoll.body_of(STILL_BONE)
		if waist != null and waist.is_simulating_physics():
			_fail("a shot handed the hips to the physics — the kick is the shooting arm's alone")
			return
	if not fired:
		_fail("the round left and the arm was never handed to the physics")
		return
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if player.ragdoll.is_kicking():
		_fail("the recoil never ended and the arm is still the physics engine's")


## The knockdown, end to end. A ragdoll is the one thing here that takes the body away from the
## animation and has to give it back, and **the giving back is what nothing else would catch**: a
## tumble left running when a corpse goes into the pool comes out of it still tumbling, five waves
## later, in front of a player who has no idea why the farmer who just spawned is lying down.
##
## Five claims: he is thrown, the body node ends where the hips did rather than where he was
## standing when the blow landed, he gets up the way he actually fell, he is back on his feet in the
## time that get-up takes, and a body retired mid-fall does not come back out of the pool still
## falling.
## Dying in the six frames after firing. The recoil owns `_physics_process` while it lasts, so a
## knockdown started inside one used to be stranded: never advanced, and then killed outright when
## the kick ran out and stopped the simulation it had no idea was now the whole body. The player
## died standing frozen instead of falling — which is what a death looks like when the one thing
## that sells it never happens.
func _check_a_knockdown_outranks_a_recoil() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null or player.ragdoll == null or not player.ragdoll.is_ready():
		_fail("the arena has no player with a rigged skeleton, so the race cannot be staged")
		return

	player.ragdoll.kick(Vector3.BACK, A_RECOIL_PUSH, A_RECOIL)
	if not player.ragdoll.is_kicking():
		_fail("the recoil would not start, so nothing here is being tested")
		return

	# Inside the kick, which is the whole point: a frame later and the race is gone.
	player.ragdoll.knock(Vector3.BACK, A_HEAVY_BLOW * Enemy.KNOCKDOWN.knock_speed)
	if not player.ragdoll.is_running():
		_fail("a killing blow during a recoil never started the fall at all")
		player.ragdoll.stop()
		return
	if player.ragdoll.is_kicking():
		_fail("the recoil outlived the knockdown, and it is the recoil that stops the simulation")

	var waist := player.ragdoll.body_of(STILL_BONE)
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if waist != null and not waist.is_simulating_physics():
		_fail("the hips stopped simulating during the fall, so the body is frozen upright")
	if not player.ragdoll.is_running():
		_fail("the fall ended within a few frames of starting, which is a fall that never happened")
	player.ragdoll.stop()
	await get_tree().physics_frame


func _check_a_knockdown_ends_and_hands_the_body_back(director: WaveDirector) -> void:
	var farmer := director.spawner.spawn_at(load(FARMHAND) as EnemyData, SPARRING_SPOT)
	if farmer == null:
		_fail("the pool would not lease a farmhand to knock down")
		return
	# The ragdoll builds its bones deferred — a parent mid-instantiation refuses `add_child` — so a
	# freshly leased body is not rigged on the frame it appears.
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	if farmer.ragdoll == null or not farmer.ragdoll.is_ready():
		_fail("the farmer carries no ragdoll, so a blow can only ever rock him where he stands")
		farmer.retire()
		return
	farmer.passive = true
	await get_tree().physics_frame
	var stood := farmer.global_position

	# How he lay the instant he settled, read by a listener connected **before** the state's own: the
	# state lets go of the skeleton in its handler, and after that the bones say he is standing.
	var landing := {}
	var read_the_landing := func() -> void:
		landing["face_up"] = farmer.ragdoll.lies_face_up()
		landing["heading"] = farmer.ragdoll.settled_heading()
	farmer.ragdoll.came_to_rest.connect(read_the_landing)

	# The heaviest thing the fists can throw, from a direction of its own so the push is not a
	# rounding error on the way he happens to be facing.
	farmer.stagger(A_HEAVY_BLOW, Vector3.FORWARD, A_HEAVY_BLOW, true)
	await get_tree().physics_frame
	if not farmer.ragdoll.is_running():
		_fail("a farmer took an uppercut and the physics never took his body")
		farmer.passive = false
		farmer.retire()
		return

	var waited := 0.0
	# Sampled **during** the tumble, which is the window every other assertion here skips. The body
	# node is pinned where he was launched from while only the bones travel, so a hurtbox left as an
	# ordinary child of it is a hit volume sitting metres from the man the player can see.
	var worst_drift := 0.0
	while farmer.ragdoll.is_running() and waited < KNOCKDOWN_PATIENCE:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
		if farmer.hurtbox != null:
			var hips := farmer.ragdoll.settled_position()
			var box := farmer.hurtbox.global_position
			worst_drift = maxf(worst_drift, Vector2(hips.x - box.x, hips.z - box.z).length())
	if worst_drift > HURTBOX_DRIFT:
		_fail(
			(
				(
					"while he was falling his hurtbox was %.2f m from his hips, and %.2f m is the most "
					+ "that still lets a player hit the body they are looking at"
				)
				% [worst_drift, HURTBOX_DRIFT]
			)
		)
	if farmer.ragdoll.is_running():
		_fail(
			(
				(
					"a knockdown was still running after %.1f s — a tumble with no end is a farmer who "
					+ "never gets up"
				)
				% KNOCKDOWN_PATIENCE
			)
		)

	# The state has to follow the body out of the fall. Given a few frames, because the settle is
	# reported on one frame and the body node catches up on the next.
	for _index: int in SETTLE_FRAMES:
		await get_tree().physics_frame
	var thrown := farmer.global_position.distance_to(stood)
	if thrown < SENT_SPRAWLING:
		_fail(
			(
				(
					"a farmer hit for %.1f stagger ended %.2f m from where he stood, and %.2f m is the "
					+ "least that reads as having been thrown"
				)
				% [A_HEAVY_BLOW, thrown, SENT_SPRAWLING]
			)
		)

	if farmer.ragdoll.came_to_rest.is_connected(read_the_landing):
		farmer.ragdoll.came_to_rest.disconnect(read_the_landing)
	# He gets up **the way he fell**: sitting up off his back, rolling over first off his front. A
	# stomach clip played on a man lying face up folds him backwards through the ground.
	var clip := farmer.animation.current_clip() if farmer.animation != null else &""
	if landing.is_empty():
		_fail("the tumble ended without the ragdoll ever reporting how he lay")
	else:
		var expected := (
			EnemyStagger.GET_UP_BACK if landing["face_up"] else EnemyStagger.GET_UP_FRONT
		)
		if clip != expected:
			_fail(
				(
					"a farmer who landed %s got up with %s, and it had to be %s"
					% ["on his back" if landing["face_up"] else "on his front", clip, expected]
				)
			)
		# And the clip's head lies where the ragdoll's did, or the first frame of the get-up spins him
		# on the ground. Both clips put the head along the body's +Z.
		var heading: Vector3 = landing["heading"]
		# A lie read off the skeleton instead of the bodies reports a man standing: head straight
		# over hips, so no direction at all — and "face up" for every fall there has ever been.
		if heading.is_zero_approx():
			_fail("the ragdoll gave no direction for his head, so it was read off a standing pose")
		var head_of_the_clip := farmer.global_basis.z
		head_of_the_clip.y = 0.0
		if not heading.is_zero_approx() and heading.dot(head_of_the_clip.normalized()) < 0.95:
			_fail("the get-up starts with his head somewhere other than where the tumble left it")
	if farmer.head_look != null and not farmer.head_look.resting:
		_fail("a farmer getting up off the ground is still turning his head to watch the player")

	# Back on his feet, and **in the time the get-up takes**: the clip's own length, or the stand-in
	# `KnockdownData` carries for a rig with no clip. Two separate claims, and they fail for different
	# reasons: the state has to honour the figure it is given, and the figure has to stay inside what a
	# knockdown can be. Without the second, a rise set to half a minute is honoured perfectly and
	# nothing objects.
	var player := farmer.animation.animation_player if farmer.animation != null else null
	var wanted := Enemy.KNOCKDOWN.rise_time
	if player != null and clip != &"" and player.has_animation(String(clip)):
		wanted = player.get_animation(String(clip)).length
	if wanted > LONGEST_SENSIBLE_RISE:
		_fail(
			(
				"getting up is set to %.1f s, and past %.1f s a knockdown stops being a knockdown"
				% [wanted, LONGEST_SENSIBLE_RISE]
			)
		)
	var rising := 0.0
	while farmer.machine.current_name == &"Stagger" and rising < LONGEST_SENSIBLE_RISE + RISE_SLACK:
		await get_tree().physics_frame
		rising += 1.0 / 60.0
	if farmer.machine.current_name == &"Stagger":
		_fail("a farmer never got up: %.1f s after the tumble he is still in Stagger" % rising)
	elif absf(rising - wanted) > RISE_SLACK:
		_fail("getting up took %.2f s against the %.2f s the get-up lasts" % [rising, wanted])
	if farmer.head_look != null and farmer.head_look.resting:
		_fail("a farmer back on his feet never took his eyes off the ground")

	farmer.passive = false

	# And the whole point, which has to be asked **mid-tumble** or it asks nothing: a body retired
	# while the physics still has it must not come back out of the pool still falling. Waiting for
	# the first knockdown to end and only then retiring would assert an invariant that had already
	# made itself true.
	farmer.stagger(A_HEAVY_BLOW, Vector3.FORWARD, A_HEAVY_BLOW, true)
	await get_tree().physics_frame
	if not farmer.ragdoll.is_running():
		_fail("the second knockdown never started, so nothing below was measured")
		farmer.retire()
		return
	farmer.retire()
	# Leased back through `revive` on **this** body rather than by asking the pool for one. The pool
	# hands out whichever body is free, which is usually not the one just retired — a check that
	# asked it for another farmer would measure a body that had never fallen and pass whatever the
	# handover does.
	farmer.revive(SPARRING_SPOT)
	await get_tree().physics_frame
	if farmer.ragdoll.is_running():
		_fail("a body retired mid-tumble came back out of the pool still falling")
	farmer.retire()


func _fail(message: String) -> void:
	_failures.append("knockdown check FAILED — " + message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"knockdown OK — a heavy blow throws a farmer, the tumble ends, the body follows his "
				+ "hips, he gets up the way he fell with the clip lined up on the ragdoll and his "
				+ "eyes off the player, he is up again in the time the get-up takes, and a body "
				+ "retired mid-fall comes back out of the pool standing"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
