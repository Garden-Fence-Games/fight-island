class_name SurfBed
extends Node3D
## Where the sea is, which turns out to be the only honest way to say how loud it is.
##
## The surf used to be one flat loop playing at a fixed level everywhere. That is the sea heard from
## nowhere in particular: it was exactly as loud standing in the middle of the island as it was with
## your feet in the water, and no amount of tuning that one figure could have been right in both
## places — quiet enough for the fight meant inaudible on the beach, and audible on the beach meant
## the sea shouting over a wind-up sixty metres inland.
##
## So the sea is put where the sea is. The shoreline is found by asking the terrain rather than by
## assuming a radius — **this island is not round**, and its coast runs between twenty-seven and
## forty-one metres from the middle — and a ring of sources is placed along it.
##
## **The sources are deliberately out of phase with each other.** Eight players starting the same
## six-second loop at the same instant are one loop eight times over: they sum coherently, which is
## eighteen decibels rather than nine, and they comb-filter into something that sounds like a fault
## in the file. Each one starts a different distance into the loop, and after that they behave like
## eight separate stretches of water.
##
## **Inverse square here, inverse distance everywhere else.** The rest of the game uses the gentler
## law on purpose: a farmer ten metres behind the player is exactly the farmer worth hearing, and
## the square law silences him. The sea wants the opposite — it is the one sound in the game that is
## *supposed* to fall away as you walk inland, and the gentle law would carry it to the middle of
## the island almost undiminished.

## How many stretches of water the coast is broken into. Eight puts them about twenty-five metres
## apart, which is far enough that the nearest one clearly wins when the player is standing in it
## and close enough that they blend into one sea from inland.
const EMITTERS: int = 8
## How loudly a stretch of surf carries. Wide, because this is the only sound in the game whose
## source is tens of metres away rather than a few, and it still has to arrive.
##
## **Halved with the island.** It is a distance, and the only distance it is about is the one from
## the middle of the island to the water; at twenty-five on the smaller coast the sea was 1.7 dB
## quieter inland than it was ankle-deep, where it is meant to be ten. Halving both keeps the ratio,
## and `FROM_THE_MIDDLE_DB` below did not have to move at all.
const CARRIES: float = 12.5
## Where the ring is looked for. No island reaches past this, and a search that found nothing inside
## it has found nothing. Left well clear of the coast it is looking for on purpose: it is a bound on
## a search, not a description of an island, and an island rebuilt larger should find its shore
## rather than fail to.
const FURTHEST_SHORE: float = 120.0
## How far above and below the ground a probe is cast from. The island's relief fits inside this
## with room to spare.
const PROBE_HEIGHT: float = 60.0
## How many halvings the search for one shoreline point takes. Twenty-four puts the answer inside a
## hundredth of a millimetre, which is far past what the ear or the check needs, and the whole ring
## still costs one frame once.
const SEARCH_STEPS: int = 24
## How often the bed asks whether it is still on the island it mapped. A scene change is the only
## thing that can invalidate the ring, and half a second is faster than anyone can reach the beach.
const CHECKS_EVERY: float = 0.5
## What the ring adds up to from the middle of the island, and therefore what the flat bed plays at
## in a menu — a menu has no coast to put the ring on, and the sea should not change level when the
## player pauses. Written down rather than derived at runtime because the flat bed has to be right
## before any island exists; `verify_mix` maps a real coast and fails if the two drift apart.
const FROM_THE_MIDDLE_DB: float = -7.6
## How far the figure above may sit from what a mapped coast actually produces.
const MIDDLE_TOLERANCE: float = 2.0

