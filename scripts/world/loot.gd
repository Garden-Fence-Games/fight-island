class_name Loot
extends Node3D
## One coin or one round, thrown out of a body: an arc, a hop on the sand, and a glint until
## somebody walks close enough to take it.
##
## **Thrown on an arc worked out once.** Where it lands is decided the moment it leaves the body —
## one ray down onto the island — and the flight is a parabola between the two ends. Nothing is
## simulated on the way, so a coin cannot tunnel through a slope or roll into the sea, and the arc
## is always the height it was asked to be, which is the point of it: long enough in the air to be
## seen.
##
## **Walked over, and generously.** Contact is enough, like a coconut, and "contact" is a wide
## circle — past it the piece flies at the player rather than waiting to be stood on. A round only
## comes to a gun with room for it; a full pocket leaves it lying until there is room.
##
## **It glints on purpose.** A gold coin is a few centimetres from a fixed camera twenty metres up,
## through a pixel filter. So it carries a small additive flare that is always there and twinkles —
## drawn over the metal, facing the camera — and reduced flashing keeps the glow and drops the
## twinkle.

enum Kind { COIN, ROUND }

## How far down from the top of the arc the island is looked for, and how far above.
const GROUND_SEARCH: float = 30.0
## What each kind is made of. Gold and silver: the colour is what says which one it is.
const GOLD: Color = Color(1.0, 0.76, 0.26)
const SILVER: Color = Color(0.86, 0.88, 0.92)

static var _flare_texture: Texture2D = null
static var _metal: Dictionary[int, StandardMaterial3D] = {}
## The body each kind wears, and the quad its flare is drawn on. Shared, because nothing writes to
## them: a coin's mesh is the same object for every coin ever thrown.
##
## **The flare's material is deliberately not here.** Every piece twinkles on its own clock and
## writes `albedo_color` each frame, so one shared material would have every coin on the island
## flicker in step — the defect this repository has already met twice, in the hitboxes and again in
## the impact flares.
static var _shape: Dictionary[int, Mesh] = {}
static var _flare_quad: QuadMesh = null

var kind: Kind = Kind.COIN
## Money for a coin, rounds for a round.
var amount: int = 1
var data: LootData = null
## Who it flies to. Handed over by whoever throws it, so nothing here looks the player up per frame.
var player: Node3D = null

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _apex: float = 1.0
var _flight: float = 1.0
var _flown: float = 0.0
var _landed_for: float = -1.0
var _pulled: bool = false
var _called: bool = false
var _phase: float = 0.0
var _spin: Node3D = null
var _body: MeshInstance3D = null
var _flare: MeshInstance3D = null
var _flare_material: StandardMaterial3D = null


## Starts it flying. `rng` rolls the arc; `space` finds the sand it lands on. Called once it is in
## the tree, because a global position written before that is dropped by the engine.
func throw(from: Vector3, rng: RandomNumberGenerator, space: PhysicsDirectSpaceState3D) -> void:
	_build()
	var angle := rng.randf_range(0.0, TAU)
	var reach := rng.randf_range(data.lands_nearest, data.lands_furthest)
	var flat := Vector3(cos(angle) * reach, 0.0, sin(angle) * reach)
	_from = from + Vector3.UP * data.leaves_at
	_to = _ground_under(from + flat, space)
	_apex = rng.randf_range(data.apex_lowest, data.apex_highest)
	_flight = rng.randf_range(data.flight_shortest, data.flight_longest)
	_phase = rng.randf()
	global_position = _from


## Whether it has come down yet. Before that it is a thing in the air and nobody can take it.
func has_landed() -> bool:
	return _landed_for >= 0.0


## Where it will come to rest.
func lands_at() -> Vector3:
	return _to


## The wave is over: fly at the player now, landed or not.
func call_in() -> void:
	_called = true
	_pulled = true


## Into the bag, wherever the player is. The end of a wave sweeps what is left this way. False when
## the bag would not take it — a round with no room for it.
func collect() -> bool:
	if kind == Kind.COIN:
		GameState.earn(amount)
		EventBus.coins_collected.emit(amount, self)
	else:
		var taken := GameState.loadout.take(amount)
		if taken <= 0:
			return false
		EventBus.rounds_scavenged.emit(taken, self)
	queue_free()
	return true


func _physics_process(delta: float) -> void:
	if _called and player != null and is_instance_valid(player):
		_fly_in(player, delta)
		return
	if not has_landed():
		_fly(delta)
		return
	_landed_for += delta
	_hop()
	if player != null and is_instance_valid(player):
		_come_to(player, delta)


func _process(delta: float) -> void:
	if _spin != null:
		_spin.rotate_y(data.spin * delta)
	_twinkle(delta)


func _fly(delta: float) -> void:
	_flown += delta
	var share := clampf(_flown / maxf(_flight, 0.01), 0.0, 1.0)
	var top := maxf(_from.y, _to.y) + _apex
	var along := _from.lerp(_to, share)
	# A parabola through both ends that peaks at `top`: the straight line between the ends, plus a
	# hump that is nought at either end and as tall as it needs to be in the middle.
	var straight := lerpf(_from.y, _to.y, share)
	var hump := 4.0 * (top - lerpf(_from.y, _to.y, 0.5)) * share * (1.0 - share)
	global_position = Vector3(along.x, straight + hump, along.z)
	if share >= 1.0:
		global_position = _to
		_landed_for = 0.0


## One small hop on landing, so it reads as having hit the sand rather than having stopped in the
## air.
func _hop() -> void:
	if _pulled or _landed_for > data.bounce_for:
		return
	var share := clampf(_landed_for / maxf(data.bounce_for, 0.01), 0.0, 1.0)
	global_position.y = _to.y + data.bounce_height * 4.0 * share * (1.0 - share)


