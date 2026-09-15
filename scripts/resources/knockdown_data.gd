class_name KnockdownData
extends Resource
## What a blow does to a body once it has landed: how hard it throws him, what breaking his poise
## adds to that, how long he may stay down, and how long getting up takes.
##
## **These are not per-attack figures, and that is the point.** What differs between a jab and an
## uppercut is already `AttackData.stagger`; these three turn that one number into a knockdown, and
## they are the same conversion for every attack in the game. One instance, in `data/combat/`.
##
## They lived as constants in `Enemy` and `EnemyStagger` until now, which put three balance figures
## in scripts and left `docs/game-design.md` describing numbers no designer could reach.

## Metres per second per point of `AttackData.stagger`. A jab at 0.10 nudges a man over; an
## uppercut at 0.60 sends him seven metres a second.
@export var knock_speed: float = 12.0
## What breaking poise is worth, as a multiple of the blow's own throw. Every hit already rocks
## him; this is the difference between rocked and sprawling.
@export var broken_poise_push: float = 1.8
## How much longer than the attack's own stagger figure a man may stay down before he is taken back
## whether the physics has settled him or not.
##
## **The attack still decides how long a knockdown lasts.** The tumble ends when the body stops
## moving, which is almost always first; this is the ceiling for the times it does not — wedged
## against a rock, caught on a slope. A flat ceiling would put a jab down as long as an uppercut.
@export var fall_ceiling: float = 4.0
## How long standing back up takes **for a rig with no get-up clip**. The farmer now carries two,
## `get_up_back` and `get_up_front`, and a rise lasts the length of whichever is playing — this is
## the stand-in for a body that has neither, and the rest pose is what it stands up in.
@export var rise_time: float = 0.7
## How long a body's poise stays spent before it refills. The meter is what turns a run of small
## hits into a knockdown, so this is the window in which they have to arrive — long enough that a
## chain counts as one beating, short enough that a man left alone recovers.
##
## It was a bare `2.0` in `Enemy._on_hurt` while every other figure of the same conversion lived
## here, which put one balance number out of a designer's reach and out of `docs/game-design.md`.
@export var poise_window: float = 2.0
