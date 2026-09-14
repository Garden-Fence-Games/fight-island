class_name EnemyData
extends Resource
## One farmer archetype. The three share a rig and a mesh; they differ here and in their material.

@export var id: StringName = &""
## A **translation key**, not a name. `DayPhase` has always held one here; these three held
## plain English, which is a screen that reads the same in every language — and the merchant
## was already printing one of them. `tools/verify_strings.tscn` holds both ends of it.
@export var display_name: String = ""

@export_group("Stats")
@export var health: float = 45.0
@export var move_speed: float = 3.4
@export var poise: float = 15.0
@export var money: int = 2

@export_group("Combat")
@export var attack: AttackData = null
## How close the player gets before this archetype notices them. It must stay well under the
## spawn search's twelve metres, or a farmer arrives already awake and the whole thing is inert.
##
## Noticing is one way. Once roused a farmer stays roused: a leash would have him lose interest the
## moment the player took four steps back, and the fight would breathe in and out at its edge.
@export var notice_radius: float = 9.0
## How far being roused carries to the farmers standing nearby. One waking alone while the two
## beside him keep staring at the sea reads as broken rather than calm.
@export var rouse_radius: float = 7.0
@export var attack_range: float = 1.6
## Which wind-up this archetype announces itself with. Empty falls back to the generic one, and that
## is a fallback rather than a default: two archetypes that sound alike are one warning wearing two
## coats.
@export var telegraph_sound: StringName = &""
## How far the archetype wants to stay from the player. Every archetype closes to attack_range.
@export var preferred_range: float = 1.4

@export_group("Presentation")
@export var tint: Color = Color(0.78, 0.36, 0.28)
