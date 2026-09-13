class_name VoiceComponent
extends AudioStreamPlayer3D
## A body that makes a noise of its own, from where it is standing.
##
## Its own player rather than one of `AudioManager`'s pooled voices, and that is the whole point:
## **Doppler needs a source that moves.** A pooled voice is put at a position and played, so it is
## stationary for its whole length, and a stationary sound is exactly the one thing this is for —
## the player has to hear that a farmer is *closing*, not merely that one is shouting somewhere.
##
## The clips are the project's own recordings. `AudioManager` still owns which ones exist and how
## loud they are, so the mix stays one table rather than becoming two.

## How long after one line before this body may say another, in seconds. Two farmers talking over
## each other is a crowd; one talking every second is a parrot.
@export var quiet_for: Vector2 = Vector2(3.5, 9.0)
## Which family of clips this body draws from — `farmer`, `gull`.
@export var kind: StringName = &""

var _rng := RandomNumberGenerator.new()
var _waits: float = 0.0
var _last: int = -1


func _ready() -> void:
	bus = &"SFX"
	# Inverse rather than inverse-square, for the reason the pooled positional voices use it: the
	# square law silences a farmer ten metres behind the player, and ten metres behind the player is
	# exactly where hearing him matters.
	attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	max_distance = AudioManager.REACH
	unit_size = AudioManager.VOICE_UNIT
	volume_db = linear_to_db(AudioManager.peak_of_voice())
	# What makes a body read as *coming towards you*. The pitch rises as it closes and falls as it
	# leaves, which is the one cue that needs no learning at all.
	doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	_rng.seed = GameState.run_seed + int(get_instance_id())
	_waits = _rng.randf_range(quiet_for.x, quiet_for.y)


## Says something, unless it said something too recently. Returns whether it spoke, so a caller that
## wants to know can ask rather than assume.
func speak() -> bool:
	if _waits > 0.0 or not AudioManager.audible or playing:
		return false
	var clips := AudioManager.voices_of(kind)
	if clips.is_empty():
		return false
	# Never the same line twice running. With nine of them that is the difference between a crowd
	# and one man with a tic.
	var pick := _rng.randi_range(0, clips.size() - 1)
	if clips.size() > 1 and pick == _last:
		pick = (pick + 1) % clips.size()
	_last = pick
	stream = clips[pick]
	play()
	_waits = _rng.randf_range(quiet_for.x, quiet_for.y)
	return true


## Back to silence and back to waiting. Called when a pooled body is handed back, or the next man to
## come out of the pool would finish the last one's sentence.
func hush() -> void:
	stop()
	stream = null
	_waits = _rng.randf_range(quiet_for.x, quiet_for.y)


func _process(delta: float) -> void:
	_waits = maxf(_waits - delta, 0.0)
