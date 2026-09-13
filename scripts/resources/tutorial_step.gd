class_name TutorialStep
extends Resource
## One line of the opening tutorial. The order, the wording and how long each line stays are data,
## so changing any of them is an inspector edit and never a script edit.
##
## A step knows nothing about how it is drawn — see `TutorialPrompt` — and nothing about what the
## player does while it is up: the lines move on with the clock, not with a button.

@export var id: StringName = &""
## A localisation key, never a literal. Each `{n}` in the string is the glyph of the n-th action in
## `prompt_actions`, on the device in hand.
@export var prompt_key: String = ""
## The actions the line names, in the order its placeholders use them. Empty for a line that names
## no button.
@export var prompt_actions: PackedStringArray = []
## How long the line stays on screen, in seconds, before the next one replaces it.
@export var seconds: float = 4.0
