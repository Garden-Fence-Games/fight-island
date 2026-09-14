class_name FrenzyData
extends Resource
## Every number the rainbow bird answers to, in one place.
##
## **The bird is a moment, not a build.** It sits still somewhere the player can see, and walking
## over it hands them a few seconds where nothing can hurt them, their feet are twice as fast and
## every punch throws a body the way a finisher does and kills it outright. It cannot be stacked, it
## ends with the wave, and afterwards the bag is exactly what it was.

## The chance a wave has one at all, rolled when the wave starts.
@export_range(0.0, 1.0) var chance_per_wave: float = 0.3333
## The first wave that may roll one. The first wave is the tutorial's, and it cannot kill anyway.
@export var first_wave: int = 2
## When, in seconds into the wave, it lands — somewhere in this range. Never at the bell, so it is a
## thing that turns up in the middle of a fight rather than part of the wave's opening.
@export var lands_between: Vector2 = Vector2(10.0, 50.0)
## How far from the player it lands: near enough to reach during the wave, far enough that it is a
## detour through the crowd.
@export var nearest: float = 7.0
@export var furthest: float = 14.0

@export_group("While it lasts")
## How long the power lasts once the bird is taken.
@export var lasts: float = 15.0
## What the player's walk and sprint are multiplied by.
@export var speed_multiplier: float = 2.0
## The blow every punch lands as, for the push and the poise: the fists' finisher. The damage is
## never read — a punch during the power takes whatever health the body has left.
@export var launches_like: AttackData = null
## The last seconds of it blink, so the end is never a surprise in the middle of a crowd.
@export var warns_for: float = 2.5


## Whether a wave with this roll gets a bird. The roll arrives rather than being made here, so a
## check can ask with a known answer.
func lands_on(wave: int, roll: float) -> bool:
	return wave >= first_wave and roll < chance_per_wave
