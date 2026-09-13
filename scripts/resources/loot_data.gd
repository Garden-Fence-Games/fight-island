class_name LootData
extends Resource
## Every number the coins and the rounds a body sprays out answer to, in one place.
##
## **A body pays the money it always did, and it pays it on the sand.** It is worth
## `EnemyData.money`, times its rank, and a round turns up on `WeaponData.scavenge_chance` of kills.
## What changed is that both are *thrown* and have to be walked over, so the payout is a thing in
## the world the player sees land, not a number that changed in a corner.
##
## **Nothing is lost by not walking over it.** Whatever is still lying on the sand when the wave
## ends goes into the bag anyway: the economy was tuned against every kill paying, and a run that
## quietly earned less because the player was busy surviving would be tuned against nothing.

## The most coins one body sprays, however much it was worth. The money is split across them, so a
## rich body is a bigger shower rather than a shower of a hundred.
@export var coins_most: int = 6

@export_group("The arc")
## How long it spends in the air, between these two, rolled per piece so a shower does not land as
## one.
@export var flight_shortest: float = 0.75
@export var flight_longest: float = 1.05
## How high the arc climbs above the higher of its two ends.
@export var apex_lowest: float = 1.4
@export var apex_highest: float = 2.2
## How far from the body it lands, flat.
@export var lands_nearest: float = 0.6
@export var lands_furthest: float = 2.2
## Where on the body it leaves from.
@export var leaves_at: float = 1.0
## The little hop when it meets the sand, and how long that hop takes.
@export var bounce_height: float = 0.15
@export var bounce_for: float = 0.22

@export_group("Taking it")
## How close the player has to be for it to be theirs. Generous on purpose: this is walked over in
## the middle of a fight, and a pickup that has to be stood on exactly is a pickup that gets missed.
@export var takes_within: float = 1.1
## And how close for it to start flying at them, which is what makes the generous radius feel like
## the coin came to them rather than like the game cheating.
@export var pulls_within: float = 2.6
## How fast it flies once pulled, in metres a second.
@export var pull_speed: float = 11.0
## How long after landing before it can be pulled. Short: long enough to see it land.
@export var settles_for: float = 0.15
## How long the end of a wave lets everything left fly in before the rest is put in the bag. Under
## `RunFlow.DELAY`, the beat before the merchant opens — `verify_loot` holds the two apart.
@export var sweep_after: float = 0.9

@export_group("The sparkle")
## How wide the flare is, in metres. Several times the piece itself: a coin is a few centimetres of
## metal twenty metres from a fixed camera, and the flare is the part that is meant to be seen.
@export var flare_size: float = 1.1
## How often it twinkles, and how much brighter the glint is than the constant glow under it.
@export var twinkle_hz: float = 1.3
@export var glint_share: float = 0.6
## Turns per second while it lies there.
@export var spin: float = 3.0


## How many coins a body worth `money` sprays: one per unit, up to the ceiling, never zero for a
## body worth something.
func coins_for(money: int) -> int:
	if money <= 0:
		return 0
	return clampi(money, 1, maxi(coins_most, 1))


## What each of those coins carries. The remainder rides on the first, so the shower always adds up
## to exactly what the body was worth.
func coin_values(money: int) -> Array[int]:
	var values: Array[int] = []
	var count := coins_for(money)
	if count == 0:
		return values
	var each := money / count
	for index: int in count:
		values.append(each)
	values[0] += money - each * count
	return values
