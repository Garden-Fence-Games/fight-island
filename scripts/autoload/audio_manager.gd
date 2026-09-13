extends Node
## Every sound the island makes, synthesised at startup rather than shipped as files.
##
## The subject of this game is timing, and the eye is on the enemy — not on the player, and not on
## the flash around their own fist. **A perfect hit has to be recognisable with the screen off.**
## That is what the five signatures are for, and it is why they were here before any audio asset
## existed: a wave lasts six minutes, and a window the player can only see is a window they will
## miss.
##
## The signatures are one family with one idea in it: **the ring is the reward.** A normal hit is a
## thud that stops. A perfect hit is the same thud with a bright partial that keeps going. A late
## parry is a dull short version of the perfect parry's bell. Nothing differs by loudness alone,
## because loudness is the first thing a player turns down and the first thing a busy fight buries.
##
## Everything added since divides into three, and the division is what keeps the mix legible:
##
## - **The player's own body** — footfalls, a roll, a reload, a trigger on an empty magazine. Flat,
##   quiet, and never the thing you are listening for. They exist so the player knows the game
##   heard them.
## - **The world** — a farmer committing, a body going down. **Positional**, because a wind-up the
##   player cannot see is the one they most need to hear, and a direction is the only thing that
##   makes a crowd survivable.
## - **The bed** — the surf, looping on its own bus, which is the only sound here with no event
##   behind it.
##
## Loudness is declared per sound rather than normalised to one peak for all of them. It has to be:
## a footfall at a hit's level buries the fight it is walking through, and the telegraph has to cut
## through three of them. `level_of` reports what each one asked for, so the mix is a table a check
## can read rather than a set of numbers tuned until it sounded fine once.
##
## Baked into `AudioStreamWAV` once, not pushed through an `AudioStreamGenerator` frame by frame: a
## one-shot does not want a live synthesiser it can starve, and a waveform built once is a waveform
## that sounds the same every time — which is the whole point of a signature.

## How many flat sounds may overlap. A chain into a parry into a hit is three, and locomotion now
## shares this pool — a sprint puts a footfall in it every fifth of a second. Raised so that a
## running player can never be the reason a perfect parry finds no voice.
## The rate, the ramp and the seam live with the signal work now. Named here as well because the
## checks ask this class what the game sounds like, and a check that had to know which file a
## sample rate moved to would be a check that breaks when it moves again.
const MIX_RATE: int = SoundBank.MIX_RATE
const RAMP: float = SoundBank.RAMP
const SURF_SEAM: float = SoundBank.SURF_SEAM

const VOICES: int = 12
## How many sounds may come from somewhere. Three farmers may commit at once at night, and a body
## can go down while they do.
const POSITIONAL_VOICES: int = 6
## How far a positional sound carries. It has to beat what the camera shows — the eye reaches about
## twenty metres at the default zoom and twenty-four at the furthest — because a telegraph that is
## only audible once its owner is on screen is a telegraph the ring already gave you.
const REACH: float = 34.0
## Where the project's own recordings live, and how a family is spelled. The only sounds in the game
## that are **not** synthesised: a voice is the one thing a sine cannot do, and these are recordings
## made for this project rather than anything with a licence to clear.
const VOICES_AT: String = "res://assets/audio/voice"
## How loudly a moving source carries. Lower than the pooled positional voices: those announce a
## wind-up and have to cut through, this one is a man muttering on his way over.
const VOICE_UNIT: float = 5.0
## How loudly a pooled positional sound carries — a wind-up, a body going down. Wider than a body's
## own voice on purpose: this is the family that has to reach the player before its owner does.
const POSITIONAL_UNIT: float = 8.0
## What the engine treats as silence, and what a track fades up from rather than starting at.
const SILENT_DB: float = -80.0
## The soundtrack itself. Five tracks as of now; the jukebox and the player in the corner still cope
## with an empty one rather than assuming a track exists, because a playlist is a data change and
## code that broke when somebody emptied it would make it a code change.
const PLAYLIST: String = "res://data/music/playlist.tres"
## The player's own death. Most of an octave down, over two thirds of a second — long enough to be
## a shout and short enough to be over before the summary screen slides in.
const CRY_SECONDS: float = 0.66
const CRY_FROM: float = 430.0
const CRY_TO: float = 150.0

