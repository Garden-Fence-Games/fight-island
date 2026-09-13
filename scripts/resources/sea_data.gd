class_name SeaData
extends Resource
## What the sea does to whoever walks into it — one slope, read at three depths.
##
## The island is not round, so the edge of the world is the waterline rather than a circle. These
## are the numbers that make it mean something: where the sea starts shoving back, how hard it
## shoves, how deep it has to be before it costs anything, and how fast it costs it. They live here
## and in `docs/game-design.md`, and nowhere else.

## How deep anyone may wade before the sea starts pushing back, measured down from the water plane.
## Everything above is the beach and costs nothing but speed.
@export var wade_depth: float = 1.1
## How hard it pushes, in metres per second, at the depth it starts drowning. It builds from nothing
## at the wading limit rather than arriving whole — a boundary that cannot be pushed against is a
## wall, and this one is meant to be losable.
@export var push_speed: float = 5.0
## Water over the head: past this the sea starts taking health. Clear of the wading limit on
## purpose, because the shove and the drag are the warning and they have to come first.
@export var drowns_at: float = 2.2
## How much deeper than `drowns_at` the water has to be before it takes everything it is going to.
## Nought here would make the surface of the drowning depth a switch.
@export var drowns_over: float = 1.0
## Health a second at full depth. A hundred-point player has seven seconds of it, which is the
## window to stop fighting the push and let the sea carry them back in.
@export var drains: float = 14.0
## How far the body lists as it goes under, in degrees at full depth. There is no drowning clip and
## no way to author one yet (#180), so the tell is the body itself — the same trade `EnemyWindUp`
## makes for its telegraph, and the same seam left for the clip when the rig lands.
@export var lists_by: float = 28.0


## How far past the wading limit a body at this height is, nought to one, where one is the depth
## that drowns. **The warning, as a number**: it is what the shove is scaled by, what the body lists
## by, and what reaching one starts the drain.
func sinking_at(height: float, water: float) -> float:
	var depth := water - height
	if depth <= wade_depth:
		return 0.0
	return clampf((depth - wade_depth) / maxf(drowns_at - wade_depth, 0.01), 0.0, 1.0)


## Health a second at this height, and nought anywhere a body can stand.
func drain_at(height: float, water: float) -> float:
	var past := (water - height) - drowns_at
	if past <= 0.0:
		return 0.0
	return drains * clampf(past / maxf(drowns_over, 0.01), 0.0, 1.0)
