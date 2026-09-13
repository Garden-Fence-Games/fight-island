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
## How high the top of a farmer's capsule sits above its own origin — half of a 2.21 m body. What
## the lean swings is the top, so this is what turns an angle into a silhouette. It was half of
## 1.7 m while a farmer was a capsule; the rig is taller, and a figure that stayed behind would
## have gone on measuring a body nobody ships.
const CAPSULE_TOP: float = 1.105
## How far that top has to swing before the tell carries at twenty metres. This is an angular
## threshold, not a proportion of the body, so it does not move with the rig: at twenty metres
## 0.45 m subtends about 1.4 degrees, which is roughly the moon.
const READS_AT_TWENTY_METRES: float = 0.45
## A degree of float noise, in radians. A lean read one physics frame apart can wobble by less.
const LEAN_SLACK: float = 0.02
## How far through its lean the body has to be on the last frame of a wind-up. Not all of it: the
## swing is thrown on the frame the wind-up runs out, so the final sample is always one frame short
## — on a wind-up halved to thirteen frames that is three degrees. What this has to separate is a
## tell driven by the duration from one running at its own rate, and the second lands near half.
const COMPLETES_BY: float = 0.9
## How long to let the flock sweep for. **Seconds, not frames**: the flock acts on accumulated time
## and headless frames go by far faster than real ones, so a frame count that looks generous can be
## twenty milliseconds and never reach a single sweep. Three sweeps at the shipped interval.
const FLOCK_SECONDS: float = 0.9
## A ceiling on the wait, so a flock that stopped processing fails the check rather than hanging it.
const FLOCK_FRAME_CAP: int = 4000
## The lowest a bird standing on the island may be. **Not zero**: the plateau is y = 0 here and the
## beach descends from it to a waterline at −1.1 m, so the sea's reach is the swell's crest at
## −0.99 m and nothing higher. Written out rather than read off the generator, which would make this
## agree with whatever the thing it checks happens to say. This caught the flock refusing the entire
## shore, and before that the ordering bug that put every ground bird at the origin's height.
const DRY_SAND: float = -0.9
## How far above the player a sky bird has to be to read as sky rather than as scenery at head
## height. Well under the generator's own floor, so this fails on a collapse and not on a tweak.
const OVERHEAD: float = 6.0
## Frames to hold a direction for, long enough for the body to reach its speed and for the dust to
## have been asked about it at least once.
const UNDER_WAY: int = 30
## How much more dust a sprint has to kick up than a walk. The two rates are the feature the player
## asked for, and a ratio that drifts towards one is the feature quietly going away.
const SPRINT_DUST_GAIN: float = 1.5
const BIRD: String = "res://scenes/world/bird.tscn"
## One simulated frame for a bird driven by hand. The bird is stepped rather than left to run,
## because what is checked here is spread over seconds and headless frames do not take real ones.
const BIRD_STEP: float = 1.0 / 60.0
## How far the share of a cruise spent flapping may stray from the bird's own `flap_share`. Loose,
## because it is sampled over whole bouts and a sampled window never starts on a bout's edge.
const FLAP_SLACK: float = 0.08

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
	# The dust goes first on purpose: it is the only check here that needs the player standing on the
	# ground he started on, and the startle check below picks him up and puts him somewhere else.
	await _check_the_dust_rises_with_the_body()
	await _check_the_birds_stand_on_sand_and_fly_in_the_sky()
	await _check_a_bird_leaves_when_you_walk_into_it()
	_check_a_perched_bird_hops_and_keeps_its_wings_folded()
	_check_a_cruising_bird_flaps_a_third_of_the_time()
	_check_a_startled_bird_beats_and_flies_head_first()
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


## The birds are scenery, so nothing in a diff says whether they are anywhere a player will see
## them. Two things can go silently wrong and both have: a ground bird placed at a guessed height
## stands in the sea, and a sky bird that lost its altitude stands in the sand next to it.
func _check_the_birds_stand_on_sand_and_fly_in_the_sky() -> void:
	var flock := _arena.get_node_or_null("BirdFlock")
	if flock == null:
		_fail("the arena has no flock, so the island is empty of anything alive but enemies")
		return
	var player := _arena.get_node("Player") as Node3D
	await _let_the_flock_sweep()
	var grounded := 0
	var flying := 0
	for bird: Bird in _birds(flock):
		if bird.is_grounded():
			grounded += 1
			if bird.global_position.y < DRY_SAND:
				_fail("a bird is standing at y=%.2f, which is the sea" % bird.global_position.y)
		elif bird.is_flying():
			flying += 1
			var above := bird.global_position.y - player.global_position.y
			if above < OVERHEAD:
				_fail("a flying bird is only %.1f m above the player" % above)
	if grounded == 0:
		_fail("no bird is on the ground")
	if flying == 0:
		_fail("no bird is in the sky")


