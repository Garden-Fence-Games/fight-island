# 0006 — `@onready` for a node's own children, not `@export`

**Status:** Accepted
**Date:** 2026-09-11

## Context

`docs/conventions.md` says to prefer `@export var target: Node3D` over `get_node("../../Foo")`, to
stop scripts reaching across the tree. Applied literally, every component reference on the player
and the enemy became an exported node property.

Those properties are stored in a `.tscn` as `health = NodePath("Health")`. **A hand-written scene
file that spells them that way does not resolve them** — the property stays null, and the failure
is silent: the scene loads, the game boots, and the first call into the component dies with
`Nonexistent function 'halt' in base 'Nil'`, several frames and one state machine away from the
cause. Resource exports (`weapon`, `data`) resolve from the same file without trouble.

## Decision

A node's **own children** are resolved with `@onready var health: HealthComponent = $Health`.
`@export` stays for resources, and for references to something genuinely outside the scene.

References that cross scenes are found by group: the camera rig and the debug overlay both take
the player from `get_first_node_in_group(&"player")` rather than a path into a sibling scene.

## Consequences

- The child names of `player.tscn` and `enemy.tscn` are a contract. Renaming `Health` breaks the
  actor, loudly, at `_ready`.
- Nothing reaches up or across the tree, which is what the original rule was protecting.
- Scene files stay hand-editable, which matters while there is no artist opening them in the
  editor.
- `@onready` must sit after the plain variables, per the member order in `docs/conventions.md` —
  `gdlint` enforces it.

## Alternatives rejected

**Author the scenes in the editor so the exports serialise correctly.** It would work, but it
makes every scene change require the GUI and leaves the repo with files nobody can safely
hand-edit or review as text.

**Resolve exports with a `get_node_or_null` fallback in `_ready`.** Two mechanisms for one job,
and the fallback hides the mistake instead of preventing it.