## The partial the perfect window adds, and how long it rings. **The same in every impact family**:
## it is the signature, and a player who learns it on fists has learnt it on the gun.
## **The whole game is in A minor**, and that is not decoration — it is what stops two sounds that
## arrive together from grinding. It was already mostly true and nobody had written it down: the bed
## is stacked fifths on A, the perfect parry is a bell on A and E, the perfect signature is E, and
## the pickup is E and B. Three sounds were in C and G — the wave sting, the merchant and the two
## endings — and those are the three most *musical* moments in the game, so they were the three that
## rang against everything else.
##
## `verify_audio` holds it: every named partial has to sit on a note of this scale. The one sound
## deliberately outside it is the dry-fire warning, which has to be heard as *not* music.
const A: float = 440.0
const C: float = 523.25
const E: float = 659.25
const PERFECT_PARTIAL: float = 1320.0
const PERFECT_RING: float = 0.13
## The body of a blow, per weapon. Pitch, how long it rings, and how much contact grain rides on top
## — a fist is a dull knock on a body, a stick is wood that cracks and carries, a round is sharp and
## over at once. The generic row is what an attack that names no family gets.
##
## `grain` only seeds the noise. Two families sharing a seed would share their contact exactly,
## which is the one way two of these could accidentally become the same sound.
##
## **The fists are the base**, and they keep the plain ids `hit` and `perfect` rather than getting a
## fourth waveform of their own. That is not an accident of implementation: the fists are the weapon
## the player never puts down and never runs out of, so a blow landing in this game sounds like a
## fist landing unless something else is in hand. An attack naming a family nothing registered falls
## back here — audibly the fist, and `verify_audio` fails the build before anyone hears it.
const BASE_IMPACT: StringName = &"fist"
const IMPACTS: Dictionary = {
	&"fist": {"hertz": 150.0, "decay": 0.035, "contact": 0.5, "snap": 0.018, "grain": 11},
	&"stick": {"hertz": 240.0, "decay": 0.075, "contact": 0.72, "snap": 0.010, "grain": 29},
	&"gun": {"hertz": 320.0, "decay": 0.022, "contact": 0.34, "snap": 0.006, "grain": 47},
}
## A wind-up, per archetype. They all climb — a warning that does not rise is a warning the ear
## reads as a drone — and they differ in **where they climb from and to**, which is the one thing
## that survives several of them at once in a crowd at night.
##
## The pirate is the outlier on purpose: he strikes hardest and from arm's length, so his is the
## lowest and the longest warning there is.
##
## **The farmhand is the base**, keeping the plain `telegraph` id for the same reason the fists keep
## `hit`: he is the archetype every wave is made of, and a wind-up in this game sounds like a
## farmhand's unless somebody rarer is committing.
const BASE_TELEGRAPH: StringName = &"farmhand"
const TELEGRAPHS: Dictionary = {
	&"farmhand": {"from": 300.0, "to": 690.0, "seconds": 0.30, "grain": 61},
	&"pirate": {"from": 200.0, "to": 380.0, "seconds": 0.48, "grain": 79},
}
## Small random pitch on repeated sounds, so a chain does not sound like a machine. The perfect hit
## and both parries are left alone: a signature that moves is not one.
const JITTER: float = 0.04
## Footfalls get more of it than anything else. Two identical steps in a row is the single most
## artificial sound a game can make, and the ear catches it long before it catches a pitch.
const STEP_JITTER: float = 0.12
## How many rounds have to be left for the warning to sound. One: the shot that empties the magazine
## is too late to act on, and two is a warning the player hears most of a wave before it matters.
const LAST_ROUNDS: int = 1
## A swing gets nearly as much. Three misses in a chain is the same trap as three identical steps,
## and a whiff carries no timing information that a wandering pitch could damage.
const SWING_JITTER: float = 0.09
## How long the surf bed runs before it comes back round. Long enough that the ear does not learn
## it, short enough to stay a reasonable amount of memory at this rate — six seconds of mono at
## 22 kHz is a quarter of a megabyte, once, for the whole game.
const SURF_SECONDS: float = 6.0
## Whole swells across the bed, and the next one up gets one more. Two and three give periods of
## three and two seconds, which do not divide into each other — so the water never settles into a
## rhythm the ear can count, and a wave every three seconds is a metronome.
const SURF_SWELLS: int = 2
## How far apart the three notes of an ending fall, and how long the last one holds. Slower than the
## wave sting: a run finishing is the one moment in the game nobody is in a hurry.
const ENDING_STEP: float = 0.22
const ENDING_RING: float = 0.55
## The one looping sound that is not music. Named so a check can tell the bed apart from a one-shot
## without knowing what a surf is.
const BED_SOUND: StringName = &"surf"
## The bus everything musical plays on, and the one it sends into. They are two buses because two
## writers on one bus is what silently overwrote the player's volume slider every frame — the duck
## lands on `MusicDuck` and `Settings` is the only thing that ever writes `Music`.
##
## Named here rather than spelled out at each use. Three files sat on this bus by writing the string
## again, and a bus renamed in the layout would have left `get_bus_index` returning -1 in one of
## them with nothing to say so: a silent bed, or a duck that never came off.
const DUCK_BUS: StringName = &"MusicDuck"
## How long every layer runs before it comes round. **The same for all of them**, or they drift out
## of phase within a minute and the lift stops being one piece of music getting louder.
const MUSIC_SECONDS: float = 8.0
## How far the second voice of each pair is pushed off the first. Three cents: slow enough that the
## beating reads as movement rather than as tuning, and small enough that it is still one note.
const DETUNE: float = 1.003
## The three layers, and what each is for. A **share of the pressure** rather than a threshold:
## `ground` is the sound of a fight happening at all, `pulse` arrives as the island fills, and
## `edge` only ever reaches full at the top. `from` and `to` are the pressure either side of the
## layer's own fade, so the three hand over rather than switching.
##
## The root is 55 Hz — A, low enough to sit under every partial in the game. Nothing here shares a
## frequency with the perfect signature at 1320 Hz or with any wind-up, which is the whole reason a
## music bed is allowed to exist during a fight.
const LAYERS: Dictionary = {
	&"music_ground": {"root": 55.0, "voices": 2, "from": 0.0, "to": 0.15, "swells": 2},
	&"music_pulse": {"root": 82.5, "voices": 2, "from": 0.2, "to": 0.55, "swells": 5},
	&"music_edge": {"root": 220.0, "voices": 3, "from": 0.6, "to": 0.95, "swells": 8},
}

## Whether anything should actually be played. False headless, because there is nobody to hear it —
## and a one-shot still in flight when the engine tears down is an object it reports as leaked, for
## the reason the bed has always known: the audio server releases a playback on its own iteration,
## and at quit there is no next iteration. That is issue #145, and it was intermittent because it
## depended on what happened to be sounding when the window closed.
##
## **A headless check is the exception, and it is not a special case — it is the literal reading of
## the rule.** "There is nobody to hear it" is false when a check is listening on purpose, which is
## what `verify_audio` does: it asks which voice is carrying which waveform. So it says so, and
## everything else stays quiet.
var audible: bool = DisplayServer.get_name() != "headless"

