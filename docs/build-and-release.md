# Build and release

## CI is the only source of shippable binaries

This is a decision, not a description. Every artifact that reaches a player comes out of
`release.yml`, on a tagged commit, from a pinned Godot version on a clean runner.

It removes a whole class of problem: no "works on my machine" build, no wondering which local
editor produced the `.zip`, no laptop state baked into a release. It also settles the mono
question — the only editor installed locally is `/Applications/Godot_mono.app`, which exports with
**mono templates** and ships a .NET runtime this game never uses. Since local exports are not
releases, that no longer matters.

**Export templates are therefore optional locally.** Install them only to look at an export
yourself. They are not installed today, and nothing is blocked by that.

## Prerequisites

- **Godot 4.7.2** to open and run the project.
- **Git LFS** before the first binary asset lands.
- Export templates *only* if you want a local export — version-locked to 4.7.2, and the mono
  editor looks for `4.7.2.stable.mono/` rather than `4.7.2.stable/`.

## Versioning

`application/config/version` in `project.godot` is the source of truth. `0.MAJOR.MINOR` until
release, `1.0.0` at launch. Git tags are `v0.3.0`. `CHANGELOG.md` follows Keep a Changelog and is
updated in the release pull request.

## Export presets

`export_presets.cfg` **is committed**. Since Godot 4.1 the editor writes every option flagged
secret — signing certificates, notarisation credentials, the script encryption key — into
`.godot/export_credentials.cfg` instead, and `.godot/` is gitignored. The committed file therefore
contains no secrets.

The two non-secret fields worth knowing about are the macOS `codesign/identity` and
`codesign/apple_team_id`. Neither is a credential, but both are left empty here and injected at
build time.

| | macOS | Windows |
|---|---|---|
| Architecture | universal (arm64 + x86_64) | x86_64 |
| Output | `build/macos/FightIsland.zip` | `build/windows/FightIsland.exe` |
| Bundle / product | `ch.tmbk.fightisland` | Fight Island |
| Notes | universal is required — Apple Silicon is most of the Mac install base | `embed_pck=false`, so a code-only patch ships a small diff instead of the whole blob |

`application/export_d3d12=1` on Windows is **mandatory** while `project.godot` sets
`rendering_device/driver.windows="d3d12"`; it ships the Agility SDK DLLs next to the executable.

## Local export, for a look

Not a release. See above.

```bash
GODOT=/Applications/Godot_mono.app/Contents/MacOS/Godot

$GODOT --headless --path . --export-release "macOS"           build/macos/FightIsland.zip
$GODOT --headless --path . --export-release "Windows Desktop" build/windows/FightIsland.exe
```

Check the exit code — a missing template errors, and the failure is easy to miss in the scroll.

## CI

`.github/workflows/release.yml` runs on a `v*.*.*` tag and **exports both platforms from a single
Linux runner**. Godot's export templates are cross-platform, and on a private repository a macOS
runner bills at **ten times** the minute rate. A macOS runner is only needed for codesigning and
notarisation, neither of which is set up.

The workflow attaches both archives to a draft GitHub Release, then pushes them to itch.io with
`butler`. If `BUTLER_API_KEY` is unset the publish step **skips with a warning** rather than
failing the tag.

## itch.io

Free to publish, no entry fee, and it takes exactly the same binaries Steam would. Channels are
`mac` and `windows`; `--userversion` is taken from the tag.

Needed once: an itch.io project page at `pepito2t/fight-island`, and the API key stored as the
`BUTLER_API_KEY` repository secret.

## Steam — manual, and later

Deliberately **not** automated. The procedure is written down so it is ready when the decision is
made, but nothing in the repository depends on it.

**The cost.** Steam Direct is **100 USD per title**, payable even for a free game. It is
"recoupable" against 1 000 USD of adjusted gross revenue — which a free game with no in-app
purchases never reaches, so treat it as a flat, non-refundable 100 USD.

**The delay.** Valve imposes **30 days** between paying the fee and the first possible release.
Pay about a month before any target date, not on the day.

**The steps, once an App ID exists:**

1. Download the Steamworks SDK from the partner site. **Do not vendor it** — the redistribution
   terms are restrictive, and it is gitignored.
2. One app, three depots: the app, a Windows content depot, a macOS content depot.
3. `app_build.vdf` plus one `depot_*.vdf` per platform, in `tools/steam/` as `.example` files. The
   real ones are gitignored because they carry the App ID and the build account context.
4. `steamcmd +login <user> +run_app_build <path>/app_build.vdf +quit`.
5. Push to the `beta` branch, smoke-test on a clean machine, then promote to `default`.

**Steamworks API.** Shipping a plain binary through Steam needs **no API integration at all**.
Achievements, cloud saves, rich presence and Steam Input need a GDExtension — **GodotSteam** is
the right one for GDScript because it works with stock export templates. Build
`scripts/autoload/steam_manager.gd` as a no-op façade first and swap the real implementation in
behind it; nothing upstream changes. If achievements should ship at launch, design the list during
M3 so the events already exist on the `EventBus`.

`steam_appid.txt` is a development-only file. It is gitignored and must never enter a depot.

## Signing, honestly

**macOS.** An unsigned or ad-hoc-signed `.app` gets *"Fight Island is damaged and can't be
opened"* — Gatekeeper's misleading message for unnotarised code. There is no workaround and no
platform signs on your behalf. It needs a paid **Apple Developer membership (~99 USD/year)** →
Developer ID Application certificate → `codesign --options runtime --timestamp` →
`xcrun notarytool submit --wait` → `xcrun stapler staple`. This is the single largest release risk.

**Windows.** Since 2023 a publicly trusted code-signing key must live on a hardware token or a
cloud HSM, so a `.pfx` in a repository secret is no longer possible. **Ship Windows unsigned at
first.** On Steam the client launches the game, so the SmartScreen friction of a direct download
largely does not apply. Revisit with Azure Trusted Signing once there is revenue.

## Release checklist

- [ ] Version bumped in `project.godot`, changelog written
- [ ] No debug actions in the release build, no `print` in hot paths
- [ ] Both platforms launched from a **clean** machine
- [ ] Save migration tested from the previous version
- [ ] Tag pushed, CI green, draft release reviewed
- [ ] itch.io channels updated
- [ ] If Steam: uploaded to `beta`, smoke-tested, then promoted to `default`
