extends Node
## Proof that nothing ships without a row in `docs/credits.md`.
##
## The document states the rule in its own second line — **a file with no row does not ship** — and
## until this was written nothing enforced it. The intro video had been in the repository since the
## boot sequence was built and had never been credited; `verify_credits` holds the document against
## the baked resource and the screen, which is a different question entirely and cannot see a file
## nobody wrote down.
##
## What counts is anything under `assets/` that is **content** rather than a Godot sidecar: a model,
## a texture, a font, a sound, a video. Shaders, scenes and `.import` files are code and scene data,
## and crediting them would be crediting ourselves for writing the game.
##
## A row may name a family rather than a file — `farmer_01..09.wav` is one row for nine recordings,
## and nine rows saying the same thing would be worse. So the match is on the **directory and the
## stem up to its first digit**, which is what a family looks like written down.
## Run: godot --headless --path . res://tools/verify_shipped.tscn

const CREDITS: String = "res://docs/credits.md"
const ASSETS: String = "res://assets"
## Extensions that are content somebody made. `.import` is Godot's own, `.uid` likewise, and a
## `.gdshader` is source.
const CONTENT: Array[String] = [
	".glb",
	".gltf",
	".png",
	".jpg",
	".jpeg",
	".exr",
	".hdr",
	".svg",
	".ttf",
	".otf",
	".wav",
	".ogg",
	".mp3",
	".ogv",
	".webm",
	".blend"
]
## Directories under `assets/` that hold no third-party content at all. `locale` is a CSV this
## project writes; `themes` and `shaders` are ours.
const OURS: Array[String] = ["res://assets/locale", "res://assets/themes", "res://assets/shaders"]
## Fewer files than this means the walk stopped finding them, and a check that found nothing would
## report a tidy pass over an empty tree.
const AT_LEAST: int = 20

var _failures: PackedStringArray = []
var _document: String = ""
var _looked_at: int = 0


func _ready() -> void:
	_run()


func _run() -> void:
	var file := FileAccess.open(CREDITS, FileAccess.READ)
	if file == null:
		_fail("cannot read %s" % CREDITS)
		_report()
		return
	_document = file.get_as_text()
	_walk(ASSETS)
	if _looked_at < AT_LEAST:
		_fail("only %d shippable files were found, which is fewer than there are" % _looked_at)
	_report()


func _walk(directory: String) -> void:
	if OURS.has(directory):
		return
	for name: String in DirAccess.get_directories_at(directory):
		_walk("%s/%s" % [directory, name])
	for name: String in DirAccess.get_files_at(directory):
		var path := "%s/%s" % [directory, name.trim_suffix(".remap")]
		if not _is_content(path):
			continue
		_looked_at += 1
		if not _credited(path):
			_fail(
				(
					(
						"%s ships and has no row in %s — the document's own rule is that a file "
						+ "without one does not"
					)
					% [path.trim_prefix("res://"), CREDITS.get_file()]
				)
			)


func _is_content(path: String) -> bool:
	for extension: String in CONTENT:
		if path.ends_with(extension):
			return true
	return false


## Named outright, covered by a family, or carried in by the model it belongs to.
##
## A **family** is the directory plus the stem up to its first digit — `farmer_01.wav` is answered
## by a row naming `farmer_`, and nine rows saying the same thing would be worse than one.
##
## A **texture beside its model** is covered by that model's row, because it is the same asset: a
## glTF import writes the embedded images out as `model_something.png` next to `model.glb`, and
## crediting the model is crediting them. This is not a loophole — it is what a reader of the
## document already concludes, and writing six rows for `bird.glb`'s one image would make the
## document harder to check rather than easier.
func _credited(path: String) -> bool:
	var bare := path.trim_prefix("res://")
	if _document.contains(bare):
		return true
	var stem := bare.get_file().get_basename()
	var cut := stem.length()
	for index: int in stem.length():
		if stem[index].is_valid_int():
			cut = index
			break
	if _document.contains("%s/%s" % [bare.get_base_dir(), stem.substr(0, cut)]):
		return true
	return _a_credited_model_owns(bare, stem)


## Whether a model in the same directory both carries this file's name as a prefix and has a row of
## its own. The longest such model wins, so `bird_fly_bird_fly.png` is answered by `bird_fly.glb`
## rather than by `bird.glb` — which matters, because one of those had a row and the other did not.
func _a_credited_model_owns(bare: String, stem: String) -> bool:
	if not (bare.ends_with(".png") or bare.ends_with(".jpg") or bare.ends_with(".jpeg")):
		return false
	var directory := bare.get_base_dir()
	var owner := ""
	for name: String in DirAccess.get_files_at("res://%s" % directory):
		var model := name.trim_suffix(".remap")
		if not (model.ends_with(".glb") or model.ends_with(".gltf")):
			continue
		var base := model.get_basename()
		if stem.begins_with("%s_" % base) and base.length() > owner.length():
			owner = base
	if owner.is_empty():
		return false
	return _document.contains("%s/%s" % [directory, owner])


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("shipped OK — all %d files that ship have a row that says who made them" % _looked_at)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		printerr("shipped FAILED — %s" % failure)
	get_tree().quit(1)