var _sounds: Dictionary = {}
var _recordings: Dictionary = {}
var _levels: Dictionary = {}
var _peaks: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _placed: Array[AudioStreamPlayer3D] = []
var _bed: SurfBed = null
var _jukebox: Jukebox = null
var _noise := RandomNumberGenerator.new()
var _health_seen: float = -1.0


func _ready() -> void:
	# Hitstop drives Engine.time_scale to a fifth. Audio does not run on that clock, but the pool
	# must not be paused by a menu either — a sound cut off mid-ring reads as a bug in the fight.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	for _index: int in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = &"SFX"
		add_child(voice)
		_voices.append(voice)
	for _index: int in POSITIONAL_VOICES:
		var voice := AudioStreamPlayer3D.new()
		voice.bus = &"SFX"
		# Inverse rather than inverse-square: the square law is what silences a farmer ten metres
		# behind the player, and ten metres behind the player is exactly where he matters.
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.max_distance = REACH
		voice.unit_size = POSITIONAL_UNIT
		add_child(voice)
		_placed.append(voice)
	_load_the_recordings()
	_start_the_bed()
	_start_the_jukebox()
	EventBus.attack_landed.connect(_on_attack_landed)
	EventBus.attack_whiffed.connect(_on_attack_whiffed)
	EventBus.parry_perfect.connect(_on_parry_perfect)
	EventBus.parry_late.connect(_on_parry_late)
	EventBus.footstep_taken.connect(_on_footstep_taken)
	EventBus.telegraph_began.connect(_on_telegraph_began)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_state_changed.connect(_on_player_state_changed)
	EventBus.weapon_found.connect(_on_weapon_found)
	EventBus.weapon_reloaded.connect(_on_weapon_reloaded)
	EventBus.weapon_dry_fired.connect(_on_weapon_dry_fired)
	EventBus.weapon_fired.connect(_on_weapon_fired)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.merchant_opened.connect(_on_merchant_opened)
	EventBus.run_ended.connect(_on_run_ended)
	EventBus.player_died.connect(_on_player_died)


## A stream left playing at teardown is an object the engine reports as leaked on the way out: the
## audio server releases a playback on its own iteration, and at quit there is no next iteration.
##
## The bed knew this and the pooled voices did not, which is issue #145 — `main.tscn` leaked a
## waveform for as long as anything happened to be sounding when the window closed. **And CI could
## not see it**: the boot gate greps every boot for a warning, and the Linux runner does not
## reproduce this one. The gate was green while a developer on the same commit was not.
##
## So the invariant is held where a platform cannot hide it — `verify_audio` calls `silence()` and
## asks the voices — rather than by watching for the warning.
func _exit_tree() -> void:
	silence()


## Every voice stopped and every waveform let go of. Public because it is a real thing to want — the
## end of a run could ask for it — and because it is the only way a check can hold the invariant on
## a machine where the symptom never appears.
##
## **Stopping is not enough; the stream has to be released.** A player freed with a stream still
## assigned is an object the engine reports as leaked, and the bed knew that while the twelve pooled
## voices did not — so `main.tscn` leaked one waveform at exit for as long as anything was still
## sounding when the window closed.
func silence() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	for voice: AudioStreamPlayer3D in _placed:
		voice.stop()
		voice.stream = null
	if _bed != null:
		_bed.silence()


## Plays a sound flat, in front of the player. Unknown ids are ignored rather than pushed as an
## error: a caller asking for a sound that does not exist yet should go quiet, not spam the log for
## the rest of the run.
func play(id: StringName, jitter: float = 0.0) -> void:
	if not audible:
		return
	var stream: AudioStreamWAV = _sounds.get(id)
	if stream == null:
		return
	var voice := _free_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.volume_db = MixTable.trim_of(id)
	voice.pitch_scale = 1.0 + _noise.randf_range(-jitter, jitter)
	voice.play()


## The same, from a point in the world. What this buys over `play` is the only thing that makes a
## crowd answerable: a player who cannot see the farmer winding up behind them can still hear which
## side he is on.
func play_at(id: StringName, where: Vector3, jitter: float = 0.0) -> void:
	if not audible:
		return
	var stream: AudioStreamWAV = _sounds.get(id)
	if stream == null:
		return
	var voice := _free_positional_voice()
	if voice == null:
		return
	voice.stream = stream
	voice.global_position = where
	voice.volume_db = MixTable.trim_of(id)
	voice.pitch_scale = 1.0 + _noise.randf_range(-jitter, jitter)
	voice.play()


## The baked waveform, for anything that wants to measure rather than hear it.
func sound(id: StringName) -> AudioStreamWAV:
	return _sounds.get(id)


## Every id there is. The mix is a property of the whole set, so the set has to be askable: a check
## that listed them itself would be short of exactly the loud one that clips.
## The clips of one family, in a stable order. Loaded once at startup like everything else, so a
## body asking for a line is not touching the disk in the middle of a fight.
func voices_of(kind: StringName) -> Array[AudioStream]:
	var found: Array[AudioStream] = []
	found.assign(_recordings.get(kind, []))
	return found


