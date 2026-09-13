class_name BloodData
extends Resource
## What a landed blow spills, where it lands, and how long the island remembers it.
##
## Three layers, each with its own job, and every figure that tunes them is here:
##
## - **The splash**, in the air for half a second: droplets thrown the way the blow travelled,
##   stretched along their own velocity so a fast one reads as a streak and a slow one as a drop.
## - **The stain**, a decal on whatever is underneath — sand, grass, rock, a body already down —
##   placed where the droplets come down, sharp and fresh.
## - **The memory**, a mask the size of the island that every stain is also stamped into for good,
##   and that the ground's own shader mixes towards red. The decal fades once the mask carries it,
##   so the island keeps every fight at a constant cost however long the run goes on.

## The red. Bright on purpose: this is the colour the island turns, and it is asked to be seen from
## a camera seventeen metres up in daylight.
@export var colour: Color = Color(0.78, 0.02, 0.04, 1.0)

@export_group("Splash")
## Droplets per blow, and per perfect one. A perfect hit already differs three ways in `Impact`;
## spilling more is a fourth that costs nothing to read.
@export var droplets: int = 22
@export var perfect_droplets: int = 40
## How fast they leave, in metres per second, before a perfect blow's own multiplier.
@export var splash_speed: Vector2 = Vector2(2.5, 7.0)
@export var perfect_speed_scale: float = 1.4
## How long a droplet is in the air. The stains are timed off this, not off the particles, so the
## two are the same number read in two places rather than two numbers that drift.
@export var splash_life: float = 0.55
## How high above the target's feet the splash starts. The chest, roughly: where a blow lands.
@export var splash_height: float = 1.2

@export_group("Stains")
## Stains per blow, and per perfect one. The first falls at the victim's feet; the rest are thrown
## downstream along the blow.
@export var stains: int = 3
@export var perfect_stains: int = 5
## Width of the stain at the feet, and of the ones thrown, in metres.
@export var pool_size: Vector2 = Vector2(0.8, 1.5)
@export var fleck_size: Vector2 = Vector2(0.3, 0.8)
## How far downstream a thrown stain may land, in metres, and how far it may stray sideways as a
## share of that distance.
@export var throw_distance: Vector2 = Vector2(0.6, 2.8)
@export var throw_scatter: float = 0.35
## Seconds between the blow and the stains appearing: the droplets have to come down first.
@export var land_delay: float = 0.2
## Seconds a stain takes to spread to its full size once it lands.
@export var spread_time: float = 0.12
## Nothing is stained below this height. The sea is not a canvas, and the swell reaches 0.99 m under
## the plateau.
@export var dry_above: float = -0.95

@export_group("Decals")
## How many sharp stains may be on the island at once. The oldest is recycled when a new one needs
## its decal — the mask has already kept it.
@export var decal_count: int = 48
## Seconds a decal stays sharp, then seconds it takes to fade into the mask beneath it.
@export var decal_life: float = 8.0
@export var decal_fade: float = 2.5

@export_group("Island memory")
## Pixels along each side of the mask, and the metres of island it covers. 1024 over 180 m is about
## 18 cm a pixel: blurry up close, and a stain seen from the fixed camera, softened by linear
## filtering, which is what dried blood soaked into sand looks like anyway. The decal carries the
## sharp edge while it is fresh.
@export var mask_resolution: int = 1024
@export var mask_extent: float = 180.0
## How much one stamp covers. Under one, so a spot hit again goes redder rather than simply staying.
@export var mask_strength: float = 0.8
## Seconds between uploads of a mask that has changed. The upload is the whole texture, so it is
## batched: a crowd's worth of blows in one frame is still one upload.
@export var mask_refresh: float = 0.2
## How much wetter the ground looks where it is soaked: roughness goes from the sand's to this.
@export var wet_roughness: float = 0.45
