class_name SoundBank
extends RefCounted
## How to shape a buffer and turn it into a waveform. No opinion about this game.
##
## Split out of `AudioManager` when that file reached the thousand-line ceiling, and the line it was
## split on is a real one rather than a convenience: everything here is signal work — a decaying
## sine, noise, a swell, a loop seam, sixteen-bit packing — and none of it knows what a telegraph is
## or how loud a footfall should be. What each of this game's sounds actually *is* stays
## next to the tables that decide it.
##
## Static, because none of it holds anything. The buffers are passed in and written in place, which
## is what lets a sound be assembled from a handful of these calls in the order a reader would say
## them out loud.

## Enough for a thud and a ring; the highest partial here is under 3 kHz. Halving the rate halves
## the bytes and changes nothing anybody can hear.
const MIX_RATE: int = 22050
## A waveform that starts or ends at full amplitude clicks. Two milliseconds is inaudible and
## enough to stop it.
const RAMP: float = 0.002
## How many time constants a buffer runs for. Six puts the slowest partial at a four-hundredth of
## itself, which is inaudible — and a buffer that ends while the sound is still going does not fade
## out, it stops dead. The length is derived from the decays rather than typed next to them, because
## a decay tuned by ear and a length left behind is a click nobody hears in a diff.
const DECAYED: float = 6.0
## How much of the bed's tail is folded back over its head to make the seam. A loop assembled from
## noise has no natural join; this is what stops the wrap being an audible tick every few seconds.
const SURF_SEAM: float = 0.25
## What a loudness figure is taken over. Three tenths of a second is about what the ear integrates
## over, and it is the difference between how loud a sound is and how tall it is.
const LOUDNESS_WINDOW: float = 0.3
## The tallest sample anything baked here may reach. Sine partials are summed, so a raw buffer can
## pass one; this is the line normalisation brings it back under, and a loudness target that would
## need more than this to reach does not get it.
const PEAK: float = 0.9


## Sized from the slowest decay the sound is about to use, and from how late the last of it starts,
## so nothing is ever cut off mid-ring.
static func long_enough(slowest_decay: float, last_starts_at: float = 0.0) -> PackedFloat32Array:
	return span(last_starts_at + slowest_decay * DECAYED)


