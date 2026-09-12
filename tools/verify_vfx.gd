extends Node
## Headless proof of the decisions in the effects, not of the pixels — the renderer draws nothing
## here, and what matters is checkable without it: that a perfect hit is a different effect and not
## a louder one, that nothing is built in the middle of a fight, and that the two accessibility
## settings are actually read.
## Run: godot --headless --path . res://tools/verify_vfx.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const IMPACT: String = "res://scenes/fx/impact.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## More bursts than a wave can ask for at once, to see whether the pool holds.
const A_LOT_OF_HITS: int = 40
## Long enough for a knock to run most of its course.
const SHAKEN_FRAMES: int = 20
## How far the eye may drift along its own arm while being shaken. It should be nothing at all; a
## centimetre is float noise.
const ARM_SLACK: float = 0.01
## How high the top of a farmer's capsule sits above its own origin — half of a 1.7 m body. What
## the lean swings is the top, so this is what turns an angle into a silhouette.
const CAPSULE_TOP: float = 0.85
## How far that top has to swing before the tell carries at twenty metres. Against a body 0.7 m
## wide, this is the difference between a man standing and a man loaded: it is over half his own
## width, and at twenty metres it subtends about 1.4 degrees, which is roughly the moon.
const READS_AT_TWENTY_METRES: float = 0.45
## A degree of float noise, in radians. A lean read one physics frame apart can wobble by less.
const LEAN_SLACK: float = 0.02
## How far through its lean the body has to be on the last frame of a wind-up. Not all of it: the
## swing is thrown on the frame the wind-up runs out, so the final sample is always one frame short
## — on a wind-up halved to thirteen frames that is three degrees. What this has to separate is a
## tell driven by the duration from one running at its own rate, and the second lands near half.
const COMPLETES_BY: float = 0.9

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _pool: EffectPool = null


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	_stand_everything_down()
	await get_tree().process_frame
	_pool = _arena.get_node_or_null("Effects") as EffectPool
	if _pool == null:
		_fail("the arena has no effect pool")
		_report()
		return

	_check_every_attack_names_an_effect()
	_check_a_perfect_hit_is_a_different_effect()
	await _check_a_fight_never_builds_an_effect()
	_check_reduce_flashing_damps_the_flare_and_leaves_the_debris()
	await _check_a_player_who_turned_shake_off_gets_none()
	await _check_the_telegraph_is_a_shape()
	await _check_the_telegraph_keeps_the_wind_ups_own_time()
	await _check_a_farmer_never_stays_leaning()
	_report()


## An attack with no effect still works, which is exactly why a missing one is invisible. Every
## attack that ships has to name one, or a weapon lands with nothing to show for it.
func _check_every_attack_names_an_effect() -> void:
	var counted := 0
	for name: String in DirAccess.get_files_at("res://data/attacks"):
		var attack := load("res://data/attacks/%s" % name.trim_suffix(".remap")) as AttackData
		if attack == null:
			continue
		counted += 1
		if attack.vfx == null:
			_fail("%s lands with no effect" % attack.id)
	if counted == 0:
		_fail("there are no attacks to check")


## The design turns damage numbers off by default because the effect is supposed to carry it. So a
## perfect hit has to *look* different in more than one way — any single difference is one the
## player has to be told about.
func _check_a_perfect_hit_is_a_different_effect() -> void:
	var scene := load(IMPACT) as PackedScene
	var plain := _pool.lease(scene) as Impact
	var perfect := _pool.lease(scene) as Impact
	if plain == null or perfect == null:
		_fail("the pool would not lease two impacts")
		return
	plain.play(Vector3.ZERO, false)
	perfect.play(Vector3.ZERO, true)
	var differences := 0
	if perfect.debris.amount > plain.debris.amount:
		differences += 1
	if perfect.debris.initial_velocity_max > plain.debris.initial_velocity_max:
		differences += 1
	if perfect.debris.lifetime > plain.debris.lifetime:
		differences += 1
	if perfect.flare.scale.x > plain.flare.scale.x:
		differences += 1
	if differences < 3:
		_fail(
			"a perfect hit differs from a plain one in %d ways, and one is not enough" % differences
		)
	if not plain.debris.emitting:
		_fail("a landed hit threw no debris at all")


## Thirty enemies on screen is the budget and effects are the easiest way to lose it. One warm batch
## at the start is the deal; everything after that is a body that has already been used.
func _check_a_fight_never_builds_an_effect() -> void:
	var scene := load(IMPACT) as PackedScene
	var warmed := _pool.made_count()
	for _index: int in A_LOT_OF_HITS:
		var impact := _pool.lease(scene) as Impact
		if impact == null:
			_fail("the pool ran out of impacts")
			return
		impact.play(Vector3.ZERO, _index % 2 == 0)
		await _wait(0.05)
		impact.finish_now()
	if _pool.made_count() != warmed:
		_fail(
			(
				"%d hits built %d more effects — the pool is one in name only"
				% [A_LOT_OF_HITS, _pool.made_count() - warmed]
			)
		)


