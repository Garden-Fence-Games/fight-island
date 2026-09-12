class_name EnemyAttack
extends EnemyState

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null or enemy.hitbox == null:
		transition_to(&"Idle")
		return
	if enemy.data.is_ranged:
		enemy.throw_at(enemy.target.global_position if enemy.target != null else Vector3.ZERO)
		return
	enemy.hitbox.arm(attack, enemy, false, enemy.damage_scale)


func exit() -> void:
	if enemy.hitbox != null:
		enemy.hitbox.disarm()


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null or _elapsed >= attack.active:
		transition_to(&"Recover")
