class_name EliteRank
extends Resource
## The runner: a bigger, glowing body that does not fight. It stands where it was put, and the
## moment it sees the player it runs — slower than they walk, so it can always be caught — and
## whoever catches it is paid for the chase.
##
## Every archetype can roll one, and a runner is **the same scene** — no new model, no new texture,
## no new data file. What changes is what it does, what it pays, and how it looks.
##
## **It gets away through the sea.** It runs from the player, and on an island away is the water:
## once it is deep enough in it slips under and is gone with everything it was carrying. The end of
## a wave takes it the same way, as it takes every body still standing.

@export_group("Running")
## How close the player has to come before it bolts, in metres. Less than an ordinary body notices
## from, so a runner can be walked up on — which is the whole of the chase.
@export var notices_within: float = 5.0
## Its speed once running, in metres a second, and not scaled by the waves. **Under the player's
## walk**, whatever the wave: a runner that could outpace the player would be a reward nobody can
## collect.
@export var runs_at: float = 2.6
## How deep in the sea it has to be to slip under, and how long the slipping under takes.
@export var gone_at_depth: float = 0.6
@export var gone_over: float = 1.0

@export_group("What it pays")
## Coins thrown when it is killed, one money each.
@export var coins: int = 20
## Rounds thrown when it is killed, once the gun has been found.
@export var rounds: int = 15

@export_group("And obviously so")
## The mesh only, never the body. Scaling the whole node would quietly scale the collision shape,
## the swing's reach and the separation radius with it — three tuned numbers moved by a change
## nobody meant to be about them.
@export var scale: float = 1.15
## A runner has to be recognisable in under a second **and in greyscale**, which a hue cannot do on
## its own. Emission is the cue that survives: it reads as brighter, not just different.
@export var glow: Color = Color(1.0, 0.42, 0.16)
@export var glow_energy: float = 1.6
