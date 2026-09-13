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
	_report()


## The knockdown, end to end. A ragdoll is the one thing here that takes the body away from the
## animation and has to give it back, and **the giving back is what nothing else would catch**: a
## tumble left running when a corpse goes into the pool comes out of it still tumbling, five waves
## later, in front of a player who has no idea why the farmer who just spawned is lying down.
##
## Four claims: he is thrown, the body node ends where the hips did rather than where he was
## standing when the blow landed, he is back on his feet in the time the resource says getting up
## takes, and a body retired mid-fall does not come back out of the pool still falling.
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

	# The heaviest thing the fists can throw, from a direction of its own so the push is not a
	# rounding error on the way he happens to be facing.
	farmer.stagger(A_HEAVY_BLOW, Vector3.FORWARD, A_HEAVY_BLOW)
	await get_tree().physics_frame
	if not farmer.ragdoll.is_running():
		_fail("a farmer took an uppercut and the physics never took his body")
		farmer.passive = false
		farmer.retire()
		return

	var waited := 0.0
	while farmer.ragdoll.is_running() and waited < KNOCKDOWN_PATIENCE:
		await get_tree().physics_frame
		waited += 1.0 / 60.0
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

	# Back on his feet, and **in the time `KnockdownData` says it takes**. Two separate claims, and
	# they fail for different reasons: the state has to honour the figure it is given, and the figure
	# has to stay inside what a knockdown can be. Without the second, a rise set to half a minute is
	# honoured perfectly and nothing objects.
	var wanted := Enemy.KNOCKDOWN.rise_time
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
		_fail("getting up took %.2f s against the %.2f s the resource carries" % [rising, wanted])

	farmer.passive = false

	# And the whole point, which has to be asked **mid-tumble** or it asks nothing: a body retired
	# while the physics still has it must not come back out of the pool still falling. Waiting for
	# the first knockdown to end and only then retiring would assert an invariant that had already
	# made itself true.
	farmer.stagger(A_HEAVY_BLOW, Vector3.FORWARD, A_HEAVY_BLOW)
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
				+ "hips, he is up again in the time the resource carries, and a body retired "
				+ "mid-fall comes back out of the pool standing"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)
