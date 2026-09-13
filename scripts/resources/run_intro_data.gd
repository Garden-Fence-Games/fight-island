class_name RunIntroData
extends Resource
## How a new run opens: the clip the player wakes up in, and the camera's turn around him before it
## settles into the one the game is played from. See `RunIntro`.

## The clip on the player's rig. It plays whole; nothing cuts it short.
@export var clip: StringName = &"new_run_awakening"
## How far round the player the camera travels while he wakes, in degrees, ending exactly where the
## game camera sits.
@export var turn_degrees: float = 360.0
## Where the turn starts, as a share of the game camera's distance and height: closer in and lower,
## opening out to the game's framing as it comes round.
@export_range(0.1, 1.0, 0.01) var start_distance: float = 0.45
@export_range(0.1, 1.0, 0.01) var start_height: float = 0.35
## The height on the body the camera looks at while it turns, in metres.
@export var look_height: float = 0.9
## Seconds the camera takes, once the clip has ended, to ease from wherever the turn left it onto
## the game camera — and the moment the player gets the body back.
@export var settle_seconds: float = 0.8
