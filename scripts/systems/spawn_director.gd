class_name SpawnDirector
extends Node
## Where a body may appear, and the leasing that puts one there.
##
## Three rules, and each of them is a thing a player would notice going wrong. Far enough away that
## nobody lands on top of the player. **Never inside the camera's view**, because a farmer fading
## into existence in frame tells the player the world is a spawner rather than a place. And on
## ground he can actually walk out of — which is `Ground`'s question, not a marker's, so it stays
## right when the island is rebuilt from a different seed.
##
## When no point passes, nothing spawns this tick and the director tries again on the next one.
## Refusing is always the right answer: a wave that arrives a second late is invisible, a farmer
## appearing in shot is not.

## The player needs time to see them coming. Closer than this and a wave is an ambush the camera
## never showed.
const MIN_PLAYER_DISTANCE: float = 12.0
## Past this they take so long to arrive that the wave reads as empty.
const MAX_PLAYER_DISTANCE: float = 26.0
## Clear space between two fresh bodies, so a drip-feed never stacks two in the same spot.
const SEPARATION: float = 2.0
## A body is taller than the point it stands on, and the camera looks down: checking the feet alone
## lets a head slide into frame.
const HEAD_HEIGHT: float = 1.8
## Tries before giving up for this tick. Generous — the search is a handful of vector maths and a
## navigation query, and failing is cheaper than spawning somewhere wrong.
const ATTEMPTS: int = 32

var _rng := RandomNumberGenerator.new()

# A child rather than an export: node exports are NodePaths in a hand-written .tscn and silently
# stay null (ADR 0006). Owning the pool is also the honest shape — nothing else leases from it.
@onready var pool: EnemyPool = $EnemyPool
@onready var _player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D


func _ready() -> void:
	_rng.seed = GameState.run_seed


## Puts one archetype on the island, or returns null when nowhere passed the rules this tick.
func spawn(
	data: EnemyData,
	health: float = 1.0,
	damage: float = 1.0,
	speed: float = 1.0,
	windup: float = 1.0,
	elite: EliteRank = null,
	harmless: bool = false
) -> Enemy:
	var where := find_point()
	if where == Vector3.INF:
		return null
	return spawn_at(data, where, health, damage, speed, windup, elite, harmless)


## The same, at a point somebody else chose. The tutorial and the headless checks need to say
## exactly where a farmer stands; the wave formula never does.
##
## `harmless` is the tutorial's: a body that closes and circles but never swings. It is a parameter
## rather than a mode on the director, because the wave formula must not be able to reach it — and
## it sits last, behind `elite`, so that the formula's own call can never arrive on it by counting.
func spawn_at(
	data: EnemyData,
	where: Vector3,
	health: float = 1.0,
	damage: float = 1.0,
	speed: float = 1.0,
	windup: float = 1.0,
	elite: EliteRank = null,
	harmless: bool = false
) -> Enemy:
	if pool == null or data == null:
		return null
	var enemy := pool.lease()
	if enemy == null:
		return null
	enemy.data = data
	enemy.revive(where, health, damage, speed, windup, elite, harmless)
	return enemy


## A point that passes every rule, or Vector3.INF when this tick found none.
func find_point() -> Vector3:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	if _player == null:
		return Vector3.INF
	var world := _player.get_world_3d()
	var camera := get_viewport().get_camera_3d()
	for _attempt: int in ATTEMPTS:
		var angle := _rng.randf_range(0.0, TAU)
		var reach := _rng.randf_range(MIN_PLAYER_DISTANCE, MAX_PLAYER_DISTANCE)
		var guess := _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
		var standing := Ground.closest_point(world, guess)
		# Measured after the snap, not before: snapping to walkable ground pulls a point by up to a
		# metre, and a rule checked on the guess is a rule the answer does not have to obey.
		if _too_close(standing):
			continue
		if not Ground.is_spawnable(world, standing, _player.global_position):
			continue
		if _in_view(camera, standing):
			continue
		if _crowded(standing):
			continue
		return standing
	return Vector3.INF


func alive_count() -> int:
	return get_tree().get_nodes_in_group(&"enemies").size()


## Ends the wave early — a run that resets, a player who died. Retiring rather than killing, so no
## death reward is paid for a fight that never happened.
func clear() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null:
			enemy.retire()


func _too_close(where: Vector3) -> bool:
	var apart := Vector2(where.x - _player.global_position.x, where.z - _player.global_position.z)
	return apart.length() < MIN_PLAYER_DISTANCE


func _in_view(camera: Camera3D, where: Vector3) -> bool:
	if camera == null:
		return false
	if camera.is_position_in_frustum(where):
		return true
	return camera.is_position_in_frustum(where + Vector3.UP * HEAD_HEIGHT)


func _crowded(where: Vector3) -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var other := node as Node3D
		if other == null:
			continue
		var apart := Vector2(other.global_position.x - where.x, other.global_position.z - where.z)
		if apart.length() < SEPARATION:
			return true
	return false
