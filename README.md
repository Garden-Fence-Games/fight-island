# Fight Island

> Land alone on an island. Survive the waves. You get three things to fight with — and what
> matters is not which one, but *when* you swing it.

A 3D PVE wave-survival arena game. One player, one island, three weapons, three attacks each.
Damage is decided by timing, not by which button you pressed. Every cleared wave pays for
exactly one upgrade — and a run never affords them all.

## Status

**Milestone 1 — prototype.** The game runs. Grey-box arena, a player who moves, sprints, dodges
and parries, the three-attack fist chain with both timing layers, and farmhands who close the
distance and swing. Everything is Godot primitives on purpose — the only question this milestone
answers is whether the timing feels good.

Still to come: the stick and the gun, waves, money and the upgrade merchant. See
[docs/roadmap.md](docs/roadmap.md).

## Features

- **Timing-driven combat.** Three attacks per weapon, chained through input windows. Hit the
  tight *perfect* window and the strike hits harder, with hitstop and a flash to prove it. A
  player who mashes only ever sees the first attack of every weapon.
- **Three weapons, no more.** Fists, a wooden stick, a gun — a different range, a different
  commitment, a different rhythm each.
- **Wave survival.** Fifteen escalating waves on a single island, then an endless mode.
- **Three farmers who want you gone.** A bare-handed swarm, a scythe-swinging bruiser whose wide
  arc cannot be sidestepped, and a thrower who keeps his distance and never lets you camp. One rig,
  three textures, three very different problems.
- **One upgrade per wave.** Health, stamina, fists, stick, gun. You cannot max them all; the
  subject of the game is what you give up.
- **A full defensive kit.** Dodge with i-frames, sprint, and a tap parry whose perfect window
  staggers the attacker and refunds stamina.
- **Free-rotating top-down camera.** Continuous yaw, clamped pitch, zoom — framed like an
  isometric RPG, played like an action game.
- **Gamepad and mouse/keyboard**, both first-class, hot-swapping mid-run.

## Tech stack

| | |
|---|---|
| Engine | Godot **4.7.2** |
| Language | **GDScript**, statically typed throughout |
| Renderer | Forward+ |
| Physics | Jolt Physics |
| 3D authoring | Blender → glTF 2.0 (`.glb`), from the art phase onward |
| Platforms | macOS (universal) · Windows (x86_64, D3D12) |
| Distribution | itch.io, then Steam |

## Requirements

- [Godot 4.7.2](https://godotengine.org/download). The version must match exactly — export
  templates are version-locked.
- **Export templates are optional.** CI produces every shippable binary; install them locally only
  if you want to look at an export yourself (*Editor → Manage Export Templates*).
- [Git LFS](https://git-lfs.com) — required before committing any binary asset. `.gitattributes`
  already routes `*.png`, `*.glb`, `*.wav` and friends through it.
- [Blender 4.x](https://www.blender.org) — only to edit the sources in `art-source/`. Not needed
  to run, build, or contribute code.

## Running the project

```bash
git clone git@github.com:pepito2t/fight-island.git
cd fight-island
git lfs install
open -a Godot project.godot   # or open the folder from the Godot project manager
```

The first open reimports every asset. There is no main scene yet — that arrives in M1.

To validate the project configuration the same way CI does:

```bash
godot --headless --path . --script tools/verify_project_config.gd
```

## Folder structure

```
.claude/       shared Claude Code setup — committed on purpose
art-source/    Blender and texture sources, not imported by the engine
assets/        imported, engine-ready art and audio
data/          balance as .tres resources — weapons, attacks, upgrades, waves
scenes/        boot, main, world, actors, weapons, ui, fx
scripts/       autoloads, resources, components, actors, systems, camera, ui
tests/         gdUnit4 suites
tools/         headless scripts and EditorScripts — never shipped
docs/          the documentation below
```

## Documentation

| Document | What it answers |
|---|---|
| [docs/game-design.md](docs/game-design.md) | The game: loop, waves, economy, and **every balance number** |
| [docs/architecture.md](docs/architecture.md) | Scene composition, components, state machines, autoloads, save format |
| [docs/conventions.md](docs/conventions.md) | GDScript style and repository rules |
| [docs/input-map.md](docs/input-map.md) | Every action, gamepad and mouse/keyboard |
| [docs/asset-pipeline.md](docs/asset-pipeline.md) | Primitives now, Blender → glTF later |
| [docs/build-and-release.md](docs/build-and-release.md) | Exports, itch.io, Steam, versioning |
| [docs/contributing.md](docs/contributing.md) | Git workflow and the definition of done |
| [docs/roadmap.md](docs/roadmap.md) | Milestones M0 → M5 |
| [docs/decisions/](docs/decisions/) | Architecture decision records |
| [docs/credits.md](docs/credits.md) | Third-party asset licences |

## Building

**Builds come from CI.** Push a `v*.*.*` tag and the release workflow exports macOS and Windows,
drafts a GitHub Release and publishes to itch.io. Nothing on a laptop is a release artifact.

To look at a local export anyway — export templates required:

```bash
godot --headless --export-release "macOS"           build/macos/FightIsland.zip
godot --headless --export-release "Windows Desktop" build/windows/FightIsland.exe
```

Signing, notarisation, itch.io and Steam are covered in
[docs/build-and-release.md](docs/build-and-release.md).

## Contributing

Conventional Commits, subject line only. Branches are `type/short-description`. Every change
goes through a pull request — nothing is merged directly into `main`. Read
[docs/contributing.md](docs/contributing.md) before the first commit: the Godot-specific rules
about `.tscn` conflicts and binary assets are there, and they matter.

## License

Code: not yet decided — see [docs/roadmap.md](docs/roadmap.md). Third-party assets keep their
own licences, tracked in [docs/credits.md](docs/credits.md).
