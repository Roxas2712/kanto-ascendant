# Changelog

All notable changes to this project are documented in this file.

## [5.1.1] - 2026-08-03

### Added

- Bundled authentic normal and shiny Pokémon Crystal front animations for
  Kanto #001-151. Together with the Johto pack, Ascendant now supplies all
  #001-251 without requiring a separate visual mod.
- A `KANTO CRYSTAL ART` option that restores original Gen-I fronts at any
  time while leaving the Johto art choice independent.
- Standalone Kanto 2D QA alongside the existing Johto, Voxel and mixed-mod
  animation scenes.
- Dedicated normal and shiny 56×56 pixel animations plus static player backs
  for Mega Charizard X, adapted from BLaDoM's recognizable Gen-V-style work.

### Changed

- Crystal Animated Sprites with Shiny Visuals is optional. When installed it
  automatically keeps ownership of #001-151, avoiding competing animation
  states, duplicate shiny effects or sounds.
- `CRYSTAL ANIMATION` now controls all bundled #001-251 front animations.
  Original 2D player backs remain static and Dramatic Shape still receives
  the front-facing normal or shiny frame.
- Mega Charizard X keeps its own detailed animation in both 2D and Voxel
  battles, even when an external full-roster sprite mod is active.

## [5.1.0] - 2026-08-03

### Added

- Authentic normal and shiny Pokémon Crystal front animations for all 100
  Johto species. The complete numbered-frame pack and original GIF timing are
  bundled; no separate download is required.
- A `CRYSTAL ANIMATION` option under Kanto Ascendant. Ordinary 2D battles
  animate the opponent while retaining the player's authentic Crystal back;
  Dramatic Shape's staged Voxel battles animate both front-facing Pokémon.
- First-class coexistence with **Crystal Animated Sprites with Shiny
  Visuals**. That mod owns Kanto #001-151 while Ascendant supplies Johto
  #152-251, including shiny artwork and presentation.
- A real-LÖVE compatibility driver covering 2D, Voxel and a mixed
  externally-animated Kanto versus Ascendant-animated Johto battle.

### Changed

- Official Mega art now resolves outside lower-priority full-species sprite
  replacements, so Mega Evolution cannot be hidden by the Crystal mod.
- Kanto Ascendant suppresses duplicate shiny sparkles and chimes only for the
  Kanto species the external Crystal mod actually supports. Johto keeps
  Ascendant's effects and Shiny Dex presentation.
- A visual mod that explicitly replaces a Johto sprite keeps ownership of
  that species; the bundled animation remains the safe default and fallback.

### Fixed

- Crystal Animated Sprites and Dramatic Shape can now run together with Kanto
  Ascendant without Totodile-through-Celebi falling back to unrelated Kanto
  battle art.
- Normal 2D player backs remain static, while Dramatic Shape's intentional
  back-to-front substitution receives the matching normal or shiny animation.

## [5.0.2] - 2026-08-03

### Added

- All 400 normal/shiny Pokémon Crystal front/back sprites for the 100 Johto
  species are now bundled directly with ZIP and MODPKG releases.
- All 198 normal/shiny PokeWilds six-pose sheets for the 99 standard Johto
  followers are bundled; Unown continues to derive its matching walking art
  from the included Crystal sprite.

### Changed

- `JOHTO ART` now identifies Crystal art as bundled instead of local.
- The sprite installer scripts remain available as repair/refresh tools.

### Fixed

- Fresh launcher installations no longer show related Kanto fallback species
  such as Squirtle for Totodile when the external sprite installers were not
  run.

## [5.0.1] - 2026-08-03

### Added

- A one-time bilingual 5.0 onboarding for every new or upgraded Hall-of-Fame
  save. Oak introduces the Ascendant menu, Route 5, Elm's research and the
  new Indigo, Vermilion and Celadon facilities.
- One authoritative next-objective tracker shared by the Journal and Research
  Atlas, with a localized location, exact progress and separate optional
  prestige records for the Battle Factory and S.S. Anne.
- Visible `NEW` / `NEU` markers when another Ascendant utility becomes
  available.
