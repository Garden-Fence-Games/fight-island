- **Fifteen methods nothing called.** A sweep of every `func` in `scripts/` against every call site
  in the project found fifteen with no caller at all, and three of them had been dead since the
  archetype that used them was taken out. Two carried a docstring claiming a headless check read
  them — `RunIntro.is_holding` and `SurfBed.on_the_coast` — which no check has ever done; a comment
  that names a reader who does not exist is worse than no comment, because the next person believes
  it. `AttackTokens.holds`, `WaveDirector.hand_over` and `WaveDirector.left_to_send` went with the
  thrower's check and the old tutorial. `AimComponent.device` was the aim's own reading of the last
  device touched, offered to the button glyphs before `Devices` existed to answer them properly.
  The rest: `StateMachine.has_state`, `WeaponData.index_of`, `UpgradeTrack.touches_body`,
  `CameraRig.screen_forward`, `MixTable.family_of`, `Settings.reset` and `reset_all`,
  `WaveDirector.progress` and `PlayerAttack.charge`. No behaviour changed, and every headless check
  still passes — which is the point: nothing was reading any of it.
