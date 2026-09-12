class_name EnemyStrafe
extends EnemyState
## Where an enemy waits for a token. Circling rather than standing still is what keeps a crowd
## alive instead of a queue.

const SPEED_SCALE: float = 0.7

var _spin: float = 1.0
var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	_spin = 1.0 if randf() < 0.5 else -1.0


func physics_update(delta: float) -> void:
	_elapsed += delta
	if enemy.data == null or enemy.target == null:
		enemy.apply_motion(Vector3.ZERO, 0.0, delta)
		return
	var to_target := enemy.direction_to_target()
	var sideways := Vector3(-to_target.z, 0.0, to_target.x) * _spin
	var keep_distance := to_target * signf(enemy.distance_to_target() - enemy.data.preferred_range)
	var direction := (sideways + keep_distance * 0.5).limit_length(1.0)
	enemy.apply_motion(direction, enemy.move_speed() * SPEED_SCALE, delta)
	enemy.face_target(delta)
	if _elapsed < 0.3:
		return
	if enemy.wants_room():
		transition_to(&"Retreat")
		return
	if enemy.distance_to_target() <= enemy.data.attack_range and enemy.claim_token():
		transition_to(&"WindUp")