## The gain a family of recordings is played at, which is the one place in the mix where the figure
## has to be **derived rather than declared**: a buffer is normalised to the level it asked for, and
## a recording arrives at whatever loudness it was recorded at. So the gain is the difference
## between the two, and getting it wrong is exactly how the farmers ended up at a footstep's
## loudness while the table said they were four decibels under a landed blow.
func gain_of_voice(kind: StringName) -> float:
	var wanted := MixTable.GULL_LEVEL if kind == &"gull" else MixTable.FARMER_LEVEL
	var recorded := MixTable.GULL_AS_RECORDED if kind == &"gull" else MixTable.FARMER_AS_RECORDED
	return db_to_linear(wanted + MixTable.HEADROOM_DB + MixTable.of_family(kind) - recorded)


## What a track comes out at, headroom included — the same question `level_of` answers for a sound
## with an id, for the one stream that has no id and is not synthesised.
## What the jukebox plays **this** track at. **Derived rather than declared**, because a track
## arrives already mastered: the figure on the table is what it should be worth at the ear, and the
## gain is whatever turns this particular recording into that. The same shape as `gain_of_voice`,
## for the same reason — and per track, so five masters six decibels apart arrive level.
##
## A track with nothing measured falls back to the soundtrack's average rather than to unity: unity
## would be a gain of zero against a master, which is the loudest thing the game could possibly do.
func gain_of_music(track: MusicTrack = null) -> float:
	var recorded := MixTable.TRACK_AS_RECORDED
	if track != null and track.as_recorded < 0.0:
		recorded = track.as_recorded
	return db_to_linear(
		MixTable.TRACK_LEVEL + MixTable.HEADROOM_DB + MixTable.of_family(&"track") - recorded
	)


## A menu press, heard. Flat rather than positional: a button is not anywhere on the island.
func click() -> void:
	play(&"ui_click")


## The soundtrack, for the player in the corner and the shortcut that mutes it. Nothing else should
## be reaching for it: what a track is called is a question for one widget.
func jukebox() -> Jukebox:
	return _jukebox


func every_sound() -> Array[StringName]:
	var all: Array[StringName] = []
	all.assign(_sounds.keys())
	return all


## How loud a sound is meant to be. The mix is a decision, so it is readable rather than implied: a
## check can assert that a footfall sits under a hit without anybody having to listen.
##
## The headroom is in it, because this answers *how loud is this really* — the table of levels is
## the **shape** of the mix, and this is the mix.
func level_of(id: StringName) -> float:
	return float(_levels.get(id, 0.0))


## How tall a sound came out, which is a different question and only one thing asks it: four loud
## sounds arriving together have to fit inside full scale, and what sums there is amplitude.
func peak_of(id: StringName) -> float:
	return float(_peaks.get(id, 0.0))


## The sea, for a check that wants to know where it is rather than hear it.
func bed() -> SurfBed:
	return _bed


## The oldest voice is not reused while it is still ringing — a perfect parry cut short by the next
## jab is the one sound in the game that must never be.
func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	return null


func _free_positional_voice() -> AudioStreamPlayer3D:
	for voice: AudioStreamPlayer3D in _placed:
		if not voice.playing:
			return voice
	return null


func _build() -> void:
	_register(&"hit", _hit(BASE_IMPACT, false), &"impact")
	_register(&"perfect", _hit(BASE_IMPACT, true), &"impact")
	for family: StringName in IMPACTS:
		if family == BASE_IMPACT:
			continue
		_register(StringName("hit_%s" % family), _hit(family, false), &"impact")
		_register(StringName("perfect_%s" % family), _hit(family, true), &"impact")
	for archetype: StringName in TELEGRAPHS:
		if archetype == BASE_TELEGRAPH:
			continue
		_register(StringName("telegraph_%s" % archetype), _telegraph_of(archetype), &"telegraph")
	_register(&"low_ammo", _low_ammo(), &"incidental")
	_register(&"whiff", _whiff(), &"whiff")
	_register(&"shot", _shot(false), &"impact")
	_register(&"shot_heavy", _shot(true), &"impact")
	_register(&"parry_perfect", _parry(true), &"impact")
	_register(&"parry_late", _parry(false), &"impact")
	_register(&"step_sand", _step(false), &"footfall")
	_register(&"step_water", _step(true), &"footfall")
	_register(&"roll", _roll(), &"footfall")
	_register(&"reload", _reload(), &"incidental")
	_register(&"dry_fire", _dry_fire(), &"incidental")
	_register(&"hurt", _hurt(), &"incidental")
	_register(&"enemy_down", _enemy_down(), &"incidental")
	_register(&"pickup", _pickup(), &"incidental")
	_register(&"telegraph", _telegraph(), &"telegraph")
	_register(&"wave_cleared", _sting(), &"sting")
	_register(&"merchant", _merchant(), &"incidental")
	_register(&"victory", _ending(true), &"sting")
	_register(&"defeat", _ending(false), &"sting")
	_register(&"death_cry", _death_cry(), &"sting")
	_register(&"surf", _surf(), &"surf")
	_register(&"ui_click", _click(), &"click")
	for layer: StringName in LAYERS:
		_register(layer, _layer(layer), &"layer")


## The recordings, by family, taken from the file names. A directory rather than a list in code: a
## line added to the game is a file dropped in, and a table here would be a second place to forget.
func _load_the_recordings() -> void:
	var taken := {}
	for name: String in DirAccess.get_files_at(VOICES_AT):
		var file := name.trim_suffix(".remap").trim_suffix(".import")
		if not file.ends_with(".wav"):
			continue
		# **Once each.** Running from source the directory lists `farmer_01.wav` *and*
		# `farmer_01.wav.import`, and trimming the suffix turns the second into the first — so every
		# clip was loaded twice and every family was twice the size it reports. Nine farmers came
		# out as eighteen, which also quietly broke "never the same line twice running": a duplicate
		# can follow its own original.
		if taken.has(file):
			continue
		taken[file] = true
		var kind := StringName(file.get_basename().rsplit("_", true, 1)[0])
		var stream := load("%s/%s" % [VOICES_AT, file]) as AudioStream
		if stream == null:
			push_error("voice: %s did not load" % file)
			continue
		if not _recordings.has(kind):
			_recordings[kind] = [] as Array[AudioStream]
		(_recordings[kind] as Array[AudioStream]).append(stream)


