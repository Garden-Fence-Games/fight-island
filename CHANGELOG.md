# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **The farmers have voices.** Nine recorded lines, the project's own — the first sounds in this
  game that are not synthesised, because a voice is the one thing a sine cannot do. A farmer speaks
  when he notices you and now and then on the way over, and **not on his wind-up**: everything here
  refuses to shout over a telegraph, and a voice from the same body would be the worst offender.
- **Doppler, so you hear him closing.** Each body carries its own `AudioStreamPlayer3D` rather than
  borrowing a pooled positional voice — a pooled voice is put at a point and played, stationary for
  its whole length, and a stationary sound cannot say *closing*.
- **The gulls call.** Two recorded cries, only from the ones settled on the sand, each bird on its
  own clock so the shore is a shore and not a chorus.
- **Dying has a sound.** A yelp that slides down most of an octave while a rasp falls with it. The
  famous one is under copyright and there is no version this project could ship, so this is the same
  joke built from the same parts — and deliberately off the key, because a scream on the tonic would
  read as the game approving.
- `tools/verify_voices.tscn` — both families shipped, every line mono and short, sitting under a
  wind-up, and moving with the body that says them.

### Changed

- **Everything is 6 dB quieter, and the figure is derived rather than tasted.** Four loud sounds
  arrive together in a night wave and each was normalised as though it were alone; uncorrelated
  sources sum as the root of the sum of squares, so four at 0.9 reached 1.8 and the master clipped.
  One `HEADROOM` moves the whole mix down together — the table of declared peaks is the **shape** of
  the mix and is untouched.
- **The whole game is in A minor, and now it says so.** It was already mostly true — the bed, the
  perfect parry and the perfect signature — and three sounds were in C and G: the wave sting, the
  merchant and the two endings, which are the three most musical moments there are. The bed had the
  same fault one level down: a stack of fifths leaves the key on the third step, and two layers were
  reaching F sharp.
- `SoundBank` — the signal work split out of `AudioManager`, which had reached the thousand-line
  ceiling. The line is a real one: a decaying sine and sixteen-bit packing know nothing about what a
  telegraph is or how loud a footfall should be.

### Added

- `tools/verify_mix.tscn` — the order, the ceiling and the key. It caught its own blindness twice:
  once when the retuned sounds stopped being numeric literals, once when the split renamed the
  function it was scanning for.

### Fixed