## Reduce-flashing damps the flare and **leaves the debris alone**. The debris is motion, not
## flashing, and taking it away would remove the hit's readability in the name of protecting the
## player from it.
func _check_reduce_flashing_damps_the_flare_and_leaves_the_debris() -> void:
	var scene := load(IMPACT) as PackedScene
	var bright := _pool.lease(scene) as Impact
	bright.play(Vector3.ZERO, true)
	var flare := bright.flare.scale.x
	var debris := bright.debris.amount
	bright.finish_now()
	Settings.set_value(&"access_reduce_flashing", true)
	var damped := _pool.lease(scene) as Impact
	damped.play(Vector3.ZERO, true)
	if damped.flare.scale.x >= flare:
		_fail("reduce-flashing left the flare at %.2f" % damped.flare.scale.x)
	if damped.debris.amount != debris:
		_fail("reduce-flashing took the debris too, which is what makes a hit readable")
	damped.finish_now()
	Settings.set_value(&"access_reduce_flashing", false)


## Nought means none, not a little. A slider a player has taken to zero that still moves the camera
## is worse than no slider.
func _check_a_player_who_turned_shake_off_gets_none() -> void:
	var rig := _arena.get_node_or_null("CameraRig") as CameraRig
	if rig == null:
		_fail("the arena has no camera rig")
		return
	Settings.set_value(&"access_screen_shake", 0)
	EventBus.shake_requested.emit(1.0)
	if rig.shake_left() > 0.0:
		_fail("shake is off and the camera was still knocked by %.2f" % rig.shake_left())
	Settings.set_value(&"access_screen_shake", 100)
	EventBus.shake_requested.emit(1.0)
	if rig.shake_left() <= 0.0:
		_fail("shake is on and the camera was not knocked at all")
	await _check_a_shake_does_not_move_the_eye(rig)


## The lesson this cost an afternoon to learn. The spring arm rewrites its child's **position**
## every frame to hold the eye at the end of the arm, so a shake written there is a shake the arm
## spends the frame undoing — and while they argue, the camera slides back down the arm towards the
## player. Every effect check still passed; the occlusion one broke, because the eye was no longer
## where anything thought it was.
##
## So: shake however you like, but the eye stays at arm's length.
func _check_a_shake_does_not_move_the_eye(rig: CameraRig) -> void:
	var settled := rig.camera.global_position.distance_to(rig.spring.global_position)
	EventBus.shake_requested.emit(1.0)
	var worst := 0.0
	for _frame: int in SHAKEN_FRAMES:
		await get_tree().process_frame
		var reach := rig.camera.global_position.distance_to(rig.spring.global_position)
		worst = maxf(worst, absf(reach - settled))
	if worst > ARM_SLACK:
		_fail(
			(
				(
					"shaking moved the eye %.2f m along its arm — the shake and the spring arm are"
					+ " fighting over the same transform"
				)
				% worst
			)
		)


## The director and the tutorial both want to run a wave, and this check is not about either.
func _stand_everything_down() -> void:
	var director := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if director != null:
		director.halt()
		director.process_mode = Node.PROCESS_MODE_DISABLED
	var tutorial := _arena.get_node_or_null("Tutorial")
	if tutorial != null:
		tutorial.process_mode = Node.PROCESS_MODE_DISABLED


func _wait(seconds: float) -> void:
	var waited := 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += 1.0 / 60.0


func _fail(message: String) -> void:
	_failures.append(message)


## **The telegraph is a shape.** The ring was removed in #122 and this is what replaced it, so the
## claim it used to carry has to come back with it: what warns the player is geometry, not colour.
##
## Asserted three ways, because "it moved" is not the claim. It has to move **enough to read at
## twenty metres**, it has to move **monotonically** — a body that tips and untips is a flicker, not
## a fill — and it has to leave the material alone, or a colourblind player is back where they were.
func _check_the_telegraph_is_a_shape() -> void:
	var farmer := _a_farmer_winding_up()
	if farmer == null:
		return
	var material := farmer.mesh.material_override as StandardMaterial3D
	var colour_before := material.albedo_color if material != null else Color.WHITE
	var glow_before := material.emission if material != null else Color.BLACK

	var leans := PackedFloat32Array()
	var windup := farmer.windup()
	for _frame: int in int(windup * 60.0) + 2:
		await get_tree().physics_frame
		if farmer.machine.current is EnemyWindUp:
			leans.append(farmer.mesh.rotation.x)

	if leans.size() < 4:
		_fail("the wind-up was over before the lean could be watched")
		return
	var most := leans[leans.size() - 1]
	# What the silhouette actually does, which is the thing that has to carry: the top of the body
	# sits `CAPSULE_TOP` above its own origin and swings by the sine of the lean.
	var swing := CAPSULE_TOP * sin(most)
	if swing < READS_AT_TWENTY_METRES:
		_fail(
			(
				(
					"the body tips %.1f°, swinging its top %.2f m — under the %.2f m a silhouette needs "
					+ "to read at twenty metres"
				)
				% [rad_to_deg(most), swing, READS_AT_TWENTY_METRES]
			)
		)
	for index: int in range(1, leans.size()):
		if leans[index] < leans[index - 1] - LEAN_SLACK:
			_fail(
				(
					"the lean went backwards at %d of %d — a body that tips and untips is a flicker"
					% [index, leans.size()]
				)
			)
			break
	if material != null:
		if material.albedo_color != colour_before or material.emission != glow_before:
			_fail("the wind-up changed the body's colour — the tell has to survive greyscale")
	_stand_him_down(farmer)


