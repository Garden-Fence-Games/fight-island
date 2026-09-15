extends Node
## Proof that nothing looks a node up by path while the game is running.
##
## `docs/architecture.md` promises `@onready` everywhere and no `get_node` per frame, and issue #31
## carries it as a line nobody had ever audited. A path lookup walks the tree by name and returns a
## different answer if anybody renames a node — so the cost is the smaller half of the objection.
## The larger half is that a lookup in a hot body is a **silent** dependency on a scene's shape,
## and the day it returns null it does so sixty times a second in the middle of a fight.
##
## Read off the source rather than measured, because the thing being held is "nobody wrote this",
## and a profiler cannot tell a lookup that ran from one that was merely there waiting for a branch.
##
## **One file deep.** A per-frame body and every private helper it calls *in the same script* are
## searched; a call into another object is not followed. That is a real limit and it is the right
## one to stop at — following `aim.direction()` into `AimComponent` would mean writing a resolver
## for a language this project already has a compiler for. What it buys is that the hot bodies
## themselves, which is where somebody actually reaches for `get_node`, cannot go quietly wrong.
## Run: godot --headless --path . res://tools/verify_lookups.tscn

const ROOTS: Array[String] = ["res://scripts", "res://tools"]
## The bodies that run every frame. `physics_update` and `update` are here because `StateMachine`
## calls them from its own `_physics_process` — a state's body is as hot as the machine driving it,
## and they are the longest functions in the project.
const PER_FRAME: Array[String] = [
	"_process", "_physics_process", "physics_update", "update", "_integrate_forces"
]
## What may not appear in one. `get_child` is left out deliberately: it takes an index rather than a
## name, so it neither walks nor breaks when a node is renamed.
const LOOKUPS: Array[String] = [
	"get_node(", "get_node_or_null(", "find_child(", "find_children(", "get_node_and_resource("
]
## Scripts that are allowed one. `StateMachine` resolves a state by name — that is the whole of what
## it does, it happens on a transition rather than on a frame, and the alternative is a dictionary
## that says the same thing less clearly.
const ALLOWED: Array[String] = ["res://scripts/components/state_machine.gd"]

## Where a component lives, and the classes that are actors rather than parts.
const COMPONENTS: String = "res://scripts/components"
const ACTORS: PackedStringArray = ["Player", "Enemy"]

var _failures: PackedStringArray = []
var _searched: int = 0
## How many lines were actually looked at. A parser that silently returns nothing is the one way
## every check below passes while holding nothing, and it is how this one shipped its first draft.
var _lines: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	for root: String in ROOTS:
		_walk(root)
	_check_no_component_names_its_owner()
	if _searched == 0:
		_fail("no per-frame body was found at all, so nothing was searched")
	if _lines == 0:
		_fail(
			(
				(
					"%d per-frame bodies were found and every one of them was empty — the parser is "
					+ "reading nothing"
				)
				% _searched
			)
		)
	_report()


## **A component may not type the thing that carries it.** `docs/architecture.md` opens on the rule
## — behaviour is assembled from components that neither know nor care who owns them — and
## `UpgradeComponent` broke it while its own docstring claimed to follow it, which is the shape that
## survives review: a file that reads as evidence the rule holds.
##
## Naming an actor is fine; `AimComponent` casts a **target** to `Enemy` and should. What is not
## fine is casting the parent or the owner, because that is the compile-time dependency that stops a
## merchant, an ally or a second body from carrying the same component.
func _check_no_component_names_its_owner() -> void:
	for name: String in DirAccess.get_files_at(COMPONENTS):
		if not name.ends_with(".gd"):
			continue
		var path := COMPONENTS.path_join(name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var number := 0
		for line: String in file.get_as_text().split("\n"):
			number += 1
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for owner_word: String in ["get_parent()", "owner"]:
				if not code.contains(owner_word):
					continue
				for actor: String in ACTORS:
					if code.contains("as %s" % actor):
						_fail(
							(
								(
									"%s:%d types what carries it as %s, and a component is not owed an "
									+ "owner"
								)
								% [path, number, actor]
							)
						)
	_searched += 1


func _walk(directory: String) -> void:
	for name: String in DirAccess.get_directories_at(directory):
		_walk("%s/%s" % [directory, name])
	for name: String in DirAccess.get_files_at(directory):
		if name.ends_with(".gd"):
			_read("%s/%s" % [directory, name.trim_suffix(".remap")])


func _read(path: String) -> void:
	if ALLOWED.has(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_fail("cannot read %s" % path)
		return
	var bodies := _bodies(file.get_as_text().split("\n"))
	for name: String in bodies:
		if not PER_FRAME.has(name):
			continue
		_searched += 1
		_search(path, name, bodies, {})


## Every function in the file, by name, as the lines of its body. Indentation is the whole parser:
## a function ends at the next line that starts in column zero, which is what GDScript means.
##
## The bodies are `Array[String]` and not `PackedStringArray`, and that is not a preference. A
## packed array is a **value**: `bodies[name].append(line)` appends to a copy and throws it away, so
## the first version of this collected forty-two per-frame bodies and every one of them was empty —
## a check that searched nothing and said it had.
func _bodies(lines: PackedStringArray) -> Dictionary:
	var bodies: Dictionary = {}
	var name := ""
	for line: String in lines:
		if line.begins_with("func ") or line.begins_with("static func "):
			name = _name_of(line)
			bodies[name] = [] as Array[String]
		elif not line.is_empty() and not line.begins_with("\t") and not line.begins_with("#"):
			name = ""
		elif not name.is_empty():
			(bodies[name] as Array[String]).append(line)
	return bodies


func _name_of(line: String) -> String:
	var after := line.trim_prefix("static ").trim_prefix("func ")
	var bracket := after.find("(")
	return after.substr(0, bracket) if bracket > 0 else after


## One body and everything it calls within the file. `seen` is what stops a pair of helpers that
## call each other from being followed for ever.
func _search(path: String, name: String, bodies: Dictionary, seen: Dictionary) -> void:
	if seen.has(name) or not bodies.has(name):
		return
	seen[name] = true
	_lines += (bodies[name] as Array[String]).size()
	for line: String in bodies[name] as Array[String]:
		var code := line.strip_edges()
		if code.begins_with("#"):
			continue
		for lookup: String in LOOKUPS:
			if code.contains(lookup):
				_fail(
					"%s looks a node up by path in %s: %s" % [path.get_file(), name, code.left(70)]
				)
		for called: String in bodies:
			if called != name and code.contains("%s(" % called):
				_search(path, called, bodies, seen)


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print(
			(
				(
					"lookups OK — %d lines across %d per-frame bodies, and none of them walks the "
					+ "tree by name"
				)
				% [_lines, _searched]
			)
		)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("lookups FAILED — %s" % failure)
	get_tree().quit(1)