- A 1,086-check upgrade matrix based on the public 1.1.0 and 2.0.0 schemas
  plus real 3.1.0 and 4.1.1 launcher saves. It covers Red, Blue and Yellow in
  English and German, restart, mod-disable and re-enable paths.

### Changed

- Gold is now the mandatory final main battle before KANTO ASCENDANT and the
  first or any later New Game Plus cycle can begin. Battle Factory and S.S.
  Anne clears remain optional prestige challenges.
- Unknown Legacy Gallery trophies display only `???` until completed.
- Atlas locations use authored English/German names, and known Pokémon now
  show their evolution method without revealing an unseen target.

### Fixed

- Disabled Johto research or Frontier options no longer leave an impossible
  New Game Plus requirement.
- The TM FIFO, Johto research, trainer growth, titles, shinies, Gold clears
  and base player data survive all covered historical upgrade paths.

## [5.0.0] - 2026-08-03

### Added

- A spoiler-safe Research Atlas under `ASCENDANT` with Oak's current
  objective, recorded trainer locations/ranks/exact cooldowns, authoritative
  reward bands and gates, TM queue status and habitats only for species
  already seen or caught.
- Permanent thematic Kanto habitats for 44 researched Johto base species.
  Each relevant habitat keeps a 2% total replacement chance and unlocks only
  after its specimen, starter trial or Larvitar finale has been recorded.
- Individual English/German Pokédex entries, classifications, canonical
  height/weight data, explicit Crystal-shaped level plans and varied legal
  TM/HM profiles for all 100 Johto species.
- A Route 5 Move Reminder for legal level-up moves, moves previously forgotten
  through the machine, exact event-provenance moves and earned Crown starter
  signatures.
- A Frontier Exchange after the Crown Champion. Released evolution items are
  renewable for 6-10 Frontier Points and any individually archived TM can be
  selected again for 3 points.
- A level-100 Indigo Battle Factory: draft three of six changing,
  fully-evolved non-legendary rentals and clear three sealed-Bag battles for
  4 Frontier Points, or 6 without a faint.
- A five-battle level-100 S.S. Anne Grand Tour with healing after rounds two
  and four, 8 Frontier Points and a 4096-real-step departure timer.
- A Celadon Legacy Gallery with completion and challenge trophy displays,
  plus selection of any unlocked achievement as the active Trainer Card title.
- Factory Architect and Sea Champion, bringing the permanent title catalogue
  to seventeen.
- A standalone 251-species reachability/evolution-economy audit and pinned
  GitHub Actions regression workflow.

### Changed

- Training Rush now accelerates only defeated-trainer recovery and silent
  growth. Eggs, friendship, outbreaks, world events and S.S. Anne departures
  always count literal walked tiles.
- TM archive rewards use a persistent FIFO. A full Bag no longer pauses the
  win clock, later TMs queue behind earlier ones, and the exact oldest waiting
  reward is reported and delivered first.
- TM51-53 become permanent entitlements on the winning Crown battle even when
  the Bag is full.
- Rematch loot is determined only by the selected BALANCED or GENEROUS table.
  Trainer rank still affects presentation, team growth and AI but never adds
  hidden probability bands.
- Shiny outbreaks require the Hall of Fame and all three Johto starter trials.
  Larvitar cannot enter a migration before Elm's research finale.
- The content-patching `KANTO 151` option now warns that changing it requires a
  restart; its loaded mode is visible in the Journal.

### Fixed

- Battle Factory runs restore the exact original party on victory or defeat,
  block saving while a rental party is active, and repair stale interrupted
  saves from earlier builds on load instead of persisting temporary rentals.
- Factory rental and opponent-construction errors now roll back the exact
  original party immediately, clear the save veto and release the host.
- Factory and S.S. Anne clear dialogue reports the Frontier Points actually
  credited, including the active Frontier Festival multiplier.
- The first TM no longer counts as a completed archive cycle.
- Blocked TMs and blocked Crown signatures can no longer be lost, reordered or
  require repeating a boss battle.
- Evolution-item and archived-TM purchases are atomic: locked stock, a full
  Bag or insufficient points never consumes Frontier Points.
- Johto registration and habitat access never pre-fill `seen` or `owned`
  Pokédex flags.
