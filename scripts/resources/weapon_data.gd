class_name WeaponData
extends Resource
## A weapon is its three attacks plus how it is carried. Tuning one never touches a script.

@export var id: StringName = &""
@export var display_name: String = ""
@export var attacks: Array[AttackData] = []
@export var is_ranged: bool = false
## The wave this weapon is dropped on the island to be found. Zero for one that is never dropped,
## which is the fists — they are never not in hand. The number lives here rather than in a director
## because *when the stick turns up* is a fact about the stick.
@export var found_at_wave: int = 0

@export_group("Chain")
## How long after a full chain before the player may attack again, measured from the end of the
## finisher's recovery. Three hits then a beat out of the conversation: that is the rhythm, and it
## is what makes "should I finish this?" a question rather than a formality. Stopping at one or two
## costs nothing.
##
## Zero for a weapon whose rhythm is governed by something else — the gun's magazine and reload do
## it better than a timer could, and stacking both would be two answers to the same question.
@export var chain_lockout: float = 0.35
## The wait a *perfect* finisher earns instead. Lower on purpose: the subject of this game is
## timing, so the thing that costs the most is exactly where the reward for timing belongs. A
## penalty everyone eats teaches nothing; one the player can buy their way out of teaches the
## window.
@export var perfect_lockout: float = 0.15

@export_group("Ranged")
@export var magazine: int = 0
@export var reload_time: float = 0.0
## What the player carries beyond the magazine when the weapon is first picked up.
@export var reserve_start: int = 0
## And what a cleared wave adds. **Running dry mid-wave is a designed moment**, not a punishment:
## the reserve refilling only between waves is the entire reason the gun does not trivialise the
## middle of a run, so this number and `magazine` are the gun's rhythm the way a lockout is the
## fists'.
@export var reserve_per_wave: int = 0


func attack_at(index: int) -> AttackData:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]


func chain_length() -> int:
	return attacks.size()


## The wait this weapon charges for a finished chain.
func lockout_for(perfect: bool) -> float:
	return perfect_lockout if perfect else chain_lockout
