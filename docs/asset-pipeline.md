# Asset pipeline

## Primitives first

**Milestones 0 to 2 use Godot primitives and nothing else.** No downloads, no Blender, no import
settings to get wrong.

| Thing | Primitive |
|---|---|
| Player | `CapsuleMesh`, 1.8 m tall, one bright colour |
| Enemies | the same capsule in three colours — farmhand, reaper, thrower — scaled ×1.15 for elites |
| Merchant | a third colour, and he never moves |
| Fists | no mesh — the hitbox is the weapon |
| Stick | `BoxMesh` 0.06 × 0.06 × 1.2 m |
| Gun | `BoxMesh` with a thinner box for the barrel |
| Scythe | a long `BoxMesh` with a second angled box for the blade |
| Thrown stone | `SphereMesh`, 0.15 m |
| Island | `PlaneMesh` for the ground, `CSGBox3D` and `CSGCylinder3D` for rocks and trunks |
| Water | a flat `PlaneMesh` with a scrolling shader, added in M2 |

Plain `StandardMaterial3D` colours, chosen so that player, enemy and elite are distinguishable at
a glance from a high angled camera. This is the fastest path to knowing whether the timing system
feels good, and that is the only question milestones 1 and 2 have to answer.

**Blender is not installed on this machine, and nothing before the art phase needs it.**

## From the art phase onward: Blender to glTF

`.blend` files live in `art-source/` and are tracked by Git LFS. **`.glb` files are committed** to
`assets/models/`.

Godot 4 can import `.blend` directly, but only when it can find a Blender executable at a
configured path — which would mean every CI runner and every build machine needs Blender
installed. The glTF contract costs one export click per iteration and buys a build that depends on
nothing but Godot. See [ADR 0003](decisions/0003-gltf-over-blend.md).

Direct `.blend` import is fine during blockout. Switch before the first CI export.

## Rules that cost real time when forgotten

- **1 Godot unit = 1 metre.** Blender scene unit scale 1.0.
- **Apply all transforms** before exporting (`Ctrl+A → All Transforms`).
- Godot is Y-up / −Z forward and glTF is Y-up / +Z forward; the importer converts. **Export with
  glTF defaults and never hand-rotate in Blender.**
- Character origin at the feet, facing −Z. Weapon origin at the grip, barrel or blade along −Z.
- **Root motion off.** Movement is code-driven so it can be interrupted on frame one.
- Normal maps must be flagged `Normal Map` in the import dock, or the lighting is subtly wrong
  forever.
- **Never trimesh the render mesh.** Author low-poly proxy volumes named `island_cliff_a-colonly`
  and leave the detailed mesh collisionless.

## Naming

Files: `char_player.glb`, **`char_farmer.glb`**, `char_merchant.glb`, `weapon_stick.glb`,
`weapon_gun.glb`, `weapon_scythe.glb`, `prop_stone.glb`, `env_island.glb`, `env_palm_tree.glb`,
`prop_crate.glb`.

**The three enemies are one file.** `char_farmer.glb` carries a single rig and a single mesh; the
archetypes are three materials — `mat_farmer_hand`, `mat_farmer_reaper`, `mat_farmer_thrower` —
swapped at runtime on the same `MeshInstance3D`. One rig means one animation set, one import to
maintain, and an elite that is a tint rather than an asset.

Texture direction: the three must be distinguishable **by value and hue at 20 m from a high
camera**, not by detail nobody will ever see. Test them greyscale before texturing them properly.

Meshes inside: `<asset>_<part>` — `char_player_body`, `weapon_gun_slide`.

Materials: `mat_sand`, `mat_water`, `mat_grass`, `mat_stone`, `mat_wood`, `mat_bark`,
`mat_char_player`, `mat_char_enemy`. **Share a material name across `.blend` files when it is the
same material** — Godot reuses the imported `.material` and it halves the draw calls.

Bones: `hips`, `spine`, `chest`, `neck`, `head`, `shoulder.L`, `upper_arm.L`, `forearm.L`,
`hand.L`, `thigh.L`, `shin.L`, `foot.L`, plus `weapon_socket_r` as a real bone so
`BoneAttachment3D` works without a helper node.

## Auto-collision suffixes

The importer strips these from the node name and generates the body:

| Suffix | Result |
|---|---|
| `-col` | visible mesh plus a concave `StaticBody3D` |
| `-convcol` | visible mesh plus a convex `StaticBody3D` |
| `-colonly` | mesh removed, `StaticBody3D` only |
| `-convcolonly` | mesh removed, convex `StaticBody3D` only |
| `-rigid` | `RigidBody3D` |
| `-navmesh` / `-occ` | navigation mesh / occluder |
| `-noimp` | skipped entirely |

## Animation clips

Names are fixed, so `AttackData.animation` can be a `StringName` constant.

**Player:** `idle`, `walk`, `run`, `sprint`, `dodge_roll`, `parry`, `parry_success`, `hurt`,
`death`, `pickup`, `reload`, `attack_fist_1/2/3`, `attack_stick_1/2/3`, `attack_gun_1/2/3`.

**Farmer (shared by all three):** `idle`, `walk`, `chase`, `strafe_l`, `strafe_r`, `stagger`,
`death`, plus one attack set per archetype — `windup_punch` / `attack_punch`,
`windup_sweep` / `attack_sweep`, `windup_throw` / `attack_throw` — and `retreat` for the thrower.

Split them in Godot's import dock, not by exporting nine files.

## Textures

PNG sources in `art-source/textures/`. Imported as **VRAM Compressed** for 3D albedo and
**Lossless** for UI. Sizes: 2048² for the island atlas, 2048² for the player, and 2048² shared by
the farmer rig — the three archetypes are three materials over one UV layout, not three budgets.
Then 1024² for weapons and large props, 512² for small props, 256² for UI icons. Prefer one trim
sheet per material family over per-object textures.

Targets: under 200 MB of texture VRAM, under 2 GB installed, under 120 k triangles on screen.

**`*.import` sidecar files are committed** — they carry the resource UID and the import settings.
Without them the whole team reimports differently.

## If the prototype needs dressing up before the art phase

CC0 sources, in preference order: **Quaternius** (rigged animated characters), **Kenney** (blocky
characters, weapons, nature kit), **Poly Haven** and **ambientCG** (PBR textures, HDRIs). Mixamo
is fine for prototype animation but its redistribution terms need checking before shipping.

**A file with no row in [`credits.md`](credits.md) does not ship.**

## Iteration loop

Edit in Blender → export `.glb` over the existing file → Godot reimports on focus → scenes update
live. Never re-instance the scene, and **never rename a mesh node once a `.tscn` references it** —
that breaks the node path silently.
