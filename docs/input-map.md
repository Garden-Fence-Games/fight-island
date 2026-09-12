# Input map

The authoritative binding lives in the `[input]` block of `project.godot`. This document is its
human-readable mirror and explains the decisions behind it — **the `.godot` file itself cannot
hold comments**, because the editor rewrites it on almost every save and strips anything it did
not write.

`tools/verify_project_config.gd` fails the build if an action disappears or loses one of its two
bindings.

## Principles

- Every gameplay input is a **named action**. Never a raw key check at a call site.
- **The table above is the default, not the law.** Options → Controls rebinds every action here
  except `ui_*` and `debug_*`, and the overrides live in `bindings.json` — see
  [menus.md](menus.md).
- Both schemes are first-class and hot-swap on the first input of the other kind.
- Godot's built-in `ui_*` actions are left alone **except** `ui_accept` and `ui_cancel`.

## Actions

| Action | Keyboard / mouse | Gamepad (Xbox) | Deadzone |
|---|---|---|---|
| `move_forward` / `_back` / `_left` / `_right` | `W` `S` `A` `D` | Left stick | 0.2 |
| `aim_left` / `_right` / `_up` / `_down` | — (the cursor aims) | Right stick | 0.2 |
| `camera_zoom_in` / `_out` | wheel up / down | D-pad up / down | 0.2 |
| `attack` | Left mouse | RT | **0.5** |
| `parry` | Right mouse | LT | **0.5** |
| `dodge` | `Space` | A | 0.2 |
| `sprint` | `Shift` | L3 | 0.2 |
| `reload` | `R` | X | 0.2 |
| `interact` | `E` | Y | 0.2 |
| `weapon_next` | `Tab` | RB, D-pad right | 0.2 |
| `weapon_prev` | — | LB, D-pad left | 0.2 |
| `weapon_fists` / `_stick` / `_gun` | `1` `2` `3` | — (cycle instead) | 0.2 |
| `pause` | `Esc` | Start | 0.2 |
| `ui_accept` | `Enter`, numpad `Enter`, `Space` | **A** | 0.2 |
| `ui_cancel` | `Esc` | **B** | 0.2 |
| `menu_options` | `O` | Y | 0.2 |
| `menu_new_run` | `N` | Y | 0.2 |
| `menu_prev_tab` | `Q` | LB | 0.2 |
| `menu_next_tab` | `E` | RB | 0.2 |

`menu_prev_tab` and `menu_next_tab` reuse the shoulder buttons `weapon_prev` and `weapon_next`
already hold, and `E` already means `interact`. Nothing collides: the options screen is only ever
open with the game paused or from the title, so no weapon swap and no interaction is listening.

`menu_options` and `menu_new_run` share Y on the pad on purpose: a title screen never shows
both badges at once, so the run state decides which one answers. They exist because the menu
prints those glyphs, and a printed glyph that does nothing is worse than no glyph.

| Action | Keyboard / mouse | Gamepad (Xbox) | Deadzone |
|---|---|---|---|
| `debug_overlay` | `F3` | — | 0.2 |
| `debug_skip_wave` | `F5` | — | 0.2 |
| `debug_give_money` | `F6` | — | 0.2 |

## Decisions worth knowing

**`ui_accept` and `ui_cancel` are overridden on purpose.** Godot 4.7's defaults are
Enter/numpad-Enter/Space and Escape respectively, **with no gamepad button at all**. Without the
override a controller player literally cannot confirm or back out of a menu. Overriding a built-in
replaces it entirely, which is why the keyboard defaults are re-listed alongside the new pad
buttons. `ui_left/right/up/down` are *not* overridden — they already carry D-pad and left stick.

**The triggers use a 0.5 deadzone.** `attack` on RT and `parry` on LT are analog; at Godot's
default 0.2 a half-pulled trigger registers as a press, which in a parry-timing game is a lost run.

**The keys still move the character; only the facing changed.** `W` `A` `S` `D` drive the body
exactly as they did — camera-relative, so `W` is always away from the viewer — and the cursor
decides which way it is pointing while it walks. That split is the whole feature: backing away from
something while still aiming at it is impossible when the two are the same input.
`tools/verify_aim.tscn` holds a key down and fails if walking ever starts following the facing.

**The four `aim_*` actions have no keyboard binding, and that is not an oversight.** The mouse aims
by where the cursor *is*; there is no key that means "look north-east". `verify_project_config`
exempts them from the both-devices rule for exactly that reason, and the cursor is what covers the
other half. The right stick aims directly; released, the body goes back to facing its movement, so
a pad player who never touches it gets the game as it played before aiming existed.

**There are no camera-turning actions**, because the camera never turns. The angle is fixed for the
whole game and only the zoom is the player's. Movement stays camera-relative — `W` is always away
from the viewer — which with a fixed angle is simply a constant mapping.

Five actions were removed when the camera was fixed: `camera_left`, `camera_right`, `camera_up`,
`camera_down` and `camera_recenter`. If a four-way snap ever comes back, they come back with it.

**`physical_keycode`, never `keycode`.** Physical codes are layout-independent, so WASD stays under
the same fingers on AZERTY and QWERTZ. Setting both would require both to match.

**`device: -1`** on every event — Godot's `ALL_DEVICES`. The `device: 0` seen in older projects is
legacy and only survives through a special case in the engine.

**The cursor stays visible.** Nothing captures it, because nothing needs relative mouse motion. That
also settles how the gun will aim: at the cursor's position on the ground plane, which is what a
mouse player expects from this camera.

**`weapon_next` shares `Tab` with `ui_focus_next`.** Harmless: weapon switching is polled in the
gameplay state, focus traversal only matters when a `Control` has focus.

## Rebinding

The options menu writes serialised `InputEvent`s into `settings.json`, and `InputMap` is rebuilt at
boot. Debug actions are not rebindable and are stripped from release builds.

## Serialisation reference

Should you ever need to hand-edit the block, these are the exact 4.7 forms. Prefer the editor.

```
InputEventKey          Object(InputEventKey,…,"keycode":0,"physical_keycode":<Key>,…)
InputEventMouseButton  Object(InputEventMouseButton,…,"button_index":<MouseButton>,…)
InputEventJoypadButton Object(InputEventJoypadButton,…,"button_index":<JoyButton>,…)
InputEventJoypadMotion Object(InputEventJoypadMotion,…,"axis":<JoyAxis>,"axis_value":<-1.0|1.0>,…)
```

`Key`: W 87 · A 65 · S 83 · D 68 · C 67 · R 82 · E 69 · `1`–`3` 49–51 · Space 32 ·
Shift 4194325 · Escape 4194305 · Tab 4194306 · Enter 4194309 · numpad Enter 4194310 ·
F3 4194334 · F5 4194336 · F6 4194337

`MouseButton`: left 1 · right 2 · middle 3 · wheel up 4 · wheel down 5

`JoyButton`: A 0 · B 1 · X 2 · Y 3 · Back 4 · Start 6 · L3 7 · R3 8 · LB 9 · RB 10 ·
D-pad up 11 · down 12 · left 13 · right 14

`JoyAxis`: left X 0 · left Y 1 · right X 2 · right Y 3 · LT 4 · RT 5
