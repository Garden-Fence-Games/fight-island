class_name SunGlint
extends CanvasLayer
## The midday sun catching the bottles by the spawn, and the flare it throws across the screen.
##
## **One glint at a time, and the right one.** Every bottle is given its own glinting face, pointing
## somewhere near straight up; each frame the one whose face best mirrors the sun into the camera is
## the one that flares, as strongly as it lines up. As the player walks the angles change, so
## different bottles catch and let go — which is what glass in grass does, and what a fixed flare
## sprite never could.
##
## **Only around midday**, fading in and out over the hours either side of it, and **never with
## reduced flashing on**: a bright burst swinging across the screen is exactly what that setting
## is for.
##
## Drawn over the 3D and under the HUD, additively, from gradients built here — no texture to ship.

const BOTTLES_AT: NodePath = ^"../Island/Props/Bottles"
const SUN_AT: NodePath = ^"../Sky/Sun"
## Twelve floats an instance, as `IslandScatter` packs them.
const STRIDE: int = 12
## Where the ghosts sit along the line from the glint through the screen's centre, as a share of it,
## and how big each is against the burst. Negative is past the centre, on the far side.
const GHOSTS: Array[Vector2] = [
	Vector2(0.55, 0.12), Vector2(1.2, 0.2), Vector2(1.6, 0.08), Vector2(2.1, 0.3)
]
const GHOST_TINTS: Array[Color] = [
	Color(1.0, 0.85, 0.5, 0.6),
	Color(0.55, 0.9, 1.0, 0.45),
	Color(1.0, 0.6, 0.9, 0.5),
	Color(0.7, 1.0, 0.7, 0.3),
]

var look: SunGlintData = preload("res://data/fx/sun_glint.tres")

var _bottles: PackedVector3Array = PackedVector3Array()
var _facets: PackedVector3Array = PackedVector3Array()
var _sun: DirectionalLight3D = null
var _burst: TextureRect = null
var _streak: TextureRect = null
var _ghosts: Array[TextureRect] = []
var _strength: float = 0.0
var _at: Vector2 = Vector2.ZERO


## How much of midday it is, nought to one, at `hour`.
static func noon_weight(hour: float, data: SunGlintData) -> float:
	var away := absf(hour - data.noon_hour)
	return 1.0 - smoothstep(0.0, maxf(data.noon_reach, 0.001), away)


## How strongly a face with normal `facet` mirrors the sun at `to_sun` into a camera at `to_camera`,
## nought to one. All three are unit vectors pointing away from the glass.
static func glint(to_sun: Vector3, to_camera: Vector3, facet: Vector3, sharpness: float) -> float:
	if to_sun.y <= 0.0 or facet.dot(to_sun) <= 0.0:
		return 0.0
	var mirrored := to_sun.reflect(facet)
	return pow(maxf(mirrored.dot(to_camera), 0.0), sharpness)


func _ready() -> void:
	layer = 0
	_sun = get_node_or_null(SUN_AT) as DirectionalLight3D
	_read_the_bottles()
	_build_the_flare()
	_show(0.0)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	var wanted := 0.0
	var best := Vector3.ZERO
	var weight := noon_weight(GameState.hour, look)
	if bool(Settings.get_value(&"access_reduce_flashing")):
		weight = 0.0
	if weight > 0.0 and camera != null and _sun != null and not _bottles.is_empty():
		var to_sun := _sun.global_basis.z.normalized()
		for index: int in _bottles.size():
			var bottle := _bottles[index]
			if not camera.is_position_in_frustum(bottle):
				continue
			var to_camera := (camera.global_position - bottle).normalized()
			var caught := glint(to_sun, to_camera, _facets[index], look.sharpness)
			if caught > wanted:
				wanted = caught
				best = bottle
		wanted *= weight
		if wanted > 0.0:
			_at = camera.unproject_position(best)
	_strength = move_toward(_strength, wanted, look.response * delta)
	_show(_strength)


func _read_the_bottles() -> void:
	var population := get_node_or_null(BOTTLES_AT)
	if population == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260913
	for child: Node in population.get_children():
		var batch := child as MultiMeshInstance3D
		if batch == null or batch.multimesh == null:
			continue
		var raw := batch.multimesh.buffer
		for index: int in batch.multimesh.instance_count:
			var at := index * STRIDE
			if at + STRIDE > raw.size():
				break
			# A little up the bottle, by its own size: the glass, not the sand under it.
			var up := Vector3(raw[at + 1], raw[at + 5], raw[at + 9]).length()
			var local := Vector3(raw[at + 3], raw[at + 7] + 0.08 * up, raw[at + 11])
			_bottles.append(batch.global_transform * local)
			var tilt := rng.randf() * look.facet_spread
			var bearing := rng.randf_range(0.0, TAU)
			_facets.append(Vector3(cos(bearing) * tilt, 1.0, sin(bearing) * tilt).normalized())


func _build_the_flare() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_burst = _sprite(_radial(Color(1.0, 0.97, 0.85, 1.0), 0.0), additive)
	_streak = _sprite(_radial(Color(1.0, 0.95, 0.8, 0.9), 0.0), additive)
	for index: int in GHOSTS.size():
		_ghosts.append(_sprite(_radial(GHOST_TINTS[index], 0.55), additive))


func _sprite(texture: Texture2D, blend: Material) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.material = blend
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## A soft disc fading to nothing at its rim, or a ring when `hollow` is above nought.
func _radial(tint: Color, hollow: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	var clear := Color(tint, 0.0)
	if hollow > 0.0:
		gradient.offsets = PackedFloat32Array([0.0, hollow, 0.8, 1.0])
		gradient.colors = PackedColorArray([Color(tint, tint.a * 0.15), tint, clear, clear])
	else:
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		gradient.colors = PackedColorArray([tint, Color(tint, tint.a * 0.35), clear])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture


func _show(amount: float) -> void:
	var visible_now := amount > 0.002
	for rect: TextureRect in [_burst, _streak] + _ghosts:
		rect.visible = visible_now
	if not visible_now:
		return
	var screen := get_viewport().get_visible_rect().size
	var burst := screen.y * look.burst_size * (0.4 + 0.6 * amount)
	var glow := clampf(amount * look.strength, 0.0, 1.0)
	_place(_burst, _at, Vector2(burst, burst), glow)
	_place(_streak, _at, Vector2(burst * 3.2, burst * 0.12), glow)
	var centre := screen * 0.5
	for index: int in _ghosts.size():
		var along := GHOSTS[index]
		var at := _at + (centre - _at) * along.x
		var size := burst * along.y * 1.6
		_place(_ghosts[index], at, Vector2(size, size), glow)


func _place(rect: TextureRect, centre: Vector2, size: Vector2, glow: float) -> void:
	rect.size = size
	rect.position = centre - size * 0.5
	rect.modulate = Color(1.0, 1.0, 1.0, glow)
