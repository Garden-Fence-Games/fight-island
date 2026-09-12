extends Node
## Headless proof of the decisions in the effects, not of the pixels — the renderer draws nothing
## here, and what matters is checkable without it: that a perfect hit is a different effect and not
## a louder one, that the telegraph is a shape rather than a colour, that nothing is built in the
## middle of a fight, and that the two accessibility settings are actually read.
## Run: godot --headless --path . res://tools/verify_vfx.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
const IMPACT: String = "res://scenes/fx/impact.tscn"
const TELEGRAPH: String = "res://scenes/fx/telegraph.tscn"
const FARMHAND: String = "res://data/enemies/farmhand.tres"
## More bursts than a wave can ask for at once, to see whether the pool holds.
const A_LOT_OF_HITS: int = 40
## Where the ring has to still be a ring: a fifth of the way through a wind-up, before any fill
## could account for it being visible.
const EARLY: float = 0.2
## Long enough for a knock to run most of its course.
const SHAKEN_FRAMES: int = 20
## How far the eye may drift along its own arm while being shaken. It should be nothing at all; a
## centimetre is float noise.
const ARM_SLACK: float = 0.01
## Sweeps to let the flock settle. It only acts every `sweep_interval`, so one frame proves nothing.
const FLOCK_FRAMES: int = 20
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
	_check_the_telegraph_is_a_shape_and_not_a_colour()
	_check_the_telegraph_fills_with_the_windup()
	_check_reduce_flashing_damps_the_flare_and_leaves_the_debris()
	await _check_a_player_who_turned_shake_off_gets_none()
	# The dust goes first on purpose: it is the only check here that needs the player standing on the
	# ground he started on, and the startle check below picks him up and puts him somewhere else.
	await _check_the_dust_rises_with_the_body()
	await _check_the_birds_stand_on_sand_and_fly_in_the_sky()
	await _check_a_bird_leaves_when_you_walk_into_it()
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


## The one that a check has to carry, because nobody notices it by looking: a telegraph drawn as a
## colour is invisible to a colourblind player, to a greyscale screenshot, and at twenty metres.
## What is asserted is that the ring is *drawn at all* before any of it has filled — which only a
## shape can be.
func _check_the_telegraph_is_a_shape_and_not_a_colour() -> void:
	var ring := _lease_a_ring()
	if ring == null:
		return
	var material := _ring_material(ring)
	if material == null:
		_fail("the telegraph has no shader to read")
		return
	if float(material.get_shader_parameter(&"rail")) <= 0.0:
		_fail("the telegraph draws nothing until it has filled — there is no shape to read")
	if (
		float(material.get_shader_parameter(&"outer"))
		<= float(material.get_shader_parameter(&"inner"))
	):
		_fail("the telegraph's ring has no width")
	# And the setting that exists for exactly this has to reach it.
	Settings.set_value(&"access_colourblind_telegraphs", true)
	var shouting := _lease_a_ring()
	if shouting != null:
		var loud := _ring_material(shouting)
		if loud == null or float(loud.get_shader_parameter(&"high_contrast")) <= 0.0:
			_fail("access_colourblind_telegraphs is on and the telegraph did not answer")
		shouting.finish()
	Settings.set_value(&"access_colourblind_telegraphs", false)
	ring.finish()


## The fill and the wind-up are the same number, or the ring lies about when the swing lands.
func _check_the_telegraph_fills_with_the_windup() -> void:
	var ring := _lease_a_ring()
	if ring == null:
		return
	var material := _ring_material(ring)
	for share: float in [0.0, EARLY, 1.0]:
		ring.fill(share)
		var drawn := float(material.get_shader_parameter(&"progress"))
		if absf(drawn - share) > 0.001:
			_fail("the ring reads %.2f when the wind-up is %.2f through" % [drawn, share])
	ring.fill(4.0)
	if float(material.get_shader_parameter(&"progress")) > 1.0:
		_fail("the ring fills past full")
	ring.finish()


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
	for _frame: int in FLOCK_FRAMES:
		await get_tree().process_frame
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
	for _frame: int in FLOCK_FRAMES:
		await get_tree().process_frame
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


## Every bird currently under the flock. Asked for rather than counted from the export, because one
## that has left is gone and the flock puts a replacement somewhere new.
func _birds(flock: Node) -> Array[Bird]:
	var found: Array[Bird] = []
	for child: Node in flock.get_children():
		var bird := child as Bird
		if bird != null:
			found.append(bird)
	return found


func _lease_a_ring() -> Telegraph:
	var ring := _pool.lease(load(TELEGRAPH) as PackedScene) as Telegraph
	if ring == null:
		_fail("the pool would not lease a telegraph")
		return null
	ring.begin(_arena.get_node("Player") as Node3D, Color.RED)
	return ring


func _ring_material(ring: Telegraph) -> ShaderMaterial:
	var mesh := ring.get_node_or_null("Ring") as MeshInstance3D
	return mesh.material_override as ShaderMaterial if mesh != null else null


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


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"vfx OK — every attack names an effect, a perfect hit differs three ways, the "
				+ "telegraph is a shape, a fight builds nothing, the birds stand on sand and leave "
				+ "when walked into, and a sprint kicks up more dust than a walk"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("vfx FAILED — %s" % failure)
	get_tree().quit(1)
