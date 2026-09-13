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
