# Kanto Ascendant

Kanto Ascendant turns Kanto into a persistent training world and adds a full
Hall-of-Fame post-game: stronger field trainers, eight Master Gym battles, an
Apex Elite Four, a living legendary event, six Gen-II species and a final
level-100 Crown Circuit. It began as Trainer Rematch; the internal
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
2. They rest and train for **128-256 completed player steps** by default.
3. Talk to them too early to see the exact number of steps remaining, followed
   by their normal post-battle dialogue as a second page.
4. Return when they are ready for a class-specific YES/NO challenge.
5. When first ready, their next rematch is +2 levels stronger. Each completed
   rematch adds another +2 until each Pokémon reaches level 100.
6. A ready trainer keeps training even when ignored. Another invisible
   128-256-step cycle begins in the background; every completed silent cycle
   adds the same +2 growth tier to the next battle while the trainer remains
   continuously available.
7. At the default growth rate, reaching +4, +8, +12 and later strength tiers
   recruits another class-appropriate Pokémon until the party reaches six.
   The chosen evolutionary families stay deterministic for that trainer and
   evolve naturally when its projected rematch level is high enough.

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
| Nugget | 20% | 26% | None |
| Rare Candy | 15% | 20% | Enemy team average level 20 |
| PP Up | 10% | 15% | Enemy team average level 35 |
| EXP.ALL / EP-Teiler | 20% | 25% | Average level 40; unique |
| Max Revive | 8% | 12% | Enemy team average level 50 |
| Master Ball | 1% | 2% | Average level 80 and Apex Champion defeated |

**OFF** disables loot. Only one band is rolled per victory. At full eligibility,
BALANCED has a 74% total item chance and GENEROUS guarantees that one of the
listed bands is rolled. An ineligible result becomes no drop rather than
increasing another item's probability.

The EP-Teiler is the original, fully functional Gen-1 `EXP_ALL`: while carried,
it distributes part of battle experience to the other non-fainted party
members. Once obtained as loot it leaves the table, and Oak's Aide will not
give a duplicate. Afterwards its old band becomes a no-drop result, reducing
the total chance to 54% in BALANCED or 75% in GENEROUS. The Master Ball remains
repeatable but is the rarest reward and cannot drop before the legendary hunt
has opened. Once eligible, it takes about 100 BALANCED or 50 GENEROUS wins on
average to see one; this is an average, not a guarantee.

If the Bag is full, the reward is never destroyed. That individual trainer
keeps it, reminds the player on the next conversation and hands it over as soon
as one Bag slot is available.

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

The new map encounters deliberately reuse the built-in overworld sheets:
`SPRITE_MONSTER` for Raikou, Entei and Suicune, `SPRITE_BIRD` for Lugia and
Ho-Oh, and the small `SPRITE_FAIRY` silhouette for Celebi.

The mod's own **OPTIONS** page can change this per species:

- Articuno, Zapdos, Moltres and Mewtwo: `APEX`, `VANILLA` or `OFF`.
- `VANILLA` makes the selected bird available normally at level 50, or
  Mewtwo at level 70, without requiring the Master/Apex circuits.
- Raikou, Entei, Suicune, Lugia, Ho-Oh and Celebi each have an independent
  `ON/OFF` switch.
- `OFF` removes the encounter and skips it as an unlock requirement. Crown
  boss copies are replaced by suitable non-legendary Pokémon as well.

Knocking out or fleeing from a legendary does not remove it. Only a successful
capture completes that encounter. Saves in which a vanilla legendary was
previously hidden after a KO or flee recover the encounter unless that species
is already marked as owned in the Pokédex.

## New species and moves

The mod expands the Pokédex to 157 and adds:

- Raikou, Entei and Suicune
- Lugia and Ho-Oh
- Celebi
- Aeroblast and Sacred Fire

Every new species has base stats, typing, learnset, TM compatibility, a
self-contained chip cry, Pokédex data, original four-shade front/back pixel art
and its own party icon.

### Optional Crystal battle art

For the authentic Pokémon Crystal front/back sprites, run this once from the
mod directory:

```sh
python3 tools/install_crystal_sprites.py
```

Restart the game afterwards. **LEGEND ART** defaults to `CRYSTAL (LOCAL)` and
uses those files when all required views for a species are installed. Choose
`ORIGINAL 4-SHADE` to switch back at any time. An incomplete or absent Crystal
installation falls back automatically.

The Crystal PNGs are downloaded for personal local use from the Pokémon
Database sprite galleries and are excluded from source and release ZIPs.

## Options

Open **MODS → KANTO ASCENDANT → OPTIONS** for the mod's own configuration
submenu. It contains:

- **LANGUAGE** — automatically follow a compatible German translation, or
  force English/German.
- **MIN REST STEPS** — lower end of the training period (default 128).
- **MAX REST STEPS** — upper end (default 256). Reversed values are normalized.
- **LEVELS / REMATCH** — field-trainer strength gained per completed rematch
  or silent training cycle (default 2; set to 0 to disable level scaling).
- **TEAM GROWTH** — allow thematic party recruitment as trainers gain
  strength tiers (default on).
- **REMATCH LOOT** — `OFF`, `BALANCED` or the more rewarding `GENEROUS`
  rare-item table.
- **LEGEND ART** — prefer locally installed Crystal battle art or force the
  original distributable four-shade sprites.
- Individual encounter rules for all ten legendary Pokémon.

The step clock, trainer recovery, growth, pending loot, circuit wins, roaming
routes and legendary progress are stored under `save.modData.trainer_rematch`.
Base save structures remain compatible if the mod is disabled.

## Installation

1. Download the ZIP from the
   [latest release](https://github.com/Roxas2712/kanto-ascendant/releases/latest)
   and import it through the launcher, or install the mod directory.
2. Restart the game and enable **Kanto Ascendant**.
3. Existing saves work. Old trainer wins receive one initial rest period, and
   existing Pokédex ownership is imported into legendary progression.

This expansion registers Pokédex entries 152-157. A second mod that registers
the same Gen-II species IDs should not be enabled at the same time.

## Credits

- **Kanto Ascendant:** Roxas2712
- **Original Trainer Rematch foundation:** ShaneMcGovernIE
- **Engine and mod interfaces:** Pokémon Gen 1 Recompilation Project

## Development

Run the ROM-free headless suite from the Gen1 Recomp engine checkout:

```sh
POKEPORT_DATA_DIR=tests/fixture_data \
TRAINER_REMATCH_MOD_DIR=../trainer_rematch \
./.tools/luajit-src/src/luajit \
../trainer_rematch/tests/trainer_rematch_test.lua
```

Validate against an imported Kanto data set:

```sh
MODKIT_LUAJIT="$PWD/.tools/luajit-src/src/luajit" \
python3 tools/modkit.py validate ../trainer_rematch --base imported
```

`tools/make_postgame_assets.py` deterministically regenerates all 18 original
four-shade post-game sprite assets. `tools/install_crystal_sprites.py` installs
the optional Crystal front/back views without adding them to release archives.
