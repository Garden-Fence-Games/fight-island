class_name MusicBed
extends Node
## Three loops on the Music bus, lifted by how much trouble the player is in.
##
## The only pacing tool the game has between waves. A wave is six minutes and the fighting is not
## evenly spread through it; what the bed does is make the difference audible before the player has
## counted anybody — the island filling up should be a thing you feel arriving rather than a number
## you read off the HUD.
##
## **Pressure is bodies on the island, not time.** A wave that has run five of its six minutes is
## not a tense wave if nobody is left, and a wave thirty seconds in with eight farmers closing is.
## Measured against what the wave formula allows at once rather than against a constant, so the bed
## means the same thing at wave 1 and at wave 15.
##
## The three layers are one piece of music getting louder, not three cues. They are the same length
## so they never drift apart, they are all built on fifths so any pair of them agrees, and their
## ranges overlap so they hand over rather than switching. Nothing in them is rhythmic: a bed the
## ear can count against is a metronome, and a player fights a metronome instead of reading a fight.
##
## **It carries no information and is allowed to be muted.** Everything that tells the player
## something is on the SFX bus; this is atmosphere, and `verify_music` holds the line.

## How fast the mix follows the island, per second of real time. Slow on purpose — a bed that
## tracked the body count frame by frame would pump every time somebody died.
const FOLLOWS: float = 0.35
## How far the music drops while something is winding up, and how fast it gets there and comes back.
## **A telegraph outranks the music**, the way it outranks a camera knock: the wind-up is the one
## thing the player has to hear, and half a bed over it is still a bed over it.
const DUCK_DB: float = -14.0
const DUCKS_IN: float = 14.0
const RECOVERS: float = 2.5
## How long a duck is held after the wind-up that asked for it. Long enough to cover the swing that
## follows, short enough that three farmers in a row do not silence the bed for a whole wave.
const HOLD: float = 0.55
## How far the bed steps back while a track is playing. It is the same music at two jobs: a track
## is the thing being listened to and the bed is the thing telling the player how full the island
## is, so under a track the bed keeps saying it and stops competing. Not silence — the pressure it
## carries is the only pacing tool the game has, and it has to survive somebody putting a song on.
const UNDER_A_TRACK_DB: float = -9.0
## Off, rather than very quiet. A layer below its own range contributes nothing, and -80 dB is what
## the engine treats as silence.
const SILENT: float = -80.0

## The wave figures, for the one thing the bed needs from them: how many bodies this wave is allowed
## to have on the island at once. A Resource export, which does resolve in a hand-written scene
## where a node export would not (ADR 0006).
@export var config: WaveConfig = null

var _players: Dictionary = {}
var _pressure: float = 0.0
var _ducked_for: float = 0.0
var _track_on: bool = false
var _bus: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bus = AudioServer.get_bus_index("Music")
	for id: StringName in AudioManager.LAYERS:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.stream = AudioManager.sound(id)
		player.volume_db = SILENT
		add_child(player)
		_players[id] = player
		if AudioManager.audible:
			player.play()
	EventBus.telegraph_began.connect(_on_telegraph_began)
	EventBus.music_track_changed.connect(_on_music_track_changed)
	# A track may already be playing: the jukebox starts at boot and this bed arrives with the arena.
	_track_on = AudioManager.jukebox() != null and AudioManager.jukebox().now_playing() != null


## A layer left playing at teardown is an object the engine reports as leaked on the way out, and CI
## fails the boot on any warning at all. The same reason the surf stops itself.
func _exit_tree() -> void:
	for player: AudioStreamPlayer in _players.values():
		player.stop()
		# Let go of the waveform as well as stopping it. A player freed with a stream still
		# assigned leaves the engine reporting one object leaked on the way out, and CI fails the
		# boot on any warning at all.
		player.stream = null
	if _bus >= 0:
		AudioServer.set_bus_volume_db(_bus, 0.0)


func _process(delta: float) -> void:
	_pressure = lerpf(_pressure, _trouble(), clampf(FOLLOWS * delta, 0.0, 1.0))
	for id: StringName in _players:
		var player: AudioStreamPlayer = _players[id]
		player.volume_db = (
			_volume_of(id, _pressure)
			+ (UNDER_A_TRACK_DB if _track_on else 0.0)
			+ MixTable.of_family(&"layer")
		)
	_ducked_for = maxf(_ducked_for - delta, 0.0)
	if _bus < 0:
		return
	var wanted := DUCK_DB if _ducked_for > 0.0 else 0.0
	var speed := DUCKS_IN if _ducked_for > 0.0 else RECOVERS
	var now := AudioServer.get_bus_volume_db(_bus)
	AudioServer.set_bus_volume_db(_bus, lerpf(now, wanted, clampf(speed * delta, 0.0, 1.0)))


## How full the island is, nought to one — bodies alive against what **this** wave may have on the
## island at once. Against the wave's own figure rather than a constant, so a full island sounds
## full at wave 1 and at wave 15; against a constant the early waves would never lift.
##
## Zero between waves, which is the breather the bed exists to make audible.
func _trouble() -> float:
	if not GameState.wave_in_progress or config == null:
		return 0.0
	var most := maxi(config.max_alive(GameState.wave), 1)
	return clampf(float(get_tree().get_nodes_in_group(&"enemies").size()) / float(most), 0.0, 1.0)


## Where one layer sits at a given pressure, in decibels. Silent below its range, **full above it**,
## and a fade across — the layers stack rather than take turns, which is the difference between one
## piece of music getting louder and three cues handing off.
func _volume_of(id: StringName, pressure: float) -> float:
	var voice: Dictionary = AudioManager.LAYERS[id]
	var from := float(voice["from"])
	var to := float(voice["to"])
	var share := clampf(inverse_lerp(from, maxf(to, from + 0.001), pressure), 0.0, 1.0)
	return SILENT if share <= 0.0 else linear_to_db(share)


## How loud the bed is right now, nought to one across all three layers.
func loudness() -> float:
	return loudness_at(_pressure)


## And how loud it would be at any pressure. The mix is a **function of how full the island is**, so
## it is readable as one — which is what lets a headless check with no ears walk the whole range
## rather than sample the one place the island happened to be.
func loudness_at(pressure: float) -> float:
	var total := 0.0
	for id: StringName in AudioManager.LAYERS:
		total += db_to_linear(_volume_of(id, pressure))
	return total / float(maxi(AudioManager.LAYERS.size(), 1))


## How far the bus is pulled down right now, in decibels. Nought when nothing is committing.
func duck_db() -> float:
	return AudioServer.get_bus_volume_db(_bus) if _bus >= 0 else 0.0


func _on_music_track_changed(track: MusicTrack) -> void:
	_track_on = track != null


func _on_telegraph_began(_where: Vector3, _archetype: EnemyData) -> void:
	_ducked_for = HOLD
