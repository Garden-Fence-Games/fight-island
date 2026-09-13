class_name CoconutData
extends Resource
## Every number the coconuts answer to, in one place.
##
## **Two sources of health, doing different jobs.** The merchant's Health track is the one that
## fills the bar — it is bought, it costs a wave's money, and it heals to full. A coconut buys back
## a mistake while the fight is on, for a fixed amount, and that is all it does. `heals` being a
## figure rather than "to full" is what keeps those two apart; if a coconut filled the bar there
## would be no reason to ever buy the track.
##
## **The supply follows the crowd, and the ceiling follows it more slowly.** `per_enemy` sets the
## shape: a wave that presses harder supplies more, so the tuning in #82 does not have to carry a
## second curve. But the crowd grows fast over fifteen waves and a ceiling that grew with it would
## never bind — it would sit above what the rate produces at every wave and brake nothing, exactly
## where braking matters. So the ceiling rises too, and deliberately slower: more coconuts in
## absolute terms late on, and fewer per enemy, so the pressure still rises while the island is more
## generous than it was at wave 2.

## What one restores, in points, clamped at the player's maximum. Small against a hundred-point bar:
## enough that walking through the crowd to reach one is a decision, not enough to be a plan.
@export var heals: float = 25.0

## How many are owed over a whole wave, per enemy in it. The shape of the supply.
@export var per_enemy: float = 0.15

## How many may lie on the island at once, on the first wave. **This is the dial.** Everything else
## sets how generous the island is; this is what stops a late wave raining them, and it is the first
## number to reach for when a wave feels soft.
@export var at_once_first: int = 2
## What that ceiling gains per wave. A quarter means it reaches three at wave 5 and four at wave 9,
## against a crowd that has more than doubled — which is the whole intent.
@export var at_once_growth: float = 0.25
## And where it stops, so an endless run past wave 15 does not walk the ceiling up for ever.
@export var at_once_most: int = 6

## How long one lies in the sand before it is gone. Short enough that a wave cannot bank its supply
## for the next one, long enough to be worth crossing the island for.
@export var lies_for: float = 20.0

## How long the fall itself takes, from the crown to the sand.
@export var falls_for: float = 0.8
## How far from the foot of its own palm it may come to rest. It fell out of that tree, so it has no
## business landing somewhere else.
@export var lands_within: float = 1.6

## How often a drop is attempted. The wave's own total and the ceiling are what actually bound it;
## this only spreads them out rather than dropping the lot at the bell.
@export var every: float = 6.0

## Which palms are eligible, measured from the player. Near enough to reach during the wave it fell
## in, far enough that it is not handed over at the player's feet.
@export var nearest: float = 7.0
@export var furthest: float = 24.0


## How many may lie on the island at once, on this wave. Clamped at both ends: a wave number below
## one is the menu asking, and the top is what stops an endless run growing it for ever.
func at_once(wave: int) -> int:
	var grown := float(at_once_first) + float(maxi(wave, 1) - 1) * at_once_growth
	return clampi(int(floorf(grown)), 1, at_once_most)


## How many the whole wave owes. Rounded down, so a thin wave supplies nothing at all rather than
## always supplying one.
func owed(enemies: int) -> int:
	return maxi(int(floorf(float(maxi(enemies, 0)) * per_enemy)), 0)
