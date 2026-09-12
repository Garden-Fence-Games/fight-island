class_name BirdFlock
extends Node
## Keeps a handful of birds around the player, and only around the player.
##
## The island is a hundred and seventy metres across and the camera sees perhaps thirty of them, so
## populating the whole of it would be paying for birds nobody will ever look at. They are spawned
## in a ring at the edge of what can be seen, forgotten when the player walks out of range, and
## startled into leaving when he walks into it.
##
## **Startling them is the feature, not a side effect.** A shore that empties as you cross it is the
## cheapest life a world can have: nothing is simulated, nothing is remembered, and the player is
## told the island was there before he was.

## The scene one bird is. Exported as a `PackedScene` because a node export does not resolve in a
## hand-written `.tscn` (ADR 0006).
@export var bird_scene: PackedScene = null
@export var on_the_ground: int = 10
@export var in_the_sky: int = 4
## Where they are put: far enough to be out of shot when they appear, near enough to be worth it.
@export var spawn_ring: Vector2 = Vector2(22.0, 34.0)
## Walk inside this and the ground birds go up. Roughly the distance at which a real one decides you
## are a problem, and comfortably outside a punch.
@export var startle_radius: float = 7.0
## Past this they are freed wherever they are, and a replacement is put down somewhere new.
@export var forget_radius: float = 46.0
@export var sky_altitude: Vector2 = Vector2(12.0, 20.0)
## The lowest ground a bird will stand on. **This is not zero**, and assuming it was is what put the
## first flock inland: on this island the plateau is y = 0 and the beach *descends* from there to a
## waterline 1.1 m below it, so a threshold at zero refuses the whole shore — the one place a gull
## belongs. The sea reaches 0.99 m below the plateau at the top of its swell; this clears it by a
## fist.
@export var dry_sand: float = -0.8
## Seconds between sweeps. Thirty birds checked four times a second is nothing; checked every frame
## it is still nothing, but there is no reason to.
@export var sweep_interval: float = 0.25

var _rng := RandomNumberGenerator.new()
var _birds: Array[Bird] = []
var _clock: float = 0.0
var _player: Node3D = null


func _ready() -> void:
	_rng.randomize()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if bird_scene == null or _player == null:
		# Nothing to do, and nothing worth warning about: a headless check that loads the arena
		# without a player should not have to care that the seagulls did not turn up.
		set_process(false)
		return
	_refill()


func _process(delta: float) -> void:
	_clock += delta
	if _clock < sweep_interval:
		return
	_clock = 0.0
	if _player == null or not is_instance_valid(_player):
		return
	var here := _player.global_position
	for index: int in range(_birds.size() - 1, -1, -1):
		var bird := _birds[index]
		if not is_instance_valid(bird):
			_birds.remove_at(index)
			continue
		var away := bird.global_position.distance_to(here)
		if away > forget_radius:
			bird.queue_free()
			_birds.remove_at(index)
			continue
		# Only the ones on the sand are startled. A bird already up there is not frightened of a man
		# on the ground, and one leaving is already leaving.
		if bird.is_grounded() and away < startle_radius:
			bird.startle(here)
	_refill()


## Tops the flock back up, counting what is actually there rather than what was asked for: a bird
## that has left is gone for good, and the ring is where the next one appears.
func _refill() -> void:
	var grounded := 0
	var flying := 0
	for bird: Bird in _birds:
		if not is_instance_valid(bird):
			continue
		if bird.is_grounded():
			grounded += 1
		elif bird.is_flying():
			flying += 1
	for _i: int in maxi(on_the_ground - grounded, 0):
		_put_down(true)
	for _i: int in maxi(in_the_sky - flying, 0):
		_put_down(false)


func _put_down(on_the_ground: bool) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var angle := _rng.randf_range(0.0, TAU)
	var reach := _rng.randf_range(spawn_ring.x, spawn_ring.y)
	var at := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
	if on_the_ground:
		var ground := _ground_under(at)
		if is_nan(ground):
			return
		at.y = ground
	else:
		at.y = _player.global_position.y + _rng.randf_range(sky_altitude.x, sky_altitude.y)
	var made := bird_scene.instantiate()
	var bird := made as Bird
	if bird == null:
		# Freed rather than returned from: an instantiated scene that is dropped without being
		# parented is never collected, and turns up as a leak at exit rather than as a bad export.
		made.free()
		return
	bird.launch(on_the_ground, Vector3(_rng.randf() - 0.5, 0.0, _rng.randf() - 0.5))
	add_child(bird)
	bird.global_position = at
	_birds.append(bird)


## The terrain under a point, or NAN where there is none — off the island, or over water. A bird put
## down on nothing would stand in the air, and one put down at a guessed height would stand in sand.
func _ground_under(at: Vector3) -> float:
	var space := get_viewport().world_3d.direct_space_state if is_inside_tree() else null
	if space == null:
		return NAN
	var from := Vector3(at.x, at.y + 40.0, at.z)
	var to := Vector3(at.x, at.y - 40.0, at.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN
	var where: Vector3 = hit["position"]
	# The sea is not a perch. Anything the swell can reach is refused and the ring is tried again on
	# the next sweep, which costs one raycast and keeps gulls off the water without keeping them off
	# the beach.
	return NAN if where.y < dry_sand else where.y