- Seeing a research-gated Johto species on an opponent's team no longer
  advertises or activates its habitat before Elm records the specimen.
- Atlas habitats now distinguish caves, buildings and other interiors from
  grass, and label pool/species odds as base chances before temporary
  encounter overrides.
- Atlas odds use the Gen-1-font-safe `PCT`/`PROZ` labels instead of a missing
  percent glyph, with location and chance details split into readable pages.
- Selected Trainer Card titles survive New Game Plus, stale Grand Tour title
  flags self-heal, and localized titles are clipped by glyph rather than byte.

## [4.2.2] - 2026-08-03

### Added

- Renewable level-25 Eevee now replace 2% of Route 7 grass encounters after
  the first Hall of Fame, providing enough copies for all five Kanto/Johto
  branches without trading or relying on random end-game gifts.

### Changed

- EXP.ALL remains unique but now occupies a 5% band in both loot modes.
- Rare Candy now occupies 5% and Nugget 15% in both loot modes. Removed
  probability becomes no drop; no other reward band was increased.

### Fixed

- Johto branch registration now appends to the original evolution list
  instead of replacing it. Gloom retains Vileplume, Poliwhirl retains
  Poliwrath, Eevee retains Vaporeon/Jolteon/Flareon, and Slowpoke retains
  Slowbro while their Generation-II alternatives remain available.

## [4.2.1] - 2026-08-03

### Changed

- Field trainers and post-game bosses now draw each new recovery/training
  period from **151-2510 completed steps** by default.
- The two rest-step options now use the same thematic 151 minimum and 2510
  maximum, with single-step precision.
- Untouched 128/256 settings from older profiles migrate automatically, while
  genuinely customized ranges remain user-controlled.
- Active trainer timers that were created inside the old 1-256-step window
  are safely rerolled once into the expanded range on save load.
- Silent cycles still keep ready trainers available while raising their next
  team after every completed background period.
- The headless suite now covers 1619 checks.

## [4.2.0] - 2026-08-03

### Added

- A self-contained `KANTO 151` option with authored REWARDS, convenience WILD
  and OFF modes. A separate all-catchable mod is no longer required.
- Version-independent habitats for every former Red/Blue/Yellow exclusive,
  renewable Eevee and both Fighting Dojo prize species.
- Level evolutions for Kadabra, Graveler and Haunter at 42 and Machoke at 45.
- Renewable ¥2100 Moon Stones in Pewter Mart and Celadon Department Store 4F.
- Bulbasaur, Squirtle and Charmander prizes from Master Erika, Misty and
  Blaine, with party/PC-full reservation.
- The unchosen Dome or Helix Fossil as a Master Brock prize. Imported saves
  missing both can receive the other from Crown Brock, and full Bags reserve
  the fossil safely.
- A WILD alternative with rare starter, fossil, Aerodactyl and final trade
  evolution encounters.

### Changed

- Mew is explicitly removed from overlapping random encounter patches and
  remains exclusive to Kanto Ascendant's authored event.
- The rematch loot documentation now lists every base band, rank bonus, gate,
  full Legend distribution and true no-drop percentage.
- The headless suite now covers 1614 ROM-free checks plus imported-data Kanto
  encounter, evolution, shop and reward validation.

## [4.1.1] - 2026-08-03

### Changed

- The vanilla Start menu is tidy again: Journal, World Status, Johto Pokédex,
  Shiny Dex, Event Archive, Dex Certificates and Mega Stones now live behind
  one bilingual `ASCENDANT` submenu.
- Every nested entry keeps its original progression gate, and backing out of
  the Ascendant screen returns to the Start menu.
- The headless suite now covers 1610 checks, with German in-engine screenshots
  for both the cleaned Start menu and the fully unlocked submenu.

## [4.1.0] - 2026-08-03

### Added

- A permanent Field Kit awarded after the first won field rematch. It invokes
  CUT, FLY, SURF, STRENGTH and FLASH from the Bag without consuming a Pokémon
  move slot while preserving each original HM and Badge requirement.
- A guaranteed renewable TM archive after the Hall of Fame: every second won
  field rematch awards the next original TM, and all 50 appear before the
  archive cycles.
