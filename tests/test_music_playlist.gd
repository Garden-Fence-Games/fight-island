extends GdUnitTestSuite
## The shuffle bag, which is the whole of what "random music" means here.
##
## Worth a unit test rather than a scene check because it is pure logic over a list, and because the
## property that matters — everything gets played before anything repeats — is the kind a single
## run cannot show you.


func _track(named: String) -> MusicTrack:
	var track := MusicTrack.new()
	track.title = named
	# Any stream at all: `is_playable` asks whether there is a file, not what is in it.
	track.stream = AudioStreamWAV.new()
	return track


func _filled(count: int) -> MusicPlaylist:
	var list := MusicPlaylist.new()
	var tracks: Array[MusicTrack] = []
	for index: int in count:
		tracks.append(_track("track %d" % index))
	list.tracks = tracks
	return list


func test_an_empty_playlist_hands_out_nothing() -> void:
	var list := MusicPlaylist.new()
	assert_bool(list.is_empty()).is_true()
	assert_object(list.draw()).is_null()


func test_a_track_with_no_file_is_a_plan_rather_than_a_track() -> void:
	var list := MusicPlaylist.new()
	var planned := MusicTrack.new()
	planned.title = "not delivered yet"
	list.tracks = [planned] as Array[MusicTrack]
	assert_bool(list.is_empty()).is_true()
	assert_object(list.draw()).is_null()


func test_one_track_is_drawn_every_time() -> void:
	var list := _filled(1)
	for _index: int in 5:
		assert_object(list.draw()).is_not_null()


## The property the bag exists for: over one full round every track comes up exactly once.
func test_every_track_is_played_before_any_repeats() -> void:
	var list := _filled(5)
	var seen: Array[String] = []
	var last: MusicTrack = null
	for _index: int in 5:
		last = list.draw(last)
		seen.append(last.title)
	seen.sort()
	assert_array(seen).has_size(5)
	for index: int in 5:
		assert_str(seen[index]).is_equal("track %d" % index)


## And the seam between rounds, which is the one place a shuffle bag still lets a track follow
## itself: the last of one round and the first of the next.
func test_a_track_never_follows_itself_across_a_refill() -> void:
	var list := _filled(4)
	var last: MusicTrack = null
	for _index: int in 40:
		var next := list.draw(last)
		assert_object(next).is_not_same(last)
		last = next