## The level asked for and the peak that came back. Both, because they answer different questions
## and only one of them is a decision: the level is the mix, and the peak is what the sum of four of
## them has to fit inside.
func _register(id: StringName, stream: AudioStreamWAV, family: StringName) -> void:
	_sounds[id] = stream
	_levels[id] = _level(MixTable.LEVELS[family])
	_peaks[id] = SoundBank.peak_of(SoundBank.samples(stream))
	MixTable.assign(id, family)


static func _level(decibels: float) -> float:
	return db_to_linear(decibels + MixTable.HEADROOM_DB)


## A thud and a snap of contact. The perfect one adds a partial that outlasts both by a quarter of
## a second — the tail is what the ear keys on when the eye is elsewhere.
##
## **The body is the weapon; the ring is the timing.** A fist, a stick and a round do not land
## alike, so each family gets its own body — a different pitch, a different amount of contact, a
## different length. What they must never differ in is the **partial the perfect window adds**: that
## one is the signature, it is the same 1320 Hz in all of them, and a player who learns it on fists
## has learnt it on the gun. Three signatures would be three things to learn in the half second
## there is.
##
## Nothing here differs by loudness. All six normalise to the same peak, for the reason the whole
## family exists: loudness is the first thing a player turns down and the first thing a busy fight
## buries.
func _hit(family: StringName, perfect: bool) -> AudioStreamWAV:
	var voice: Dictionary = IMPACTS.get(family, IMPACTS[BASE_IMPACT])
	var body := float(voice["decay"])
	var samples := SoundBank.long_enough(maxf(PERFECT_RING if perfect else 0.0, body))
	SoundBank.tone(samples, float(voice["hertz"]), 0.9, body)
	SoundBank.hiss(samples, float(voice["contact"]), float(voice["snap"]), int(voice["grain"]))
	if perfect:
		SoundBank.tone(samples, PERFECT_PARTIAL, 0.38, PERFECT_RING)
		SoundBank.tone(samples, PERFECT_PARTIAL * 1.5, 0.16, 0.10)
	return SoundBank.bake(samples, _level(MixTable.IMPACT_LEVEL))


## A swing through air: something **passing**, not something failing to arrive.
##
## No transient at all, and that is the point — nothing was struck, so nothing snaps. What it does
## have is a shape: dark noise that swells, peaks in the middle and falls away. That is the whole
## difference between a swish and a wash of hiss, and it is why the level rises and falls rather
## than merely decaying. A sound that starts at its loudest is a sound that started with contact.
##
## Two things it deliberately is not. It is **not as loud as a hit** — a miss is the least
## interesting thing that can happen in a fight, and it used to come out at the same peak as a
## landed blow. And it is **not half a second long**: a decay of 0.09 ran the buffer six time
## constants deep, so every missed jab washed for 540 ms over the top of whatever came next. Air
## moves past in a sixth of a second.
func _whiff() -> AudioStreamWAV:
	var samples := SoundBank.span(0.17)
	SoundBank.hiss(samples, 0.9, INF, 23)
	# Twice, at different weights. One pass leaves white noise sounding like escaping steam; the
	# second takes the top off it, and what is left reads as air rather than as a hiss.
	SoundBank.soften(samples, 0.14)
	SoundBank.soften(samples, 0.40)
	SoundBank.swell(samples, 0.055)
	SoundBank.release(samples, 0.09)
	return SoundBank.bake(samples, _level(MixTable.WHIFF_LEVEL))


## The report. A crack and a body, both very short, and nothing that rings: what makes a gunshot a
## gunshot is that it is over before the ear has finished deciding what it was.
##
## The charged shot is the same report an octave lower and longer — one report scaled rather than
## two waveforms, because what differs between the gun's three attacks is weight, not identity.
func _shot(heavy: bool) -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.09 if heavy else 0.05)
	SoundBank.hiss(samples, 0.9, 0.012 if heavy else 0.006, 71)
	SoundBank.tone(samples, 70.0 if heavy else 120.0, 0.8, 0.09 if heavy else 0.05)
	SoundBank.soften(samples, 0.45 if heavy else 0.65)
	return SoundBank.bake(samples, _level(MixTable.IMPACT_LEVEL))


## A bell. The perfect one rings for half a second on three partials; the late one is the same bell
## damped — one partial, a fifth of the length. Same voice, and the difference is all in the tail.
func _parry(perfect: bool) -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.30 if perfect else 0.055)
	SoundBank.hiss(samples, 0.8 if perfect else 0.4, 0.008, 37)
	if perfect:
		SoundBank.tone(samples, 880.0, 0.40, 0.30)
		SoundBank.tone(samples, 1318.0, 0.25, 0.24)
		SoundBank.tone(samples, 2640.0, 0.12, 0.14)
		return SoundBank.bake(samples, _level(MixTable.IMPACT_LEVEL))
	SoundBank.tone(samples, 440.0, 0.25, 0.055)
	return SoundBank.bake(samples, _level(MixTable.IMPACT_LEVEL))


