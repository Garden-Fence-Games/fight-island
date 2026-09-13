class_name EnemyAttack
extends EnemyState

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null or enemy.hitbox == null:
		transition_to(&"Idle")
		return
	enemy.hitbox.arm(attack, enemy, false, enemy.damage_scale)


func exit() -> void:
	if enemy.hitbox != null:
		enemy.hitbox.disarm()


## The blow, named by the archetype's own `AttackData` — the same arrangement the player's nine
## attacks use, and for the same reason: one state drives all three and only the state knows which.
func clip_name() -> StringName:
	var attack := enemy.data.attack if enemy.data != null else null
	return attack.animation if attack != null else &""


## Exactly the active window. The arm travels while the hitbox is armed and not a frame either side
## of it, which is what makes a blow that missed look like a blow that missed.
func clip_duration() -> float:
	var attack := enemy.data.attack if enemy.data != null else null
	return attack.active if attack != null else 0.0


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.apply_motion(Vector3.ZERO, 0.0, delta)
	var attack := enemy.data.attack if enemy.data != null else null
	if attack == null or _elapsed >= attack.active:
		transition_to(&"Recover")
