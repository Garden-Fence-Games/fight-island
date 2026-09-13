class_name BloodField
extends Node
## Where the blood goes when a blow lands, and how the island keeps it.
##
## Listens for `attack_landed` the way `HitFeedback` does, so nothing that throws a punch knows the
## game has blood in it. Each landed blow does three things — see `BloodData` for why three:
##
## 1. A `BloodSplash` is leased and thrown along the blow.
## 2. A handful of stains are chosen where the droplets come down: one at the victim's feet, the
##    rest thrown downstream. Each is found by casting down onto the world, so a stain lands on the
##    sand, on a rock or on nothing at all over the sea.
## 3. When the droplets have had time to fall, each stain is shown as a **decal**, sharp and fresh,
##    and stamped into the **island's mask**, where it stays. The decal fades after a while; by then
##    the ground's shader is drawing the same red out of the mask.
##
## **Nothing is built in the middle of a fight.** The decals are made once, in `_ready`, and
## recycled oldest first. The stamps the mask is painted with are pre-drawn at a few sizes and
## headings, so a blow costs a lookup and a native blend rather than a loop over pixels.
##
## **The mask is uploaded in batches.** An `ImageTexture` can only be sent whole, so a crowd's worth
## of blows in one frame is still one upload, at most every `mask_refresh` seconds. The decals carry
## the stain on screen in the meantime, so the delay is never seen.

const BLOOD: BloodData = preload("res://data/fx/blood.tres")
const GROUND_SHADER: Shader = preload("res://assets/shaders/terrain_blood.gdshader")
const STAIN_PATHS: PackedStringArray = [
	"res://assets/textures/fx/blood_stain_0.png",
	"res://assets/textures/fx/blood_stain_1.png",
	"res://assets/textures/fx/blood_stain_2.png",
	"res://assets/textures/fx/blood_stain_3.png",
	"res://assets/textures/fx/blood_stain_4.png",
	"res://assets/textures/fx/blood_stain_5.png",
]
## The widths, in mask pixels, a stamp is pre-drawn at. At 1024 pixels over 180 m a pool at the feet
## is five to nine pixels across and a fleck two to five; the nearest size is used.
const STAMP_SIZES: PackedInt32Array = [3, 5, 8, 12]
## How many headings a stamp is pre-drawn at. Eight is 45°, which a stain eighteen centimetres a
## pixel wide cannot show the difference from.
const STAMP_HEADINGS: int = 8
## The side of the square a stain is rotated in before it is shrunk to a stamp. Rotating at the
## final size would turn a three-pixel stamp into noise.
const STAMP_WORK_SIZE: int = 32
## How far above and below a landing point the ground is looked for.
const GROUND_SEARCH_UP: float = 4.0
const GROUND_SEARCH_DOWN: float = 8.0
## How tall a decal's box is, straddling the ground. Tall enough to wrap a bump in the sand and the
## top of a body already lying there; short enough not to paint the shins of whoever walks through.
const DECAL_HEIGHT: float = 0.6
## The share of its full width a stain starts at, before it spreads.
const SPREAD_FROM: float = 0.35

## What a landed blow is thrown as. A scene rather than a path, so the pool can key on it.
@export var splash_scene: PackedScene = null

var _rng := RandomNumberGenerator.new()
var _textures: Array[Texture2D] = []
var _stamps: Dictionary[Vector3i, Image] = {}
var _mask: Image = null
var _mask_texture: ImageTexture = null
var _mask_dirty: bool = false
var _since_upload: float = 0.0
var _decals: Array[Decal] = []
var _ages: PackedFloat32Array = []
var _widths: PackedFloat32Array = []
var _next_decal: int = 0
var _landings: Array[Landing] = []


## One stain waiting for its droplets to come down.
class Landing:
	var at: Vector3
	var heading: Vector3
	var width: float
	var stain: int
	var wait: float

	func _init(where: Vector3, towards: Vector3, across: float, which: int, delay: float) -> void:
		at = where
		heading = towards
		width = across
		stain = which
		wait = delay


func _ready() -> void:
	add_to_group(&"blood")
	_rng.randomize()
	for path: String in STAIN_PATHS:
		var texture := load(path) as Texture2D
		if texture != null:
			_textures.append(texture)
	_build_mask()
	_dress_the_ground()
	_draw_stamps()
	_make_decals()
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.corpse_struck.connect(_on_corpse_struck)


