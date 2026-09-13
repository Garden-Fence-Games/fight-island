class_name RagdollData
extends Resource
## What a ragdoll's body is made of: how heavy each part is, how far each joint turns, and how the
## whole thing loses energy. Without it every bone was a one-kilogram capsule a few centimetres wide
## joined by the same loose cone, and a farmer fell like a sock.
##
## **The weights are anthropometric, not tuned.** Each simulated bone carries its segment's share of
## the body from Winter's table (*Biomechanics and Motor Control of Human Movement*), which is where
## games take them from: the trunk is about half of a person, a thigh a tenth, the head a twelfth.
## A body that heavy in the middle and light at the ends tumbles about its hips instead of flailing
## about its wrists, which is most of what reads as "human" once it is on the floor.
##
## **The joint ranges contain every pose the rig is ever animated in**, measured across all of its
## clips, with room around them — a range tighter than a clip would snap a body into the limit on
## the frame it is knocked out of that clip.

## The whole body, in kilograms. The shares below divide it.
@export var body_mass: float = 85.0
## Each simulated bone's share of `body_mass`. Bones that are not simulated — hands, toes, the end
## of the head — fold into the nearest one that is: a forearm carries its hand. Shares that do not
## sum to one are normalised, so leaving a bone out does not quietly lighten the body.
@export var shares: Dictionary[StringName, float] = {}
## Each simulated bone's joint to its parent. A bone with no entry keeps a modest default range.
@export var joints: Dictionary[StringName, JointLimits] = {}
## How quickly a body stops spinning and sliding. Some, so a heavy body settles rather than rolling
## for ever on flat sand; not much, or it falls through the air as if underwater.
@export var angular_damp: float = 2.5
@export var linear_damp: float = 0.15
## Sand: grips, does not bounce.
@export var friction: float = 0.9
@export var bounce: float = 0.0
## How a bone's capsule is fitted to the mesh around it: the share of that bone's vertices the
## radius has to reach, and the smallest radius there may be. Not every vertex — a hat brim, a
## sleeve end or a belt buckle would each fatten a whole limb.
@export_range(0.1, 1.0, 0.01) var fit_share: float = 0.7
@export var smallest_radius: float = 0.05
