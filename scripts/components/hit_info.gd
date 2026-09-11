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
var hitstop: float = 0.0
## Set by a listener on Hurtbox.hurt - a parry, a shield - before the health component sees it.
var negated: bool = false


func _init(
	from_attack: AttackData = null, from_source: Node3D = null, was_perfect: bool = false
) -> void:
	if from_attack == null:
		return
	source = from_source
	perfect = was_perfect
	damage = from_attack.damage * (from_attack.perfect_multiplier if was_perfect else 1.0)
	stagger = from_attack.stagger
	poise_damage = from_attack.poise_damage
	hitstop = from_attack.hitstop if was_perfect else 0.0
	if from_source != null:
		direction = -from_source.global_transform.basis.z
