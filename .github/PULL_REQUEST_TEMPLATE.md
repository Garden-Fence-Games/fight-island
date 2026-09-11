## What

<!-- One or two sentences. What changed. -->

## Why

<!-- Closes #123 -->

## Test plan

- [ ] Project imports clean (`godot --headless --path . --import`)
- [ ] `tools/verify_project_config.gd` passes
- [ ] Verified with keyboard and mouse
- [ ] Verified with a gamepad
- [ ] No new errors or warnings in the Godot output

## Checklist

- [ ] Branch is `type/short-description`; commits are Conventional Commits, subject line only
- [ ] Files under `res://` are `snake_case`; nodes and `class_name` are `PascalCase`
- [ ] No `.godot/`, no build output, no credentials committed
- [ ] New binary assets are LFS-tracked
- [ ] `project.godot` changes are intentional — the editor rewrites this file aggressively
- [ ] Docs updated per the trigger table in `docs/contributing.md`
- [ ] If a balance value moved: `docs/game-design.md` **and** the `.tres`

## Clip

<!-- Required for anything that changes how the game feels. -->
