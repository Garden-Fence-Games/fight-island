class_name CreditsRoll
extends Resource
## Everything `docs/credits.md` credits, in the order the document credits it.
##
## Two lists because the document has two tables and they answer different questions: what went into
## the game, and what the game was built with. Baked by `tools/build_credits.gd`.

@export var assets: Array[CreditEntry] = []
@export var tools: Array[CreditEntry] = []


## Every row, both lists, for anything that only wants to count them.
func every() -> Array[CreditEntry]:
	var all: Array[CreditEntry] = []
	all.append_array(assets)
	all.append_array(tools)
	return all
