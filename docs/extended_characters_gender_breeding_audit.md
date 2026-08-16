# Extended Characters, Gen-II Gender and Breeding — Phase 1 audit

## Scope and source of truth

This is an audit of the Kanto Ascendant 6.5.0 source worktree and its Gen1
Recomp engine checkout.  It makes no implementation change.  `.` below means
the Kanto Ascendant worktree; `../../gen1recomp` means the engine checkout
used by the existing test and ModKit workflow.

The feature package must remain separate from Starfall Lab.  The immediate
integration target is the public `kanto_ascendant` save bucket, after the
6.5.0 identity migration has run.

## 1. Character and rival architecture

### Current representation

* A save owns names and no character identity: `save.player.name` and
  `save.player.rival` are created by `../../gen1recomp/src/core/SaveData.lua`
  in `SaveData.newGame`.  Defaults are `RED` and `BLUE`.
* `../../gen1recomp/src/core/Data.lua` provides the vanilla boot defaults;
  `data.field.boot` can replace names, the start position and the intro
  screens for a total conversion.  It is not a per-save character model.
* Player overworld art comes from `data.field.playerSprites` (with the
  `FieldDefaults.PLAYER_SPRITES` fallback) in
  `../../gen1recomp/src/world/Player.lua`.  Its defaults are `SPRITE_RED`,
  `SPRITE_SEEL` while surfing, `SPRITE_RED_BIKE`, and `SPRITE_BIRD` while
  flying.
* Player battle/intro/card/Hall-of-Fame art resolves through
  `../../gen1recomp/src/pokemon/Sprites.lua:playerPath`.  The existing live
  seam is the `player.sprite` hook; it receives side and purpose (`battle`,
  `intro`, `trainer_card`, `hof`) but not a character identity yet.
* Oak's speech is assembled by `src/ui/OakSpeech.lua` and has an
  `intro.oak_speech.build` hook.  It currently loads the player front picture
  and hardcodes `SPRITE_RED` as the shrink destination.

### Rival role

* Rival maps use `SPRITE_BLUE` and `OPP_RIVAL1`, `OPP_RIVAL2`, or
  `OPP_RIVAL3`; map objects are imported in
  `../../gen1recomp/data/generated/maps.lua`.
* `src/battle/BattleState.lua:newTrainer` correctly treats the three
  `OPP_RIVAL*` classes as a *role* for naming: it overlays
  `save.player.rival` on the trainer name.  This is a useful existing
  separation of name from party class, but visual identity and party choice
  remain fixed.
* `src/script/Commands.lua:rival_battle` selects the normal counter-pick
  roster.  The Yellow branch instead selects parties from `save.rivalStarter`.
  No character identity is passed to either path.
* Vanilla Oak's Lab and Pallet/Route/Tower/Silph/Champion scenes are in
  `data/scripts/oaks_lab.lua`, `data/scripts/story.lua`,
  `data/scripts/story5.lua`, and `data/scripts/pallet_town.lua`.  They use
  the rival role and the standard `OPP_RIVAL*` battle classes, not an
  abstraction for a particular person.
* Daisy is an independent `SPRITE_DAISY` map object.  The family-house and
  flavour scripts remain named `reds_house*`; those names are presentation/
  map identifiers, not evidence that the player must be Red.

### Relevant RED == player and BLUE == rival couplings

| Location | Classification | Why it matters |
|---|---|---|
| `SaveData.newGame` defaults | identity default | Safe legacy fallback, but insufficient to identify a chosen character when names are custom. |
| `FieldDefaults.PLAYER_SPRITES` / `PLAYER_PICS` | presentation | Direct Red art defaults; must be resolved from a character record when Extended Selection is on. |
| `OakSpeech.lua` `SPRITE_RED` | accidental coupling | The shrink endpoint bypasses `player.sprite`. |
| generated Pallet/route map objects `SPRITE_BLUE` | character identity/presentation | Must be resolved or patched for a Red/Green rival while retaining object IDs and event flags. |
| `OPP_RIVAL1..3` in scripts and battles | gameplay role | Keep these classes/flags; only the identity, art, dialogue and party lookup should vary. |
| `save.player.rival` in `BattleState.newTrainer` | presentation/name | Already supports custom names; must remain independent of `rival_character`. |
| `reds_house*`, `red_fish_*` asset names | map/presentation | Some are player-art paths and need a resolver; map IDs and imported source labels should not be renamed wholesale. |

## 2. Yellow-specific coupling

* `data/scripts/oaks_lab_yellow.lua` implements the Pikachu starter scene,
  the forced Eevee rival pick, later Eevee evolution state, and the Yellow
  Oak/Lab event sequence.  It writes `save.rivalStarter`; it does not create
  a character identity.
* `src/world/PikachuFollower.lua` derives the Yellow partner from the actual
  starter in the party and its ownership/state.  It is not a Red identity
  check and should stay role/party based.
* `src/script/Commands.lua` contains the deliberate Yellow `OPP_RIVAL*`
  party table keyed by `save.rivalStarter`; preserve that mechanic and add a
  character-to-presentation layer outside it.
* Yellow text/scene assets pass through the same Oak Speech, `player.sprite`,
  map object and rival-battle seams as Red/Blue.  The key risk is treating the
  existing Yellow *player role* as Red or its rival role as Blue when choosing
  portraits, walk sheets or family text.

## 3. Pokémon data, Gen-II gender and breeding

### Pokémon representation