## **The picture keeps the wind-up's own time**, which is the whole reason the ring was driven by
## the duration rather than played as a clip. Waves shorten a wind-up and the hour shortens it
## again, so a tell at its own rate would finish early and lie about when the swing lands.
##
## Checked by halving it: the same farmer, the same tell, a wind-up scaled to half — and the body
## still has to be fully back at the moment it swings, not half way.
func _check_the_telegraph_keeps_the_wind_ups_own_time() -> void:
	var farmer := _a_farmer_winding_up(0.5)
	if farmer == null:
		return
	var windup := farmer.windup()
	var most := 0.0
	for _frame: int in int(windup * 60.0) + 2:
		await get_tree().physics_frame
		if farmer.machine.current is EnemyWindUp:
			most = maxf(most, farmer.mesh.rotation.x)
	var through := most / deg_to_rad(EnemyWindUp.LEAN_DEGREES)
	if through < COMPLETES_BY:
		_fail(
			(
				(
					"on a wind-up cut in half the body reached %.0f%% of its lean, and it has to reach "
					+ "%.0f%% — a picture running on its own clock would land near 50%%"
				)
				% [through * 100.0, COMPLETES_BY * 100.0]
			)
		)
	_stand_him_down(farmer)


## Every way out of a wind-up stands the body back up. The swing and the stagger go through `exit`;
## **a wave cleared mid-commit does not** — it retires the body through `sleep()` with no state ever
## exiting, and the next life would start leaning into a swing nobody threw.
func _check_a_farmer_never_stays_leaning() -> void:
	var farmer := _a_farmer_winding_up()
	if farmer == null:
		return
	for _frame: int in 6:
		await get_tree().physics_frame
	if is_zero_approx(farmer.mesh.rotation.x):
		_fail("the farmer never leaned at all, so standing him up proves nothing")
		_stand_him_down(farmer)
		return
	# The path with no `exit` in it.
	farmer.retire()
	await get_tree().physics_frame
	farmer.revive(Vector3(0.0, 0.0, -6.0))
	await get_tree().physics_frame
	if not is_zero_approx(farmer.mesh.rotation.x):
		_fail(
			"a body retired mid-commit came back leaning %.1f°" % rad_to_deg(farmer.mesh.rotation.x)
		)
	_stand_him_down(farmer)


## One farmer, committed, with nothing else able to touch him. `windup` scales his wind-up the way a
## wave and the hour do.
func _a_farmer_winding_up(windup: float = 1.0) -> Enemy:
	var director := _arena.get_node_or_null("WaveDirector") as WaveDirector
	if director == null:
		_fail("the arena has no wave director to lease a body from")
		return null
	var farmer := director.spawner.spawn_at(
		load(FARMHAND) as EnemyData, Vector3(0.0, 0.0, -6.0), 1.0, 1.0, 1.0, windup
	)
	if farmer == null or farmer.mesh == null:
		_fail("could not lease a farmer to watch")
		return null
	# **The pool lives under the director**, so standing the director down to keep waves out of this
	# check freezes every body it would lend out too — `revive` sets the body back to *inherit*, and
	# what it inherits is disabled. The first run of this watched a farmer who was never processing
	# and reported a tell that had simply never been asked to happen.
	farmer.process_mode = Node.PROCESS_MODE_ALWAYS
	farmer.machine.current.transition_to(&"WindUp")
	return farmer


func _stand_him_down(farmer: Enemy) -> void:
	if farmer != null and is_instance_valid(farmer):
		farmer.retire()


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"vfx OK — every attack names an effect, a perfect hit differs three ways, a "
				+ "fight builds nothing, and a farmer rears back in a shape that keeps the "
				+ "wind-up's own time and never stays leaning"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("vfx FAILED — %s" % failure)
	get_tree().quit(1)
