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
## Invulnerable for as long as this is set, rather than for a window that runs out: the rainbow
## bird's power is ended by its own clock or by the wave, and a window could not be taken back
## early. Like every other invulnerability, the sea ignores it — see `drain`.
var shielded: bool = false

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
	return shielded or _invulnerable_for > 0.0


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


## Points back, clamped at the maximum. **No invulnerability window and no signal of its own**:
## being healed is not being hit, and a coconut that handed out i-frames would be a dodge the player
## did not earn. Healing the dead does nothing, which is what stops a pickup landing on the frame a
## run ended and quietly reviving somebody the summary has already been opened for.
func heal(amount: float) -> float:
	if not is_alive() or amount <= 0.0:
		return 0.0
	var before := current_health
	current_health = minf(current_health + amount, max_health)
	if is_equal_approx(current_health, before):
		return 0.0
	health_changed.emit(current_health, max_health)
	return current_health - before


## Points away, with no invulnerability window and no `damaged` signal. **The sea is not a blow**:
## i-frames would make drowning a thing the player could out-wait, and the flash, the numbers and
## the shake all belong to something that struck them. `died` still fires — a death is a death
## whatever took the last point of it.
##
## `minimum_health` is honoured for the reason it exists: the wave that teaches the parry cannot
## kill, and a player who walks into the sea during it is owed the same promise.
func drain(amount: float) -> float:
	if not is_alive() or amount <= 0.0:
		return 0.0
	var before := current_health
	current_health = maxf(current_health - amount, minimum_health)
	# **A bar cannot hold a billionth of a point.** A drain lands on the floor by subtraction rather
	# than by a blow that overshoots it, and `0.333333 - 0.333333` is not exactly zero in a float:
	# the last frame left a denormal, `current_health <= 0.0` was false, nobody died — and the frame
	# after that was swallowed by the no-change guard below, because a billionth is inside
	# `is_equal_approx`. The player sat at zero health, alive, for ever.
	if is_zero_approx(current_health):
		current_health = minimum_health
	if is_equal_approx(current_health, before):
		return 0.0
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		died.emit()
	return before - current_health


func set_max_health(value: float, heal_to_full: bool) -> void:
	max_health = maxf(value, 1.0)
	current_health = max_health if heal_to_full else minf(current_health, max_health)
	health_changed.emit(current_health, max_health)