func _exit_tree() -> void:
	if EventBus.attack_landed.is_connected(_on_attack_landed):
		EventBus.attack_landed.disconnect(_on_attack_landed)
	if EventBus.corpse_struck.is_connected(_on_corpse_struck):
		EventBus.corpse_struck.disconnect(_on_corpse_struck)


func _process(delta: float) -> void:
	_bring_down(delta)
	_age(delta)
	_since_upload += delta
	if _mask_dirty and _since_upload >= BLOOD.mask_refresh:
		_upload()


## Spills blood at `feet` for a blow travelling along `direction`, and says how many stains found
## ground to land on. They are queued, not shown: they appear when the droplets would have landed.
func spill(feet: Vector3, direction: Vector3, perfect: bool) -> int:
	var queued := 0
	var heading := Vector3(direction.x, 0.0, direction.z)
	heading = heading.normalized() if not heading.is_zero_approx() else Vector3.FORWARD
	var side := Vector3(-heading.z, 0.0, heading.x)
	var count := BLOOD.perfect_stains if perfect else BLOOD.stains
	for index: int in count:
		var at := feet
		var width := 0.0
		if index == 0:
			at += heading * _rng.randf_range(0.0, 0.3)
			width = _rng.randf_range(BLOOD.pool_size.x, BLOOD.pool_size.y)
		else:
			var distance := _rng.randf_range(BLOOD.throw_distance.x, BLOOD.throw_distance.y)
			var stray := _rng.randf_range(-1.0, 1.0) * BLOOD.throw_scatter * distance
			at += heading * distance + side * stray
			width = _rng.randf_range(BLOOD.fleck_size.x, BLOOD.fleck_size.y)
		var ground := _ground_under(at)
		if is_nan(ground.y) or ground.y < BLOOD.dry_above:
			continue
		# The further a stain was thrown, the longer its droplets were in the air.
		var delay := BLOOD.land_delay * (1.0 + 0.6 * float(index) / float(maxi(count, 1)))
		var stain := _rng.randi_range(0, maxi(_textures.size() - 1, 0))
		_landings.append(Landing.new(ground, heading, width, stain, delay))
		queued += 1
	return queued


## Lands every queued stain now, and sends the mask. For the headless checks, which cannot sit
## through the droplets' flight for every blow.
func settle_now() -> void:
	for landing: Landing in _landings:
		_land(landing)
	_landings.clear()
	_upload()


## How soaked the ground is at a world position, from nought to one. Read off the mask, so it
## answers for every stain the island has ever had, including ones whose decals are long gone.
func soaked_at(where: Vector3) -> float:
	var pixel := _to_mask(where)
	if pixel.x < 0 or pixel.y < 0 or pixel.x >= _mask.get_width() or pixel.y >= _mask.get_height():
		return 0.0
	return _mask.get_pixel(pixel.x, pixel.y).a


## Stains currently drawn as decals.
func stains_showing() -> int:
	var showing := 0
	for decal: Decal in _decals:
		if decal.visible:
			showing += 1
	return showing


## How many decals exist at all. The check watches this: a fight must not add to it.
func decals_made() -> int:
	return _decals.size()


## Decals currently on the island, for a check that wants to know where they went.
func showing_decals() -> Array[Decal]:
	var showing: Array[Decal] = []
	for decal: Decal in _decals:
		if decal.visible:
			showing.append(decal)
	return showing


func _on_attack_landed(target: Node3D, _damage: float, perfect: bool, _attack: AttackData) -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree():
		return
	var feet := target.global_position
	_bleed(feet, feet + Vector3.UP * BLOOD.splash_height, _blow_direction(target), perfect)


## A corpse bleeds from where it lies, not from chest height: the body is on the sand.
func _on_corpse_struck(where: Vector3, direction: Vector3, perfect: bool) -> void:
	_bleed(where, where, direction, perfect)


func _bleed(feet: Vector3, wound: Vector3, direction: Vector3, perfect: bool) -> void:
	var pool := get_tree().get_first_node_in_group(&"effects") as EffectPool
	if pool != null and splash_scene != null:
		var splash := pool.lease(splash_scene) as BloodSplash
		if splash != null:
			splash.play(wound, direction, perfect, BLOOD)
	spill(feet, direction, perfect)


