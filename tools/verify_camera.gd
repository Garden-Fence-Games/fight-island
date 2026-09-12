extends Node
## Headless proof that the stone between the camera and the player gets out of the way, and that
## nothing else does.
##
## The renderer draws nothing here, so what is checked is the number the shader reads — the fade
## each boulder is carrying — rather than the pixels. That is the whole of the logic; turning a
## fade into transparency has no decisions in it.
## Run: godot --headless --path . res://tools/verify_camera.tscn

const ARENA: String = "res://scenes/world/arena.tscn"
## Long enough for a fade to travel its whole range at FADE_SPEED, with room to spare.
const PATIENCE: float = 1.2
## How far in front of the boulder the body stands, measured on the ground rather than along the
## line to the camera. Halfway along that line used to be the answer, and it tied this check to the
## camera's distance without saying so: at seventeen metres the halfway point lands under the sea,
## the snap to walkable ground pulls it sideways, and the boulder is no longer between anything.
## Four metres is close enough that the ground under it is the ground that was asked for.
const JUST_IN_FRONT: float = 4.0
## How far the snap to walkable ground may move the body before the test has stopped testing what it
## says it tests. A silent mis-placement passes the fade check by never occluding anything.
const CLOSE_ENOUGH: float = 1.5
## The most an occluder may fade and still be stone rather than a hole. Written out rather than read
## off OcclusionFader: a check that takes its bound from the class it is checking agrees with
## whatever that class says, and a fade of 1.0 — invisible — passed it until this was written out.
const STILL_THERE: float = 0.9

var _failures: PackedStringArray = []
var _arena: Node3D = null
var _player: Player = null
var _fader: OcclusionFader = null
var _camera_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_run()


func _run() -> void:
	_arena = (load(ARENA) as PackedScene).instantiate() as Node3D
	add_child(_arena)
	# Wave 1 belongs to the tutorial now, and a lesson holding it open would leave this check
	# waiting for a parry nobody is going to throw. This one is not about the lesson.
	_stand_the_tutorial_down(_arena)
	(_arena.get_node("WaveDirector") as WaveDirector).halt()
	_player = _arena.get_node("Player") as Player
	_fader = _arena.get_node("CameraRig/Occlusion") as OcclusionFader
	if _player == null or _fader == null:
		_fail("the arena has no player or no occlusion fader")
		_report()
		return
	await _advance(0.5)
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_fail("the arena has no camera")
		_report()
		return
	# Fixed yaw and fixed pitch mean the eye sits at a constant offset from the body. That is what
	# lets the test put a boulder exactly between them.
	_camera_offset = camera.global_position - _player.global_position

	_check_there_is_something_to_fade()
	await _check_nothing_fades_in_the_open()
	await _check_a_boulder_in_the_way_fades_and_comes_back()
	_check_the_palms_are_left_alone()
	_report()


## An island with nothing in the occluder group would satisfy every check below by never fading
## anything, and would go on hiding the player behind five metres of rock in silence.
func _check_there_is_something_to_fade() -> void:
	if _fader.centres().is_empty():
		_fail("nothing on the island is marked as an occluder")
		return
	var formations := _arena.get_node_or_null("Island/RockFormations")
	if formations == null or formations.get_child_count() == 0:
		_fail("the island has no rock formations")


## Standing in the open, nothing is faded. This is the check that catches the fade being written the
## wrong way round — at which point every boulder would be permanently see-through and every other
## check here would still be satisfied.
func _check_nothing_fades_in_the_open() -> void:
	await _stand_at(Vector3.ZERO)
	for fade: float in _fader.fades():
		if fade > 0.0:
			_fail("a boulder faded %.2f with nothing between the camera and the player" % fade)
			return


func _check_a_boulder_in_the_way_fades_and_comes_back() -> void:
	var centres := _fader.centres()
	if centres.is_empty():
		return
	var toward_camera := Vector3(_camera_offset.x, 0.0, _camera_offset.z).normalized()
	var wanted := centres[0] - toward_camera * JUST_IN_FRONT
	await _stand_at(wanted)
	if _adrift(wanted) > CLOSE_ENOUGH:
		_fail(
			(
				(
					"the body was put %.1f m from where the boulder needed it — there is no walkable"
					+ " ground in front of that rock, so nothing was ever between it and the camera"
				)
				% _adrift(wanted)
			)
		)
		return
	var faded := _fader.fades()[0]
	if faded <= 0.0:
		_fail("a boulder standing between the camera and the player did not fade")
		return
	if faded > STILL_THERE:
		_fail("a boulder faded %.2f — it should go pale, not vanish" % faded)
	await _stand_at(Vector3.ZERO)
	if _fader.fades()[0] > 0.0:
		_fail("a boulder stayed faded after the player walked out from behind it")


## The palms are deliberately outside all of this: the body reads clearly through a crown, and
## thinning several hundred trees in and out as someone walks looks stranger than the trees did.
## Written down as a check so it is a decision rather than an omission somebody later "fixes".
func _check_the_palms_are_left_alone() -> void:
	var population := _arena.get_node_or_null("Island/Props/Palms")
	if population == null:
		_fail("the island has no palms")
		return
	# The scatter is chunked so the camera can cull it, so this walks every batch: one cell put back
	# into the occluder group would be one corner of the island thinning in and out, and checking
	# only the first would never see it.
	var batches := 0
	for child: Node in population.get_children():
		var palms := child as MultiMeshInstance3D
		if palms == null or palms.multimesh == null:
			continue
		batches += 1
		if palms.is_in_group(&"occluder"):
			_fail("the palms are being faded, and they are meant not to be")
			return
		if palms.multimesh.use_custom_data:
			_fail("the palms carry a per-instance fade slot nothing writes to")
			return
	if batches == 0:
		_fail("the island has no palms")


## Puts the body down and lets the rig catch up — it follows through a smooth, so the eye is not
## where the test wants it until a few frames have passed.
## How far the ground snap moved the body, on the flat. Height is the ground's to decide.
func _adrift(wanted: Vector3) -> float:
	var offset := _player.global_position - wanted
	offset.y = 0.0
	return offset.length()


func _stand_at(where: Vector3) -> void:
	_player.global_position = Ground.closest_point(_player.get_world_3d(), where)
	_player.velocity = Vector3.ZERO
	await _advance(PATIENCE)


func _advance(seconds: float) -> void:
	var elapsed := 0.0
	while elapsed < seconds:
		await get_tree().process_frame
		elapsed += 1.0 / 60.0


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("camera OK — stone in the way goes pale, only while it is in the way, palms never")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr(failure)
	get_tree().quit(1)


func _stand_the_tutorial_down(arena: Node) -> void:
	var tutorial := arena.get_node_or_null(^"TutorialDirector") as TutorialDirector
	if tutorial != null:
		tutorial.stand_down()
