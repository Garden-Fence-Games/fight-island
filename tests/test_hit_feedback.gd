extends GdUnitTestSuite
## The two colours `HitFeedback` multiplies a body by, judged the way an eye judges them.
##
## These are not decoration. `albedo_color` multiplies the texture underneath, so a value picked
## against a white capsule means something entirely different once the capsule is a textured rig —
## which is exactly how the third punch of every combo came to turn the player black. Nothing in a
## diff shows that, and no scene check catches a colour that is merely too dark to be a character.

## Rec. 709, the same weighting the elite and farmer checks use: legibility is one question and it
## gets one answer everywhere in this project.
const RED: float = 0.2126
const GREEN: float = 0.7152
const BLUE: float = 0.0722

## Below this the body stops being a man and becomes a hole in the scene. It is a floor on the
## *multiplier*, so it holds whatever the rig's own texture turns out to be: a body cannot come out
## darker than this fraction of however dark it already was.
const STILL_A_BODY: float = 0.45
## Above this nothing happened. A drain the player cannot see is a lockout they cannot see, and the
## whole reason the signal pair exists is that an invisible wait reads as a dropped input.
const VISIBLY_DRAINED: float = 0.80


func test_a_spent_body_is_dulled_and_not_blacked_out() -> void:
	var luma := _luma(HitFeedback.SPENT_COLOR)
	assert_float(luma).is_greater(STILL_A_BODY)
	assert_float(luma).is_less(VISIBLY_DRAINED)


## Drained, not recoloured. The player reads "spent" off it without having to learn what a colour
## means, so no channel may be lifted above where it started — a spent body that went *blue* would
## be a new thing to learn rather than the same thing with the life taken out of it.
func test_a_spent_body_is_never_brighter_than_it_was() -> void:
	var spent := HitFeedback.SPENT_COLOR
	for channel: float in [spent.r, spent.g, spent.b]:
		assert_float(channel).is_less_equal(1.0)


## The flash and the drain have to go opposite ways, or the two readings collapse into one. The
## flash is emissive and additive; the drain multiplies down. This pins the pair rather than either
## one alone, because it is the contrast between them that carries the meaning.
func test_the_damage_flash_reads_the_other_way_from_the_drain() -> void:
	assert_float(_luma(HitFeedback.PERFECT_COLOR)).is_greater(_luma(HitFeedback.SPENT_COLOR))
	assert_float(_luma(HitFeedback.NORMAL_COLOR)).is_greater(_luma(HitFeedback.SPENT_COLOR))


## The drain arrives faster than it leaves. Spending has to register at once; coming back is allowed
## to be gentle, because nothing depends on the player noticing the exact frame the weapon is ready.
func test_the_drain_lands_faster_than_it_lifts() -> void:
	assert_float(HitFeedback.SPENT_FADE).is_less(HitFeedback.READY_FADE)


func _luma(colour: Color) -> float:
	return RED * colour.r + GREEN * colour.g + BLUE * colour.b
