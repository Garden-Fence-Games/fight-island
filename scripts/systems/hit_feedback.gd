class_name HitFeedback
extends Node
## Everything that makes a hit readable without a number: a beat of stopped time, a flash, and a
## nudge of the camera. Listens on the bus, so nothing in combat knows it exists.

const HITSTOP_SCALE: float = 0.05
const FLASH_DURATION: float = 0.18
const PERFECT_COLOR: Color = Color(1.0, 0.96, 0.7)
const NORMAL_COLOR: Color = Color(1.0, 0.58, 0.3)

var _stops: int = 0


func _ready() -> void:
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.hitstop_requested.connect(_on_hitstop_requested)


func _on_attack_landed(target: Node3D, _damage: float, perfect: bool) -> void:
	var enemy := target as Enemy
	if enemy == null or enemy.mesh == null:
		return
	var material := enemy.mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = true
	material.emission = PERFECT_COLOR if perfect else NORMAL_COLOR
	material.emission_energy_multiplier = 3.0 if perfect else 1.2
	var tween := create_tween()
	tween.tween_property(material, "emission_energy_multiplier", 0.0, FLASH_DURATION)


func _on_hitstop_requested(duration: float) -> void:
	if duration <= 0.0:
		return
	_stops += 1
	Engine.time_scale = HITSTOP_SCALE
	# Unscaled, or the timer would be frozen by the very slowdown it is meant to end.
	await get_tree().create_timer(duration, true, false, true).timeout
	_stops -= 1
	if _stops <= 0:
		_stops = 0
		Engine.time_scale = 1.0
