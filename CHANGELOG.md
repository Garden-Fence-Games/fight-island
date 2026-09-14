# Changelog

All notable changes to this project are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **A kill's coins and rounds spray out of the body.** They were paid into the corner the instant a
  body fell. Now they are thrown — gold coins adding up to exactly what the body was worth, and a
  silver round — on a high arc so the player sees where they land, then spin and glint on the sand
  with a small constant flare that twinkles. Walking near is enough: inside a generous radius they
  fly to the player. Whatever is left when a wave is cleared flies in before the merchant opens, so
  no money is lost; a round the pocket has no room for waits on the sand. The `+$` number now rises
  as a coin is taken. Figures in `data/pickups/loot.tres`; held by `tools/verify_loot.tscn`.

### Changed

- **One kill in three leaves a round, up from one in eight.** A drop is a single round, so the gun
  can afford to be generous — and a round that has to be walked over is worth more of them.
- **The gun has no magazine and no reload.** Every round it carries fires, one after another, up to
  the ceiling of thirty it arrives with; with none left the trigger clicks, and walking over a round
  makes it fire again at once. The reload state, its `R` / X binding and its sound are gone, the HUD
  reads rounds against the ceiling, and the gun track hands over six rounds without the extra
  magazine slot that no longer exists. A save from before carries its magazine and reserve over as
  one count.
- **A body that drops rounds drops one, two or three**, each a third of the time and each its own
  piece on the sand. How often a body drops any is unchanged.

- **The mutation sweep runs on every pull request instead of once a week.** It breaks the game on
  purpose one constant at a time and reports which breakages no check notices — and it was kept off
  pull requests because it "takes the better part of half an hour". That figure was never measured.
  Its last sweep finished in **seven minutes nineteen**, which is about what the checks it audits
  cost, because it runs each of them once and stops at the first that fails.
  - Weekly is not a cadence this repository has. That green sweep ran on a Sunday morning against a
    twenty-six line table; ninety-one commits landed in the day after it, ten of them appending to
    the table, and by the Monday three entries named constants that had been renamed, moved or
    deleted. A guard that goes quiet is now caught by the change that quietened it.
  - `.github/workflows/mutation.yml` is gone and the job lives in `ci.yml`, behind the same CI gate
    as every other job, so a survivor blocks a merge rather than sending a mail on Sunday.

### Fixed

- **Three of the mutations pointed at code that had moved, so `mutate.sh` could not run.** An entry
  whose original text is no longer in the file it names is reported `STALE` and counted as a
  survivor, which fails the whole run. `PEAK` had moved from `AudioManager` to `SoundBank`,
  `HEADROOM` had become `MixTable.HEADROOM_DB` and changed units with it, and one entry still broke
  the thrower's telegraph. Both survivors are repointed and proved — the peak mutation makes
  `verify_audio` report two sounds twenty decibels under what they declared, and the headroom
  mutation makes `verify_mix` say in as many words that a night wave clips.
  - **And with the table able to run again, two entries turned out to measure nothing.** The tide's
    `drains` and `drains_from` were mutated on the `@export` default in `tide_data.gd`, which
    `data/combat/tide.tres` overrides on every load — so the game got the shipped figure whatever
    the mutation said, and `verify_drowning` was right not to notice. Both now mutate the `.tres`,
    where the number actually lives, and both are caught. They were the only two of their kind.

### Removed

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

- **Five constants nothing read, and the comments that vouched for them.** `Enemy.CHEST_HEIGHT`
  named `verify_sightlines` as its keeper, and that check went out with the thrower.
  `WeaponPickup.LABEL_HEIGHT` was a second home for a height the scene already sets — the same 1.3,
  written twice. `AudioManager.BODY_DECAY` said it was "the thud both hits share" long after each
  impact family got a decay of its own. `PosedMesh.PER_VERTEX` was a hard-coded four under a
  docstring saying the figure is read rather than assumed — which the code does, from the arrays,
  three lines further down. `Emphasis.NOTHING` was never returned; the decision it was written to
  record, that an ordinary hit gets no mark at all, moves onto `for_hit`, which is what makes it.

- **Every weapon explains itself when it reaches the hand.** There was one line, shown once a run,
  for whichever weapon happened to be found first — so the gun taught nothing at all, and a stick
  found second would have taught the gun's lesson. Now the stick says *[attack] to swing it —
  [weapon_next] to switch weapons* and the gun says *[attack] to fire — walk over rounds to get
  more*, each the first time that weapon goes in the bag.
  - **The stick carries the swap key** because it is the first thing the bag has to switch between.
    Nothing else in the game names that key, so `verify_tutorial` asserts the stick's line still
    does rather than trusting the copy to stay right.
  - Both weapons drop on wave 1, so two can be found seconds apart: the second **queues** behind the
    first instead of replacing a line the player is still reading. The check pushes a weapon in
    halfway through another's line, which is the case a queue filled before the first line was ever
    shown does not exercise.
  - The glyph is read off the binding as always, so the swap reads **E** and not the `Tab` the notes
    for 0.2.0 claimed — that key moved when swapping became `E` and picking up became `F`.

## [0.2.0] - 2026-09-14

Two archetypes leave the island and nothing replaces them; the sea kills for the first time;
and the macOS build can be opened, which the 0.1.0 one could not.

### Added

- **The first weapon picked up says how to switch.** Nobody could find the swap: the only thing
  that ever named `Tab` was the input table. The first pickup of a run begun from the title now
  shows *[Tab] to switch weapons* — RB on a pad — for its own `seconds`, once, and waits for the
  opening lines if they are still up. Fading one line out no longer hides the next one shown
  straight after it.

- **A drowned player struggles and goes under.** Dying out of their depth no longer hands the body
  to the ragdoll, which had nothing true to do in the water: the player plays `drowning`,
  Purple-Sigil's looping struggle with a strong bob, and sinks while it loops. The summary waits
  until the body is all the way under, and the sea stops carrying it back to the sand. A death on
  land, or in the shallows, still falls the way the blow threw it.
- **Forcing against the sea is exponential.** Walking out against the push doubles the drain every
  second it goes on, up to a cap, and resets the moment the player stops heading out — drifting out
  of depth still costs the ordinary rate. Figures in `data/combat/tide.tres`.
