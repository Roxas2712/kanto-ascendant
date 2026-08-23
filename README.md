# Kanto Ascendant

Kanto Ascendant turns Kanto into a persistent training world and adds a full
Hall-of-Fame post-game: ranked field trainers, personal Leader missions,
adaptive circuits, the Ascendant Battle Frontier, Rocket Resurgence, a living legendary
event, five historical Heritage Cups, the complete 100-species Johto Pokédex,
Mew, a full Route 5 breeding Day-Care, Generation-II shinies, official Mega
Evolutions, Yellow's optional partner evolution, the Silver/Kris/Gold Johto
Masters trial, optional early Johto migration and Mew/Celebi Signals, a
Battle Factory, repeatable S.S. Anne voyages and a spoiler-safe Research Atlas.
From 6.5.0 RC10 onward the internal
ID is `kanto_ascendant`. The first boot copies legacy Kanto Ascendant options
and save data from the former `trainer_rematch` namespace and keeps a rollback
shadow for RC9.

> [!IMPORTANT]
> RC9 and older Kanto Ascendant builds used the same internal ID as the
> standalone Trainer Rematch mod. Before enabling RC10, disable or move the
> old Kanto Ascendant installation out of the launcher's `mods` directory.
> RC10 declares a conflict with the standalone `trainer_rematch` ID so the two
> implementations cannot run over the same trainer hooks.

> [!IMPORTANT]
> **Engine 0.1.90:** this release requires Gen 1 Recomp 0.1.90 or newer; its
> release acceptance is performed against 0.1.90. Before
> enabling Kanto Ascendant, disable standalone packages whose systems it
> already includes, and disable **Kanto Reforged**. The 0.1.90 manager
> blocks Ascendant while one of those conflicts remains enabled; it does not
> silently modify or disable the other package. Reforged remains usable on its
> own. It also blocks renderer archives that currently do not work with 0.1.90
> and points to one official supported-series Voxel renderer or native 2D
> instead. No
> compatibility or defect claim about Reforged is implied.

> [!IMPORTANT]
> **Vanilla Kanto boundary:** every save starts with original Generation-I
> species and move data. After the Hall of Fame, Elm's/Lind's aide in
> Oak's/Eich's Lab can irreversibly open **BEYOND KANTO / JENSEITS VON KANTO**
> for that save after two default-NO confirmations. Until then Johto waves,
> Masters, extended rewards/evolutions and non-Kanto Legacy Bank withdrawals
> stay sealed. The Hoenn/HEVO caves themselves remain playable with the same
> maps and puzzles and deterministic #001-151 encounter substitutes. Every
> other slot and newly created save begins sealed independently.

Looking for a specific mechanic, item or location? Open the
**[complete FAQ and spoiler guide](FAQ.md)**. Every detailed answer is
collapsed so players can reveal only the information they want.

