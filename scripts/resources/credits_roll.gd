class_name CreditsRoll
extends Resource
## Everything `docs/credits.md` credits, in the order the document credits it.
##
## Four lists because the document has four tables and they answer different questions: **whose game
## it is**, who made it, what went into it, and what it was built with. Baked by
## `tools/build_credits.gd`.

@export var studio: Array[CreditEntry] = []
@export var people: Array[CreditEntry] = []
@export var assets: Array[CreditEntry] = []
@export var tools: Array[CreditEntry] = []


## Every row, every list, for anything that only wants to count them.
func every() -> Array[CreditEntry]:
	var all: Array[CreditEntry] = []
	all.append_array(studio)
	all.append_array(people)
	all.append_array(assets)
	all.append_array(tools)
	return all
