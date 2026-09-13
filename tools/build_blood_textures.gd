extends SceneTree
## Draws the blood stains and writes them to `assets/textures/fx/`.
##
## **Generated rather than downloaded or painted**, for now: every stain is reproducible from a
## seed, owned outright, and replaceable file for file — a painted set dropped in under the same
## names changes nothing else in the game.
##
## White with an alpha, never red. The colour is `BloodData.colour`, applied in the decal and in the
## ground shader, so the red can be pushed or calmed without redrawing anything.
##
## **Every stain is drawn travelling along +X.** The pool sits left of centre and the spray fans out
## towards the right-hand edge, which is the direction `BloodField` turns to face the blow. A stain
## drawn any other way would spray back towards whoever threw the punch.
##
## What makes it read as blood rather than as a red blob is the spray, not the pool: droplets fanned
## in a cone, each stretched along its own line of flight and thinner the further it went, and
## fingers reaching out of the pool the same way.
##
## Run: godot --headless --path . --script tools/build_blood_textures.gd

const OUT_DIR: String = "res://assets/textures/fx"
const COUNT: int = 6
const SIZE: int = 256
const SEED: int = 20260913
## Where the pool sits. Left of centre, so the spray has most of the image to travel across.
const POOL_CENTRE: Vector2 = Vector2(0.36, 0.5)
## Half-angle of the spray cone, in degrees, around +X.
const CONE: float = 38.0

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_rng.seed = SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.fractal_octaves = 3
	for index: int in COUNT:
		_noise.seed = SEED + index * 17
		var image := _stain()
		var path := "%s/blood_stain_%d.png" % [OUT_DIR, index]
		var error := image.save_png(ProjectSettings.globalize_path(path))
		print("%s %s" % [path, "written" if error == OK else "FAILED (%d)" % error])
	quit()


func _stain() -> Image:
	var cover := PackedFloat32Array()
	cover.resize(SIZE * SIZE)
	var centre := POOL_CENTRE * SIZE
	var pool := _rng.randf_range(0.15, 0.21) * SIZE
	_draw_pool(cover, centre, pool)

	# Fingers: short thick streaks leaving the pool downstream, the way a splash drags its edge.
	for _finger: int in _rng.randi_range(2, 5):
		var angle := deg_to_rad(_rng.randf_range(-CONE, CONE) * 1.2)
		var along := Vector2(cos(angle), sin(angle))
		var start := centre + along * pool * _rng.randf_range(0.7, 0.95)
		var length := pool * _rng.randf_range(0.6, 1.3)
		_draw_drop(cover, start + along * length * 0.5, length * 0.5, pool * 0.14, angle)

	# The spray: many droplets in a cone, smaller and longer the further they flew.
	for _drop: int in _rng.randi_range(25, 45):
		var angle := deg_to_rad(_rng.randfn(0.0, CONE * 0.55))
		var flight := _rng.randf_range(1.15, 1.0 / POOL_CENTRE.x * 0.6)
		var distance := pool * flight + _rng.randf() * (SIZE * 0.62 - pool * flight)
		var reach := clampf(distance / (SIZE * 0.62), 0.0, 1.0)
		var along := Vector2(cos(angle), sin(angle))
		var width := lerpf(0.035, 0.007, reach) * SIZE * _rng.randf_range(0.6, 1.4)
		var stretch := lerpf(1.2, 4.0, reach) * _rng.randf_range(0.8, 1.3)
		var at := centre + along * distance
		# A drop that would run off the image is left out: the decal would draw it cut dead straight.
		if not _fits(at, along * width * stretch, width):
			continue
		_draw_drop(cover, at, width * stretch, width, angle)

	# Specks all round: blood does not land only where it was aimed.
	for _speck: int in _rng.randi_range(5, 10):
		var angle := _rng.randf_range(0.0, TAU)
		var at := centre + Vector2(cos(angle), sin(angle)) * pool * _rng.randf_range(1.3, 2.1)
		var radius := _rng.randf_range(0.006, 0.016) * SIZE
		_draw_drop(cover, at, radius, radius, 0.0)

	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for y: int in SIZE:
		for x: int in SIZE:
			var alpha := cover[y * SIZE + x]
			if alpha <= 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.0))
				continue
			# Not a flat fill: a little thinner here and there, so the island's red has a grain.
			var grain := 0.88 + 0.12 * (_noise.get_noise_2d(x * 3.0, y * 3.0) * 0.5 + 0.5)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * grain))
	return image


## The pool: a disc whose edge is pushed in and out by noise, harder than a drop's.
func _draw_pool(cover: PackedFloat32Array, centre: Vector2, radius: float) -> void:
	var reach := int(ceil(radius * 1.5))
	for y: int in range(maxi(int(centre.y) - reach, 0), mini(int(centre.y) + reach, SIZE)):
		for x: int in range(maxi(int(centre.x) - reach, 0), mini(int(centre.x) + reach, SIZE)):
			var offset := Vector2(x + 0.5, y + 0.5) - centre
			var angle := atan2(offset.y, offset.x)
			var lumpy := _noise.get_noise_2d(cos(angle) * 90.0, sin(angle) * 90.0)
			var edge := radius * (1.0 + 0.38 * lumpy)
			_cover(cover, x, y, (edge - offset.length()) / 1.5 + 0.5)


## One droplet: an ellipse `length` along its line of flight and `width` across, feathered by a
## pixel so its edge is soft at whatever size the decal draws it.
func _draw_drop(
	cover: PackedFloat32Array, centre: Vector2, length: float, width: float, angle: float
) -> void:
	var reach := int(ceil(maxf(length, width) + 2.0))
	var along := Vector2(cos(angle), sin(angle))
	var across := Vector2(-along.y, along.x)
	for y: int in range(maxi(int(centre.y) - reach, 0), mini(int(centre.y) + reach, SIZE)):
		for x: int in range(maxi(int(centre.x) - reach, 0), mini(int(centre.x) + reach, SIZE)):
			var offset := Vector2(x + 0.5, y + 0.5) - centre
			var u := offset.dot(along) / maxf(length, 0.5)
			var v := offset.dot(across) / maxf(width, 0.5)
			var inside := sqrt(u * u + v * v)
			var feather := 1.5 / maxf(width, 0.5)
			_cover(cover, x, y, (1.0 - inside) / feather + 0.5)


## Whether a drop centred at `at`, reaching `half_length` either way along its flight and `width`
## across, stays clear of the image's edge by a few pixels.
func _fits(at: Vector2, half_length: Vector2, width: float) -> bool:
	var margin := 4.0 + width
	for tip: Vector2 in [at + half_length, at - half_length]:
		if tip.x < margin or tip.y < margin or tip.x > SIZE - margin or tip.y > SIZE - margin:
			return false
	return true


func _cover(cover: PackedFloat32Array, x: int, y: int, amount: float) -> void:
	var index := y * SIZE + x
	cover[index] = maxf(cover[index], clampf(amount, 0.0, 1.0))
