class_name HitFeedback
extends Node
## Everything that makes a hit readable without a number: a beat of stopped time, a flash, and the
## colour the body goes while its chain is spent. Listens on the bus, so nothing in combat knows it
## exists.

const HITSTOP_SCALE: float = 0.05
const FLASH_DURATION: float = 0.18
const PERFECT_COLOR: Color = Color(1.0, 0.96, 0.7)
const NORMAL_COLOR: Color = Color(1.0, 0.58, 0.3)
## How hard each flares before settling back. A perfect hit outshines an elite's own glow by nearly
## twice, which is what keeps the timing readable on the body it matters most on.
const PERFECT_FLASH: float = 3.0
const NORMAL_FLASH: float = 1.2
## What the body goes while it cannot attack. Drained rather than tinted a new colour: the player
## reads "spent" off it without having to learn what a colour means, and it cannot be mistaken for
## the damage flash, which goes the other way.
##
## **It multiplies a texture, so it cannot be read as a colour on its own.** These numbers were
## chosen against a white capsule, where 0.2 was a slate blue. The same value over the rig's albedo
## map takes the character to a fifth of his own brightness, which is not a drained man — it is a
## silhouette, and the third punch of every combo turned the player black. Dulled and cooled to a
## bit over half, which still reads as spent on a body that is already coloured.
const SPENT_COLOR: Color = Color(0.52, 0.58, 0.68)
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
	# Emission is not this system's to own. An elite wears its rank in the same slot, and flashing
	# to nought used to take that away for the rest of the body's life — one hit, and the only cue
	# that reads at a glance and in greyscale was gone. So the flash settles back to whatever the
	# body was wearing rather than to zero, which for an ordinary farmer is nothing at all.
	var resting := enemy.rank.glow if enemy.rank != null else Color.BLACK
	var settles_to := enemy.rank.glow_energy if enemy.rank != null else 0.0
	material.emission_enabled = true
	material.emission = PERFECT_COLOR if perfect else NORMAL_COLOR
	material.emission_energy_multiplier = PERFECT_FLASH if perfect else NORMAL_FLASH
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(material, "emission_energy_multiplier", settles_to, FLASH_DURATION)
	tween.tween_property(material, "emission", resting, FLASH_DURATION)


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
