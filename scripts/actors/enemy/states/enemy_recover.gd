class_name EnemyRecover
extends EnemyState

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0


func exit() -> void:
	enemy.release_token()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null or _elapsed >= attack.recovery:
		transition_to(&"Chase")