- A bilingual Move Deleter and TM Archive status page in the Route 5 Day-Care
  machine. HMs may be removed, but a Pokémon's final move is protected.
- TM51 Frenzy Plant / Flora-Statue from Crown Erika, TM52 Blast Burn /
  Lohekanonade from Crown Blaine and TM53 Hydro Cannon / Aquahaubitze from
  Crown Misty. Both matching Kanto and Johto starter families can learn them.

### Fixed

- Independent rematch rewards are now composed without a leading empty reward
  suppressing later Johto or shiny reward messages.
- The headless suite expanded to 1592 checks, plus an in-engine Bag, Field Kit,
  HM deletion, starter compatibility and renewable-TM QA route.

## [4.0.0] - 2026-08-03

### Added

- A repeatable Silver, Kris and Gold Johto Masters gauntlet after the Crown
  Champion. All three use changing six-Pokémon level-100 teams, maximum AI,
  automatic between-round healing and an unconditional battle-item lock.
- Gold awards exactly one uniformly random genuine-DV shiny from all 251
  Pokémon after every clear. Full parties use the PC; a completely full PC
  reserves the already-selected gift without rerolling it.
- The permanent KANTO ASCENDANT title and a golden Trainer Card treatment
  after the first Johto Masters clear.
- Four Pokédex certificates for #001-150, all 151 Kanto species, #001-250 and
  the complete #001-251 roster. Future certificate tiers remain hidden until
  the corresponding collection milestone has actually been reached.
- Four rotating 2048-step world events: Training Rush, Johto Migration,
  Golden Wind and Frontier Festival.
- A unified Start-menu Journal for legendary sightings, live roamer
  locations, titles, type masteries, world events and Johto Masters records.
- Per-species shiny encounter/capture records and optional protection from
  accidental PC release.

### Changed

- Johto and Shiny Pokédex lists now match the original Pokédex presentation:
  unseen entries remain `-----`, seen entries reveal their names and captured
  entries use the Poké Ball marker instead of pre-filled `OWN/HAT` text.
- The Grand Tournament is presented as the Ascendant Battle Frontier and now
  awards persistent Frontier Points, doubled during Frontier Festival.
- Crown Leader victories permanently register eight individual type
  masteries.
- Blue's adaptive boss roster now rotates strong Johto counter-picks as well
  as reacting to the player's dominant party type.
- The headless suite expanded from 1547 to 1574 checks.

## [3.2.0] - 2026-08-03

### Added

- A self-contained Generation-II shiny system for all 251 Pokémon. Shininess
  uses Crystal's real Defense/Speed/Special/Attack DV rule, so no proprietary
  save flag is required and existing virtual shinies migrate automatically.
- A bilingual 251-entry Shiny Dex with separate seen and caught records.
- The Shiny Charm is awarded after all 251 species are owned. It grants two
  additional 1/8192 rolls while Ascendant shiny hunting is enabled.
- Consecutive field-rematch wins add one, three or seven shiny rolls at
  streaks 10, 25 and 50. Every tenth victory also starts a deterministic
  2048-step Johto outbreak with a 25% species replacement rate and fifteen
  additional shiny rolls on its route.
- A guaranteed red Gyarados event in Seafoam Islands B4F after a 25-win
  post-Hall-of-Fame rematch streak. It persists until captured.
- Crystal-accurate egg DV inheritance. A compatible shiny donor can produce
  the authentic 1/64 shiny result; Crystal's matching Defense/Special-DV
  incompatibility rule is retained.
- Built-in battle sparkles, chime, battle marker and status-screen icon. An
  active `shiny_indicators` mod is detected automatically and becomes the
  sole effects provider, preventing doubled audio or animation.
- Official Crystal shiny front/back downloads for all 100 Johto species and
  PokeWilds shiny follower sheets for 99; Unown's follower is generated from
  its Crystal shiny front sprite.
- A scripted 2D/voxel QA driver for Shiny Feraligatr and Shiny Suicune.

### Changed

- The Crystal installer now validates and installs four views per Johto
  species: normal front/back plus shiny front/back.
- The follower bridge now resolves the selected individual, not merely its
  species, so normal and shiny copies of the same Pokémon use the right sheet.
