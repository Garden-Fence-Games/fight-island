class_name EliteRank
extends Resource
## What being an elite is worth, in one place.
##
## Every archetype can roll one, and an elite is **the same scene** — no new model, no new texture,
## no new data file. That constraint is what keeps a difficulty curve from turning into an asset
## list, and it is the reason these are multipliers rather than a second set of stats.

@export_group("Worse")
@export var health_multiplier: float = 2.0
@export var damage_multiplier: float = 1.4
## Paid on death. An elite that is twice the fight has to be worth more than twice the money, or
## the right play is to walk away from it.
@export var money_multiplier: int = 3

@export_group("And obviously so")
## The mesh only, never the body. Scaling the whole node would quietly scale the collision shape,
## the swing's reach and the separation radius with it — three tuned numbers moved by a change
## nobody meant to be about them.
@export var scale: float = 1.15
## An elite has to be recognisable in under a second **and in greyscale**, which a hue cannot do on
## its own. Emission is the cue that survives: it reads as brighter, not just different.
@export var glow: Color = Color(1.0, 0.42, 0.16)
@export var glow_energy: float = 1.6