- **The accessibility switches are held together, not one at a time.** Each already had a check of
  its own — the shake slider means nought at nought, reduce-flashing damps the flare and leaves the
  debris, no switch is dead — and one at a time is not the question a player who needs all of them
  is asking. `verify_access` puts every switch at the end of its travel at the same time and holds
  the floor under them: **a switch may take away emphasis, it may never take away a signal.**
  - What survives, whatever is turned off: the **telegraph**, because it is geometry and a lean
    outlives greyscale and every switch in the menu; the **difference between a perfect hit and an
    ordinary one**, in more than one way that is neither colour nor brightness — more debris, thrown
    faster, lasting longer, with damage numbers off by default so the effect carries the whole
    message; and a **clock nobody left stopped**, after a burst of requests and not merely after
    one.
  - Written down once in `docs/game-design.md` under *The floor under the switches*, so the next
    effect has a rule to be written against rather than a precedent to be guessed at.
  - The check found nothing broken in the game, and one thing broken in itself: the first version
    loaded the arena rather than `main.tscn`, so it emitted hitstop requests into a bus where
    `HitFeedback` was not listening and passed without testing anything. The mutation caught it.
    `verify_feel` warns about that exact trap in its own docstring, and this is the second time the
    project has paid for it.
- **The HUD says what is in hand and what is in the bag.** The three weapons sit bottom right in the
  order the swap key walks along them: the one being swung is lit and wears the active chip, a
  weapon carried but not held is dim, and one nobody has found yet is dimmer still and says **the
  wave it turns up in** rather than its key — read off the weapon, so the row cannot promise a wave
  the pickup director disagrees with. The slots are built from `Arsenal`, so a fourth weapon is a
  `.tres` and not an edit to a scene.
  - The badge on each slot is **the key on the device in hand**, and a pad has no direct weapon
    keys, so there the slots carry no badge and the cycle key at the end of the row is the only one
    shown. `verify_hud` moves the hand from keyboard to pad and asserts the row changes with it.

### Changed

- **A change to the game is now a line in the changelog, and CI says so.** A pull request touching
  `scripts/`, `scenes/`, `data/` or `assets/` without writing an entry fails `Pull request hygiene`.
  Six shipped without one in a single evening — a new font, the studio credit, the whole soundtrack,
  the length of a wave — and none of it was in the 0.1.0 notes until the release was read against
  the merge log. Nothing in a diff shows an entry that was never written, which is the whole reason
  it has to be a rule rather than a habit. The label `no changelog` is the way out for a change a
  player could not notice.

- **Swapping weapons is `E`, and picking one up is `F`.** They were the other way round. Swapping is
  something the player does inside a fight, several times a wave, under pressure; picking up is done
  once, standing still, with a prompt on the ground naming the key. The hand belongs to the thing
  done often. The pickup prompt renders whatever `interact` is bound to, so the letter on the ground
  moved with it. `Tab` is free again — it had been sharing with `ui_focus_next`.
  - On a pad nothing moved: the swap has been **RB** and **LB** all along.

### Removed

- **The reaper is gone too. The island is the farmhand and the pirate.** Removed rather than left
  at a share of zero — the archetype, his sweep, his telegraph, his draw and blow, his locale row,
  and `verify_playfield`, the check that walked nineteen thousand square metres asking whether any
  corner answered a 160° arc with nothing. That was his question and nobody else's.
  - **Two archetypes, so two bands.** Waves 1 to 3 are farmhands and nothing else; the pirate joins
    at wave 4 at a flat tenth and never leaves. The seven bands that existed to move the reaper's
    share collapse into those two.
  - **The mix stops being a difficulty lever**, and that is a consequence rather than a decision.
    One swarm archetype and one flat hazard leave a band nothing to escalate, so every wave from the
    fourth is composed identically and the whole curve is carried by `hp_mult`, `dmg_mult` and the
    crowd.
  - **The late game is gentler again.** Measured by `tools/measure_waves.tscn`, wave 15 goes from
    81 to 73 points of incoming damage a second at the night pool and survival under full contact
    from 1.5 s to 1.6 s — a smaller drop than the thrower's, because the reaper was competing for a
    token the farmhand would otherwise have spent rather than carrying one of his own.
  - **The camera's zoom floor is re-derived.** Eleven metres was set by the reaper's 2.8 m reach
    plus the 1.8 m he covered winding up; it is now the pirate's 2.0 m plus 2.4 m, so the bound is
    4.4 m of visible ground rather than 4.6. Eleven still clears it, and `verify_view` measures it
    off the resources rather than the comment.

- **The thrower is gone, and nothing stands in for him.** He was never wanted: issue #9 asked for a
  ranged farmer and #73 built him, and the design he was built into is not the one this game is.
  Removed rather than switched off — the archetype, his stone, the `Projectile` he flew, the
  `Retreat` state, the separate ranged token pool, `EnemyData.is_ranged`, `retreat_range` and
  `projectile`, the rule that no wave may open with a ranged body, his telegraph, his clips, his
  locale row, and `verify_sightlines`, which existed to answer a question only he asked.
  - **The late game is measurably gentler**, and this is the price rather than a side effect. His
    token was a free one: he queued on a pool nobody else could use, so being shot at cost nothing
    the melee pool was already spending. Measured by `tools/measure_waves.tscn`, wave 15 goes from
    103 to 81 points of incoming damage a second at the night pool, and survival under full contact
    from 1.2 s to 1.5 s.
  - **The curve is smoother for it.** The worst wave-to-wave step in the run was his arrival at 32
    per cent; the worst now is the pirate's at 17, and every other step is under 14.

### Fixed