## Flies at a player close enough, and goes in the bag once it reaches them. A round that the bag
## would refuse is not pulled at all: it stays where it is for when there is room.
func _come_to(to: Node3D, delta: float) -> void:
	if _landed_for < data.settles_for:
		return
	if kind == Kind.ROUND and GameState.loadout.room() <= 0:
		_pulled = false
		return
	var chest := to.global_position + Vector3.UP * 0.6
	var apart := global_position.distance_to(chest)
	var flat := Vector2(
		global_position.x - to.global_position.x, global_position.z - to.global_position.z
	)
	if flat.length() <= data.takes_within:
		collect()
		return
	if not _pulled and flat.length() > data.pulls_within:
		return
	_pulled = true
	global_position = global_position.move_toward(chest, data.pull_speed * delta)
	if apart <= 0.2:
		collect()


func _fly_in(to: Node3D, delta: float) -> void:
	var chest := to.global_position + Vector3.UP * 0.6
	global_position = global_position.move_toward(chest, data.pull_speed * delta)
	if global_position.distance_to(chest) <= 0.2:
		collect()


func _twinkle(delta: float) -> void:
	if _flare_material == null:
		return
	_phase = fposmod(_phase + delta * data.twinkle_hz, 1.0)
	var glint := pow(maxf(sin(_phase * TAU), 0.0), 6.0)
	if bool(Settings.get_value(&"access_reduce_flashing")):
		glint = 0.0
	var strength := (1.0 - data.glint_share) + data.glint_share * glint
	_flare_material.albedo_color = Color(_tint(), strength)
	_flare.scale = Vector3.ONE * (0.75 + 0.5 * glint)


func _tint() -> Color:
	return GOLD if kind == Kind.COIN else SILVER


func _ground_under(at: Vector3, space: PhysicsDirectSpaceState3D) -> Vector3:
	if space == null:
		return Vector3(at.x, at.y, at.z)
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * GROUND_SEARCH, at + Vector3.DOWN * GROUND_SEARCH, PhysicsLayers.BIT_WORLD
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return at
	return (hit["position"] as Vector3) + Vector3.UP * _resting_height()


## How far above the sand its middle sits, so it lies on the island rather than in it.
func _resting_height() -> float:
	return 0.12 if kind == Kind.COIN else 0.06


func _build() -> void:
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = _shape_for(kind)
	# A coin is stood on its edge, so the spin shows the face and then the rim.
	_body.rotation_degrees = (
		Vector3(90.0, 0.0, 0.0) if kind == Kind.COIN else Vector3(0.0, 0.0, 90.0)
	)
	_body.material_override = _metal_for(kind)
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The spin turns the holder, so a coin stood on its edge turns about the vertical.
	_spin = Node3D.new()
	_spin.name = "Spin"
	add_child(_spin)
	_spin.add_child(_body)
	_flare = MeshInstance3D.new()
	_flare.name = "Flare"
	_flare.mesh = _quad_for(data.flare_size)
	_flare_material = StandardMaterial3D.new()
	_flare_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flare_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flare_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flare_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_flare_material.albedo_texture = _flare_image()
	_flare_material.albedo_color = _tint()
	_flare_material.render_priority = 1
	_flare.material_override = _flare_material
	_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flare)


## The body a kind wears, built once. A mesh nobody writes to is one object, however many pieces
## are on the sand.
static func _shape_for(which: Kind) -> Mesh:
	if _shape.has(which):
		return _shape[which]
	var built: Mesh = null
	if which == Kind.COIN:
		var coin := CylinderMesh.new()
		coin.top_radius = 0.16
		coin.bottom_radius = 0.16
		coin.height = 0.045
		coin.radial_segments = 16
		coin.rings = 1
		built = coin
	else:
		var shell := CapsuleMesh.new()
		shell.radius = 0.065
		shell.height = 0.34
		shell.radial_segments = 10
		shell.rings = 2
		built = shell
	_shape[which] = built
	return built


## The quad every flare is drawn on. One size for all of them, off the same `LootData`.
static func _quad_for(side: float) -> QuadMesh:
	if _flare_quad != null and is_equal_approx(_flare_quad.size.x, side):
		return _flare_quad
	_flare_quad = QuadMesh.new()
	_flare_quad.size = Vector2.ONE * side
	return _flare_quad


## Polished metal, one material per kind shared by every piece of it. Metallic with a low roughness
## so it takes the sky, and a little emission so it still reads as gold or silver at dusk.
static func _metal_for(which: Kind) -> StandardMaterial3D:
	if _metal.has(which):
		return _metal[which]
	var material := StandardMaterial3D.new()
	var tint := GOLD if which == Kind.COIN else SILVER
	material.albedo_color = tint
	material.metallic = 1.0
	material.metallic_specular = 0.8
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.35
	_metal[which] = material
	return material


## A four-pointed star with a soft core, drawn once: the flare every piece wears.
static func _flare_image() -> Texture2D:
	if _flare_texture != null:
		return _flare_texture
	var side := 64
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var middle := (side - 1) / 2.0
	for y: int in side:
		for x: int in side:
			var dx := (x - middle) / middle
			var dy := (y - middle) / middle
			var core := pow(clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0), 3.0)
			var across := pow(clampf(1.0 - absf(dy) * 14.0, 0.0, 1.0), 2.0) * (1.0 - absf(dx))
			var down := pow(clampf(1.0 - absf(dx) * 14.0, 0.0, 1.0), 2.0) * (1.0 - absf(dy))
			var value := clampf(core + (across + down) * 0.8, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, value))
	_flare_texture = ImageTexture.create_from_image(image)
	return _flare_texture
