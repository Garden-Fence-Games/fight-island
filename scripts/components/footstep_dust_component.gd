class_name FootstepDustComponent
extends Node
## The puff a foot leaves in dry sand, and more of it the faster the body is going.
##
## **Built in code rather than saved in the scene**, like the head-look's modifier and the ragdoll's
## bones: it is one emitter with no decisions in it that an inspector would help with, and building
## it here keeps `player.tscn` about the player.
##
## **A primitive sphere rather than the authored orb.** The asset is a white ball scaled over
## thirteen frames; a `GPUParticles3D` does the same scaling on the GPU for every puff at once, and
## an imported mesh would buy a draw call and an asset to keep in step for no difference anyone can
## see. The moment the puff stops being a white ball — a texture, a shape — swap `MESH` for it here.
##
## Emission is tied to speed, not to a step: there is no footfall event on the rig yet, and a rate
## that rises with the body is what "more when sprinting" actually looks like.

## Puffs a second at a walk, and at a sprint. Between the two it is interpolated by speed, so the
## trail thickens as the player opens up rather than switching over.
@export var walking_rate: float = 14.0
@export var sprinting_rate: float = 34.0
## Under this the body counts as standing still and nothing is emitted — otherwise a player turning
## on the spot kicks up sand.
@export var still_speed: float = 0.4
@export var puff_life: float = 0.55
## How big a puff gets, in metres. It began at 0.16 m, which was dust that read as nothing at all at
## eighteen metres from a fixed camera — the scale the puff has to survive is the one the player
## actually watches it from, not the one it looks right at from a metre away.
@export var puff_size: float = 0.56
@export var dust: Color = Color(0.93, 0.89, 0.8, 0.5)

var _particles: GPUParticles3D = null
var _body: CharacterBody3D = null
var _walk_speed: float = 1.0
var _top_speed: float = 1.0


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	if _body == null:
		set_process(false)
		return
	# The two speeds the body actually travels at, read off the player rather than repeated here, so
	# the rates land on a walk and on a sprint instead of on a walk and on standing still. A walk is
	# already two thirds of a sprint, so interpolating up from zero would have put a walk at nearly
	# the sprinting rate and left the sprint with nothing left to say.
	_walk_speed = maxf(Player.MOVE_SPEED, 0.001)
	_top_speed = maxf(Player.SPRINT_SPEED, _walk_speed + 0.001)
	# Deferred, like the head-look's modifier: a component's `_ready` runs while its parent is still
	# setting up its own children, and an `add_child` there is dropped. The emitter then never enters
	# the tree, emits nothing, and is reported as a leak at exit — which is how this was found.
	_build.call_deferred()


func _process(_delta: float) -> void:
	if _particles == null or _body == null:
		return
	var speed := Vector2(_body.velocity.x, _body.velocity.z).length()
	if speed < still_speed or not _body.is_on_floor():
		_particles.emitting = false
		return
	_particles.emitting = true
	var effort := clampf((speed - _walk_speed) / (_top_speed - _walk_speed), 0.0, 1.0)
	_particles.amount_ratio = lerpf(walking_rate, sprinting_rate, effort) / sprinting_rate


func _build() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = puff_size * 0.5
	mesh.height = puff_size
	mesh.radial_segments = 6
	mesh.rings = 3

	var look := StandardMaterial3D.new()
	look.albedo_color = dust
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.vertex_color_use_as_albedo = true
	# Dust does not cast anything, and thirty puffs that did would cost more than the dust is worth.
	mesh.material = look

	var how := ParticleProcessMaterial.new()
	how.direction = Vector3.UP
	how.spread = 35.0
	how.initial_velocity_min = 0.4
	how.initial_velocity_max = 1.1
	how.gravity = Vector3(0.0, -0.8, 0.0)
	how.scale_min = 0.5
	how.scale_max = 1.0
	# Grown then gone, which is the shape the authored orb was drawing by hand.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.35, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ramp := CurveTexture.new()
	ramp.curve = curve
	how.scale_curve = ramp
	var fade := Gradient.new()
	fade.set_color(0, Color(dust.r, dust.g, dust.b, dust.a))
	fade.set_color(1, Color(dust.r, dust.g, dust.b, 0.0))
	var fade_texture := GradientTexture1D.new()
	fade_texture.gradient = fade
	how.color_ramp = fade_texture

	_particles = GPUParticles3D.new()
	_particles.name = "Dust"
	_particles.draw_pass_1 = mesh
	_particles.process_material = how
	_particles.amount = int(sprinting_rate * puff_life) + 1
	_particles.lifetime = puff_life
	_particles.emitting = false
	_particles.local_coords = false
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Behind the body and at the ground: the puff belongs where the foot left, not where the hips are.
	_particles.position = Vector3(0.0, 0.05, 0.15)
	_body.add_child(_particles)