## A foot in sand, and a foot in the surf. Both are noise and neither has a pitch: sand is a scuff
## with the top taken off it, and water is the same scuff wetter, brighter and twice as long, with
## the swell that makes it read as something displaced rather than something struck.
##
## Deliberately the quietest things in the game. The player walks for six minutes a wave, and a
## footfall that competes with the fight is a footfall that hides it.
func _step(wading: bool) -> AudioStreamWAV:
	if not wading:
		var sand := SoundBank.long_enough(0.014)
		SoundBank.hiss(sand, 0.7, 0.014, 5)
		SoundBank.soften(sand, 0.30)
		return SoundBank.bake(sand, _level(MixTable.FOOTFALL_LEVEL))
	var water := SoundBank.long_enough(0.045)
	SoundBank.hiss(water, 0.7, 0.045, 7)
	SoundBank.soften(water, 0.55)
	SoundBank.swell(water, 0.012)
	return SoundBank.bake(water, _level(MixTable.FOOTFALL_LEVEL))


## A roll: air, and then a body arriving. The swish alone would be a slower whiff, so the shoulder
## landing is in it — a low thump two thirds of the way through, which is the thing that separates
## going to ground from swinging at it.
##
## Its length is designed rather than derived. A decay of 0.16 ran the buffer most of a second,
## which is twice the roll itself and long enough to still be sounding when the player is back on
## their feet and swinging.
func _roll() -> AudioStreamWAV:
	var samples := SoundBank.span(0.34)
	SoundBank.hiss(samples, 0.9, INF, 29)
	SoundBank.soften(samples, 0.10)
	SoundBank.swell(samples, 0.10)
	SoundBank.tone(samples, 110.0, 0.55, 0.05, 0.20)
	SoundBank.release(samples, 0.08)
	return SoundBank.bake(samples, _level(MixTable.FOOTFALL_LEVEL))


## Two dry clacks, a magazine out and a magazine in. Nothing rings: it is the one sound in the game
## that is purely mechanical, and that is what separates it from everything that hits.
func _reload() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.008, 0.10)
	SoundBank.hiss(samples, 0.8, 0.006, 41)
	SoundBank.hiss(samples, 0.6, 0.008, 43, 0.10)
	SoundBank.soften(samples, 0.75)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## The trigger on an empty magazine. One dead click and a stub of low body — the sound of a thing
## not happening, which is exactly what the player needs told: a press that produces nothing at all
## reads as a dropped input, and they blame the game rather than their own ammunition.
func _dry_fire() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.012)
	SoundBank.hiss(samples, 0.7, 0.005, 47)
	SoundBank.tone(samples, 210.0, 0.25, 0.012)
	SoundBank.soften(samples, 0.8)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## Taking a hit. Lower and duller than landing one, and with the top rolled off: the player has to
## be able to tell, with the screen off, whether that thud was theirs or the farmer's.
func _hurt() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.055)
	SoundBank.tone(samples, 88.0, 0.9, 0.055)
	SoundBank.hiss(samples, 0.4, 0.022, 53)
	SoundBank.soften(samples, 0.18)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## A body going down: a fall rather than an impact. The pitch drops away instead of ringing, which
## is the one shape in this whole set that nothing else uses — and it arrives from where the body
## was standing, so a kill behind the player still reads as a kill.
func _enemy_down() -> AudioStreamWAV:
	var samples := SoundBank.span(0.34)
	SoundBank.fall(samples, 340.0, 120.0, 0.7)
	SoundBank.hiss(samples, 0.35, 0.05, 59)
	SoundBank.soften(samples, 0.22)
	SoundBank.release(samples, 0.14)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## Finding a weapon. Two notes going up, which is the shortest way a game has ever said *that one
## is yours now*.
func _pickup() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.10, 0.07)
	SoundBank.tone(samples, 660.0, 0.5, 0.09)
	SoundBank.tone(samples, 990.0, 0.45, 0.10, 0.07)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## **The most important sound in the game, and the only one that rises.**
##
## Everything else here decays, because everything else reports something that already happened. A
## telegraph reports something that has not happened yet, so it goes the other way: the pitch and
## the level both climb, and the ear reads a climb as a thing arriving. That is a categorical
## difference rather than a matter of degree, which is what lets it survive three farmers, a fight
## and a player who has turned the music up.
##
## It releases at the end rather than swelling into the cut, or the buffer would stop dead at full
## amplitude — and a telegraph that ends in a click is a telegraph the player flinches at twice.
func _telegraph() -> AudioStreamWAV:
	return _telegraph_of(&"")


## The same shape at an archetype's own pitch. One climb rather than three hand-built warnings,
## because what must be shared is that it *rises* — and what must differ is where from and to.
func _telegraph_of(archetype: StringName) -> AudioStreamWAV:
	var voice: Dictionary = TELEGRAPHS.get(archetype, TELEGRAPHS[BASE_TELEGRAPH])
	var samples := SoundBank.span(float(voice["seconds"]))
	SoundBank.climb(samples, float(voice["from"]), float(voice["to"]), 0.75)
	SoundBank.hiss(samples, 0.16, 0.02, int(voice["grain"]))
	SoundBank.release(samples, 0.07)
	return SoundBank.bake(samples, _level(MixTable.TELEGRAPH_LEVEL))


## The last round in the magazine. Two short clicks a semitone apart, dry and quiet: running out is
## a **designed** moment and the answer to it is to close on the next farmer, which is a decision
## the player has to be able to make before the trigger stops answering rather than after.
##
## Deliberately not a musical interval and deliberately under the shot that carried it — it arrives
## in the same breath as a gunshot and must not be mistaken for part of one.
func _low_ammo() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.05, 0.07)
	SoundBank.tone(samples, 880.0, 0.6, 0.02)
	SoundBank.tone(samples, 932.0, 0.6, 0.05, 0.07)
	SoundBank.soften(samples, 0.30)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## A wave passed. Three notes up, and the only sound in the game allowed to be musical: it is the
