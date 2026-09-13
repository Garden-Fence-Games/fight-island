class_name DayPhase
extends Resource
## One stretch of the day, and everything that is different while it lasts.
##
## The look and the rules live together on purpose. A night the player can see is a night whose
## rules they can read, and splitting "how dark" from "how mean" across two files is how a tuning
## pass ends up with a pitch-black stretch that hits for a quarter of the health bar.

@export var id: StringName = &""
## A translation key rather than a word, so the clock reads in the player's language.
@export var display_name: String = ""
## How long this phase lasts, in seconds of a wave. The phases together are one wave.
@export var seconds: float = 180.0
## The hour the phase begins on, which is also the hour the clock reads when it takes over. The
## phase runs from here to the next one's start, so the array of them is a whole day and the spans
## cannot leave a gap without someone noticing the clock skip.
@export_range(0.0, 24.0) var starts_at_hour: float = 0.0
## **How much of this phase is spent turning into the next one**, as a share of its own span. A
## quarter suits a phase whose job is to hold a look: a sky that is always halfway between two
## things never looks like either.
##
## **Dawn and dusk are the opposite**, and they carry one. They exist to be the turn — holding a
## dusk and then flipping into night in the last few seconds of it is the abrupt version of exactly
## the thing they were added to smooth. At one, the light slides continuously from the day, through
## the dusk's own colours, into the night, and never sits still in between.
@export_range(0.0, 1.0) var turning_share: float = 0.25

@export_group("Rules")
@export var damage_scale: float = 1.0
## Applied to the telegraph before the wave config's floor, never after: the floor is the point
## past which a wind-up stops being readable, and night is not allowed to argue with it.
@export var windup_scale: float = 1.0
## How much further one farmer noticing the fight carries to the ones standing near him. This is
## the dial that changes the shape of a night rather than its numbers — by day the player picks off
## the edge of a crowd, by night the whole beach turns at once.
@export var rouse_scale: float = 1.0
@export var melee_tokens: int = 2

@export_group("Look")
@export var sun_colour: Color = Color(1.0, 0.96, 0.88)
@export var sun_energy: float = 1.0
## Degrees above the horizon. It drives the shadows, which is the most visible half of the look:
## a low sun throws the long shadows that say evening better than any colour does.
@export var sun_elevation_degrees: float = 55.0
## Degrees around the compass, and it only ever increases across a turn so the sun sweeps forward
## through the sky instead of swinging back the way it came.
@export var sun_azimuth_degrees: float = 40.0
## How much of the light a shadow takes away. It has to follow the sun rather than stay put: a moon
## at a third of daylight's energy, casting a shadow as opaque as noon's, is what makes a night look
## like a day render with the brightness pulled down. The shadow would be darker than the light that
## threw it.
@export_range(0.0, 1.0) var shadow_opacity: float = 1.0
## How far a shadow's edge spreads. A high sun draws a hard edge because it is nearly a point; a low
## one and a moon throw edges that have travelled through air, and a knife-sharp shadow under a dim
## sky reads as a decal stuck to the ground rather than as shade.
@export var shadow_softness: float = 1.0
## Ambient comes from the sky, so this is a multiplier on a background that darkens by itself. It
## goes *up* at night rather than down — the sky is already black, and what is left has to keep a
## silhouette legible.
@export var ambient_energy: float = 1.0
@export var sky_top: Color = Color(0.32, 0.52, 0.85)
@export var sky_horizon: Color = Color(0.68, 0.8, 0.92)
@export var fog_colour: Color = Color(0.6, 0.73, 0.84)
@export var fog_density: float = 0.0
