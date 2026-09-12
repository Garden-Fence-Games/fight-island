class_name HitFeedback
extends Node
## Everything that makes a hit readable without a number: a beat of stopped time, a flash, and the
## colour the body goes while its chain is spent. Listens on the bus, so nothing in combat knows it
## exists.

const HITSTOP_SCALE: float = 0.05
const FLASH_DURATION: float = 0.18
const PERFECT_COLOR: Color = Color(1.0, 0.96, 0.7)
const NORMAL_COLOR: Color = Color(1.0, 0.58, 0.3)
## What the body goes while it cannot attack. Drained rather than tinted a new colour: the player
## reads "spent" off it without having to learn what a colour means, and it cannot be mistaken for
## the damage flash, which goes the other way.
const SPENT_COLOR: Color = Color(0.2, 0.28, 0.36)
const SPENT_FADE: float = 0.06
const READY_FADE: float = 0.14

var _stops: int = 0
var _ready_color: Color = Color.WHITE
var _spent_tween: Tween = null


func _ready() -> void:
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.hitstop_requested.connect(_on_hitstop_requested)
	EventBus.chain_spent.connect(_on_chain_spent)
	EventBus.chain_ready.connect(_on_chain_ready)
	# The rig's own albedo, which is white: the textures carry the colour and this only multiplies
	# them. Read here rather than assumed, so a rig that ships already tinted comes back to itself.
	var materials := _player_materials()
	if not materials.is_empty():
		_ready_color = materials[0].albedo_color


func _on_attack_landed(target: Node3D, _damage: float, perfect: bool) -> void:
	var enemy := target as Enemy
	if enemy == null or enemy.mesh == null:
		return
	var material := enemy.mesh.material_override as StandardMaterial3D
	if material == null:
		return
	if bool(Settings.get_value(&"access_reduce_flashing")):
		return
	material.emission_enabled = true
	material.emission = PERFECT_COLOR if perfect else NORMAL_COLOR
	material.emission_energy_multiplier = 3.0 if perfect else 1.2
	var tween := create_tween()
	tween.tween_property(material, "emission_energy_multiplier", 0.0, FLASH_DURATION)


## The state, held for as long as it lasts, rather than a flash when a press is refused. Seeing
## that the weapon is not ready *before* pressing is worth more than being told afterwards.
func _on_chain_spent(_seconds: float) -> void:
	_fade_body_to(SPENT_COLOR, SPENT_FADE)


func _on_chain_ready() -> void:
	_fade_body_to(_ready_color, READY_FADE)


func _fade_body_to(colour: Color, seconds: float) -> void:
	var materials := _player_materials()
	if materials.is_empty():
		return
	if _spent_tween != null and _spent_tween.is_valid():
		_spent_tween.kill()
	_spent_tween = create_tween()
	_spent_tween.set_parallel(true)
	for material: StandardMaterial3D in materials:
		_spent_tween.tween_property(material, "albedo_color", colour, seconds)


## Every material the body is drawn with, so the whole silhouette answers rather than a patch of it.
## A rig has one per surface where the capsule had a single override, which is why this is a list.
## Looked up each time rather than cached here: the player owns the copies and hands back the same
## ones, and a stale material is a bug that only shows up much later.
func _player_materials() -> Array[StandardMaterial3D]:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player == null:
		return []
	return player.body_materials()


func _on_hitstop_requested(duration: float) -> void:
	if duration <= 0.0 or not bool(Settings.get_value(&"access_hitstop")):
		return
	_stops += 1
	Engine.time_scale = HITSTOP_SCALE
	# Unscaled, or the timer would be frozen by the very slowdown it is meant to end.
	await get_tree().create_timer(duration, true, false, true).timeout
	_stops -= 1
	if _stops <= 0:
		_stops = 0
		Engine.time_scale = 1.0
