class_name TutorialStep
extends Resource
## One lesson of wave 1. The order and the wording are data, so changing either is an inspector
## edit and never a script edit — which is the only way the seven steps stay a design decision
## rather than a code one.
##
## A step is two halves: **what closes it**, and **what the wave does while it is open**. Nothing
## here describes a prompt beyond its string, because a step that knows how it is drawn is a step
## whose UI cannot be replaced.

## What the director watches for. `NONE` is the movement lesson: walking is the one thing in this
## game nothing else cares about, so there is no event to listen to and the director measures it.
enum Trigger {
	NONE,
	ATTACK_LANDED,
	DODGE_EVADED,
	PARRY_PERFECT,
	PLAYER_STATE,
}

## An extra condition on the trigger, when the event alone is not the lesson. A landed hit is a
## landed hit; the chain and the perfect window are the *same* event with something more true
## about it.
enum Condition {
	ANY,
	PERFECT,
	CHAINED,
}

@export var id: StringName = &""
## A localisation key, never a literal — the prompt is the one string in the game a player reads
## mid-fight, and it has to be translatable like the rest. `{0}` in the string is the glyph.
@export var prompt_key: String = ""
## Which actions the glyph names. One for most lessons; four for movement, which the player does
## with a whole stick or a whole cluster of keys rather than with a button. Empty for the lessons
## that are about timing and have no button to name.
@export var prompt_actions: PackedStringArray = []
@export var trigger: Trigger = Trigger.NONE
@export var condition: Condition = Condition.ANY
## For `PLAYER_STATE`: the state whose arrival closes the step.
@export var state: StringName = &""
## For `NONE`: metres the player has to cover. Movement is taught by moving.
@export var travel: float = 0.0

@export_group("What the wave does")
## Bodies standing on the island while this step is open. The step says how many should be there,
## not how many to send — so a farmer killed during the lesson is replaced and the lesson survives
## being played well.
@export var enemies: int = 0
## Spawned unable to attack. The first lessons need something to hit that will not hit back.
@export var passive: bool = false
## Enough health to survive being the subject of a lesson. A farmhand that dies to the chain
## demonstration takes the perfect-hit demonstration with him.
@export var health_multiplier: float = 1.0
## A slower telegraph, so a first parry is readable. Never faster: this is a floor, not a dial.
@export var windup_multiplier: float = 1.0
## The wave cannot end while this step is open. True for the parry and nothing else — a player who
## reaches wave 2 without ever having parried is lost by wave 5.
@export var holds_wave: bool = false


## What has to have happened for this step to be over, as one name. The director keeps the set of
## everything the player has done this wave and closes any step whose fact is already in it — which
## is the whole of *satisfied retroactively*, including for something done long before it was asked.
func fact() -> StringName:
	match trigger:
		Trigger.ATTACK_LANDED:
			return _hit_fact()
		Trigger.DODGE_EVADED:
			return &"evaded"
		Trigger.PARRY_PERFECT:
			return &"parried"
		Trigger.PLAYER_STATE:
			return StringName("state:%s" % state)
	# The movement lesson has no event behind it; the director measures the distance instead.
	return &""


## A landed hit, a chained one and a perfect one are the same event with more true about it, so
## they are three facts rather than one fact with a qualifier.
func _hit_fact() -> StringName:
	match condition:
		Condition.CHAINED:
			return &"hit_chained"
		Condition.PERFECT:
			return &"hit_perfect"
	return &"hit"
