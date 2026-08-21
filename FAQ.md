# Kanto Ascendant FAQ and Spoiler Guide

This is the public reference for **Kanto Ascendant 6.5.8**. It applies to Red,
Blue and Yellow and is maintained from the current mod code, release
documentation and confirmed support reports.

> [!WARNING]
> **Every gameplay FAQ entry may contain spoilers.** Those answers are collapsed
> by default and every gameplay dropdown carries its own spoiler warning.
> Open only the question you want answered. Entries labelled **full spoiler**
> reveal exact locations, requirements or progression. The support-report status
> at the end is spoiler-free.

- [Installation and compatibility](#installation-and-compatibility)
- [Main story, rematches and Kanto 151](#main-story-rematches-and-kanto-151)
- [Johto Signals and Mythic Signals](#johto-signals-and-mythic-signals)
- [Johto research, breeding and items](#johto-research-breeding-and-items)
- [Shinies, outbreaks and the red Gyarados](#shinies-outbreaks-and-the-red-gyarados)
- [Mega Evolution, Yellow's partner and Gorochu](#mega-evolution-yellows-partner-and-gorochu)
- [Hidden Evolution fissures and the three hero trials](#hidden-evolution-fissures-and-the-three-hero-trials)
- [Heritage events and the Event Archive](#heritage-events-and-the-event-archive)
- [Post-game, legends and facilities](#post-game-legends-and-facilities)
- [Menus, art, followers and troubleshooting](#menus-art-followers-and-troubleshooting)
- [Current support-report status](#current-support-report-status)

## Installation and compatibility

<details>
<summary><strong>⚠️ SPOILER — What is Kanto Ascendant?</strong></summary>

Kanto Ascendant is a gameplay and content mod for Pokémon Gen 1 Recomp. It is
not a ROM hack and does not contain a Pokémon ROM. Gen 1 Recomp imports the
player's Red, Blue or Yellow data; Ascendant then adds persistent rematches,
all 251 Kanto/Johto species, optional early Johto and Mythic Signals,
breeding, shinies, Mega Evolution, Gorochu and a large Hall-of-Fame post-game.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do I install or update it?</strong></summary>

1. Download the release `.zip` from the
   [6.5.8 GitHub release](https://github.com/Roxas2712/kanto-ascendant/releases/tag/v6.5.8).
2. Import it through the Gen 1 Recomp launcher.
3. Use Gen 1 Recomp **0.1.90** or newer. Disable every package the manager reports as a
   conflict, then enable **Kanto Ascendant** and restart.

Existing Red, Blue and Yellow saves are supported. Do not replace or delete
your save file when updating.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do I move from RC9's trainer_rematch ID to RC10?</strong></summary>

RC9 and older Kanto Ascendant builds accidentally used `trainer_rematch`, the
same ID as the standalone Trainer Rematch mod. RC10 corrects Kanto Ascendant's
ID to `kanto_ascendant` and explicitly conflicts with `trainer_rematch`.

Close the launcher and find its actual `mods` directory:

- Portable mode: the `mods` folder beside the game executable
- Windows standard mode: `%APPDATA%\LOVE\pokemon-love2d\mods`
- macOS: `~/Library/Application Support/LOVE/pokemon-love2d/mods`
- Linux/SteamOS: `~/.local/share/love/pokemon-love2d/mods`

Move the old Kanto Ascendant `trainer_rematch` folder **out of the `mods`
directory**, restart the launcher, import RC10, enable **Kanto Ascendant** and
restart once more. Merely renaming the folder while leaving it inside `mods`
still exposes the old manifest ID. Do not touch `save.lua`, save slots or
backups: RC10 recognizes the old Kanto data, imports it into
`kanto_ascendant`, and keeps an RC9-compatible rollback shadow.

Do not enable the standalone Trainer Rematch mod beside Kanto Ascendant.
Ascendant already includes and extends that gameplay, so running both would
double-own the same trainer interaction hooks.

Portable Windows handhelds, including an ROG Ally, may use the folder beside
the executable instead of `%APPDATA%`. If neither documented location exists,
that is launcher/operating-system support rather than an Ascendant gameplay
defect.

</details>

<details>
<summary><strong>⚠️ SPOILER — Which other mods are compatible?</strong></summary>

Kanto Ascendant includes its own Gen-I Randomizer and works completely in 2D
without a renderer mod. It is designed to coexist with the German language
packages or one official renderer in these
best-effort ranges: Voxel Ascendant `>=0.1.0-rc.1 <3.0.0-0`, Dramaless
`>=1.6.2-ST.190.1 <3.0.0-0`, PotatoVoxel `>=1.7.2 <3.0.0-0`, or Battle Art
`>=1.9.0 <3.0.0-0`. Choose at most one Voxel renderer.

Every Dramaless 2.x build is renderer-native. Only exact `2.0.2` receives the
narrow fixed camera control; every other 2.x build keeps complete native
ownership. Only exact Battle Art `1.9.2` receives its bounded optional-cache
repair. Later in-range releases receive the common closed capability surface,
not an adapter written for another version. PotatoVoxel keeps its own camera,
HUD, quality settings and cache; its upstream `LOGS TO DEV` setting is ON by
default and can be switched OFF.

These ranges avoid a KASC update for every renderer release, but are
best-effort—not a guarantee for every upstream change. If an update breaks
rendering, roll the renderer back to the last working release. Unversioned and
3.x packages, multi-renderer setups, Dramatic Shape, Terrarium and First Person
remain blocked. Canonical repositories are the support contract; rich managers
and runtime metadata reject an explicit mismatch, while older managers mainly
enforce the ID/version fence.
Ascendant now bundles
its own followers, Wilds/living-world,
Crystal-animation, rematch, bag, quick-select, gender/breeding and Nuzlocke
systems. Their standalone packages must be disabled before Ascendant is
enabled on engine 0.1.90.

Important limits:

- Do not enable another complete Johto species registry at the same time.
- **Kanto Reforged is not currently supported beside Ascendant.** Disable it
  before enabling Ascendant. The rule prevents simultaneous initialization;
  it does not claim that either mod is defective, and Reforged remains usable
  by itself.
- **All Pokémon Catchable, Modern Party UI and standalone Trainer Rematch are
  not supported beside Ascendant.** Ascendant already owns their encounter,
  party/summary or rematch systems; enable only Ascendant's integrated version.
- Kanto Ascendant's KANTO 151 option owns its overlapping encounter slots.
- The Randomizer remains authoritative for randomized species and moves.
  Ascendant preserves boss team size, levels, rules, AI, rewards and
  progression.
- The current standalone `shiny_indicators` release is not approved on engine
  0.1.90: it overlaps Ascendant's built-in presentation and still uses APIs
  denied by the sandbox. Keep it disabled; Ascendant supplies its own shiny
  sparkles, chime and markers.
- Gorochu registered by another compatible graphics/audio provider keeps that
  provider's asset; Ascendant fills only missing assets.
- Ascendant's bundled Wilds 1.12.2 provider supplies visible Kanto and Johto
  encounters. Do not enable standalone Wilds of Kanto beside it. Use
  Ascendant's **LIVING WORLD** and **VISIBLE JOHTO** settings instead.
- Unique Menu Icons and Dynamic Cries register expanded-species icon or cry
  keys that Ascendant already owns. Keep them disabled beside Ascendant; since 6.5.5
  reports these overlaps as manager conflicts instead of allowing a late
  duplicate-registration failure.
- Wilds rolls a visible encounter when it appears. Fighting an entity that was
  already standing on the map does not roll it again. Changing the Johto
  current, scanning a trace or toggling **VISIBLE JOHTO** refreshes old visible
  rolls. Check **ASCENDANT → WORLD → JOHTO SIGNALS → WILDS LINK** for the live
  connection state. **EARLY JOHTO** remains locked there until the receiver has
  physically been repaired on Driftglass; afterward, turning it or **MYTHIC
  SIGNALS** on/off also clears stale visible rolls.

</details>

<details>
<summary><strong>⚠️ SPOILER — Do option changes apply immediately?</strong></summary>

Most runtime options do. **VISIBLE JOHTO** refreshes Wilds of Kanto's existing
visible encounter rolls immediately; classic grass encounters are unaffected
when the visible bridge is off. Encounter-table options such as **KANTO 151** are
loaded while the mod starts and require a restart. The in-game KANTO 151
status page shows both the loaded and selected mode when they differ.

</details>

## Main story, rematches and Kanto 151

<details>
<summary><strong>⚠️ FULL SPOILER — What is BEYOND KANTO / JENSEITS VON KANTO?</strong></summary>

Every save begins on the Generation-I boundary. After the first Hall of Fame,
Elm's/Lind's aide in Oak's/Eich's Lab offers **BEYOND KANTO / JENSEITS VON
KANTO** behind two choices that both default to **NO**. Accepting it is a
save-local, irreversible decision:

- Dark and Steel rules activate, Magnemite/Magneton gain Steel, and Bite,
  Gust, Sand-Attack and Karate Chop use their Generation-II types/categories.
- Johto wild waves, research and the Silver/Kris/Gold Masters passages open.
- Non-Kanto Legacy Bank withdrawals, extended cave encounters, Hoenn/HEVO
  rewards and their new evolutions become available.

While the boundary remains sealed, the Kanto story, Hall of Fame, Kanto
rematches, Kanto surprise trainers, Kanto 151 and the physical Hoenn/HEVO cave
maps, scientists, puzzles and light stones remain playable. Those caves use
deterministic #001-151 encounter substitutes and keep extended rewards sealed;
the Bank still displays non-Kanto Pokémon but cannot withdraw them. There is no
second copy of any cave or script.

The decision belongs only to that save. Loading another slot, starting a
normal New Game or beginning New Game+ starts sealed again. Existing saves
that already contain genuine Johto/Hoenn Pokémon or real research,
Masters/HEVO progress migrate active; launcher options and archive history
alone do not activate a fresh save.

</details>

<details>
<summary><strong>⚠️ SPOILER — Does Ascendant replace the original Kanto story?</strong></summary>

No. The original story, Gyms, Team Rocket, Elite Four and first Hall of Fame
remain familiar. Some mechanics, encounter availability and early field
rematches are active during the story, but the main boss overhaul begins
after the first Hall of Fame.

Dark and Steel are registered additively for extended content. Existing
Generation-I type, stat, learnset and move records keep their vanilla Kanto
data while **BEYOND KANTO** is sealed. Only after that save's irreversible
opt-in do Magnemite/Magneton and the four documented original moves receive
their Generation-II overlay. Evolution branches into new species are appended
without replacing any original Kanto evolution.

</details>

<details>
<summary><strong>How do Difficulty and Adaptive Trainer Levels interact?</strong></summary>

They are separate controls. Difficulty owns its badge-phased fixed level
adjustment and, in 6.5.6, the first canonical pre-Hall-of-Fame battle against
each story Gym Leader:

| Difficulty | First story Gym contract |
|---|---|
| Standard | Exact Red/Blue/Yellow edition team and behavior, including Yellow's official special moves |
| High | Same edition roster with three useful, legal moves |
| Hard | One themed addition, stronger AI and one battle-wide Leader heal |
| Very Hard | One or two themed additions, four useful legal moves, advanced AI and at most two heals; Brock and Misty keep one |
| Extreme | A progressive early cap of four/five and later cap of six, the advanced move/AI policy, limited healing and the existing player-item lock |

This contract does not rewrite rematches, forced encounters, Randomizer
results after its documented composition seam, or postgame Master, Apex and
Crown battles. Generation-II moves can enter a higher-tier story Gym set only
when that save has both activated **BEYOND KANTO** and repaired its Driftglass
receiver. The complete boundaries and roster ceilings are in the
[story Gym difficulty contract](docs/STORY_GYM_DIFFICULTY_6_5_6.md).

Adaptive Trainer Levels runs later. AUTO is classic/off on Standard and aims
at the rounded active-party average +1 on High, +2 on Hard, +3 on Very Hard
and +4 on Extreme. Manual -2, Match, +2, +4, +6 and +8 targets and exact
classic OFF are also available. It does not pull an authored team below its
Difficulty floor, duplicate the fixed Difficulty bonus or replace curated
moves. Existing saves retain classic behavior until Adaptive or Difficulty is
deliberately revisited. See the
[bilingual Adaptive contract](docs/adaptive-trainer-levels.md).

</details>

<details>
<summary><strong>⚠️ SPOILER — How do field-trainer rematches work?</strong></summary>

After a trainer is defeated, they train for a configurable number of completed
player steps. Fresh saves use NORMAL. The same selected range governs visible
field recovery, silent training and post-game Gym recovery:

| Profile | Future interval |
|---|---:|
| VERY SHORT | 151-302 |
| SHORT | 303-604 |
| NORMAL | 605-1255 |
| LONG | 1256-1882 |
| VERY LONG | 1883-2510 |
| CUSTOM | Saved minimum and maximum, editable from 151 through 2510 |

Only exact preset pairs acquire a preset name during migration. The existing
151-2510 pair, the historical 128-256 pair and every other hand-tuned pair
become CUSTOM without rewriting either value. CUSTOM values survive a
temporary preset selection. A change affects only intervals rolled afterward;
every already scheduled `readyAt`, `nextTrainingAt` and `bossRest` timestamp
is preserved. Legacy Wanderers use their own independent frequency.

Talking early shows the exact remaining count. When ready, talk again to
accept a class-specific rematch. If its projected team averages more than ten
levels above the active party, a second warning appears first. That preview
uses the same fixed Difficulty adjustment as the actual battle even when
Adaptive Trainer Levels is OFF.

By default, every completed training cycle adds two levels, capped at 100.
Ignored ready trainers continue silent training, so their next team can grow
further. At strength tiers +4, +8, +12 and beyond, TEAM GROWTH can recruit
class-appropriate Pokémon until the team reaches six.

Ranks are based on completed rematches and silent growth:

| Rank | Growth tiers |
|---|---:|
| Rookie | 0 |
| Veteran | 2 |
| Expert | 5 |
| Master | 10 |
| Legend | 20 |

Master and Legend field trainers receive an overworld sparkle. The engine's
ordinary trainer prize and Pay Day paths remain intact; Ascendant's reward is
an additional post-win layer.

</details>

<details>
<summary><strong>⚠️ SPOILER — What can field rematches drop?</strong></summary>

The old six fixed item bands are no longer the implementation. A victory uses
three layers in this order:

1. Independent one-time EXP-helper catchups.
2. If loot is enabled, a post-Hall-of-Fame Master Ball check.
3. If no Master Ball was awarded, one ordinary item check followed by an
   extra-money roll on an item miss.

The helper checks can stack with each other and with layer 2 or 3:

| Missing helper | Check per eligible win |
|---|---:|
| EXP Share / EXP.ALL | 225/10000 = **2.25%** |
| EXP Multiplier x2 | **1/300** |
| Next x3 stage | **1/250** after x2 |
| Next x5 stage | **1/250** after x3 |

OFF disables only the Master Ball and ordinary
item/extra-money layers. It does not disable native trainer prize money, Pay
Day, helper catchups, Field Kit/TM progress, Johto research or the shiny
streak.

With BALANCED or GENEROUS active, a registered Master Ball has a separate
**1/50 (2%)** chance after the Hall of Fame. A hit suppresses the ordinary
item/money roll. Enemy average level and Apex completion are not gates.

| Enemy team | BALANCED / GENEROUS ordinary-item chance |
|---|---:|
| Not entirely level 100 | **65% / 80%** |
| All level 100, 0 mastery wins | **72% / 87%** |
| All level 100, 12+ mastery wins | **75% / 90%** |

For an all-level-100 team, each mastery win adds 0.25 percentage point up to
+3 points. An item miss reaches one of these conditional money tables:

| Enemy team | Amounts and conditional chances |
|---|---|
| Below all-100 | ¥0 / ¥100 / ¥250 / ¥500 / ¥750 / ¥1000 / ¥1250 / ¥1500 / ¥1750 / ¥2000 = 5 / 20 / 20 / 20 / 12 / 10 / 6 / 4 / 2 / 1% |
| All level 100 | ¥1000 / ¥1500 / ¥2000 / ¥2500 / ¥3000 / ¥4000 / ¥5000 / ¥6000 / ¥7000 / ¥8000 = 25 / 20 / 18 / 12 / 10 / 6 / 4 / 2.5 / 1.5 / 1% |

After the Hall of Fame, a below-100 BALANCED result is 2% Master Ball, 63.7%
ordinary item, 32.585% positive extra money and 1.715% nothing extra. GENEROUS
is 2%, 78.4%, 18.62% and 0.98%. At all level 100 with no mastery, BALANCED is
2% / 70.56% / 27.44% and GENEROUS is 2% / 85.26% / 12.74%; that money table
has no zero result. At 12+ mastery wins those item/money pairs become
73.5% / 24.5% and 88.2% / 9.8%. Before the Hall of Fame, below-100 totals are
65% item, 33.25% positive money, 1.75% nothing in BALANCED and 80% / 19% / 1%
in GENEROUS.

The current ordinary pool has 120.5 base weight:

| Group | Results (base weights) |
|---|---|
| Balls | Poké Ball x3/x5/x10 (8/5/1), Great Ball x2/x3/x5 (7/4/1), Ultra Ball x1/x2/x3 (5/3/1) |
| Healing | Potion x2 (6), Super Potion x2 (6), Hyper Potion (5), Max Potion (2), Full Heal x2 (5), Revive (4), Max Revive (1) |
| PP | Ether (5), Max Ether (2), Elixir (3), Max Elixir (1) |
| Training | PP Up, Rare Candy, HP Up, Protein, Iron, Calcium, Carbos (2 each) |
| Evolution | Five Kanto Stones (2 each); Sun Stone, King's Rock, Metal Coat, Dragon Scale, Upgrade (1.5 each) |
| Apricorn Balls | Fast, Friend, Heavy, Level, Love, Lure, Moon (2 each) |

Premium results receive x1.6 effective weight against an all-level-100 team
and up to another x1.25 from mastery. Master Ball, Safari Ball and HEVO
progression relics are excluded from this pool. The one-time Thunder Tear is
progression-locked and excluded too.

No result is destroyed by capacity. A rematch Master Ball uses
`Bag -> PC -> pending`; a field EXP helper or ordinary item uses Bag then its
corresponding persistent pending record until space is available.

</details>

<details>
<summary><strong>⚠️ FULL SPOILER — How do Legacy Wanderers and their rewards work?</strong></summary>

Legacy Wanderers are not field rematches. They exist only during an active
true Legacy Journey from cycle 2 onward, use their own state and ignore the
REMATCH BREAK profile. Only eligible outdoor Kanto route/town/city steps and
genuine outdoor map changes count. Interiors, caves, Safari and HEVO maps do
not. There is no repeated per-step probability: once due, the reserved
encounter retries only when the field state is safe.

| Frequency | Earliest steps | Target map changes | Hard due |
|---|---:|---:|---:|
| RARE | 600 | 4-6 | 5000 steps, or 7 changes after the floor |
| NORMAL | 200 | 2-3 | 1800 steps, or 4 changes after the floor |
| OFTEN | 200 | 1-2 | 900 steps, or 3 changes after the floor |
| NEVER | Disabled | - | Reserved rewards still deliver |

After a win, a 240-480-step same-map encore is possible at 3% on RARE, 10% on
NORMAL and 20% on OFTEN. At most two wins may occur on the same map; the next
cycle then requires three genuine outdoor changes. Moving to a different
outdoor map cancels an encore into that three-map cycle. A loss gives no
reward, restores pre-battle money, adds one relief level (maximum three) and
starts a fresh three-map cycle; each later win removes one relief level.

One exact-once reward token is reserved before the battle. On a win it checks,
in priority order: registered Master Ball **1/32**; missing EXP Share **1/4**;
missing x2 Multiplier **1/6**; next x3 **1/12**; next x5 **1/24**; otherwise
the ordinary pool. The catch-up odds are conditional checks and disappear as
soon as their unlock exists.

Before Beyond Kanto, the ordinary pool is Poké Ball stacks (12 weight), Great
Ball stacks (12), Ultra Ball stacks (9) and Safari Ball (1), total 34. Beyond
Kanto adds the seven Apricorn Balls at 5 weight each plus twenty validated,
teachable Generation-II/III TMs at 1 each. The current ordinary pool total is
89. The twenty are Toxic, Ice Beam, Blizzard, Hyper Beam, SolarBeam, Iron
Tail, Thunderbolt, Thunder, Earthquake, Dig, Psychic, Double Team, Reflect,
Fire Blast, Swift, Dream Eater, Rest, Frenzy Plant, Blast Burn and Hydro
Cannon. Invalid, placeholder, incompatible and HM records never enter it.

Every Wanderer item uses `Bag -> PC -> pending`; the persistent token ledger
prevents replay or duplicate delivery.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do I obtain the Field Kit and renewable TMs?</strong></summary>

- The first won field rematch awards the permanent **Field Kit**.
- It can use Cut, Fly, Surf, Strength or Flash from the Bag, but the matching
  HM and Badge are still required.
- After the first Hall of Fame, every second won field rematch awards the next
  TM in a guaranteed TM01-TM50 cycle.
- A full Bag places earned TMs into a persistent first-in, first-out queue.
  The Route 5 Day-Care machine reports and delivers the oldest waiting TM.
- Crown Erika, Blaine and Misty unlock TM51 Frenzy Plant, TM52 Blast Burn and
  TM53 Hydro Cannon. Once earned, they join later archive cycles.

The Route 5 machine also contains the Move Deleter and Move Reminder. The
Deleter can remove HMs but never leaves a Pokémon with no usable move.

</details>

<details>
<summary><strong>⚠️ SPOILER — When does Espeon learn Psybeam?</strong></summary>

Espeon learns Psybeam normally at level 36 as part of its own Generation-II
level-up learnset. Existing Espeon at level 36 or above can relearn Psybeam at
the Route 5 Move Reminder; Espeon below level 36 cannot select it yet. Psybeam
is not added to Johto Move Resonance or to any original Kanto learnset.

</details>

<details>
<summary><strong>⚠️ SPOILER — Can all original 151 Pokémon be obtained in one save?</strong></summary>

Yes, when **KANTO 151** is set to **REWARDS** or **WILD**.

- **REWARDS** is the default. Version exclusives share habitats, while the
  other starters and missing fossil are Master Leader rewards.
- **WILD** also adds rare wild starters, fossils, Aerodactyl and former trade
  evolutions.
- **OFF** disables Ascendant's catchability, evolution and renewable Moon
  Stone additions.

KANTO 151 never inserts Mew into an ordinary encounter table. Mew's original
late-game investigation remains available, while the independent optional
**Mythic Signals** system can create its own protected encounters.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: exact shared Kanto 151 locations</strong></summary>

These changes apply in every edition when KANTO 151 is active:

| Pokémon or family | Location |
|---|---|
| Caterpie and Weedle lines | Viridian Forest |
| Oddish, Bellsprout, Mankey, Meowth | Route 5 |
| Ekans, Sandshrew, Growlithe, Vulpix | Route 8 |
| Scyther and Pinsir | Safari Zone Center |
| Slowpoke, Staryu, Shellder | Seafoam Islands B2F |
| Hitmonlee | Victory Road 1F |
| Hitmonchan | Victory Road 2F |
| Grimer, Growlithe, Magmar, Ditto | Pokémon Mansion B1F |
| Electabuzz | Power Plant |
| Eevee, level 25, 2% | Route 7 after the first Hall of Fame |

Former trade evolutions also gain level routes:

- Kadabra → Alakazam at level 42
- Graveler → Golem at level 42
- Haunter → Gengar at level 42
- Machoke → Machamp at level 45

Trading still works as an earlier alternative.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: exact REWARDS and WILD-only Kanto locations</strong></summary>

In default **REWARDS** mode:

| Reward | Source |
|---|---|
| Bulbasaur | Defeat Master Erika |
| Squirtle | Defeat Master Misty |
| Charmander | Defeat Master Blaine |
| Missing Dome or Helix Fossil | Defeat Master Brock |
| Second fossil for an unusual save owning neither | Defeat Crown Brock |

In **WILD** mode only:

| Pokémon | Location |
|---|---|
| Bulbasaur Lv.23 | Safari Zone East |
| Squirtle Lv.23 | Seafoam Islands B2F |
| Omanyte and Kabuto Lv.35 | Seafoam Islands B4F |
| Aerodactyl Lv.45 | Victory Road 3F |
| Charmander Lv.23 | Victory Road 3F |
| Alakazam Lv.49 | Cerulean Cave 1F |
| Machamp Lv.55 | Cerulean Cave 2F |
| Gengar and Golem Lv.57 | Cerulean Cave B1F |

Renewable Moon Stones cost ¥2100 in Pewter Mart and Celadon Department Store
4F.

</details>

<details>
<summary><strong>⚠️ SPOILER — Where are Mankey and the two Nidoran?</strong></summary>

With KANTO 151 active, **Mankey is on Route 5 in Red, Blue and Yellow**.

The native Route 22 table remains edition-specific:

- Red and Blue: Nidoran♀ and Nidoran♂; no Mankey
- Yellow: Nidoran♀, Nidoran♂ and Mankey

This preserves Route 22's original edition identity while Route 5 guarantees
Mankey in every active KANTO 151 game.

</details>

## Johto Signals and Mythic Signals

<details>
<summary><strong>⚠️ SPOILER — Do I need to start a new game for Johto Signals?</strong></summary>

No. Version 6.5.8 upgrades existing Red, Blue and Yellow saves in place.

The signal system does not count steps taken before 6.0 was installed. Once
the updated save has a starter and the Pokédex, it begins its own hidden
counter normally. Party, PC, Bag, money, trainer progress and existing
Pokédex records are preserved.

</details>

<details>
<summary><strong>⚠️ SPOILER — How does the first Johto signal begin?</strong></summary>

After choosing a starter and receiving the Pokédex, Professor Oak calls after
**1–200 eligible player steps**. He reports unusual objects on Pallet Town's
southern coast. The call places a visible dark capsule there.

There is no options-menu shortcut around this route. **EARLY JOHTO** is locked
until the receiver has physically been repaired on Driftglass, and the Johto
current is chosen there.

If the capsule remains untouched, Oak gives exactly one reminder after
another 400 eligible steps. There is no third call. If both Early Johto and
Mythic Signals are disabled, no Signals quest is forced into the Kanto
opening.

</details>

<details>
<summary><strong>⚠️ SPOILER — What happens if I decline the capsule or Driftglass trip?</strong></summary>

Nothing is lost.

- Declining the capsule leaves the physical object on the coast.
- Taking it cancels Oak's reminder. The sealed capsule can be opened
  immediately or later under **ASCENDANT → WORLD → JOHTO SIGNALS**.
- Opening it reveals coordinates. Show those coordinates to Pallet's boatman
  to unlock the Driftglass trip.
- Declining the boat trip leaves the boatman available for later.
- Driftglass has a return boat during every quest stage, including before the
  receiver is repaired.

The trip never permanently removes the player from Kanto. Disabling and
re-enabling either Signals option also preserves its counters.

</details>

<details>
<summary><strong>⚠️ SPOILER — What do the three Johto currents change?</strong></summary>

Repair the Migration Receiver at Driftglass, then choose:

| Current | Effect |
|---|---|
| **Kanto First** | No early Johto replacements; normal Kanto encounters remain unchanged |
| **Wanderwaves** | Badge- and habitat-aware Johto groups at about 2%, or 4% during a strong signal |
| **Johto Unleashed** | About 10% Johto share across matching authored habitats |

Only suitable base species are introduced. Legendary and Mythical Pokémon are
never part of the Johto migration pool.

Ordinary Johto encounters use the current route's weighted average level plus
a random 2-5 levels. Explicitly authored primal-trace encounters keep their
intended story level.

The average is calculated from the route's actual encounter slots and their
Gen-I encounter weights, then rounded to a whole level. For example, a route
with an effective average of level 3 can produce an ordinary Johto Pokémon at
level 5, 6, 7 or 8 — never level 12 or 15 just because that species has a
later research habitat. Grass and surfing tables are balanced independently.

The current can be changed later under
**ASCENDANT → WORLD → JOHTO SIGNALS**. Choosing Kanto First does not disable
the independent Mythic Signals system.

</details>

<details>
<summary><strong>⚠️ SPOILER — Are high-level Johto Pokémon on the first routes intended?</strong></summary>

No. A previous 6.0.x path accidentally reused fixed research-habitat levels,
which could place level 12-15 Johto Pokémon beside level 2-6 Kanto encounters.
That behavior is being corrected for the next patch.

After the fix, ordinary Johto replacements stay only 2-5 levels above the
weighted average of the route's active encounter table. The same rule is used
by classic 2D encounters, Wilds of Kanto and permanent researched habitats.
Primal traces, guaranteed story encounters and other explicitly authored
special battles are excluded and keep their designed levels.

</details>

<details>
<summary><strong>⚠️ FULL SPOILER — Where are the four primal traces and their rare encounters?</strong></summary>

After repairing the receiver, follow its clue to the relevant map and choose
**ASCENDANT → WORLD → JOHTO SIGNALS → SCAN CURRENT AREA**.

| Trace scan | Species unlocked | Encounter habitat | Level |
|---|---|---|---:|
| Deep Viridian Forest | Chikorita | Route 24 grass | 18 |
| Route 6, south of Cerulean | Totodile | Seafoam Islands B2F | 22 |
| Pokémon Mansion B1F | Cyndaquil | Pokémon Mansion B1F | 22 |
| Victory Road 3F | Larvitar | Victory Road 3F | 45 |

Each trace unlocks only its own base species. Until the species is genuinely
seen, Dex-aware screens display `???`.

Every suitable wild battle then receives a separate protected rare roll:

| Current | Chance | Hard guarantee |
|---|---:|---:|
| Wanderwaves | 1/512 | Next suitable encounter at attempt 512 |
| Johto Unleashed | 1/256 | Next suitable encounter at attempt 256 |

Changing currents does not erase the counters. Repel, scripted encounters,
roamers, outbreaks and other authored battles cannot consume a guaranteed
trace result.

</details>

<details>
<summary><strong>⚠️ SPOILER — Are Mew and Celebi roaming from the beginning, and can I catch them?</strong></summary>

**Mythic Signals are enabled by default**, but nothing can appear before the
Pokédex is active. After that, rare Mew or Celebi **echoes** may replace a
genuine Kanto grass encounter even before the Driftglass receiver is repaired.

An echo is a warning, not a catch opportunity:

- it appears at level 60–100, based on the player's party;
- it cannot be caught with any Ball;
- a Master Ball is rejected and returned rather than consumed;
- it cannot be escaped from or reduced below 1 HP;
- the battle continues until the player's party falls.

The first echo is guaranteed by the 512th eligible grass encounter. Later
echoes begin at 1/2048, gain pressure during the hunt and are guaranteed by
encounter 2048.

</details>

<details>
<summary><strong>⚠️ FULL SPOILER — How do Mew and Celebi become catchable?</strong></summary>

1. Witness three Mythic echoes in genuine Kanto grass.
2. Repair the Driftglass receiver.
3. Earn at least four Badges.
4. Ask the Driftglass researcher to complete the **Resonance Seal**.
5. Search genuine Kanto grass for a true manifestation.

A true manifestation uses a protected 1/8192 counter and can be caught
normally. If it escapes or defeats the party, the same species remains bound:
it keeps its level, DVs, HP and status, returns at 1/16 and is guaranteed
within 32 further eligible encounters.

Already-owned species and individually disabled Mew/Celebi outcomes are
removed from the pool. Existing canonical Mew or Celebi story conclusions
remain authoritative, so Signals do not create required duplicates.

Use **ASCENDANT → WORLD → MYTHIC SIGNALS** to inspect progress or disable this
system independently from Early Johto.

</details>

<details>
<summary><strong>⚠️ SPOILER — Do Signals reveal the complete Johto Pokédex?</strong></summary>

No. Before visiting Driftglass, the ordinary Pokédex remains Kanto-only and
ends at #151. Repairing the Migration Receiver there upgrades it into the
**National Dex** with slots through #251.

The upgrade never pre-fills seen or owned records. An unseen species remains
hidden, a real sighting reveals its name and sprite, and its height, weight
and description remain **Data unknown** until a real catch, evolution, egg or
reward records ownership.

Early Johto catches are recognized by Elm's later research. When a later
milestone would award a duplicate specimen, the research system supplies its
safe compensation instead.

Existing 6.0.0-6.0.2 saves whose Johto receiver was already active receive
the National Dex automatically when upgraded. If the old quest had only
started, every capsule, boat and counter flag is retained and the researcher
still awards the National Dex on Driftglass.

</details>

## Johto research, breeding and items

<details>
<summary><strong>⚠️ SPOILER — When do Johto Pokémon start appearing?</strong></summary>

There are now two independent routes:

- Optional **Johto Signals** can introduce habitat-aware Johto encounters
  during the Kanto story.
- The original research campaign still begins after the first Hall of Fame
  and eventually exposes every normal Johto base family.

For the postgame research route, the first Hall of Fame places Elm's aide in
Oak's Lab. Complete all three starter trials:

| Trial | Location | Reward |
|---|---|---|
| Verdant Trial | Celadon City | Chikorita |
| Ember Trial | Cinnabar Island | Cyndaquil |
| Torrent Trial | Cerulean City | Totodile |

After all three, every won ordinary field rematch awards one still-missing
Johto base family. There are 40 normal specimen tracks; the first further
rematch after all 40 awards Larvitar. Johto Pokémon already obtained through
Signals are recognized rather than incorrectly counted as new discoveries.

Once a family is researched, its base species also establishes a renewable
2% Kanto habitat. Multiple eligible families sharing a location split the
same combined 2%; they do not each receive 2%. Research unlocks the species
and location, but it does not force the old authored habitat level. Each
ordinary encounter now uses that route's weighted average plus 2-5 levels.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: all researched Johto habitats</strong></summary>

| Base species | Habitat |
|---|---|
| Chikorita | Route 24 grass |
| Cyndaquil | Pokémon Mansion B1F |
| Totodile | Seafoam Islands B2F |
| Sentret | Route 1 grass |
| Hoothoot | Route 2 grass |
| Ledyba | Viridian Forest |
| Spinarak | Viridian Forest |
| Chinchou | Route 20 water |
| Natu | Route 22 grass |
| Mareep | Route 8 grass |
| Marill | Route 6 grass |
| Sudowoodo | Route 10 grass |
| Hoppip | Route 5 grass |
| Aipom | Route 16 grass |
| Sunkern | Route 24 grass |
| Yanma | Safari Zone Center |
| Wooper | Route 19 water |
| Murkrow | Route 7 grass |
| Misdreavus | Pokémon Tower 7F |
| Unown | Mt. Moon B2F |
| Wobbuffet | Cerulean Cave 1F |
| Girafarig | Route 18 grass |
| Pineco | Viridian Forest |
| Dunsparce | Diglett's Cave |
| Gligar | Victory Road 1F |
| Snubbull | Route 8 grass |
| Qwilfish | Route 21 water |
| Shuckle | Mt. Moon B2F |
| Heracross | Route 15 grass |
| Sneasel | Seafoam Islands B4F |
| Teddiursa | Route 10 grass |
| Slugma | Pokémon Mansion B1F |
| Swinub | Seafoam Islands B2F |
| Corsola | Route 19 water |
| Remoraid | Route 21 water |
| Delibird | Seafoam Islands B4F |
| Mantine | Route 20 water |
| Skarmory | Victory Road 2F |
| Houndour | Route 7 grass |
| Phanpy | Route 11 grass |
| Stantler | Safari Zone East |
| Smeargle | Route 16 grass |
| Miltank | Safari Zone Center |
| Larvitar | Victory Road 3F |

The habitat becomes active only after that family, starter trial or Larvitar
finale is recorded. These are ordinary renewable habitats, so their encounter
levels follow the active grass/water table rather than a fixed species level.

</details>

<details>
<summary><strong>⚠️ SPOILER — How does the Route 5 Day-Care work?</strong></summary>

The Route 5 house is a complete two-parent Generation-II-style Day-Care:

- Each deposited parent gains one experience point per completed player step.
- Retrieval costs ¥100 plus ¥100 per level gained.
- Compatibility uses Gen-II egg groups, gender DVs and the normal Ditto,
  genderless, baby and Undiscovered restrictions.
- Every 256 compatible steps performs an egg check.
- Eggs wait safely until the party has space.
- Carried eggs cannot battle, be healed or become parents.
- Each species uses its own hatch cycle.

Crystal DV inheritance is reproduced. Defense and the lower three Special
bits come from Ditto or the opposite-gender parent. A valid shiny donor can
therefore produce the authentic **1/64 shiny breeding result**. As in Crystal,
parents sharing the relevant Defense and lower Special bits are incompatible.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: research eggs, evolution items and partner rewards</strong></summary>

Baby eggs:

| Recorded specimens | Egg | Hatch steps |
|---:|---|---:|
| 4 | Pichu | 256 |
| 8 | Cleffa | 320 |
| 12 | Igglybuff | 320 |
| 16 | Togepi | 384 |
| 20 | Tyrogue | 384 |
| 25 | Smoochum | 448 |
| 30 | Elekid | 448 |
| 35 | Magby | 448 |

Evolution-item milestones:

| Recorded specimens | Item |
|---:|---|
| 3 | Sun Stone |
| 7 | King's Rock |
| 11 | Metal Coat |
| 15 | Dragon Scale |
| 19 | Up-Grade |
| 24 | Metal Coat |
| 29 | King's Rock |
| 34 | Sun Stone |

Guaranteed Kanto research partners:

| Recorded specimens | Partner |
|---:|---|
| 2 | Gloom |
| 5 | Poliwhirl |
| 9 | Eevee |
| 13 | Slowpoke |
| 17 | Onix |
| 21 | Scyther |
| 25 | Seadra |
| 28 | Porygon |
| 32 | Eevee |
| 36 | Golbat |
| 39 | Chansey |

Collect eggs and use item evolutions at the visible Route 5 Day-Care machine.
A full party or Bag reserves the reward.

</details>

<details>
<summary><strong>⚠️ SPOILER — Where is the early Johto evolution-item grotto?</strong></summary>

Repair the Migration Receiver at Driftglass, then inspect the second glass
seam near the researcher. It opens the optional **Prism Grotto**.

The Prism Reader stores six inscriptions. Five are short pillar sequences
that each award one guaranteed item:

- Sun Stone
- King's Rock
- Metal Coat
- Dragon Scale
- Up-Grade

A wrong pillar resets only the current sequence. Solved inscriptions can be
rehearsed but never duplicate their reward. If the Bag is full, the Prism
Reader keeps the formed item until space is available.

The repeatable Twilight Mirror inscription requires Eevee in the party. Its
ten-note rite raises Eevee to the required bond threshold; level it once by
day for Espeon or by night for Umbreon. **JOHTO TIME** controls day/night.
Espeon and Umbreon in the party provide extra pillar hints.

The large crystal tablet directly behind the Prism Reader has a separate
**Johto Move Resonance** option; the six pillars themselves remain puzzle
controls. Choose an original Kanto Pokémon from the party and the tablet lists
the compatible Generation-II moves currently implemented by Ascendant.
Crystal-compatible TM and inherited moves are immediately available. A move
that was learned only by level remains locked until that Pokémon reaches its
original Crystal level, and the tablet states the exact required level.

The tablet never replaces a move. With four occupied slots it directs the
player to the existing Route 5 Move Deleter, which can also remove HMs but
always leaves the Pokémon with at least one move. Return to the tablet after
opening a slot. Every move awakened by the tablet is recorded for the existing
Route 5 Move Reminder. Once the Driftglass receiver is repaired, that Reminder
also reads the same species-specific Resonance catalogue directly: for example,
Scyther may relearn False Swipe from level 18 onward even though its original
RBY level-up schedule stays untouched. Johto species use their own regular
Crystal level-up schedules instead (including Espeon's Psybeam at level 36).
Unsupported mechanics such as Pursuit are not replaced with fake moves, and
Pokémon without a supported compatible move are left unchanged.

</details>

<details>
<summary><strong>⚠️ SPOILER — Where can I get more Johto evolution items?</strong></summary>

After the Crown Champion, the Frontier Exchange opens at Route 5 and under
**ASCENDANT**:

| Item | Frontier Points |
|---|---:|
| Sun Stone | 6 |
| King's Rock | 8 |
| Metal Coat | 8 |
| Dragon Scale | 10 |
| Up-Grade | 10 |

An already recorded TM can also be bought for 3 Frontier Points. Locked items
and unrecorded TMs remain unavailable.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do special Johto evolutions work?</strong></summary>

- Crobat, Togetic and Blissey evolve through friendship.
- Espeon and Umbreon use friendship plus day/night. **JOHTO TIME** can follow
  the system clock or force Day/Night.
- Tyrogue evolves at level 20: Attack higher than Defense gives Hitmonlee,
  Defense higher gives Hitmonchan, equal values give Hitmontop.
- Gloom, Poliwhirl, Slowpoke, Onix, Scyther, Seadra and Porygon use their
  relevant research item at the Route 5 machine.
- New branches are appended; original choices such as Vileplume, Poliwrath,
  Slowbro and the three stone Eeveelutions remain available.

</details>

## Shinies, outbreaks and the red Gyarados

<details>
<summary><strong>⚠️ SPOILER — What are the base shiny odds?</strong></summary>

Natural shinies use the authentic Generation-II DV formula and are
**1/8192**. Defense, Speed and Special DVs must be 10; Attack must be
2, 3, 6, 7, 10, 11, 14 or 15.

This applies to Bulbasaur through Celebi. Compatible Pokémon already present
in an older save are recognized automatically. Gorochu can also be shiny but
is a guest species outside the 251-species completion requirement.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do Ascendant's extra shiny rolls stack?</strong></summary>

With **SHINY HUNTS = ASCENDANT**, each bonus is an additional independent
1/8192 roll:

| Condition | Extra rolls |
|---|---:|
| Shiny Charm | +2 |
| 10-win field-rematch streak | +1 |
| 25-win streak | +3 |
| 50-win streak | +7 |
| Active outbreak on its named route | +15 |
| Active Golden Wind world event | +2 |

Only the highest streak row applies; the 10/25/50 bonuses are not added
together. Charm, the current streak tier, outbreak and Golden Wind do stack.

Some useful effective totals:

| Active bonuses | Total rolls | Approximate chance |
|---|---:|---:|
| None | 1 | 1/8192 |
| 10-win streak | 2 | 1/4096.25 |
| Shiny Charm | 3 | 1/2731.00 |
| 25-win streak | 4 | 1/2048.38 |
| 50-win streak | 8 | 1/1024.44 |
| Charm + 50 streak | 10 | 1/819.65 |
| Charm + 50 streak + Golden Wind | 12 | 1/683.13 |
| Outbreak only | 16 | 1/512.47 |
| Charm + 50 streak + outbreak | 25 | 1/328.16 |
| All bonuses | 27 | 1/303.89 |

The exact formula for `n` rolls is `1 - (8191 / 8192)^n`; it is not exactly
`n / 8192`.

Setting **SHINY HUNTS = NATURAL** disables bonus rolls, outbreaks and the red
Gyarados event while retaining natural DV shinies.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do streaks and Johto outbreaks work?</strong></summary>

Only won ordinary field-trainer rematches increase the streak. Losing a field
rematch resets it; wild battles do not.

After the first Hall of Fame and all three Elm starter trials, every tenth
consecutive win starts a deterministic outbreak lasting **2048 actual player
steps**. On the announced route, one quarter of normal encounters becomes the
outbreak species and receives +15 shiny rolls.

The outbreak cycle is:

1. Route 1 — Sentret
2. Route 2 — Spinarak
3. Route 4 — Phanpy
4. Route 6 — Mareep
5. Route 8 — Houndour
6. Route 12 — Marill
7. Route 15 — Yanma
8. Route 21 — Corsola
9. Route 22 — Dunsparce
10. Route 24 — Natu

It then repeats from Sentret.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: how do I trigger and find the red Gyarados?</strong></summary>

All of these conditions must be true:

1. **SHINY HUNTS** is set to **ASCENDANT**.
2. **RED GYARADOS** is enabled.
3. The first Hall of Fame has been completed.
4. The current field-rematch streak reaches **25 consecutive wins**.
5. The player is on **Seafoam Islands B4F**, not another Seafoam floor.

Oak announces the event when it unlocks. After that, a normal random encounter
on B4F becomes a guaranteed level-50 shiny Gyarados. It keeps returning until
caught; knocking it out or running away does not end the event.

If ordinary Gyarados still appear, check the exact floor, current streak and
both options first. A screenshot alone cannot distinguish an unmet condition
from an encounter conflict; include the ASCENDANT/Shiny status and enabled mod
list in a bug report.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do I obtain the Shiny Charm, and what does the Shiny Dex track?</strong></summary>

After the Hall of Fame, **ASCENDANT → SHINY DEX** tracks:

- shiny species seen;
- shiny species caught or hatched;
- wild encounter totals;
- number of shiny copies caught per revealed species.

Owning all ordinary Pokédex species #001-251 awards Oak's permanent,
non-tossable **Shiny Charm**. Gorochu does not count toward or block it.

The optional Shiny Release Lock prevents accidental release through Bill's PC.
It is a safety feature only; it does not change shiny odds.

</details>

<details>
<summary><strong>⚠️ SPOILER — Are there any other guaranteed shinies?</strong></summary>

Yes:

- The red Gyarados event is a guaranteed genuine-DV shiny.
- Every successful Silver/Kris/Gold Johto Masters run awards one genuine-DV
  shiny selected uniformly from all 251 species. Each species has an
  individual 1/251 chance; duplicates are possible.
- Crystal-style breeding can reach the authentic 1/64 result with a valid
  shiny donor.

</details>

## Mega Evolution, Yellow's partner and Gorochu

<details>
<summary><strong>⚠️ SPOILER — When and how do I unlock Mega Evolution?</strong></summary>

After the first Hall of Fame, use the Route 5 Day-Care machine to synchronize
the **Mega Ring** and register the separate **Mega Stone Case**.

During battle, press **SELECT** (`Tab` by default on keyboard) while the
FIGHT/PKMN/ITEM/RUN menu is visible. One Pokémon per side can Mega Evolve in
each battle. The form is battle-only and survives switching.

Enemy Mega defaults to post-game bosses. A story-mode Sabrina Alakazam, for
example, is not expected to Mega Evolve before the Master circuit.

</details>

<details>
<summary><strong>⚠️ SPOILER — Which Mega forms exist and where are their stones?</strong></summary>

The official catalog contains 30 forms for 27 species:

- Kanto: Venusaur, Charizard X/Y, Blastoise, Beedrill, Pidgeot, Alakazam,
  Slowbro, Gengar, Kangaskhan, Pinsir, Gyarados, Aerodactyl, Mewtwo X/Y
- Johto: Ampharos, Steelix, Scizor, Heracross, Houndoom, Tyranitar
- Z-A: Clefable, Victreebel, Starmie, Dragonite, Meganium, Feraligatr,
  Skarmory
- Mega Dimension: Raichu X/Y

Stone progression:

| Stone group | Unlock | Cost/source |
|---|---|---|
| Most classic non-Mewtwo stones | First Hall of Fame | ¥5000 |
| Charizardite X/Y | First Hall of Fame | ¥7500 |
| Most Z-A stones and Raichunite X/Y | All eight Master Leaders | ¥10000 |
| Mewtwonite X/Y | Apex Champion | ¥15000 |
| Meganiumite | Chikorita-family Starter Relic | Quest reward |
| Feraligatrite | Totodile-family Starter Relic | Quest reward |

The Route 5 machine forges stones. **ASCENDANT → MEGA STONES** shows `OWN`,
price or `LOCK`. When both X/Y stones are owned, the Route 5 form menu selects
the preferred Charizard, Mewtwo or Raichu form.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: what is Ascendant Typhlosion?</strong></summary>

Owning the Cyndaquil family assigns its Starter Relic journey. After defeating
Gold, a black seal appears in **Pokémon Mansion B1F**. Bring a
**level-100 Typhlosion** after owning all **251 Pokémon**.

The resulting permanent Basalt Core unlocks the fan form Ascendant Typhlosion
through the normal SELECT input without using a Mega Stone. It is Fire/Ground,
uses a +100 non-HP stat adaptation and restores 25% HP once when awakening.
The unlock survives Ascendant Cycles.

</details>

<details>
<summary><strong>⚠️ SPOILER — How does Yellow's Heart of Thunder quest work?</strong></summary>

After the Thunder Badge, speak to Lt. Surge. Keep Yellow's original partner
Pikachu in the party, walk **251 steps** and win **three trainer battles**,
then return to Surge for the permanent **Thunderheart**.

Using it gives three choices:

1. evolve permanently into Raichu;
2. stay Pikachu and permanently awaken Raichu's full base-stat profile once;
3. decide later.

Staying preserves Pikachu's form and moveset. Permanent Raichu evolution
remains available later but grants no second stat increase. Partner identity,
happiness, memories, dialogue, follower and Mega Raichu X/Y access are
preserved.

Upgraded Yellow saves with the Thunder Badge receive one Thunderheart and a
completed trial. The mod adopts a single unambiguous self-owned candidate; if
several candidates exist it asks instead of guessing.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: how do I obtain Gorochu?</strong></summary>

Gorochu is optional in Red, Blue and Yellow:

1. Red/Blue: return to Lt. Surge after the Thunder Badge and accept the
   permanent Thunderheart.
2. Yellow: complete the 251-step/three-trainer-win partner trial and return to
   Surge for the same item.
3. Take the Thunderheart to the silent condenser in the **remote east wing of
   the Power Plant**, far from Zapdos.
4. Generate one protected, consumable **Thunder Tear**. The Thunderheart
   remains in the Bag.
5. Use the Tear outside battle on the Raichu you choose.

No Hall of Fame, level threshold or level-up trigger is required. The Tear
cannot be used on Pikachu or another species. The Heart cannot be consumed,
sold, tossed, traded or deposited.

</details>

<details>
<summary><strong>⚠️ SPOILER — What makes Gorochu special?</strong></summary>

- Permanent pure Electric guest species, Pokédex number 1026
- Base stats: 85 HP / 135 Attack / 90 Defense / 125 Speed / 125 Special
- Total 560, about 13.13% above either 495-point Mega Raichu adaptation
- Dedicated normal/shiny 2D, Crystal animation, Voxel and follower art
- Seven animated Yellow partner expressions for sleepy, unwell, upset, wary,
  content, devoted and excited
- Spoken Gorochu cry in Yellow; Raichu-derived Gen-I chip cry in Red/Blue
- Cannot Mega Evolve; permanent Gorochu and temporary Mega Raichu X/Y are
  alternative paths
- Outside Kanto/National certificates, Shiny Charm and 251-species completion

Yellow's original partner keeps its exact identity, happiness, memories and
follower state after evolving.

</details>

<details>
<summary><strong>⚠️ SPOILER — Can opponents use Gorochu if I do not?</strong></summary>

No. Gorochu stays hidden from every opposing trainer in Red, Blue and Yellow
until the player personally completes a Raichu-to-Gorochu evolution on that
save.

Before discovery, Lt. Surge's authored slot and Randomizer-generated trainer
Gorochu are replaced with Raichu. Owning the Heart, generating the Tear,
seeing Gorochu or receiving one externally does not unlock opponent use.

</details>

## Hidden Evolution fissures and the three hero trials

**Spoiler-free hints:** enter the Hall of Fame, then look for a new field
researcher whose clue matches the current RED, BLUE or GREEN hero. The clue
must be solved before that hero's fissure becomes visible. Bring the field
techniques suggested by the cave itself and read the final black door: it
reports every missing mandatory condition before returning you to the correct
branch, without deleting solved progress.

RED, BLUE and GREEN below identify the selected hero route stored in that
save; they are not three interchangeable entrances for one character.

Grey monster statues are mandatory quiz objects. Yellow relics are optional
floor lights only; they improve visibility and never count as a statue or an
ending requirement. Questions cover Kanto, Johto, general Pokémon knowledge
and Sinnoh. Their order and correct answer position are shuffled per save, so
there is no fixed answer-button sequence.

The complete German offline guide includes overview sheets and clickable
individual maps for all three routes. It contains full spoilers:
[Hidden Evolution solution maps](docs/guides/hidden-evolution/README.md).

<details>
<summary><strong>⚠️ FULL SPOILERS — RED: Groudon/fire fissure, complete solution and Legacy hand-off</strong></summary>

### Find and enter RED's fissure

1. Enter the Hall of Fame. Professor Aster then appears in Celadon City at
   `(38,22)`.
2. Answer **VIRIDIAN WEST**. A wrong answer only starts a 250-walked-step
   cooldown before another attempt.
3. Go to Route 22. Face north from `(35,2)` toward the first bare wall west of
   Viridian; the fissure is at `(35,1)`.
4. Before the final door, activate **BEYOND KANTO** through Elm's aide in Oak's
   Lab. The cave can be explored before this, but it cannot be completed while
   the boundary is sealed.
5. Bring **STRENGTH** for all three mandatory boulders and **SURF** for the
   lower chasm, either on a valid field user or through an already unlocked
   Field Kit technique.

### Mandatory route

| Step | Area | Exact requirement |
|---:|---|---|
| 0 | Shared fissure tunnel | Take RED's branch from `(6,22)` to trial pad `(7,1)`. |
| 1 | Upper Basalt Passage | Solve `S1` `(3,6)`, then `S2` `(29,4)`. Push boulder `A` `(13,29)→(19,29)`, `B` `(21,25)→(21,19)` and `C` `(31,17)→(37,17)`. Exit at `(45,3)`. |
| 2 | Abyss Ring | Solve `S3` `(11,4)`, then `S4` `(27,10)`. Take the intended lower-chasm exit at `(41,5)`. |
| 2a | Ember Refuge | Falls land here and preserve all progress. Continue at `(45,5)` or use a safe return pad. |
| 3 | Lower Chasm | SURF to `S5` `(5,6)`, then use the shrine exit `(39,7)`. |
| 4 | Groudon Shrine | Touch the mandatory coloured end seal `Σ` at `(35,11)`, then continue through `(39,5)`. The research archive at `(31,13)` is optional. |
| 5 | Shared sealed antechamber | RED arrives at `(3,21)`; interact with the black door at `(15,5)`. |

Solve all five grey statues in `S1→S5` order. RED uses shuffled true/false
questions. A wrong answer consumes only that question; a new question appears
on the next interaction, while solved statues and positioned boulders stay
solved. Yellow `L1–L3` relics only widen that floor's visible area. The first
reveals roughly one third, the second two thirds and the third removes the
narrow visibility opening.

The marked fall cells in the Upper Basalt Passage `(12,22)`, `(26,18)`,
`(36,12)` and Abyss Ring `(10,24)`, `(18,20)`, `(28,14)`, `(38,10)` lead to
the Ember Refuge; they do not reset the trial.

### Mega Stone, final door, Oak and the KASC terminal

The optional first location for **BLAZIKENITE** is `M` `(33,9)` in the Ember
Refuge. Missing it does not block completion: touching the completed red end
seal permanently records and secures the stone as a last chance. A newly
secured stone is acknowledged again at the black door.

The door requires `5/5` statues, boulders `A`, `B` and `C` on their targets,
and **BEYOND KANTO: ACTIVE**. If anything is missing, it lists each group as
`OK` or `MISSING`, then returns RED to `(6,21)` in the fissure tunnel without
resetting progress. When everything is complete, the Groudon call, blackout
and Oak call record RED's own seal and reveal **TORCHIC** for the next Legacy
Journey.

Fly to Pallet Town, enter Oak's Lab and use the **upper-left KASC terminal**.
Choose **LEGACY**, not the separate ASC RUN entry. Any Pokémon still in the
ordinary Day-Care or Day-Care Plus, including reserved eggs, must be collected
first. Choose the pact, Pokémon Bank rule, item archive rule, Randomizer and
Nuzlocke settings; Left/Right changes a rule value and SELECT explains it.
Read the complete archive/reset summary; the final irreversible confirmation
defaults to **NO**. Nothing is reset before the final **YES**: that
confirmation archives the old run, replaces the current save
with a new Legacy save and places Torchic in Oak's left Lab ball.

[Open RED's complete map guide](docs/guides/hidden-evolution/red.html).

</details>

<details>
<summary><strong>⚠️ FULL SPOILERS — BLUE: Kyogre/water fissure, complete solution and Legacy hand-off</strong></summary>

### Find and enter BLUE's fissure

1. Enter the Hall of Fame. Professor Nera then appears on Cinnabar Island at
   `(6,11)`.
2. Answer **NUGGET HEADWATER**. A wrong answer only starts a 250-walked-step
   cooldown before another attempt.
3. Go beyond Nugget Bridge to Route 24. Face north from `(10,4)` toward the
   long rock wall; the fissure is at `(10,3)`.
4. Before the final door, activate **BEYOND KANTO** through Elm's aide in Oak's
   Lab.
5. Bring **STRENGTH** for the three mandatory switches. **SURF** is required
   only for the optional Mega Stone side path.

### Mandatory route

| Step | Area | Exact requirement |
|---:|---|---|
| 0 | Shared fissure tunnel | Take BLUE's branch from `(26,22)` to trial pad `(27,1)`. |
| 1 | Frost Threshold | Reach the exit `(25,3)`; its floor lights are optional. |
| 2 | Frost Hall | Solve `S1` `(25,22)`. Push boulder `H` `(13,25)→(27,25)` onto the Hall switch, then leave at `(41,17)`. |
| 3 | Glacier Maze | Solve `S2` `(11,5)`, then `S3` `(37,31)`. Push boulder `E` `(29,25)→(35,25)` onto the Ice switch; exit at `(49,13)`. |
| 4 | Tidal Depths | Solve west `S4` `(3,19)`, then east `S5` `(47,9)`. Push boulder `T` `(35,19)→(41,19)` onto the Depths switch; exit at `(41,7)`. |
| 5 | Kyogre Shrine | Touch the mandatory coloured end seal `Σ` at `(19,3)`, then continue through `(37,7)`. The archive at `(19,9)` is optional. |
| 6 | Shared sealed antechamber | BLUE arrives at `(15,21)`; interact with the black door at `(15,5)`. |

Solve the five grey statues in `S1→S5` order. BLUE uses shuffled three-choice
questions; the question order and correct answer position remain stable for
that save. A wrong answer produces a fresh question next time and does not
erase solved statues or switches. Yellow `L1–L3` relics only expand local
visibility and are never mandatory.

The six red `X` ice holes are `(41,6)`, `(42,7)`, `(4,16)`, `(3,17)`,
`(29,28)` and `(30,29)`. A fall returns BLUE to the start of the Glacier Maze
without removing statue or switch progress.

### Mega Stone, final door, Oak and the KASC terminal

The optional first location for **SWAMPERTITE** is `M` `(21,29)` in the Tidal
Depths, reached through the SURF side path. Missing it does not block
completion: the completed blue end seal permanently records and secures the
stone as a last chance.

The door requires `5/5` statues, the east Depths `S5` safeguard, all three
switches `HALL`, `ICE` and `DEPTHS`, and **BEYOND KANTO: ACTIVE**. It lists
every missing item before returning BLUE to `(26,21)` in the fissure tunnel,
without resetting progress. Success plays the Kyogre call, blackout and Oak
call, records BLUE's own seal and reveals **MUDKIP** for the next Legacy
Journey.

At Oak's Lab, use the **upper-left KASC terminal** and choose **LEGACY**.
Collect every Pokémon and reserved egg from the ordinary Day-Care and Day-Care
Plus first. Configure the pact, Pokémon Bank, item archive, Randomizer and
Nuzlocke choices; Left/Right changes rule values and SELECT opens help. Read
the complete archive/reset summary; the final irreversible confirmation starts
on **NO**. Only the final **YES** archives the old run, replaces the current
save with a new Legacy save and places Mudkip in Oak's left Lab ball.

[Open BLUE's complete map guide](docs/guides/hidden-evolution/blue.html).

</details>

<details>
<summary><strong>⚠️ FULL SPOILERS — GREEN: Rayquaza/grass fissure, complete solution and Legacy hand-off</strong></summary>

### Find and enter GREEN's fissure

1. Enter the Hall of Fame. Professor Linden then appears in Pewter City at
   `(8,3)`.
2. Answer **MOON APPROACH**. A wrong answer only starts a 250-walked-step
   cooldown before another attempt.
3. On Route 3, face north from `(41,4)` toward the long wall between Pewter
   and Mt. Moon; the fissure is at `(41,3)`.
4. Before the final door, activate **BEYOND KANTO** through Elm's aide in Oak's
   Lab.
5. Bring the **Cascade Badge** and a valid **CUT** field user, or an already
   unlocked Field Kit CUT technique. CUT is not consumed.

### Mandatory route

| Step | Area | Exact requirement |
|---:|---|---|
| 0 | Shared fissure tunnel | Take GREEN's branch from `(46,22)` to trial pad `(47,1)`. |
| 1 | Mist Threshold | Reach the exit `(55,5)`. The shortcut at `(29,15)` activates only after completing the route. |
| 2 | Root Grove | Solve `S1` `(21,35)`, then `S2` `(55,17)`; exit at `(53,3)`. |
| 3 | Veiled Grove | Solve `S3` `(5,25)`. At the Root Gate `(22,23)`, use at least `2/5` statue memories plus Cascade Badge and CUT to open the block at `(12,10)`. Solve `S4` `(45,21)` and `S5` `(39,35)`. At the Canopy `(53,5)`, use `5/5` to open `(27,3)`; exit at `(57,9)`. |
| 4 | Rayquaza Shrine | Touch the mandatory coloured end seal `Σ` at `(45,11)`, then continue through `(51,3)`. The archive at `(31,23)` is optional. |
| 5 | Shared sealed antechamber | GREEN arrives at `(27,21)`; interact with the black door at `(15,5)`. |

Solve the grey statues in `S1→S5` order. GREEN uses shuffled number and
true/false questions. A wrong answer only replaces the current question; it
does not erase awakened statues. The game's “memories” are exactly this saved
statue count—there is no separate collectible. Yellow floor-light relics only
expand local visibility and never count toward `2/5`, `5/5` or the ending.

### Mega Stone, final door, Oak and the KASC terminal

The optional first location for **SCEPTILITE** is `M` `(13,15)` in the Veiled
Grove; its hint is at `(19,19)`. Missing it does not block completion: the
completed green end seal permanently records and secures the stone as a last
chance.

The door requires `5/5` statues, `ROOT GATE: OK`, `CANOPY: OK` and **BEYOND
KANTO: ACTIVE**. It reports any missing condition before returning GREEN to
`(46,21)` in the fissure tunnel without resetting progress. Success plays the
Rayquaza call, blackout and Oak call, records GREEN's own seal and reveals
**TREECKO** for the next Legacy Journey.

At Oak's Lab, use the **upper-left KASC terminal** and choose **LEGACY**.
Collect every Pokémon and reserved egg from the ordinary Day-Care and Day-Care
Plus first. Configure the pact, Pokémon Bank, item archive, Randomizer and
Nuzlocke choices; Left/Right changes rule values and SELECT opens help. Read
the complete archive/reset summary; the final irreversible confirmation starts
on **NO**. Only the final **YES** archives the old run, replaces the current
save with a new Legacy save and places Treecko in Oak's left Lab ball.

[Open GREEN's complete map guide](docs/guides/hidden-evolution/green.html).

</details>

## Heritage events and the Event Archive

<details>
<summary><strong>⚠️ SPOILER — What does READY mean in the Event Archive?</strong></summary>

**READY means unlocked; it is not a claim button.**

In Festival Cups mode, visit the relevant city's Cup host and win the
three-round bracket. In Roaming Hunts mode, search the profile's suitable
habitats. The current source now adds this instruction directly to an
unclaimed READY entry.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: where are all five Heritage Cups?</strong></summary>

| Cup | Unlock | Host location | One-time prize |
|---|---|---|---|
| University Cup | 2 badges | Cerulean City | Lv.15 Magikarp: Splash, Dragon Rage |
| Stamp Sky Cup | 2 badges | Celadon City | Lv.25 Fearow with Pay Day |
| Balloon Cup | Thunder Badge | Vermilion City | Lv.5 Pikachu with Fly |
| Stamp Fire Cup | 4 badges | Celadon City | Lv.40 Rapidash with Pay Day |
| Wave Cup | Soul Badge | Fuchsia City | Lv.5 Pikachu with Surf |

Each Cup contains three consecutive themed opponents and heals the party
between rounds. Full party/PC storage reserves the already selected prize.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do Roaming Hunts work?</strong></summary>

Set **HERITAGE EVENTS = ROAMING HUNTS**. The same five historical Pokémon
wander suitable habitats:

- water: Routes 19-21 and every Seafoam floor;
- route: grass Routes 1-25;
- electric: Routes 9, 10, 11, 16, Viridian Forest and Power Plant;
- fire: Routes 7, 8, 16, 17, 18 and every Pokémon Mansion floor.

The target's map, HP, status and fixed DVs persist. It may move after a map
change, can optionally flee on its first action and recovers after three map
visits when knocked out.

</details>

<details>
<summary><strong>⚠️ SPOILER — What does the Event Archive preserve?</strong></summary>

It records every distribution's original level, moves, source and obtained
location across Ascendant Cycles. Event Pokémon carry provenance, a battle
rosette and an **EVENT INFO** party command.

A full party and PC reserve one prize in the Archive until storage is
available. Mew is handled separately as the mythic finale.

</details>

## Post-game, legends and facilities

<details>
<summary><strong>⚠️ SPOILER — What is the main post-game order?</strong></summary>

| Stage | Requirement | Level |
|---|---|---:|
| Master Circuit | First Hall of Fame | 76-90 |
| Apex Elite Four/Champion | All 8 Master crests | 90-100 |
| Legendary Hunt | Apex Champion | 80-95 |
| Crown Gyms | Catch Lugia and Ho-Oh | 100 |
| Crown Elite Four/Champion | All 8 Crown wins | 100 |
| Frontier, Factory, S.S. Anne, Johto Masters | Crown Champion | 100 |
| Mew investigation | Crown, research and enabled event completion | 5 or 100 |
| Ascendant Cycle | All major enabled systems completed | 100 |

Master Leaders can be challenged in any order. After a boss fight, that
Leader uses the same step-based recovery system as rematch trainers.

</details>

<details>
<summary><strong>⚠️ SPOILER — When do bosses use Mega Evolution?</strong></summary>

Enemy Mega Evolution defaults to Ascendant's post-game bosses. Master, Apex
and Crown battles use authored six-Pokémon plans and the strongest allowed AI;
repeat meetings rotate deterministic team orders. Master and Apex teams have
no legendary Pokémon. Crown teams may use legends only after their encounters
are available.

The Randomizer may change species and moves but does not remove the boss
battle's intended size, level, rules, AI, reward or progression.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: legendary unlock order and locations</strong></summary>

With default APEX settings, all legendary encounters remain sealed until the
Apex Champion:

1. Articuno, Zapdos and Moltres awaken at level 80 in their original areas.
2. Mewtwo awakens at level 90 in Cerulean Cave.
3. Raikou, Entei and Suicune roam Kanto grass routes at level 85. The Research
   Log shows their latest tracked route; a visible overworld encounter and a
   1-in-32 grass replacement are both possible.
4. Catch all three birds to reveal Lv.95 Lugia in Seafoam Islands.
5. Catch all three beasts to reveal Lv.95 Ho-Oh at Pokémon Tower's summit.
6. Catch Lugia and Ho-Oh to open the Crown Circuit and reveal Lv.90 Celebi in
   Viridian Forest.
7. After the Crown Champion, complete every enabled legend, all Oak research
   reports and Rocket Resurgence. Follow Oak, Mr. Fuji and the Cinnabar fossil
   room to reveal Mew on Route 24.

Mew is Lv.100 in Ascendant profile or a fixed-DV Lv.5 historical distribution
with Pound. Knocking out or fleeing from a legend never deletes it; only
capture completes the encounter.

Birds and Mewtwo can individually be set to APEX, VANILLA or OFF. VANILLA
keeps their original Lv.50/Lv.70 timing. Other legends and Mew have separate
ON/OFF switches; disabled requirements are skipped.

</details>

<details>
<summary><strong>⚠️ SPOILER — What are Leader missions and Oak's research assignments?</strong></summary>

After Apex, each Leader offers a personal themed-rematch mission. Completing
it gives a rare reward and unlocks that Leader's signature roster variant.

Oak's Lab scientist tracks eight sequential assignments:

1. Win 5 field rematches.
2. Raise 3 trainers to Expert.
3. Earn 4 Master crests.
4. Catch 3 enabled legends.
5. Complete 4 Leader missions.
6. Win 3 Frontier rounds.
7. Defeat all 4 Rocket Resurgence units.
8. Defeat the Crown Champion.

Disabled systems are skipped and full-Bag rewards are reserved.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: Rocket Resurgence locations</strong></summary>

After Apex:

1. Power Plant — stop the legendary-energy relay.
2. Silph Co. top floor — defeat the administrator.
3. Pokémon Tower — confront the spirit experiment.
4. Viridian Gym — defeat Giovanni's level-100 control experiment.

The storyline can be disabled without blocking the rest of the mod.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do the Frontier, Factory and S.S. Anne work?</strong></summary>

After the Crown Champion:

- **Ascendant Battle Frontier:** three consecutive level-100 battles. Rules
  rotate through Open, No Item, Trio, Endurance, Set Style and Kanto Purist.
  A clear awards 3 Frontier Points, or 5 with no faint. Every fifth clear
  awards a Master Ball; other clears award PP Up.
- **Battle Factory:** draft exactly three of six changing level-100
  non-legendary rentals and clear three no-item battles. Rewards 4 points, or
  6 with no rental faint. The original party is restored after the run.
- **S.S. Anne Grand Tour:** five rotating level-100 no-item decks, healing
  after decks 2 and 4. A clear awards 8 points; the next voyage opens after
  4096 actual walking steps.

A Frontier Festival world event doubles Frontier Point awards.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do Johto Masters and the random shiny reward work?</strong></summary>

After the first Hall-of-Fame entry, defeat Silver, Kris and Gold consecutively
at level 100 with the Bag sealed. The team heals before each round. Every
additional run requires another full Elite-Four-and-Champion clear and starts
again at Silver; Gold cannot be repeated directly.

Gold awards exactly one genuine-DV shiny chosen uniformly from all 251
species. Starters, fossils, Mew, Celebi and every legend each have the same
1/251 chance. Duplicates are allowed. Full storage reserves the already chosen
species.

The repeatable first clear also awards the KANTO ASCENDANT title and golden
Trainer Card treatment.

</details>

<details>
<summary><strong>⚠️ SPOILER — What are world events?</strong></summary>

After the Hall of Fame, Kanto rotates events lasting 2048 walked steps:

- Training Rush — trainer recovery and silent growth advance twice per step.
- Johto Migration — a rare Johto species appears on one announced route.
- Golden Wind — every wild encounter gains two shiny rolls.
- Frontier Festival — Frontier Point awards are doubled.

The current event appears in **ASCENDANT → JOURNAL**.

</details>

<details>
<summary><strong>⚠️ SPOILER — What survives an Ascendant Cycle / New Game Plus?</strong></summary>

Starting a double-confirmed Cycle resets Master/Apex/Crown circuits, circuit
research, Leader missions and Rocket progress. It preserves the base story,
party, inventory, captured legends, Johto specimens and eggs, permanent
titles, facility records and Event Archive claims.

Replayed major bosses are level 100. ROTATING cycles use No Items, Set Style,
Trio and Kanto Purist in sequence; every rotating rule also seals items.
NORMAL removes extra restrictions while retaining level-100 teams.

</details>

<details>
<summary><strong>⚠️ FULL SPOILER — How does Oak's Legacy Journey partner choice work?</strong></summary>

The special choice appears only in an active true Legacy Journey; a normal
Red, Blue or Yellow opening is unchanged. In the Red/Blue lab, the left ball
gives the current character's Hoenn starter—RED gets Torchic, BLUE gets
Mudkip and GREEN gets Treecko—but only if that same character's rift seal was
earned in an earlier Legacy life. Before then the ball stays visible and Oak
explains that it is reserved, perhaps for the next life. Another character's
seal never unlocks it. No Sinnoh starter is offered. The middle ball
opens a graphical Pokédex-style catalogue: **Balanced** is a curated early or
lower-power pool, while **Free** contains the 129 lowest-stage or standalone
canonical species within #001-251. A baby stage replaces its in-range
evolution (Pichu rather than Pikachu); Gastly and Ditto are legal, Gengar and
Dragonite are not. It requires two confirmations and marks only the partner actually
received as seen and owned.

The rival claims and hides the right ball first with character-aware dialogue,
but its species and evolution line are resolved only after the player's final
choice. The partner, rival line, Dex entry and archive state are then saved as
one durable atomic decision. Yellow retains its authored Pikachu-or-catalogue
branch and the rival's Eevee logic. Completed RED, BLUE and GREEN paths also
award permanent Legacy titles; completing all three preserves the Legacy Pass
title.

</details>

<details>
<summary><strong>⚠️ SPOILER — Where can the original Kanto starters appear early in an eligible replay?</strong></summary>

These are rare, additional early habitats in an eligible Legacy replay only;
ordinary new games remain unchanged:

- **Bulbasaur:** Viridian Forest grass, Lv. 5, 2%.
- **Charmander:** Route 4 grass east of Mt. Moon, Lv. 7, 2%.
- **Squirtle:** Route 24 grass north of Nugget Bridge, Lv. 9, 2%.

Each species is guaranteed by the 50th eligible encounter at the latest.
In **KANTO 151 WILD** mode, the later authored sources remain available as
well: Safari Zone East for Bulbasaur, Seafoam Islands B2F for Squirtle and
Victory Road 3F for Charmander.

</details>

## Menus, art, followers and troubleshooting

<details>
<summary><strong>⚠️ SPOILER — Where can I see my current objective instead of guessing?</strong></summary>

- **ASCENDANT → RESEARCH ATLAS:** current Oak objective, known trainer
  cooldowns/ranks/locations, exact loot gates, TM queue and revealed habitats.
- **ASCENDANT → JOURNAL:** legends and roamer routes, titles, type mastery,
  world event and Johto Masters records.
- **ASCENDANT → WORLD:** Early Johto current, primal-trace progress, Mythic
  Signals and the next optional Signals objective.
- **Oak's Lab scientist:** Research Log and exact post-game objective.
- **Hall-of-Fame console, right side:** Crown Archive.
- **ASCENDANT → NATIONAL DEX:** all discovered #001-251 entries after the
  Driftglass upgrade.
- **ASCENDANT → SHINY DEX:** revealed shiny statistics.
- **ASCENDANT → EVENT ARCHIVE:** Heritage profiles and claims.
- **ASCENDANT → MEGA STONES:** Stone Case status.
- **Route 5 machine:** evolutions, TM queue, Move Deleter, Move Reminder and
  Frontier Exchange after unlock.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do SELECT, the Field Kit and Bag sorting work?</strong></summary>

In the overworld, tap **SELECT** to use the saved favourite Field Kit tool, or
hold **SELECT** for about 0.35 seconds to open the complete Field Kit. Inside
the kit:

- **A** uses the highlighted tool;
- **SELECT** assigns it as the favourite quick action;
- **B** closes the kit.

Cut checks the tile in front of the player, Fly opens its map, Surf and
Strength use their normal field checks, the Bicycle toggles normally, and the
Itemfinder runs immediately. If the selected action cannot be used in the
current position, the game gives a short explanation instead of silently
switching to the Bicycle.

Inside the Bag, **SELECT** keeps its classic sorting role: mark an item, move
the cursor and press **SELECT** again to place it. **B** cancels an active move
or exits when nothing is being moved. **START** opens the context help.

</details>

<details>
<summary><strong>⚠️ SPOILER — What changed on the Trainer Card in 6.5.7?</strong></summary>

The native Trainer Card entry now opens one approved 640×400 HD standard card
instead of enlarging the old low-resolution layout. It shows the fixed
**KANTO ASCENDANT** brand, selected Red/Green/Blue identity, active earned
title, money, play time and all eight Kanto Leader/badge slots on one screen.
The player and Leader portraits use their existing 128-pixel masters.

Giovanni remains a completely black silhouette until the save contains a real
Giovanni victory flag. Adding or obtaining an Earth Badge by itself does not
reveal him. This applies to every edition and New Game Plus cycle.

Version 6.5.7 contains only this fixed standard card. Unlockable card designs,
the larger title expansion and cards shown around scheduled battles remain
future work and are not silently enabled by this hotfix.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do followers work?</strong></summary>

Open **Start → Pokémon**, select a party member and choose **Follower**.
Ascendant's integrated system supports up to six party followers. Do not
enable PokéPC Followers, Followers EX or their Voxel merge beside Ascendant;
the reviewed 0.1.90 loader blocks that combination before both can initialize.

Ascendant bundles normal and Shiny six-pose follower sheets for every Kanto
species #001-151, every Johto species and Gorochu. An owned Pokémon's actual
DV-based Shiny state selects its matching follower sheet. A missing or damaged
Kanto Shiny sheet falls back to the normal sheet of that same species instead
of changing identity or crashing.

This applies to Pokémon that already belong to the player. Free-roaming Wilds
on engines 0.1.96 and 0.1.98 do not know the later battle Pokémon's DVs yet, so
Ascendant does not pre-roll or advertise a Shiny colour in the overworld.

In Yellow, the native partner Pikachu remains follower one with its original
mood and dialogue; it cannot be replaced in that authored story slot. To add
another species, open **Start → Pokémon**, choose that party member, then
**Follower → Custom Add/Add Follower**. The action automatically increases the
visible count to follower two; alternatively choose a count from two through
six in Ascendant's follower options. If partner Pikachu is boxed or fainted,
its authored first slot stays reserved but the independently selected extras
continue following: count two shows one extra, and count six shows up to five.
The first extra temporarily leads the visible chain. Healing or withdrawing
Pikachu prepends it as follower one again without duplicating or reordering
the saved extras. Professor Oak still catches the canonical level-5 Pikachu
and the lab gift remains Pikachu.

Version 6.5.7 restores the missing emotion window by marking exactly the
level-5 Pikachu given by Oak's original three-argument Lab command. Another
Pikachu does not gain partner emotions. The marker remains on the same Pokémon
while it is fainted, stored or later evolves into Raichu or Gorochu. An
affected older save with exactly one eligible self-owned Pikachu, Raichu or
Gorochu is repaired automatically; when several candidates make the identity
ambiguous, Ascendant does not guess.

</details>

<details>
<summary><strong>⚠️ SPOILER — What do the art options change?</strong></summary>

- Exact path: **START → ASCENDANT → OPTIONS → VISUALS → CHARACTERS / TRAINERS**.
- **FIELD CHARACTERS:** changes only the overworld walking sheets.
- **TRAINER PORTRAITS:** switches Red, Blue and Green between `CRYSTAL HD`
  and `ORIGINAL` across the selector, Trainer Card, normal 2D front/back,
  rival, tutorial and other 2D identity surfaces. Staged 3D and throw art
  remains owned by the active reviewed renderer.
- **JOHTO ART:** bundled Crystal art or four-shade Kanto fallback for #152-251.
- **KANTO CRYSTAL ART:** battle art for #001-151.
- **DEX SPRITES:** independently switches Kanto Pokédex and party **STATS**
  portraits between active Red/Blue/Yellow original art and static Crystal
  frame one. Johto uses its species-authentic bundled Crystal portrait because
  Red/Blue/Yellow have no native #152-251 art.
- **CRYSTAL ANIMATION:** animates normal/shiny #001-251 battle fronts.
- **BAG / STORAGE → BOX ICONS:** `CURRENT` keeps the established icons in the
  right-hand 5×4 Box grid. The default-off `HGSS WALKERS` choice uses frame
  zero of the already bundled 16×96 Wilds walking sheet when an exact
  normal/Shiny species asset exists. The large selected-Pokémon preview on the
  left never changes; Gorochu, unsupported forms and missing sheets fall back
  to the current icon. No new art files are added by 6.5.7, and the existing
  Wilds/follower attribution in `THIRD_PARTY_NOTICES.md` remains authoritative.
- Reviewed voxel renderers use their dedicated staged-3D assets. Gorochu and
  all official Mega forms have separate sharp 96×96 masters.

DEX SPRITES does not change battles, followers, evolutions, trades, Hall of
Fame screens or the small animated party icons.

</details>

<details>
<summary><strong>⚠️ SPOILER — Why are cries, followers or sprites missing or wrong?</strong></summary>

First report:

- Kanto Ascendant version;
- Red, Blue or Yellow;
- platform and renderer (2D or Voxel);
- complete enabled mod list;
- exact species and front/back/follower context;
- screenshot or short clip.

Ascendant bundles species-authentic legacy cries for #152-251, preserves
external Gen-II/Gorochu audio and fills only missing cries.
It also includes mobile-ready follower sheets, so clearing or rebuilding a
third-party graphics cache may be necessary after updating an older wrapper.

Do not assume that disabling a mod in the menu removes every cached graphic.
Retest after a full restart with only Ascendant enabled, then add graphics mods
one at a time.

</details>

<details>
<summary><strong>⚠️ SPOILER — How should I report a reproducible bug?</strong></summary>

Use [GitHub Issues](https://github.com/Roxas2712/kanto-ascendant/issues) and
include:

1. exact Ascendant version;
2. edition, operating system and renderer;
3. enabled mod list and relevant options;
4. what you expected and what happened;
5. exact steps to reproduce;
6. save file when progression is involved;
7. screenshot/video and log when visual or crash-related.

Progress counters, roaming routes and many compatibility conflicts cannot be
proven from a screenshot alone.

</details>

## Current support-report status

<details>
<summary><strong>Verified reports reviewed on 6 August 2026</strong></summary>

| Report | Status |
|---|---|
| Master Circuit shows 6/8 after eight wins | **Fixed in current GitHub source.** Gym clears are recorded at battle end, and affected saves repair missing crests from victory-only boss history. |
| Lt. Surge only repeats Gorochu dialogue after the evolution | **Fixed in current GitHub source.** Completed owners return to the normal rematch conversation. |
| Event Archive says READY but nothing happens | **Clarified in current GitHub source.** READY means unlocked; the details page now directs Festival players to the Cup city or Roaming players to habitats. |
| Randomized Master battles | **Confirmed working.** Randomizer species/moves remain authoritative while Ascendant progression is preserved. |
| Red Gyarados appears with normal colours | **Fixed in 6.0.4.** Guaranteed and bonus-roll shinies now receive their shiny state before Crystal, Voxel or another battle-art wrapper selects the visible sprite. |
| Crystal is selected but Pokémon → STATS still shows old art | **Fixed in 6.0.4.** The party status portrait now follows the independent DEX SPRITES selector in Red, Blue and Yellow. |
| Johto Signals start question returns or appears over an existing repaired save | **Fixed in 6.0.4.** YES/NO is saved immediately and the question is deferred until the selected slot has fully loaded. |
| Early-route Johto Pokémon appear around level 12-15 beside level 2-6 Kanto encounters | **Fixed in 6.0.5.** Ordinary Johto encounters, including permanent researched habitats, use the rounded, weighted route average plus 2-5 levels in classic 2D and Wilds; authored primal encounters keep their story levels. |
| Story Sabrina's Alakazam did not Mega Evolve | **Expected.** Enemy Mega defaults to post-game Ascendant bosses. |
| Mankey/Nidoran location confusion | **Documented above.** Active KANTO 151 adds Mankey to Route 5 in every edition; native Route 22 remains edition-specific. |
| RC9/standalone `trainer_rematch` conflicts with RC10 | **Expected identity guard.** Move the old RC9 folder out of `mods`, then enable RC10 as documented above. |

The packaged release and current source can temporarily differ. The
[release page](https://github.com/Roxas2712/kanto-ascendant/releases/latest)
states which fixes are included in the downloadable package.

</details>