var _flat: AudioStreamPlayer = null
var _placed: Array[AudioStreamPlayer3D] = []
var _mapped: bool = false
var _waited: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_flat = AudioStreamPlayer.new()
	_flat.bus = &"Ambience"
	_flat.stream = AudioManager.sound(AudioManager.BED_SOUND)
	_flat.volume_db = FROM_THE_MIDDLE_DB
	add_child(_flat)
	for index: int in EMITTERS:
		var water := AudioStreamPlayer3D.new()
		water.bus = &"Ambience"
		water.stream = AudioManager.sound(AudioManager.BED_SOUND)
		water.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		water.unit_size = CARRIES
		# Unlimited on purpose. `REACH` is what a sound that belongs to a body may carry; the sea is
		# tens of metres away from the fight and still has to be heard.
		water.max_distance = 0.0
		add_child(water)
		_placed.append(water)
	if AudioManager.audible:
		_flat.play()


func _physics_process(delta: float) -> void:
	_waited += delta
	if _waited < CHECKS_EVERY:
		return
	_waited = 0.0
	var space := get_world_3d().direct_space_state
	var on_land := space != null and _ground(space, Vector3.ZERO) > Water.level
	if not on_land:
		_go_flat()
		return
	# One probe while the ring stands, the whole search only when there is a new coast to find.
	if _mapped:
		return
	var coast := _map_the_coast(space)
	if not coast.is_empty():
		_go_positional(coast)


## Where the ring ended up. Empty until an island has been found.
func coastline() -> PackedVector3Array:
	var found := PackedVector3Array()
	if not _mapped:
		return found
	for water: AudioStreamPlayer3D in _placed:
		found.append(water.global_position)
	return found


## Re-reads the desk. Debug-only in practice — nothing else moves a fader — but it is the sea's own
## business how its sources answer one, so it lives here rather than in the screen that calls it.
func remix() -> void:
	var trim := MixTable.of_family(&"surf")
	_flat.volume_db = FROM_THE_MIDDLE_DB + trim
	for water: AudioStreamPlayer3D in _placed:
		water.volume_db = trim


## A stream left playing at teardown is an object the engine reports as leaked on the way out: the
## audio server releases a playback on its own iteration, and at quit there is no next iteration.
func silence() -> void:
	_flat.stop()
	for water: AudioStreamPlayer3D in _placed:
		water.stop()


## **Found rather than assumed.** A radius would fence the sea off from half the beach and put it
## inland on the other side, for the same reason `PlayableArea` refuses to use one: the island is
## not round. Each direction is walked outwards until the ground stops being above the waterline.
func _map_the_coast(space: PhysicsDirectSpaceState3D) -> PackedVector3Array:
	var found := PackedVector3Array()
	for index: int in EMITTERS:
		var angle := TAU * float(index) / float(EMITTERS)
		var way := Vector3(cos(angle), 0.0, sin(angle))
		var land := 0.0
		var sea := FURTHEST_SHORE
		for _step: int in SEARCH_STEPS:
			var between := (land + sea) * 0.5
			if _ground(space, way * between) > Water.level:
				land = between
			else:
				sea = between
		found.append(way * land + Vector3.UP * Water.level)
	return found


func _ground(space: PhysicsDirectSpaceState3D, at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * PROBE_HEIGHT, at + Vector3.DOWN * PROBE_HEIGHT, PhysicsLayers.BIT_WORLD
	)
	var hit := space.intersect_ray(query)
	return (hit["position"] as Vector3).y if hit.has("position") else -INF


func _go_positional(coast: PackedVector3Array) -> void:
	for index: int in _placed.size():
		_placed[index].global_position = coast[index]
	if _mapped:
		return
	_mapped = true
	_flat.stop()
	if not AudioManager.audible:
		return
	for index: int in _placed.size():
		# Out of phase with each other, or the ring is one loop eight times over.
		_placed[index].play(AudioManager.SURF_SECONDS * float(index) / float(EMITTERS))


func _go_flat() -> void:
	if not _mapped:
		return
	_mapped = false
	for water: AudioStreamPlayer3D in _placed:
		water.stop()
	if AudioManager.audible:
		_flat.play()
