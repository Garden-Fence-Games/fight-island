class_name Jukebox
extends AudioStreamPlayer
## The soundtrack: one track at a time, drawn at random, from the studio sting to the last wave.
##
## **It belongs to `AudioManager` and is not a fourth autoload.** Music outlives every scene it
## starts in — the sting hands over to the title and the title to the island, and a track that
## restarted at each of those would be three seconds of music three times. `AudioManager` is already
## the global that owns sound and already owns the `Music` bus, so the jukebox is its child rather
## than another singleton ([ADR 0004](../../docs/decisions/0004-three-autoloads.md)).
##
## **On the `Music` bus with the bed, deliberately.** A wind-up ducks that whole bus, so a telegraph
## gets out from under the soundtrack for free and by the same rule that already governs the bed —
## the one sound the player must hear outranks the one they may switch off.
##
## Muting is the jukebox's own, not the bus's: the bus carries the bed as well, and somebody turning
## the songs off has not asked for the island to go quiet.

## A track began, or stopped. Null means nothing is playing — an empty playlist, or muted.
signal track_changed(track: MusicTrack)
## The player asked for silence, or asked for it back.
signal muted_changed(muted: bool)

## The soundtrack. A `Resource` export, which resolves in a hand-written scene where a node export
## would not (ADR 0006) — and which is where the music becomes a data change rather than a code one.
@export var playlist: MusicPlaylist = null
## How long a track takes to arrive and to leave. Long enough not to be a cut, short enough that
## skipping feels like a button rather than a request.
@export var fade: float = 1.2

var _muted: bool = false
var _track: MusicTrack = null
var _fader: Tween = null


func _ready() -> void:
	bus = &"Music"
	# A stream still playing when the engine tears down is reported as a leak, and CI fails a boot on
	# any warning at all. The bed already sits this out for the same reason; the jukebox joins it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	finished.connect(_on_finished)
	if AudioManager.audible:
		_begin(_drawn())


## The shortcut, from wherever the player happens to be. Handled here rather than on the HUD or the
## menus because this is the one node that is in every scene — and `_unhandled_input` means a menu
## that wants the key first still gets it.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"music_mute"):
		return
	get_viewport().set_input_as_handled()
	toggle_mute()


## What is playing, or null. The player in the corner asks; nothing else has any business knowing.
func now_playing() -> MusicTrack:
	return _track


func is_muted() -> bool:
	return _muted


## Whether there is a soundtrack at all. A playlist nobody has filled in yet is not a fault, and the
## player in the corner says so rather than showing an empty frame.
func has_music() -> bool:
	return playlist != null and not playlist.is_empty()


## Silence, or back. Stops rather than turns down: a muted track that kept running would come back
## in the middle of itself, and a track is not a loop.
func set_muted(value: bool) -> void:
	if _muted == value:
		return
	_muted = value
	muted_changed.emit(_muted)
	EventBus.music_muted.emit(_muted)
	if _muted:
		_stop()
		return
	_begin(_drawn())


func toggle_mute() -> void:
	set_muted(not _muted)


## The next one. Does nothing while muted — a skip that quietly unmuted would be a button changing
## two things.
func skip() -> void:
	if _muted or not has_music():
		return
	_begin(_drawn())


func _on_finished() -> void:
	if _muted:
		return
	_begin(_drawn())


func _drawn() -> MusicTrack:
	return playlist.draw(_track) if has_music() else null


## Starts a track, fading in from silence. A null track is the empty playlist and the muted case,
## and both mean the same thing here: nothing plays and the corner says so.
func _begin(track: MusicTrack) -> void:
	_track = track
	if track == null or not AudioManager.audible:
		_stop()
		return
	stream = track.stream
	volume_db = AudioManager.SILENT_DB
	play()
	_fade_to(linear_to_db(AudioManager.peak_of_music()))
	track_changed.emit(_track)
	EventBus.music_track_changed.emit(_track)


func _stop() -> void:
	stop()
	stream = null
	_track = null
	track_changed.emit(null)
	EventBus.music_track_changed.emit(null)


func _fade_to(wanted: float) -> void:
	if _fader != null and _fader.is_valid():
		_fader.kill()
	_fader = create_tween()
	_fader.tween_property(self, "volume_db", wanted, fade)