* Party, boxes, gifts, wild Pokémon and encounters use plain serializable
  Pokémon tables.  `../../gen1recomp/src/pokemon/Pokemon.lua:new` creates
  `species`, `level`, `exp`, four DVs, derived HP DV, stat experience, stats,
  HP, catch rate, status and moves.
* `../../gen1recomp/src/pokemon/Stats.lua:randomDVs` stores `attack`,
  `defense`, `speed`, and `special` as 0–15 and derives HP from their low
  bits.  Imported boxed mons can lack a derived stat block; `Stats.ensure`
  reconstructs it without changing the saved DVs.
* `../../gen1recomp/src/save_convert/GenSave.lua` reads/writes party and box
  mon DVs from the original Gen-I structures.  No spare gender byte is
  required or appropriate.

### Finding: authentic Gen-II gender is feasible without a new byte

It is already implemented in `./daycare.lua:gender`: it looks up the Gen-II
female threshold from `./breeding_data.lua`, then derives gender from Attack
DV (`attackDV < threshold * 2` is female; 0 is male-only, 8 female-only, and
negative is genderless).  The 251-row data table is generated offline by
`tools/build_breeding_data.py`.

This is DV-derived and therefore backward compatible for party, box, gifts,
trades and scripted Pokémon as long as all creation paths retain DVs.  The
current system does not show a general gender marker in every UI; it uses the
answer for breeding.  A future display feature must call the same centralized
resolver rather than write a `gender` field to each mon.

### Existing Day Care Plus

* The vanilla engine Day Care stores one mon at `save.daycare.mon` with
  `steps` and `depositLevel`; deposit/withdraw and Gen-I EXP/fee/move logic
  are in `../../gen1recomp/data/scripts/story2.lua` (`M.DAYCARE`).
  Steps are advanced by `src/world/OverworldController.lua`.
* Ascendant already adds the requested two-parent and egg layer in
  `./daycare.lua`.  Its isolated mod state is
  `mod.save['daycare_plus']` with `version`, `parents`, `eggMeter`,
  `reservedEggs`, and aggregate egg counters.  Existing single-slot vanilla
  state is explicitly migrated/reclaimed by its Day Care menu logic.
* Eggs are ordinary mon tables marked with `isEgg`, `eggSpecies`, remaining
  and total steps, origin and optional research key.  Hatching restores a
  normal mon in place.  The implementation includes Gen-II-style parent
  compatibility, Ditto handling, mother species, baby species, a 256-step
  production check and the documented DV inheritance/anti-incest condition.
* `main.lua` loads `breeding_data.lua` and instantiates Day Care Plus before
  Mega, Johto and later systems.  It exports both `daycare` and
  `breedingData`; the regression suite already has targeted coverage in
  `tests/trainer_rematch_test.lua` and upgrade fixtures.

## 4. Save architecture and safe storage boundary

The engine save is a plain Lua table encoded deterministically by
`src/core/SaveSerializer.lua`; the load sequence is parse, migrate, validate/
quarantine and restore in `src/core/SaveData.lua`.  Each save carries
`meta.format`, version, player data, flags, party/box and `modData`.
Mod-owned persistence is namespaced below `save.modData[modId]`; do not use
SRAM-like offsets or guess at unused bytes.

The 6.5.0 `identity_migration.lua` moves known content from the legacy
`trainer_rematch` bucket to `kanto_ascendant` before normal feature code uses
it, and writes a rollback shadow afterward.  It already includes
`daycare_plus` in its copied keys.  Therefore later character state belongs
in the canonical Kanto Ascendant mod bucket and must be added to the
migration's allow-list and rollback copy.

Recommended record, created only for a new Extended Selection save or on
first safe migration:

```lua
mod.save["extended_characters"] = {
  version = 1,
  enabled = true,
  player_character = "RED", -- or BLUE/GREEN
  rival_character = "BLUE",
  third_character = "GREEN",
}
```

Legacy/default resolution must be non-writing where possible and yield
`enabled=false`, `RED`, `BLUE`, `GREEN`.  Names remain in
`save.player.name` / `save.player.rival`; they are never a character ID.
This avoids mutating old saves simply by loading them and leaves the existing
Day Care Plus record independent.

## 5. Major risks and recommended boundaries

1. **Engine ownership:** character selection must hook or extend the engine's
   new-game/Oak Speech flow.  A content-only map replacement cannot safely
   replace all boot and naming states.
2. **Visual gaps:** only Red has a complete player asset set locally.  Blue is
   an NPC/rival asset, and Green is absent.  Do not turn on a character choice
   until all required fallbacks are explicit.
3. **Role versus identity:** retain `OPP_RIVAL*`, event flags, Yellow's
   `rivalStarter`, and custom names.  Map object replacement must preserve
   existing object IDs and script trigger names.
4. **Save migration:** add a versioned, namespaced record and migrate through
   `identity_migration.lua`; never patch `save.player.name` to encode identity.
5. **Breeding regression:** the existing feature is already DV-derived.  Do
   not duplicate a gender formula in character code or migrate DVs; use a
   shared exported resolver when Phase 4 reaches UI/display work.

### Implementation boundary

Phase 2 should add only a centralized character-definition/resolution module,
the new-game choice and a default-safe save record.  It may consume existing
engine seams (`player.sprite`, `intro.oak_speech.build`, field/player art
configuration) but must not bulk-rewrite map objects, Yellow scripts,
`OPP_RIVAL*` parties, Pokémon gender UI, or Day Care Plus.  Those are later,
separately testable phases.
