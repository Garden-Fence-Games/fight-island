class_name PlayerParry
extends PlayerState
## A tap, not a stance. One defensive button and all the difficulty in the moment: perfect negates
## and pays stamina back, late halves, and anything after that is the cost of mashing.

const PERFECT_END: float = 0.12
const LATE_END: float = 0.22
const RECOVERY_END: float = 0.45
const PERFECT_REFUND: float = 25.0
const PERFECT_STAGGER: float = 1.0
const LATE_REDUCTION: float = 0.5
const LATE_STAGGER: float = 0.25

var _elapsed: float = 0.0


func enter(_message: Dictionary) -> void:
	_elapsed = 0.0


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.halt(delta)
	if _elapsed >= RECOVERY_END:
		transition_to(&"Idle")


## Called by the player when a hit arrives while this state is current, before health sees it.
func resolve(info: HitInfo) -> void:
	if _elapsed <= PERFECT_END:
		info.negated = true
		if player.stamina != null:
			player.stamina.refund(PERFECT_REFUND)
		_stagger_attacker(info.source, PERFECT_STAGGER)
		EventBus.parry_perfect.emit()
		Emphasis.spend(Emphasis.for_parry())
		transition_to(&"Idle")
		return
	if _elapsed <= LATE_END:
		info.damage *= LATE_REDUCTION
		# The blow is written down as what it became, not as what it was thrown as. A late parry
		# takes the weight out of it as well as the damage, and whoever reads this afterwards — the
		# fall, the shake — has to see the hit that actually landed.
		info.stagger = LATE_STAGGER
		EventBus.parry_late.emit()
		transition_to(&"Hurt", {"stagger": info.stagger})
		return
	transition_to(&"Hurt", {"stagger": info.stagger})


func _stagger_attacker(source: Node3D, duration: float) -> void:
	if source == null:
		return
	var enemy := source.owner as Enemy
	if enemy == null:
		enemy = source as Enemy
	if enemy != null:
		enemy.stagger(duration)
