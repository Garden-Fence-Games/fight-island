# Credits

Every third-party file used in the project gets a row here: what it is, where it came from, who
made it, its licence, and when it was added.

**A file with no row does not ship.**

## Assets

The island's vegetation, stone and huts come from two CC0 packs by the same author, and the player
is now a modelled rig. The enemies, the weapons and the terrain itself are still Godot primitives —
see [asset-pipeline.md](asset-pipeline.md).

| File | Source | Author | Licence | Added |
|---|---|---|---|---|
| `icon.svg` | Godot project template | Godot Engine contributors | MIT | 2026-09-11 |
| `assets/logo/fight_island_logo_1.svg` | original, Figma | Purple-Sigil | © the project, all rights reserved | 2026-09-11 |
| `assets/models/char_player.glb` — mesh, gun, textures and clips | original, Blender | Purple-Sigil | © the project, all rights reserved | 2026-09-12 |
| `assets/models/char_player.glb` — skeleton | [Mixamo](https://www.mixamo.com) auto-rigger | Adobe | **`prototype only`** — not CC0, see below | 2026-09-12 |
| `assets/fonts/badeen_display.ttf` | [Google Fonts](https://fonts.google.com/specimen/Badeen+Display) | The Badeen Project Authors | SIL OFL 1.1 | 2026-09-12 |
| `assets/fonts/inter_semibold.ttf` | [Google Fonts](https://fonts.google.com/specimen/Inter) | The Inter Project Authors | SIL OFL 1.1 | 2026-09-12 |
| `assets/models/nature/palm_tree.glb` | original, modelled and painted in Blender | Purple-Sigil | © the project, all rights reserved | 2026-09-12 |
| `assets/models/nature/stone_largeD.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/nature/stone_smallA.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/nature/grass_leafs.glb` | [Nature Kit](https://kenney.nl/assets/nature-kit) 2.1 | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/camp/structure.glb` | [Survival Kit](https://kenney.nl/assets/survival-kit), the 1.0 export on [Poly Pizza](https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH) | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/camp/structure_base.glb` | [Survival Kit](https://kenney.nl/assets/survival-kit), the 1.0 export on [Poly Pizza](https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH) | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/camp/structure_roof.glb` | [Survival Kit](https://kenney.nl/assets/survival-kit), the 1.0 export on [Poly Pizza](https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH) | Kenney | CC0 1.0 | 2026-09-12 |
| `assets/models/camp/floor.glb` | [Survival Kit](https://kenney.nl/assets/survival-kit), the 1.0 export on [Poly Pizza](https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH) | Kenney | CC0 1.0 | 2026-09-12 |

CC0 waives every requirement, crediting included. Kenney is credited here anyway, and each pack's
own licence file travels with its models — in `assets/models/nature/` and `assets/models/camp/`.
The Survival Kit file is the current 2.0 one; its CC0 grant is word for word the 1.0 grant.

**Why the hut pieces come through Poly Pizza and not from kenney.nl.** Survival Kit 2.0, the version
the site serves today, moved the whole pack onto a shared `colormap` texture: one material per
model, and the part names the island's palette maps colours onto are gone with them. The 1.0 export
still carries separate, untextured `wood` and `woodDark` materials, which is the form
[asset-pipeline.md](asset-pipeline.md) requires and the same form the Nature Kit ships in. Same
author, same licence, same pack — an older cut of it.

No third-party file is used by the effects or the sounds: the impacts are Godot primitives driven by
`CPUParticles3D`, and **every sound in the game is synthesised at startup** — the combat signatures,
the footfalls, the wind-up, the gunshots, the stings and the surf bed alike. There is still not one
audio file in the repository, so there is nothing to credit here and nothing that can ship without
a row.
There is nothing to credit and nothing to clear before release.

## Engine and tools

| | Licence |
|---|---|
| [Godot Engine](https://godotengine.org) 4.7.2 | MIT |
| [Jolt Physics](https://github.com/jrouwe/JoltPhysics) | MIT |
| [gdUnit4](https://github.com/MikeSchulze/gdUnit4) 6.2.1, vendored in `addons/gdUnit4` | MIT |

gdUnit4 is committed rather than fetched, because a build machine that has to reach the network to
run the tests is a build machine that stops running them the day the network moves. Its own licence
travels with it in `addons/gdUnit4/LICENSE`. Nothing in `addons/` is linted, formatted, or pushed
through Git LFS by this project — it is not ours to reformat, and somebody else's nine icons in LFS
would turn every upgrade of the addon into pointer churn.

**One file of it is deliberately not vendored:** `src/dotnet/GdUnit4CSharpApi.cs`, the bridge for
projects that write their tests in C#. This one is GDScript only ([ADR 0001](decisions/0001-gdscript-over-csharp.md)),
and the repository guard rails refuse a `.cs` file anywhere — a rule worth more kept absolute than
carved out for a directory. Its loader never reaches it here: it returns early unless the engine is
a .NET build *and* `project.godot` names a C# assembly *and* that `.csproj` exists on disk, and
none of the three is true. Re-add the file if this project ever takes on C#, which it will not.

## Note on Mixamo

Mixamo animations are convenient for prototyping but their redistribution terms are not CC0.
Anything from Mixamo must be replaced or cleared before a public release, and it gets a row here
flagged `prototype only` in the meantime.

**The player's animations are original**, authored in Blender. What comes from Mixamo is the
*skeleton*: the rig was produced by their auto-rigger, which is why all 33 bones are named
`mixamorig:*` and why every source action arrived called `mixamo.com`. Adobe's terms do allow a
Mixamo-rigged character to ship, but the flag stays until someone reads those terms against this
project rather than assuming — replacing an auto-rig late costs every clip that was authored on it.