- **A sound still in flight when the engine tears down leaked an object** (#145). `AudioManager` is
  now quiet headless — there is nobody to hear it — and a headless *check* says so explicitly,
  because "nobody is listening" is exactly false when a check is about to ask which voice is
  carrying which waveform. Measured: three boots of `main.tscn` in five warned before, none in five
  after.
- The first attempt at this released every voice in `_exit_tree` instead, and **did not work** —
  stopping at teardown is too late, because the audio server releases a playback on its own
  iteration and at quit there is no next one. The release is kept as `AudioManager.silence()`,
  which is a real thing to want, but it is not what fixes the leak.

### Fixed

- **The hint bar lied after a rebind.** Nine labels across seven screens wrote both the glyph and
  the word out by hand — `[B / ESC] BACK`, and the same again. A player who rebound *back* still
  read `[B / ESC]`, and a player reading anything but English read English. `HintLabel` names the
  action and the key instead, the way `MenuEntry` has since the menus were built.
- **The merchant printed untranslatable English.** `UpgradeTrack.display_name` held a name rather
  than a key and reached the screen raw, in the upgrade card and in the run summary. `WeaponData`
  and `EnemyData` held names too; `DayPhase` had always held a key. All four agree now.
- Two dead rows found by the same check: `UI_BACK`, which existed for the hint bar that had written
  its own English out instead, and three `WEAPON_*` rows waiting for a field that held a name.

### Added

- `tools/verify_strings.tscn` — every key-shaped string resolves, and every row is asked for.
  `tr()` answers an unknown key with the key itself: nothing logged, nothing null, and the player
  reads `SUMMARY_PERFECT_PARRIES` off the screen.
- `verify_glyphs` fails on any scene that writes a glyph out by hand.

### Added

- `tools/verify_lookups.tscn`, which closes the last line of #31 that nobody had ever audited: **no
  path lookup in any body that runs every frame**. It reads the source — `_process`,
  `_physics_process` and the states' own `physics_update` and `update`, plus every private helper
  those call in the same file. 807 lines across 42 bodies, and none of them walks the tree.
- The four group queries that *do* run per frame, measured rather than assumed: 2.9 µs of a
  16 667 µs frame at thirty bodies, which is 0.017% of the budget. No cache, for the same reason the
  spatial grid was written and thrown away.

### Added

- `tools/verify_bus.tscn` — every signal on the bus has to be raised by something **and** heard by
  something. It is the same shape as a settings row that reaches nothing, one layer down, and it is
  the worst kind of dead code: declared, documented, emitted at exactly the right moment, and
  doing nothing. **A headless check counts as a listener** — `enemy_spawned` has no gameplay
  consumer at all and exists so `verify_waves` and `verify_day_night` can watch bodies arrive
  instead of polling a group; a rule that only read `scripts/` would have called it dead and
  deleted what two checks are built on.


- **A farmer rears back before he swings.** The ring under a winding-up enemy went in #122 and
  nothing replaced it — a wind-up read as a body that had planted its feet, which left the sound
  carrying the whole telegraph and left a player with SFX at zero no warning in any channel. The
  body now tips 35° backwards over the wind-up and snaps forward on the swing.
- It is a **shape, not a colour**, so it survives greyscale, a colourblind player and a camera
  twenty metres up with no accessibility switch of its own; it is the **same tell for every
  archetype**; and it is **a share of the wind-up's own duration** rather than a clip at its own
  rate, so the waves and the hour cannot drift the picture away from the timing.
- `verify_vfx` gained the claim the ring used to carry, and two the ring never did: that the
  silhouette swings far enough to read at twenty metres (0.49 m, against a body 0.7 m wide), that
  the lean only ever grows — a body that tips and untips is a flicker, not a fill — and that every
  way out of a wind-up stands the body back up, including a wave cleared mid-commit.
- **A bed that lifts with the island.** Three loops on the Music bus, driven by how full the island
  is rather than by how far through the wave it is — a wave five minutes through is not a tense wave
  if nobody is left. Measured against what *this* wave allows at once, so a full island sounds full
  at wave 1 and at wave 15, and the breather between waves is silent.
- **A telegraph outranks the bed.** The Music bus drops 14 dB while anything is winding up and eases
  back after, the same rule that already refuses a camera knock over a wind-up.
- **The merchant, the victory and the death have a sound.** A screen arriving in silence reads as
  the game having stopped rather than as the fight having paused. Victory and defeat are the same
  three notes in the same order, and the whole difference is which way they go — one shape, two
  readings, nothing new to learn.
- `EventBus.merchant_opened` and `EventBus.run_ended(victory)`.
- `tools/verify_music.tscn`, which walks the whole mix rather than sampling it: the bed never falls
  as the island fills, a fight never starts in silence, a wind-up ducks it and it comes back, the
  three layers are one length, and **nothing the player needs plays on a bus they may mute**.

### Added

- **The thrower test from #39, walked and passed.** `tools/verify_sightlines.tscn` puts a thrower at
  the ten metres he prefers on 36 bearings from every stance a fight can happen on — sixty thousand
  lines from sixteen hundred places — and holds the island to a **band**, because the composition
  has two opposite failures. Too little open ground and a ranged enemy is decoration throwing into
  rock; no cover at all and his stone is a tax rather than something the player answers by breaking
  his line while closing. The shipped island measures 79.3% clear and 20.7% blocked.
- It casts the ray the stone actually flies — the `world` layer, chest to chest — rather than a
  navigation query or a walkability grid, because what stops a stone is not what stops a body: a
  wreck a metre high is cover and a walkable dip is not. Proven to answer the world rather than its
  own arithmetic by flying the same walk at ankle height (39.3% clear, threat floor trips) and above
  everything (100% clear, cover floor trips).
- **A weapon you can hear.** Fists, stick and gun each land with their own body — 150 Hz gone in
  35 ms, 240 Hz for twice as long, 320 Hz over at once. What they do **not** differ in is the
  partial the perfect window adds: 1320 Hz in all three, because it is the signature of the whole
  game and a player who learns it on fists has to have learnt it on the gun.
- **A warning you can place.** The farmhand, the reaper and the thrower wind up from three different
  pitches. The thrower's is the highest and the only climb crossing an octave: he strikes from
  fourteen metres and is the one archetype the player may never see coming, so sound is the only
  warning the design gives them.
- **The last round says so.** The shot that leaves one in the magazine plays two dry clicks. Running
  out is a designed moment and the answer is to close on the next farmer — a decision the player has
  to be able to make before the trigger stops answering.
- `AttackData.impact_sound` and `EnemyData.telegraph_sound`, so a blow's sound is named by the data
  that throws it, the way its burst already is.

### Changed

- `EventBus.attack_landed` carries the `AttackData` and `telegraph_began` carries the `EnemyData`.
  Five of the six listeners ignore them; the one that does not would otherwise have to ask the bag
  what is in hand at the moment of contact, and a weapon swapped during a swing would make that
  a lie.

### Added

- `tools/verify_data_surface.tscn` — every field `docs/architecture.md` names on a balance resource
  has to be a field that resource actually has. Asked of a fresh instance's property list rather
  than of the source text, so a name that only appears in a comment cannot satisfy it. Fields the
  document leaves out are not failures: a bullet is a summary and choosing what to omit is editing,
  while naming something that is not there is being wrong.
- `tools/verify_settings.tscn` — every key in `Settings.DEFAULTS` has to be either applied by
  `Settings` itself or read by a script that is not the options row drawing it. It reads the
  project's own source to answer that, the way `verify_credits` reads `docs/credits.md`, because a
  check that can only see runtime state cannot see a consumer that does not exist. Proven by
  putting one of the dead settings back.
- **`tools/mutate.sh`** — breaks one constant at a time and reports which breakages no check
  notices, because reading for a guard that cannot fail does not work. Twenty-four mutations in
  `tools/mutations.txt`, run weekly in CI and by hand when a guard is written. Seven of them
  survived the first sweep.

### Fixed

- **`EnemyData.first_wave` decided nothing, and looked like it decided when an archetype joins the
  fight.** Every `.first_wave` the code reads belongs to a `WaveBand`; nothing has ever read an
  enemy's. All three archetypes set it in their `.tres`, so anyone asking "when does the reaper
  turn up?" would have found the answer sitting on `reaper.tres`, changed it, and watched nothing
  happen — the real answer is the band shares in `standard.tres`.
  The two agreed today, which is what made it worth removing rather than fixing: a balance number
  with two homes is correct right up until somebody retunes one of them.


- **`EventBus.perfect_timing` was raised on every perfect hit and heard by nobody.** It had a
  declaration, a docstring, a line in `docs/architecture.md` and an emitter in `PlayerAttack` — and
  no connection anywhere in the project, because everything that cares already reads the `perfect`
  flag on `attack_landed`. Removed, along with its line in the document.


- **A distant orientation landmark cannot exist under this camera**, and #39 had been asking for one
  since before the blockout. Measured against the real frustum rather than argued: at −50° the top
  edge of the view still points downward, so the taller a thing is the *sooner* it leaves the frame.
  A 30 m spire is invisible at every distance; a 3 m rock thirty metres away is in shot at full
  zoom. Nothing at all is in frame past 30 m. Written into `docs/architecture.md` with the table,
  because it is backwards from every intuition about landmarks and it will be proposed again.
- It also turns out not to be needed: a camera that never turns means up-screen is always the same
  world direction, so facing is never in question. What is left is knowing where on the island you
  are, which the camp, the six formations and the shape of the coast already answer.


- **A dodge that granted no invulnerability passed every check in the project.** `IFRAME_LENGTH` set
  to nought: the roll still moved, still went where the keys said, still survived the chain lockout,
  and no longer avoided anything. The dodge is one of the two defensive tools and the half that
  matters was held by nothing. `verify_combat` now rolls through a real swing, checks a blow before
  the window still lands, and refuses a roll that ends before its own window opens.
- **A sprint that cost nothing passed every check.** `SPRINT_DRAIN` at zero leaves a player who
  outruns the wave for ever, and the design rests on the opposite — a walking player cannot break
  away from a farmhand, so retreat costs breath. `verify_combat` now runs until the breath gives out.
- **Three guards that took their bound from the thing they were guarding**, and so agreed with
  whatever it said: the body's turn cap (passed at ten times the rate, two revolutions a frame), the
  stick's wake threshold (passed at a thousandth), and the emphasis ceiling (passed at a full
  second). Each writes its figure out now and asserts the constant against it first.
