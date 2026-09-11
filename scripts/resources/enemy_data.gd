class_name EnemyData
extends Resource
## One farmer archetype. The three share a rig and a mesh; they differ here and in their material.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Stats")
@export var health: float = 45.0
@export var move_speed: float = 3.4
@export var poise: float = 15.0
@export var money: int = 2

@export_group("Combat")
@export var attack: AttackData = null
@export var aggro_radius: float = 18.0
@export var attack_range: float = 1.6
@export var is_ranged: bool = false
## How far the archetype wants to stay from the player. Melee archetypes close to attack_range.
@export var preferred_range: float = 1.4

@export_group("Presentation")
@export var tint: Color = Color(0.78, 0.36, 0.28)
@export var first_wave: int = 1
