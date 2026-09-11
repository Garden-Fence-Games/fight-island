class_name Hitbox
extends Area3D
## The active half: monitoring, never monitorable, and disabled at rest. In M1 the owning state
## arms it for the active frames; from the art phase an animation call-method track does it
## instead, through the same two methods.

signal landed(target: Node3D, info: HitInfo)

var attack: AttackData = null
var source: Node3D = null
var perfect: bool = false

var _already_hit: Array[int] = []

@onready var shape: CollisionShape3D = $Shape


func _ready() -> void:
	monitoring = true
	monitorable = false
	if shape != null:
		shape.disabled = true


func arm(from_attack: AttackData, from_source: Node3D, was_perfect: bool) -> void:
	attack = from_attack
	source = from_source
	perfect = was_perfect
	_already_hit.clear()
	if shape == null:
		return
	_fit_to(from_attack)
	shape.disabled = false


## Reach and arc come from the attack, so a weapon swap needs no second hitbox.
func _fit_to(from_attack: AttackData) -> void:
	var box := shape.shape as BoxShape3D
	if box == null:
		return
	var width := 2.0 * from_attack.reach * sin(deg_to_rad(from_attack.arc_degrees * 0.5))
	box.size = Vector3(maxf(width, 0.2), 1.2, maxf(from_attack.reach, 0.2))
	shape.position = Vector3(0.0, 1.0, -from_attack.reach * 0.5)


func disarm() -> void:
	if shape != null:
		shape.disabled = true
	_already_hit.clear()


func _physics_process(_delta: float) -> void:
	if shape == null or shape.disabled or attack == null:
		return
	for area: Area3D in get_overlapping_areas():
		_try_hit(area)


func _try_hit(area: Area3D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	var id := hurtbox.get_instance_id()
	if _already_hit.has(id):
		return
	_already_hit.append(id)
	var info := HitInfo.new(attack, source, perfect)
	if hurtbox.take_hit(info):
		landed.emit(hurtbox.owner, info)
