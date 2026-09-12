class_name CreditEntry
extends Resource
## One row of `docs/credits.md`, as the game shows it.
##
## Never written by hand: `tools/build_credits.gd` reads the document and bakes `data/credits.tres`,
## and `tools/verify_credits.tscn` fails if the two have drifted. A credits screen maintained beside
## the document is a second list of the same assets, and the way it goes wrong is that the one the
## player sees is missing a row.

## What is being credited — a file path, or the name of an engine or an addon.
@export var subject: String = ""
## Where it came from, with the link text and the link kept apart so the screen can show one and
## point at the other.
@export var source: String = ""
@export var source_url: String = ""
@export var author: String = ""
@export var licence: String = ""
