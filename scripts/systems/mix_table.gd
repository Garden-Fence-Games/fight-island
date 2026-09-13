class_name MixTable
extends Object
## How loud everything is, and the faders that let somebody decide otherwise.
##
## Split out of `AudioManager` on a real seam rather than for room: that file makes the sounds, and
## this one decides what they are worth against each other. A check that wants to know the shape of
## the mix asks here; a check that wants to know what a waveform is asks there.

# The mix is written in loudness, not in peaks, and that is the whole of it.
#
# Every figure below is a decibel target for how loud a sound actually *is* — the loudest
# root-mean-square it reaches over a third of a second, which is roughly what the ear adds up.
# `SoundBank.loudness` is what measures it and `verify_mix` is what holds the table to it.
#
# It used to be written in peaks, and peaks measure the wrong thing. A decaying sine spends nearly
# all its length near silence and noise that never stops sits at its own average throughout, so two
# sounds at the same peak can be seventeen decibels apart to listen to. One declared figure held the
# reload, the merchant chime and a body going down, and the three came out ten decibels apart; and a
# farmer's recorded shout — the one family here not normalised at all, being a recording rather than
# a buffer — sat at a footstep's loudness before the distance to him was even applied. A mix nobody
# could hear was not a mix tuned badly. It was a table measured in the wrong unit.
#
# The order is the design: quietest is the body the player already controls, loudest is what the
# island is doing to him. **The figures below were set by ear at the desk, in a fight, and then
# written down** — which is why a few of them sit where no rule would have put them.
## The one sound that has to be heard over everything else, and the loudest thing the player himself
## ever causes is still well under it.
const TELEGRAPH_LEVEL: float = -15.5
## A wave passing is the only sound in the game the player is allowed to sit and enjoy.
const STING_LEVEL: float = -16.5
## A landed blow, a shot, a parry. The loudest thing the player himself causes, and under the one
## thing he has to hear coming.
const IMPACT_LEVEL: float = -22.0
## What a body's own voice is worth. **Beside a wind-up rather than under it**, which is a decision
## and not a drift: a farmer shouting used to be flavour nobody could hear, and the level that made
## him audible in a fight is the level that puts him alongside the cue he is announcing. He is two
## decibels over it inside four metres and two under it beyond — `verify_mix` holds him in that band
## in both directions, which is what the old one-sided rule could never do.
const FARMER_LEVEL: float = -13.5
## A reload, a dry trigger, a body going down: moments worth hearing and never worth listening for.
const INCIDENTAL_LEVEL: float = -35.25
## What a music track comes out at. Above the bed's own layers, which is what "the bed sits under
## the music" means in figures — and still **under everything that tells the player something**: a
## soundtrack is the one sound the player may switch off, so it can never be why a wind-up was
## missed.
const TRACK_LEVEL: float = -36.75
## A miss is the least interesting thing that happens in a fight. Under a hit by enough to be heard
## as the lesser of the two.
const WHIFF_LEVEL: float = -41.75
## A gull is weather. It is the only voice in the game that says nothing, so it sits eight decibels
## under the one that does.
const GULL_LEVEL: float = -21.5
## The bed's own layers, under a track by the margin that makes "the bed sits under the music" a
## figure rather than a hope.
const LAYER_LEVEL: float = -40.0
## **The quietest thing in the game.** A footfall is confirmation, not information, and it happens
## twice a second for the whole run, so it is the one sound that can tire an ear out on its own. It
## now sits under the sea it is walking beside rather than over it.
const FOOTFALL_LEVEL: float = -47.75
## What **one stretch of the coast** comes out at, which is the one figure in this table that is not
## what the player hears: the sea is a ring of sources now, so what reaches the ear is the sum of
## them at whatever distance the player is standing. `SurfBed` owns that arithmetic and
## `FROM_THE_MIDDLE_DB` is the part of it a menu needs.
##
## The bed sits under the whole game without ever being the reason something was missed. **It is
## continuous, and that is why it is this far down**: everything else in this table is something
## that happens, and this is something that is always there.
const SURF_LEVEL: float = -32.0
## It confirms that the machine heard you and carries nothing else. A menu has no other sound in it,
## so a click anywhere near a hit would be the loudest thing a player ever hears — and they hear it
## forty times before the island.
const CLICK_LEVEL: float = -40.75
## How far the whole table sits below where it is written, and the only figure that moves the mix as
## a whole rather than changing its shape.
##
## **Derived, not tasted.** Several sounds arrive at once — three farmers commit at night while a
## chain lands — and each is normalised as though it were alone. Uncorrelated sources sum as the
## root of the sum of squares, so four at full scale reach twice it and the master clips. This is
## what keeps the four loudest inside full scale together, and `verify_mix` is what proves it does.
const HEADROOM_DB: float = -2.0
## How loud the recordings already are, per family, before the game does anything to them.
##
## **A recording cannot be normalised the way a buffer can**: the engine holds these compressed and
## there is nothing to measure at load. So the figure is written down, and `verify_mix` reads the
## source files and fails when it drifts.
const FARMER_AS_RECORDED: float = -19.4
const GULL_AS_RECORDED: float = -18.6
## How far a recorded family may drift from the figure above before the gain built on it is wrong.
const AS_RECORDED_TOLERANCE: float = 1.5
## Every family the desk can move, in the order it shows them: loudest at the top of the table.
const FAMILIES: Array[StringName] = [
	&"telegraph",
	&"sting",
	&"impact",
	&"farmer",
	&"incidental",
	&"track",
	&"whiff",
	&"gull",
	&"layer",
	&"footfall",
	&"surf",
	&"click",
]
## What each family is written down as. One place, so the desk, the bakery and the checks are all
## reading the same figures.
const LEVELS: Dictionary[StringName, float] = {
	&"telegraph": TELEGRAPH_LEVEL,
	&"sting": STING_LEVEL,
	&"impact": IMPACT_LEVEL,
	&"farmer": FARMER_LEVEL,
	&"incidental": INCIDENTAL_LEVEL,
	&"track": TRACK_LEVEL,
	&"whiff": WHIFF_LEVEL,
	&"gull": GULL_LEVEL,
	&"layer": LAYER_LEVEL,
	&"footfall": FOOTFALL_LEVEL,
	&"surf": SURF_LEVEL,
	&"click": CLICK_LEVEL,
}
## What a fader may do to a family, either way. Twenty-four decibels is enough to put any family
## over or under any other without being enough to turn a mix into noise by accident.
const FADER_RANGE: float = 24.0
## Where the desk writes what it was left at. `user://` rather than the project: a mix in progress
## is somebody's working state, not a change to the game.
const DESK_AT: String = "user://mix-desk.json"

