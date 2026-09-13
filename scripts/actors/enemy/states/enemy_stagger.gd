class_name EnemyStagger
extends EnemyState
## Knocked off his feet, and back on them.
##
## Two phases, and the animation follows them by name. **While the physics has the body the state
## names no clip at all** — a simulator and an AnimationPlayer both write bone poses, and the one
## that is not driving has no business fighting the one that is. Once the body settles, `get_up`
## takes over.
##
## `get_up` is not on the rig yet. A clip the rig does not carry resolves to the rest pose, so the
## farmer stands and walks off; the day it is authored it plays here, and nothing else changes.
##
## A hit that finds no rig to throw falls back to the stand-still stagger this state used to be, so
## a capsule, a headless check and a farmer whose skeleton failed to resolve all still work.

enum Phase { FALLING, RISING }

## How long standing up takes until `get_up` exists to say so.
const RISE_TIME: float = 0.7

var _phase: Phase = Phase.RISING
var _remaining: float = 0.0


func enter(message: Dictionary) -> void:
	if enemy.hitbox != null:
		enemy.hitbox.disarm()
	_remaining = float(message.get("duration", 0.5))
	var push: float = float(message.get("push", 0.0)) * Enemy.KNOCKDOWN.knock_speed
	var from: Vector3 = message.get("from", Vector3.ZERO)
	if push <= 0.0 or enemy.ragdoll == null or not enemy.ragdoll.is_ready():
		_phase = Phase.RISING
		return
	_phase = Phase.FALLING
	if not enemy.ragdoll.came_to_rest.is_connected(_on_came_to_rest):
		enemy.ragdoll.came_to_rest.connect(_on_came_to_rest)
	enemy.ragdoll.knock(from, push, _remaining * Enemy.KNOCKDOWN.fall_ceiling)


## Whatever takes him out of here — a killing blow, a wave cleared, a body returned to the pool —
## has to hand the skeleton back, or it comes out of the pool still tumbling.
func exit() -> void:
	if enemy.ragdoll != null and enemy.ragdoll.is_running():
		enemy.ragdoll.stop()
	if enemy.ragdoll != null and enemy.ragdoll.came_to_rest.is_connected(_on_came_to_rest):
		enemy.ragdoll.came_to_rest.disconnect(_on_came_to_rest)


## Nothing while the physics drives, then `get_up` once he is pushing himself off the ground.
func clip_name() -> StringName:
	return &"" if _phase == Phase.FALLING else &"get_up"


func physics_update(delta: float) -> void:
	if _phase == Phase.FALLING:
		# The body node is not what is moving — the bones are. Holding it still keeps the collider
		# and the navigation agent out of the way until the tumble picks a place to stop.
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		return
	_remaining -= delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	if _remaining <= 0.0:
		transition_to(&"Chase")


## The tumble is over. The body node catches up with where the hips actually ended, because that is
## where the player last saw him — leaving it where he was hit would teleport him back.
func _on_came_to_rest() -> void:
	if _phase != Phase.FALLING:
		return
	var landed := enemy.ragdoll.settled_position()
	enemy.ragdoll.stop()
	enemy.global_position = Vector3(landed.x, enemy.global_position.y, landed.z)
	_phase = Phase.RISING
	_remaining = RISE_TIME
	# Re-asked rather than assumed: the state is the same, but what it wants played has changed.
	if enemy.animation != null:
		enemy.animation.refresh()
