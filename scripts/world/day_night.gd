class_name DayNight
extends Node3D
## The sun, the sky and the fog, following the clock.
##
## It reads how far into the wave the fight is, which is the same clock the rules read — so the
## light and the damage change together, and a player who sees the sun go down has been told what
## is about to happen to them.
##
## Owning the light and the environment as children rather than pointing at them: node exports do
## not resolve in a hand-written .tscn (ADR 0006), and the thing that paints the sky may as well be
## the thing the sky hangs from.

@onready var world: WorldEnvironment = $Environment
@onready var sun: DirectionalLight3D = $Sun


func _ready() -> void:
	# The environment is a sub-resource of the scene, and a sub-resource is shared by every instance
	# of it. Two arenas in one process — which is exactly what the headless checks make — would
	# otherwise paint each other's sky.
	if world != null and world.environment != null:
		world.environment = world.environment.duplicate(true)
	# A sky opens at daybreak unless something is driving it. The arena's wave director overwrites
	# this on its first frame; the title screen's island has no director, and without the reset it
	# would come up at whatever hour the run the player just lost had reached.
	GameState.day_elapsed = 0.0


func _process(_delta: float) -> void:
	var cycle := GameState.day_cycle as DayCycle
	if cycle == null or world == null or sun == null:
		return
	var holding := cycle.phase_at(GameState.day_elapsed)
	if holding == null:
		return
	var turning := cycle.after(holding)
	_paint(
		holding, turning if turning != null else holding, cycle.turn_amount(GameState.day_elapsed)
	)


func _paint(from: DayPhase, to: DayPhase, amount: float) -> void:
	sun.light_color = from.sun_colour.lerp(to.sun_colour, amount)
	sun.light_energy = lerpf(from.sun_energy, to.sun_energy, amount)
	_aim(
		lerpf(from.sun_elevation_degrees, to.sun_elevation_degrees, amount),
		rad_to_deg(
			lerp_angle(
				deg_to_rad(from.sun_azimuth_degrees), deg_to_rad(to.sun_azimuth_degrees), amount
			)
		)
	)
	var air := world.environment
	air.ambient_light_energy = lerpf(from.ambient_energy, to.ambient_energy, amount)
	air.fog_light_color = from.fog_colour.lerp(to.fog_colour, amount)
	air.fog_density = lerpf(from.fog_density, to.fog_density, amount)
	if air.sky == null:
		return
	var dome := air.sky.sky_material as ProceduralSkyMaterial
	if dome == null:
		return
	var horizon := from.sky_horizon.lerp(to.sky_horizon, amount)
	dome.sky_top_color = from.sky_top.lerp(to.sky_top, amount)
	dome.sky_horizon_color = horizon
	# The ground half of the dome is what the camera sees past the island's edge. Left bright it
	# stays daylight-blue under a midnight sky, and the horizon reads as a seam.
	dome.ground_horizon_color = horizon
	dome.ground_bottom_color = horizon.darkened(0.5)


## A directional light shines down its own -Z, so yaw first and then tip it down by the elevation.
func _aim(elevation: float, azimuth: float) -> void:
	sun.rotation = Vector3.ZERO
	sun.rotate_y(deg_to_rad(azimuth))
	sun.rotate_object_local(Vector3.RIGHT, deg_to_rad(-elevation))
