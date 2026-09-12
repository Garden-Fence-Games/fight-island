class_name Upgrades
extends RefCounted
## The five tracks, loaded from `data/upgrades/` once. Static because the list is the contents of a
## directory and nothing about it belongs to a scene.
##
## The order is the order of the cards, and it is the order of the files — health, stamina, then
## the three weapons, which is the order the design lays them out and the order a player buys them
## in often enough that shuffling it would cost them a habit.

const DIRECTORY: String = "res://data/upgrades"
const ORDER: PackedStringArray = ["health", "stamina", "fists", "stick", "gun"]

static var _tracks: Array[UpgradeTrack] = []


static func all() -> Array[UpgradeTrack]:
	if not _tracks.is_empty():
		return _tracks
	for name: String in ORDER:
		var track := load("%s/%s.tres" % [DIRECTORY, name]) as UpgradeTrack
		if track != null:
			_tracks.append(track)
	return _tracks


static func find(id: StringName) -> UpgradeTrack:
	for track: UpgradeTrack in all():
		if track.id == id:
			return track
	return null
