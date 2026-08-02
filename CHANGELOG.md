# Changelog

All notable changes to this project are documented in this file.

## [1.1.0] - 2026-08-02

### Added

- Oak's bilingual Research Log in his Lab, with current objectives, circuit
  progress, encounter requirements, caught status and live roamer routes.
- Phase-aware reactions from seven NPCs across Kanto, covering the initial
  rumors, Apex escalation, legendary hunt, Crown Circuit and final victory.
- Unique atmospheric introductions, cries and white-flash transitions for
  all ten legendary encounters.
- A one-time legendary-hunt Rival event after the first legendary capture,
  using a new six-Pokémon, non-legendary level-100 roster.
- A bilingual Crown Archive on the Hall-of-Fame console that records field
  rematches, circuit crests, titles, legendary captures and the Rival event.

### Changed

- Renamed the visible mod from **Trainer Rematch** to **Kanto Ascendant** to
  reflect its full post-game scope. The internal `trainer_rematch` ID remains
  unchanged for save and option compatibility.

## [1.0.10] - 2026-08-02

### Added

- A one-time Professor Oak event scene after the first Champion victory and
  immediately before the Hall of Fame. Oak reports increasing legendary
  sightings, strange shadows, storms and unknown beasts across Kanto.
- Complete English and German versions selected by the existing language
  system. If every legendary encounter is disabled, Oak uses a matching
  non-legendary post-game announcement instead.

### Changed

- Later League clears restore Oak's original invitation, keeping the sighting
  announcement a story event rather than repeatable dialogue.

## [1.0.9] - 2026-08-02

### Changed

- Raised BALANCED rematch loot to Nugget 20%, Rare Candy 15%, PP Up 10%,
  Max Revive 8%, the unique EXP.ALL/EP-Teiler 20%, and Master Ball 1%.
- Reworked GENEROUS into its own richer table: Nugget 26%, Rare Candy 20%,
  PP Up 15%, Max Revive 12%, EXP.ALL/EP-Teiler 25%, and Master Ball 2%.
- Kept all strength and progression requirements unchanged. Once unlocked, a
  Master Ball now takes about 100 BALANCED or 50 GENEROUS eligible victories
  on average instead of roughly 1,000.

## [1.0.8] - 2026-08-02

### Added

- Optional rare item loot after winning field-trainer rematches.
- Balanced drop bands: Nugget 10%, Rare Candy 4%, PP Up 3%, Max Revive 2%,
  the unique EXP.ALL/EP-Teiler 1%, and Master Ball 0.1%.
- Strength gates for valuable loot. EXP.ALL requires an average level-40
  opponent; Master Ball requires average level 80 and the Apex Champion win.
- **REMATCH LOOT / REVANCHEN-BEUTE** with `OFF`, `BALANCED` and `GENEROUS`.
  Generous mode doubles each fixed band.
- Full-Bag protection: the individual trainer reserves a rolled reward and
  delivers it later when room is available.

### Changed

- Removed the artificial +20 field-trainer boost limit. Repeated battles and
  silent training now continue until each enemy Pokémon naturally reaches
  level 100.
- EXP.ALL is treated as a unique reward and uses the engine's existing,
  functional Gen-1 party experience distribution. Its Oak's Aide flag is
  synchronized to prevent a duplicate.
- Master Balls remain repeatable but cannot drop before the legendary hunt.

## [1.0.7] - 2026-08-02

### Added

- All 47 trainer classes now have thematic Pokémon recruitment pools.
- Growing field trainers add another party member at every second strength
  tier until they reach the six-Pokémon limit.
- Recruitment prefers species sharing the original team's types, avoids
  duplicates where possible and is deterministic per individual trainer.
- Recruited evolutionary families advance through their normal level
  evolutions when the projected rematch level is high enough.
- A bilingual **TEAM GROWTH / TEAM-WACHSTUM** option can disable recruitment
  while leaving step cooldowns and level growth active.

### Changed

- Both completed rematches and silent background-training cycles contribute
  toward party recruitment.
- Ordinary field trainers can never recruit legendary Pokémon.
- Strength warnings now preview the expanded party as well as its higher
  levels.

## [1.0.6] - 2026-08-02

### Added

- Ready field trainers now continue training on invisible background counters
  when the player walks past them without accepting a rematch.
- Every fully completed silent counter adds one normal growth tier to that
  trainer's next team: +2 levels with the default setting.
- Silent training is persisted separately from the number of actual rematches,
  so the first real repeat battle is still identified correctly even if its
  team has already grown several times.

### Changed

- Finishing the visible recovery period no longer freezes a trainer's strength.
  The trainer stays continuously battle-ready while subsequent randomized
  128-256-step training cycles run.
- Passive and battle-earned growth share the existing +20 and level-100 caps.
- Older saves start their first silent cycle when loaded or next inspected;
  they are not granted speculative levels for time that was never tracked.

## [1.0.5] - 2026-08-02

### Added

- Character-specific Master and Crown dialogue sets for Brock, Misty,
  Lt. Surge, Erika, Koga, Sabrina, Blaine and Giovanni.
- Each circuit Leader now has a personal challenge, rejection reaction,
  exact-step recovery line, defeat quote and story-progression hint in both
  English and German.
- Separate Apex and Crown scenes for Lorelei, Bruno, Agatha, Lance and the
  Champion, including new pre-battle, in-battle defeat and post-battle text.

### Changed

- Circuit dialogue now reflects the boss's team and personality, including
  Suicune with Misty, Raikou with Lt. Surge, Celebi with Erika, Lugia with
  Sabrina, Entei with Blaine, and Lugia plus Ho-Oh with Lance.
- If one of those legends is disabled in OPTIONS, the affected boss uses an
  alternate line that matches the non-legendary replacement team.
