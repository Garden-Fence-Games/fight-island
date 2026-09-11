# Contributing

## Setup

```bash
git clone git@github.com:pepito2t/fight-island.git
cd fight-island
git lfs install
open -a Godot project.godot
```

The first open reimports every asset. `.godot/` is generated and ignored.

## Commits

Conventional Commits, **subject line only** — no body, no co-author trailer.

Types: `feat`, `fix`, `chore`, `docs`, `ci`, `refactor`, `perf`, `art`. `art:` exists so
asset-only commits are easy to filter out of a changelog.

```
feat: add orbit camera rig
fix: clamp camera pitch at 65 degrees
art: replace player capsule with the rigged mesh
```

## Branches

`type/short-description` — `feat/parry-window`, `fix/dodge-iframes`, `ci/pin-godot`.

## Pull requests

Always, even solo, even for a typo. `gh pr create`. Title in Conventional Commit form. The body
carries what, why, a test plan, and **a clip for anything that changes how the game feels**.

**Never merge directly into `main`.** Squash merge on green.

A bug found mid-work gets `gh issue create --title "bug: …"` before or alongside the fix, and the
pull request links it.

## The Godot-specific rules

These are where this document earns its keep.

- **`.tscn` and `.tres` are text but they merge terribly.** Node order shifts and sub-resource IDs
  churn. **One branch owns a scene at a time.** Resolve a conflict by taking one side wholesale and
  redoing the other change in the editor — never by hand-editing the conflict markers.
- Keep scenes small and composed. A huge scene is a merge hazard as much as an architecture smell.
- **`*.import` files are committed.** `.godot/` never is. There is no `.import/` folder in Godot 4.
- `project.godot` and `export_presets.cfg` are marked `-merge` in `.gitattributes`, so git raises a
  conflict instead of silently producing a valid-looking but semantically wrong file. Resolve them
  by hand, deliberately.
- **Git LFS must be installed before the commit that adds a binary asset.** The patterns are
  already in `.gitattributes`; retrofitting LFS rewrites history and invalidates every clone.

## Documentation duty — the trigger table

| Change | Update in the same PR | Update in ZenNotes |
|---|---|---|
| Any balance value | `docs/game-design.md` **and** the `.tres` | only if the *intention* changed → `Contenu et équilibrage` |
| New weapon, attack, upgrade track, enemy behaviour | `docs/game-design.md` | `Le jeu` |
| New autoload, component, `Resource` class, physics layer | `docs/architecture.md` | `Architecture` |
| New or renamed input action | `docs/input-map.md` **and** `project.godot` | — |
| New asset or third-party source | `docs/credits.md`, and `asset-pipeline.md` if the process changed | `Assets et pipeline` only if the pipeline changed |
| A style or naming rule | `docs/conventions.md` | `Conventions` |
| Export preset, signing, Steam, versioning | `docs/build-and-release.md`, `CHANGELOG.md` | `Build et Distribution` |
| A milestone completed or re-scoped | `docs/roadmap.md` | hub note, `## Où en est le projet` |
| An open question **closed** | new ADR in `docs/decisions/` | delete the line from `Décisions à trancher` |
| A new open question | — | add to `Décisions à trancher`, with a recommended default |
| Anything that changes the one-line answer to "where is this project at?" | `README.md` status | hub note, `## Où en est le projet` |

**Cadence.** Repo docs in the same pull request, always — that is already the definition of done.
ZenNotes per milestone, plus immediately when a decision closes or the status line becomes false.
ZenNotes is not in git, so a per-PR rule cannot be enforced and would rot into a lie.

`/sync-notes` drafts the ZenNotes status refresh from the roadmap and the commit log.

## Definition of done

```
- [ ] Static types everywhere, explicit return types
- [ ] Project starts with no errors and no warnings in the Godot output
- [ ] tools/verify_project_config.gd passes
- [ ] No debug prints, no debug actions in a release build
- [ ] Tests pass
- [ ] Docs updated per the trigger table above
- [ ] A balance change touched docs/game-design.md AND the .tres
- [ ] A finished milestone updated ZenNotes
```
