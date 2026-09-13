class_name MusicTrack
extends Resource
## One piece of music: what it is called, who made it, and the file it plays from.
##
## **The title is data, not a filename.** A player showing `battle_theme_02_final` is a player
## showing a build artefact, and a track renamed on disk would rename it on screen. So the name the
## jukebox displays is written here and the file is a separate field.
##
## `stream` is null until the music is delivered. A track with no stream is not an error and is not
## skipped quietly either — `MusicPlaylist` refuses to hand one out, so a playlist half filled in
## plays the half that exists rather than falling silent on the first gap.

## What the player sees. Not localised: a title is a name, and names are not translated.
@export var title: String = ""
## Who it is by, shown after the title when there is one. Also what `docs/credits.md` has to carry
## before the track can ship.
@export var artist: String = ""
@export var stream: AudioStream = null
## **How loud this file already is**, in the loudness the mix table is written in — the loudest RMS
## over any 0.3 s. Measured once, when the track is added, and written down because the streams are
## MP3 and there is nothing to measure at load.
##
## Per track rather than one figure for the soundtrack, and that is not tidiness: these five masters
## span six decibels, so a single average plays one of them six louder than another and the player
## hears the level jump every time a track changes. What the table declares is what a track should
## be worth at the ear; this is what turns each file into that.
##
## Re-measure by decoding and taking the loudest 0.3 s window:
## `ffmpeg -v error -i track.mp3 -ac 1 -ar 44100 -f s16le - | <max short-term RMS>`
@export var as_recorded: float = 0.0


## Whether this track can actually be played. A row in the playlist with no file yet is a plan, not
## a track, and the jukebox has to be able to tell the difference.
func is_playable() -> bool:
	return stream != null


## Title and artist as one line, for the player in the corner. Falls back to the title alone, and
## then to nothing at all rather than to a placeholder nobody chose.
func billing() -> String:
	if title.is_empty():
		return ""
	return "%s — %s" % [title, artist] if not artist.is_empty() else title
