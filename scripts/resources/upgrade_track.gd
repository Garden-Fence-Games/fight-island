class_name UpgradeTrack
extends Resource
## One of the five things money buys. Every level of a track does the same thing again, which is
## why there is one line of copy rather than five: a card that has to describe five different
## effects is a card that is really five upgrades wearing one name.
##
## **The effects are fields, not a branch.** Nothing anywhere asks "is this the health track"; the
## component that applies them reads the numbers and applies whichever are not zero. Adding a sixth
## track is a `.tres`, not a script.

@export var id: StringName = &""
@export var display_name: String = ""
## What the next level does, in words. Shown as-is on the card — the price is next to it and the
## level is above it, so this line only has to say what changes.
@export var next_level_key: String = ""

@export_group("Body")
@export var max_health: float = 0.0
## The health track heals to full on purchase. Buying more life and not getting it now is a
## purchase the player makes once and then never again mid-wave.
@export var heals_on_purchase: bool = false
@export var max_stamina: float = 0.0
@export var stamina_regen: float = 0.0

@export_group("Weapon")
## Which weapon the multipliers below belong to. Empty means the track touches no weapon.
@export var weapon: StringName = &""
@export var damage: float = 0.0
@export var stamina_cost: float = 0.0
@export var reach: float = 0.0
@export var magazine: int = 0
## Rounds the purchase itself hands over, once. It used to be added to every cleared wave, back
## when a wave restocked the gun on its own; now that nothing does, this is the merchant's half of
## the supply line and the bodies on the ground are the other.
@export var reserve: int = 0


func touches_body() -> bool:
	return not is_zero_approx(max_health) or not is_zero_approx(max_stamina)