- The same shiny follower art is shared by classic 2D and Dramatic Shape's
  voxel renderer.
- The headless suite expanded from 1525 to 1547 checks.

## [3.1.0] - 2026-08-02

### Added

- Route 5 is now a full two-parent Day-Care. Both deposited Pokémon gain one
  experience point per completed player step and retain the original
  ¥100-plus-¥100-per-level retrieval price.
- Canonical breeding data for National Pokédex entries 1-251: Generation-II
  egg groups, Attack-DV gender ratios, Ditto rules, baby-family resolution,
  species hatch cycles and unbreedable baby/legendary handling.
- Real party eggs. They occupy a party slot, cannot battle or be healed,
  count down only while carried and hatch into a level-5 Pokémon with Pokédex
  ownership and origin metadata.
- Elm's eight research eggs now wait at the Route 5 Day-Care and use the same
  party-egg system. Existing queued research eggs migrate automatically.
- A visible evolution machine inside the Day-Care. It handles every compatible
  item evolution and, after the Hall of Fame, forges the Mega Ring.
- A dedicated Mega Stone Case and 30 individual form-bound stones covering
  exactly the 27 species among #001-251 that officially have Mega Evolutions
  through July 2026. No invented Mega species are included.
- Once-per-battle Mega Evolution, activated with SELECT from the main battle
  menu. Every form has its own five-stat Kanto adaptation; HP and saved party
  stats never change.
- Optional enemy Mega Evolution for post-game bosses or all trainers.
- Four-shade original front/back sprites for Mega Raichu X and Mega Raichu Y.
  Other eligible species retain their normal sprite inside a visible Mega aura.
- A Route 5 form selector for Charizard X/Y, Mewtwo X/Y and Raichu X/Y once
  both matching stones are owned.

### Changed

- Crystal battle sprites now receive edge-connected transparency before use,
  preventing opaque 56x56 background cards in on-map voxel battles. Dramatic
  Shape's front-facing player-side choice is preserved instead of being
  overwritten with the Crystal back view.
- Optional species-accurate Gen-2-style follower sheets now cover all 100
  Johto Pokémon in both 2D and voxel rendering. A local installer downloads
  the PokeWilds art and Kanto silhouettes remain the safe per-species fallback.
- Elm's aide now reports research and egg status while directing item
  evolutions to the visible Route 5 machine.
- Classic stones unlock with the Mega Ring after the first Hall of Fame, new
  Z-A stones after all eight Master Leaders and Mewtwonite X/Y after the Apex
  Champion.
- The headless suite expanded from 1417 to 1525 checks.
- Johto party leaders now fall back to related, existing Kanto follower
  sheets when the optional all-species follower mod only ships Gen-1 art.
  This prevents missing-texture crashes in both 2D and voxel rendering.
- Raikou, Entei and Suicune now use the standard animated quadruped party
  icon; Lugia and Ho-Oh use the standard bird icon; Celebi uses the standard
  Mew-like fairy icon. The old single-frame thumbnails are no longer selected.

## [3.0.0] - 2026-08-02

### Added

- The complete canonical Johto Pokédex from Chikorita #152 through Celebi
  #251: 100 native species records, five-stat balancing, cries, learnsets,
  evolutions, Pokédex entries, icons and distributable sprite fallbacks.
- Dark and Steel types with the Generation-II matchup table. Magnemite and
  Magneton now use their Electric/Steel typing.
- Crunch, Metal Claw, Iron Tail, Shadow Ball, Flame Wheel, Giga Drain, Sludge
  Bomb, Spark and Powder Snow alongside Aeroblast and Sacred Fire.
- Three post-Hall-of-Fame starter trials in Celadon, Cinnabar and Cerulean.
  Each has three themed rounds and awards Chikorita, Cyndaquil or Totodile;
  all three can be earned in one save.
- Elm's persistent Kanto research programme in Oak's Lab. Once all starters
  are secured, every field-rematch victory awards one deterministic,
  class-themed, never-duplicate Johto family.
- Forty rematch specimen families, eight step-hatched baby eggs, fixed
  evolution-item milestones and Larvitar as the final research reward.
