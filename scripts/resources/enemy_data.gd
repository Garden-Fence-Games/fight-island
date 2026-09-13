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
@export var is_ranged: bool = false
## Which wind-up this archetype announces itself with. Empty falls back to the generic one, and that
## is a fallback rather than a default: three archetypes that sound alike are one warning wearing
## three coats, and the thrower is the one the player cannot see coming.
@export var telegraph_sound: StringName = &""
## How far the archetype wants to stay from the player. Melee archetypes close to attack_range.
@export var preferred_range: float = 1.4
## Closer than this and the archetype backs away instead of fighting. Zero for anyone who stands
## their ground, which is everyone but the thrower — he is what stops the player camping a corner,
## and he only does that by refusing to be cornered himself.
@export var retreat_range: float = 0.0
## What this archetype throws. A `PackedScene` export, which does resolve in a hand-written scene
## where a node export would not (ADR 0006).
@export var projectile: PackedScene = null

@export_group("Presentation")
@export var tint: Color = Color(0.78, 0.36, 0.28)
