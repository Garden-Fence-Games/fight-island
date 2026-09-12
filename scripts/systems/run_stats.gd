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


## Anything missing or of the wrong type falls back to a fresh tally's value, so a hand-edited or
## half-written file costs the player their numbers rather than their run.
static func from_dict(data: Dictionary) -> RunStats:
	var stats := RunStats.new()
	stats.waves_cleared = int(data.get("waves_cleared", stats.waves_cleared))
	stats.ended_on_wave = int(data.get("ended_on_wave", stats.ended_on_wave))
	stats.seconds = float(data.get("seconds", stats.seconds))
	stats.money_earned = int(data.get("money_earned", stats.money_earned))
	stats.money_spent = int(data.get("money_spent", stats.money_spent))
	stats.perfect_hits = int(data.get("perfect_hits", stats.perfect_hits))
	stats.perfect_parries = int(data.get("perfect_parries", stats.perfect_parries))
	var kills: Variant = data.get("kills", {})
	if kills is Dictionary:
		for archetype: Variant in kills as Dictionary:
			# JSON has no StringName, and a String key would never answer `kills_of`.
			stats._kills[StringName(archetype)] = int((kills as Dictionary)[archetype])
	return stats


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


func to_dict() -> Dictionary:
	var kills := {}
	for archetype: StringName in _kills:
		kills[String(archetype)] = int(_kills[archetype])
	return {
		"waves_cleared": waves_cleared,
		"ended_on_wave": ended_on_wave,
		"seconds": seconds,
		"money_earned": money_earned,
		"money_spent": money_spent,
		"perfect_hits": perfect_hits,
		"perfect_parries": perfect_parries,
		"kills": kills,
	}
