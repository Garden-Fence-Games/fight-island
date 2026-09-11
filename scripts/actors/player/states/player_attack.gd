class_name PlayerAttack
extends PlayerState
## Windup, active frames, recovery - and the chain window that opens with the recovery. One state
## drives all nine attacks; which one is playing is data, not a branch.
##
## The facing is taken once, on entry, and never again: a swing that can be steered mid-animation
## is a swing with no commitment, and commitment is the only thing making a windup cost anything.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var _attack: AttackData = null
var _index: int = 0
var _perfect: bool = false
var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _landed: bool = false


func enter(message: Dictionary) -> void:
	_index = int(message.get("index", 0))
	_perfect = bool(message.get("perfect", false))
	_attack = player.weapon.attack_at(_index) if player.weapon != null else null
	if _attack == null:
		transition_to(&"Idle")
		return
	if player.stamina != null and not player.stamina.try_spend(_attack.stamina_cost):
		transition_to(&"Idle")
		return
	_phase = Phase.WINDUP
	_elapsed = 0.0
	_landed = false
	player.close_chain()
	player.snap_to_face(player.look_direction(player.move_direction()))
	if player.hitbox != null and not player.hitbox.landed.is_connected(_on_landed):
		player.hitbox.landed.connect(_on_landed)


func exit() -> void:
	if player.hitbox != null:
		player.hitbox.disarm()
		if player.hitbox.landed.is_connected(_on_landed):
			player.hitbox.landed.disconnect(_on_landed)


func physics_update(delta: float) -> void:
	if _attack == null:
		return
	_elapsed += delta
	player.halt(delta)
	match _phase:
		Phase.WINDUP:
			if _elapsed >= _attack.windup:
				_begin_active()
		Phase.ACTIVE:
			if _elapsed >= _attack.active:
				_begin_recovery()
		Phase.RECOVERY:
			var queued := player.take_attack_input()
			if not queued.is_empty():
				transition_to(&"Attack", queued)
				return
			if _elapsed >= _attack.recovery:
				transition_to(&"Idle")


func _begin_active() -> void:
	_phase = Phase.ACTIVE
	_elapsed = 0.0
	if player.hitbox != null:
		player.hitbox.arm(_attack, player, _perfect)


func _begin_recovery() -> void:
	_phase = Phase.RECOVERY
	_elapsed = 0.0
	if player.hitbox != null:
		player.hitbox.disarm()
	# A finisher that hits nothing costs the longer breath - that is what makes it a commitment.
	if not _landed and _attack.is_finisher() and player.stamina != null:
		player.stamina.punish_whiff()
	player.open_chain(_attack, _index)


func _on_landed(target: Node3D, info: HitInfo) -> void:
	_landed = true
	EventBus.attack_landed.emit(target, info.damage, info.perfect)
	if not info.perfect:
		return
	EventBus.perfect_timing.emit()
	EventBus.hitstop_requested.emit(info.hitstop)
