class_name Water
extends Node
## Wading costs speed, for whoever is doing it.
##
## It is the cheapest way to make the shoreline mean something: the beach stops being decoration and
## becomes a place you think twice about being caught in. Enemies pay it too, so backing into the
## shallows is a real choice rather than a free escape.

## Speed left at the deepest anyone is allowed to wade. Ankle-deep barely costs anything; the drag
## builds as the ground falls away.
const SLOWEST: float = 0.35

static var level: float = -1.1


## How much of its speed a body keeps at this height. One above water, falling to SLOWEST at the
## wading limit.
static func drag_at(height: float, wade_limit: float) -> float:
	if height >= level:
		return 1.0
	var depth := clampf((level - height) / maxf(wade_limit, 0.01), 0.0, 1.0)
	return lerpf(1.0, SLOWEST, depth)
