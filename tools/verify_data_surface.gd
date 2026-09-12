extends Node
## Headless proof that **`docs/architecture.md` only names fields that exist.**
##
## `data/` is called the balance surface in that document, and the document enumerates it: each
## `Resource` gets a bullet listing what it carries. Those bullets are what somebody reads before
## touching balance, and they had drifted badly enough to describe a design that was never built —
## `UpgradeTrack` was written up as an `icon`, a `max_level` and an `Array[UpgradeLevel]`, and
## `UpgradeLevel` has never existed. `AttackData` was credited with an `sfx` nothing ever had and a
## `range` that is really `reach`. `WeaponData` had a `model` and an `upgrade_track`, neither real.
##
## A wrong field list is worse than no field list. It is the one document trusted enough that
## nobody checks it against the code, so it sends whoever reads it looking for a property that is
## not there — or, worse, designing against one.
##
## The rule is narrow on purpose: **every field the document names has to exist.** Fields the
## document leaves out are not failures, because a bullet is a summary and choosing what to leave
## out is editing. Naming something that is not there is not editing; it is being wrong.
##
## It reads the document, the same way `verify_waves` reads `docs/game-design.md` and
## `verify_credits` reads `docs/credits.md`. The balance surface already has one check holding the
## numbers to the table; this one holds the table to the code.
## Run: godot --headless --path . res://tools/verify_data_surface.tscn

const DOC: String = "res://docs/architecture.md"
## The section that enumerates the surface. Bounded, so a backticked word anywhere else in a
## thousand-line document is never mistaken for a field.
const OPENS: String = "## Data-driven balance"
const CLOSES: String = "## Autoloads"
## Every resource the section can talk about, by the name it is written under. A bullet for a class
## that is not in here fails rather than being skipped: a section that has grown a ninth resource
## should not quietly stop being checked.
const CLASSES: Dictionary = {
	"AttackData": "res://scripts/resources/attack_data.gd",
	"EnemyData": "res://scripts/resources/enemy_data.gd",
	"WeaponData": "res://scripts/resources/weapon_data.gd",
	"UpgradeTrack": "res://scripts/resources/upgrade_track.gd",
	"WaveConfig": "res://scripts/resources/wave_config.gd",
	"WaveBand": "res://scripts/resources/wave_band.gd",
	"DayPhase": "res://scripts/resources/day_phase.gd",
	"DayCycle": "res://scripts/resources/day_cycle.gd",
	"EliteRank": "res://scripts/resources/elite_rank.gd",
	"TutorialStep": "res://scripts/resources/tutorial_step.gd",
	"ArchetypeShare": "res://scripts/resources/archetype_share.gd",
}

var _failures: PackedStringArray = []


func _ready() -> void:
	_run()


func _run() -> void:
	var lines := _the_section()
	if lines.is_empty():
		_fail("could not find the %s section in %s" % [OPENS, DOC])
		_report()
		return
	var claimed := 0
	for bullet: String in _bullets(lines):
		var owner := _class_named_by(bullet)
		if owner.is_empty():
			continue
		if not CLASSES.has(owner):
			_fail(
				(
					(
						"the section has a bullet for %s, which this check has never heard of — "
						+ "add it to CLASSES or the document has grown a resource nobody verifies"
					)
					% owner
				)
			)
			continue
		for field: String in _fields_named_in(bullet):
			claimed += 1
			if not _has_field(owner, field):
				_fail("%s is credited with `%s`, and it has no such field" % [owner, field])
	# A section that suddenly names nothing would pass every assertion above while telling the
	# reader nothing, and that is the failure this catches.
	if claimed < 20:
		_fail("only %d fields were claimed by the whole section — the parse is broken" % claimed)
	_report()


