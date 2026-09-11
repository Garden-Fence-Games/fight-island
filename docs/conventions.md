# Conventions

## Language

English everywhere in the repository: code, identifiers, comments, commit messages, docs. French
lives in the ZenNotes vault and in the game's FR locale file.

## File naming — and the conflict with the global rule

The global `~/.claude/CLAUDE.md` says *"Files/folders: `kebab-case` for all languages."*
**Inside this repository that rule is overridden for engine files.**

The reason is not taste. **Godot's `res://` filesystem is case-sensitive even when macOS is
not**, so a casing mistake compiles and runs locally and only fails after export, on someone
else's machine. Godot's official style guide specifies `snake_case` for `.gd`, `.tscn`, `.tres`
and assets, and `PascalCase` for `class_name` and node names. Every addon, every engine demo and
every `res://` path in the wild follows it. On top of that, the editor generates files itself —
`*.import` sidecars, `export_presets.cfg`, `.godot/` — and you cannot impose kebab-case on those,
so the alternative is a permanently mixed tree.

| Zone | Convention |
|---|---|
| Anything Godot loads — `scenes/`, `scripts/`, `assets/`, `data/`, `addons/` | `snake_case` files and folders |
| Node names in `.tscn`, `class_name`, custom Resource types | `PascalCase` |
| Everything else — `docs/`, `tools/`, `.github/` | `kebab-case`; GitHub's own files keep `UPPER_SNAKE` |

**This is a decision, not drift.** Do not "fix" snake_case `.gd` files. See
[ADR 0002](decisions/0002-godot-file-naming.md).

## Identifiers

`snake_case` for files, variables, functions and signals · `PascalCase` for classes and node
names · `UPPER_SNAKE_CASE` for constants and enum members · a `_leading_underscore` for private ·
`StringName` (`&"idle"`) for identifiers compared every frame.

## Script member order

Enforced, with a blank line between groups:

`@tool` → `class_name` → `extends` → docstring → `signal` → `enum` → `const` → `@export` →
public vars → private vars → `@onready` → `_init` → `_enter_tree` → `_ready` →
`_process` / `_physics_process` → `_input` / `_unhandled_input` → public methods →
private methods → inner classes.

## Static typing

Everywhere, no exceptions. Every variable, every parameter, every return type including
`-> void`. `:=` inference is allowed only when the right-hand side is an unambiguous literal or a
typed call. No untyped collections: `Array[AttackData]`, and typed dictionaries where they apply.

## Signals

Named as a past-tense fact — `wave_cleared`, never `clear_wave` and never `on_wave_cleared`.
Handlers are `_on_<emitter>_<signal>`. Connect in code with `signal.connect(callable)` rather than
in the editor, except for UI where the editor connection is genuinely clearer — and even then the
handler lives in the scene's own script.

## `class_name`

On every `Resource` subclass and every type used as an `@export` hint or a type annotation. Not on
one-off scene scripts: it pollutes the global scope and slows the editor's class cache.

## Scenes and nodes

One responsibility per scene. A scene past roughly ten direct children or a script past roughly
250 lines gets split. Prefer `@export var target: Node3D` over `get_node("../../Foo")` — never
reach up the tree, and never reach across it.

## Comments

The global rule holds unchanged: **default zero comments**. A comment carries a *why* that is
genuinely non-obvious — a hidden constraint, a subtle invariant, a workaround — and it is one line.
Never describe what the code does. The one place a short block is welcome is a `##` docstring on a
`Resource` class, because it shows up in the inspector.

## Magic numbers

None. Gameplay constants live in `.tres` under `data/`; engineering constants are `const` at the
top of the file.

## Localisation

Every player-facing string goes through `tr()` with a `UI_` / `HUD_` / `ITEM_` key prefix from day
one, even while only English exists.

## Formatting

Tabs, per Godot's official style. `gdformat` is the arbiter and CI enforces it:

```bash
gdformat $(git ls-files '*.gd')
gdlint   $(git ls-files '*.gd')
```

## Definition of done

- The project opens and runs with **no errors and no warnings** in the Godot output
- `tools/verify_project_config.gd` passes
- No orphan nodes on scene exit
- No `print` left behind — `print_debug` only, behind an `OS.is_debug_build()` guard
- Tests pass
- Docs touched are updated in the same pull request
- A balance change updates `docs/game-design.md` **and** the `.tres`
