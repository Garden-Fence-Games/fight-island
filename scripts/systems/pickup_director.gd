class_name PickupDirector
extends Node
## Puts the stick and the gun on the island, from the wave each of them says it turns up.
##
## It owns no schedule of its own: **each weapon carries its own `found_at_wave`**, because when the
## stick turns up is a fact about the stick. The director only listens for a wave starting and asks
## what is due — and *due* means owed from that wave on, not offered on that wave alone, because a
## run can be resumed past it.
##
## Placement is the opposite rule to a spawn. A farmer must never appear in shot; a weapon lying in
## the grass must, or the player spends a wave looking for something the game already gave them.

## How far from the player it lands. Near enough to walk to during the wave it arrives in, far
## enough not to drop at the player's feet like a reward for nothing.
const NEAREST: float = 6.0
const FURTHEST: float = 13.0
## Tries before giving up and dropping it at the nearest reachable point regardless of the view.
## Never finding anywhere loses the weapon for the whole run, which is far worse than one that
## landed behind the camera.
const ATTEMPTS: int = 48
const PICKUP_SCENE: String = "res://scenes/world/weapon_pickup.tscn"

## Weapons already put on the island. A pickup is a node in the arena and not a saved fact, so what
## stops a second stick is this rather than the wave number — see `_on_wave_started`.
var _dropped: Array[StringName] = []

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = GameState.run_seed + 2
	EventBus.wave_started.connect(_on_wave_started)


## Whatever the wave is due, placed now. Public so the tutorial and the headless checks can hand a
## weapon over without waiting for a wave to arrive.
func drop(weapon: WeaponData) -> WeaponPickup:
	if weapon == null or GameState.loadout.owns(weapon.id):
		return null
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return null
	var where := _somewhere_visible(player)
	if where == Vector3.INF:
		return null
	var pickup := (load(PICKUP_SCENE) as PackedScene).instantiate() as WeaponPickup
	pickup.weapon_id = weapon.id
	add_child(pickup)
	pickup.global_position = where
	return pickup


## Reachable ground the player can see, or the best reachable ground found if none of it was in
## shot. `Vector3.INF` only when there is nowhere at all to stand.
func _somewhere_visible(player: Node3D) -> Vector3:
	var world := player.get_world_3d()
	var camera := get_viewport().get_camera_3d()
	var fallback := Vector3.INF
	for _attempt: int in ATTEMPTS:
		var angle := _rng.randf_range(0.0, TAU)
		var reach := _rng.randf_range(NEAREST, FURTHEST)
		var guess := player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
		var standing := Ground.closest_point(world, guess)
		if not Ground.is_spawnable(world, standing, player.global_position):
			continue
		if fallback == Vector3.INF:
			fallback = standing
		if camera == null or _can_be_seen(camera, standing):
			return standing
	return fallback


## Whether the weapon itself would be in frame, asked at the height it lies at rather than a metre
## above it. The two differ exactly at the bottom edge of the shot, which is the blind side — so
## asking about the air over a weapon accepts ground the weapon is not visible on.
func _can_be_seen(camera: Camera3D, standing: Vector3) -> bool:
	return camera.is_position_in_frustum(standing + Vector3.UP * WeaponPickup.RESTING_HEIGHT)


## A weapon is **owed from** the wave it is due on, not offered on that wave alone.
##
## It used to be an exact match, and a pickup is a node in `arena.tscn` that nothing saves — so a
## player who cleared wave 2 without walking over the stick and quit to the title resumed at wave 3
## and never saw the stick again. The gun at wave 4 is worse: the whole scavenging economy, the
## reload rhythm and the answer to a thrower leave the run with it.
##
## `drop` already refuses a weapon the bag owns and already returns null when nowhere passed, so a
## wave that finds no ground keeps the weapon owed and the next one tries again — the same promise
## `SpawnDirector` makes about a spawn point.
func _on_wave_started(wave: int, _enemies: int) -> void:
	for weapon: WeaponData in Arsenal.all():
		if weapon.found_at_wave <= 0 or wave < weapon.found_at_wave:
			continue
		if _dropped.has(weapon.id) or GameState.loadout.owns(weapon.id):
			continue
		if drop(weapon) != null:
			_dropped.append(weapon.id)
