class_name AttackData
extends Resource
## One attack. Every window is measured in seconds from the start of this attack's recovery, which
## is why a chain window can outlast the recovery itself.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Damage")
@export var damage: float = 8.0
@export var stagger: float = 0.1
@export var poise_damage: float = 10.0

@export_group("Cost")
@export var stamina_cost: float = 6.0
@export var ammo_cost: int = 0

@export_group("Timing")
@export var windup: float = 0.12
@export var active: float = 0.08
@export var recovery: float = 0.22
## Pressing attack inside this window continues the chain. Zero width means this attack is a
## finisher and nothing follows it.
@export var chain_window: Vector2 = Vector2(0.10, 0.45)
## The last slice of the chain window. A press in here is perfect.
@export var perfect_window: Vector2 = Vector2(0.33, 0.45)
@export var perfect_multiplier: float = 1.35
@export var hitstop: float = 0.08

@export_group("Reward")
## What a body killed by this attack is worth, over what it would otherwise pay. It sits on the
## attack rather than on the chain, next to `perfect_multiplier`, because the chain is where the
## *timing* lives and this is about which swing landed — a finisher is reachable only by chaining
## twice, so paying for the swing and paying for the combo are the same rule stated once.
@export var money_multiplier: float = 1.0

@export_group("Reach")
@export var reach: float = 1.4
@export var arc_degrees: float = 70.0

@export_group("Ranged")
## Resolved as a ray the instant the windup ends, instead of arming a hitbox for its active frames.
## A bullet has no travel and no swing: giving one active frames would let a farmer walk into a shot
## that had already been fired.
@export var is_hitscan: bool = false
## Rays one press sends. The double tap is two, which is also why it needs two rounds to exist.
@export var shots: int = 1
## The windup only advances while the button is held, and letting go early cancels the attack. The
## charged shot is the one attack in the game that asks for a hold rather than a tap.
@export var charges: bool = false

@export_group("Presentation")
@export var animation: StringName = &""


func is_finisher() -> bool:
	return is_equal_approx(chain_window.x, chain_window.y)


func total_duration() -> float:
	return windup + active + recovery
