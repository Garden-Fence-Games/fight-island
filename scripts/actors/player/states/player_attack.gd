class_name PlayerAttack
extends PlayerState
## Windup, active frames, recovery - and the chain window that opens with the recovery. One state
## drives all nine attacks; which one is playing is data, not a branch.
##
## The facing is taken once, on entry, and never again: a swing that can be steered mid-animation
## is a swing with no commitment, and commitment is the only thing making a windup cost anything.
##
## A shot is the same state with two things different. It resolves as a **ray at the end of the
## windup** rather than a box held open for its active frames — a bullet has no travel, so a farmer
## must not be able to walk into one already fired. And the charged shot **only charges while the
## button is held**: letting go early cancels it, which is what makes holding a commitment rather
## than a formality.

enum Phase { WINDUP, ACTIVE, RECOVERY }

## Where on a body the burst is drawn: the chest, which is where a swing lands and where the camera
## is already looking. The feet are under the ground and the head is off the top of most bodies.
const IMPACT_HEIGHT: float = 1.1

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
	# Rounds before stamina: a trigger pulled on an empty magazine must not also cost breath.
	if not _take_ammo():
		transition_to(&"Idle")
		return
	var cost := _attack.stamina_cost * player.stamina_cost_multiplier
	if player.stamina != null and not player.stamina.try_spend(cost):
		transition_to(&"Idle")
		return
	_phase = Phase.WINDUP
	_elapsed = 0.0
	_landed = false
	player.close_chain()
	player.snap_to_face(player.look_direction(player.move_direction()))
	if player.hitbox != null and not player.hitbox.landed.is_connected(_on_landed):
		player.hitbox.landed.connect(_on_landed)
	if player.hitscan != null and not player.hitscan.landed.is_connected(_on_landed):
		player.hitscan.landed.connect(_on_landed)


## The clip this swing plays, named by its own `AttackData`. The animation component asks the state
## for it instead of looking `Attack` up in a table, because one state drives all nine attacks and
## only the state knows which one is running. The table still answers for every other state.
func clip_name() -> StringName:
	return _attack.animation if _attack != null else &""


## How long the clip should take: exactly as long as the attack itself. The windows are balance and
## live in the `.tres`; the clip bends to them, so the fist is out during the active frames rather
## than roughly around them. Returning zero leaves the clip at its authored speed.
func clip_duration() -> float:
	return _attack.total_duration() if _attack != null else 0.0


## How far a charge has come, nought to one, for whatever wants to draw it. Zero for every attack
## that does not charge, which is eight of the nine.
func charge() -> float:
	if _attack == null or not _attack.charges or _phase != Phase.WINDUP:
		return 0.0
	return clampf(_elapsed / maxf(_attack.windup, 0.001), 0.0, 1.0)


func exit() -> void:
	if player.hitbox != null:
		player.hitbox.disarm()
		if player.hitbox.landed.is_connected(_on_landed):
			player.hitbox.landed.disconnect(_on_landed)
	if player.hitscan != null and player.hitscan.landed.is_connected(_on_landed):
		player.hitscan.landed.disconnect(_on_landed)


func physics_update(delta: float) -> void:
	if _attack == null:
		return
	_elapsed += delta
	player.halt(delta)
	match _phase:
		Phase.WINDUP:
			_update_windup()
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


## A charge that is let go of early is abandoned, and the round is handed back. The stamina is not:
## deciding to charge is the commitment, and a cost that can be taken back is not one.
func _update_windup() -> void:
	if _attack.charges and not Input.is_action_pressed(&"attack"):
		_refund_ammo()
		transition_to(&"Idle")
		return
	if _elapsed >= _attack.windup:
		_begin_active()


func _begin_active() -> void:
	_elapsed = 0.0
	if _attack.is_hitscan:
		_shoot()
		_begin_recovery()
		return
	_phase = Phase.ACTIVE
	if player.hitbox != null:
		player.hitbox.arm(_attack, player, _perfect, player.damage_multiplier)


## Every round of the press leaves at once. The double tap may legitimately hit the same farmer
## twice, so nothing is remembered between the two — the design pays 2 × 16, not 16.
func _shoot() -> void:
	if player.hitscan == null:
		return
	for _round: int in maxi(_attack.shots, 1):
		player.hitscan.fire(_attack, player, _perfect, player.damage_multiplier)
		# Announced whether or not the ray found anybody: the report is the round leaving, and a
		# gun that is only audible when it connects is a gun the player cannot tell they fired.
		EventBus.weapon_fired.emit(_attack)


func _begin_recovery() -> void:
	# The one moment a miss is knowable: the window is shut and nothing was touched. Announced here
	# rather than on exit, because a chain moves straight from one attack to the next and the state
	# leaves without the swing ever having ended on its own.
	if not _landed:
		EventBus.attack_whiffed.emit(_attack)
	_phase = Phase.RECOVERY
	_elapsed = 0.0
	if player.hitbox != null:
		player.hitbox.disarm()
	# A finisher that hits nothing costs the longer breath - that is what makes it a commitment.
	if not _landed and _attack.is_finisher() and player.stamina != null:
		player.stamina.punish_whiff()
	# The chain is spent here rather than when the recovery ends, so the wait is measured from the
	# end of the recovery but cannot be cancelled by being hit out of it. A debt that a stagger
	# clears is a debt worth taking a hit for.
	if _attack.is_finisher() and player.weapon != null:
		player.spend_chain(_attack.recovery + player.weapon.lockout_for(_perfect))
	player.open_chain(_attack, _index)


## Whether there was anything to fire. An empty magazine says so on the bus rather than silently
## refusing, because a press that produces nothing at all is a press the player thinks was lost.
func _take_ammo() -> bool:
	if _attack.ammo_cost <= 0:
		return true
	if GameState.loadout.spend(_attack.ammo_cost):
		return true
	EventBus.weapon_dry_fired.emit()
	return false


func _refund_ammo() -> void:
	GameState.loadout.refund(_attack.ammo_cost)


## One blow, one spend. Perfect, finisher and killing are three things that can be true of the same
## swing, and `Emphasis` takes the loudest of them rather than letting all three land at once — see
## `scripts/systems/emphasis.gd` for why that is the difference between weight and noise.
func _on_landed(target: Node3D, info: HitInfo) -> void:
	_landed = true
	EventBus.attack_landed.emit(target, info.damage, info.perfect, _attack)
	_show_the_impact(target, info.perfect)
	var enemy := target as Enemy
	var killed := enemy != null and not enemy.is_alive()
	Emphasis.spend(Emphasis.for_hit(info.perfect, _attack.is_finisher(), killed, _attack.hitstop))


## The effect the attack names, leased rather than made. Played from here because this is the one
## place that knows all three things it needs — which attack, which body, and whether the timing was
## perfect — and because the melee hitbox and the gun's hitscan both arrive through it.
func _show_the_impact(target: Node3D, perfect: bool) -> void:
	if _attack == null or _attack.vfx == null or target == null:
		return
	var pool := player.get_tree().get_first_node_in_group(&"effects") as EffectPool
	if pool == null:
		return
	var impact := pool.lease(_attack.vfx) as Impact
	if impact != null:
		impact.play(target.global_position + Vector3.UP * IMPACT_HEIGHT, perfect)
