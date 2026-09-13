class_name SunGlintData
extends Resource
## How the midday sun flares off the glass by the spawn. See `SunGlint`.

## The hour the flare is strongest, and how many hours either side of it it fades out over. The day
## phase runs nine to six, so this is the middle of it.
@export var noon_hour: float = 13.5
@export var noon_reach: float = 3.0
## How tightly a bottle has to reflect the sun at the camera to flare: an exponent on the alignment,
## so a higher figure is a rarer, briefer flash.
@export var sharpness: float = 90.0
## How far each bottle's glinting face may point away from straight up, as a share of a full tilt.
## Each bottle gets its own at random, which is what makes different ones catch as the view moves.
@export_range(0.0, 1.0, 0.01) var facet_spread: float = 0.55
## The flare at full strength: how big the burst is, as a share of the screen's height, and how
## bright it and its ghosts get.
@export var burst_size: float = 0.55
@export_range(0.0, 2.0, 0.01) var strength: float = 1.0
## How fast the flare follows the glint, per second. Slow enough that one frame's catch does not
## strobe; quick enough that it reads as the sun catching glass.
@export var response: float = 10.0