## A buffer of exactly this many seconds, for the sounds whose length is designed rather than
## derived from a decay — a telegraph is as long as the warning needs to be.
static func span(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(maxi(int(seconds * float(MIX_RATE)), 2))
	return samples


## A decaying sine, added in. `decay` is the time constant, so the partial is down to a thirtieth of
## itself after three of them. `at` is when it starts, for the sounds that are two notes rather than
## a chord.
static func tone(
	samples: PackedFloat32Array, hertz: float, amplitude: float, decay: float, at: float = 0.0
) -> void:
	var step := TAU * hertz / float(MIX_RATE)
	var from := mini(int(at * float(MIX_RATE)), samples.size())
	for index: int in range(from, samples.size()):
		var seconds := float(index - from) / float(MIX_RATE)
		samples[index] += sin(step * float(index - from)) * amplitude * exp(-seconds / decay)


## Decaying noise, from a seeded source so the waveform is the same on every machine and every run.
## A signature that is regenerated differently each launch is not a signature. An infinite decay is
## noise that never falls away, which is what a bed is made of.
static func hiss(
	samples: PackedFloat32Array, amplitude: float, decay: float, seed_value: int, at: float = 0.0
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var from := mini(int(at * float(MIX_RATE)), samples.size())
	for index: int in range(from, samples.size()):
		var seconds := float(index - from) / float(MIX_RATE)
		samples[index] += rng.randf_range(-1.0, 1.0) * amplitude * exp(-seconds / decay)


## A sine whose pitch climbs across the whole buffer while its level climbs with it. The phase is
## carried rather than recomputed from the index: a frequency that changes means the angle has to be
## integrated, and `sin(t × f(t))` is a different and much worse sound than a sweep.
static func climb(
	samples: PackedFloat32Array, from_hertz: float, to_hertz: float, amplitude: float
) -> void:
	var phase := 0.0
	var last := float(maxi(samples.size() - 1, 1))
	for index: int in samples.size():
		var through := float(index) / last
		phase += TAU * lerpf(from_hertz, to_hertz, through) / float(MIX_RATE)
		samples[index] += sin(phase) * amplitude * through


## The same, going down and fading out — a fall rather than an arrival.
static func fall(
	samples: PackedFloat32Array, from_hertz: float, to_hertz: float, amplitude: float
) -> void:
	var phase := 0.0
	var last := float(maxi(samples.size() - 1, 1))
	for index: int in samples.size():
		var through := float(index) / last
		phase += TAU * lerpf(from_hertz, to_hertz, through) / float(MIX_RATE)
		samples[index] += sin(phase) * amplitude * (1.0 - through)


## A one-pole low pass, run once over the buffer. Enough to turn white noise into air.
static func soften(samples: PackedFloat32Array, weight: float) -> void:
	var carried := 0.0
	for index: int in samples.size():
		carried += (samples[index] - carried) * weight
		samples[index] = carried


## Fades a sound in over its first stretch, which is what makes noise read as a swing passing rather
## than as something being hit.
static func swell(samples: PackedFloat32Array, seconds: float) -> void:
	var over := maxi(int(seconds * float(MIX_RATE)), 1)
	for index: int in mini(over, samples.size()):
		samples[index] *= float(index) / float(over)


## Fades a sound out over its last stretch. The mirror of `_swell`, and what a sound that rises has
## to end with: a buffer that stops at full amplitude does not finish, it is interrupted.
##
## **Squared, where the swell is linear.** A linear fade is still at a fiftieth of full a couple of
## milliseconds from the end, which is audible as a stop — and it is exactly what the cut-off check
## measures, because a tail that is still there when the buffer runs out is a tail that was cut. The
## square drops the last two milliseconds to well under a thousandth while leaving the shape of the
## fade, which the ear reads, untouched.
static func release(samples: PackedFloat32Array, seconds: float) -> void:
	var over := maxi(int(seconds * float(MIX_RATE)), 1)
	var last := samples.size() - 1
	for index: int in mini(over, samples.size()):
		var through := float(index) / float(over)
		samples[last - index] *= through * through


## A slow rise and fall across the whole buffer, counted in whole swells rather than in hertz. This
## is what turns a flat hiss into water: the noise does not change, the amount of it does.
##
## **Whole cycles, which is why the count is an integer.** A fractional swell would leave the bed at
## a different level from the one it started at, and the seam would then have to hide a step in
## volume as well as a step in the noise — which is the one thing a cross-fade cannot do.
static func breathe(samples: PackedFloat32Array, swells: int, depth: float) -> void:
	var last := float(maxi(samples.size() - 1, 1))
	var turns := float(maxi(swells, 1))
	for index: int in samples.size():
		var through := float(index) / last
		samples[index] *= 1.0 - depth + depth * (0.5 - 0.5 * cos(TAU * turns * through))


## Ramped off the zero line, normalised to the level it was asked for, and packed to 16-bit.
## Normalising rather than trusting the sum is what keeps a fourth partial from silently clipping
## the other three; asking for a level rather than sharing one is what keeps a footfall under a hit.
##
## **The ramp goes on before the level is measured, not after.** A short sound is loudest within a
## millisecond or two of starting — a dry click is nothing else — so a ramp applied afterwards eats
## the very samples the normalisation was aimed at, and the sound comes out under what it asked for.
## The dry trigger landed at 0.33 against the 0.55 it declared, which is how a mix that was written
## down as a table stops being the mix that plays.
static func bake(samples: PackedFloat32Array, level: float) -> AudioStreamWAV:
	var ramp := maxi(int(RAMP * float(MIX_RATE)), 1)
	var last := samples.size() - 1
	for index: int in mini(ramp, samples.size()):
		samples[index] *= float(index) / float(ramp)
		samples[last - index] *= float(index) / float(ramp)
	return wav(encode(samples, samples.size(), scale_to_loudness(samples, level)), false)


## The same, for the one sound that comes back round.
##
## **A loop may not be ramped.** The two millisecond fade that stops a one-shot clicking is, on a
## loop, a hole punched in the bed every time it wraps — so there is no ramp here at all, and the
## join is made by `_join` before anything is shaped.
static func bake_loop(samples: PackedFloat32Array, level: float) -> AudioStreamWAV:
	return wav(encode(samples, samples.size(), scale_to_loudness(samples, level)), true)


## Folds a buffer's tail back over its head and returns it short by exactly that much, so the result
## meets itself where it wraps. Noise has no natural join; this makes one.
##
## **It has to run before the envelope, not after.** Shaping first and cutting second was the first
## version and it left a seam 33% apart in level: whole swells across the *whole* buffer are not
## whole swells across what is kept, so the bed came back round to a different point in its own
## breathing. Join the noise, then breathe over what survived.
static func join(samples: PackedFloat32Array) -> PackedFloat32Array:
	var seam := mini(maxi(int(SURF_SEAM * float(MIX_RATE)), 1), samples.size() / 2)
	var kept := samples.size() - seam
	for index: int in seam:
		var through := float(index) / float(seam)
		samples[index] = samples[index] * through + samples[kept + index] * (1.0 - through)
	samples.resize(kept)
	return samples


static func encode(samples: PackedFloat32Array, count: int, scale: float) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index: int in count:
		bytes.encode_s16(index * 2, int(clampf(samples[index] * scale, -1.0, 1.0) * 32767.0))
	return bytes


## The samples back out of a baked stream, for the checks that ask what the engine is actually
## holding and for the one place that needs a waveform's height after the fact.
static func samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var bytes := stream.data
	out.resize(bytes.size() / 2)
	for index: int in out.size():
		out[index] = float(bytes.decode_s16(index * 2)) / 32768.0
	return out


static func peak_of(samples: PackedFloat32Array) -> float:
	var loudest := 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	return loudest


## **How loud a buffer is, as opposed to how tall it is.** The loudest root-mean-square the buffer
## reaches over any `LOUDNESS_WINDOW`, which is roughly what the ear integrates over.
##
## This exists because peak is a bad yardstick for a mix and the whole table used to be written in
## it. Two sounds normalised to the same peak are not the same loudness and are not close: a
## decaying sine spends nearly all its length near silence, while noise that never stops sits at its
## own average the whole way through. Measured across this game's own sounds the gap reached
## seventeen decibels at an identical peak.
##
## The window is taken as a maximum rather than as an average over the whole buffer, for the reason
## a tail should not buy a sound quiet: a parry that rings for a second and a half is as loud as its
## loudest moment, not as loud as its average with the silence afterwards.
static func loudness(samples: PackedFloat32Array) -> float:
	var count := samples.size()
	if count == 0:
		return 0.0
	var span := mini(maxi(int(LOUDNESS_WINDOW * float(MIX_RATE)), 1), count)
	var running := 0.0
	var loudest := 0.0
	for index: int in count:
		running += samples[index] * samples[index]
		if index >= span:
			running -= samples[index - span] * samples[index - span]
		if index >= span - 1:
			loudest = maxf(loudest, running / float(span))
	return sqrt(loudest)


## The scale that puts a buffer at the loudness it asked for, **and never past the ceiling**.
##
## A loudness target says nothing about a buffer's tallest sample, so a sound with a wide crest —
## the impacts are sixteen decibels from average to peak — can ask for a modest loudness and still
## want more than full scale to reach it. When that happens the peak wins and the sound comes out
## quieter than it asked for, which `verify_audio` sees and reports rather than letting it pass as
## the level on the table.
static func scale_to_loudness(samples: PackedFloat32Array, level: float) -> float:
	var heard := loudness(samples)
	if heard <= 0.0:
		return 0.0
	var tallest := peak_of(samples)
	if tallest * (level / heard) > PEAK:
		return PEAK / tallest
	return level / heard


static func wav(bytes: PackedByteArray, looping: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = bytes.size() / 2 - 1
	return stream
