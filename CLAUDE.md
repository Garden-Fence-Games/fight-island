# Fight Island

Godot 4.7.2 · GDScript · 3D · Forward+ · Jolt Physics · macOS + Windows · itch.io, then Steam.

PVE wave-survival arena on an island. One player against waves of enemies, three weapons
(fists, wooden stick, gun), three attacks each, and **the damage is decided by when you
press, not by which button**. Health and stamina; stamina powers dodge, sprint and parry.
Each cleared wave buys upgrades among health, stamina, fists, stick, gun — one early, more later.

## Hard rules

- **GDScript only. Never add C#.** The `[dotnet]` block was removed from `project.godot` on
  purpose. Do not create `.csproj`, `.sln` or `.cs` files.
- **Never commit `.godot/`.** It is generated cache and, since Godot 4.1, it also holds
  `export_credentials.cfg` — real signing secrets.
- **The per-asset `*.import` sidecars ARE committed.** They carry resource UIDs; ignoring
  them breaks every reference in the project. There is no `.import/` folder in Godot 4.
- **Balance numbers have exactly one home:** `docs/game-design.md` and, once they exist, the
  `.tres` files in `data/`. Never copy a number into another document, and never restate one
  in ZenNotes.
- **`project.godot` is rewritten by the editor** on almost every save, and it strips anything
  it did not write. Never put explanatory comments in the `[input]` block — they live in
  `docs/input-map.md`.
- Do not create `.tscn` scenes or gameplay `.gd` scripts unless the task explicitly asks.

## File naming — this overrides the global kebab-case rule

Godot's official style guide wins inside this repository, and the reason is not taste:
**Godot's `res://` filesystem is case-sensitive even when macOS is not**, so a casing mistake
only surfaces after export, on someone else's machine.

| Zone | Convention | Example |
|---|---|---|
| Anything Godot loads — `scenes/`, `scripts/`, `assets/`, `data/`, `addons/` | `snake_case` files and folders | `scripts/actors/player/player_state_machine.gd` |
| Node names in `.tscn`, `class_name`, custom Resource types | `PascalCase` | `PlayerStateMachine` |
| Everything else — `docs/`, `tools/`, `.github/` | `kebab-case` (GitHub's own files keep `UPPER_SNAKE`) | `docs/input-map.md` |

This is a decision, not drift. Do not "fix" snake_case `.gd` files. See
`docs/decisions/0002-godot-file-naming.md`.

## GDScript style

- **Tabs** for indentation — official Godot style, and what `gdformat` emits.
- **Static typing everywhere**, including explicit `-> void`. Typed arrays
  (`Array[AttackData]`), never a bare `Array`.
- Member order: `@tool`, `class_name`, `extends`, docstring, `signal`, `enum`, `const`,
  `@export`, public vars, private vars, `@onready`, `_init`, `_ready`,
  `_process`/`_physics_process`, `_input`/`_unhandled_input`, public methods, private methods.
- Signals are named as a past-tense fact — `wave_cleared`, never `on_wave_clear`. Handlers are
  `_on_<emitter>_<signal>`. Connect in code, not in the editor.
- Composition over inheritance. There is no `BaseCharacter`; behaviour is assembled from
  components that do not know who owns them.
- Tunable numbers belong in a `Resource` under `data/`, never hardcoded in a script.

## Architecture notes that are easy to get wrong

- **There is no camera look, and nothing should add one.** The yaw and the pitch are constants on
  `CameraRig` — the whole design rests on one viewing angle, so a telegraph can never hide behind
  geometry the player turned into. `camera_left/right/up/down` were removed with it (see
  `docs/input-map.md`), and so were mouse sensitivity, stick sensitivity and invert Y: a fixed
  camera has no look delta to scale and no pitch to invert. Only zoom remains.
- **Mouse motion cannot be an InputMap action.** The mouse *aims* rather than looks: the cursor is
  cast onto the ground in `_unhandled_input`, which is a position and not a delta.
- Physics layers are named in `project.godot` — reference them through a constants script, never
  as raw integers.
- Hit registration runs on the physics frame, never on interpolated visual transforms.
- **Never `ResourceLoader.load()` anything from `user://`.** A `.tres` can carry a script path,
  and that is arbitrary code execution on a file the player can edit. Saves are JSON.

## Documentation duty

Human-facing project notes live in **ZenNotes**, not only in this repo:
`~/Documents/ZenNotes/inbox/Garden Fence/Fight Island/`.

Notes are **French**, with `title` / `tags` / `dateCreated` frontmatter and bare
`[[wikilinks]]`. Tags are `[projet, garden-fence]`. Match the tone of the `inbox/tmbk/Folio/` and
`inbox/tmbk/MasterJAM/` notes.

The split: **`docs/` says how and how much; ZenNotes says where we are and why.** A ZenNotes
note may state an intention — *"les vagues doublent la pression toutes les cinq vagues"* — but
never the coefficient.

At the end of any session that changed the project's status, closed a decision, or completed a
milestone, propose updating those notes. `/sync-notes` drafts the status refresh.

The per-change mapping is the trigger table in `docs/contributing.md`.

## Git

- Branches `type/short-description`. Conventional Commits, **subject line only** — no body, no
  co-author trailer.
- Always a pull request (`gh pr create`). Never merge to `main` directly, not even for a typo.
- **One branch owns a `.tscn` at a time.** Scene files merge badly; resolve a conflict by taking
  one side wholesale and redoing the other change in the editor, never by hand-editing markers.
- Binary assets must be LFS-tracked before the commit that adds them.

## Local environment

- Godot **4.7.2 standard** lives at `/Applications/Godot.app/Contents/MacOS/Godot` and is **not on
  PATH**. There is no .NET/mono build installed, and none is wanted.
- **CI is the only source of shippable binaries.** Never treat a local export as a release, and do
  not suggest installing export templates to "unblock" anything — they are optional and only serve
  a local look.
- **Blender is not installed.** The prototype is built from Godot primitives on purpose; the
  Blender pipeline in `docs/asset-pipeline.md` is for the art phase.

## Commands

```bash
GODOT=/Applications/Godot.app/Contents/MacOS/Godot

$GODOT --headless --path . --import                                   # import and validate
$GODOT --headless --path . --script tools/verify_project_config.gd    # actions and layers
gdformat $(git ls-files '*.gd') && gdlint $(git ls-files '*.gd')      # style
```
