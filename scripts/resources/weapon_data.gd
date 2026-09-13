class_name WeaponData
extends Resource
## A weapon is its three attacks plus how it is carried. Tuning one never touches a script.

@export var id: StringName = &""
## A **translation key**, not a name. `DayPhase` has always held one here; these three held
## plain English, which is a screen that reads the same in every language — and the merchant
## was already printing one of them. `tools/verify_strings.tscn` holds both ends of it.
@export var display_name: String = ""
@export var attacks: Array[AttackData] = []
@export var is_ranged: bool = false
## The wave this weapon is dropped on the island to be found. Zero for one that is never dropped,
## which is the fists — they are never not in hand. The number lives here rather than in a director
## because *when the stick turns up* is a fact about the stick.
@export var found_at_wave: int = 0
## Appended to a locomotion clip's name while this weapon is held — `_gun` turns `walk` into
## `walk_gun`. Empty for a weapon carried the way the base cycles were authored, which is the fists
## and, for now, the stick.
##
## A clip-name fragment rather than a set of clip names, because the rig arrives one animation at a
## time: a variant that has not been authored is silently skipped, so naming the whole set here
## would mean listing clips that do not exist and pretending they do.
@export var clip_suffix: StringName = &""

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
## Every round the player may hold at once, **magazine included**. One number rather than two
## because one number is what the player counts: a reload moves rounds, it never makes them.
##
## Nothing refills this on a clock. Ammunition comes off the bodies of the people who came to kill
## you, a round at a time, and from the merchant — so **running dry is a designed moment** and the
## way out of it is to keep fighting rather than to wait.
@export var ammo_cap: int = 0
## How often a body leaves a round behind. The gun's whole supply line, and the reason an empty
## pocket is a reason to close rather than to retreat.
@export_range(0.0, 1.0) var scavenge_chance: float = 0.0


func attack_at(index: int) -> AttackData:
	if index < 0 or index >= attacks.size():
		return null
	return attacks[index]


func chain_length() -> int:
	return attacks.size()


## Where a blow sits in the chain, or -1 for an attack this weapon does not throw. It is the only
## way to tell a chained hit from an opening one *while it lands*: the player's `chain_index` is the
## window a finished swing left open, and starting the next swing closes it.
func index_of(attack: AttackData) -> int:
	return attacks.find(attack)


## The wait this weapon charges for a finished chain.
func lockout_for(perfect: bool) -> float:
	return perfect_lockout if perfect else chain_lockout
