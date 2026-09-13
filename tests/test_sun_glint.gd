extends GdUnitTestSuite
## The two questions the flare asks every frame, answered without a screen: is it midday, and does
## this bottle throw the sun into the camera.

var _look: SunGlintData = preload("res://data/fx/sun_glint.tres")


func test_the_flare_belongs_to_midday() -> void:
	assert_float(SunGlint.noon_weight(_look.noon_hour, _look)).is_equal_approx(1.0, 0.001)
	assert_float(SunGlint.noon_weight(_look.noon_hour + _look.noon_reach + 0.1, _look)).is_equal(
		0.0
	)
	assert_float(SunGlint.noon_weight(3.0, _look)).is_equal(0.0)


func test_a_face_that_mirrors_the_sun_into_the_camera_flares_fully() -> void:
	# The sun high in one direction, the camera high in the opposite: a flat face mirrors one into
	# the other exactly.
	var to_sun := Vector3(1.0, 1.0, 0.0).normalized()
	var to_camera := Vector3(-1.0, 1.0, 0.0).normalized()
	assert_float(SunGlint.glint(to_sun, to_camera, Vector3.UP, _look.sharpness)).is_equal_approx(
		1.0, 0.001
	)


func test_a_face_turned_away_barely_glints() -> void:
	var to_sun := Vector3(1.0, 1.0, 0.0).normalized()
	var to_camera := Vector3(1.0, 1.0, 0.0).normalized()
	assert_float(SunGlint.glint(to_sun, to_camera, Vector3.UP, _look.sharpness)).is_less(0.01)


func test_no_sun_no_glint() -> void:
	var below := Vector3(0.0, -1.0, 0.0)
	assert_float(SunGlint.glint(below, Vector3.UP, Vector3.UP, _look.sharpness)).is_equal(0.0)
