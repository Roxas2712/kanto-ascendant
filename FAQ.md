# Kanto Ascendant FAQ and Spoiler Guide

This is the public reference for Kanto Ascendant. It applies to Red, Blue and
Yellow and is maintained from the current mod code, release documentation and
confirmed support reports.

> [!WARNING]
> **Every gameplay FAQ entry may contain spoilers.** Those answers are collapsed
> by default and every gameplay dropdown carries its own spoiler warning.
> Open only the question you want answered. Entries labelled **full spoiler**
> reveal exact locations, requirements or progression. The support-report status
> at the end is spoiler-free.

- [Installation and compatibility](#installation-and-compatibility)
- [Main story, rematches and Kanto 151](#main-story-rematches-and-kanto-151)
- [Johto research, breeding and items](#johto-research-breeding-and-items)
- [Shinies, outbreaks and the red Gyarados](#shinies-outbreaks-and-the-red-gyarados)
- [Mega Evolution, Yellow's partner and Gorochu](#mega-evolution-yellows-partner-and-gorochu)
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
all 251 Kanto/Johto species, breeding, shinies, Mega Evolution, Gorochu and a
large Hall-of-Fame post-game.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do I install or update it?</strong></summary>

1. Download the current `.modpkg` from the
   [latest GitHub release](https://github.com/Roxas2712/kanto-ascendant/releases/latest).
2. Import it through the Gen 1 Recomp launcher.
3. Restart the game and enable **Kanto Ascendant** under **MODS**.

Existing Red, Blue and Yellow saves are supported. Do not replace or delete
your save file when updating.

</details>

<details>
<summary><strong>⚠️ SPOILER — The launcher says trainer_rematch is already installed, but Kanto Ascendant is missing from the list. What do I do?</strong></summary>

`trainer_rematch` is Kanto Ascendant's permanent internal ID. A stale or
incomplete installed copy can therefore block a new import even when its
visible name is missing.

Close the launcher and find its actual `mods` directory:

- Portable mode: the `mods` folder beside the game executable
- Windows standard mode: `%APPDATA%\LOVE\pokemon-love2d\mods`
- macOS: `~/Library/Application Support/LOVE/pokemon-love2d/mods`
- Linux/SteamOS: `~/.local/share/love/pokemon-love2d/mods`

Move the entire stale `trainer_rematch` folder **out of the `mods` directory**,
restart the launcher and import the current package again. Merely renaming the
folder while leaving it inside `mods` can still expose the same manifest ID.
Do not touch `save.lua`, save slots or backups.

Portable Windows handhelds, including an ROG Ally, may use the folder beside
the executable instead of `%APPDATA%`. If neither documented location exists,
that is launcher/operating-system support rather than an Ascendant gameplay
defect.

</details>

<details>
<summary><strong>⚠️ SPOILER — Which other mods are compatible?</strong></summary>

Kanto Ascendant is designed to coexist with the Gen-I Randomizer, PokéPC
Followers, Followers EX, Wilds of Kanto, Dramatic Shape/Voxel, Crystal
Animated Sprites and dedicated shiny-indicator mods.

Important limits:

- Do not enable another complete Johto species registry at the same time.
- Kanto Ascendant's KANTO 151 option owns its overlapping encounter slots.
- The Randomizer remains authoritative for randomized species and moves.
  Ascendant preserves boss team size, levels, rules, AI, rewards and
  progression.
- Dedicated indicator mods own the shiny presentation when detected, avoiding
  doubled sparkles and sounds.
- Gorochu registered by another compatible graphics/audio provider keeps that
  provider's asset; Ascendant fills only missing assets.

</details>

<details>
<summary><strong>⚠️ SPOILER — Do option changes apply immediately?</strong></summary>

Most runtime options do. Encounter-table options such as **KANTO 151** are
loaded while the mod starts and require a restart. The in-game KANTO 151
status page shows both the loaded and selected mode when they differ.

</details>

## Main story, rematches and Kanto 151

<details>
<summary><strong>⚠️ SPOILER — Does Ascendant replace the original Kanto story?</strong></summary>

No. The original story, Gyms, Team Rocket, Elite Four and first Hall of Fame
remain familiar. Some mechanics, encounter availability and early field
rematches are active during the story, but the main boss overhaul begins
after the first Hall of Fame.

Dark and Steel types and the Generation-II type chart are active. Magnemite
and Magneton are Electric/Steel. This can change individual matchups without
turning the original story into a completely different campaign.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do field-trainer rematches work?</strong></summary>

After a trainer is defeated, they train for a configurable **151-2510 completed
player steps**. Talking early shows the exact remaining count. When ready,
talk again to accept a class-specific rematch.

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

Master and Legend field trainers receive an overworld sparkle. Rematches give
no prize money and Pay Day payouts are disabled.

</details>

<details>
<summary><strong>⚠️ SPOILER — What can field rematches drop?</strong></summary>

Only one reward band is rolled per victory. An ineligible band becomes no
drop; it is not rerolled.

| Item | Balanced | Generous | Requirement |
|---|---:|---:|---|
| Nugget | 15% | 15% | None |
| Rare Candy | 5% | 5% | Enemy average level 20 |
| PP Up | 10% | 15% | Enemy average level 35 |
| EXP.ALL | 5% | 5% | Average level 40; unique |
| Max Revive | 8% | 12% | Enemy average level 50 |
| Master Ball | 1% | 2% | Average level 80 and Apex Champion defeated |

At full eligibility the total item chance is 44% in Balanced and 54% in
Generous. A full Bag never destroys a reward: that trainer reserves it.

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
<summary><strong>⚠️ SPOILER — Can all original 151 Pokémon be obtained in one save?</strong></summary>

Yes, when **KANTO 151** is set to **REWARDS** or **WILD**.

- **REWARDS** is the default. Version exclusives share habitats, while the
  other starters and missing fossil are Master Leader rewards.
- **WILD** also adds rare wild starters, fossils, Aerodactyl and former trade
  evolutions.
- **OFF** disables Ascendant's catchability, evolution and renewable Moon
  Stone additions.

Mew is never a random encounter. It remains a dedicated late-game
investigation.

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

## Johto research, breeding and items

<details>
<summary><strong>⚠️ SPOILER — When do Johto Pokémon start appearing?</strong></summary>

The first Hall of Fame places Elm's aide in Oak's Lab. Complete all three
starter trials:

| Trial | Location | Reward |
|---|---|---|
| Verdant Trial | Celadon City | Chikorita |
| Ember Trial | Cinnabar Island | Cyndaquil |
| Torrent Trial | Cerulean City | Totodile |

After all three, every won ordinary field rematch awards one still-missing
Johto base family. There are 40 normal specimen tracks; the first further
rematch after all 40 awards Larvitar.

Once a family is researched, its base species also establishes a renewable
2% Kanto habitat. Multiple eligible families sharing a location split the
same combined 2%; they do not each receive 2%.

</details>

<details>
<summary><strong>⚠️ SPOILER — Full spoiler: all researched Johto habitats</strong></summary>

| Base species | Habitat | Level |
|---|---|---:|
| Chikorita | Route 24 grass | 18 |
| Cyndaquil | Pokémon Mansion B1F | 22 |
| Totodile | Seafoam Islands B2F | 22 |
| Sentret | Route 1 grass | 12 |
| Hoothoot | Route 2 grass | 14 |
| Ledyba | Viridian Forest | 14 |
| Spinarak | Viridian Forest | 15 |
| Chinchou | Route 20 water | 25 |
| Natu | Route 22 grass | 18 |
| Mareep | Route 8 grass | 20 |
| Marill | Route 6 grass | 18 |
| Sudowoodo | Route 10 grass | 24 |
| Hoppip | Route 5 grass | 16 |
| Aipom | Route 16 grass | 24 |
| Sunkern | Route 24 grass | 17 |
| Yanma | Safari Zone Center | 25 |
| Wooper | Route 19 water | 22 |
| Murkrow | Route 7 grass | 22 |
| Misdreavus | Pokémon Tower 7F | 28 |
| Unown | Mt. Moon B2F | 18 |
| Wobbuffet | Cerulean Cave 1F | 48 |
| Girafarig | Route 18 grass | 28 |
| Pineco | Viridian Forest | 16 |
| Dunsparce | Diglett's Cave | 22 |
| Gligar | Victory Road 1F | 38 |
| Snubbull | Route 8 grass | 21 |
| Qwilfish | Route 21 water | 28 |
| Shuckle | Mt. Moon B2F | 20 |
| Heracross | Route 15 grass | 27 |
| Sneasel | Seafoam Islands B4F | 32 |
| Teddiursa | Route 10 grass | 24 |
| Slugma | Pokémon Mansion B1F | 30 |
| Swinub | Seafoam Islands B2F | 30 |
| Corsola | Route 19 water | 27 |
| Remoraid | Route 21 water | 24 |
| Delibird | Seafoam Islands B4F | 31 |
| Mantine | Route 20 water | 30 |
| Skarmory | Victory Road 2F | 40 |
| Houndour | Route 7 grass | 23 |
| Phanpy | Route 11 grass | 22 |
| Stantler | Safari Zone East | 27 |
| Smeargle | Route 16 grass | 25 |
| Miltank | Safari Zone Center | 28 |
| Larvitar | Victory Road 3F | 45 |

The habitat becomes active only after that family, starter trial or Larvitar
finale is recorded.

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

After the Crown Champion, defeat Silver, Kris and Gold consecutively at level
100 with the Bag sealed. The team heals before each round.

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

## Menus, art, followers and troubleshooting

<details>
<summary><strong>⚠️ SPOILER — Where can I see my current objective instead of guessing?</strong></summary>

- **ASCENDANT → RESEARCH ATLAS:** current Oak objective, known trainer
  cooldowns/ranks/locations, exact loot gates, TM queue and revealed habitats.
- **ASCENDANT → JOURNAL:** legends and roamer routes, titles, type mastery,
  world event and Johto Masters records.
- **Oak's Lab scientist:** Research Log and exact post-game objective.
- **Hall-of-Fame console, right side:** Crown Archive.
- **ASCENDANT → JOHTO POKéDEX:** specimen, egg and habitat progress.
- **ASCENDANT → SHINY DEX:** revealed shiny statistics.
- **ASCENDANT → EVENT ARCHIVE:** Heritage profiles and claims.
- **ASCENDANT → MEGA STONES:** Stone Case status.
- **Route 5 machine:** evolutions, TM queue, Move Deleter, Move Reminder and
  Frontier Exchange after unlock.

</details>

<details>
<summary><strong>⚠️ SPOILER — How do followers work?</strong></summary>

Enable a compatible follower provider such as PokéPC Followers or its Voxel
merge. Then open **Start → Pokémon**, select a party member and choose
**Follower**.

Ascendant bundles normal and shiny six-pose follower sheets for every Johto
species plus Gorochu. Missing or damaged individual sheets use a safe Kanto
silhouette instead of crashing.

The follower mod's old Yellow-to-Charmander conversion is neutralized:
Professor Oak must catch the canonical level-5 Pikachu, the lab gift remains
Pikachu and unrelated level-5 encounters are not rewritten.

</details>

<details>
<summary><strong>⚠️ SPOILER — What do the art options change?</strong></summary>

- **JOHTO ART:** bundled Crystal art or four-shade Kanto fallback for #152-251.
- **KANTO CRYSTAL ART:** battle art for #001-151.
- **DEX SPRITES:** independently switches only Kanto Pokédex fronts between
  active Red/Blue/Yellow original art and static Crystal frame one.
- **CRYSTAL ANIMATION:** animates normal/shiny #001-251 battle fronts.
- Dramatic Shape/Voxel uses dedicated renderer assets. Gorochu and all official
  Mega forms have separate sharp 96×96 masters.

DEX SPRITES does not change battles, followers, summaries, evolutions, trades,
Hall of Fame screens or party icons.

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

Ascendant preserves external Gen-II/Gorochu audio and fills only missing cries.
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
<summary><strong>Verified reports reviewed on 5 August 2026</strong></summary>

| Report | Status |
|---|---|
| Master Circuit shows 6/8 after eight wins | **Fixed in current GitHub source.** Gym clears are recorded at battle end, and affected saves repair missing crests from victory-only boss history. |
| Lt. Surge only repeats Gorochu dialogue after the evolution | **Fixed in current GitHub source.** Completed owners return to the normal rematch conversation. |
| Event Archive says READY but nothing happens | **Clarified in current GitHub source.** READY means unlocked; the details page now directs Festival players to the Cup city or Roaming players to habitats. |
| Randomized Master battles | **Confirmed working.** Randomizer species/moves remain authoritative while Ascendant progression is preserved. |
| Red Gyarados not appearing | **Not yet a confirmed defect.** Verify ASCENDANT shiny mode, event enabled, first Hall of Fame, current 25-win streak and Seafoam B4F; attach the save if all are true. |
| Story Sabrina's Alakazam did not Mega Evolve | **Expected.** Enemy Mega defaults to post-game Ascendant bosses. |
| Mankey/Nidoran location confusion | **Documented above.** Active KANTO 151 adds Mankey to Route 5 in every edition; native Route 22 remains edition-specific. |
| Stale trainer_rematch install on a handheld PC | **Launcher/filesystem support, not a gameplay defect.** Recovery steps are documented above. |

The packaged release and current source can temporarily differ. The
[release page](https://github.com/Roxas2712/kanto-ascendant/releases/latest)
states which fixes are included in the downloadable package.

</details>
