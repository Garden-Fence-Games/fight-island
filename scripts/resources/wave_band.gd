class_name WaveBand
extends Resource
## The archetype mix for a stretch of waves — one row of the composition table.

## The first wave this mix applies to. It holds until another band claims a later wave.
@export var first_wave: int = 1
@export var shares: Array[ArchetypeShare] = []


## An archetype, rolled against the mix. `melee_only` covers the rule that no wave opens with a
## thrower: the player is never shot at before anything is on screen.
##
## Normalised over what can actually be spawned rather than over the table, so a share naming an
## archetype that does not exist yet simply does not come up, and the remaining shares keep their
## proportions to each other. That is what lets the real table live in the data file while the
## reaper and the thrower are still issues.
func pick(rng: RandomNumberGenerator, melee_only: bool = false) -> EnemyData:
	var available: Array[ArchetypeShare] = []
	var total := 0.0
	for entry: ArchetypeShare in shares:
		if entry == null or entry.enemy == null or entry.share <= 0.0:
			continue
		if melee_only and entry.enemy.is_ranged:
			continue
		available.append(entry)
		total += entry.share
	if available.is_empty():
		return null
	var roll := rng.randf() * total
	for entry: ArchetypeShare in available:
		roll -= entry.share
		if roll <= 0.0:
			return entry.enemy
	return available[available.size() - 1].enemy
