extends GdUnitTestSuite
## How the wave curves behave, not what they are worth. `tools/verify_waves.tscn` owns the table and
## checks it against `docs/game-design.md`; these are the properties that have to hold whatever
## anybody tunes it to.

const SHIPPED: String = "res://data/waves/standard.tres"
## Far past the fifteen a run lasts. Endless mode will ask for these, and a ceiling that only holds
## inside the shipped range is a ceiling that does not hold.
const FAR_PAST_THE_END: int = 200


func test_wave_one_scales_nothing() -> void:
	# Every curve is written as "1.0 plus growth times (n - 1)", so wave one is the identity. A curve
	# that starts anywhere else quietly rebalances the wave the player meets first.
	var config := WaveConfig.new()
	assert_float(config.health_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(config.damage_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(config.speed_multiplier(1)).is_equal_approx(1.0, 0.0001)
	assert_float(config.windup_multiplier(1)).is_equal_approx(1.0, 0.0001)


## The crowd is the difficulty, not the body: no wave, however far, makes a body tougher.
func test_health_never_grows() -> void:
	var config := WaveConfig.new()
	for wave: int in range(1, FAR_PAST_THE_END):
		assert_float(config.health_multiplier(wave)).is_equal_approx(1.0, 0.0001)


func test_a_later_wave_is_never_a_smaller_one() -> void:
	var config := WaveConfig.new()
	for wave: int in range(2, FAR_PAST_THE_END):
		assert_int(config.enemy_count(wave)).is_greater_equal(config.enemy_count(wave - 1))
		assert_int(config.max_alive(wave)).is_greater_equal(config.max_alive(wave - 1))


func test_the_crowd_stays_between_its_floor_and_its_ceiling() -> void:
	var config := WaveConfig.new()
	for wave: int in range(1, FAR_PAST_THE_END):
		assert_int(config.max_alive(wave)).is_between(config.fewest_alive, config.most_alive)


func test_speed_stops_at_its_ceiling_and_the_telegraph_at_its_floor() -> void:
	var config := WaveConfig.new()
	for wave: int in range(1, FAR_PAST_THE_END):
		assert_float(config.speed_multiplier(wave)).is_less_equal(config.speed_ceiling)
		assert_float(config.windup_multiplier(wave)).is_greater_equal(config.windup_floor)


## The composition rule that is easy to get backwards and reads identically either way in a diff.
## Scaling the wind-up and *then* clamping is what keeps night from making a telegraph unreadable;
## clamping first and scaling second puts it under the floor and nothing says so.
func test_no_phase_can_push_the_telegraph_under_its_floor() -> void:
	var config := WaveConfig.new()
	var phase := DayPhase.new()
	for scale: float in [1.0, 0.88, 0.5, 0.01]:
		phase.windup_scale = scale
		for wave: int in range(1, FAR_PAST_THE_END):
			assert_float(config.windup_multiplier(wave, phase)).is_greater_equal(
				config.windup_floor
			)


func test_a_phase_multiplies_the_damage_the_wave_already_asked_for() -> void:
	var config := WaveConfig.new()
	var phase := DayPhase.new()
	phase.damage_scale = 1.25
	for wave: int in [1, 5, 15]:
		var wanted := config.damage_multiplier(wave) * 1.25
		assert_float(config.damage_multiplier(wave, phase)).is_equal_approx(wanted, 0.0001)


## A null phase is how an arena with no day cycle runs — the tutorial, and every headless check that
## does not care what time it is. It has to read exactly as the bare wave curve.
func test_no_phase_at_all_leaves_the_curve_alone() -> void:
	var config := WaveConfig.new()
	for wave: int in [1, 9, 15]:
		assert_float(config.damage_multiplier(wave, null)).is_equal_approx(
			config.damage_multiplier(wave), 0.0001
		)
		assert_float(config.windup_multiplier(wave, null)).is_equal_approx(
			config.windup_multiplier(wave), 0.0001
		)


func test_elites_start_on_their_wave_and_stop_at_their_ceiling() -> void:
	var config := WaveConfig.new()
	for wave: int in range(1, config.elite_first_wave):
		assert_float(config.elite_chance(wave)).is_equal_approx(0.0, 0.0001)
	assert_float(config.elite_chance(config.elite_first_wave)).is_equal_approx(
		config.elite_base_chance, 0.0001
	)
	for wave: int in range(1, FAR_PAST_THE_END):
		assert_float(config.elite_chance(wave)).is_less_equal(config.elite_chance_ceiling)


func test_a_flawless_wave_pays_its_bonus_and_nothing_else() -> void:
	var config := WaveConfig.new()
	for wave: int in [1, 7, 15]:
		var plain := config.reward_for(wave, false)
		var wanted := int(roundf(float(plain) * (1.0 + config.flawless_bonus)))
		assert_int(config.reward_for(wave, true)).is_equal(wanted)


## The band in force is the last one that has started, whatever order they sit in the array.
func test_the_band_is_the_last_one_that_has_started() -> void:
	var config := WaveConfig.new()
	config.bands = [_band(8), _band(1), _band(3)]
	assert_int(config.band_for(1).first_wave).is_equal(1)
	assert_int(config.band_for(2).first_wave).is_equal(1)
	assert_int(config.band_for(3).first_wave).is_equal(3)
	assert_int(config.band_for(7).first_wave).is_equal(3)
	assert_int(config.band_for(40).first_wave).is_equal(8)


func test_no_band_has_started_before_the_first_one() -> void:
	var config := WaveConfig.new()
	config.bands = [_band(4)]
	assert_object(config.band_for(3)).is_null()


## The shipped table has to answer for every wave a run can reach, or a late wave sends nobody.
func test_the_shipped_table_has_a_band_for_every_wave() -> void:
	var config := load(SHIPPED) as WaveConfig
	assert_object(config).is_not_null()
	for wave: int in range(1, 16):
		assert_object(config.band_for(wave)).is_not_null()


func _band(first_wave: int) -> WaveBand:
	var band := WaveBand.new()
	band.first_wave = first_wave
	return band