## The whole of what the birds are for. A shore that empties as you cross it costs nothing to
## simulate and tells the player the island was there before he was — so the startle is the feature,
## and a bird that sat still while being walked through would be worse than no bird.
func _check_a_bird_leaves_when_you_walk_into_it() -> void:
	var flock := _arena.get_node_or_null("BirdFlock")
	if flock == null:
		return
	var player := _arena.get_node("Player") as Node3D
	var target: Bird = null
	for bird: Bird in _birds(flock):
		if bird.is_grounded():
			target = bird
			break
	if target == null:
		_fail("there was no bird on the ground to walk into")
		return
	var stood := target.global_position
	# Put back afterwards: the player is dropped onto sand that is not the height he was standing at,
	# so leaving him there leaves him inside a dune for whatever runs next.
	var was := player.global_position
	player.global_position = Vector3(stood.x, stood.y + 1.0, stood.z)
	await _let_the_flock_sweep()
	player.global_position = was
	if not is_instance_valid(target):
		return
	if target.is_grounded():
		_fail("a bird was walked straight through and stayed on the ground")
	elif target.global_position.y <= stood.y:
		_fail("a startled bird left without climbing")


## Dust is tied to speed rather than to a footfall, because the rig has no footstep event yet. That
## makes the contrast between a walk and a sprint the only thing carrying it, and a contrast is
## exactly what an interpolation anchored at the wrong end loses: anchored at zero instead of at
## walking pace, a walk already emitted four fifths of a sprint.
func _check_the_dust_rises_with_the_body() -> void:
	var player := _arena.get_node("Player") as CharacterBody3D
	var dust := player.find_child("Dust", true, false) as GPUParticles3D
	if dust == null:
		_fail("the player kicks up no dust at all")
		return
	if dust.emitting:
		_fail("the player is standing still and still kicking up sand")
	Input.action_press(&"move_forward")
	for _frame: int in UNDER_WAY:
		await get_tree().physics_frame
	await get_tree().process_frame
	var walking := dust.amount_ratio
	var walked := dust.emitting
	Input.action_press(&"sprint")
	for _frame: int in UNDER_WAY:
		await get_tree().physics_frame
	await get_tree().process_frame
	var sprinting := dust.amount_ratio
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	if not walked:
		_fail("walking kicked up no dust")
	if sprinting < walking * SPRINT_DUST_GAIN:
		_fail(
			(
				(
					"sprinting kicks up %.2f against walking's %.2f, which is not the difference the"
					+ " dust is there to show"
				)
				% [sprinting, walking]
			)
		)


## Waits on the clock the flock itself runs on.
func _let_the_flock_sweep() -> void:
	var waited := 0.0
	var frames := 0
	while waited < FLOCK_SECONDS and frames < FLOCK_FRAME_CAP:
		await get_tree().process_frame
		waited += get_process_delta_time()
		frames += 1


