class_name StaminaComponent
extends Node
## Gates dodge, sprint, parry and melee. Never gates a trigger pull.

signal stamina_changed(current: float, maximum: float)

@export var max_stamina: float = 100.0
@export var regen_per_second: float = 20.0
## Regeneration waits this long after the last spend, so trading blows costs breathing room.
@export var regen_delay: float = 0.8
## The longer pause a whiffed heavy earns.
@export var whiff_delay: float = 1.2

var current_stamina: float = 0.0

var _blocked_for: float = 0.0


func _ready() -> void:
	current_stamina = max_stamina
	stamina_changed.emit(current_stamina, max_stamina)


func _process(delta: float) -> void:
	if _blocked_for > 0.0:
		_blocked_for = maxf(_blocked_for - delta, 0.0)
		return
	if current_stamina >= max_stamina:
		return
	current_stamina = minf(current_stamina + regen_per_second * delta, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)


func has(amount: float) -> bool:
	return current_stamina >= amount


func try_spend(amount: float) -> bool:
	if not has(amount):
		return false
	spend(amount)
	return true


func spend(amount: float) -> void:
	current_stamina = maxf(current_stamina - amount, 0.0)
	_blocked_for = regen_delay
	stamina_changed.emit(current_stamina, max_stamina)


func drain(amount_per_second: float, delta: float) -> void:
	spend(amount_per_second * delta)


func punish_whiff() -> void:
	_blocked_for = whiff_delay


func refund(amount: float) -> void:
	current_stamina = minf(current_stamina + amount, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)


func set_max_stamina(value: float) -> void:
	max_stamina = maxf(value, 1.0)
	current_stamina = minf(current_stamina, max_stamina)
	stamina_changed.emit(current_stamina, max_stamina)
