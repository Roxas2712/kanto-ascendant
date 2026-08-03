# Kanto Ascendant

Kanto Ascendant turns Kanto into a persistent training world and adds a full
Hall-of-Fame post-game: ranked field trainers, personal Leader missions,
adaptive circuits, the Ascendant Battle Frontier, Rocket Resurgence, a living legendary
event, five historical Heritage Cups, the complete 100-species Johto Pokédex,
Mew, a full Route 5 breeding Day-Care, Generation-II shinies, official Mega
Evolutions, the Silver/Kris/Gold Johto Masters trial, a Battle Factory,
repeatable S.S. Anne voyages, a spoiler-safe Research Atlas and a replayable
level-100 New Game Plus. The internal
`trainer_rematch` ID remains unchanged so existing saves and options continue
to work.

> [!IMPORTANT]
> **Development Preview:** Kanto Ascendant is in active development. More
> features, dialogue and polish will follow. Bug reports, balancing feedback
> and feature wishes are welcome in
> [GitHub Issues](https://github.com/Roxas2712/kanto-ascendant/issues) and will
> be considered for future updates.

Every rematch is fought for pride. Trainer prize money and Pay Day payouts are
disabled in all rematch, Master, Apex and Crown battles.

## Field trainer rematches

1. Beat a trainer.
2. They rest and train for **151-2510 completed player steps** by default.
3. Talk to them too early to see the exact number of steps remaining, followed
   by their normal post-battle dialogue as a second page.
4. Return when they are ready for a class-specific YES/NO challenge.
5. When first ready, their next rematch is +2 levels stronger. Each completed
   rematch adds another +2 until each Pokémon reaches level 100.
6. A ready trainer keeps training even when ignored. Another invisible
   151-2510-step cycle begins in the background; every completed silent cycle
   adds the same +2 growth tier to the next battle while the trainer remains
   continuously available.
7. At the default growth rate, reaching +4, +8, +12 and later strength tiers
   recruits another class-appropriate Pokémon until the party reaches six.
   The chosen evolutionary families stay deterministic for that trainer and
   evolve naturally when its projected rematch level is high enough.

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
sprite. Rank never changes item probability: the selected BALANCED or GENEROUS
table below is the complete and authoritative reward distribution.

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

### Rare rematch loot

Winning a field-trainer rematch can award an item instead of money. Each mode
uses fixed independent bands:

| Item | BALANCED / NORMAL | GENEROUS / VIEL | Additional requirement |
|---|---:|---:|---|
| Nugget | 15% | 15% | None |
| Rare Candy | 5% | 5% | Enemy team average level 20 |
| PP Up | 10% | 15% | Enemy team average level 35 |
| EXP.ALL / EP-Teiler | 5% | 5% | Average level 40; unique |
| Max Revive | 8% | 12% | Enemy team average level 50 |
| Master Ball | 1% | 2% | Average level 80 and Apex Champion defeated |

**OFF** disables loot. Only one band is rolled per victory. At full eligibility,
BALANCED has a 44% total item chance and GENEROUS has 54%. The removed
probability remains no drop instead of increasing another item's chance. An
ineligible result also becomes no drop rather than being rerolled.

At full eligibility, BALANCED is exactly **1% Master Ball, 5% EXP.ALL, 5%
Rare Candy, 10% PP Up, 8% Max Revive, 15% Nugget and 56% no drop**. GENEROUS
is exactly the percentages in the table and totals 54%, leaving 46% no drop.
Level, Apex and one-time EXP.ALL requirements still apply to their individual
bands in both modes. If a requirement is not met, that exact band is a no-drop
result rather than being rerolled.

The EP-Teiler is the original, fully functional Gen-1 `EXP_ALL`: while carried,
it distributes part of battle experience to the other non-fainted party
members. Once obtained as loot it leaves the table, and Oak's Aide will not
give a duplicate. Afterwards its old band becomes a no-drop result, reducing
the total chance to 39% in BALANCED or 49% in GENEROUS. The Master Ball remains
repeatable but is the rarest reward and cannot drop before the legendary hunt
has opened. Once eligible, it takes about 100 BALANCED or 50 GENEROUS wins on
average to see one; this is an average, not a guarantee.

If the Bag is full, the reward is never destroyed. That individual trainer
keeps it, reminds the player on the next conversation and hands it over as soon
as one Bag slot is available.

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

Mew is deliberately never inserted into a random encounter table. It remains
the finale of Kanto Ascendant's Oak/Fuji/Cinnabar heritage investigation, so
the 151st capture still feels like an event. The three birds and Mewtwo retain
their separate APEX/VANILLA/OFF controls.

If **All Pokémon Catchable 151 Mod** was previously enabled, it can now be
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
and German text. **LANGUAGE** defaults to `AUTO`:

- English is the standalone fallback.
- `deutsch`, `deutsch-blau` and `deutsch-gelb` are detected automatically for
  the matching Red, Blue or Yellow game version.
- `ENGLISH` and `DEUTSCH` force either language independently of installed
  translation mods.
- The normal trainer text appended after a cooldown comes from the base game,
  so it follows the active translation mod too.

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
player steps. **ASCENDANT → JOHTO POKéDEX** and Elm's aide both show persistent
progress; the aide reports whether an egg is waiting at Route 5 or its exact
remaining steps while carried. A full party never destroys a prize.

Generation-II evolution support includes:

- Dark and Steel types, including Electric/Steel Magnemite and Magneton.
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
and status icon. If `Gen II Shiny Indicators` is active, Kanto Ascendant
detects its export and lets that mod provide the presentation alone—there are
no doubled sparkles or sounds. The hunt logic, Dex, breeding, Johto art,
followers and event remain owned by Kanto Ascendant, so the separate visual
mod can later be disabled without losing progression.

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

After defeating Kanto's Crown Champion, a second Indigo host opens the final
**Johto Masters Trial**:

1. Silver uses a rotating aggressive pool.
2. Kris uses a rotating strategic pool.
3. Gold uses a rotating Champion and legendary pool.

All opponents use full level-100 teams, maximum battle AI and a sealed Bag.
The player's team is fully healed before every round, but the three opponents
must be cleared in sequence. Each Master owns twelve candidates and selects a
different set and order for every attempt.

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

Pikachu and every other species without an official Mega Evolution are
explicitly rejected in battle. There is no mod-invented Ascendant Mega form.

The Route 5 machine forges every stone individually:

- Classic non-Mewtwo stones unlock with the Ring after the first Hall of Fame
  and normally cost ¥5,000. Charizardite X/Y cost ¥7,500 each.
- The newly discovered Z-A stones and Raichunite X/Y unlock after all eight
  Master Leaders and cost ¥10,000 each.
- Mewtwonite X/Y unlock after the Apex Champion and cost ¥15,000 each.
- **ASCENDANT → MEGA STONES** shows the complete Stone Case and live
  `OWN`, price or `LOCK` status.
- When both stones are owned, the Route 5 form menu selects Charizard X/Y,
  Mewtwo X/Y or Raichu X/Y.

Every form uses a +100-point Kanto adaptation across the four non-HP Gen-1
stats, accounting for the fact that later games split Special Attack and
Special Defense. Type changes supported by Kanto Ascendant are applied in battle.
Mega Raichu X/Y have dedicated original four-shade front/back sprites. Mega
Charizard X has dedicated normal and shiny four-color front animations plus
static player backs in the same 56×56 Crystal-style format. Other forms use
their normal Gen-1 sprite with a Mega aura.

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

Mew remains the unique mythic finale rather than a second roaming copy.
**MEW PROFILE** chooses the Ascendant level-100 encounter or a historical
level-5 Nintendo Space World '99 build with Pound and fixed
HP/Attack/Defense/Speed/Special DVs of 5/10/1/12/5. Turning **MEW** off still
skips the encounter and its completion requirement entirely.

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
Ho-Oh, and the small `SPRITE_FAIRY` silhouette for Celebi.

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
- Dark and Steel typing
- Crunch, Metal Claw, Iron Tail, Shadow Ball, Flame Wheel, Giga Drain,
  Sludge Bomb, Spark, Powder Snow, Aeroblast and Sacred Fire

Every new species has base stats, typing, learnset, TM compatibility, a
self-contained chip cry, Pokédex data and a four-shade Kanto fallback. The six
story legends retain their authored front/back pixel art. Their party-menu
icons use the game's standard animated silhouettes: quadruped for the three
beasts, bird for Lugia and Ho-Oh, and the Mew-like fairy icon for Celebi.

### Bundled Crystal battle art

Authentic normal and shiny Pokémon Crystal front/back sprites for **all 100
Johto Pokémon** are included in the release. No separate download is needed.
The repair utility can validate and refresh the complete 400-PNG set:

```sh
python3 tools/install_crystal_sprites.py
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
the first 151 between bundled Crystal fronts and the original Gen-I art;
**CRYSTAL ANIMATION** controls motion. In the original 2D battle layout the
opponent animates and the player's authentic back remains static. In Dramatic
Shape's staged Voxel battles both front-facing Pokémon animate.

The external mod is now optional. Kanto Ascendant can still be enabled beside
[Crystal Animated Sprites with Shiny Visuals](https://github.com/distilledorion-sketch/crystal_animated_sprites_with_shiny_visuals).
When detected, that visual mod keeps ownership of Kanto #001-151 while
Ascendant supplies Johto. For Dramatic Shape, use
[LOW-K3YS's Voxel-compatible fork](https://github.com/LOW-K3YS/crystal_animated_sprites_with_shiny_visuals).
Duplicate Kanto sparkle/chime presentation is suppressed automatically, while
Johto shinies retain Ascendant's own effects. Mega forms always keep their
official form sprite.

Unown is the sole static exception because Crystal stores its separate letter
forms rather than a generic animated #201 sheet; the included form-A Crystal
art remains authentic.

### Follower and voxel compatibility

Species-accurate normal and shiny 16x16 Gen-2-style walking sprites are also
bundled for every Johto Pokémon. The repair utility can refresh them:

```sh
python3 tools/install_gen2_followers.py
```

The package contains normal and shiny six-pose PokeWilds sheets for 99
species; Unown is built from its matching Crystal front sprite. They are
converted on first use to Gen1 Recomp's exact down/up/side walking layout.
The selected individual determines whether the normal or shiny sheet is used.
Both the normal 2D renderer and Dramatic Shape's voxel renderer consume the
same converted sheet. The source project and individual sprite contributors
are credited in the [PokeWilds project](https://github.com/SheerSt/pokewilds).

If an individual sheet is damaged or missing, the related Kanto silhouette
remains as a crash-safe fallback until the package is repaired.

## Options

Open **MODS → KANTO ASCENDANT → OPTIONS** for the mod's own configuration
submenu. It contains:

- **LANGUAGE** — automatically follow a compatible German translation, or
  force English/German.
- **MIN REST STEPS** — lower end of the training period (default and minimum
  151).
- **MAX REST STEPS** — upper end (default and maximum 2510). Reversed values
  are normalized.
- **LEVELS / REMATCH** — field-trainer strength gained per completed rematch
  or silent training cycle (default 2; set to 0 to disable level scaling).
- **TEAM GROWTH** — allow thematic party recruitment as trainers gain
  strength tiers (default on).
- **REMATCH LOOT** — `OFF`, `BALANCED` or the more rewarding `GENEROUS`
  rare-item table.
- **JOHTO ART** — use the bundled Crystal battle art for all 100 species or
  force the four-shade Kanto fallback.
- **KANTO CRYSTAL ART** — use bundled normal/shiny Crystal fronts for #001-151
  without requiring a separate sprite mod.
- **CRYSTAL ANIMATION** — animate normal and shiny #001-251 fronts with their
  original Crystal timing; 2D player backs stay static.
- **SHINY HUNTS** — use Ascendant Charm/streak/outbreak bonuses or retain only
  natural 1/8192 DV shinies.
- **SHINY EFFECTS** — enable Kanto Ascendant's built-in sparkles, chime and
  markers when no dedicated indicator mod is active.
- **SHINY RELEASE LOCK** — prevent accidental release of shiny Pokémon from
  Bill's PC.
- **RED GYARADOS** — enable or skip the guaranteed Seafoam shiny event.
- **JOHTO TIME** — follow the system clock or force DAY/NIGHT for Eevee.
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
routes and legendary progress are stored under `save.modData.trainer_rematch`.
Base save structures remain compatible if the mod is disabled.

## Achievements, titles and New Game Plus

The Crown Archive and Legacy Gallery now record **seventeen** permanent titles,
including Rematch Legend, Crestbearer, Beast Tracker, Grand Champion, Rocket
Breaker, Myth Seeker, Johto Master, Factory Architect, Sea Champion and Kanto
Ascendant. Special titles also recognize a Crown victory without legendary
party members and major fights completed without a faint. Every unlocked title
can be selected for the Trainer Card in the Legacy Gallery.

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

## Installation

1. Download `kanto-ascendant-5.1.1.zip` from the
   [latest release](https://github.com/Roxas2712/kanto-ascendant/releases/latest)
   and import it through the launcher. The identical `.modpkg` is also
   available for launcher versions that use that extension. Developers may
   alternatively install the checked-out mod directory.
2. Restart the game and enable **Kanto Ascendant**.
3. Existing saves work. Old trainer wins receive one initial rest period, and
   existing Pokédex ownership is imported into legendary progression.

This expansion registers Pokédex entries 152-251. A second full-Johto species
mod should not be enabled at the same time. Existing Kanto Ascendant saves are
safe: the six previously added legends keep their string species IDs, so
captured Pokémon and progression survive the switch to canonical dex numbers.

## Credits

- **Kanto Ascendant:** Roxas2712
- **Original Trainer Rematch foundation:** ShaneMcGovernIE
- **Original all-catchable encounter inspiration:** Wowabox (Darklinkduck)
- **Engine and mod interfaces:** Pokémon Gen 1 Recompilation Project

## Development

Run the ROM-free headless suite from the Gen1 Recomp engine checkout:

```sh
export POKEPORT_DATA_DIR=tests/fixture_data
export TRAINER_REMATCH_MOD_DIR=../trainer_rematch
./.tools/luajit-src/src/luajit ../trainer_rematch/tests/trainer_rematch_test.lua
./.tools/luajit-src/src/luajit ../trainer_rematch/tests/field_economy_test.lua
./.tools/luajit-src/src/luajit ../trainer_rematch/tests/atlas_legacy_test.lua
./.tools/luajit-src/src/luajit ../trainer_rematch/tests/reachability_test.lua
./.tools/luajit-src/src/luajit ../trainer_rematch/tests/upgrade_matrix_test.lua
```

Validate against an imported Kanto data set:

```sh
MODKIT_LUAJIT="$PWD/.tools/luajit-src/src/luajit" \
python3 tools/modkit.py validate ../trainer_rematch --base imported
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
`tools/mega_crystal_qa_driver.lua` performs real battle transformations for
Mega Raichu X/Y and Mega Charizard X, including the latter's normal/shiny
front animation, and verifies ownership with bundled or external Crystal art.
`tools/install_mega_crystal_animations.py` deterministically rebuilds Mega
Charizard X as 56×56 four-color normal/shiny animation frames and static
backs from the credited pixel-animation source.
`tools/make_mega_assets.py` regenerates the four
original four-shade Mega Raichu battle sprites. `tools/build_breeding_data.py`
refreshes the offline 251-entry egg-group, gender-ratio and hatch-cycle table
used at runtime.
