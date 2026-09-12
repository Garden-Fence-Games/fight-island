class_name RunStats
extends RefCounted
## The tally the run summary reads. Counted while the run happens rather than reconstructed at the
## end, because half of these numbers — a perfect hit, a parry — leave no trace to reconstruct
## them from once the fight is over.

var waves_cleared: int = 0
var ended_on_wave: int = 1
var seconds: float = 0.0
var money_earned: int = 0
var money_spent: int = 0
var perfect_hits: int = 0
var perfect_parries: int = 0

var _kills: Dictionary = {}


func record_kill(archetype: StringName) -> void:
	if archetype.is_empty():
		return
	_kills[archetype] = kills_of(archetype) + 1


func kills_of(archetype: StringName) -> int:
	return int(_kills.get(archetype, 0))


## The archetypes this run actually met, in the order they were first felled. Listing every
## archetype in the game instead would mean this screen keeping a list of them, and that list would
## be the second place they are enumerated.
func archetypes_seen() -> Array:
	return _kills.keys()


func total_kills() -> int:
	var total := 0
	for archetype: StringName in _kills:
		total += int(_kills[archetype])
	return total


func formatted_time() -> String:
	var whole := int(seconds)
	return "%d:%02d" % [whole / 60, whole % 60]
