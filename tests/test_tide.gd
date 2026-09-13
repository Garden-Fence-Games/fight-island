extends GdUnitTestSuite
## What insisting against the sea costs, and how long going under takes, answered without an island.

var _tide: TideData = preload("res://data/combat/tide.tres")


func test_not_forcing_leaves_the_drain_alone() -> void:
	assert_float(_tide.forcing_multiplier(0.0)).is_equal(1.0)


func test_forcing_doubles_the_drain_on_its_interval() -> void:
	var once := _tide.forcing_multiplier(_tide.forcing_doubles_every)
	var twice := _tide.forcing_multiplier(_tide.forcing_doubles_every * 2.0)
	assert_float(once).is_equal_approx(2.0, 0.001)
	assert_float(twice).is_equal_approx(4.0, 0.001)


func test_forcing_grows_faster_the_longer_it_lasts() -> void:
	# An exponential, not a ramp: each interval adds more than the one before it.
	var step := _tide.forcing_doubles_every
	var first_gain := _tide.forcing_multiplier(step) - _tide.forcing_multiplier(0.0)
	var second_gain := _tide.forcing_multiplier(step * 2.0) - _tide.forcing_multiplier(step)
	assert_float(second_gain).is_greater(first_gain)


func test_forcing_stops_at_its_cap() -> void:
	assert_float(_tide.forcing_multiplier(600.0)).is_equal_approx(_tide.forcing_cap, 0.001)


func test_going_under_takes_depth_over_speed() -> void:
	assert_float(_tide.sink_seconds()).is_equal_approx(_tide.sink_depth / _tide.sink_speed, 0.001)
