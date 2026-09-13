class_name PlayableArea
extends Node3D
## The sea, as a consequence rather than as a fence.
##
## The island is not round, so a circle would either wall off half the beach or let the player swim
## away on the other side. Depth is the honest boundary: walk down the sand, wade in to the shins,
## and the sea starts pushing back. **Nothing is ever blocked**, so the edge of the world is felt as
## the shape of the place.
##
## What used to end there now goes on. The shove builds from nothing at the wading limit instead of
## arriving whole, because a boundary that cannot be pushed against is a wall; the ground goes on
## falling away for anyone who insists; and past the depth `data/world/sea.tres` names, the water is
## over the head and starts taking health a second at a time. **Drowning is a death like any other**
## — it goes through `HealthComponent` and leaves by `player_died`, and there is no second ending.
##
## The descent is the warning and the drowning is only where it ends, so all of it is a share of one
## depth: the shove, the list of the body, and the figure on the bus. Nothing here flashes and
## nothing here shakes the screen — the sea is slow on purpose, and the two access settings have
## nothing to turn off.

## One home for the numbers, and a `preload` rather than an export because this node is built into a
## generated scene by `tools/build_island.gd`, where an export is not reliably set (ADR 0006).
const SEA: SeaData = preload("res://data/world/sea.tres")
## How far the share has to move before it is worth saying so. A signal every physics frame, for a
## number that crawls, is a signal nobody can afford to listen to.
const WORTH_SAYING: float = 0.02

var _water_level: float = -1.1
var _player: Player = null
var _said: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player
	var water := get_parent().get_node_or_null(^"Water") as Node3D
	if water != null:
		_water_level = water.position.y
	Water.level = _water_level


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var share := sinking()
	_say(share)
	_list(share)
	if share <= 0.0:
		return
	_shove(share)
	_drown(delta)


## How far under the player is, nought at the wading limit and one at the depth that drowns. Public
## because `tools/verify_sea.gd` walks a body out to sea and has to read the warning it is given.
func sinking() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	return SEA.sinking_at(_player.global_position.y, _water_level)


## Inward, and harder the deeper it is. A second move rather than a change to where the player was
## walking: what the player asked for has already happened this frame, and the sea is what happens
## to them on top of it.
func _shove(share: float) -> void:
	var inward := global_position - _player.global_position
	inward.y = 0.0
	if inward.is_zero_approx():
		return
	inward = inward.normalized() * SEA.push_speed * share
	_player.velocity.x = inward.x
	_player.velocity.z = inward.z
	_player.move_and_slide()


## Health, a second at a time, and only where a body cannot stand. Through `drain` rather than as a
## blow: a blow hands out the invulnerability window that stops a player being chain-stunned, and
## the water would become the safest place in a wave.
func _drown(delta: float) -> void:
	if _player.health == null:
		return
	var taken := SEA.drain_at(_player.global_position.y, _water_level)
	if taken > 0.0:
		_player.health.drain(taken, delta)


## The body tips as it goes under. There is no drowning clip and no way to author one yet (#180), so
## the tell is the body itself — the same trade `EnemyWindUp` makes for its telegraph, and driven
## the same way, by a share of the thing that is happening rather than by a clip of its own.
##
## Dropped the moment the player is dead, because from there the ragdoll owns the body, and two
## things writing one rig is how a corpse ends up standing.
func _list(share: float) -> void:
	if _player.rig == null:
		return
	_player.rig.rotation.x = deg_to_rad(SEA.lists_by * share) if _player.is_alive() else 0.0


## Said when it has moved enough to be worth a frame of somebody's attention, and always said when
## it reaches nothing — whoever is drawing this has to be told the water let go.
func _say(share: float) -> void:
	if absf(share - _said) < WORTH_SAYING and not (is_zero_approx(share) and _said > 0.0):
		return
	_said = share
	EventBus.player_sinking.emit(share)