## What the desk has been moved to, per family, in decibels. **Empty in a shipped game**: the desk
## is a debug tool, nothing else writes here, and a release build never opens it.
static var faders: Dictionary[StringName, float] = {}
## The one fader that moves everything together.
static var master: float = 0.0

static var _family_of: Dictionary[StringName, StringName] = {}


## What a sound is worth, in decibels, with the desk taken into account. This is the figure a player
## is played at; `AudioManager.level_of` is the figure it was baked to.
static func trim_of(id: StringName) -> float:
	return of_family(_family_of.get(id, &""))


## The same for a family that has no single id — the recordings, the soundtrack, the sea.
static func of_family(family: StringName) -> float:
	return float(faders.get(family, 0.0)) + master


## Where a family sits once the desk has had its say, which is what a fader reads out.
static func level_of(family: StringName) -> float:
	return float(LEVELS.get(family, 0.0)) + HEADROOM_DB + of_family(family)


## Told once, at build time, so that nothing has to guess a family from the spelling of an id.
static func assign(id: StringName, family: StringName) -> void:
	_family_of[id] = family


static func family_of(id: StringName) -> StringName:
	return _family_of.get(id, &"")


## Every id the desk would move by touching one fader, so it can audition the family it is about to
## change rather than making the user find a farmer.
static func sounds_of(family: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for id: StringName in _family_of:
		if _family_of[id] == family:
			found.append(id)
	found.sort()
	return found


## Back to the written table, which is what the desk's reset does and what a run that never opens
## the desk always has.
static func flatten() -> void:
	faders.clear()
	master = 0.0
