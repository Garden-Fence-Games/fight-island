class_name EnemyWindUp
extends EnemyState
## The telegraph. It shortens as waves go on but never past its floor, because a wind-up nobody
## can read is noise, not difficulty.

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	enemy.face_target(delta * 0.4)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null:
		transition_to(&"Idle")
		return
	if _elapsed >= attack.windup:
		transition_to(&"Attack")
