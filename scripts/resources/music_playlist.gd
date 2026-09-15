class_name MusicPlaylist
extends Resource
## Every track the game can play, and the order it draws them in.
##
## **A shuffle bag, not a coin toss.** Drawing independently each time lets the same track follow
## itself, which with a handful of them is the difference between a soundtrack and a loop. So the
## bag holds every track once, hands them out in a random order, and is refilled when it empties —
## everything gets played before anything repeats.
##
## The bag lives on the resource rather than in the jukebox because the order is a property of the
## list: two jukeboxes would be two orders, and there is only ever one soundtrack.

@export var tracks: Array[MusicTrack] = []

var _bag: Array[int] = []
## How many tracks the current bag was dealt from. A playlist that grew or shrank invalidates the
## bag; a bag merely part-used does not, and confusing the two refilled it on every single draw.
var _bag_for: int = 0
## The run this bag was dealt for, or -1 before the first deal. A boolean here latched at boot and
## never let go: `AudioManager` builds the jukebox in its own `_ready`, so the first deal happens
## against whatever seed the title screen had, and `begin_run` re-randomises the seed afterwards
## with nothing watching. Every run got the same soundtrack order, for ever.
var _seeded_from: int = -1
var _rng := RandomNumberGenerator.new()


## The tracks that can actually be heard. A row with no file is a plan and is not one of them.
func playable() -> Array[MusicTrack]:
	var found: Array[MusicTrack] = []
	for track: MusicTrack in tracks:
		if track != null and track.is_playable():
			found.append(track)
	return found


func is_empty() -> bool:
	return playable().is_empty()


## The next track, or null when there is no music to play. `avoid` is the one currently on, so a
## refilled bag cannot hand back the track that just finished as the first of the new round — the
## one seam where "everything before anything repeats" would still let a track follow itself.
func draw(avoid: MusicTrack = null) -> MusicTrack:
	var choices := playable()
	if choices.is_empty():
		return null
	if _bag.is_empty() or _bag_for != choices.size():
		_refill(choices.size())
	var pick: int = _bag.pop_back()
	if choices.size() > 1 and choices[pick] == avoid and not _bag.is_empty():
		var swapped: int = _bag.pop_back()
		_bag.append(pick)
		pick = swapped
	return choices[pick]


## Back to a full bag, in a fresh order.
##
## Seeded **once per run**, so a recording of one run has the same soundtrack twice — and only once
## within it, because re-seeding at every refill would deal the same order every round, which is a
## shuffle that shuffles to the same thing.
func _refill(count: int) -> void:
	if _seeded_from != GameState.run_seed:
		_rng.seed = GameState.run_seed + count
		_seeded_from = GameState.run_seed
	_bag_for = count
	_bag.clear()
	for index: int in count:
		_bag.append(index)
	for index: int in range(_bag.size() - 1, 0, -1):
		var other := _rng.randi_range(0, index)
		var held := _bag[index]
		_bag[index] = _bag[other]
		_bag[other] = held