- **A camera knock that never died away passed every check.** `SHAKE_DECAY` at a thousandth leaves a
  camera that never stops moving, which is the opposite of the entire argument for a fixed angle.

### Added

- **One budget for the whole hit.** `scripts/systems/emphasis.gd` is now the single table deciding
  how loud anything in a fight may be, and the only thing that emits `hitstop_requested` or
  `shake_requested`. A perfect finisher that kills is **one** blow: the loudest figure on each
  channel wins and nothing is summed. Summed it would stop for 0.20 s and shake at 0.9; it stops for
  0.18 and shakes at 0.6.
- **A ceiling of twelve frames** on any single blow, in frames because that is the unit a stop is
  felt in.
- `tools/verify_feel.tscn`, holding all of it — including that a hitstop never costs the player a
  buffered press.

### Fixed

- **`docs/architecture.md` listed nine fields that do not exist**, on the one document the project
  treats as the reference for what `data/` carries. `UpgradeTrack` was written up as an `icon`, a
  `max_level` and an `Array[UpgradeLevel]` — a level-table design that was never built, and
  `UpgradeLevel` has never existed as a type. `AttackData` was credited with an `sfx` nothing ever
  had and a `range` that is really `reach`. `EnemyData` had a `damage` it does not carry (a
  farmer's damage belongs to the swing he throws) and a `material` that is really `tint`.
  `WeaponData` had a `model` and an `upgrade_track`, neither real. All four lists now match the
  resources, and say what is interesting about the difference rather than only correcting it.


- **Three settings persisted across launches and moved nothing**: mouse sensitivity, stick
  sensitivity and invert Y. They were written for a camera that can be turned, and this one cannot
  be — the yaw and the pitch are constants on `CameraRig`, the mouse aims by where its cursor lands
  on the ground and the stick by the direction it points. There was never a look delta to scale or a
  pitch to invert, so all three are gone along with their rows and their string-table entries. It is
  the third time this has shipped, after the colourblind telegraphs and aim assist, and it is the
  worst shape a settings bug has: silent, and it lands on the player who needed the setting, who
  finds it, sets it and believes they are covered.
- `CLAUDE.md` still told every future session that camera look reads `InputEventMouseMotion` and
  that `camera_left/right/up/down` live in the input map. The camera was fixed and those five
  actions removed — `docs/input-map.md` records it and `CLAUDE.md` never caught up, which is the
  most expensive place in the repository to be wrong.


- **Taking a hit shakes the camera.** The comment beside the shake call read "shake on the three
  finishers **and on taking damage**, and nowhere else", and taking damage shook nothing at all: the
  code had been describing a design it did not implement. It is the loudest figure in the table now.
- **The perfect parry is the longest stop in the game again.** It was 6 frames and the charged shot
  was 11, so the most skilful input in the game was quieter than a held trigger. It is 12 — the
  whole budget, and nothing else may draw level.
- **Nothing shouts over a telegraph.** A shake requested while anything *in shot* is winding up is
  refused outright. The camera is fixed precisely so a wind-up can never be hidden, and a screen
  that jumps while a farmer commits hands that back. A farmer committing off screen refuses nothing.

### Removed

- `HitInfo.hitstop`, which nothing read once `Emphasis` owned the decision.

### Fixed

- **Aim assist does something.** It has been a row in the options screen, a key in
  `Settings.DEFAULTS` and a value that persisted since the settings landed, and **nothing has ever
  read it** — `docs/menus.md` said the code would arrive with the gun, the gun arrived, and nobody
  came back. That is the failure the same document calls worse than a missing setting, because a
  player who needs it sets it and believes they are covered.
- `AimComponent` now turns the aim towards the nearest body in angle, inside a 12° cone and inside
  the reach of the attack in hand: `soft` takes half the error, `strong` takes all of it. Applied in
  `direction()`, so the head, the body, the swing and the shot never disagree about where the player
  is pointing.

### Added

- **A credits screen the player can reach**, from a discreet line beside the version number on the
  title. It is an overlay like the options screen, scrolls on the stick and the arrows, and back
  returns exactly one level.
- **The screen is generated, not written.** `docs/credits.md` stays the list;
  `tools/build_credits.gd` bakes it into `data/credits.tres`; `tools/verify_credits.tscn` fails the
  build if the document and the resource have come apart, or if a baked row never reaches a label.
  Adding an asset is a row in the document and a rebuild — nobody edits a scene for it. A second
  hand-kept copy of an attribution list goes wrong in exactly one direction, which is by leaving
  somebody out.

### Fixed

- **`docs/architecture.md` said the crowd's cost does not rise with the square of the crowd. It
  does.** The measurement behind that claim read the whole physics step, which is mostly
  `move_and_slide` and the navigation agents, and it stopped at forty bodies — so a term worth a
  millisecond stayed buried under the ones worth two or three and the total read flat. Isolated and
  taken past the budget, separation costs 17 µs per body at ten bodies and 77 µs at sixty, and a
  per-body cost that climbs with the crowd is the square term by definition.
  **The decision not to fix it stands** — at thirty bodies the pass is about 1.3 ms of a 16.7 ms
  frame — but *not quadratic* would have meant never looking again, and past about sixty bodies a
  grid wins by roughly four to one. Only the reason changed.
- `stress_enemies` reports the separation pass on its own, and at sixty and a hundred and twenty
  bodies as well as inside the budget, so the shape is re-measurable instead of asserted. Its
  passes are spread one to a frame: two hundred in one frame is a 678 ms frame, which made the
  tool's own busy-machine warning fire at every size — correctly, about itself.
- **A weapon is no longer dropped where the player cannot see it.** `PickupDirector` asked the
  camera whether a point *a metre above* the ground was in shot, then laid the weapon on the ground
  — and the two answers differ exactly at the bottom edge of the frame, which is the blind side. It
  now asks at `WeaponPickup.RESTING_HEIGHT`, the height the thing actually lies at. One drop in
  roughly two hundred was landing out of shot; CI found the first one, not the machine it was
  written on.
- **The wheel no longer winds in close enough to hide a swing.** `CameraRig.MIN_ZOOM` goes from 6 m
  to 11 m. The ground that stays in shot on the blind bearing is very nearly half the arm — six
  metres showed 2.75 m of it — and a reaper strikes from 2.8 m after covering 1.8 m during his
  wind-up, so under 4.6 m his swing began off-screen. The old floor was a setting that quietly took
  the fight away from whoever chose it.

### Added

- `tools/verify_view.tscn`, which answers where the fixed camera's blind side is by measuring it:
  36 bearings marched outward until the ground leaves the frame. It then holds the two rules that
  depend on the answer — a melee swing begins on screen at **every** zoom the wheel reaches, and a
  weapon dropped in the grass lands where the player can see it — 768 of them, from 96 places around
  the island. Proven by breaking both: inverting `PickupDirector`'s view test put 179 of 192 weapons
  out of shot, and winding the wheel to the old floor of six metres left 2.8 m of ground against the
  4.6 m a reaper needs.

- **The island makes a sound now.** Footfalls on sand and in the surf, a roll, a reload, a dry
  trigger, the two gunshots, taking a hit, a body going down, finding a weapon, a wave-cleared
  sting, and a surf bed on the `Ambience` bus. Still not one audio file in the repository — all of
  it is synthesised at startup beside the five combat signatures.
- **The wind-up is audible, and it comes from a direction.** A second pool of
  `AudioStreamPlayer3D` voices carries the sounds that belong to the world rather than to the
  player, and the telegraph is the reason it exists. With the ring gone and the clip that should
  replace it not authored yet, **this is currently the only telegraph the game has** — and the one
  it could never have drawn anyway, for the two farmers behind the player, with three able to
  commit at once at night. It is also the only sound in the game that **climbs**: everything else
  reports something already over, so it falls away, and a rise is what an ear reads as a thing
  arriving.
- Footfalls are counted in **metres covered, not on a timer**, so a sprint's steps come faster than
  a walk's without either speed knowing about the other, wading slows them because wading costs
  speed, and leaning into a boulder makes no sound at all.
- Loudness is now **declared per sound** rather than normalised to one shared peak, and the mix is
  asserted as an ordering — footfall under swing under hit under telegraph. A footfall at a hit's
  level walks over the fight it is walking through.
- `EventBus.footstep_taken`, `telegraph_began` and `weapon_fired`.
- `verify_audio` grew from five sounds to seventeen and a loop, and gained the claims that are not
  about waveforms: that the telegraph plays positionally and at the farmer's own position, that a
  missed shot plays nothing, that the mix is ordered, and that the surf comes back round without a
  step in level at its seam.

### Changed

- **The island's loose stone is thinned out.** Scattered rocks drop from 424 placed to 200 and
  pebbles from 3 400 to 1 200. The six authored formations are untouched — they are what the island
  is supposed to say "stone" with, and a fighting floor peppered with boulders nobody ever has to
  think about was reading as litter in front of the fight.
- `tools/build_island.gd` reports what the scatter **laid down** rather than what it was asked for.
  The counts are targets: `_spots` gives up after `count * 120` throws, so a figure past what the
  gap rule can fit is simply never reached. Rocks sat at 950 and were placing 424 — which is why
  lowering that number did nothing until it dropped under the ceiling. Grass asks for 24 000 and
  places 11 898.

- **The gun is rationed by a ceiling and fed by the dead.** The player never holds more than 30
  rounds, magazine included, and **a cleared wave no longer hands over any**. Ammunition enters a
  run two ways now: one body in eight leaves a round behind, and the gun track hands over its six
  the moment it is bought. An empty pocket is a reason to close on the next farmer rather than back
  away from him, which is the opposite of what an ammunition counter usually does to a player.
- `WeaponData.reserve_per_wave` is gone, replaced by `ammo_cap` and `scavenge_chance`. The upgrade
  track's `reserve` now pays once, at the counter, instead of topping up every wave.
- `EventBus.rounds_scavenged`, and the HUD's ammo panel answers it the way the money chip answers a
  payout — rounds arrive mid-fight, which is exactly when a counter in the corner goes unread.

### Removed

- **The ring under a winding-up enemy.** The red circle that filled on the ground while a farmer
  committed is gone, along with its scene, its shader and `Enemy.telegraph_scene`. The wind-up
  itself is untouched — it still shortens with the waves and with the hour, and still stops at its
  floor — but until the enemy rig carries the tell in an animation, a wind-up reads only as a body
  that has planted its feet.
- The `access_colourblind_telegraphs` setting and its options row, which existed to thicken that
  ring and had nothing else to reach. A toggle that persists and moves nothing is worse than a
  missing one: a player who needs it sets it and believes they are covered.

### Added

- **No corner of the island answers the reaper's sweep with nothing.** `tools/verify_playfield.tscn`
  walks every square metre of ground the fight can reach — nineteen thousand of them — and fails if
  a dodge from any of them lands only in directions a 160° arc already covers. The camera never
  turns, so a pocket is not something the player can look their way out of; and the first run of it
  found one, on a sandbank a hundred metres out that no enemy can reach, which is what taught the
  check to walk the ground the fight reaches rather than the ground a body can paddle to.

- **Somebody lived on this island before it was an arena.** Five wooden huts stand off the fighting
  core — three of them still standing on their stilts under a plank roof, two collapsed to the bare
  post frame with their planking on the sand around them. They are placed rather than scattered,
  they block, and a standing one fades out of the way of the camera exactly as a boulder does; a
  wreck is a metre high and see-through, so it never fades and never hides a fight.
- Four CC0 models out of Kenney's Survival Kit in `assets/models/camp/`, and `wood` / `woodDark` in
  the island's palette — the pack is the Nature Kit's companion, on the same tile and in the same
  untextured, named-part form the generator already recolours.
- `verify_island` now checks that no hut stands in the surf, and that everything in the camera's
  fade group is wearing a material that can actually fade.
- **The stick and the gun.** Six attacks to the table in `docs/game-design.md`: the stick's 120°
  sweep reaches two bodies at once, which is the whole reason it exists and the answer to the
  reaper; the gun is hitscan, rationed by a magazine of six and a reserve that **only grows between
  waves**.
- The charged shot, the one attack in the game that holds rather than taps. Letting go early
  abandons it and hands the round back, but not the stamina.
- Ground pickups: the stick on wave 2, the gun on wave 4, each weapon carrying its own
  `found_at_wave`. A prompt appears on the weapon itself, in world space, with the glyph for the
  device in hand.
- Weapon switching — three direct keys and a wheel that only ever offers what has been found.
  Free and instant, and the only thing it costs is the chain, whose windows belonged to the old
  weapon.
- `Loadout`, the run's bag: weapons found, what is in hand, and the rounds. Saved with the run, so
  a resumed run is still holding what it was holding, with the ammunition it had left.
- `Hitscan`, `PlayerReload`, `PickupDirector`, `Arsenal`.
- `tools/verify_weapons.tscn` — headless proof that one 120° sweep reaches two farmers and never
  hits either twice, that the gun's figures match the table, that a trigger on an empty magazine
  does not fire, that the reserve grows on a cleared wave and at no other moment, and that a swap
  drops the chain.
- `docs/game-design.md` gained a **poise** column. The numbers had been in the resources since M1
  with no row in the document, which is exactly the drift that document exists to prevent.

- **Every glyph on screen names the device in hand.** A menu row and a tutorial prompt each name an
  *action*, never a key, and `Devices` answers with what that action is bound to on the keyboard or
  the pad — swapping the instant the player picks up a controller, and following a rebind
  everywhere it is shown. A pad player never reads the word "mouse".
- `EventBus.input_device_changed` and `EventBus.bindings_changed`.
- `TutorialStep.prompt_actions`: the movement lesson names all four of its actions and the glyph
  deduplicates them — `W A S D` on a keyboard, one `L-STICK` on a pad, because a stick is one thing
  to the player even though the engine reports it as four half-axes.
- `tools/verify_glyphs.tscn` — headless proof that the badge follows the hand and the hand follows
  the binding: a controller picked up changes the title's Quit row from `ESC` to `B` without
  anything being reopened, no prompt names hardware the player is not holding, and every action a
  screen names has a glyph on both devices — a list gathered from the menus and the tutorial data
  rather than typed out, so a row added tomorrow is covered.

- [ADR 0007](docs/decisions/0007-sprint-hold-or-toggle.md) closes the sprint question: hold on a
  keyboard, toggle on a pad, decided **per press** from the device the press arrived on rather than
  from a mode chosen at launch. No behaviour changed — the decision was already shipped, it just
  had no written record.

- **The island is behind the title screen**, blurred and dimmed, with the camera drifting through a
  narrow arc. The grey wash is gone. It is the same `island.tscn` the fight happens on, lit by the
  same sky, softened by the pause menu's own shader — three things that now cannot drift apart.
- `scenes/world/island_sky.tscn`, the environment and sun lifted out of `arena.tscn` so the title
  and the arena cannot be lit differently.

- **Wave 1 is the tutorial.** A `TutorialDirector` in the arena reads seven `TutorialStep`
  resources, hand-drives that one wave, then hands the island back — wave 2 arrives on the formula
  like every other. Every step closes retroactively, so a player who lands a chained perfect hit
  before being asked closes three lessons at once and never sees a prompt. Cleared steps live in
  `progress.json`; a second run skips the whole thing.
- One prompt at a time, bottom-centre, fading in after a beat of silence. It never blocks, never
  pauses, never repeats.
- The on-demand spawn hook: `SpawnDirector.spawn` and `spawn_at` take `harmless`, and a harmless
  farmer is refused the attack token — he closes and circles but cannot swing.
- `HealthComponent.minimum_health`, raised to one during wave 1 and dropped after. Silently: the
  flash, the numbers and the stagger all behave normally.
- `EventBus.dodge_evaded` — a blow arriving while the player rolls through it, which is the dodge
  lesson. Distinct from a dodge that merely happened.
- `EventBus.player_state_changed`.
- `tools/verify_tutorial.tscn` — headless proof that a chained perfect hit closes three lessons
  with no prompt shown, that a harmless farmer cannot claim a token, that the player cannot be
  taken below one hit point during wave 1, that the parry holds the wave open, and that a second
  run skips the tutorial.

- Saving and resuming a run. `run.json` is written when a wave starts, when one is cleared and when
  an upgrade is bought, so Continue survives closing the game and a run resumed between two waves
  still gets the merchant it had not spent. A finished run deletes its file.
- `progress.json`, holding what outlives a run — the best wave reached today, the tutorial's steps
  next.
- Every file under `user://` now carries a version and passes through a migration on read. A file
  from an older build is accepted, one from a newer build is refused, and an unreadable run file is
  deleted rather than left to fail every launch.
- `tools/verify_save.tscn` — headless proof that a run survives the round trip whole, that a
  missing, truncated, incomplete or future-dated file falls back instead of crashing, and that an
  interrupted wave is fought again rather than skipped.
- Merchant between waves: five cards driven by `UpgradeTrack` resources, one purchase a wave, and
  leftover money that carries. Effects reach the living player the moment they are bought,
  including the heal to full on a health purchase.
- Run summary on death and on victory, the same layout both times: waves, time, money earned and
  spent, kills by archetype, upgrade levels, and the two perfect counters in the accent colour.
  Victory adds one line unlocking endless and nothing else.
- `UpgradeComponent`, which reads its body's base values once and applies `base + level × step`, so
  re-applying never drifts.
- `tools/verify_merchant.tscn` — headless proof that prices follow the cost curve, that a purchase
  reaches the body, that there is exactly one a wave, and that money carries.
- Pause menu on `Esc` / Start: Resume · Options · Restart run · Quit to title, over a blurred and
  dimmed world. Restart and Quit each confirm; nothing else in the game does. Back goes exactly one
  level, and quitting to the title keeps the run so Continue has something to continue.
- `ConfirmDialog`, the only thing in the game that asks twice — and the one consumer of the
  hold-to-confirm accessibility setting.
- `tools/verify_pause.tscn` — headless proof that opening really stops the tree, that back goes one
  level and not two, and that cancelling a restart changes nothing.
- Options screen: five tabs — gameplay, controls, video, audio, accessibility — reachable from the
  title and built from one table, so the rows it draws and the settings that exist cannot drift
  apart. Every setting applies the moment it changes and is written to `user://settings.json`.
- Full input rebinding, both devices, from one row each: the device the player presses with decides
  which column changes. Overrides only, stored in `user://bindings.json`, with a reset per device.
- `OptionRow` and `KeybindRow`, the two rows every settings screen will reuse — a ten-block slider,
  a pill toggle and a `< value >` picker, all on the same focus chrome.
- Damage numbers, hitstop, reduce flashing and the sprint mode now read their setting live. Aim
  assist, tutorial prompts, screen shake and the colourblind telegraphs are stored and waiting for
  the features that will read them.
- `menu_prev_tab` and `menu_next_tab` input actions.
- `tools/verify_options.tscn` — headless proof that every setting has a row, that a row writes
  through to the file, and that a rebind moves the InputMap and comes back on a reset.
- In-run HUD: health and stamina bottom-left, ammo bottom-right with a ranged weapon in hand,
  wave and money top-right. Every element listens on the `EventBus` and holds no reference to the
  player. Damage numbers exist and are off by default.
- Run state: money, the wave index and a `RunStats` tally — perfect hits, perfect parries, kills by
  archetype, money earned and spent, run time — collected while the run happens.
- `Settings` and `SaveManager`, both static classes rather than autoloads: every player-facing
  setting, applied the moment it changes and written to `user://settings.json` as JSON.
- Four audio buses — Master, Music, SFX, Ambience — for the audio settings to act on.
- `tools/verify_hud.tscn` — headless proof that the HUD answers every signal it claims to, that
  ammo follows the weapon, and that damage numbers stay off until asked for.
- Title screen: Play · Options · Quit, pad-navigable from the first frame, with Play becoming
  Continue and a New run entry appearing once a run is under way. Built to the Figma design — the
  tokens, the 96 px margins and the 420 × 72 menu rows. A grey wash stands in for the island until
  the arena is composed behind it.
- A Garden Fence intro sting before the title, skippable with any button.
- `MenuEntry`, the menu row every screen will reuse: caret, label, and the glyph that fires it.
- A shared UI theme under `assets/themes/` carrying the design tokens, the `UI_` string table in
  `assets/locale/ui.csv`, and Badeen Display and Inter under `assets/fonts/`.

### Changed

- **The island's grass grows in two lengths.** Half of it stands between 0.5 m and 0.85 m and the
  other half stays under a third of a metre, drawn as height and width independently rather than
  as one size scaled up. What read as a carpet was never the amount of grass — it was that every
  blade of it was the same length. The tall band stops under 1.1 m, the line the camera's occlusion
  draws to a body, which is the height at which ground cover stops dressing a fight and starts
  hiding one.
- Grass takes its wind over the tall band's own height, so one set of figures now serves both
  lengths: a long blade leans over and the tuft beside it barely stirs.

### Fixed

- **One swing shrank another.** Every body in the pool was handed the same hitbox box — it is a
  sub-resource of the enemy scene, and `Hitbox` resizes it to the reach of whatever is swinging. So
  a farmhand arming during a reaper's active frames pulled the reaper's own box in to 1.6 m, and a
  player who stepped inside the scythe's 2.8 m after that was never reported to the sweep at all.
  From wave 3, where the reaper joins the band, with three men able to commit at once at night. A
  hitbox now owns the shape it resizes, and `verify_combat` swings two reaches at once.
- A hitstop freed mid-beat left the game running at a twentieth of speed for good: the `await` that
  restores the clock belongs to a node a scene change can take away.
- **A swing through empty air was as loud as one that connected**, came out of nowhere at full
  level, and then washed for 540 ms over whatever the player did next — a decay of 0.09 ran its
  buffer six time constants deep. It is now a sixth of a second, darker, under a hit, and shaped
  like something passing: it swells, peaks in the middle and falls away.
- **A missed gunshot played a swish.** `attack_whiffed` fires for a hitscan too, so the gun swung an
  arm it does not have — and meanwhile the gun had no report at all, so a shot that connected was a
  thud with no bang in front of it and a shot that missed was a whoosh. Rounds now crack when they
  leave the barrel, per round, so the double tap cracks twice.
- The anti-click ramp was applied after normalising, so every short sound came out under the peak it
  was aimed at — the dry trigger landed at 0.33 against 0.55, because a click is loudest inside the
  two milliseconds the ramp fades.
- Four headless checks read whatever run happened to be saved on the machine. `GameState` restores
  a run at boot, so a developer carrying the gun ran `verify_combat` against gun damage and
  `verify_animation` against an empty magazine. CI never saw it — a clean checkout has no `user://`.
  They now start from a fresh run and put the machine's own back.
- A run quit halfway through a wave came back at the **next** wave, silently skipping the one that
  was interrupted: the wave director read the state's current wave as if it were the last cleared
  one.
- The run clock counted time spent on the title screen with a run suspended behind it.
- Strings with a comma in them were cut short on screen: the locale CSV was written without
  quoting, so the merchant's card copy stopped at its first clause.
- A cold checkout failed to import: `project.godot` lists a translation file the CSV importer has
  not written yet. CI now imports twice and gates on the second pass, which also proves a cold
  import converges rather than merely surviving.
- `menu_options` and `menu_new_run` input actions, so the glyphs the menu prints are real.
- Playable prototype: a grey-box arena, a player who moves, sprints, dodges and parries, the
  three-attack fist chain with its chain and perfect windows, and farmhands that close the
  distance and swing.
- Components: health, stamina, hitbox, hurtbox, and a node-based state machine.
- `EventBus` and `GameState` autoloads, a free-orbit camera rig, hit feedback and a debug overlay.
- Balance as resources under `data/` — three fist attacks, the fists, and the farmhand.
- `tools/verify_combat.tscn` — headless proof of the damage, the perfect multiplier, the chain
  window, the parry and the enemy approach. CI now boots the game instead of parsing files.

- Project configuration: full input map (21 actions, gamepad and keyboard/mouse), named 3D
  physics layers, display and rendering settings, project version.
- `tools/verify_project_config.gd` — headless guard that fails the build when an action or a
  layer goes missing.
- Documentation set under `docs/`, including the game design with its balance tables, the
  architecture, the conventions, the asset pipeline, the release path and five ADRs.
- Shared Claude Code setup under `.claude/`, and `CLAUDE.md` at the root.
- GitHub Actions: lint and headless validation on every pull request, mac and Windows exports
  plus an itch.io publish on tags.
- Git LFS tracking for binary assets, configured before the first asset landed.

### Added

- An island: generated terrain with a real coastline, a beach, gentle inland relief, water you can
  wade into, and scattered palms, rocks and grass. Built by `tools/build_island.gd` and baked to a
  scene; `tools/verify_island.tscn` enforces the composition rules combat depends on — including a
  height ceiling, because a fixed camera cannot look around a wall.
- `tools/screenshot.gd` — two looks at the arena as PNGs, because judging a world by reading its
  generator does not work.
- Water as a shader: depth-graded colour, moving surface, and foam along the whole shoreline,
  derived from the sea floor behind it rather than authored.
- Wading slows the player and the enemies, in proportion to depth.
- Fixed: the six authored boulders carried colliders scaled twice — the shape was already in
  metres and then inherited the visual's scale — so the largest one stopped the player from
  twelve metres away, through open ground. `verify_island` now reads the collider's own scale and
  caps its radius, which is the only way a bug that is invisible by definition gets caught.
- Palms and the larger boulders block. Clearance between blocking props is measured as the gap
  between their surfaces, so the player can always dodge through.

### Changed

- `run/main_scene` is `boot.tscn` again, and boot now opens the intro rather than the arena.
- The game ships in English only. The `tr()` layer stays; a second locale does not.
- The camera is **fixed** and only follows the player. Framing it from one direction for the whole
  game means every silhouette reads the same way, the island is composed for one viewpoint, and a
  telegraph can never hide behind geometry.

### Removed

- The `[dotnet]` block from `project.godot` — this is a GDScript project.
- Five input actions that a fixed camera has no use for: `camera_left`, `camera_right`,
  `camera_up`, `camera_down`, `camera_recenter`.

[Unreleased]: https://github.com/pepito2t/fight-island/commits/main
