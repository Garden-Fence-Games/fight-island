# Contributing

## Setup

```bash
git clone git@github.com:Garden-Fence-Games/fight-island.git
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
| Export preset, signing, Steam, versioning | `docs/build-and-release.md`, a fragment in `changelog.d/` | `Build et Distribution` |
| Anything under `scripts/`, `scenes/`, `data/` or `assets/` | one fragment in `changelog.d/` — **enforced by CI**, or the label `no changelog` | — |
| A milestone completed or re-scoped | `docs/roadmap.md` | hub note, `## Où en est le projet` |
| An open question **closed** | new ADR in `docs/decisions/` | delete the line from `Décisions à trancher` |
| A new open question | — | add to `Décisions à trancher`, with a recommended default |
| Anything that changes the one-line answer to "where is this project at?" | `README.md` status | hub note, `## Où en est le projet` |

**The entry goes in `changelog.d/`, never in `CHANGELOG.md`.** One file per change, named
`<section>-<slug>.md`, holding the bullet exactly as it should read. `changelog.d/README.md` has the
format; `tools/assemble-changelog.sh 0.3.0` folds them into `CHANGELOG.md` at release and deletes
them.

This is the answer to a question that has three plausible ones, so that nobody invents a fourth.
Every pull request used to append to the top of the same `## [Unreleased]` block, at the same
offset, and five branches conflicted there in a single evening — always on this file, never on code.
A `merge=union` driver in `.gitattributes` would have kept both sides automatically, in one line,
but entries here run to ten lines of prose and union merges by line: it would interleave two
paragraphs into one unreadable bullet and call that resolved. Writing the notes at release time from
the merged pull request titles is cheaper still and loses the part that matters — an entry here says
*why*, and a title cannot. A file per change is the only one of the three that removes the collision
instead of making it cheaper.

**And it is machine-checked.** A pull request that touches the game and adds no fragment fails
`Pull request hygiene`; a fragment the assembler cannot place fails `Repository guard rails`. The
first asks only that a fragment exists, not what is in it — a check that graded the prose would be a
check people route around — and `no changelog` on the pull request is the way out for a change a
player could not notice. It exists because six pull requests shipped without an entry in one
evening, including a new font, the whole soundtrack and a change to how long a wave lasts, and none
of it reached the release notes until somebody read the build against the merge log. **Nothing in a
diff shows an entry that was never written.**

**Cadence.** Repo docs in the same pull request, always — that is already the definition of done.
ZenNotes per milestone, plus immediately when a decision closes or the status line becomes false.
ZenNotes is not in git, so a per-PR rule cannot be enforced and would rot into a lie.

`/sync-notes` drafts the ZenNotes status refresh from the roadmap and the commit log.

## A check that cannot fail

The commonest way a guard goes quiet is that it takes its bound from the thing it is checking:

```gdscript
var most := deg_to_rad(Player.TURN_SPEED_DEGREES) * (3.0 / 60.0)
if turned > most:
```

Ten times the turn rate moves the expectation with it, and the check passes on a body that spins
twice in a single frame. Reading for this does not work — three of the ones found this way were
written by people who believed they were holding exactly the thing they were not.

**Write the figure out, and assert the constant against it first.** Moving it deliberately is then a
one-line edit; moving it by accident fails, and says so:

```gdscript
if not is_equal_approx(Player.TURN_SPEED_DEGREES, EXPECTED_TURN_RATE):
    _fail("the body turns at %.0f°/s and this check was written for %.0f°/s" % [...])
    return
```

`tools/mutate.sh` measures it rather than trusting anyone's reading: it breaks one constant at a
time, runs the checks that should notice, and reports the ones that did not. The table lives in
`tools/mutations.txt`, and a line in it is a claim — *if somebody changed this by accident, one of
these checks would say so*. **CI runs the whole table on every pull request**, so a guard that has
gone quiet is caught by the change that quietened it rather than by a sweep next Sunday. Run it by
hand anyway when you add an entry, because a line nobody has watched fail is a line that proves
nothing:

```
tools/mutate.sh
```

A **survivor** is either a guard reading its bound off what it guards, or a property nobody ever
wrote a guard for. Both are worth a morning. A line added to the table without once being run in
the broken state is a line that means nothing.

A **STALE** entry is the same failure wearing a different coat: the original text it names is no
longer in the file, so the mutation cannot be applied and nothing is measured. It counts as a
survivor, which is why moving or renaming a constant the table watches is a change to the table too.

## Definition of done

```
- [ ] Static types everywhere, explicit return types
- [ ] Project starts with no errors and no warnings in the Godot output
- [ ] tools/verify_project_config.gd passes
- [ ] No debug prints, no debug actions in a release build
- [ ] Tests pass
- [ ] A new guard was run once with the thing it guards broken, and failed
- [ ] Docs updated per the trigger table above
- [ ] A balance change touched docs/game-design.md AND the .tres
- [ ] A finished milestone updated ZenNotes
```
