# Documentation

| Document | What it answers |
|---|---|
| [game-design.md](game-design.md) | The game: loop, timing system, waves, economy, and **every balance number** |
| [architecture.md](architecture.md) | Scene composition, components, state machines, autoloads, save format |
| [conventions.md](conventions.md) | GDScript style, and why file naming overrides the global rule |
| [tutorial.md](tutorial.md) | How the game teaches itself — wave 1 is the tutorial |
| [menus.md](menus.md) | Title, pause, options, merchant, run summary, HUD |
| [input-map.md](input-map.md) | Every action on both schemes, and the decisions behind them |
| [asset-pipeline.md](asset-pipeline.md) | Primitives now, Blender to glTF later |
| [build-and-release.md](build-and-release.md) | Exports, itch.io, the Steam checklist, signing |
| [contributing.md](contributing.md) | Git workflow, `.tscn` conflicts, the documentation trigger table |
| [roadmap.md](roadmap.md) | M0 to M5, with exit criteria |
| [credits.md](credits.md) | Third-party asset licences |
| [decisions/](decisions/) | Architecture decision records |

## Where a fact lives

**One home per fact.** A balance number lives in `game-design.md` and in `data/*.tres`, and
nowhere else. Project status lives in ZenNotes, never here. An open question lives in ZenNotes
until it closes, and then it becomes an ADR here and disappears from there.