## Every bird currently under the flock. Asked for rather than counted from the export, because one
## that has left is gone and the flock puts a replacement somewhere new.
func _birds(flock: Node) -> Array[Bird]:
	var found: Array[Bird] = []
	for child: Node in flock.get_children():
		var bird := child as Bird
		if bird != null:
			found.append(bird)
	return found


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
	var surfaces := farmer.body_materials.materials()
	var material: StandardMaterial3D = surfaces[0] if not surfaces.is_empty() else null
	var colour_before := material.albedo_color if material != null else Color.WHITE
	var glow_before := material.emission if material != null else Color.BLACK

	var leans := PackedFloat32Array()
	var windup := farmer.windup()
	for _frame: int in int(windup * 60.0) + 2:
		await get_tree().physics_frame
		if farmer.machine.current is EnemyWindUp:
			leans.append(EnemyWindUp.REARS_BACK * farmer.visual.rotation.x)

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
			most = maxf(most, EnemyWindUp.REARS_BACK * farmer.visual.rotation.x)
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
	if is_zero_approx(farmer.visual.rotation.x):
		_fail("the farmer never leaned at all, so standing him up proves nothing")
		_stand_him_down(farmer)
		return
	# The path with no `exit` in it.
	farmer.retire()
	await get_tree().physics_frame
	farmer.revive(Vector3(0.0, 0.0, -6.0))
	await get_tree().physics_frame
	if not is_zero_approx(farmer.visual.rotation.x):
		_fail(
			(
				"a body retired mid-commit came back leaning %.1f°"
				% rad_to_deg(farmer.visual.rotation.x)
			)
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
	if farmer == null or farmer.visual == null:
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


## A bird on the sand is the perched model — the rig lies with its wings spread flat, and a beach of
## birds standing on it would stand there mid-glide. And it is alive: it hops, and it does not hop
## its way off the spot the flock chose for it.
func _check_a_perched_bird_hops_and_keeps_its_wings_folded() -> void:
	var bird := _a_bird(true, Vector3.FORWARD)
	if bird == null:
		return
	var lowest := INF
	var highest := -INF
	var furthest := 0.0
	var home := bird.global_position
	for _frame: int in int(12.0 / BIRD_STEP):
		bird._process(BIRD_STEP)
		lowest = minf(lowest, bird.global_position.y)
		highest = maxf(highest, bird.global_position.y)
		furthest = maxf(
			furthest,
			Vector2(bird.global_position.x - home.x, bird.global_position.z - home.z).length()
		)
	if bird.flight == null or bird.perched == null:
		_fail("the bird scene is missing its Perched or Flight model")
	elif bird.flight.visible or not bird.perched.visible:
		_fail("a bird on the ground is showing its flying rig, wings spread")
	if highest - home.y < bird.hop_height * 0.5:
		_fail("a bird sat on the sand for twelve seconds without hopping once")
	if lowest < home.y - 0.001:
		_fail("a hopping bird sank %.3f m into the sand" % (home.y - lowest))
	if furthest > Bird.HOME_RANGE + bird.hop_length * 2.0:
		_fail("a hopping bird wandered %.2f m off the spot the flock put it on" % furthest)
	bird.queue_free()


## Nothing flaps the whole way across the sky: a cruising bird beats a third of the time and glides
## the rest, and the two clips are different clips. Measured over several whole cycles.
func _check_a_cruising_bird_flaps_a_third_of_the_time() -> void:
	var bird := _a_bird(false, Vector3.FORWARD)
	if bird == null:
		return
	var wings := _wings_of(bird)
	if wings == null:
		return
	for clip: StringName in [bird.fly_clip, bird.glide_clip]:
		if not wings.has_animation(String(clip)):
			_fail("the flying rig carries no %s" % clip)
			bird.queue_free()
			return
		if wings.get_animation(String(clip)).loop_mode == Animation.LOOP_NONE:
			_fail("%s does not loop — the wings would stop dead after one pass" % clip)
	var flapping := 0
	var frames := int(bird._cruise_period() * 3.0 / BIRD_STEP)
	for _frame: int in frames:
		bird._process(BIRD_STEP)
		if wings.current_animation == String(bird.fly_clip):
			flapping += 1
	if not bird.flight.visible:
		_fail("a bird in the sky is not showing its flying rig")
	var share := float(flapping) / float(maxi(frames, 1))
	if absf(share - bird.flap_share) > FLAP_SLACK:
		_fail(
			(
				"a cruising bird flapped %.0f%% of the time, and it should be about %.0f%%"
				% [share * 100.0, bird.flap_share * 100.0]
			)
		)
	bird.queue_free()


## Startled, it only beats — and it goes head first. The models' fronts are +Z and Godot's forward
## is −Z, so without the half turn in the scene every bird that ever fled the player did it
## backwards.
func _check_a_startled_bird_beats_and_flies_head_first() -> void:
	var bird := _a_bird(true, Vector3.FORWARD)
	if bird == null:
		return
	var wings := _wings_of(bird)
	bird._process(BIRD_STEP)
	var from := bird.global_position
	bird.startle(from + Vector3(0.0, 0.0, 3.0))
	var other := 0
	for _frame: int in int(2.0 / BIRD_STEP):
		bird._process(BIRD_STEP)
		if wings != null and wings.current_animation != String(bird.fly_clip):
			other += 1
	if not bird.flight.visible or bird.perched.visible:
		_fail("a startled bird took off still showing the perched model")
	if other > 0:
		_fail("a startled bird glided for %d frames — it should beat the whole way out" % other)
	var travelled := bird.global_position - from
	travelled.y = 0.0
	# The model's head is its local +Z; the scene turns it, so in the world it is the flight node's +Z.
	var head := bird.flight.global_basis.z
	head.y = 0.0
	if travelled.normalized().dot(head.normalized()) < 0.9:
		_fail("a startled bird flies tail first — its head points away from where it is going")
	if travelled.z > -1.0:
		_fail("a bird startled from behind did not fly away from what startled it")
	bird.queue_free()


## One bird, standing on its own in the tree and driven by hand. The flock is not involved: these
## checks are about the bird, and a flock would free it or startle it at its own pace.
func _a_bird(on_the_ground: bool, heading: Vector3) -> Bird:
	var bird := (load(BIRD) as PackedScene).instantiate() as Bird
	if bird == null:
		_fail("bird.tscn is not a Bird")
		return null
	bird.launch(on_the_ground, heading)
	add_child(bird)
	bird.set_process(false)
	bird.global_position = Vector3(200.0, 5.0, 200.0)
	return bird


func _wings_of(bird: Bird) -> AnimationPlayer:
	if bird.flight == null:
		_fail("the bird scene has no Flight model")
		return null
	var players := bird.flight.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		_fail("the flying rig carries no AnimationPlayer")
		return null
	return players[0] as AnimationPlayer


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"vfx OK — every attack names an effect, a perfect hit differs three ways, a "
				+ "fight builds nothing, a farmer rears back in a shape that keeps the "
				+ "wind-up's own time and never stays leaning, the birds stand on sand and "
				+ "leave when walked into, a perched bird hops with its wings folded, a cruising "
				+ "one flaps a third of the time, a startled one beats and flies head first, and "
				+ "a sprint kicks up more dust than a walk"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("vfx FAILED — %s" % failure)
	get_tree().quit(1)