- The ordinary first Elite Four and Champion story clear still uses the
  original game or translation-mod dialogue; new scenes activate only in the
  Apex and Crown circuits.

## [1.0.4] - 2026-08-02

### Added

- Complete English and German variants for all mod-owned trainer challenges,
  rejection reactions, strength warnings, cooldown reports, boss prompts and
  legendary messages.
- Automatic German text detection for `deutsch`, `deutsch-blau` and
  `deutsch-gelb`, with optional dependency ordering so the matching
  translation loads first when installed.
- A **LANGUAGE** option with `AUTO`, `ENGLISH` and `DEUTSCH` overrides.

### Changed

- A resting field trainer now says its normal post-battle line as a second
  page after reporting the exact remaining steps.
- Mod-option labels are German when a matching German translation is detected
  during loading.

## [1.0.3] - 2026-08-02

### Added

- Individual legendary encounter controls in the mod's **OPTIONS** submenu.
  Articuno, Zapdos, Moltres and Mewtwo each offer `APEX`, `VANILLA` and
  `OFF`; every added Johto legend has its own `ON/OFF` toggle.
- `VANILLA` restores the original availability and level for a Kanto static
  legend: level 50 for each bird and level 70 for Mewtwo.
- Disabling a legend removes its encounter and catch requirement. Any copy
  used by a Crown boss is replaced with a suitable non-legendary Pokémon.

### Fixed

- A defeated trainer with no existing mod record now starts a recovery period
  lazily when spoken to instead of skipping directly to an immediate rematch.
- Previously defeated Master Leaders now report their exact remaining steps
  and become repeatable when their recovery period ends.

## [1.0.2] - 2026-08-02

### Added

- Visible Raikou, Entei and Suicune sightings on each beast's current roaming
  route. Talking to the overworld Pokémon starts the same level-85 encounter;
  the existing random grass encounter remains available too.

### Changed

- Overworld appearances now reuse the game's standard sprite sheets:
  `SPRITE_MONSTER` for the three beasts, `SPRITE_BIRD` for Lugia and Ho-Oh,
  and `SPRITE_FAIRY` for Celebi.

## [1.0.1] - 2026-08-02

### Added

- Optional Pokémon Crystal front/back battle sprites for all six added
  species, installed locally from Pokémon Database with
  `tools/install_crystal_sprites.py`.
- A **LEGEND ART** option for switching between local Crystal art and the
  original distributable four-shade sprites.
- Automatic fallback to the original sprites when the local Crystal pack is
  incomplete or absent.

### Changed

- Crystal art is now the preferred local style. Copyrighted game sprites are
  excluded from source and release ZIPs; the installer downloads them only for
  the user's personal installation.

## [1.0.0] - 2026-08-02

### Added

- A five-stage Hall-of-Fame progression: eight Master Gym Leaders, the Apex
  Elite Four and Champion, a gated legendary hunt, eight level-100 Crown Gym
  battles, and a final level-100 Crown Elite Four.
- Six-Pokémon fixed-move boss rosters for every Master, Apex and Crown battle.
- Legendary progression gates: all legendary battles stay sealed until the
  Apex Champion; the birds unlock Lugia, the roaming beasts unlock Ho-Oh, and
  Lugia plus Ho-Oh unlock the Crown Circuit.
- Level-80 Articuno/Zapdos/Moltres, level-90 Mewtwo, roaming level-85 Raikou,
  Entei and Suicune, level-95 Lugia/Ho-Oh, and a secret level-90 Celebi.
- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi as full custom species,
  including stats, learnsets, Pokédex data, cries, front/back sprites and
  party icons.
- Aeroblast and Sacred Fire.
- Original, reproducible four-shade pixel assets and an asset generation tool.
- Recovery for old vanilla static legends hidden by a KO or flee when they
  have not actually been caught.
- 302-check headless coverage for field rematches, progression gates and every
  boss roster.

### Changed

- Scripted Gym Leaders now enter the post-game rematch flow after the first
  Hall of Fame; Giovanni returns to Viridian Gym.
- All Master, Apex and Crown battles are marked as rematches and pay no money.
- Static legendary encounters disappear permanently only after capture.

## [0.4.0] - 2026-08-02

### Added

- Per-trainer recovery periods: the first rematch and every later rematch
  require a random 128-256 completed player steps by default.
- Resting trainers report the exact number of steps still required.
- Progressive rematch teams: +2 levels on the first rematch, another +2
  after each completed rematch, capped at +20 and Pokémon level 100.
- Persistent, per-save trainer rest and growth state in
  `save.modData.trainer_rematch`.
- Mod-manager options for the minimum/maximum rest steps and level gain.

### Changed

- The strength-gap warning now measures the actually boosted rematch team.

## [0.3.0] - 2026-08-01

### Added

- Strength warning: when the rematch team averages more than 10 levels
  above the player's party, the trainer warns in its own voice ("My team
  is far stronger than yours...") and asks a second time before the battle
  starts.  Declining walks away with the class's usual decline line.

## [0.2.0] - 2026-08-01

### Added

- A trainer record may mark a dedicated rematch team via `rematchIndex`
  (Yellow Legacy Changes 1.6.0+ ships the hack's gym-leader, Elite Four
  and Champion rematch teams this way); the rematch battle then uses that
  team instead of the trainer's own.  Without a marker, behavior is
  unchanged.

## [0.1.0] - 2026-08-01

### Added

- Rematch prompt when talking to a defeated field trainer (YES/NO).
- Per-trainer-class rematch dialogue in the class's own voice.
- Per-trainer-class decline reaction: mocking for cocky classes, understanding for wise ones.
- No money rewards for rematch battles (trainer prize and Pay Day suppressed).
- The trainer's vanilla post-battle dialogue follows the decline reaction.