## Which way the blow travelled. An enemy remembers it; anything else is read as pushed away from
## the player, which is what every blow in the game is.
func _blow_direction(target: Node3D) -> Vector3:
	var enemy := target as Enemy
	if enemy != null:
		return enemy.last_hit_from
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null:
		return target.global_position - player.global_position
	return Vector3.FORWARD


func _bring_down(delta: float) -> void:
	var index := 0
	while index < _landings.size():
		var landing := _landings[index]
		landing.wait -= delta
		if landing.wait > 0.0:
			index += 1
			continue
		_land(landing)
		_landings.remove_at(index)


## The stain shown sharp, and kept for good.
func _land(landing: Landing) -> void:
	_stamp(landing)
	if _decals.is_empty():
		return
	# Oldest first: the one about to be taken has been in the mask for longest.
	var slot := _next_decal
	_next_decal = (_next_decal + 1) % _decals.size()
	var decal := _decals[slot]
	decal.global_position = landing.at
	# A stain is drawn spraying along its own +X, and a decal maps its texture's X onto its own.
	decal.global_basis = Basis(Vector3.UP, atan2(-landing.heading.z, landing.heading.x))
	if not _textures.is_empty():
		decal.texture_albedo = _textures[landing.stain % _textures.size()]
	decal.modulate = BLOOD.colour
	var start := landing.width * SPREAD_FROM
	decal.size = Vector3(start, DECAL_HEIGHT, start)
	decal.visible = true
	_ages[slot] = 0.0
	_widths[slot] = landing.width


## Spreads a fresh stain to its full size, and fades an old one into the mask under it.
func _age(delta: float) -> void:
	for slot: int in _decals.size():
		if _ages[slot] < 0.0:
			continue
		_ages[slot] += delta
		var decal := _decals[slot]
		var age := _ages[slot]
		var spread := clampf(age / maxf(BLOOD.spread_time, 0.001), 0.0, 1.0)
		var width := _widths[slot] * lerpf(SPREAD_FROM, 1.0, spread)
		decal.size = Vector3(width, DECAL_HEIGHT, width)
		if age <= BLOOD.decal_life:
			continue
		var fading := (age - BLOOD.decal_life) / maxf(BLOOD.decal_fade, 0.001)
		var colour := BLOOD.colour
		colour.a = clampf(1.0 - fading, 0.0, 1.0)
		decal.modulate = colour
		if fading >= 1.0:
			decal.visible = false
			_ages[slot] = -1.0


func _stamp(landing: Landing) -> void:
	if _mask == null or _stamps.is_empty():
		return
	var across := landing.width / BLOOD.mask_extent * float(BLOOD.mask_resolution)
	var size_index := 0
	for index: int in STAMP_SIZES.size():
		if absf(STAMP_SIZES[index] - across) < absf(STAMP_SIZES[size_index] - across):
			size_index = index
	# Mask X is world X and mask Y is world Z, so the heading's angle is measured from +X towards +Z.
	var angle := fposmod(atan2(landing.heading.z, landing.heading.x), TAU)
	var heading_index := int(round(angle / TAU * STAMP_HEADINGS)) % STAMP_HEADINGS
	var key := Vector3i(landing.stain % maxi(_textures.size(), 1), size_index, heading_index)
	var stamp := _stamps.get(key) as Image
	if stamp == null:
		return
	var corner := _to_mask(landing.at) - stamp.get_size() / 2
	_mask.blend_rect(stamp, Rect2i(Vector2i.ZERO, stamp.get_size()), corner)
	_mask_dirty = true


func _upload() -> void:
	if _mask_texture != null and _mask != null:
		_mask_texture.update(_mask)
	_mask_dirty = false
	_since_upload = 0.0


func _to_mask(where: Vector3) -> Vector2i:
	var origin := -BLOOD.mask_extent * 0.5
	var scale_to_pixels := float(BLOOD.mask_resolution) / BLOOD.mask_extent
	return Vector2i(
		int(floor((where.x - origin) * scale_to_pixels)),
		int(floor((where.z - origin) * scale_to_pixels))
	)