> [!IMPORTANT]
> **Development Preview:** Kanto Ascendant is in active development. More
> features, dialogue and polish will follow. Bug reports, balancing feedback
> and feature wishes are welcome in
> [GitHub Issues](https://github.com/Roxas2712/kanto-ascendant/issues) and will
> be considered for future updates.

## What's new in 6.5.15

- Cancels a Wandertrainer's queued farewell movement when a defeat blackouts
  to another map, preventing that orphaned movement from blocking field input.
- Keeps the 6.5.14 controller unlock while preserving normal blackout,
  healing, protected Wandertrainer money and next-encounter cadence.

See the full spoiler-light [6.5.15 release notes](RELEASE_NOTES_6.5.15.md).

## What's new in 6.5.14

- Prevents a Legacy Wandertrainer defeat from carrying its encounter input
  lock through the native blackout into a Pokémon Center.
- Retires the stale field encounter while preserving the normal blackout,
  party healing, protected Wandertrainer money and next-encounter cadence.

See the historical [6.5.14 release notes](RELEASE_NOTES_6.5.14.md).

## What's new in 6.5.13

- Gives Legacy Wandertrainers twelve contextual bilingual greetings while
  reserving legendary-accomplishment lines for the current playthrough's Hall
  of Fame.
- Names both Pokémon in active-partner challenges and distinguishes current
  Legacy-path accomplishments from achievements inherited from another life.
- Adds six farewells for each battle result and lets the Wandertrainer walk
  safely out of view before disappearing.
- Keeps Yellow's Jessie/James/Meowth story battles on their approved combined
  staged art, with exact byte verification and a native Yellow fallback.

See the historical [6.5.13 release notes](RELEASE_NOTES_6.5.13.md).

## What's new in 6.5.12

- Adds a dedicated, active-Legacy-only `GAMEPLAY → LEGACY NG+` options page
  and makes the less intrusive `RARE` Wanderer cadence the new default.
- Makes `FIELD CHARACTERS` and `TRAINER PORTRAITS` work for exact pre-6.5
  Red/Blue saves that have no character record, without rewriting story or
  identity data.
- Keeps Red and Green's selected voice through both Route 22 post-battle
  phases and revises their complete bilingual main-story dialogue for natural,
  scene-correct English and German while Blue retains native edition text.

See the historical [6.5.12 release notes](RELEASE_NOTES_6.5.12.md).

## What's new in 6.5.11

- Keeps every dynamically generated host on reachable public floor tiles;
  Celadon's Game Corner entrance and Indigo Plateau access lanes stay clear.
- Restores the Poké Flute in the normal battle Bag while preserving Link and
  explicit no-item restrictions, and queues full-Bag Ascendant rewards safely.
- Prevents visible Wilds from blocking multi-cell map connections and seals
  extended Rematch Mastery moves until their save-bound authority is earned.
- Keeps field-rematch rosters stable across visual-option changes and reloads,
  and makes Legacy Wanderer parties, moves, Rest AI and dialogue stage-safe.
- Repairs release-list navigation, regional Box filters and durable Hoenn
  starter catalogue unlocks.
- Prevents wrong-edition German packs or stale language values from mixing
  locales, localizes both remaining raw QoL labels and fixes Crown Archive
  research counts when optional assignments are disabled.
- Fixes minimum-engine character art probing, VASC trainer-back orientation,
  Crystal cache reuse, Gorochu catalogue composition and Red's walk cycle;
  Blue and Green also retain their identity when mounting the Bicycle.
- Lets selected friendship-evolution followers gain progress from genuine
  walking steps without advancing reserves or synthetic clocks.
- Selects one Apricorn preview authority and aligns Johto Masters dialogue,
  evolution rules and reward handoff with the implemented 6.5 systems.

See the full spoiler-light [6.5.11 release notes](RELEASE_NOTES_6.5.11.md).

## What's new in 6.5.10

- Corrects Red/Green's Yellow rival progression so the S.S. Anne Wartortle
  remains Wartortle in Pokémon Tower and later becomes Blastoise, while every
  Eevee-outcome variant advances to the intended story tier.
- Restores the Pokémon Tower room music immediately after winning the rival
  battle on affected engine builds.
- Adds Leaf Blade/Laubklinge to Leafeon's level-71 learnset. It uses physical
  Attack only for Leafeon and stays a classic special Grass move globally.
- Repairs clipped Yellow partner-Raichu portraits and adds a Yellow-only
  RAICHU FACES option for corrected Ascendant or classic Yellow-style faces.

See the full spoiler-light [6.5.10 release notes](RELEASE_NOTES_6.5.10.md).

## What's new in 6.5.9

- Restores renewable Koffing and Weezing acquisition in Yellow when KANTO 151
  is set to REWARDS or WILD, using only two former Raticate slots in Pokémon
  Mansion B1F.
- Replaces the Red-only reachability snapshot with a real Red/Blue/Yellow
  matrix covering actual wild encounters, fishing, gifts, trades, events,
  research eggs, evolution and configurable legendary paths.
- Verifies all six edition/mode combinations at 251/251 while keeping KANTO
  151 OFF and disabled legendary options as explicit configuration boundaries.

See the full spoiler-light [6.5.9 release notes](RELEASE_NOTES_6.5.9.md).

## What's new in 6.5.8

- Fixes a Gen1Recomp 0.2.14 compatibility regression that could return to
  Oak's first player-name prompt and stall after player/rival selection when
  starting a new game.
- Releases the engine-owned held intro prompt before Ascendant opens its
  custom NamingScreen. Older engines—and a future engine that removes this
  held-prompt lifecycle again—continue through the previous path unchanged.
- Covers Red, Blue and Yellow as well as the Legacy/New Game Plus hand-off.

See the full spoiler-light [6.5.8 release notes](RELEASE_NOTES_6.5.8.md).

## What's new in 6.5.7

- Replaces the low-resolution Trainer Card with the approved 640×400 HD
  standard card. It keeps the KANTO ASCENDANT brand, selected identity, active
  title, money, play time and all eight Kanto Leader/badge slots on one screen.
  Giovanni stays a black silhouette until a genuine Giovanni victory flag is
  present; merely owning an Earth Badge cannot reveal him.
- Restores Yellow's native partner-emotion window by marking the exact
  level-5 Pikachu that Oak gives through the original three-argument Lab
  command. Other Pikachu remain ordinary, while the partner identity survives
  storage, fainting and later evolution into Raichu or Gorochu.
- Corrects Yellow's German Oak's Lab exchange to use grammatical, deliberately
  paginated text without changing the adjacent English dialogue.
- Adds a default-off **BOX ICONS → HGSS WALKERS** choice for the right-hand
  5×4 storage grid. It reuses the already bundled Wilds walking sheets, keeps
  the large left preview unchanged and falls back to the current icon for
  missing species or unsupported forms. No new third-party art is added.

This hotfix contains one fixed standard Trainer Card. Unlockable card designs,
title expansion and pre-battle card overlays remain outside 6.5.7.

See the full spoiler-light [6.5.7 release notes](RELEASE_NOTES_6.5.7.md).

## What's new in 6.5.6

- Restores the complete Red and Green Oak's Lab dialogue contract in English
  and German. Blue alone keeps the native grandson dialogue.
- Uses the existing approved Professor Oak standee for Yellow's catching
  tutorial in supported staged renderers. Because no approved old-man 3D art
  exists, Red/Blue delegate only that tutorial to the native 2D battle.
- Uses the newly supplied Red, Green and Blue Crystal walking sheets. Their
  immediately preceding sheets remain the first validated fallbacks, with all
  older per-character fallback generations retained behind them.
- Adds separate Crystal-palette Shiny follower sheets for all Kanto species
  #001-151. The normal sheet remains the safe fallback. In Yellow, selected
  extras keep following while the authored partner is fainted or stored; the
  partner safely returns to follower one when available again.
- Keeps the ordinary Pokédex at #151 before Driftglass and #251 after the
  National Dex upgrade, while active authored Johto habitats become visible
  on the AREA page without exposing inactive locations.
- Adds an independent Wild Level Scaling option that defaults to off; trainer
  difficulty is unaffected.
- Adds Adaptive Trainer Levels as a separate Core Rule. AUTO stays classic on
  Standard and targets the rounded active-party average +1/+2/+3/+4 on the
  four higher Difficulty settings; manual gaps and exact classic OFF remain
  available. Existing saves keep classic behavior until the setting is
  deliberately revisited. See the [bilingual contract](docs/adaptive-trainer-levels.md).
- Makes the selected Difficulty shape the first canonical story Gym battles:
  Standard keeps the exact edition team and moves, including Yellow's special
  move tables; higher tiers progressively add legal moves, themed teammates,
  AI and limited healing without changing postgame, Master, Apex or Crown
  fights. See the [story Gym contract](docs/STORY_GYM_DIFFICULTY_6_5_6.md).
- Adds named Rematch Break profiles. Fresh saves use NORMAL 605-1255; existing
  custom ranges keep their values, and already scheduled field, silent-training
  and postgame Gym timers never reroll when the profile changes.
- Makes the classic Adaptive-OFF rematch warning include the same fixed
  Difficulty level adjustment as the battle it previews.
- Prevents actually upscaled ordinary trainer Pokémon from losing their last
  legal damaging move while learning several status moves. Unscaled authored
  parties and curated story movesets remain untouched.
- Restores Giga Drain's half-damage healing and excludes the one-time Thunder
  Tear from ordinary rematch loot. The current reward odds, weighted pool and
  OFF behavior are audited in the rematch sections below and in the FAQ.
- Moves only Ascendant-owned enemy Crystal fronts slightly up and left in
  native 2D battles so large animated, Shiny and Mega frames no longer cover
  the player's Pokémon name. Other sprite styles and staged renderers keep
  their own placement.
- Uses both visible dialogue rows before requiring another button press while
  preserving authored pauses and safe English/German pagination.
- Gives Yellow's Mt. Moon fossil Super Nerd his own challenge, victory and
  post-battle dialogue instead of the unrelated generic Shorts text.

See the full spoiler-light [6.5.6 release notes](RELEASE_NOTES_6.5.6.md).

## What's new in 6.5.5

- Uses the new authored Red, Green and Blue Crystal walking sheets while
  retaining the previous sheets as validated fallbacks.
- Prevents Wilds of Kanto from blocking Oak's starter choice, doors, warps,
  NPCs, items, scripted positions and other critical paths, including repair
  of unsafe saved spawns.
- Restores distinct Red, Blue and Green rival voices across the main story and
  postgame in English and German.
- Makes SELECT context-aware: tap a favourite Field Kit tool, hold for the full
  kit, or use classic mark-and-place sorting while the Bag is open.
- Keeps Trainer Card pixel art crisp and refreshes Battle Art Mega animation
  frames without taking ownership of the renderer's stage, camera or HUD.
- Reports Unique Menu Icons, Dynamic Cries, All Pokémon Catchable and Modern
  Party UI as explicit conflicts instead of allowing overlapping registries or
  menu hooks to fail late. Existing Kanto Reforged and Trainer Rematch guards
  remain active.

See the full spoiler-light [6.5.5 release notes](RELEASE_NOTES_6.5.5.md).

## What's new in 6.5.4

- Repairs Johto Signals and affected save-local wild distributions without asking
  affected 6.5.3 saves to restart.
- Makes archive storage safer and reachable from every eligible player PC,
  including atomic quantity withdrawals.
- Fixes Pokédex `AREA`, Fighting Dojo prize selection, an optional cave exit,
  rematch evolution/AI edge cases and overly steep early difficulty scaling.
- Restores Yellow follower/partner presentation and keeps Red, Blue and Green
  trainer identity consistent in normal battles, tutorials and Trainer Cards.
  The complete party can now be shown as up to six followers.
- Admits official Voxel Ascendant, Battle Art, Dramaless and PotatoVoxel builds
  from their current baselines through 2.x on a best-effort basis. Exact
  adapters stay pinned, and only one renderer may run at a time.

See the full spoiler-light [6.5.4 release notes](RELEASE_NOTES_6.5.4.md).

## What's new in 6.5.3

- Three character-specific Hidden Evolution trials expand the postgame while
  keeping their final discoveries out of this overview.
- Quiz statues are visually distinct from optional floor lights, draw from a
  much larger knowledge catalogue and use a readable timed exam screen.
- Oak's Lab now has one direct KASC Terminal for long-run continuity and
  configurable ASC RUN rules.
- Dialogue pagination, save/retry recovery, surprise-trainer losses, the
  Lt. Surge/Major Bob reward path and Oak's hosted presentation received
  extensive fixes.
- Exact routes and solutions are available only through clearly marked
  spoiler sections in the [FAQ](FAQ.md) and the optional
  [offline map guide](docs/guides/hidden-evolution/README.md).

See the historical spoiler-light [6.5.3 release notes](RELEASE_NOTES_6.5.3.md).

## What's new in 6.0.5

- Ordinary Johto replacements now use the rounded, Gen-I-weighted average of
  the active route plus a random 2-5 levels. The same balancing applies to
  classic 2D encounters, Wilds of Kanto and researched Johto habitats; primal
  and other authored story encounters retain their designed levels.
- The FAQ now lists researched habitats without obsolete fixed encounter
  levels and explains the new route-based scaling.

## What's new in 6.0.4

- Driftglass now hides an optional **Prism Grotto** with five short reusable
  symbol-sequence riddles for guaranteed Johto evolution items and a separate
  Twilight rite for Eevee's day/night evolutions.
- The central crystal tablet offers optional **Johto Move Resonance** for 104
  original Kanto species. It grants only compatible Gen-II moves already
  implemented by Ascendant, preserves Crystal's original level gates and
  works with the existing Route 5 Move Deleter and Move Reminder.
- Johto #152-251 now consistently use their bundled species-authentic Crystal
  fronts, backs and legacy cries. Johto onboarding choices are saved
  immediately and no longer reappear after restarting or while an existing
  repaired save is still loading.
- **DEX SPRITES → CRYSTAL** now applies to both Pokédex entries and the static
  portrait under **Pokémon → STATS**, while battle artwork remains controlled
  separately.
- Guaranteed and bonus-roll shinies are prepared before Crystal, Voxel or
  other battle-art wrappers select a sprite, preventing events such as the Red
  Gyarados from appearing in normal colours.

## What's new in 6.0.3

- The ordinary Pokédex now stays Kanto-only until Driftglass research
  upgrades it into the **National Dex**. Seen Johto Pokémon reveal their
  identity; complete species data still requires catching them.
- Existing 6.0.0-6.0.2 saves whose Migration Receiver was already active
  receive the National Dex automatically. A quest that was only started keeps
  its progress and receives the upgrade from the Driftglass researcher.
- Added optional Wilds of Kanto 1.7.1 integration for visible Johto
  encounters, plus a clear in-game link status and refreshed normal/Shiny
  Johto walkers without replacing the existing Kanto follower provider.

## What's new in 6.0.2

- Professor Oak and Professor Eich now use the trainer's actual saved name in
  both Johto Signals calls. The literal `[PLAYER]` placeholder can no longer
  appear in English or German.
- The fix is save-compatible with Red, Blue and Yellow and does not reset any
  Johto Signals, Mythic Signals or existing game progress.

## What's new in 6.0.1

- Professor Oak now starts the optional Johto Signals field quest after
  **1–200 eligible post-Pokédex steps** and points the player toward Pallet
  Town's southern coast.
- A real dark-capsule object persists on the coast until it is taken. Oak
  gives only one reminder after 400 more eligible steps.
- The capsule can be opened immediately or later from the Johto Signals menu.
  Its coordinates lead through the Pallet boatman to Driftglass.
- The complete opening dialogue, Journal guidance and German text layout were
  rewritten. Existing 6.0 saves retain their progress.

## What's new in 6.0.0

- **Johto Signals** can optionally bring habitat-aware Johto encounters into
  the Kanto story. The original Kanto-first flow remains available at all
  times.
- A hidden Pallet signal opens the reversible Driftglass research trip,
  Migration Receiver and three player-controlled encounter currents.
- Four concealed primal traces separately unlock Chikorita, Totodile,
  Cyndaquil and Larvitar with protected rare-encounter counters.
- Independent **Mythic Signals** introduce dangerous Mew and Celebi echoes,
  the Resonance Seal and persistent true-manifestation hunts.
- Journal, Research Atlas and the shared **WORLD** menu guide every optional
  objective in English and German without revealing unseen species.
- Existing Red, Blue and Yellow saves upgrade in place. The complete 5.4.2
  support hotfix, FAQ and progression repairs are included.

## What's new in 5.4.2

- Missing Master or Crown Leader victories are now committed through a second
  victory-only path, and affected saves repair their circuit progress safely.
- Event Archive entries explain that `READY` means unlocked and point to the
  relevant Cup city or roaming habitat.
- Lt. Surge/Major Bob repairs a missing permanent Thunderheart before entering
  his postgame rematch dialogue. Once the item exists, Master and Crown
  challenges remain reachable even with Gorochu in the party.
- The public FAQ now consolidates installation, mechanics, locations and
  current support status behind individually protected spoiler sections.

## What's new in 5.4.1

- Authored Ascendant boss battles now hand their intended temporary roster to
  the Gen-I Randomizer. Randomized species and moves remain authoritative,
  while Ascendant safely reapplies the authored team size, levels, rules, AI,
  rewards and progression.
- Repeatable field trainers can recruit suitable Johto families after Elm's
  research exposes them. Each trainer's choices are deterministic and never
  reroll when later families become available.
- **DEX SPRITES** independently switches Kanto #001-151 between the active
  Red/Blue/Yellow Pokédex fronts and bundled static Crystal frame-one art,
  without changing any battle, animation or follower setting.
- Gorochu's optional discovery is now a clear item journey: obtain the
  permanent Thunderheart from Lt. Surge, find its remote Power Plant
  condenser, create one consumable Thunder Tear and use it on the Raichu you
  choose.
- Gorochu now has dedicated sharp 96×96 normal/shiny Voxel fronts and backs,
  an independent six-pose follower sheet, and complete Raichu/Gorochu
  conversation portraits. Yellow uses its spoken Gorochu cry; Red and Blue
  use an edition-fitting Gen-I chip cry. External Gorochu audio remains first
  priority.

The engine's normal trainer prize money and Pay Day paths remain intact.
Ascendant's rematch controller adds a separate item-or-money bonus after a
win; it does not replace those native payouts. Legacy Wanderer losses are the
separate exception documented below: their pre-battle money is restored.

## Field trainer rematches

1. Beat a trainer.
2. On a fresh save they rest and train for the **NORMAL 605-1255 completed
   player-step** profile.
3. Talk to them too early to see the exact number of steps remaining, followed
   by their normal post-battle dialogue as a second page.
4. Return when they are ready for a class-specific YES/NO challenge.
5. When first ready, their next rematch is +2 levels stronger. Each completed
   rematch adds another +2 until each Pokémon reaches level 100.
6. A ready trainer keeps training even when ignored. Another invisible cycle
   from the same selected profile begins in the background; every completed
   silent cycle adds the same +2 growth tier to the next battle while the
   trainer remains continuously available.
7. At the default growth rate, reaching +4, +8, +12 and later strength tiers
   recruits another class-appropriate Pokémon until the party reaches six.
   The chosen evolutionary families stay deterministic for that trainer and
   evolve naturally when its projected rematch level is high enough. Before
   Elm's research exposes a Johto family, recruitment remains Kanto-only;
   afterward suitable classes can add that family without rerolling recruits
   they already trained.

The shared break profile controls ordinary visible field rematches, their
silent-training intervals and post-game Gym recovery:

| Profile | Future interval |
|---|---:|
| VERY SHORT | 151-302 |
| SHORT | 303-604 |
| NORMAL | 605-1255 |
| LONG | 1256-1882 |
| VERY LONG | 1883-2510 |
| CUSTOM | Saved minimum and maximum, editable from 151 through 2510 |

Fresh saves start on NORMAL. During migration, only an exact named pair maps
to that preset. The existing 151-2510 pair, the historical 128-256 pair and
every other hand-tuned pair become CUSTOM without changing either number.
Switching away from CUSTOM preserves both values. A profile change affects
only intervals rolled later:
every already scheduled `readyAt`, `nextTrainingAt` and post-game `bossRest`
timestamp remains unchanged. Legacy Wanderers use their independent frequency
system and never consume this range.

Every field trainer now has a persistent rank based on completed rematches and
silent training:

| Rank | Growth tiers | Additional effect |
|---|---:|---|
| Rookie | 0 | Normal class-specific rematch |
| Veteran | 2 | Persistent rank banner |
| Expert | 5 | Stronger battle AI |
| Master | 10 | Full battle AI and overworld marker |
| Legend | 20 | Full battle AI and enhanced marker |

Master and Legend trainers display a small sparkle above their overworld
sprite. Rank itself does not alter loot. A fully level-100 enemy team and its
separate mastery-win counter can improve the ordinary item roll as documented
below.

All 47 trainer classes have their own opening and rejection dialogue. Cocky
classes mock a refusal; wise and polite classes understand. If a rematch team
averages more than 10 levels above the player's party, its trainer gives a
second strength warning before battle.

All 47 classes also have distinct recruitment pools: Bug Catchers seek more
bugs, Fishers add fishing species, Bird Keepers add flying partners, Psychics
add Psychic families, Rockets favor their familiar urban poison species, and
so on. Existing team types are preferred within the class theme, duplicate
species are avoided where possible, and normal trainers never recruit
legendary Pokémon. **TEAM GROWTH** can disable party expansion without
disabling the level or step systems.

The Gen-I Randomizer remains authoritative for ordinary rematch species and
moves. Ascendant then appends only earned recruit slots and finally applies
the persistent rematch/background-training levels, clamped at level 100.

### Field-rematch rewards (authoritative 6.5.6 audit)

The reward controller resolves a win in three independent layers. EXP helpers
are checked first, then a post-Hall-of-Fame Master Ball check, then the ordinary
item-or-extra-money layer. The EXP checks can therefore stack with each other
and with the main result on the same victory.

| One-time helper still missing | Check on each eligible win |
|---|---:|
| EXP Share / EXP.ALL | 225/10000 = **2.25%** |
| EXP Multiplier x2 | **1/300** |
| Next x3 stage, after x2 | **1/250** |
| Next x5 stage, after x3 | **1/250** |

OFF disables only the Master Ball check and the ordinary
item/extra-money layer. It does **not** disable the native trainer prize or Pay
Day, EXP-helper catchups, the first Field Kit, renewable-TM progress, Johto
research rewards or shiny-streak progress.

With BALANCED or GENEROUS selected, a registered Master Ball receives a
separate **1/50 (2%)** check after the Hall of Fame. A hit awards the Ball and
suppresses the ordinary item/money roll for that transaction. There is no
enemy-average-level or Apex requirement.

After a Master miss, or before the Hall of Fame, the ordinary item chance is:

| Enemy team | BALANCED / GENEROUS |
|---|---:|
| Not entirely level 100 | **65% / 80%** |
| Entire team level 100, 0 mastery wins | **72% / 87%** |
| Entire team level 100, 12+ mastery wins | **75% / 90%** |

At level 100 each mastery win adds 0.25 percentage point, capped at +3 points.
If the item roll misses, the extra-money table is rolled. These percentages
are conditional on reaching that table:

| Enemy team | Amounts and conditional weights |
|---|---|
| Below the all-100 condition | ¥0 / ¥100 / ¥250 / ¥500 / ¥750 / ¥1000 / ¥1250 / ¥1500 / ¥1750 / ¥2000 = 5 / 20 / 20 / 20 / 12 / 10 / 6 / 4 / 2 / 1% |
| Entire team level 100 | ¥1000 / ¥1500 / ¥2000 / ¥2500 / ¥3000 / ¥4000 / ¥5000 / ¥6000 / ¥7000 / ¥8000 = 25 / 20 / 18 / 12 / 10 / 6 / 4 / 2.5 / 1.5 / 1% |

Useful combined examples, including the post-Hall-of-Fame Master check:

| State | Master | Ordinary item | Positive extra money | Nothing extra |
|---|---:|---:|---:|---:|
| Below 100, BALANCED | 2% | 63.7% | 32.585% | 1.715% |
| Below 100, GENEROUS | 2% | 78.4% | 18.62% | 0.98% |
| All 100, 0 mastery, BALANCED | 2% | 70.56% | 27.44% | 0% |
| All 100, 0 mastery, GENEROUS | 2% | 85.26% | 12.74% | 0% |
| All 100, 12+ mastery, BALANCED | 2% | 73.5% | 24.5% | 0% |
| All 100, 12+ mastery, GENEROUS | 2% | 88.2% | 9.8% | 0% |

Before the Hall of Fame, the below-100 totals are 65% item, 33.25% positive
money and 1.75% nothing in BALANCED, or 80%, 19% and 1% in GENEROUS.

The current ordinary item pool uses weighted stacks, not the obsolete fixed
Nugget bands. Its complete base pool is 120.5 weight before level-100 and
mastery premium modifiers:

| Group | Results (base weights) |
|---|---|
| Balls | Poké Ball x3/x5/x10 (8/5/1), Great Ball x2/x3/x5 (7/4/1), Ultra Ball x1/x2/x3 (5/3/1) |
| Healing | Potion x2 (6), Super Potion x2 (6), Hyper Potion (5), Max Potion (2), Full Heal x2 (5), Revive (4), Max Revive (1) |
| PP recovery | Ether (5), Max Ether (2), Elixir (3), Max Elixir (1) |
| Training | PP Up, Rare Candy, HP Up, Protein, Iron, Calcium and Carbos (2 each) |
| Evolution | Fire, Water, Thunder, Leaf and Moon Stones (2 each); Sun Stone, King's Rock, Metal Coat, Dragon Scale and Upgrade (1.5 each) |
| Apricorn Balls | Fast, Friend, Heavy, Level, Love, Lure and Moon Balls (2 each) |

Ultra Ball stacks, Max Potion/Revive/Ether, Elixirs and the Training group are
premium. An all-level-100 team multiplies their effective weight by 1.6;
mastery multiplies it by up to another 1.25. Master Ball, Safari Ball and HEVO
progression relics never enter this ordinary pool. The one-time Thunder Tear
is progression-locked and excluded too.

No earned item is destroyed by capacity. A rematch Master Ball uses
`Bag -> PC -> pending`; a field EXP helper or ordinary field item uses Bag
then its corresponding persistent pending record and is delivered when space
becomes available.

## All 151 Kanto Pokémon in one save

Kanto Ascendant now removes every Red/Blue/Yellow exchange and one-time-choice
lock itself. A separate all-catchable mod is no longer needed. The **KANTO
151** option has three modes:

| Mode | Behaviour |
|---|---|
| **REWARDS / BELOHNUNGEN** (default) | Version exclusives live together in fitting habitats. The three other starters and the excluded Mt. Moon fossil remain meaningful Master-Leader prizes. |
| **WILD** | Also places the starters, both fossils, Aerodactyl and the four former trade evolutions in rare late-game encounters. |
| **OFF / AUS** | Disables Kanto Ascendant's catchability, evolution and Moon Stone additions. Existing legendary options and story events remain independent. |

In both active modes:

- Viridian Forest contains both Caterpie and Weedle families.
- Route 5 contains Oddish, Bellsprout, Mankey and Meowth; Route 8 contains
  Ekans, Sandshrew, Growlithe and Vulpix.
- Scyther and Pinsir share the Safari Zone; both Hitmonlee and Hitmonchan can
  be found in Victory Road.
- After the first Hall of Fame, renewable level-25 Eevee occupy 2% of Route
  7 grass encounters. Together with Celadon's gift and Elm's two partners,
  this supports Vaporeon, Jolteon, Flareon, Espeon and Umbreon in one save.
- Electabuzz appears in the Power Plant, Magmar in Pokémon Mansion, and the
  Seafoam Islands include Slowpoke, Staryu and Shellder.
- Kadabra, Graveler and Haunter evolve at level 42; Machoke evolves at level
  45. Trading remains an optional earlier route.
- New Johto branches are appended instead of replacing Gen-I evolution
  choices: Gloom keeps Vileplume, Poliwhirl keeps Poliwrath, Eevee keeps all
  three stone branches and Slowpoke keeps Slowbro.
- Moon Stones cost ¥2100 and are renewable in Pewter Mart and Celadon
  Department Store 4F.

In the default REWARDS mode, Master Erika entrusts the player with Bulbasaur,
Master Misty with Squirtle and Master Blaine with Charmander if that exact
starter has not already been owned. Master Brock examines the Mt. Moon choice
and awards the missing Dome or Helix Fossil. An unusual imported save that
owns neither can earn the second fossil from Crown Brock. Full parties, PC
boxes or Bags reserve the already selected prize instead of deleting or
rerolling it.

The KANTO 151 modes never insert Mew into an ordinary encounter table. Its
Oak/Fuji/Cinnabar heritage investigation remains authoritative; the optional
Mythic Signals path can surface it only after the separate three-echo and
Resonance Seal sequence. The three birds and Mewtwo retain their separate
APEX/VANILLA/OFF controls.

If **All Pokémon Catchable 151 Mod** was previously enabled, it must now be
disabled; Kanto Ascendant preserves compatibility during migration and its
selected KANTO 151 mode takes precedence over overlapping encounter slots.

### Field Kit, renewable TMs and Move Deleter

The first won field-trainer rematch awards the permanent **Field Kit /
Feld-Kit**. Select it in the Bag to use CUT, FLY, SURF, STRENGTH or FLASH
without teaching the move to a Pokémon. It does not skip progression: the
matching original HM and Badge must both be owned. Every HM can still be
taught normally, so this is a choice rather than a replacement.

After the first Hall of Fame, every second won field rematch awards the next
TM from a guaranteed archive cycle. All 50 original TMs appear once before the
cycle starts again. A full Bag reserves the selected TM instead of rerolling
or deleting it.

The visible machine inside the **Route 5 Day-Care** now includes a bilingual
Move Deleter and a TM Archive status page. The Move Deleter can remove HMs as
well as ordinary techniques, but always leaves a Pokémon with at least one
usable move.

Three Crown Leaders award new starter TMs:

| Leader | Reward | Move | Compatible families |
|---|---|---|---|
| Erika | TM51 | Frenzy Plant / Flora-Statue | Bulbasaur and Chikorita lines |
| Blaine | TM52 | Blast Burn / Lohekanonade | Charmander and Cyndaquil lines |
| Misty | TM53 | Hydro Cannon / Aquahaubitze | Squirtle and Totodile lines |

Each has 150 power, 90% accuracy, 5 PP and the Hyper Beam recharge rule. Once
earned from its Crown Leader, the new TM joins later renewable archive cycles.

Kanto Ascendant 5.0 makes this archive fully lossless. A full Bag no longer
pauses its victory counter: every earned TM enters a persistent first-in,
first-out queue, later rewards continue behind it, and the Route 5 machine
reports and delivers the oldest waiting TM first. TM51-53 become permanent
entitlements as soon as their Crown battle is won, even if they cannot enter
the Bag at that moment.

The same machine now includes a **Move Reminder**. It offers only moves that
the individual Pokémon can prove it knows: legal level-up moves for its
current level, moves previously forgotten through the machine, original event
distribution moves and an earned Crown signature move for the matching starter
family. Ordinary TM compatibility never becomes a free tutor shortcut.

After the Crown Champion, the **Frontier Exchange** opens both at Route 5 and
under **ASCENDANT**. Earned research evolution items become renewable:

| Item | Frontier Points |
|---|---:|
| Sun Stone | 6 |
| King's Rock | 8 |
| Metal Coat | 8 |
| Dragon Scale | 10 |
| Up-Grade | 10 |

An individual TM already recorded in the archive can be bought again for
3 Frontier Points. Locked research items stay visibly marked as locked and
unrecorded TMs remain unavailable behind their real progression, while a full
Bag never consumes points.

### Language

Every new trainer, cooldown, boss and legendary message has complete English
and German text. Language follows the active game translation:

- English is the standalone fallback.
- `deutsch`, `deutsch-blau` and `deutsch-gelb` are detected automatically for
  the matching Red, Blue or Yellow game version.
- The normal trainer text appended after a cooldown comes from the base game,
  so it follows the active translation mod too.

## Johto Signals

Version 6.0.3 and later can let Johto begin stirring during the Kanto story
without changing the normal opening by default. After the starter and Pokédex,
Professor Oak calls within 1–200 eligible steps. That call places a real dark
capsule on Pallet Town's southern coast. If it remains untouched, Oak gives
one reminder after another 400 eligible steps and never calls a third time.

The capsule remains visible when declined. Once taken, it can be opened
immediately or later under **ASCENDANT → WORLD → JOHTO SIGNALS**. Inside are
foreign pollen, starry sand, a damaged receiver and etched coordinates. The
Pallet boatman identifies the coordinates and offers the warned trip to the
**Driftglass signal station**. The boat back to Pallet is available at every
stage. Driftglass' researcher repairs the Migration Receiver, upgrades the
ordinary Kanto Pokédex into the **National Dex**, and explains three currents.
Before that upgrade, the Pokédex ends at #151 even though Johto species are
already registered internally. Saving during a live Driftglass visit does not
interrupt that visit; continuing the written slot later resumes safely at the
Pallet landing.

The National Dex preserves discovery-first behavior: an unseen species stays
hidden, a real sighting reveals its name and sprite, and height, weight and
description remain unknown until the species is actually caught. Existing
6.0.0-6.0.2 saves whose Johto receiver was already active receive the upgrade
automatically. If the old quest had only begun, its exact progress is retained
and the National Dex is still awarded by the Driftglass researcher.

| Current | Early encounter behavior |
|---|---|
| **Kanto First** | No early Johto replacement |
| **Wanderwaves** | 2% in matching badge-aware habitats; 4% during a strong signal |
| **Johto Unleashed** | 10% across matching Kanto habitats |

The chosen current can be changed later under
**ASCENDANT → WORLD → JOHTO SIGNALS**. **EARLY JOHTO** is visibly locked until
the physical receiver has been repaired at Driftglass; only then can that hub
turn the migration encounters on or off. If **MYTHIC SIGNALS** remains on, the
shared capsule, receiver, Driftglass trip and researcher remain available and
the safe **Kanto First** current is enforced. The generic mod-options screen
cannot bypass the field quest or select an active current.

After the receiver is repaired, a glass seam at Driftglass opens the optional
**Prism Grotto**. Its six native cave pillars form five short sequence riddles
for one guaranteed Sun Stone, King's Rock, Metal Coat, Dragon Scale and
Up-Grade. The Prism Reader keeps every inscription available, repeats hints
after any current choice and holds a formed item safely if the Bag is full.
Each item is awarded only once; solved riddles remain replayable without
duplicating it.

The central crystal tablet behind the Prism Reader has a separate optional
**Johto Move Resonance** function. Select a party member first recorded in
Kanto to see the Generation-II moves that species could legally carry in
Pokémon Crystal and that Ascendant currently implements. TM and inherited
access is available immediately. A genuine level-up move keeps its original
required level; an under-levelled partner is told the exact level at which to
return. The tablet never replaces a move. If all four slots are occupied, it
directs the player to the existing Route 5 Move Deleter, which may also remove
an HM but always leaves at least one move. After returning to the tablet, every
newly awakened move is recorded for the existing Route 5 Move Reminder.

The sixth inscription is the repeatable **Twilight Mirror** rite. With Eevee
in the party, its ten-note sequence raises that Eevee to the existing Johto
friendship threshold. One later level by day produces Espeon; one by night
produces Umbreon. **JOHTO TIME** still controls which period applies. Players
who choose Johto Unleashed receive a stronger early hint toward this grotto,
while Kanto First and Wanderwaves keep it clearly optional.

Four hidden primal traces separately unlock Chikorita, Totodile, Cyndaquil
and Larvitar. Their identities remain `???` until a real sighting. Each trace
species has a separate encounter counter: 1:512 in Wanderwaves and 1:256 in
Johto Unleashed, with the next eligible battle guaranteed at the limit.
Switching currents preserves progress. Repel, scripted encounters, roamers,
outbreaks and other authored replacements cannot spend the guarantee.

Independently, optional **Mythic Signals** can answer in genuine Kanto grass
as soon as the Pokédex is active, even before the receiver is repaired. They
are enabled by default and can be disabled separately. The first Mew or Celebi
echo is guaranteed by roll 512 and later echoes by roll 2048. Echoes scale
from level 60 toward the player's party, remain at 1 HP, cannot be escaped
or caught, and reject a Master Ball without consuming it. The warning ends
only when the player's party falls. After exactly
three echoes, four Badges and a repaired receiver, only the Driftglass
researcher can create the Resonance Seal.

True manifestations then use a protected 1:8192 counter. A failed catch binds
that same Pokémon as a persistent retry with its DVs, HP and status preserved.
Already-owned or disabled species are excluded, so the signal path never
duplicates an existing Mew or Celebi conclusion.

Journal and Research Atlas pages show the next signal step as a clearly
optional objective without replacing Gold or another mandatory goal.
Locations are localized in English and German, and neither the Atlas nor the
receiver pre-fills unseen Pokédex entries. Wilds of Kanto visible encounters
and ordinary grass battles use the same selection and pity transaction.

## Complete Johto research

The first Hall of Fame opens Professor Elm's Kanto research programme. His aide
appears inside **Oak's Lab** and directs the player to three independent
starter trials:

| Trial | Location | Prize | Format |
|---|---|---|---|
| Verdant Trial | Celadon City | Chikorita / Endivie | Three Grass examiners |
| Ember Trial | Cinnabar Island | Cyndaquil / Feurigel | Three Fire examiners |
| Torrent Trial | Cerulean City | Totodile / Karnimani | Three Water examiners |

Each trial has three increasingly strong opponents, heals the party between
rounds and awards its level-5 starter once. All three starters can be obtained
in one save; there is no permanent starter choice.

Completing all three activates Johto specimens in ordinary field-trainer
rematches. Every won rematch awards one still-missing evolutionary family,
without random duplicates. Trainer classes search matching habitats: Bug
Catchers find bugs, Bird Keepers find flying species, Fishers and Swimmers find
water species, Hikers find rock and ground species, Psychics and Channelers
find unusual mind or ghost species, Scientists find technical species, and so
on. If one habitat is exhausted, the reward advances into the remaining global
list so no trainer-class shortage can block completion.

The research track contains **40 base families**. Their normal evolutions fill
the rest of the Pokédex. Larvitar is held back as Elm's final specimen and is
awarded on the first further rematch after all 40 tracks are complete.

Research also changes the world permanently. Once its matching specimen,
starter trial or Larvitar finale has been recorded, each of **44 Johto base
species** establishes a thematic Kanto habitat. It replaces 2% of normal
encounters on that map and terrain, allowing further copies, evolutions and
shiny hunts without replacing Elm's guaranteed discovery path. Several
families can share one location, but their combined replacement chance remains
2%. Merely registering these habitats never marks a Pokémon seen or owned.

Eight baby Pokémon arrive as research eggs at fixed specimen milestones:
Pichu, Cleffa/Pii, Igglybuff/Fluffeluff, Togepi, Tyrogue/Rabauz, Smoochum/
Kussilla, Elekid and Magby. They are reserved at the Route 5 Day-Care, become
real party eggs when collected and hatch after their displayed 256-448 actual
player steps. Elm's aide and the Research Atlas show persistent progress; the
aide reports whether an egg is waiting at Route 5 or its exact remaining steps
while carried. A full party never destroys a prize.

Generation-II evolution support includes:

- Additive Dark and Steel types for Johto species and moves. Existing
  Generation-I type, stat, learnset and move records keep their vanilla Kanto
  data by default; only documented evolution branches into new Johto species
  are appended, without replacing original Kanto evolutions.
- Friendship evolutions for Crobat, Togetic and Blissey.
- Day/night friendship branches for Espeon and Umbreon. **JOHTO TIME** follows
  the system clock by default and can force DAY or NIGHT.
- Tyrogue's level-20 Attack/Defense branches for Hitmonlee, Hitmonchan or
  Hitmontop.
- Sun Stone, Metal Coat, King's Rock, Dragon Scale and Up-Grade evolutions.
  These items are earned at fixed research milestones and are used at the
  visible evolution machine inside the Route 5 Day-Care.
- Eleven guaranteed Kanto research partners, including two Eevee, prevent
  version exclusives and one-off gifts from making the full Johto Dex
  impossible.

The Johto and Shiny Pokédexes now follow the original list rules: an unseen
slot shows only its number and `-----`, a seen species reveals its name, and
an owned species receives the Poké Ball marker. Registering the 100 species
with the engine does not reveal them. The extended ordinary Pokédex uses the
same rules across all 251 entries, so every new encounter still uncovers
something.

Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi remain part of the larger
legendary story rather than ordinary rematch prizes. Their species IDs are
unchanged for save compatibility, but their Pokédex numbers are now canonical:
243-245 and 249-251.

## Route 5 Day-Care and breeding

The small house between Cerulean City and the Underground Path is now a
complete two-parent Day-Care:

- Leave up to two Pokémon. Each gains one experience point for every completed
  player step, independently of egg production.
- Taking a parent back costs the original ¥100 plus ¥100 for every level
  gained. Moves learned during those levels are applied on retrieval.
- Compatibility uses the Generation-II egg groups and Attack-DV gender rules
  for all 251 Kanto and Johto species. Ditto, genderless species, baby Pokémon
  and the Undiscovered group follow their normal restrictions.
- Egg DVs use Crystal's exact inheritance: Defense and the lower three Special
  bits come from Ditto or the opposite-gender parent. A valid shiny donor can
  therefore yield the authentic 1/64 shiny result. Parents with matching
  Defense and lower Special bits are incompatible, as in Crystal.
- Every 256 compatible walking steps performs an egg check. Compatibility
  dialogue explains whether the pair has a high, normal, low or zero chance.
- Eggs wait safely with the attendant until there is a free party slot. A
  carried egg cannot battle, be healed or act as a parent.
- Hatch distance comes from that species' own egg cycle. Hatching records the
  Pokémon as owned and preserves its Route 5 or Elm research origin.
- A pre-3.1 vanilla Day-Care deposit, its level baseline and all accumulated
  step experience migrate into parent slot one automatically.

The machine visible beside the attendant lists every currently possible item
evolution in the party. Elm's aide remains the research contact in Oak's Lab
and points the player to this physical machine.

## Generation-II shinies

Every Pokémon from Bulbasaur through Celebi can be shiny. The result is stored
entirely in its normal Gen-1 DVs: Defense, Speed and Special must be 10, while
Attack must be 2, 3, 6, 7, 10, 11, 14 or 15. Natural encounters therefore keep
Crystal's **1/8192** rate and existing compatible Pokémon are recognized when
an old save is opened.

The Start menu's **ASCENDANT** submenu gains a bilingual **SHINY DEX** after
the Hall of Fame. It
tracks shiny species seen in battle and actually caught or hatched. Owning all
251 ordinary species awards Oak's non-tossable **Shiny Charm**, which adds two
independent shiny rolls:

| Condition | Additional 1/8192 rolls |
|---|---:|
| Shiny Charm | 2 |
| 10 consecutive field-rematch wins | 1 |
| 25 consecutive field-rematch wins | 3 |
| 50 consecutive field-rematch wins | 7 |
| Active outbreak route | 15 |

Charm, streak and outbreak rolls stack. Losing a field rematch resets the
streak; wild battles do not. Every tenth consecutive win starts a
deterministic Johto outbreak for **2048 player steps**. On its named route, a
quarter of normal encounters become the outbreak species and receive the
large shiny bonus.

A 25-win streak after the Hall of Fame also begins a one-time world event:
Oak reports a red Gyarados in **Seafoam Islands B4F**. Random encounters on
that floor lead to the guaranteed level-50 shiny until it has been caught, so
knocking it out or fleeing never destroys the event.

Kanto Ascendant includes its own entrance sparkles, two-note chime, HUD marker
and status icon. On engine 0.1.90, disable the standalone
`shiny_indicators` package before enabling Ascendant: its current upstream
release still uses APIs denied by the sandbox and overlaps Ascendant's
generated-sprite and battle-presentation hooks. Shiny hunt progress is owned
entirely by Ascendant and is unaffected by that package being absent.

The Shiny Dex also records wild encounter totals and the number of shiny
copies caught for each revealed species. **SHINY RELEASE LOCK** protects
shiny Pokémon from accidental release through Bill's PC; it can be disabled
explicitly in the mod options.

## Ascendant Battle Frontier and Johto Masters

The former Grand Tournament is now the **Ascendant Battle Frontier** in the
Indigo Plateau lobby. Its three-round level-100 brackets retain Open, No-Item,
Trio, Endurance, Set-Style and Kanto-Purist rules. Victories award three
Frontier Points, or five for a run without a faint. A Frontier Festival world
event doubles that award. Historical event catch-up prizes and the existing
rare item rewards remain available.

After the first Hall-of-Fame entry, a second Indigo host opens the final
**Johto Masters Trial**:

1. Silver uses a rotating aggressive pool.
2. Kris uses a rotating strategic pool.
3. Gold uses a rotating Champion and legendary pool.

All opponents use full level-100 teams, maximum battle AI and a sealed Bag.
The player's team is fully healed before every round, but the three opponents
must be cleared in sequence. Each Master owns twelve candidates and selects a
different set and order for every attempt. Every later run requires one new
Hall-of-Fame entry—defeat the Elite Four and Champion again—and always starts
at Silver; Gold cannot be repeated directly to farm shinies.

Gold alone gives the reward after a successful run: one genuine-DV shiny,
selected uniformly from all 251 Pokémon. Starters, fossils, Mew, Celebi and
every legendary have the same individual 1/251 chance; duplicates are
possible. A full party sends the gift to a Box, while a completely full PC
causes Gold to reserve the already-selected species instead of rerolling or
destroying it. The trial is repeatable without limit.

The first clear also awards the permanent **KANTO ASCENDANT** title and a
golden Trainer Card treatment. Later clears retain the title and continue to
award exactly one random shiny from Gold.

Kanto Ascendant 5.0 adds two more Crown facilities:

- The **Battle Factory** host in Indigo offers six changing, fully evolved
  non-legendary level-100 rentals. Draft exactly three, clear three no-item
  battles and earn 4 Frontier Points, or 6 when no rental faints. The player's
  exact original party is backed up and restored after victory or defeat.
  Saving is deliberately blocked during a live rental run; loading a stale
  interrupted save from an earlier build safely restores the original party.
- The **S.S. Anne Grand Tour** departs from Vermilion for five rotating
  level-100 no-item battles. The party is healed after decks two and four.
  A clear awards 8 Frontier Points; the next voyage departs after 4096 actual
  walked steps, never accelerated trainer-training steps.

The first clears add the selectable **Factory Architect** and **Sea Champion**
titles.

## Discovery certificates and living world

The Game Freak designer in Celadon Mansion 3F now keeps four separate
completion certificates:

| Certificate | Requirement |
|---|---|
| Kanto | Own #001-150 |
| Myth | Own all 151 Kanto species, including Mew |
| National | Own #001-250 |
| Complete | Own all 251 species, including Celebi |

Only true Pokédex ownership unlocks a certificate. Future tiers stay completely
hidden until they are earned, so the next milestone is never spoiled. Earned
certificates can be reopened from **ASCENDANT → DEX CERTIFICATES** in the
Start menu.

After the Hall of Fame, Kanto also rotates step-based world events. Each lasts
2048 walked steps and is stored in the save:

- **Training Rush** advances trainer recovery and silent growth twice per step.
- **Johto Migration** adds a rare Johto species to one announced Kanto route.
- **Golden Wind** adds two shiny rolls to every wild encounter.
- **Frontier Festival** doubles Frontier Points.

The **ASCENDANT → JOURNAL** page combines Oak's legendary sightings and live
roamer locations, Crown Archive titles, all eight type masteries, the current
world event and Johto Masters records. Crown rematches permanently reveal the
matching Leader type mastery. Blue's later boss teams now rotate Johto
counter-picks in addition to reacting to the player's dominant party type.

The new **ASCENDANT → RESEARCH ATLAS** consolidates discovery without exposing
future content. It shows the current Oak objective, every already-recorded
trainer's exact remaining steps, rank and location, the exact active rematch
loot bands and gates, the TM queue/cycle status, and habitat information only
for species already seen or caught. Unseen Johto species and future
certificates remain concealed; once a species is recorded, the Atlas shows
only its currently active native and researched habitat sources. Habitat
terrain distinguishes grass, water, caves, buildings and other interiors;
displayed encounter percentages are clearly marked as base chances before
temporary world events or other later encounter overrides.

Celadon Mansion 3F also gains a **Legacy Gallery** curator. The gallery shows
earned completion, circuit, Frontier, Johto Masters, Factory and cruise
trophies. Any unlocked achievement can be selected as the active Trainer Card
title instead of being replaced automatically by the newest one. The selected
title survives Ascendant New Game Plus and the full localized title fits the
card's badge banner without byte-based umlaut truncation.

## Mega Evolution and individual stones

After the first Hall of Fame, use the Route 5 evolution machine to synchronize
the **Mega Ring** and register the **Mega Stone Case**. Stones live in this
separate case because Gen 1 has no held-item field and its ordinary Bag has
only 20 slots. A matching owned stone resonates automatically; it is still a
strict form-specific requirement.

During a normal battle, press **SELECT** (`Tab` by default on keyboard) while
the four-choice FIGHT/PKMN/ITEM/RUN menu is visible. One Pokémon per side may
Mega Evolve in each battle. The transformation is battle-only: HP, stored
party stats and save data are not permanently changed, and the same Pokémon
remains transformed if switched out and back in.

Only species with an officially released Mega Evolution through **July 2026**
are eligible. Within the mod's National Pokédex #001-251 this produces exactly
**27 species and 30 forms**:

| Group | Eligible forms |
|---|---|
| Classic Kanto | Venusaur; Charizard X/Y; Blastoise; Beedrill; Pidgeot; Alakazam; Slowbro; Gengar; Kangaskhan; Pinsir; Gyarados; Aerodactyl; Mewtwo X/Y |
| Classic Johto | Ampharos; Steelix; Scizor; Heracross; Houndoom; Tyranitar |
| Newly discovered in Z-A | Clefable; Victreebel; Starmie; Dragonite; Meganium; Feraligatr; Skarmory |
| Mega Dimension | Raichu X/Y |

Ordinary Pikachu and every other species without an official Mega Evolution
are rejected by the official Mega system. Yellow's specifically marked
Oak-gift partner is the sole exception: if it remains Pikachu, Raichunite X or
Y can bridge it directly into the corresponding official Mega Raichu for that
battle. Its stored species remains Pikachu and it returns to Pikachu
afterward. The Stone Case remains a strictly official 30-form catalog; the
separate secret fan form described below is never presented as a released
Mega Evolution.

### Yellow partner: Heart of Thunder

After the Thunder Badge, Lt. Surge can begin an optional early partner
journey. Walk **251 steps** and win **three trainer battles** with Yellow's
original Pikachu in the party, then return to Surge. He condenses its charge
into the permanent **Thunderheart / Donnerherz**.

Thunderheart is a key item: it cannot be consumed, sold, discarded or
deposited. Using it lets Pikachu choose one of three answers:

- evolve permanently into Raichu;
- remain Pikachu and awaken Raichu's full strength once;
- wait and decide later.

Choosing **Stay Pikachu** once makes only the marked original partner use
Raichu's complete 60/90/55/100/90 base-stat profile while preserving
Pikachu's form and its own level-up moveset. The option then disappears, but
Thunderheart remains and permanent evolution into Raichu stays available at
any time. That later evolution changes only the form and grants no second
stat increase.

Raichu keeps the exact partner identity, Yellow happiness and memories, gains
its own bond responses and continues following with or without an all-species
follower mod. Mega-Raichu X/Y remain temporary later options for the marked
partner. Gorochu remains the stronger permanent postgame evolution reached
through Raichu and the Thunder Tear.

Upgraded Yellow saves that already have the Thunder Badge receive one
Thunderheart automatically with the walking/battle trial completed. When only
one self-owned Pikachu or Raichu exists it is adopted automatically. A save
with several candidates receives a one-time choice instead, so the mod never
silently marks the wrong Pokémon. Red and Blue do not receive Yellow's partner
choice or Awakening route; their Thunderheart powers only the separate
Gorochu journey described below.

### Gorochu: the Thunder Path evolution

Raichu can now evolve permanently into the guest species **Gorochu** in Red,
Blue and Yellow through a voluntary item journey:

1. In Red and Blue, return to Lt. Surge after earning the Thunder Badge and
   accept the permanent **Thunderheart**. In Yellow, complete the original
   partner's Heart of Thunder trial—251 steps and three trainer victories—
   before returning to Surge for the same item.
2. Follow the Thunderheart to a silent condenser in the Power Plant's remote
   east wing, far from Zapdos.
3. Let the condenser form one consumable **Thunder Tear**. The permanent
   Thunderheart returns to the Bag.
4. Use the Tear outside battle on the Raichu you choose. The item is consumed
   and the evolution is permanent.

This replaces 5.4.0's bond/Thunder/Power-Plant level-up condition; no Hall of
Fame or level-up trigger is required by the new path. Yellow's original marked
partner keeps the same identity, happiness, memories and follower after the
evolution. Existing saves that already completed the 5.4.0 evolution retain
their Gorochu discovery and opponent unlock.

Yellow dialogue that explicitly addresses the player's tracked partner follows
that identity too: relevant Celadon Mansion, Pewter Museum, Gym and Surfing
lines say Pikachu, Raichu or Gorochu as appropriate. Text about another
character's Pikachu, wild Pikachu and the Pokédex is left untouched.

Gorochu is a pure Electric species with dedicated normal/shiny front, back,
six-frame Crystal animation and an independent six-pose follower sheet.
Dramatic Shape/Voxel uses separate sharp 96×96 normal/shiny front and back
masters instead of enlarging the smaller 2D battle card. Yellow's partner
version also has seven separate animated normal/shiny faces for sleepy,
unwell, upset, wary, content, devoted and excited reactions; Raichu has the
same complete dialogue-portrait coverage, and these portraits never replace
battle art.

Audio follows the active edition. Yellow uses the dedicated spoken Gorochu
cry, while Red and Blue use a Gen-I-style chip cry derived from Raichu with
their native audio path. A Gorochu cry registered by another mod always takes
priority over both bundled fallbacks.

Gorochu uses guest Pokédex number **1026**. It appears in the Research Atlas
and Shiny Dex only after discovery, and it deliberately remains outside all
original 151/251 completion certificates and Shiny Charm requirements.
It also remains hidden from every opposing trainer in Red, Blue and Yellow
until the player personally completes the Raichu-to-Gorochu evolution on that
save. Before then, Major Bob and Randomizer-generated trainer teams receive
Raichu instead; owning the Heart or Tear alone never reveals Gorochu.

The Route 5 machine forges most stones individually:

- Classic non-Mewtwo stones unlock with the Ring after the first Hall of Fame
  and normally cost ¥5,000. Charizardite X/Y cost ¥7,500 each.
- Most newly discovered Z-A stones and Raichunite X/Y unlock after all eight
  Master Leaders and cost ¥10,000 each.
- **Meganiumite and Feraligatrite cannot be bought.** Owning any member of
  the Chikorita or Totodile family assigns its one-time **STARTER RELIC**
  journey, regardless of whether it came from Elm's trial, a wild encounter,
  a gift, a PC box or an upgraded save. Keep that family in the party to
  complete its walking and trainer-battle goals. Endivie's family must also
  retrace Kanto's oldest growth in **Viridian Forest**; Karnimani's family must
  brave the ice and current of the **Seafoam Islands**. The completed relic is
  claimed from its keeper in Celadon or Cerulean. Newly assigned journeys show
  `NEW` in both Start-menu layers; each Relic page and the shared Journal
  tracker always name the next required objective and location.
- Mewtwonite X/Y unlock after the Apex Champion and cost ¥15,000 each.
- **ASCENDANT → MEGA STONES** shows the complete Stone Case and live
  `OWN`, price or `LOCK` status.
- When both stones are owned, the Route 5 form menu selects Charizard X/Y,
  Mewtwo X/Y or Raichu X/Y.

Every form uses a +100-point Kanto adaptation across the four non-HP Gen-1
stats, accounting for the fact that later games split Special Attack and
Special Defense. Type changes supported by Kanto Ascendant are applied in
battle. All **30 official forms** now have dedicated sharp 96×96 front, back,
normal and shiny master sprites plus side-aware integer-pixel animation loops.
Each silhouette remains crisply readable in the original 2D arena and in
Dramatic Shape's Voxel-facing battles; the original command box cleanly masks
the player sprite below its top border, and no form falls back to its ordinary
species sprite. They also ship with separate static four-shade Gen-I
derivatives. With Crystal art disabled, the engine recolours those cards
through the active Red, Blue or Yellow monster palette instead of displaying
the full-colour animated Mega art. Gen-I-mode shinies retain distinct
four-shade artwork, and Voxel uses the same edition-aware palette.

<details>
<summary><strong>Secret-form spoiler: Ascendant Typhlosion</strong></summary>

Owning Cyndaquil, Quilava or Typhlosion assigns the third one-time **STARTER
RELIC** journey. Its final Basalt stage opens after defeating **Gold**, when a
black seal appears in **Pokémon Mansion B1F**. It awakens only when the player
has caught all **251 Pokémon** and brings a **level-100 Typhlosion** in the
party. The permanent Basalt Core then unlocks **Ascendant Typhlosion**, a
clearly labelled Kanto Ascendant fan form that uses the same SELECT input
without using a Mega Stone.

Ascendant Typhlosion becomes **Fire/Ground**, receives a +100 non-HP stat
adaptation and restores 25% HP once when awakening. It has dedicated sharp
96×96 normal/shiny front and back sprites with the approved broad obsidian
chest-and-shoulder mantle, open V, bracers, greaves and volcanic dorsal
plates. The front master is reduced directly from the accepted full-resolution
concept instead of reconstructing its armor with disconnected geometric
overlays. Its 23-frame front motion is merged with Pokémon Crystal's authentic
#157 flame animation and timing, building from a calm mantle into a full cyan
volcanic explosion behind the armored body before settling again. The player
back receives the same readable eruption through a separate 12-frame loop.
Both work in normal 2D and Voxel-facing battles. The discovered relic remains
unlocked through New Game+ cycles.

</details>

**ENEMY MEGA** defaults to post-game bosses, can be expanded to every trainer
or disabled. An opponent waits until an actually eligible team member is
active; it can no longer transform an arbitrary species. **MEGA EVOLUTION**
disables the entire system.

The official game description confirms that Mega Evolution normally requires
a Key Stone and a matching held Mega Stone. The official Mega Dimension page
also confirms that Mega Raichu X and Y use two different stones:
[Mega Evolution](https://legends.pokemon.com/en-us/mega-pokemon) and
[Mega Dimension](https://legends.pokemon.com/en-us/dlc).

## Hall-of-Fame post-game

The first Hall of Fame opens the new progression. Master Gym Leaders can be
challenged in any order.

| Stage | Requirement | Level curve | Result |
|---|---|---:|---|
| Master Circuit | First Hall of Fame | 76-90 | Win all eight Master crests |
| Apex Elite Four | Eight Master crests | 90-100 | Defeat Lorelei, Bruno, Agatha, Lance and the Champion |
| Legendary Hunt | Apex Champion | 80-95 | Catch the awakened Kanto and Johto legends |
| Crown Gyms | Catch Lugia and Ho-Oh | 100 | Defeat all eight level-100 specialists |
| Crown Elite Four | Eight Crown wins | 100 | Beat the final legendary Champion team |
| Heritage Festival | Two to five badges | Original event levels | Win five historical three-round Cups |
| Ascendant Frontier | Crown Champion | 100 | Win rotating three-round brackets |
| Battle Factory | Crown Champion | 100 | Draft three rentals and clear three battles |
| S.S. Anne Grand Tour | Crown Champion | 100 | Clear five decks; returns after 4096 real steps |
| Johto Masters | Crown Champion | 100 | Defeat Silver, Kris and Gold without items |
| Origin Investigation | Crown, research and event completion | 5 or 100 | Follow the final trail to Mew |
| Ascendant Cycle | Every major system completed | 100 | Replay the complete mod post-game |

Each boss uses a fixed six-Pokémon competitive roster with four selected moves
per Pokémon. The Master and Apex teams contain no legendary Pokémon. Legends
first appear on enemy teams in the Crown Circuit, after their encounters have
become available.

Every circuit boss has new character-specific English and German writing.
Each Gym Leader has separate Master and Crown introductions, refusal reactions,
step-count recovery lines and in-battle defeat quotes, plus personal hints for
the next progression stage. The Apex and Crown Elite Four and Champion have
their own before-battle, defeat and after-battle scenes. These replacements
activate only for the stronger circuits. On the first story clear, Professor
Oak adds one new scene before leading the player into the Hall of Fame:
increasing legendary sightings, shadows, storms and unknown beasts foreshadow
the coming hunt without unlocking those encounters early. The announcement
plays once; later League clears restore Oak's normal invitation.
Dialogue that names a legendary automatically switches to a matching
non-legendary variant when that encounter is disabled in **OPTIONS**.

Giovanni returns to Viridian Gym for the circuit. After a circuit battle, a
leader uses the same step-based recovery period as other rematch trainers,
reports the exact remaining steps, and becomes repeatable when ready.

### Leader personal missions and adaptive teams

After the Apex victory, every Gym Leader offers a personal mission built
around their character and specialty. The assignments ask for themed field
rematches—such as Water trainers for Misty, Psychics for Sabrina and Rockets
for Giovanni—and report exact progress. Completing one awards a rare item and
unlocks that Leader's signature roster variant.

Master, Apex and Crown opponents no longer present one completely static plan:
repeat battles use six deterministic order variants, completed Leader missions change signature
slots, and the Champion can bring a non-legendary counter to the dominant type
in the player's current party. Disabled legendary options continue to use
their non-legendary replacements.

## Kanto Heritage events

Five new hosts appear naturally as badges are earned. Each runs a
three-opponent themed bracket and awards one faithful Generation-I event build
at its original level:

| Heritage Cup | Unlock | One-time prize | Historical build |
|---|---:|---|---|
| University Cup | 2 badges | University Magikarp Lv.15 | Splash, Dragon Rage |
| Stamp Sky Cup | 2 badges | Pokémon Stamp Fearow Lv.25 | Growl, Leer, Fury Attack, Pay Day |
| Balloon Cup | Thunder Badge | Flying Pikachu Lv.5 | ThunderShock, Growl, Fly |
| Stamp Fire Cup | 4 badges | Pokémon Stamp Rapidash Lv.40 | Ember, Fire Spin, Stomp, Pay Day |
| Wave Cup | Soul Badge | Surfing Pikachu Lv.5 | ThunderShock, Growl, Surf |

**HERITAGE EVENTS** can replace the festival with **ROAMING HUNTS**. In that
mode the same five Pokémon wander suitable Kanto habitats. Their map, HP,
status and fixed DVs persist between encounters; they can move after a map
change, optionally flee on their first action, and recover after three map
visits if knocked out. The original cup prizes remain available as Ascendant
Frontier catch-up awards when Festival mode is active.

The Start menu's bilingual **ASCENDANT → EVENT ARCHIVE** records every
distribution, original level, moves and source permanently across Ascendant
Cycles. Event Pokémon carry provenance in their save record, receive a small
battle rosette, and gain an **EVENT INFO** entry in their party submenu. A full
party and PC never destroys a prize: one reserved Pokémon waits in the archive
until space is available.

Mew's heritage finale remains the canonical authored conclusion.
**MEW PROFILE** chooses the Ascendant level-100 encounter or a historical
level-5 Nintendo Space World '99 build with Pound and fixed
HP/Attack/Defense/Speed/Special DVs of 5/10/1/12/5. Optional Mythic Signals
honor that conclusion and never create a second owned copy. Turning **MEW**
off still skips both paths and its completion requirement entirely.

Historical levels, moves and Mew DVs were checked against the
[Generation-I Japanese distribution archive](https://bulbapedia.bulbagarden.net/wiki/List_of_Japanese_event_Pok%C3%A9mon_distributions_in_Generation_I).

## Oak's Ascendant research

Oak's Lab scientist manages eight sequential assignments alongside the
legendary Research Log:

1. Win five field-trainer rematches.
2. Raise three trainers to Expert rank.
3. Earn four Master crests.
4. Catch three enabled legendary Pokémon.
5. Complete four Leader missions.
6. Win three Ascendant Frontier rounds.
7. Defeat all four Rocket Resurgence units.
8. Defeat the Crown Champion.

Each report has a fixed rare reward. A full Bag never destroys it: the
scientist reserves the item until space is available. Disabled systems are
automatically skipped so they cannot block research completion.

## Ascendant Battle Frontier

After the Crown Champion, a new host appears in the Indigo Plateau lobby.
Every bracket contains three consecutive level-100 battles selected from six
new opponents. The rules rotate after every attempt:

- **Open Rules** — three standard battles, with recovery between rounds.
- **No-Item Cup** — the Bag is sealed for all three battles.
- **Trio Cup** — only the first three party Pokémon can participate.
- **Endurance Cup** — no healing between rounds.
- **Set-Style Cup** — no free switch after an opposing Pokémon faints.
- **Kanto Purist Cup** — legendary party Pokémon are sealed.

Opponents and bracket order change with every run. Victories, best round,
Frontier Points and titles are recorded in the Crown Archive. Every fifth
championship awards a Master Ball; other completed brackets award PP Up. A
clean run without a faint gives five points instead of three. If a missed
Heritage distribution is currently available, a championship also awards the
next unclaimed event Pokémon.

## Rocket Resurgence

After the Apex Champion victory, a four-part Team Rocket story begins:

1. Stop a legendary-energy relay inside the Power Plant.
2. Defeat the Rocket administrator occupying Silph Co.'s top floor.
3. Confront the executive using Pokémon Tower's spirits to trace an origin.
4. Face Giovanni's final level-100 control experiment in Viridian Gym.

Each victory changes NPC dialogue across Kanto and reveals the next location.
The storyline can be disabled independently without blocking research, titles
or the final Ascendant Cycle.

## A living post-game event

The expansion now changes Kanto around its milestones instead of presenting
the new battles without comment:

- After the first Champion victory, Oak reports increasing legendary
  sightings before leading the player into the Hall of Fame.
- Oak's Lab scientist by the entrance opens the bilingual **Research Log**.
  It reports the current objective, Master/Crown progress, captured legends,
  encounter requirements and each roaming beast's latest tracked route.
- Seven witnesses in Pallet, Cerulean, Vermilion, Fuchsia, Lavender, Cinnabar
  and Indigo react differently during the rumor, Apex, hunt, Crown and
  completed phases.
- Every legendary encounter has a species-specific atmospheric introduction,
  followed by its cry and a white flash before battle.
- After the first legendary capture, the Rival appears in Oak's Lab with a
  one-time level-100, non-legendary hunter team. Defeating him records the
  event in the archive; losing or declining leaves the challenge available.
- The right side of the Hall-of-Fame recording console opens the bilingual
  **Crown Archive**, showing field rematches, Master and Crown crests, Apex and
  Crown titles, legendary captures and the Rival event.

## Legendary unlock order

Legendary encounters are sealed until the Apex Champion has been defeated.
They cannot be fought or caught early with the default `APEX` settings.

- **Articuno, Zapdos and Moltres** awaken at level 80.
- **Mewtwo** awakens at level 90.
- **Raikou, Entei and Suicune** begin roaming Kanto at level 85. Each occupies
  a grass route and can move when the player changes maps. On its current
  route it appears visibly in tall grass with the game's standard monster
  overworld sprite; talking to it starts the encounter. The existing 1-in-32
  chance to replace a grass encounter on that route remains as a second way
  to find it.
- Catch all three birds to reveal **Lugia** at level 95 in Seafoam Islands.
- Catch all three roaming beasts to reveal **Ho-Oh** at level 95 on Pokémon
  Tower's summit.
- Catch Lugia and Ho-Oh to open the Crown Circuit and reveal the secret
  **Celebi** encounter at level 90 in Viridian Forest.
- After the Crown Champion, every enabled legend, all research reports and
  Rocket Resurgence are complete, Oak begins a three-clue investigation.
  Follow Oak to Mr. Fuji and the Cinnabar fossil room to reveal **Mew** at
  level 100 on Route 24, or level 5 with its historical profile.

The new map encounters deliberately reuse the built-in overworld sheets:
`SPRITE_MONSTER` for Raikou, Entei and Suicune, `SPRITE_BIRD` for Lugia and
Ho-Oh, and a small mythic silhouette for Celebi.

The mod's own **OPTIONS** page can change this per species:

- Articuno, Zapdos, Moltres and Mewtwo: `APEX`, `VANILLA` or `OFF`.
- `VANILLA` makes the selected bird available normally at level 50, or
  Mewtwo at level 70, without requiring the Master/Apex circuits.
- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi each have an independent
  `ON/OFF` switch.
- Mew has its own `ON/OFF` switch plus Ascendant Lv.100 and historical Lv.5
  profiles, and is skipped as a final completion requirement when disabled.
- `OFF` removes the encounter and skips it as an unlock requirement. Crown
  boss copies are replaced by suitable non-legendary Pokémon as well.

Knocking out or fleeing from a legendary does not remove it. Only a successful
capture completes that encounter. Saves in which a vanilla legendary was
previously hidden after a KO or flee recover the encounter unless that species
is already marked as owned in the Pokédex.

## New species and moves

The mod expands the Pokédex to the canonical **251** and adds every species
from Chikorita through Celebi, including:

- All three Johto starter lines
- Every common, baby, branch-evolution and pseudo-legendary family
- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi
- Additive Dark and Steel typing for the new Johto content; existing
  Generation-I type, stat, learnset and move records retain their vanilla
  Kanto data, with only additive evolution branches into new Johto species
- Crunch, Metal Claw, Iron Tail, Shadow Ball, Flame Wheel, Giga Drain,
  Sludge Bomb, Spark, Powder Snow, Aeroblast and Sacred Fire

Every new species has base stats, typing, learnset, TM compatibility, Pokédex
data and a four-shade Kanto fallback. After all enabled mods finish loading,
Ascendant preserves any externally registered Gen-II cry and installs its
bundled species-authentic legacy cry only for species still missing audio.
Mega and Ascendant forms use that resolved base-species cry. The six story
legends retain their authored front/back pixel art. Their party-menu icons use
the game's standard animated silhouettes: quadruped for the three beasts, bird
for Lugia and Ho-Oh, and the Mew-like mythic icon for Celebi.

Gorochu follows the same external-owner rule but selects its bundled fallback
by edition: Yellow receives the dedicated spoken clip, while Red and Blue use
the Raichu-derived Gen-I chip definition. Changing editions during scripted
testing replaces only Ascendant's own previous fallback, never another mod's
registered cry.

### Bundled Crystal battle art

Authentic normal and shiny Pokémon Crystal front/back sprites for **all 100
Johto Pokémon**, plus matching normal/shiny player backs for **Kanto
#001-151**, are included in the release. No separate download is needed.
The repair utilities can validate or refresh both sets:

```sh
python3 tools/install_crystal_sprites.py
python3 tools/install_kanto_crystal_backs.py
```

**JOHTO ART** defaults to `CRYSTAL` and uses each bundled pair. Choose
`KANTO FALLBACK` to switch back at any time. A damaged or incomplete
installation remains safe because each missing pair falls back independently.
Crystal art is edge-keyed into a transparent derived copy, so the white battle
background never becomes a rectangular card in Dramatic Shape's on-map
battles. When that renderer makes both Pokémon face its camera, the matching
normal or shiny Crystal front sprite is used on both sides.

### Crystal animation and external-mod compatibility

Normal and shiny Crystal front animations for **all #001-251** are bundled as
numbered frames with the source-game timing. **KANTO CRYSTAL ART** switches
the first 151 between bundled Crystal front/back art and the original Gen-I
art; **CRYSTAL ANIMATION** controls front motion. In the original 2D battle
layout the opponent animates and the player's matching Crystal back remains
static at native size. In Dramatic Shape's staged Voxel battles both
front-facing Pokémon animate.

The integrated v1.5 presentation layer additionally supplies authored
grayscale animations for #001-251, Kanto normal/shiny/grayscale backs,
Crystal trainer/player portraits, Tower Ghost art and animated Crystal views
in summary, Pokédex, evolution, Hall of Fame, title and Oak-intro scenes.
Palette modes choose the matching colour or grayscale source before the
engine palette pass. Ditto keeps the copied silhouette with its purple tint
and returns cleanly after switching or battle end. These additions are
strictly scoped by the existing battle/summary/Pokédex/box/scene toggles.

The complete v1.5 normal/shiny/grayscale sprite and animation pipeline is now
owned by Kanto Ascendant. The external
[Crystal Animated Sprites with Shiny Visuals](https://github.com/distilledorion-sketch/crystal_animated_sprites_with_shiny_visuals)
package and
[LOW-K3YS's Voxel-compatible fork](https://github.com/LOW-K3YS/crystal_animated_sprites_with_shiny_visuals)
must not be enabled beside Ascendant: both packages wrap the same battle,
party, box, Pokédex and shiny-presentation hooks. The Recompile launcher
blocks the combination and explains why. Players can still choose Gen-I,
Crystal, animated/static and per-screen presentation inside Ascendant. Mega
forms always keep their form silhouette: Crystal mode uses the sharp
full-colour animation, while Gen-I/Kanto-fallback mode uses the matching
static four-shade Mega card.

Randomizers also receive every authored Ascendant boss roster as their actual
input, including Master/Crown Leaders, Apex/Crown Elite battles, Johto
Masters, research trials, Grand Tour, Heritage Cups, tournaments and hunts.
They may replace species and moves; Ascendant retains the battle type, team
size, per-slot level pattern, AI, rewards and progression rules. Invalid or
vanilla-party fallback output is repaired before the battle begins.

Unown is the sole static exception because Crystal stores its separate letter
forms rather than a generic animated #201 sheet; the included form-A Crystal
art remains authentic.

### Follower and voxel compatibility

Kanto Ascendant does not require a Voxel renderer: the complete campaign,
including the fissures, remains available through the engine's native 2D
renderer. Official packages from their current baselines through 2.x are
admitted on a best-effort basis: Voxel Ascendant `>=0.1.0-rc.1 <3.0.0-0`,
Dramaless `>=1.6.2-ST.190.1 <3.0.0-0`, Battle Art `>=1.9.0 <3.0.0-0`, and
PotatoVoxel `>=1.7.2 <3.0.0-0`. Use only one renderer. Unversioned packages, 3.x
builds and multi-renderer setups fail closed. Canonical repositories are the
support contract; rich managers and runtime metadata reject explicit mismatches,
while older managers primarily enforce the ID/version fence.

The known baselines keep their exact reviewed adapters. Exact Dramaless
`2.0.2` is renderer-native and alone receives the narrow fixed `BattleCam`
control; every other Dramaless 2.x build remains completely native-owned.
Exact Battle Art `1.9.2` alone receives the optional mesh-cache lifecycle
repair. Future in-range releases receive only the common closed capability
surface and never inherit those exact adapters. PotatoVoxel keeps its own
camera, HUD, quality controls and cache; its upstream `LOGS TO DEV` option is
ON by default and can be disabled in Voxel Settings or the mod manager.

Series admission is not a promise that an untested upstream release cannot
change its API or visuals. If a renderer update breaks Kanto Ascendant, roll
that renderer back to the last working release and report it; a separate KASC
allowlist update is not required for each 1.x/2.x release. Dramatic Shape,
Terrarium and First Person remain blocked. External renderer assets are never
included in the Kanto Ascendant ZIP.

For reproducibility, the exact reviewed Dramaless 2.0.2 and PotatoVoxel 1.7.2
release ZIP hashes are respectively
`85e2f866bd7badce4c5d97ccbf1f8b88b2a9fd30ec0659454c187d7398b808a7` and
`200153d7623db14e08925d1b51f99f8ccbfa5e32db134922f51c8179bd64fd33`.
The reviewed Battle Art 1.9.0/1.9.2 hashes are
`3ba60ad7dc8443f2a337c147ca8be31ce3661fd549cf9b4e4e000206c3d780c8` and
`144e53200a06b6652433804bd89f18d1d378a15a63fefedaa4da22401c313f24`.

Species-accurate normal and shiny 16x16 Gen-2-style walking sprites are also
bundled for every Johto Pokémon. The repair utility can refresh them:

```sh
python3 tools/install_gen2_followers.py
```

The package contains normal and shiny six-pose PokeWilds sheets for 99
species; Unown is built from its matching Crystal front sprite. Every release
also includes renderer-ready 16×96 copies in Gen1 Recomp's exact down/up/side
walking layout, so mobile devices do not need to generate or cache them.
The selected individual determines whether the normal or shiny sheet is used.
Both the normal 2D renderer and Dramatic Shape's voxel renderer consume the
same packaged sheet. The source project and individual sprite contributors are
credited in the [PokeWilds project](https://github.com/SheerSt/pokewilds).

If an individual sheet is damaged or missing, the related Kanto silhouette
remains as a crash-safe fallback until the package is repaired.

Ascendant now owns the active follower system in Red, Blue and Yellow. Choose
up to six party followers from the Pokémon menu; Yellow's native partner
Pikachu keeps its original mood and dialogue, while additional followers use
Ascendant's interaction path. Standalone PokéPC Followers/Followers EX
packages must be disabled before Ascendant is enabled because both would own
the same follower and sprite hooks.

Kanto Ascendant now bundles the supported **Wilds of Kanto 1.12.2** spawn,
ambient-town, renderer and AI core. Visible Kanto encounters and peaceful
town Pokémon therefore work in a clean Ascendant-only installation; the
standalone Wilds follower controller and settings menus are deliberately not
started. Ascendant registers all 100 Johto species with the renderer as
normal/shiny six-frame walker sheets rather than static battle portraits.
`AUTO` or `FOLLOWERS EX` sprite style uses Ascendant's bundled Johto walkers.

Early Wanderwaves and Johto Unleashed apply to newly created visible Wilds
entities as well as classic grass encounters. A visible Pokémon is rolled when
it appears, not when the player later touches it. Changing the Johto current,
scanning a primal trace or toggling **VISIBLE JOHTO**, **EARLY JOHTO** or
**MYTHIC SIGNALS** clears stale visible rolls so the next entities use the new
state. The Johto Signals submenu has a **WILDS LINK** page showing whether the
bundled living-world provider is ready or disabled.

Once a family has been researched, the same rare Kanto habitat used by
ordinary encounters can also produce that species visibly in the overworld.
Hall-of-Fame and research gates, authored levels and the original two-percent
replacement chance remain unchanged. At two percent, a long dry run is
possible: even 50 eligible fresh rolls still have roughly a 36% chance of no
ordinary Johto replacement.

## Options

Open **MODS → KANTO ASCENDANT → OPTIONS** for the mod's own configuration
submenu. It contains:

Character art is grouped under **START → ASCENDANT → OPTIONS → VISUALS →
CHARACTERS / TRAINERS**. **FIELD CHARACTERS** changes only overworld sheets.
**TRAINER PORTRAITS** switches Red, Blue and Green between `CRYSTAL HD` and
`ORIGINAL` across the selector, Trainer Card, normal 2D front/back, rival,
tutorial and other 2D identity surfaces. Staged 3D and throw art remains owned
by the active reviewed renderer.

- **REMATCH BREAK** — `VERY SHORT` 151-302, `SHORT` 303-604, `NORMAL`
  605-1255, `LONG` 1256-1882, `VERY LONG` 1883-2510 or `CUSTOM`. Fresh saves
  start on NORMAL. In Ascendant's in-game menu the numeric minimum/maximum
  rows appear only for CUSTOM; switching profiles preserves those values and
  changes only intervals scheduled afterward.
- **LEVELS / REMATCH** — field-trainer strength gained per completed rematch
  or silent training cycle (default 2; set to 0 to disable level scaling).
- **TEAM GROWTH** — allow thematic party recruitment as trainers gain
  strength tiers (default on).
- **REMATCH LOOT** — `OFF`, `BALANCED` or the more rewarding `GENEROUS`
  rare-item table.
- **JOHTO ART** — use the bundled Crystal battle art for all 100 species or
  force the four-shade Kanto fallback. Johto Mega and Ascendant forms follow
  this choice too.
- **KANTO CRYSTAL ART** — use bundled normal/shiny Crystal fronts and player
  backs for #001-151 without requiring a separate sprite mod. Kanto Mega
  forms follow this choice and receive the active Red/Blue/Yellow palette
  when disabled.
- **DEX SPRITES** — independently choose `ORIGINAL` (default), preserving the
  active Red/Blue/Yellow ROM's palette-aware Kanto Pokédex fronts, or
  `CRYSTAL`, using bundled static normal frame one for Kanto #001-151.
  This never changes battles, animation, summaries, evolutions, trades,
  Hall-of-Fame screens, icons or followers. Johto and guest species retain
  their registered art.
- **CRYSTAL ANIMATION** — animate normal and shiny #001-251 fronts with their
  original Crystal timing; matching 2D player backs stay static.
- **SHINY HUNTS** — use Ascendant Charm/streak/outbreak bonuses or retain only
  natural 1/8192 DV shinies.
- **SHINY EFFECTS** — enable Kanto Ascendant's built-in sparkles, chime and
  markers when no dedicated indicator mod is active.
- **SHINY RELEASE LOCK** — prevent accidental release of shiny Pokémon from
  Bill's PC.
- **RED GYARADOS** — enable or skip the guaranteed Seafoam shiny event.
- **JOHTO TIME** — follow the system clock or force DAY/NIGHT for Eevee.
- **EARLY JOHTO** — after the physical Driftglass repair, enable or disable
  only the voluntary early migration encounters in the state-aware Signals
  hub. Before repair the row is locked and the generic options screen cannot
  activate it. Mythic Signals can still use the shared capsule, receiver and
  Driftglass researcher with Kanto First enforced.
- **VISIBLE JOHTO** — let the bundled living world's newly generated visible
  encounters use the active early-Johto current and researched habitat
  replacements. Turning it off keeps visible encounters Kanto-only without
  disabling Johto in classic grass battles.
- **MYTHIC SIGNALS** — enable or disable the Mew/Celebi echo and Resonance
  Seal path independently.
- Individual encounter rules for all ten post-game legends plus Mew.
- **MEW** — enable or skip the final mythic investigation.
- **MEW PROFILE** — choose Ascendant Lv.100 or historical event Lv.5.
- **HERITAGE EVENTS** — use badge-gated Festival Cups, persistent Roaming
  Hunts, or disable all five non-Mew distributions.
- Individual switches for University Magikarp, Stamp Fearow, Flying Pikachu,
  Stamp Rapidash and Surfing Pikachu.
- **ROAMERS CAN FLEE** and **EVENT ROSETTE** — tune the roaming behavior and
  event marker independently.
- **ROCKET STORY** — enable or skip Rocket Resurgence.
- **GRAND TOURNAMENT** — legacy option name for enabling or skipping the
  Ascendant Battle Frontier.
- **NEW GAME+ RULES** — use rotating cycle rules, legacy No-Item rules only,
  or normal battle access.

The step clock, trainer recovery, growth, pending loot, circuit wins, roaming
routes and legendary progress are stored under
`save.modData.kanto_ascendant`. RC10 imports a recognizable legacy
`save.modData.trainer_rematch` bucket before migrations run and writes an
independent legacy shadow whenever the game is saved, so the supplied RC9
rollback can still read progress written by RC10. Base save structures remain
compatible if the mod is disabled.
The Dex style persists through the standard mod-options file; old profiles
without the key automatically use `ORIGINAL` and need no migration or restart.

## Achievements, titles and New Game Plus

The Crown Archive and Legacy Gallery now record **twenty-one** permanent titles,
including Rematch Legend, Crestbearer, Beast Tracker, Grand Champion, Rocket
Breaker, Myth Seeker, Johto Master, Factory Architect, Sea Champion and Kanto
Ascendant. Additional hidden journey milestones add their own titles.
Special titles also recognize a Crown victory without legendary party members
and major fights completed without a faint. Every unlocked title can be
selected for the Trainer Card in the Legacy Gallery.

Completing the Crown, all eight Leader missions, the Johto specimen tracks,
one Ascendant Frontier victory, Rocket Resurgence and the enabled Mew finale unlocks an
Ascendant Steward in the Hall of Fame. The Steward starts a double-confirmed
**Ascendant Cycle**:

- Master, Apex, Crown, circuit-research, Leader-mission and Rocket progress
  reset.
- Base-story progress, party Pokémon, inventory and captured legends remain.
- Johto specimens, eggs, permanent titles, tournament records and Event
  Archive claims remain.
- Every replayed Master, Apex, Crown and Rocket boss slot is raised to level
  100, independent of the selected rules preset.
- Boss teams use six adaptive order variants.
- **ROTATING** rules repeat across cycles: No Items, SET Style, Trio, then
  Kanto Purist. Every rotating rule also seals battle items.
- **NO ITEMS** retains the simpler legacy restriction; **NORMAL** removes
  extra restrictions but keeps the level-100 teams.
- Temporary SET style and party locks are restored after every battle without
  changing the player's saved preference or party condition.

A later cycle cannot be restarted until its circuits, research, Leader
missions, Rocket story and one new tournament bracket are completed.

### True Legacy Journeys

Legacy Journeys can begin a genuinely fresh adventure while preserving only
the deliberately archived legacy. Their character-specific discoveries and
rewards are intentionally left unspoiled here.

<details>
<summary><strong>⚠️ FULL SPOILERS — Legacy Journey mechanics and rewards</strong></summary>

The 6.5 Legacy Journey starts a genuinely fresh game directly after the
previous journey's finale while keeping only the deliberately archived
legacy. The chosen RED, BLUE or GREEN avatar binds that journey to a distinct
combat, research or nature path. Each completed path awards a permanent seal;
the active path stage itself resets for every fresh journey.
Completing all three paths unlocks the Oak's Lab finale and the permanent
Legacy Pass. Seals and the Pass are displayed in the Legacy Gallery.

Only during an active Legacy Journey, Oak's next Red/Blue-edition partner
scene gives the three physical balls fixed roles. The left ball contains the
current hero's Hoenn partner (RED → Torchic, BLUE → Mudkip, GREEN → Treecko),
but only after that hero's matching rift seal was earned in an earlier
Legacy life. Before the unlock it remains visible and Oak gives a
story-specific "perhaps next life" hint; seals never cross-unlock another
hero's gift. The middle ball opens a graphical
Pokédex-style catalogue: Balanced is a curated early/lower-power pool and Free
contains exactly the 129 lowest-stage or standalone canonical species within
#001-251. If a baby stage exists in that range, it replaces its evolution (so
Pichu is offered, not Pikachu); Gastly and Ditto remain legal, while Gengar and
Dragonite do not. The rival claims and hides the right ball
first; its real species line is resolved only after the player's double-
confirmed choice. Only the received partner is added to the otherwise fresh
Pokédex. The complete player/rival decision is written once and mirrored into
the Legacy archive without duplication. Yellow retains its authored Pikachu
staging and offers the same catalogue as the alternative choice.

The canonical Hoenn starter families #252-260 are registered solely for this
character-bound, matching-seal left-ball reward and never enter wild encounter
tables. No Sinnoh starter is offered.

Johto visibility follows one shared Driftglass receiver contract in grass,
water, caves, towns and the bundled visible-Wilds layer. KANTO FIRST exposes
none; WANDERWAVES exposes only the active wave at its authored routes and
native 2/4-percent replacement rate; JOHTO UNLEASHED exposes every authored
ordinary base, including the three starters and Larvitar, at the native
10-percent replacement rate. The visible layer still creates exactly the
same number of entities as the native map roll. Legendary and mythical
species remain absent from generic pools and become visible only through
their own active event.

A separate Package-3 compatibility catalogue reserves private Dex slots
#261-279 for exactly seventeen later evolutions of existing Kanto/Johto lines
plus Azurill and Wynaut. It is loaded after the earned Hoenn starter module,
uses HGSS level-up data filtered against moves the engine actually provides,
and does not unlock a Sinnoh Pokédex or place any of those species into a
generic wild pool. Their eventual habitats and evolution relic rewards remain
explicit downstream hooks rather than automatic RC23 content.

Crystal presentation uses identity-correct authored front loops for all 28
private catalogue species: 21 from Nuuk's supplied Crystal packs and the
remaining seven exact identities from the pinned Polished Crystal source.
These normal/shiny fronts animate in enemy battles, Title, Pokédex, Summary
(including Box `STATS`) and Hall of Fame. Supplied rear cards contain one pose
and stay static; no artificial jitter is used. Followers, visible Wilds and
Voxel keep the actual walking/pose animation owned by their respective
renderers.

#### Legacy Wanderers: separate cadence and rewards

Legacy Wanderers exist only in an active true Legacy Journey (cycle 2 or
later). They do not use `REMATCH BREAK`, field-rematch loot or the ordinary
trainer state. Only eligible steps on Kanto routes and outdoor town/city maps
count; interiors, caves, Safari and HEVO maps do not. There is no per-step
spawn roll. Once due, the transaction waits for a safe eligible field state.

The setting lives at `START → ASCENDANT → OPTIONS → GAMEPLAY → LEGACY NG+`.
New Legacy journeys default to `RARE`; explicit saved choices are preserved.

| Frequency | Earliest eligible steps | Normal map-change target | Hard due |
|---|---:|---:|---:|
| RARE | 600 | 4-6 | 5000 steps, or 7 map changes after the floor |
| NORMAL | 200 | 2-3 | 1800 steps, or 4 map changes after the floor |
| OFTEN | 200 | 1-2 | 900 steps, or 3 map changes after the floor |
| NEVER | Disabled | - | Already reserved rewards still deliver |

After a win, a same-map encore has a 3% / 10% / 20% chance on RARE / NORMAL /
OFTEN and becomes due after 240-480 eligible steps. At most two Wanderers can
be won on one map; afterward three genuine outdoor map changes are required.
A loss grants no reward, restores the player's pre-battle money, adds one of
three relief levels and schedules a new three-map cycle. A later win removes
one relief level.

Each win reserves exactly one reward token. Resolution order is a registered
Master Ball at **1/32**, then a still-missing EXP Share at **1/4**, then the
next missing EXP Multiplier stage (x2 **1/6**, x3 **1/12**, x5 **1/24**), then
the ordinary Wanderer pool. These are conditional priority checks, not slices
of one flat table.

Before Beyond Kanto, the ordinary pool is Poké Ball stacks (12 weight), Great
Ball stacks (12), Ultra Ball stacks (9) and Safari Ball (1), total 34. After
Beyond Kanto it also contains all seven Apricorn Balls at 5 weight each and
twenty live, teachable Generation-II/III TMs at 1 each. The current ordinary
pool total is 89. Those TMs are Toxic, Ice Beam, Blizzard, Hyper Beam,
SolarBeam, Iron Tail, Thunderbolt, Thunder, Earthquake, Dig, Psychic, Double
Team, Reflect, Fire Blast, Swift, Dream Eater, Rest, Frenzy Plant, Blast Burn
and Hydro Cannon. Invalid, placeholder, incompatible and HM records are
excluded. Wanderer placement is always `Bag -> PC -> pending`, and its token
ledger prevents duplicate delivery.

</details>

## Installation

> [!NOTE]
> **Release package convention:** every playable release is published as a
> launcher-compatible `.zip`. A matching `.modpkg` may be retained only as an
> internal build or verification artifact.

1. Download `kanto_ascendant-6.5.15.zip` from the
   [6.5.15 release](https://github.com/Roxas2712/kanto-ascendant/releases/tag/v6.5.15)
   and import it through the launcher. Developers may alternatively install
   the checked-out mod directory.
   If you downloaded a complete bundle, extract it first and import the inner
   Ascendant ZIP; the outer bundle is a transport archive and deliberately has
   no root `manifest.json`.
2. Restart the game and enable **Kanto Ascendant**.
3. Existing saves work. Old trainer wins receive one initial rest period, and
   existing Pokédex ownership is imported into legendary progression.

This expansion registers Pokédex entries 152-251 plus the separate guest
entry 1026 for Gorochu. A second full-Johto species mod should not be enabled
at the same time. Existing Kanto Ascendant saves are safe: the six previously
added legends keep their string species IDs, so captured Pokémon and
progression survive the switch to canonical dex numbers.

## Credits

- **Kanto Ascendant:** Roxas2712
- **Original Trainer Rematch foundation:** ShaneMcGovernIE
- **Original all-catchable encounter inspiration:** Wowabox (Darklinkduck)
- **Engine and mod interfaces:** Pokémon Gen 1 Recompilation Project

## Development

Run the ROM-free headless suite from the Gen1 Recomp engine checkout:

```sh
export POKEPORT_DATA_DIR=tests/fixture_data
export TRAINER_REMATCH_MOD_DIR=../kanto-ascendant
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/trainer_rematch_test.lua
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/gorochu_visuals_test.lua
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/gorochu_audio_matrix_test.lua
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/field_economy_test.lua
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/atlas_legacy_test.lua
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/reachability_test.lua
env -u POKEPORT_DATA_DIR ./.tools/luajit-src/src/luajit \
  ../kanto-ascendant/tests/recruitment_full_data_test.lua
./.tools/luajit-src/src/luajit ../kanto-ascendant/tests/upgrade_matrix_test.lua
```

Run the standalone Signals gates from the mod checkout:

```sh
../gen1recomp/.tools/luajit-src/src/luajit tests/johto_signals_test.lua
../gen1recomp/.tools/luajit-src/src/luajit tests/johto_signals_content_test.lua
../gen1recomp/.tools/luajit-src/src/luajit tests/johto_signals_hub_test.lua
../gen1recomp/.tools/luajit-src/src/luajit tests/johto_signals_dialogue_test.lua
../gen1recomp/.tools/luajit-src/src/luajit tests/johto_signals_wilds_test.lua
../gen1recomp/.tools/luajit-src/src/luajit \
  tests/wilds_1_7_1_compat_test.lua
../gen1recomp/.tools/luajit-src/src/luajit \
  tests/johto_signals_ui_integration_test.lua
python3 tests/johto_signals_scope_audit_test.py
python3 tools/johto_signals_release_audit.py .
```

The map-collision and Mythic battle suites run from the engine checkout with
`KANTO_SIGNALS_MOD_DIR` and `TRAINER_REMATCH_MOD_DIR` pointed at this mod.
GitHub CI runs both contracts and repeats the release-boundary audit against
the exact RC10 package.

The upgrade matrix includes separate schema-derived Kanto Ascendant 5.3
fixtures for Red, Blue and Yellow. They pin the public 5.3 package hash and
exercise pre/post-Hall-of-Fame Signals initialization, legacy-event and
Mew/Celebi reconciliation, native save serialization, restart and mod off/on.
They are sanitized test buckets rather than published player saves. Original
full-save UAT sources remain separately identified and are never inferred
from those fixtures.

Validate against an imported Kanto data set:

```sh
MODKIT_LUAJIT="$PWD/.tools/luajit-src/src/luajit" \
python3 tools/modkit.py validate ../kanto-ascendant --base imported
```

`tools/make_postgame_assets.py` deterministically regenerates all 18 original
four-shade post-game sprite assets. `tools/install_crystal_sprites.py` validates
or refreshes the bundled 400 normal/shiny Crystal front/back views.
`tools/install_crystal_animations.py` refreshes the bundled normal/shiny
Crystal animation frames for #001-251 and their exact timing table.
`tools/install_gen2_followers.py` refreshes the bundled normal/shiny
100-species Gen-2-style walking pack. `tools/shiny_qa_driver.lua`
captures the 2D follower, voxel follower and voxel battle paths.
`tools/crystal_animation_qa_driver.lua` exercises standalone Kanto, Johto,
Voxel and mixed external-Kanto/Ascendant-Johto paths in a real LÖVE client.
`tools/dex_sprite_qa_driver.lua` runs the complete ORIGINAL/CRYSTAL and
KANTO-CRYSTAL-ART independence matrix against Red, Blue or Yellow and captures
Kanto/Johto entry pages. `tools/summary_sprite_qa_driver.lua` verifies and
captures the same independent static selection in the party status screen.
`tools/red_gyarados_qa_driver.lua` performs the recurring event encounter in
2D and Dramatic Shape/Voxel, catches it and verifies that it stops recurring.
`tools/gorochu_qa_driver.lua` performs the real Raichu evolution, validates
normal/shiny front and back art, and captures Gorochu's follower plus all
seven normal/shiny partner expressions without covering the emotion bubble.
`tools/gorochu_voxel_qa_driver.lua` verifies Gorochu's six authored 96×96
normal/shiny Voxel front frames, dedicated rear masters, smooth Dex/status
cards and all six follower poses. The Crystal pixel-art route stays separate.
`tools/gorochu_dialogue_qa_driver.lua` captures the complete English/German
Raichu and Gorochu conversation matrix. The headless audio matrix verifies
Yellow's spoken cry, Red/Blue's chip fallback and external-owner priority.
`tools/mega_crystal_qa_driver.lua` performs real battle transformations in
2D and Voxel layouts and verifies Mega ownership with bundled or external
Crystal art. `tools/install_all_mega_sprites.py` installs all 30 approved
96×96 front/back/normal/shiny masters and their side-aware integer-pixel
animation loops. `tools/build_ascendant_typhlosion.py` merges the approved
Ascendant Typhlosion form with Crystal #157's authentic front animation and
generates its separate back loop. `tools/build_breeding_data.py`
refreshes the offline 251-entry egg-group, gender-ratio and hatch-cycle table
used at runtime.

The complete reusable form-art, animation, 2D HUD, Voxel, fallback and QA
checklist is preserved in [`docs/MEGA_FORM_PIPELINE.md`](docs/MEGA_FORM_PIPELINE.md).
The focused 6.0 flow, save contract and UAT matrix are recorded in
[`docs/JOHTO_SIGNALS_6_SCOPE_AND_UAT.md`](docs/JOHTO_SIGNALS_6_SCOPE_AND_UAT.md).
