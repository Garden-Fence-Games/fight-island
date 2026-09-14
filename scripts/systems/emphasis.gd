class_name Emphasis
extends RefCounted
## How loud each thing that happens in a fight is allowed to be, in one table.
##
## Every one of these effects is individually an improvement and collectively a mess. A hit that
## stops time, shakes the screen, flashes the body and kicks the camera is not four times as
## satisfying — it is unreadable, and reading a fight is the whole subject. So the emphasis on a
## blow is **decided here and spent once**, rather than accumulated by whoever happens to be
## emitting at the time.
##
## Three rules hold it together:
##
## **One blow, one spend.** A perfect finisher that kills is one event, not three. `for_hit` takes
## the loudest figure on each channel rather than the sum, so what decides is the most emphatic
## thing that happened and nothing can stack its way past the ceiling.
##
## **There is a ceiling**, and it is in frames because that is the unit a stop is felt in. A figure
## in seconds quietly becomes a different number of frames the day anything else moves.
##
## **A stop never eats a press.** The input buffer ages on the same scaled clock the stop slows, so
## a hitstop lengthens the buffer in real time rather than spending it. `verify_feel` holds that,
## because it is the one property here a player would be right to blame the game for.
##
## What is *not* here is how long each attack stops for. That is per-attack content — a charged
## shot at 0.18 s and a pistol crack at 0.06 s are saying something true about their own weight —
## and it lives in the `.tres` beside the damage. This table decides which events spend on which
## channel, how two of them combine, and how far any of it may go.
##
## The accessibility settings are the ceiling above this one and not a suggestion: `CameraRig`
## scales every shake by the slider and `HitFeedback` refuses every stop when the toggle is off, so
## nothing here has to remember them.

## Sixty, because that is the rate the fight is designed at. A machine running faster stops for the
## same length of time, not for the same number of its own frames.
const FRAME: float = 1.0 / 60.0
## The most any single blow may stop the clock for, whatever combination produced it. Twelve frames
## is a fifth of a second — past that a stop stops reading as emphasis and starts reading as the
## game hitching. The heaviest attack in the game asks for eleven, so the ceiling is real without
## already biting.
const MOST_FRAMES: int = 12
## A body leaving the fight. Small, and the one place a shake costs nothing — whatever might have
## been telegraphing on that spot is the thing that just died.
const KILL_FRAMES: int = 3
const KILL_SHAKE: float = 0.3
## The end of a committed chain, and the most expensive thing the player can choose to do. Camera
## rather than clock: a second stop inside a chain reads as a hitch, not as weight.
const FINISHER_SHAKE: float = 0.6
## The single most skilful input in the game, and **the only thing that spends the whole budget**.
## It was six frames and the charged shot was eleven, so the longest stop in the game belonged to a
## held trigger rather than to the hardest input in it — `verify_feel` found that the day the table
## was written. Nothing else may draw level, which the same check holds.
const PARRY_FRAMES: int = MOST_FRAMES
## Taking a hit. The loudest thing that happens to the player and the only one they did not choose.
## All camera and no clock: a stop here would take away the moment they need to recover in.
const HURT_SHAKE: float = 1.0


## One blow's whole emphasis. `stop` is the attack's own figure, spent only on a perfect hit; the
## rest is this table. Three things can be true of the same blow and it is still one blow.
##
## An ordinary hit comes back at nothing at all, and that is a decision rather than an omission: it
## happens dozens of times a wave, the flash on the body already says it landed, and marking it
## would cost every mark that matters.
static func for_hit(perfect: bool, finisher: bool, killed: bool, stop: float) -> Dictionary:
	var seconds := stop if perfect else 0.0
	var shake := 0.0
	if finisher:
		shake = maxf(shake, FINISHER_SHAKE)
	if killed:
		seconds = maxf(seconds, float(KILL_FRAMES) * FRAME)
		shake = maxf(shake, KILL_SHAKE)
	return {"seconds": minf(seconds, float(MOST_FRAMES) * FRAME), "shake": shake}


static func for_parry() -> Dictionary:
	return {"seconds": float(PARRY_FRAMES) * FRAME, "shake": 0.0}


static func for_hurt() -> Dictionary:
	return {"seconds": 0.0, "shake": HURT_SHAKE}


## Puts it on the bus. The one place that turns this table into signals, so a new emitter cannot
## invent a figure of its own without coming through here.
static func spend(emphasis: Dictionary) -> void:
	var seconds := float(emphasis.get("seconds", 0.0))
	if seconds > 0.0:
		EventBus.hitstop_requested.emit(seconds)
	var shake := float(emphasis.get("shake", 0.0))
	if shake > 0.0:
		EventBus.shake_requested.emit(shake)