## The ground under a point, or a NAN height where there is none.
func _ground_under(at: Vector3) -> Vector3:
	var viewport := get_viewport()
	var space := viewport.world_3d.direct_space_state if viewport != null else null
	if space == null:
		return Vector3(at.x, NAN, at.z)
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * GROUND_SEARCH_UP,
		at + Vector3.DOWN * GROUND_SEARCH_DOWN,
		PhysicsLayers.BIT_WORLD
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return Vector3(at.x, NAN, at.z)
	return hit["position"]


func _build_mask() -> void:
	var side := maxi(BLOOD.mask_resolution, 1)
	_mask = Image.create(side, side, false, Image.FORMAT_RGBA8)
	_mask.fill(Color(1.0, 1.0, 1.0, 0.0))
	_mask_texture = ImageTexture.create_from_image(_mask)


## The island's ground, given the shader that reads the mask. Found by name under the arena rather
## than exported: a node export does not resolve in a hand-written scene (ADR 0006). The dry look is
## taken from the material it replaces, so the sand stays exactly the sand it was.
func _dress_the_ground() -> void:
	var host := get_parent()
	var terrain := (
		host.find_child("Terrain", true, false) as MeshInstance3D if host != null else null
	)
	if terrain == null:
		return
	var dry := 0.95
	var previous := terrain.material_override as StandardMaterial3D
	if previous != null:
		dry = previous.roughness
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter(&"blood_mask", _mask_texture)
	material.set_shader_parameter(&"blood_colour", BLOOD.colour)
	material.set_shader_parameter(&"mask_origin", Vector2.ONE * -BLOOD.mask_extent * 0.5)
	material.set_shader_parameter(&"mask_extent", BLOOD.mask_extent)
	material.set_shader_parameter(&"dry_roughness", dry)
	material.set_shader_parameter(&"wet_roughness", BLOOD.wet_roughness)
	terrain.material_override = material


## Every stain pre-drawn at every stamp size and heading, as white with the stain's coverage in
## alpha scaled by `mask_strength`.
func _draw_stamps() -> void:
	for stain: int in _textures.size():
		var source := _textures[stain].get_image()
		if source == null:
			continue
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		source.resize(STAMP_WORK_SIZE, STAMP_WORK_SIZE, Image.INTERPOLATE_BILINEAR)
		for heading: int in STAMP_HEADINGS:
			var turned := _turned(source, TAU * float(heading) / float(STAMP_HEADINGS))
			for size_index: int in STAMP_SIZES.size():
				var stamp := turned.duplicate() as Image
				var side := STAMP_SIZES[size_index]
				stamp.resize(side, side, Image.INTERPOLATE_BILINEAR)
				_stamps[Vector3i(stain, size_index, heading)] = stamp


## A square image turned by `angle` about its centre, from its +X towards its +Y.
func _turned(source: Image, angle: float) -> Image:
	var side := source.get_width()
	var turned := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var centre := Vector2(side, side) * 0.5
	var back := -angle
	for y: int in side:
		for x: int in side:
			var offset := Vector2(x + 0.5, y + 0.5) - centre
			var from := centre + offset.rotated(back)
			var sx := int(from.x)
			var sy := int(from.y)
			if sx < 0 or sy < 0 or sx >= side or sy >= side:
				continue
			var coverage := source.get_pixel(sx, sy).a * BLOOD.mask_strength
			turned.set_pixel(x, y, Color(1.0, 1.0, 1.0, coverage))
	return turned


func _make_decals() -> void:
	for index: int in maxi(BLOOD.decal_count, 0):
		var decal := Decal.new()
		decal.name = "Stain%d" % index
		decal.visible = false
		decal.size = Vector3(1.0, DECAL_HEIGHT, 1.0)
		decal.modulate = BLOOD.colour
		# Faded at the top and bottom of its box, and on anything too steep to have caught a drop, so
		# a stain that lands against a boulder wraps its foot rather than running up its face.
		decal.upper_fade = 0.3
		decal.lower_fade = 0.3
		decal.normal_fade = 0.5
		if not _textures.is_empty():
			decal.texture_albedo = _textures[index % _textures.size()]
		add_child(decal)
		_decals.append(decal)
	_ages.resize(_decals.size())
	_ages.fill(-1.0)
	_widths.resize(_decals.size())
	_widths.fill(0.0)
