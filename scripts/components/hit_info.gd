class_name HitInfo
extends RefCounted
## One contact between a hitbox and a hurtbox. Deliberately not a Resource: a Resource has disk
## identity and would end up silently shared between two contacts.

var damage: float = 0.0
var direction: Vector3 = Vector3.FORWARD
var source: Node3D = null
var stagger: float = 0.0
var poise_damage: float = 0.0
var perfect: bool = false
## Carried on the contact rather than asked for afterwards: by the time a body is paying out, the
## swing that killed it is over and the attack that threw it is already gone.
var money_multiplier: float = 1.0
## Set by a listener on Hurtbox.hurt - a parry, a shield - before the health component sees it.
var negated: bool = false


func _init(
	from_attack: AttackData = null,
	from_source: Node3D = null,
	was_perfect: bool = false,
	damage_scale: float = 1.0
) -> void:
	if from_attack == null:
		return
	source = from_source
	perfect = was_perfect
	damage = from_attack.damage * damage_scale
	if was_perfect:
		damage *= from_attack.perfect_multiplier
	stagger = from_attack.stagger
	poise_damage = from_attack.poise_damage
	money_multiplier = from_attack.money_multiplier
	if from_source != null:
		direction = -from_source.global_transform.basis.z
