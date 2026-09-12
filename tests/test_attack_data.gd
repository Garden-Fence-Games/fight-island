extends GdUnitTestSuite
## Attack window arithmetic, and one property every attack that ships has to satisfy.

const ATTACKS: String = "res://data/attacks"


func test_a_zero_width_chain_window_is_a_finisher() -> void:
	var attack := AttackData.new()
	attack.chain_window = Vector2(0.45, 0.45)
	assert_bool(attack.is_finisher()).is_true()
	attack.chain_window = Vector2(0.10, 0.45)
	assert_bool(attack.is_finisher()).is_false()


func test_an_attack_lasts_its_three_phases() -> void:
	var attack := AttackData.new()
	attack.windup = 0.2
	attack.active = 0.08
	attack.recovery = 0.34
	assert_float(attack.total_duration()).is_equal_approx(0.62, 0.0001)


## The perfect window is *the last slice of* the chain window. One that started before the chain
## opened, or ran past where it closes, would be partly unreachable — the player would be pressing
## inside a window the chain has already refused. Nothing in a diff shows that; a `.tres` simply
## stops rewarding the timing it advertises.
func test_every_shipped_perfect_window_is_the_tail_of_its_chain() -> void:
	var attacks := _shipped_attacks()
	assert_array(attacks).is_not_empty()
	for attack: AttackData in attacks:
		if attack.is_finisher():
			continue
		assert_float(attack.perfect_window.x).is_greater_equal(attack.chain_window.x)
		assert_float(attack.perfect_window.y).is_less_equal(attack.chain_window.y)
		assert_float(attack.perfect_window.y).is_greater(attack.perfect_window.x)


## A perfect hit has to be worth reaching for. One that paid the same as a normal one would make the
## whole timing system decorative.
func test_every_shipped_attack_pays_for_perfect_timing() -> void:
	for attack: AttackData in _shipped_attacks():
		assert_float(attack.perfect_multiplier).is_greater(1.0)


## The money bonus is for finishing a combo, and the only attack that can finish one is a finisher.
## Put on anything else it would pay for a swing the player reaches without chaining at all, which
## is the whole thing the bonus buys. A `.tres` cannot state that rule about itself.
func test_only_a_finisher_is_worth_extra_money() -> void:
	var attacks := _shipped_attacks()
	assert_array(attacks).is_not_empty()
	var paid := 0
	for attack: AttackData in attacks:
		assert_float(attack.money_multiplier).is_greater_equal(1.0)
		if attack.money_multiplier > 1.0:
			assert_bool(attack.is_finisher()).is_true()
			paid += 1
	# An enemy's swing is an AttackData too and pays nothing, so this also catches a bonus landing on
	# the farmhand rather than on the fists.
	assert_int(paid).is_greater(0)


func _shipped_attacks() -> Array[AttackData]:
	var out: Array[AttackData] = []
	for name: String in DirAccess.get_files_at(ATTACKS):
		var path := "%s/%s" % [ATTACKS, name.trim_suffix(".remap")]
		var attack := load(path) as AttackData
		if attack != null:
			out.append(attack)
	return out
