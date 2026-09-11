class_name Hurtbox
extends Area3D
## The passive half of the pair: monitorable, never monitoring. It reports the hit and lets its
## owner decide what that means - a parry, i-frames, or damage.

signal hurt(info: HitInfo)

## The actor's health sits beside the hurtbox, by the actor scene's own naming contract.
@onready var health: HealthComponent = get_node_or_null(^"../Health")


func _ready() -> void:
	monitoring = false
	monitorable = true


## Returns true when the hit was consumed, so a hitbox knows not to try again this swing.
func take_hit(info: HitInfo) -> bool:
	hurt.emit(info)
	if info.negated:
		return true
	if health == null:
		return true
	return health.apply(info)
