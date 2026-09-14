extends GdUnitTestSuite
## The cost curve. Properties rather than the five numbers — `tools/verify_waves.tscn` already
## asserts those against the design document, and a second copy of a table is a second thing to
## keep in step.


func test_a_price_lands_on_a_five() -> void:
	# Money is read at a glance in the middle of a fight, which is the whole reason for the
	# rounding. A price of 132 would be legible only to someone counting.
	for owned: int in Economy.LEVEL_CAP:
		assert_int(Economy.upgrade_cost(owned) % Economy.ROUNDING).is_equal(0)


func test_every_level_costs_more_than_the_last() -> void:
	for owned: int in range(1, Economy.LEVEL_CAP):
		assert_int(Economy.upgrade_cost(owned)).is_greater(Economy.upgrade_cost(owned - 1))


## A track that is already full is not for sale, and neither is a negative one. Nought is the answer
## rather than a refusal, so a merchant asking the price of something it cannot sell gets a figure
## no wallet will ever pay.
func test_a_full_track_is_not_for_sale() -> void:
	assert_int(Economy.upgrade_cost(Economy.LEVEL_CAP)).is_equal(0)
	assert_int(Economy.upgrade_cost(Economy.LEVEL_CAP + 40)).is_equal(0)
	assert_int(Economy.upgrade_cost(-1)).is_equal(0)


## One purchase after waves one to three, two after four to six, and one more every three waves on.
func test_the_merchant_sells_one_more_every_three_waves() -> void:
	for pair: Array in [[1, 1], [3, 1], [4, 2], [6, 2], [7, 3], [15, 5], [16, 6]]:
		assert_int(Economy.purchases_after(pair[0])).is_equal(pair[1])


func test_a_track_costs_what_its_levels_cost() -> void:
	var summed := 0
	for owned: int in Economy.LEVEL_CAP:
		summed += Economy.upgrade_cost(owned)
	assert_int(Economy.track_cost()).is_equal(summed)
