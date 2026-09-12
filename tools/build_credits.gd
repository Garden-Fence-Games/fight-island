extends SceneTree
## Bakes data/credits.tres from docs/credits.md.
##
## The document is what a contributor edits when they add an asset; this is what the game reads. The
## two are held together by `tools/verify_credits.tscn`, which fails the build if a row was added to
## one and not baked into the other — the drift that would otherwise show up as a missing row on the
## screen the player is shown to satisfy a licence.
##
## Run: godot --headless --path . --script tools/build_credits.gd

const OUTPUT: String = "res://data/credits.tres"


func _init() -> void:
	var roll := CreditsSource.parse()
	if roll == null:
		quit(1)
		return
	if roll.assets.is_empty() or roll.tools.is_empty():
		printerr(
			(
				"credits: %s gave no rows — the parser and the document disagree"
				% CreditsSource.DOCUMENT
			)
		)
		quit(1)
		return
	if ResourceSaver.save(roll, OUTPUT) != OK:
		printerr("credits: could not save " + OUTPUT)
		quit(1)
		return
	print("credits baked — %d assets, %d tools" % [roll.assets.size(), roll.tools.size()])
	quit(0)