- Friendship, day/night Eevee and Tyrogue stat-branch evolution methods.
- Sun Stone, Metal Coat, King's Rock, Dragon Scale and Up-Grade, plus Elm's
  solo evolution machine.
- Eleven version-safe Kanto research partners, including two Eevee, so every
  Johto branch is obtainable in Red, Blue and Yellow.
- A bilingual 100-entry Johto Research Dex in the Start menu with owned/seen
  tracking, exact egg steps and full-PC prize reservation.
- Optional local Pokémon Crystal front/back sprites for all 100 Johto
  species. The installer now validates and downloads 200 views.

### Changed

- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi keep their save-stable
  species IDs but now use canonical Pokédex numbers 243-245 and 249-251.
- `LEGEND ART` is now the broader `JOHTO ART` option. Missing Crystal pairs
  fall back independently to built-in four-shade silhouettes.
- The headless suite expanded from 1202 to 1417 checks and an imported-data
  smoke test now validates the full 251-species merge.

## [2.1.0] - 2026-08-02

### Added

- Five badge-gated, three-round Heritage Cups awarding faithful Generation-I
  University Magikarp, Pokémon Stamp Fearow, Flying Pikachu, Pokémon Stamp
  Rapidash and Surfing Pikachu builds at their original levels.
- An alternative roaming mode with persistent map, DVs, HP and status,
  optional first-action escape, relocation and three-map knockout recovery.
- A permanent bilingual Event Archive in the Start menu, including source,
  level, original moves, claim status and full-PC prize reservation.
- Event provenance on each obtained Pokémon, an EVENT INFO party entry and an
  optional battle rosette.
- An Ascendant Lv.100 / historical Lv.5 Mew profile choice. Historical Mew
  keeps Pound and the fixed 5/10/1/12/5 event DVs.
- Grand Tournament catch-up prizes for enabled, missed Heritage events.
- SET-Style and Kanto Purist Grand Tournament rules.
- SET, Trio and Purist Ascendant Cycle rules with automatic post-battle
  restoration of the player's saved battle style, HP and status.

### Changed

- Ascendant Cycle Master, Apex, Crown and Rocket teams now always reach level
  100, even when NEW GAME+ RULES is set to NORMAL.
- Adaptive circuit order expanded from three to six deterministic variants.
- NEW GAME+ RULES now defaults to a four-cycle rotation: No Items, SET Style,
  Trio and Kanto Purist. The legacy No-Item-only and unrestricted NORMAL
  presets remain available.
- The Grand Tournament now rotates six rulesets instead of four.
- The headless suite expanded from 1162 to 1202 checks.

## [2.0.0] - 2026-08-02

### Added

- Five persistent trainer ranks: Rookie, Veteran, Expert, Master and Legend.
- Stronger AI, visible overworld markers and new BALANCED bonus-loot bands for
  high-rank field trainers.
- Eight sequential Ascendant research assignments with rare rewards and
  Bag-full reservation.
- Personal bilingual missions for all eight Gym Leaders.
- Leader signature roster variants, rotating boss orders and an adaptive
  Champion counter-pick.
- A repeatable three-round Kanto Grand Tournament with six level-100
  opponents and Open, No-Item, Trio and Endurance rules.
- A four-chapter Rocket Resurgence story across the Power Plant, Silph Co.,
  Pokémon Tower and Viridian Gym.
- Expanded Rocket/Mew world reactions and four one-time environmental scenes.
- A three-clue Oak, Mr. Fuji and Cinnabar investigation ending with a
  persistent level-100 Mew encounter on Route 24.
- A dedicated Mew option plus independent Rocket and Tournament switches;
  disabled systems are removed from completion requirements.
- Fourteen permanent achievements and titles in the Crown Archive.
- A double-confirmed, save-safe Ascendant New Game Plus cycle that preserves
  base-story progress, Pokémon, items, captured legends, titles and tournament
  records.

### Changed

- Master, Apex and Crown repeat battles now rotate team order.
- Completed Leader missions unlock signature roster variants.
- The Champion adapts one non-legendary counter-pick to the player's dominant
  party type.
- The Crown Archive now includes title, research, Tournament, Rocket, Mew and
  cycle records.
- The headless suite expanded from 1080 to 1162 checks.

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