## one moment nothing is trying to kill the player, so it is the one moment a chord costs nothing.
func _sting() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.42, 0.30)
	SoundBank.tone(samples, A, 0.5, 0.20)
	SoundBank.tone(samples, C, 0.5, 0.24, 0.15)
	SoundBank.tone(samples, E, 0.5, 0.42, 0.30)
	return SoundBank.bake(samples, _level(MixTable.STING_LEVEL))


## The counter opening. Two notes a fifth apart and nothing above them — quiet, warm and over
## quickly, because the merchant is a pause rather than an event and a sting here would tell the
## player something happened when what happened is that nothing is happening.
func _merchant() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.30, 0.09)
	SoundBank.tone(samples, A, 0.6, 0.22)
	SoundBank.tone(samples, E, 0.45, 0.30, 0.09)
	SoundBank.soften(samples, 0.25)
	return SoundBank.bake(samples, _level(MixTable.INCIDENTAL_LEVEL))


## The end of a run, either way. **The same three notes in the same order**, and the whole
## difference is where they go: up for a victory, down for a death. One shape, two readings —
## a player does not have to learn two sounds to know which one they got, and a summary screen that
## arrives in silence reads as the game having crashed rather than ended.
func _ending(victory: bool) -> AudioStreamWAV:
	var notes: Array[float] = [A * 2.0, E, A]
	if victory:
		notes = [A, E, A * 2.0]
	var samples := SoundBank.long_enough(ENDING_RING, ENDING_STEP * 2.0)
	for index: int in notes.size():
		var last := index == notes.size() - 1
		SoundBank.tone(
			samples,
			notes[index],
			0.5,
			ENDING_RING if last else ENDING_STEP * 1.6,
			ENDING_STEP * float(index)
		)
	return SoundBank.bake(samples, _level(MixTable.STING_LEVEL))


## The player going down: a yelp that falls away and cracks doing it.
##
## The famous one is a recording under copyright and there is no version of it this project could
## ship, so this is the same **joke** built out of the same parts — a voiced tone that slides down
## most of an octave while a noisy rasp on top falls with it, which is what a shout is. It is short
## and it is silly, and both of those are the point: a death is the one moment the game is allowed
## to stop taking itself seriously, and a long one would still be going while the summary arrives.
##
## Off the key deliberately, like the dry-fire warning. A death is not a musical event and a scream
## that landed on the tonic would read as the game approving.
func _death_cry() -> AudioStreamWAV:
	var samples := SoundBank.span(CRY_SECONDS)
	SoundBank.fall(samples, CRY_FROM, CRY_TO, 0.75)
	# The rasp. Noise that falls with the voice rather than sitting under it — a shout is a voice
	# that is breaking, and a steady hiss underneath reads as wind instead.
	SoundBank.hiss(samples, 0.30, CRY_SECONDS * 0.5, 97)
	SoundBank.soften(samples, 0.35)
	SoundBank.swell(samples, 0.03)
	SoundBank.release(samples, 0.16)
	return SoundBank.bake(samples, _level(MixTable.STING_LEVEL))


## A menu press. Two short tones a fifth apart and gone in a tenth of a second — the same interval
## everything tonal in this game is built on, so the menus are in the key the island is in.
func _click() -> AudioStreamWAV:
	var samples := SoundBank.long_enough(0.05, 0.02)
	SoundBank.tone(samples, 880.0, 0.5, 0.04)
	SoundBank.tone(samples, 1320.0, 0.35, 0.035, 0.02)
	return SoundBank.bake(samples, _level(MixTable.CLICK_LEVEL))


## The surf, and nothing else. It is the only sound here with no event behind it, and the only one
## that loops.
##
## Two slow swells at frequencies that do not divide into each other, so the bed never settles into
## a rhythm the ear can count — a wave every three seconds is a metronome, and a metronome under a
## fight is worse than silence.
func _surf() -> AudioStreamWAV:
	var noise := SoundBank.span(SURF_SECONDS + SURF_SEAM)
	SoundBank.hiss(noise, 0.9, INF, 67)
	SoundBank.soften(noise, 0.08)
	# Joined first, then breathed over what is left: the swells have to be whole across the buffer
	# that actually loops, not across the longer one the seam was cut out of.
	var samples := SoundBank.join(noise)
	SoundBank.breathe(samples, SURF_SWELLS, 0.55)
	SoundBank.breathe(samples, SURF_SWELLS + 1, 0.30)
	return SoundBank.bake_loop(samples, _level(MixTable.SURF_LEVEL))


