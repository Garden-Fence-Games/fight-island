class_name HealthComponent
extends Node
## Points of life, invulnerability windows, and nothing about who owns them.

signal health_changed(current: float, maximum: float)
signal damaged(info: HitInfo)
signal died

@export var max_health: float = 100.0
## Granted automatically after every hit that lands, so a player is never chain-stunned to death.
@export var hit_invulnerability: float = 0.4
## Damage stops here instead of at zero. Raised to one for wave 1 and dropped again after: a player
## who dies during the parry lesson has learned that parrying is dangerous, which is the opposite
## of true. Everything else — the flash, the numbers, the stagger — behaves normally, and they
## never find out.
@export var minimum_health: float = 0.0

var current_health: float = 0.0

var _invulnerable_for: float = 0.0


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func _process(delta: float) -> void:
	if _invulnerable_for > 0.0:
		_invulnerable_for = maxf(_invulnerable_for - delta, 0.0)


func is_alive() -> bool:
	return current_health > 0.0


func is_invulnerable() -> bool:
	return _invulnerable_for > 0.0


func make_invulnerable(duration: float) -> void:
	_invulnerable_for = maxf(_invulnerable_for, duration)


func apply(info: HitInfo) -> bool:
	if not is_alive() or is_invulnerable():
		return false
	current_health = maxf(current_health - info.damage, minimum_health)
	health_changed.emit(current_health, max_health)
	damaged.emit(info)
	if current_health <= 0.0:
		died.emit()
	else:
		make_invulnerable(hit_invulnerability)
	return true


func set_max_health(value: float, heal_to_full: bool) -> void:
	max_health = maxf(value, 1.0)
	current_health = max_health if heal_to_full else minf(current_health, max_health)
	health_changed.emit(current_health, max_health)