## The lines between the two headings, so nothing outside the surface is read as part of it.
func _the_section() -> PackedStringArray:
	var file := FileAccess.open(DOC, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var kept := PackedStringArray()
	var inside := false
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with(OPENS):
			inside = true
			continue
		if inside and line.begins_with(CLOSES):
			break
		if inside:
			kept.append(line)
	file.close()
	return kept


## The class a bullet introduces, from `- **`ClassName`** — …`, or empty for any other line. The
## bullets are the only thing that says which resource the fields after it belong to.
func _class_named_by(line: String) -> String:
	var trimmed := line.strip_edges()
	if not trimmed.begins_with("- **`"):
		return ""
	var from := trimmed.find("`") + 1
	var to := trimmed.find("`", from)
	return trimmed.substr(from, to - from) if to > from else ""


## One bullet per entry, rejoined across the lines it wraps onto. A bullet's fields are spread over
## three or four lines in this document, and a line at a time cannot tell an enumeration from the
## prose that follows it.
func _bullets(lines: PackedStringArray) -> PackedStringArray:
	var found := PackedStringArray()
	var building := ""
	for line: String in lines:
		if line.strip_edges().begins_with("- **`"):
			if not building.is_empty():
				found.append(building)
			building = line.strip_edges()
		elif not building.is_empty():
			if line.strip_edges().is_empty():
				found.append(building)
				building = ""
			else:
				building += " " + line.strip_edges()
	if not building.is_empty():
		found.append(building)
	return found


## Every backticked token in a bullet's **enumeration**, which the document consistently writes
## between the em dash that opens the bullet and the next one — after which it is explaining rather
## than listing.
##
## That boundary is what tells a field from prose, and it took a red run to find: `WeaponData`'s
## bullet ends with "so `walk` becomes `walk_gun`", and both were reported as missing fields. They
## are clip names in a sentence. Anything after the second dash is a sentence.
##
## Snake case and nothing else, so `PascalCase` type names, `Array[DayPhase]` and
## `docs/game-design.md` are never mistaken for fields. A trailing `: Type` is dropped, because the
## document writes both `phases: Array[DayPhase]` and a bare `id` and means a field by each.
func _fields_named_in(bullet: String) -> PackedStringArray:
	var found := PackedStringArray()
	var opens := bullet.find("—")
	if opens < 0:
		return found
	var listing := bullet.substr(opens + "—".length())
	var closes := listing.find("—")
	if closes >= 0:
		listing = listing.substr(0, closes)
	var parts := listing.split("`")
	# Odd indices are the insides of the backtick pairs.
	for index: int in range(1, parts.size(), 2):
		var token := parts[index].strip_edges()
		var colon := token.find(":")
		if colon > 0:
			token = token.substr(0, colon).strip_edges()
		if _looks_like_a_field(token):
			found.append(token)
	return found


func _looks_like_a_field(token: String) -> bool:
	if token.is_empty() or token.length() > 40:
		return false
	for index: int in token.length():
		var letter := token[index]
		var lower := letter >= "a" and letter <= "z"
		var digit := letter >= "0" and letter <= "9"
		if not lower and not digit and letter != "_":
			return false
	# A single bare word can be prose as easily as a field — `on`, `off`, `one`. Anything the
	# document names that is genuinely a field and genuinely one word is still checked, because
	# those read as fields only inside a resource bullet, which is the only place this is called.
	return true


## Whether the class really carries the field, asked of a fresh instance rather than of the source
## text: a property list is what the engine and the inspector actually see, so it cannot be fooled
## by a name that appears in a comment.
func _has_field(owner: String, field: String) -> bool:
	var made := _instance_of(owner)
	if made == null:
		_fail("%s could not be instanced from %s" % [owner, CLASSES[owner]])
		return true
	for property: Dictionary in made.get_property_list():
		if str(property.get("name", "")) == field:
			return true
	return false


func _instance_of(owner: String) -> Resource:
	var script := load(str(CLASSES[owner])) as GDScript
	if script == null:
		return null
	return script.new() as Resource


func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				"data surface OK — every field docs/architecture.md names on a balance resource "
				+ "is a field that resource actually has"
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("data surface FAILED — %s" % failure)
	get_tree().quit(1)