## One layer of the music: a chord that breathes, built on the same seam the surf uses.
##
## Detuned rather than in unison. Two sines a few cents apart beat slowly against each other, which
## is the difference between a drone that is a sound and a drone that is a test tone — and it is
## free, where a filter sweep would not be.
##
## **Nothing here is rhythmic in the sense a fight is.** The swells are slow and their counts do not
## divide into each other, for the reason the surf's do not: a bed the ear can count against is a
## metronome, and a metronome is a thing the player starts fighting to instead of reading.
func _layer(id: StringName) -> AudioStreamWAV:
	var voice: Dictionary = LAYERS[id]
	var samples := SoundBank.span(MUSIC_SECONDS + SURF_SEAM)
	var root := float(voice["root"])
	for step: int in int(voice["voices"]):
		# A fifth above each time, which stacks without ever landing on a third — a bed with a mode
		# in it is a bed that has an opinion about the scene, and this one has to survive six
		# minutes of whatever the player is doing.
		#
		# **Three steps is the ceiling**, and it is not a taste: A, E, B are all in the home key and
		# the fourth is F sharp, which A minor does not contain. Two layers were reaching it, so the
		# one sound playing under every other sound in the game disagreed with the sting, the
		# merchant and both endings. `verify_mix` walks the table and holds it.
		var hertz := root * pow(1.5, float(step))
		SoundBank.tone(samples, hertz, 0.7 / float(step + 1), INF)
		SoundBank.tone(samples, hertz * DETUNE, 0.7 / float(step + 1), INF)
	var looped := SoundBank.join(samples)
	SoundBank.breathe(looped, int(voice["swells"]), 0.45)
	SoundBank.breathe(looped, int(voice["swells"]) + 1, 0.2)
	return SoundBank.bake_loop(looped, _level(MixTable.LAYER_LEVEL))


## The bed starts with the game and never stops. On its own bus, so a player who wants the island
## quiet and the fight loud has a slider that does exactly that.
##
## **Except where there is nobody to hear it.** A headless run has no audio output, and a stream
## still playing when the engine tears down is two objects it reports as leaked — the audio server
## releases a playback on its next iteration, and at quit there is no next iteration. That is
## engine behaviour and it is not specific to a loop; it is simply guaranteed by one, because a bed
## is playing at every moment including the last. CI fails a boot on any warning at all, and the
## right answer is to leave the gate alone rather than to teach it to ignore a real leak.
##
## The waveform is still built and still assigned, so the loop, its seam and its length are exactly
## as checkable headless as everything else here. The only thing skipped is the playing.
func _start_the_bed() -> void:
	_bed = SurfBed.new()
	add_child(_bed)


## The soundtrack, built here because music outlives scenes and this is the node that does too.
func _start_the_jukebox() -> void:
	_jukebox = Jukebox.new()
	_jukebox.name = "Jukebox"
	_jukebox.playlist = load(PLAYLIST) as MusicPlaylist
	add_child(_jukebox)


## The family the attack names, or the generic thud when it names none. The perfect one never gets
## jitter: a signature that moves is not one, and that holds for all three families.
func _on_attack_landed(_target: Node3D, _damage: float, perfect: bool, attack: AttackData) -> void:
	var family := attack.impact_sound if attack != null else &""
	var id := StringName("%s_%s" % ["perfect" if perfect else "hit", family])
	if not _sounds.has(id):
		id = &"perfect" if perfect else &"hit"
	play(id, 0.0 if perfect else JITTER)


## Only a weapon that moves through air makes the sound of moving through air. A shot that found
## nobody has already been heard — it cracked when the round left — and following it with a swish
## was the gun swinging an arm it does not have.
func _on_attack_whiffed(attack: AttackData) -> void:
	if attack != null and attack.is_hitscan:
		return
	play(&"whiff", SWING_JITTER)


## The report, and — on the round that leaves one behind — the warning. Running dry is a designed
## moment, and a player who only learns about it when the trigger stops answering has been told
## about it one round too late to do anything with it.
func _on_weapon_fired(attack: AttackData) -> void:
	if attack == null:
		return
	play(&"shot_heavy" if attack.charges else &"shot", JITTER)
	if GameState.loadout != null and GameState.loadout.magazine == LAST_ROUNDS:
		play(&"low_ammo")


func _on_parry_perfect() -> void:
	play(&"parry_perfect")


func _on_parry_late() -> void:
	play(&"parry_late")


func _on_footstep_taken(wading: bool) -> void:
	play(&"step_water" if wading else &"step_sand", STEP_JITTER)


## From where he is standing, and pitched a little differently each time. Three farmers committing
## together on one waveform would arrive as a single louder farmer, which is the opposite of what
## the sound is for.
func _on_merchant_opened() -> void:
	play(&"merchant")


## The yelp goes on the death, not on the summary. `run_ended` arrives a beat later and carries the
## screen; this is the body hitting the sand.
func _on_player_died() -> void:
	play(&"death_cry")


func _on_run_ended(victory: bool) -> void:
	play(&"victory" if victory else &"defeat")


func _on_telegraph_began(where: Vector3, archetype: EnemyData) -> void:
	var id := archetype.telegraph_sound if archetype != null else &""
	play_at(id if _sounds.has(id) else &"telegraph", where, JITTER)


func _on_enemy_died(enemy: Node3D, _archetype: StringName, _money: int) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	play_at(&"enemy_down", enemy.global_position, JITTER)


## The bus carries the health that resulted, so a drop is what a hit looks like from here — and a
## heal at the merchant must not sound like one. The same comparison the wave director makes to
## decide whether a wave was flawless.
func _on_player_damaged(current: float, _maximum: float) -> void:
	var dropped := _health_seen >= 0.0 and current < _health_seen
	_health_seen = current
	if dropped:
		play(&"hurt", JITTER)


## A roll and a reload are states, and the bus already says when the player enters one — the signal
## exists for exactly this. Cheaper than two more signals, and it cannot drift out of step with the
## animation, because it *is* the transition the animation plays.
func _on_player_state_changed(state: StringName) -> void:
	if state == &"Dodge":
		play(&"roll", JITTER)


func _on_weapon_found(_id: StringName) -> void:
	play(&"pickup")


func _on_weapon_reloaded() -> void:
	play(&"reload", JITTER)


func _on_weapon_dry_fired() -> void:
	play(&"dry_fire", JITTER)


func _on_wave_cleared(_wave: int, _reward: int) -> void:
	play(&"wave_cleared")
