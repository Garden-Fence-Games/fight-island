class_name Projectile
extends Area3D
## A thrown thing, in the air, on its own. It carries the attack that threw it rather than a damage
## figure, so a stone and a bullet differ only in the resource behind them.
##
## **It has to be slow enough to sidestep.** That is what keeps a ranged archetype from being
## unfair: the player is never asked to react to something already arriving, only to something they
## can see coming. Speed is a design figure here, not a performance one.

## The thrower is told when its stone is gone, because the ranged token is held until then rather
## than until the throwing animation ends — see `Enemy.throw`.
signal spent

@export var speed: float = 12.0
## A backstop only. A stone that somehow never lands would hold the ranged token for the rest of the
## run and every thrower after it would stand there politely waiting its turn.
@export var seconds_to_live: float = 6.0

var attack: AttackData = null
var source: Node3D = null
var damage_scale: float = 1.0

var _heading: Vector3 = Vector3.FORWARD
var _travelled: float = 0.0
var _age: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	add_to_group(&"projectiles")


func launch(
	from_attack: AttackData, from_source: Node3D, toward: Vector3, scale_damage: float = 1.0
) -> void:
	attack = from_attack
	source = from_source
	damage_scale = scale_damage
	_heading = toward.normalized() if not toward.is_zero_approx() else Vector3.FORWARD
	look_at(global_position + _heading, Vector3.UP)


func _physics_process(delta: float) -> void:
	_age += delta
	if attack == null or _age > seconds_to_live:
		_finish()
		return
	var step := speed * delta
	global_position += _heading * step
	_travelled += step
	# The attack's reach is how far the throw carries, the same field a melee weapon uses for how
	# far it swings. One number, one meaning: how far this attack can touch someone.
	if _travelled >= attack.reach:
		_finish()
		return
	for body: Node3D in get_overlapping_bodies():
		if body != source:
			_finish()
			return
	for area: Area3D in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox.owner == source:
			continue
		hurtbox.take_hit(HitInfo.new(attack, source, false, damage_scale))
		_finish()
		return


func _finish() -> void:
	set_physics_process(false)
	spent.emit()
	queue_free()
