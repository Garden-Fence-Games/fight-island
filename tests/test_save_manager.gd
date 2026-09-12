extends GdUnitTestSuite
## The save file is the one thing in the game the player owns and can edit, so every way it can be
## wrong is a case here. All of it runs on paths of its own — a check that eats the developer's run
## is worse than no check.

const MINE: String = "user://test_save_manager.json"


func after_test() -> void:
	SaveManager.erase(MINE)


func test_what_goes_in_comes_back_out() -> void:
	assert_bool(SaveManager.write_versioned(MINE, {"wave": 7, "money": 130})).is_true()
	var back := SaveManager.read_versioned(MINE)
	assert_int(int(back["wave"])).is_equal(7)
	assert_int(int(back["money"])).is_equal(130)


## JSON has one number type, so every integer comes back a float. Every reader already casts, and
## the run seed is stored as *text* for the same reason — sixty-four bits do not survive a double,
## and losing its low bits brings the run back on a different island. Written down here because it
## is the kind of trap that is obvious once and never again.
func test_every_number_comes_back_a_float() -> void:
	SaveManager.write_versioned(MINE, {"wave": 7})
	assert_bool(SaveManager.read_versioned(MINE)["wave"] is float).is_true()


func test_a_file_is_stamped_with_the_build_that_wrote_it() -> void:
	SaveManager.write_versioned(MINE, {"wave": 1})
	var stamp: Variant = SaveManager.read_json(MINE)[SaveManager.VERSION_KEY]
	assert_int(int(stamp)).is_equal(SaveManager.VERSION)


## The caller's dictionary is theirs. Stamping it in place would put a version key into whatever
## live object it came from — `GameState.snapshot()` returns a fresh one today, and would not have
## to tomorrow.
func test_writing_does_not_stamp_the_callers_dictionary() -> void:
	var mine := {"wave": 3}
	SaveManager.write_versioned(MINE, mine)
	assert_bool(mine.has(SaveManager.VERSION_KEY)).is_false()


## A file from a build that does not exist yet is refused whole rather than read in halves. Nothing
## here can know what a field it has never heard of means, and guessing corrupts a save the player
## can still open with the build that wrote it.
func test_a_file_from_a_newer_build_is_refused() -> void:
	SaveManager.write_json(MINE, {"wave": 9, SaveManager.VERSION_KEY: SaveManager.VERSION + 1})
	assert_dict(SaveManager.read_versioned(MINE)).is_empty()


## Version nought is everything written before the stamp existed. It is still readable key for key,
## so it comes through rather than being thrown away.
func test_a_file_from_before_the_stamp_still_reads() -> void:
	SaveManager.write_json(MINE, {"wave": 4})
	assert_int(int(SaveManager.read_versioned(MINE)["wave"])).is_equal(4)


func test_a_file_that_is_not_there_reads_as_nothing() -> void:
	SaveManager.erase(MINE)
	assert_dict(SaveManager.read_versioned(MINE)).is_empty()


## Truncated, or a JSON array where an object belongs. Both are a player with a text editor, and
## both have to answer "use your defaults" rather than throw.
func test_a_broken_file_reads_as_nothing() -> void:
	for rubbish: String in ['{"wave": 3', "[1, 2, 3]", "", "not json at all"]:
		var file := FileAccess.open(MINE, FileAccess.WRITE)
		file.store_string(rubbish)
		file.close()
		assert_dict(SaveManager.read_versioned(MINE)).is_empty()


func test_erasing_a_file_that_is_not_there_is_not_an_error() -> void:
	SaveManager.erase(MINE)
	SaveManager.erase(MINE)
	assert_bool(FileAccess.file_exists(MINE)).is_false()


## The three files have three lifetimes, and sharing a path would give them one.
func test_the_three_files_are_three_files() -> void:
	var paths := [SaveManager.SETTINGS_PATH, SaveManager.RUN_PATH, SaveManager.PROGRESS_PATH]
	assert_array(paths).has_size(3)
	assert_int(_distinct(paths)).is_equal(3)


func _distinct(paths: Array) -> int:
	var seen: Array[String] = []
	for path: Variant in paths:
		if not seen.has(path):
			seen.append(path)
	return seen.size()
