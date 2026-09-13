class_name TideData
extends Resource
## What standing in the sea costs, in health a second.
##
## The sea has always pushed back at the wading limit and has always cost speed on the way there.
## Neither of those could ever kill anybody: the push wins against a walk before the water is over
## a head, so the boundary was a wall the player bounced off rather than a place with a price.
##
## **It drains rather than killing at a depth.** A threshold is unreadable — the player is fine and
## then the run is over — while a bar coming down is on the screen they already watch, and it tells
## them how long they have. Every point of it is reversible: stop pushing outward and the sea
## carries them back in.
##
## Drowning ends the run through `HealthComponent.died` and `player_died`, the same door every other
## death goes through. It is the only thing in the game that can end a run without a fight, which is
## why the warning is the whole of the feature and the death is only where it stops.

## Where the bar starts coming down, measured from the water plane. The same depth the sea starts
## pushing back at, so one thing happens at one place: the water that shoves is the water that
## costs.
@export var drains_from: float = 1.1
## And where the drain is at its full rate. A walk out against the push stalls at about 1.4 m and a
## sprint at about 1.6, so this is the far end of what anybody can reach by insisting.
@export var drowns_at: float = 1.6
## Health a second at that depth, falling to nothing at `drains_from`. Twenty takes a full bar in
## five seconds at the deepest a player can hold themselves, and about eight at a walk — long enough
## to notice, short enough to mean something.
@export var drains: float = 20.0

@export_group("Forcing")
## **Insisting costs more the longer it goes on.** While the player keeps walking out against the
## push, the drain doubles every this many seconds — an exponential, so a few seconds of it is a
## warning and a few more is the end. Standing still or turning back resets it at once: the sea is
## only merciless to somebody who is fighting it.
@export var forcing_doubles_every: float = 1.0
## The most the forcing can multiply the drain by, so the curve stays a curve and not a switch.
@export var forcing_cap: float = 10.0
## How squarely the player has to be heading out to count as forcing: the dot of their movement with
## the way out to sea. Walking along the shore in deep water is not insisting.
@export var forcing_alignment: float = 0.3

@export_group("Going under")
## How fast a drowned body sinks, in metres a second, while it keeps struggling.
@export var sink_speed: float = 0.45
## How far it sinks before it is gone and the struggle stops — past the top of its head.
@export var sink_depth: float = 1.6


## How fast the sea is taking this body, at a height above the water plane. Nought anywhere it does
## not reach, so a caller never has to ask whether the player is in the water.
func draining_at(height: float, water_level: float) -> float:
	var depth := water_level - height
	if depth <= drains_from:
		return 0.0
	var into := (depth - drains_from) / maxf(drowns_at - drains_from, 0.01)
	return drains * clampf(into, 0.0, 1.0)


## What the drain is multiplied by after `seconds` of forcing: one at the start, doubling every
## `forcing_doubles_every`, never past `forcing_cap`.
func forcing_multiplier(seconds: float) -> float:
	if seconds <= 0.0:
		return 1.0
	return minf(pow(2.0, seconds / maxf(forcing_doubles_every, 0.01)), maxf(forcing_cap, 1.0))


## How long a drowned body takes to go all the way under.
func sink_seconds() -> float:
	return sink_depth / maxf(sink_speed, 0.01)
