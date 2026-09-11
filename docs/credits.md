# Credits

Every third-party file used in the project gets a row here: what it is, where it came from, who
made it, its licence, and when it was added.

**A file with no row does not ship.**

## Assets

The island's vegetation and stone come from one CC0 pack, and the player is now a modelled rig. The
enemies, the weapons and the terrain itself are still Godot primitives — see
[asset-pipeline.md](asset-pipeline.md).

| File | Source | Author | Licence | Added |
|---|---|---|---|---|
| `icon.svg` | Godot project template | Godot Engine contributors | MIT | 2026-09-11 |
| `assets/logo/fight_island_logo_1.svg` | original | — *to fill* | — *to fill* | 2026-09-11 |
| `assets/models/char_player.glb` — rig and clips | [Mixamo](https://www.mixamo.com) | Adobe | **`prototype only`** — not CC0, see below | 2026-09-12 |
| `assets/models/char_player.glb` — mesh, gun and textures | — *to fill* | — *to fill* | — *to fill* | 2026-09-12 |
| `assets/fonts/badeen_display.ttf` | [Google Fonts](https://fonts.google.com/specimen/Badeen+Display) | The Badeen Project Authors | SIL OFL 1.1 | 2026-09-12 |
| `assets/fonts/inter_semibold.ttf` | [Google Fonts](https://fonts.google.com/specimen/Inter) | The Inter Project Authors | SIL OFL 1.1 | 2026-09-12 |
| `assets/models/nature/tree_palm.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/nature/stone_largeD.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/nature/stone_smallA.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/nature/grass_leafs.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |

CC0 waives every requirement, crediting included. Kenney is credited here anyway, and the pack's own
licence file travels with the models in `assets/models/nature/`.

## Engine and tools

| | Licence |
|---|---|
| [Godot Engine](https://godotengine.org) 4.7.2 | MIT |
| [Jolt Physics](https://github.com/jrouwe/JoltPhysics) | MIT |

## Note on Mixamo

Mixamo animations are convenient for prototyping but their redistribution terms are not CC0.
Anything from Mixamo must be replaced or cleared before a public release, and it gets a row here
flagged `prototype only` in the meantime.