- **The macOS build could not be opened at all.** The `.app` shipped with a signature claiming
  resources it did not carry — Godot's export templates are cross-platform but a macOS bundle's
  seal is not, and the Linux runner cannot write one. macOS calls that *damaged* rather than
  *unsigned*, which is the refusal with **no Open Anyway offered**: the player has no way through
  it. The bundle is now re-sealed ad-hoc on a macOS runner, which turns the hard refusal into the
  ordinary unidentified-developer one that System Settings can approve. Measured both ways on the
  published 0.1.0 archive, and through a full zip round-trip. Notarisation (#88) is what removes the
  approval step; this only makes it reachable.

## [0.1.0] - 2026-09-13

The first tagged build: a fifteen-wave run on a generated island, three weapons, a merchant
between waves — held by 42 headless checks in CI and 50 mutations that prove those checks can
still fail.

### Added

- **A soundtrack.** Five licensed tracks, drawn as a shuffle bag so everything plays before
  anything repeats, and playing from the first frame — before the intro, which is a silent video, so
  the music is its audio. A track carries its **own measured loudness** and the gain is derived from
  it, the way a recorded voice already was: five masters six decibels apart would otherwise step the
  level every time the track changed.
- **The sea is where the sea is.** The surf was one flat loop at a fixed level everywhere — as loud
  in the middle of the island as with your feet in the water. The shoreline is now found by asking
  the terrain rather than assuming a radius, and a ring of eight sources sits on it, deliberately
  out of phase so they do not comb-filter into one loop played eight times. Measured: **-42.7 dB
  inland against -30.8 dB at the water**.
- **Ten more farmer lines**, nineteen in all, each levelled to the family's own measured loudness.
  Five arrived as voice messages recorded nine decibels hot, one clipped at source; dropped in raw
  they would have been nine decibels louder than every other farmer on the island.
- **The draw budget is measured with the crowd in the frame.** `measure_draw` places thirty bodies
  in front of the camera and reports a frame time against the 16.7 ms a 60 Hz frame has. On an M2
  Pro at 1080p: **9.74 ms empty, 10.32 at thirty, 10.83 at sixty.** Double the budget costs 1.1 ms
  more than an empty island, which costs 9.74 on its own — the crowd is not what spends the frame.


### Added

- **The sea is deep enough to drown in** (#196). Past the wading limit the bar comes down, faster
  the deeper you are — nothing at 1.1 m, twenty health a second by 1.6 — and at zero the run ends
  through `player_died`, the same door as any other death.
  - **The push is untouched.** It already beat a walk before the water was over a head, which is
    exactly what makes this fair: a walk out against it stalls at about 1.4 m and a sprint at 1.6,
    so drowning costs five to eight seconds of holding yourself out there while watching it happen.
    Stop pushing and the sea carries you back in. There is no line you cross.
  - **It drains rather than killing at a depth.** A threshold is unreadable — fine, then the run is
    over — while a bar coming down is on the screen the player already watches and tells them how
    long they have.
  - **No drowning clip, and this does not fake one.** The body sinking is the terrain falling away
    under it, which is free and already true. When the clip lands it plays where every other death
    animation does, and nothing here has to change.
  - Figures in `data/combat/tide.tres`, and in `docs/game-design.md` once.

### Fixed

- **The pirate wears his own paint.** `char_pirate.glb` shipped with only the eyes' image: the body
  and club textures in `char_pirate.blend` pointed at a folder on the artist's desktop, never loaded
  during the export, and the exporter dropped them without a word — so Godot drew both white. They
  point at `art-source/textures/pirate_texture.png` and `stick.png` now, and the re-exported rig
  embeds all three images; the clips are unchanged.
- **Nobody could find a coconut.** Reported as the feature not working at all; it worked perfectly —
  ten drops out of ten, two in a live wave, exactly the wave-1 ceiling. It was simply impossible to
  know any of it had happened. Three reasons, each measured: they were judged in frame at the palm
  rather than at the landing spot, so half of them fell out of shot; fourteen centimetres of brown on
  sand under brown trunks through a pixel filter is not a pickup, so it carries its own light now;
  and walking over one is the only pickup with no prompt, so the feed says `Coconut +25 health`. A
  real bug turned up on the way — `drop_from` wrote `global_position` **before the node entered the
  tree**, which Godot discards, so a coconut sat at the origin until its first fall step.

- **The itch.io publish had the wrong account.** `ITCH_USER` was the repository owner, and the page
  lives at `garden-fence/fight-island`. The 0.1.0 tag exported both platforms and attached them to
  the GitHub release before failing on `/wharf/builds: invalid target (bad user)` — everything up to
  the last step was fine, which is why nothing caught it earlier: it is the one part of the chain
  that cannot be checked without a key.

- **The mix was written in peaks, and peaks measure the wrong thing.** Two sounds normalised to the
  same peak are not the same loudness and are not close — measured across this game's own sounds the
  gap reached seventeen decibels. The farmers sat at a footstep's loudness because a voice level was
  applied to recordings already louder than it. The table is in loudness now, and so is the check
  that should have caught it: it had compared a gain against a peak, two numbers in different units,
  neither of them a loudness.
- **The soundtrack shipped inaudible**, at -46.6 dB: under the menu click and barely over a
  footstep, so in a menu the button was louder than the music. Same fault as the farmers, on the one
  family still measured in the wrong unit — a level applied as a gain to an already-mastered
  recording. Two guards now hold it: the soundtrack must sit above the furniture and under a
  wind-up, and every shipped track must declare a measured loudness.

- **A body could sit at zero health, alive, for ever.** `HealthComponent` lost a death to floating
  point: a drain lands on the floor by subtraction rather than by a blow that overshoots it, and
  `0.333333 - 0.333333` is not exactly zero. The bar held a billionth of a point, `current_health <=
  0.0` was false, nobody died — and the next frame was swallowed by the no-change guard, because a
  billionth is inside `is_equal_approx`. Found by the drowning check, which is the first thing in
  the game to take health away a fraction at a time rather than in whole blows.

### Changed

- **The menus are set in a face you can read.** Badeen Display was chosen for impact and failed the
  one thing a menu owes the player: its counters close up at every size, so at 40 px `THE STUDIO`
  rendered as a row of filled blocks. Oswald Medium replaces it through one `ext_resource` that
  eight theme variations point at. A standing rule goes with it — Badeen drew its Latin digits as
  the Arabic-Indic forms, so no string carrying a number could be set in it.
- **A wave is ninety seconds**, forty-five of light and forty-five of dark, down from four minutes.
  Fifteen waves goes from about an hour to about twenty-five minutes. The turn of the sky moved with
  it: `turning_share` is now a fact about each phase rather than one global, and **dawn and dusk
  carry all of it** — they exist to *be* the turn, and holding a dusk before flipping into night in
  its last few seconds was the abrupt version of the thing dusk was added to smooth.
- **The credits say whose game it is.** A `The studio` row leads the roll — Garden Fence,
  gardenfence.ch — through the existing document-to-screen chain rather than around it.
- **The whole mix was set by ear**, in a fight, at a fader desk built for it, and the figures it was
  left at are the defaults.

- **Both weapons lie on the island from wave 1.** The stick used to arrive in wave 2 and the gun in
  wave 4, and holding them back cost more than it bought: a weapon nobody has found is a weapon that
  does not exist, and behind the gun sat an upgrade track the merchant refuses until the weapon is
  carried — so a player saving for it had money with nowhere to go for four waves. Ammunition comes
  off the bodies from the first wave for the same reason: the pocket only fills once the gun is in
  the bag.
  - The gun **was** being dropped, and in shot: rolled two hundred times on the real island it landed
    inside the camera's frustum two hundred times. What it was not, was **visible** — a borrowed rig
    mesh at its own scale is 0.54 m of dark metal on pale sand under a camera twenty metres up, a
    third of the carved shape it replaced. Everything borrowed is brought to one length on the
    ground now, so a weapon reads as a thing to pick up before it reads as a model of itself.
  - `verify_weapons` gains the assertion the failure needed: **every upgrade track that names a
    weapon names a weapon that is dropped.** A track for a weapon nobody can find is a locked card
    for the length of a run, and nothing said so.

- **The tutorial runs on a clock, before wave 1.** It was wave 1 itself, seven lessons each waiting
  for the player to perform them, and the parry lesson could hold the wave open for ever. After the
  new-run opening, four lines now follow one another on an empty island — how the player got here,
  punch and dodge, sprint, survive — each for its own `seconds` in `data/tutorial/`, with the real
  buttons of the device in hand. Then wave 1 starts at once. Nothing waits for an input. It shows on
  every run begun from the title, like the opening; a retry, a restart or a resume skips it.

- **The fifteen waves are tuned, off a measurement rather than off the formulas** (#82). The curve
  now steps by about 11 and 14 per cent through the waves that teach, by 17 to 22 through 4–6 where
  three archetypes arrive one per wave, and by under 5 across 12–15, which is the endurance band
  doing what its name says.
  - **The cliff was the thrower, and it was the token pool that made it one.** He queues on the
    ranged pool, which is one token and nobody else's, so *one* thrower standing is the whole of
    what being shot at costs and a second adds nothing. Landing him whole at thirteen per cent in
    wave 5 was a **32 per cent jump in incoming damage in a single wave**, against a run that
    otherwise steps by five to fifteen. He opens at six per cent in wave 5 and doubles at wave 6.
  - **The archetypes no longer arrive together.** Waves 1 and 2 are farmhands and nothing else —
    that is where the player uses what the tutorial taught rather than meeting somebody new. Then
    the reaper at 3, the pirate at 4, the thrower at 5.
  - **The roster budget is a budget again.** `enemy_count` was `12 + floor(n * 6)`, sized for a
    four-minute wave; after the wave was cut to ninety seconds it promised a hundred and two bodies
    at wave fifteen and delivered twenty-two, and the number *fell* as the waves rose because bodies
    harden faster than the player's damage grows. It is `16 + floor(n * 1.2)` — just above what can
    physically be killed, so outrunning a wave is something a good player can do.
  - **The crowd climbs to the end**: `max_alive` caps at 14 rather than 12, and reaches it at wave
    13 instead of stopping at 10. It is not the damage dial — the pool is two bodies by day and
    three at night in every wave of the run — so what a bigger crowd adds is somebody always in the
    way, which is the difference between an endurance test and a harder wave six.

  `docs/game-design.md` said `max_alive` was "the real pressure dial" and that a run affords about
  two tracks of five. Neither was true: the pool caps damage whatever the crowd, and the run earns
  another 680 or so in kill money on top of the 2 010 in rewards — about three and a half tracks.
  Both are corrected rather than tuned away; the wind-up floor was not touched.


- **The merchant sells what you carry.** A weapon's upgrade track is refused until the weapon is in
  the bag — the stick is found in wave 2 and the gun in wave 4, and fifteen per cent more damage on
  something the player cannot swing yet is money spent on nothing they would only discover was
  worthless two waves later.
  - The card **stays on the shelf and says where the weapon turns up**, rather than disappearing.
    The screen already held that line — *a card nobody can read is a card nobody can want* — and a
    player who can see the gun track has a reason to save for the wave it arrives in.
  - The gate is on `can_buy`, not on the button. A card is one of two ways to reach a purchase and
    `buy()` is the other, so greying out a button that `buy()` would still honour is not a gate —
    which `verify_merchant` now proves by calling `buy()` directly with an empty bag.
- **`stress_enemies` times the real separation rule, not a copy of it.** The tool held its own copy
  of the arithmetic because the method was private, and a copy measures whatever the copy still
  does — the day the rule changes, the tool goes on reporting the cost of the one it replaced and
  neither of them is wrong. The isolated pass calls `Enemy._separation()` itself, reaching past the
  underscore rather than keeping a copy that can drift.
- The spatial grid for #31 was written a **third** time — bucketed, over pairs, addressed by index
  into packed arrays rather than through a dictionary — measured against the scan in the same
  process, and thrown away a third time: 15 µs per body against 27 at thirty, 8 against 49 at a
  hundred and twenty. The pass really is about twice as fast at the budget — what makes it not worth
  shipping is where the time goes, because that pass is 0.36 ms of a frame whose other 9.7 ms are
  the island being drawn. `docs/architecture.md` carries the three sets of figures so the fourth
  attempt has somewhere to read them.

### Fixed

- **`verify_waves` failed on a distance it measured too late** — "something spawned 11.49 m from
  the player", on a rule of twelve that nothing had broken (#216). `SpawnDirector` measures the
  distance against where the player stands when it places the body; the check measured it again
  afterwards, and in between the arriving wave shoves him. The half-metre of slack the check carried
  for this — added in #167 for the same symptom — was a number chase: CI produced 0.51 m of drift.
  The distance is now judged in `_on_enemy_spawned`, at the instant the body arrives, the way the
  camera half of the same check already was. Same measurement as the rule, and no slack to excuse.

- **`verify_corpses` was a coin toss** — four runs in five on `main`, and it blocked every pull
  request behind it including the release. Three assertions flaked, and none of them was a bug in
  the game (#207).
  - The impulse was never being lost. Instrumenting `push_near` showed **sixteen bodies taking it
    every time**. What varies is how much of it reaches the *hips*, which is what the check reads,
    and that depends on the pose the tumble happened to leave: splayed on his back the hips travel a
    third of a metre, folded on his side a tenth. Both are a body reacting; only one was passing. A
    single blow now has to **disturb** the body — five centimetres, against a picture's nought and
    the two real modes' nine and thirty-three — and "shoved" is what a sustained walk into one has
    to do, which is a different claim and keeps its own figure.
  - The two shove checks **poll for the movement instead of reading at a fixed frame**. A ragdoll
    woken a frame later than usual had not finished travelling when the reading was taken, and the
    check reported that the player walks through corpses.
  - The sand check held the body's lowest point to 35 cm and read 36 on about one run in five. It is
    45 now: what it was written against was **two metres** of skin under the sand, and a centimetre
    is two machines' solvers disagreeing, not a body sinking.

### Added

- **`tools/measure_waves.tscn`** — the fifteen waves, read off the shipped resources: the crowd, the
  hit points standing, the damage coming in by day and by night, how long the player lives under
  full contact, how much of the roster can physically arrive, and what the run earns against what a
  track costs. It changes nothing and asserts nothing. A tuning pass is read off this page, and
  re-running it is how the next one starts.

- **The stick's return and finisher are authored.** `attack_stick_2` and `attack_stick_3` come from
  `Boy_stick_fight_2/3`, each with its own trail (`StickTrail2`, `StickTrail3`), and replace the
  stand-ins that replayed the backhand. The three swings were drawn on different guards, so the
  first two end with a key on the next swing's opening pose and the combo does not snap between
  hits; `verify_clips` holds the joins.

- **The island is drawn as pixel art.** The finished 3D frame is cut into fat pixels — two screen
  pixels across at 1080p — outlined along silhouettes and lit along creases, on a slightly smaller
  palette; the interface stays sharp. `PixelLook` runs after the transparent pass, so the sea, the
  blood and the particles are styled with everything else, and `data/fx/pixel_look.tres` tunes it.
  *Pixel art* under Video switches it off, live.

### Changed

- **The island is half the size.** `MAX_RADIUS` was 88 m — a hundred and seventy-six metres across
  for a fight that happens inside eighteen. Forty-four is still two and a half times the ring bodies
  arrive in: room to give ground and to break a thrower's line, and not room to get lost in.
  - **Halving a radius quarters an area**, so everything scattered by an absolute count came down
    with it — palms, rocks, pebbles, grass and bushes are each a quarter of what they were, or the
    same island would have been four times as dense.
  - **Five of the six rock formations would have been standing in the sea.** They sat a little past
    half the old radius, at the edge of the plateau. They and the five huts are *scaled* rather than
    re-placed, so the composition the fixed camera was chosen for is the one it was. `CORE_RADIUS`
    did not move: nine metres of flat ground is sized to the player, not to the island.
  - **The sea was audible in the middle** — 1.7 dB quieter inland than it was ankle-deep, where it
    is meant to be ten. `SurfBed.CARRIES` is a distance, and the only distance it is about is the
    one from the middle to the water, so it halved with the island. `FROM_THE_MIDDLE_DB` did not
    have to move at all.
  - `verify_navigation` aims at one authored boulder by its coordinates, written out on purpose;
    `verify_coconut` held the grove against a hundred palms and a forty-metre spread. Both follow
    the island now, and the coconut bounds sit well under what the island lays down rather than
    beside it — they are there to catch a `MultiMesh` that was not read, not to re-state a count.

### Changed

- **The gun's recoil is physics rather than a clip.** The arm goes to the ragdoll for a tenth of a
  second when the round leaves — thrown back and up at `AttackData.recoil` metres per second — and
  the simulator's influence falls to nought across the window so it eases back onto the animation.
  A shot never looks the same twice and never disagrees with where the body happened to be standing.
  - The three generated recoils are gone. There is **one** clip now, `aim_gun`, and all three shots
    fire from it: what the animation owes a shot is the body underneath it, and that body is the
    same for a tap, a double tap and a hand cannon.
  - **`aim_gun` carries no shooting arm**, and that is the whole trick. An AnimationPlayer and a
    skeleton modifier both write bone poses and the clip wins — measured rather than assumed: with
    the arm still in the clip the physical body swung five centimetres and the skin moved two
    millimetres, and the same shot rendered against one with no recoil at all was pixel for pixel
    the same picture. `mixamorig_RightHand` stays animated, so the revolver stays in the fist while
    the arm is thrown.
  - `verify_clips` holds both halves of that — no arm in the clip, the hand still in it — and
    `verify_knockdown` fires a real shot and asserts the arm is handed over, the hips never are,
    `is_running` stays false throughout, and the simulation is stopped when it ends.

- **The wave comes to the player.** Two numbers, and between them most of a wave stopped being spent
  walking.
  - Bodies arrive **12–18 m** away rather than 12–26. A farmer notices at nine metres, so one that
    landed at the far edge was fourteen metres of approach before anything happened — once per
    farmer, on a four-minute clock.
  - And **being ignored wakes him**. Ten seconds standing unnoticed and he comes looking, rousing
    the men beside him on the way; five seconds after dark, on the same `rouse_scale` that already
    carries a shout further. Standing still was a read with no clock on it, so a body nobody walked
    up to stood there until daybreak and the player had to go and fetch the rest one at a time.
  - `verify_waves` parks a body past its own notice radius, where nothing but the patience can move
    it, and holds both figures against **written-out** bounds — a watch window taken from the number
    being watched passes for every number, including a patience nobody would stand through.

### Added

- **A new run opens on the player waking up.** Purple-Sigil's `new_run_awakening` plays whole while
  the camera turns once round him, close and low, and opens out onto the game camera exactly — the
  turn's last point is where the game is played from, so nothing is cut to. For its length there is
  no body to control, no free head, no waves, no tutorial and no HUD. Only a run begun from the
  title opens this way; a retry, a restart or a resume goes straight in. `verify_run_intro` holds
  both.
- **Bottles in the grass where the player wakes up, and the midday sun catches them.** Seventy of
  Purple-Sigil's bottles, standing and lying, in glass, within ten metres of the spawn and nowhere
  else. Around midday the one whose glass best mirrors the sun into the camera throws a lens flare
  across the screen — a burst, a streak and a line of ghosts through the centre — and as the player
  moves, different bottles catch and let go. Reduced flashing turns it off. `SunGlint`, tuned by
  `data/fx/sun_glint.tres`.

- **The pirate comes ashore.** The rig arrived with #192 and nothing used it. He is an archetype
  now, and he is the hardest blow in the game: **22 damage**, nearly three farmhands, a quarter of
  the player's health off one mistake.
  - Two things keep that fair. He telegraphs for **0.80 s**, the longest wind-up there is, with the
    lowest and longest warning of the four — a pirate committing carries under a crowd at night,
    which is when he turns up. And he is **a tenth of a wave**, rolled per spawn rather than
    scheduled — a chance, not a quota, so whether a wave brings two of him or six is the wave's own
    business. His share is taken proportionally from the other three, so the triangle they form is
    untouched and the farmhand is still the most common thing on the island in every wave.
  - **His telegraph and his blow are cut out of the swing he already had.** The clip is one movement
    across three states, so `char_pirate_stand_ins.tres` slices it rather than inventing either
    half. Where to cut was measured off the shoulder's turn per twenty-fifth of the clip — a lift, a
    still, a strike, a still — and both ends of a slice are sampled rather than snapped to the
    nearest key, so the wind-up hands the blow a body it is already standing in.
  - **A body is pooled with the rig it was made with.** The ragdoll fitted its capsules to those
    vertices and the animation found that skeleton, so a pirate revived into a farmer's body would
    mean rebuilding every component that ever looked at a rig. `EnemyPool` keeps a shelf per body
    and `EnemyData.id` picks it; the three farmers go on sharing one.
  - `Enemy.body` is a `PackedScene` put on in `_enter_tree` rather than an instance saved into the
    scene — an inherited scene cannot swap a child that is already one, and `enemy_pirate.tscn`
    overrides the rig, the data and the stand-ins and nothing else.

- **The stick is in hand.** The clips arrived last; this is them reaching the game.
  - `idle_stick`, `walk_stick` and `dodge_roll_stick` play, off one line in
    `data/weapons/stick.tres` — `clip_suffix = &"_stick"` — and no code at all. That is what the
    suffix was built for, and `verify_clips` now equips the stick and reads the clip that comes out
    of the component, so clearing that line fails the build instead of quietly walking the player
    around empty-handed with a stick in his fist.
  - **The second and third swings move.** The rig carries the backhand and only the backhand, so the
    return and the finisher are that swing again, stretched to their own windows and lent by
    `char_player_stand_ins.tres`. Before this they played nothing: the arm held the last pose of the
    first swing through both of them while the damage went out.
  - Stretched from the clip's own keys rather than posed like the gun's stand-ins, which is what
    keeps the stick in the hand — `attack_stick_1` keys `Stick` and `StickTrail` frame by frame, and
    a posed stand-in would have swung an empty fist.
  - Not reversed, which was the obvious thing to try. The authored swing opens and closes on the
    grip, nought degrees apart, so playing it backwards travels the same arc and only moves where
    the fast part of it lands — a guess about somebody else's timing. That the swing opens and
    closes on the grip is what lets it be repeated at all, so the check holds each join to half a
    degree.
  - The inventory in `docs/asset-pipeline.md` is now **empty**: every clip either actor asks for
    exists or is lent. The section stays, and `verify_clips` reads the section rather than its rows,
    so the next gap has somewhere to be written down.

- **The stick swings, and the pirate is on the shelf.** Purple-Sigil's clips that had been sitting
  outside the project are in it now, exported and imported, and wired to nothing that was not
  already asking for them:
  - `attack_stick_1` plays the moment the stick swings, because the stick already named it. The
    stick itself is in the player's rig, keyed by each stick clip where it was held and a thousandth
    of its size everywhere else, with its swing trail.
  - `idle_stick`, `walk_stick` and `dodge_roll_stick` wait on `clip_suffix = &"_stick"`.
  - `char_pirate.glb` — Ennemi_2 — with `idle`, `walk`, `chase`, `attack` and both get-ups, its
    weapon keyed in every clip. No scene or archetype uses it yet.

  Sources are in `art-source/`; what is left to wire is in `docs/asset-pipeline.md`.
- **The player falls when they die.** The run ended on the rest pose — a body standing to attention
  under the screen that says it is over. The body goes to the physics now, the same
  `RagdollComponent` the farmers have used since they stopped sinking into the sand, so the fall
  agrees with where the player was standing, which way the blow came from and what they landed
  against. **`death` is off the clip list rather than waiting on it**: no clip could do the last of
  those.

- **The farmer swings.** His telegraph froze him mid-stride and the blow that followed moved nothing
  at all — `EnemyWindUp` and `EnemyAttack` named no clip, and the three `attack_*` names in
  `data/enemies` were promises the rig had never been asked to keep. Both states name their clip now,
  the way `PlayerAttack` already did, and six stand-ins are generated from the farmer's own idle:
  a draw and a blow for the farmhand, the reaper and the thrower.
  - The **pair** is the point. A blow lasts an eighth of a second — shorter than the crossfade into
    it — so an arm starting from wherever the walk cycle left it would spend the whole strike
    blending and read as nothing. The draw puts the arm where the blow begins, and `verify_clips`
    asserts the blow's first pose *is* the draw's last.
  - The telegraph stretches to the wind-up **actually being fought**, not the tuned one: the waves
    shorten it and the hour shortens it again, and the lean and the arm are driven by the same
    share so they cannot tell the player two different things.
  - The 35° lean is untouched. It is geometry at twenty metres and it survives greyscale; the arm
    says *which* farmer is swinging, which the lean never could.
- **`AttackData.windup_animation`**, for an attack whose wind-up is a state of its own. A second
  name rather than a prefix rule on the first: deriving `windup_punch` from `attack_punch` would be
  a convention nothing enforces, and the first attack to break it would play nothing and say so to
  nobody.
- **A blow bleeds, and the island keeps it.** Droplets are thrown the way the blow travelled,
  stretched along their own flight rather than tumbling as cubes. Stains come down where they land —
  at the victim's feet and thrown downstream, on sand or rock but never on the sea — first as sharp
  decals, and for good in a mask the ground's shader turns red and wet. A perfect blow spills more.
  Nothing is built mid-fight, and `verify_blood` holds all of it.
- **The parry has a body.** Pressing the defensive button played nothing, so the component fell back
  to the rest pose and the player went limp for nearly half a second — arms at their sides, in the
  one moment the game asks the most of them. There is a guard now, and it is **the state's own
  windows rather than a guess at them**: the hands snap up in a twentieth of a second, stay up for
  exactly as long as `PlayerParry` can still negate or halve, and come down across the recovery —
  which is the window where a mashed parry is punished, and now the window where the player can see
  they are open.
- **A stand-in that has come away from its rule now fails.** The clips are generated from the
  windows, so the two agree only while somebody rebakes. `verify_clips` compares each one's length
  against the rule it was built to, and says which command to run. `verify_animation` moved its
  clipless-state example from `Parry` to `Dead` — it was written to fail on purpose the day the clip
  it borrowed arrived, and it did.

- **The gun fires on camera.** `attack_gun_1/2/3` were named by the gun's `.tres` files and carried
  by no rig, so a shot moved not one bone: the component found no clip, fell back to the rest pose,
  and the rest pose on this rig is almost exactly the carry pose. Stand-ins are now generated by
  `tools/build_clips.gd` from the rig's own `idle_gun`, so the body stays the one that was posed and
  only the recoil is invented — the muzzle jumps, harder for a double tap and harder still for a
  charged shot, and is back on target before the recovery ends. **They are built to lose**: a
  stand-in is lent only for a name the rig has no clip of, so a hand-authored `attack_gun_1` retires
  it on the spot.
- **The missing clips are written down.** `tools/verify_clips.tscn` asks both actors for every clip
  their states and their attacks name, and holds the inventory in `docs/asset-pipeline.md` in both
  directions — an undocumented gap fails, and so does a row for a clip that now plays. Eight are on
  the list today, including the player's `parry` and all three of the reaper's, the farmhand's and
  the thrower's blows.
- **The people are in the credits.** Pepito2t on development, Purple-Sigil on 3D and VFX,
  DabitheSheep on audio — first in the document and first on the screen, because who made the game
  is the credit a player is actually owed and the asset ledger answers a different question.

### Fixed

- **The tutorial could not be finished.** Wave 1 stopped on the chain lesson, on every first run.
  The director asked for the second blow of a chain and then recognised it by `Player.chain_index` —
  which is the window a *finished* swing leaves open, and entering the next swing closes it, so it
  reads -1 for the whole of every blow that lands. A chained hit is named by the attack that landed
  instead, which is what `attack_landed` was already carrying.
- **And past that it stopped again at the dodge lesson.** The farmhand sent for the attack lesson is
  spawned harmless, harmlessness is decided at spawn, and the director only ever tops the island
  *up* — so the body still standing when the gloves were meant to come off could never swing, and a
  lesson that ends on being swung at could never end. A step says what should be standing, and what
  is standing is now made to match it.
- **Switching *Show tutorial prompts* off no longer leaves a wave that cannot end.** The parry holds
  wave 1 open until it lands and nothing on screen was left to say so. The tutorial hands the island
  back instead, and a run started with the toggle already off never takes it in the first place.
- **Wave 1 counts towards the run clock**, like every other wave. Halting the formula stopped the
  clock, and nothing started it again until wave 2 arrived.
- `verify_tutorial` answers the chain lesson with a real attack rather than by writing the player's
  bookkeeping by hand, watches a standing farmer be allowed to swing, and switches the prompts off
  mid-lesson — the three things that were true of the checks and not of the game.
- **The macOS build could not be made at all.** Apple Silicon reads ASTC and nothing else, and
  `import_etc2_astc` was off — so the universal preset refused to export with "Cannot export for
  universal or arm64 if ETC2 ASTC texture format is disabled". Nothing in the project could see it,
  because no check and no script reads an export preset: it would have surfaced on the first `v*`
  tag, with the release already cut and nothing to attach. Found by dry-running `release.yml`, which
  is now written down as the thing to do before tagging. `verify_project_config` holds the settings
  the presets depend on.
- **Godot aborted at the end of the macOS export**, after the pack was written — a core dump on
  shutdown, which `set -e` turns into a failed release. The cause was `addons/gdUnit4`, a test
  framework that no export filter excluded and that was therefore being packed into the game. Both
  presets exclude it now: the export finishes cleanly and the shipped binaries no longer carry a
  test runner. Proven by dry-running the workflow twice — the same run that found the ASTC setting.

- **A dying body took the knock rate whole.** `KnockdownData.knock_speed` is metres per second *per
  point of `AttackData.stagger`*, and `EnemyDead` passed it bare — so a man killed by a jab was
  thrown as hard as one killed by the heaviest blow in the game. It is the killing blow's own share
  now, on both sides. `verify_corpses` holds it two ways: an absolute bound on how far the player
  may be thrown, and — because a bound on one distance passes any constant you like — a jab and an
  uppercut have to lay two bodies **visibly apart**.
- **Nothing stopped an animation from fighting the simulator.** Both write bone poses and the second
  writer wins. `EnemyStagger` avoided it by naming no clip, which works on the farmer only because
  his rig carries no `RESET` — the player's does, so the same arrangement would have stood a dying
  man upright on the frame he was knocked down. `AnimationComponent` now lets go of the rig when the
  physics takes the body and refuses to touch it until the physics gives it back.
- **A ragdoll is a body, not a sock.** Build 6 threw sixteen one-kilogram capsules a few
  centimetres across on the same loose cone, and a farmer folded like cloth with his skin a metre
  into the sand. Each bone now weighs its anthropometric share of the body, its capsule is fitted to
  the vertices it carries, and its joint is limited in an anatomical frame — a knee folds back, a
  neck does not turn the head round. `RagdollData` and `JointLimits` carry all of it.
- **Corpses lie on the sand and stay bodies.** They were pictures lifted onto the navigation mesh,
  which sits above the terrain, so every one hovered and a body still sliding when the fall ended
  froze in place. A corpse now takes the tumble over and keeps its ragdoll until it is still, then
  rests as a baked mesh with no skeleton in the tree. Walking into one shoves it; striking one
  throws it and it bleeds, without the blow counting as a hit. `verify_corpses` holds all of it.
- **The music slider reached nothing.** `MusicBed` lerped the `Music` bus towards nought every frame
  while `Settings` wrote the player's figure to it once, so the slider was overwritten within about
  a second of the arena loading — and `_exit_tree` handed full volume back on the way to the title.
  A bus each fixes it for good: the bed and the jukebox now sit on a new **`MusicDuck`** bus that
  sends to `Music`, the duck happens under the player's setting rather than instead of it, and
  `Settings` is the only thing that ever writes `Music`.
- **One stone in the air at the wrong moment and no farmer threw again.** A thrower retired or
  killed mid-flight only *deferred* its ranged token, went into the pool, and `revive` cleared the
  debt — so the pool of one stayed booked to a body that no longer existed and every later thrower
  was refused a wind-up. A body leaving the fight now lets go of both the stone and the token, and
  disconnects the old stone so it cannot release the token its successor is holding.
- **A weapon nobody picked up was lost for the run.** The pickup director dropped a weapon on the
  one wave matching its `found_at_wave`, and a pickup is a node in the arena rather than a saved
  fact — so clearing wave 2 without walking over the stick and resuming meant playing out the run on
  fists. A weapon is **owed** from its wave onwards now, once per run.
- **The money chip froze mid-pulse.** The HUD kept one tween handle for two chips, and the payout
  and the scavenged round come off the same body — so the second pulse killed the first one's tween
  and left the money chip stretched for the rest of the run. A tween per chip.
- **The run clock counted the title screen.** Quitting mid-wave keeps the run and the wave on
  purpose, which is what makes it resume into that wave — so the clock cannot be gated on either. It
  follows a runtime `fighting` flag the wave director owns instead, and a laptop left open on the
  menu no longer adds hours to the summary.
- **The arrow keys had no name.** `InputBindings` read only `physical_keycode`, and Godot's own
  `ui_*` defaults are bound by logical keycode — so they described to an **empty string**, which is
  not `UNBOUND` and which nothing therefore noticed. The credits screen shipped a hint reading
  `SCROLL` with no key in front of it.
- `verify_glyphs` checked the hints of the options screen alone and passed while that shipped. It
  finds every scene carrying a hint now, and holds a floor on how many it expects to find.
- `verify_strings` asked the CSV whether a key existed. **The CSV is not what the game reads** —
  Godot compiles it, and a row added without a re-import is a row `tr()` has never heard of. It
  asks `tr()` now, which is the question the screen asks.

### Changed

- **What grows on the island is Purple-Sigil's clusters, and the grass is no longer planted.**
  Grass, bushes and palms come in sizes now — one plant, a few, a thicket — drawn from a mix that
  slides from mostly singles by the water to mostly thickets inland, with every size still turning
  up everywhere. The grass lost the sixty-centimetre spacing that had laid it out in step: clusters
  overlap, and two scales of noise cut clearings into it, and there is twice as much of it. The
  ground under grass is a light yellow-green wherever grass can grow — the old green was read as
  linear and came out nearly white — and the grass is tinted a shade warmer. The scattered stone is
  Purple-Sigil's seven rocks, bare on the sand and mossy inland, the pillars held to a farmer's
  height; the six rock formations are her big single rock grown to size, and Kenney's boulder is
  gone.
  The bushes' leaves are cut out along their painted alpha, which the foliage shader had ignored.
  The old single `bush`, `grass_tuft` and `palm_tree` models are gone. The bushes cost a ninth of
  what they did; the grass nearly four times.
- **A wave is four minutes rather than six** — two of daylight and two of dark. Every phase keeps
  its share of the turn, its opening hour and every rule in its column, so the ramp is the one the
  design already describes, walked at a pace that does not ask for ninety minutes to see fifteen
  waves. The one thing it changes beyond the clock: a late wave, which ended on the hour rather
  than on an empty roster, now sends a third fewer bodies before daybreak.

- The duck bus is named once, on `AudioManager`, instead of written out as `"MusicDuck"` in the bed,
  the jukebox and the bus lookup. A rename in the layout used to leave `get_bus_index` returning -1
  in whichever of the three was missed, with nothing to say so — a silent bed, or a duck that never
  came off. Carried over from the closed #181, which had it right.

- **A new intro video** with the VFX pass — impact shake, bloom, chromatic aberration, grain and a
  particle layer keyed to where the logo's planks land. The two scripts that generate it are in
  `art-source/video/`, the same way a `.blend` lives there and the `.glb` ships.

### Fixed

- **The intro video had never been credited**, and nor had `bird_fly.glb`. `docs/credits.md` states
  the rule in its own second line — *a file with no row does not ship* — and nothing enforced it.
  `verify_credits` holds the document against the baked resource and the screen, which is a
  different question and cannot see a file nobody wrote down.

### Added

- `tools/verify_shipped.tscn` — every file under `assets/` that is content rather than a Godot
  sidecar has a row. A row may name a family (`farmer_01..09.wav`), and a texture is covered by the
  model it was imported out of, because it is the same asset.

### Added

- **The dead stay where they fall.** A killed farmer is thrown by the ragdoll, lands, and the pose
  he landed in is kept. The pile builds across the waves — it is the record of the run, and it used
  to sink into the sand at 1.2 m/s.
- **A corpse is not an enemy.** The body goes straight back to the pool of thirty-two; what stays is
  the picture, with no script, no collision, no physics and **no skeleton**. `PosedMesh` skins every
  vertex once on the processor and leaves a static mesh — without that a corpse cost 0.4 ms a frame
  even stripped and disabled, because a `Skeleton3D` updates on an engine notification rather than
  in `_process`, and sixteen of them came to 15 ms of a 16.7 ms frame.
- `RagdollComponent.settle_pose()`, which pins where the physics actually put the bones into the
  skeleton. The simulator is a `SkeletonModifier3D`: its output reaches the skin but never the
  skeleton's own pose, so a corpse read off the skeleton came out standing to attention.
- `tools/verify_corpses.tscn` — he lands, he lies down, his lowest vertex clears the sand, his body
  returns to the pool, and the pile has a ceiling.

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

[Unreleased]: https://github.com/pepito2t/fight-island/compare/v0.2.0...main
[0.2.0]: https://github.com/pepito2t/fight-island/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/pepito2t/fight-island/releases/tag/v0.1.0
