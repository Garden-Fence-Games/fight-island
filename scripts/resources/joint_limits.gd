class_name JointLimits
extends Resource
## How far one joint of a ragdoll may turn, in degrees, measured **from the rig's rest pose** in an
## anatomical frame built for that joint:
##
## - **flex** turns the bone's tip towards the body's front — or towards its back, for a joint that
##   `bends_back`, which is a knee. This is the axis a hinge would have.
## - **twist** turns the bone about its own length.
## - **side** turns it across the body.
##
## From the rest pose rather than from whatever pose the body was in when it was knocked, because a
## limit measured from a pose is a limit that moves with it: a farmer hit mid-stride would get knees
## that fold forward by exactly as much as his stride had them bent. `RagdollComponent` starts the
## simulation at rest and puts every body back where the animation had it, so these mean the same
## thing whatever pose a body leaves.

## Least and most flexion. Negative is extension — a hip swinging behind the body, a knee locking.
@export var flex: Vector2 = Vector2(-20.0, 20.0)
## Twist either way about the bone's own length.
@export var twist: float = 15.0
## Least and most turn across the body.
@export var side: Vector2 = Vector2(-15.0, 15.0)
## A knee: flexion takes the tip towards the back of the body rather than the front.
@export var bends_back: bool = false
