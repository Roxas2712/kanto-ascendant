# Native follower project: Phase 1 audit and implementation boundary

Audit baseline: Kanto Ascendant 6.0.7 (`b4303dc`) with Gen1Recomp
`50947eec2aa0404f71b2b105bba837e3629e0cb6`. This document describes the
existing code. It does not implement Phase 2.

## Engine implementation map

| Concern | Existing implementation and seam |
| --- | --- |
| Player entity | `src/world/Player.lua`: `Player.new`, `tryMove`, `update`, `position`, `facingCell`, `pose`. Movement commits one cell at the end of a step. |
| Yellow follower | `src/world/PikachuFollower.lua`: `starterInParty`, private `shouldSpawn`, `onMapEntered`, `current`, `rebase`, `update`, `talk`, Bill/Nurse helpers. |
| World lifecycle | `src/world/OverworldController.lua`: `setMap`, `update`, `crossConnection`, `onStepComplete`, `takeWarp`, `startWarpTo`, `reloadMap`, `scriptMove`, `updateScriptMoves`, `interact`. |
| Warp resolution | `src/world/Warp.lua`: `onArrive`, `onCollision`, `onEdge`, `destination`; `warp.destination` is the public reroute hook. |
| Party | `src/pokemon/Party.lua` owns max/add/healthy helpers. `src/ui/PartyMenu.lua` performs a direct table swap for reorder. There is no generic `party.changed` or reorder event. |
| PC | `src/pokemon/Boxes.lua`: `ensure`, `active`, `deposit`. `Boxes.deposit` rotates through all 12 boxes. `src/ui/BoxMenu.lua` mutates party/box arrays directly and its interactive deposit path checks only the active box. There are no generic deposit/withdraw hooks. |
| Evolution | `src/pokemon/Evolution.lua`: `pendingFor`, `apply`, `evolve`, `checkParty`. `apply` mutates the same Pokémon table and emits `pokemon.evolved`. |
| Battle/Dex sprites | `src/pokemon/Sprites.lua`: `path` (`pokemon.sprite` hook, `ctx.trueColor`) and `iconPath` (`pokemon.icon` hook). |
| Overworld sprites | `src/render/SpriteRenderer.lua`: `new`, `resolveImage`, `draw`. Sprite definitions come from the merged `sprites` registry and support `walker`, frame count and `trueColor`. |
| Species/registries | Mod registries are built by `src/mods/Loader.lua`/`Registry.lua`; species, icons and sprites are merged into `game.data`. |
| Version branch | `src/core/GameVersion.lua`: process-global Red/Blue/Yellow selection, cache prefix and save suffix. |
| Input | `src/core/Input.lua`: keyboard/gamepad mappings feed Game Boy actions. A follower UI should consume existing `a`, `b`, directions, `start`, `select`; it must not introduce raw-key polling. Rebinding is applied by `Input:applyBindings`. |
| Persistence | `src/mods/Loader.lua` exposes save-scoped `mod.save`, global `mod.options` and `mod.migrations:add`. `src/core/Game.lua:adoptSave` switches the mod backing bucket per slot; `writeSave` emits `save.writing`. `src/core/SaveData.lua:runMigrations` runs mod migrations before validation. |

Useful engine events already exist: `map.entered`, `map.exited`,
`player.warped`, `map.reloaded`, `world.stepped`, `pokemon.evolved`,
`save.loaded` and `save.writing`. Party reorder and PC transfer need either a
narrow engine hook/event or reconciliation on these existing safe boundaries.

## Vanilla/recompiled Yellow semantics

`PikachuFollower.starterInParty` currently finds a party species named
`PIKACHU`; it is not an immutable Oak-gift identity. `shouldSpawn` additionally
requires Yellow, `EVENT_GOT_STARTER`, a healthy partner, a sprite, and no
bike/surf state. The follower is a passable synthetic NPC using
`SPRITE_PIKACHU`.

The movement model is a single `ow.pikachuTrail = {x,y}` target. The follower
moves to the cell the player vacated, catches up faster when necessary, handles
ledges, and is rebased across map connections. Connection transitions retain
the live entity through `keepPikachu`; ordinary warps rebuild it behind the
player. This one-target model cannot safely represent 2–4 followers.

Yellow behaviour is broader than rendering:

- `modifyHappiness`, `bumpHappiness` and `onStep` maintain the Yellow value and
  mood changes.
- `talk` renders emotion bubbles, cry and partner picture selection.
- Bill's House has dedicated enter/machine/exit sequences.
- the Pokémon Center counter hop and visibility helpers are scripted story
  behaviour.
- `OverworldController:interact` dispatches directly to the Yellow talk path
  for the follower NPC.

The generic implementation must therefore replace only selection, entity and
movement presentation. It must leave the Yellow story adapter authoritative.

## Ascendant Yellow partner layer

`yellow_partner.lua` is already a compatibility adapter, not a slot-1 feature:

- Exact identity is stored on the Pokémon table as
  `_ascendantYellowPartner`; controller state is under the `yellow_partner`
  mod-save key (schema version 2).
- `Commands.give_pokemon` is wrapped so Oak's actual gift receives the marker.
  Legacy migration scans party and all boxes and adopts only an unambiguous
  self-owned Pikachu/Raichu/Gorochu.
- Reorder and boxing do not lose the marker. `Evolution.apply` mutates the same
  table, so Pikachu -> Raichu -> Gorochu also retains it. The
  `pokemon.evolved` listener updates partner state.
- Happiness/mood are deliberately retained for evolved partners.
- `installFollowerBridge` wraps the engine Yellow module. For Raichu/Gorochu,
  `withSpawnAlias` temporarily aliases only the marked partner to Pikachu while
  the legacy spawn/update logic runs, then restores its real species.
- Yellow-visible story text is restored where an external follower mod might
  have replaced it.

This adapter must remain the single owner of Oak-gift identity, happiness,
Bill/Nurse sequences and evolved-partner talk. A future generic system must
detect it and suppress a duplicate legacy entity.

## Gorochu asset audit

The owner's earlier belief that Gorochu has no proper walker is no longer true
for 6.0.7. The current tree contains:

- Crystal battle front/back: `assets/crystal/gorochu_front.png` and
  `gorochu_back.png`;
- normal/shiny Voxel front/back masters under `assets/voxel/gorochu/`;
- Raichu-derived six-pose source sheets at `assets/followers/gorochu.png` and
  `assets/followers/shiny/gorochu.png` (96x16), rebuilt by
  `tools/build_gorochu_follower_assets.py`;
- runtime normal/shiny walkers at
  `assets/followers_runtime/{normal,shiny}/follower_GOROCHU.png` (16x96);
- authored pose reference at
  `assets/sources/gorochu/gorochu_follower_pose_reference.png`;
- seven-mood normal/shiny talking portraits under
  `assets/yellow_partner_gorochu_portraits/`;
- a dedicated Yellow-style cry plus Red/Blue chip fallback.

The original custom walker passed only structural validation but did not match
the Kanto follower family's proportions. The replacement preserves Raichu's
complete silhouette and adds only 3-8 horn pixels per frame. Pixel-level QA
now checks one connected silhouette, bottom-row grounding, gait-pair overlap,
four-color palettes, normal/shiny parity and source/runtime order.
`gorochu.lua` registers the custom species with `trueColor = true`;
`gorochu_visuals.lua` selects the battle variants.

There is no separate bespoke 16x16 party thumbnail. Gorochu currently uses
Raichu's animated icon class via the icon registry. That is an intentional
fallback, not a missing overworld walker.

## Raichu/Gorochu Talking Box

The implementation is in `yellow_partner.lua`:

- `portraitFrames` resolves normal/shiny, species and mood frames.
- `portraitBoxX` picks tile x=1 or x=12 from the follower/bubble position.
- `drawRaichuPortrait` draws `Font.drawBox(boxX, boxY, 7, 7)`, then a 40x40
  true-colour inner picture at `(boxX+1)*8, (boxY+1)*8`.
- `raichuFollowerTalk` selects the reaction and installs the emote record.
- `installPortraitAnimator`/`installPortraitRenderer` wrap overworld
  update/UI drawing and SGB palette regions.

All audited portrait files are 40x40. Representative alpha bounds are
symmetrically centred at (19.5,19.5), and `Font.drawBox(7,7)` provides exactly
a 5x5-tile (40x40) interior. Therefore the inner centring formula itself is
correct. The reported visual issue is most likely the coarse left/right box
anchor relative to the NPC/emotion bubble, not off-centre source pixels.
Phase 6 should reproduce the exact failing camera/follower position before
altering `portraitBoxX`; no Phase-1 product change is justified.

## Johto and external references

`johto_data.lua` is the canonical ordered catalogue for #152–251.
`postgame_species.lua` registers all 100 species generically and maps their
Crystal battle art and native icon classes. The follower inventory is already
complete:

- 100/100 normal runtime sheets, 16x96;
- 100/100 shiny runtime sheets, 16x96;
- source sheets under `assets/followers/`;
- Unown has the documented local fallback;
- format conversion and lookup live in `sprite_assets.lua` and
  `tools/install_gen2_followers.py`.

`THIRD_PARTY_NOTICES.md` records the PokeWilds source and Project/Pokémon asset
provenance. Runtime sheets are true-colour RGBA and can be registered with one
species -> asset map.

PokePCFollowers was inspected at official upstream commit/tag `3404248`
(`v0.5.4`) and in the locally available fork. Worth adapting:

- a selected-mon resolver with party fallback;
- a species/dex -> walker asset lookup;
- a live sprite-definition refresh;
- Party submenu integration through `ui.party.submenu`;
- an `activeMon` export for compatibility;
- Red/Blue spawn eligibility and true-colour intent.

Do not copy its brittle mechanics: it patches a private `shouldSpawn` upvalue,
rewrites global renderer methods, overloads `SPRITE_PIKACHU`, fingerprints a
Pokémon from collision-prone stats/DVs, and some branches alter Yellow's Oak
story/starter. Ascendant needs public modules and a stable per-Pokémon id.

No Follower EX source, package or independent asset set is present in the
workspace or installed mods. Only compatibility names/tests were found. The
referenced Discord channel was not available through the authorized private
Kanto release-thread bridge, so its contents were not inferred. There is
nothing verified to reuse from Follower EX in Phase 1.

## Proposed native architecture

Keep six modules with one-way dependencies:

1. `follower_selection.lua`: pure resolution from party + saved stable ids;
   returns Pokémon objects and reasons, never entities.
2. `follower_order.lua`: PARTY mode follows current party order; CUSTOM mode
   reconciles saved ids against party membership and count.
3. `follower_sprites.lua`: one registry from species id to normal/shiny
   six-pose sheet; includes Kanto, Johto and custom species without branches.
4. `follower_movement.lua`: owns entities and a bounded history of committed
   cells. Follower 1 targets the player's vacated cell; follower N targets the
   predecessor's vacated cell. It handles spawn/rebase/flush, not selection.
5. `yellow_follower_compat.lua`: delegates Oak identity, mood, talk and scripts
   to `yellow_partner.lua`, chooses presentation, and prevents duplicate
   legacy/generic followers.
6. `follower_state.lua`: schema/defaults/migration and stable-id
   reconciliation only.

Movement must record committed cells (not interpolated pixels) from normal and
scripted movement. A connection rebases entities and queued cells. A warp or
teleport flushes history and respawns a collision-free chain. Followers remain
passable. Bike/surf/special-script visibility policy belongs in the Yellow or
presentation adapter, not sprite lookup.

## Persistence and migration

Concrete selection belongs to the save slot, not global options, because it
refers to Pokémon in that playthrough. Proposed bucket:

```lua
followers = {
  version = 1,
  count = 1,
  orderMode = "PARTY",
  custom = { "mon-id-..." },
  yellowPresentation = nil,
}
```

Assign `_ascendantFollowerId` lazily to a selected Pokémon and persist it on
the Pokémon table. It survives reorder, boxing, evolution and save/reload.
On load, repair duplicate ids and discard custom ids not present in the party;
never use DV/OT fingerprints as the primary key. Keep UI defaults in
`mod.options` only if they do not reference a concrete Pokémon.

Register the first new schema through `mod.migrations:add` at the release that
introduces it, and also reconcile on `save.loaded`. Existing 6.0.7 has a mixed
history: most subsystems use local `version` fields plus `save.loaded`, while
`grand_tour.lua` already demonstrates the formal migration API. New follower
state should use the formal API. Save validation already quarantines unknown
mod species/items when a mod is disabled and reclaims them when re-enabled;
the follower state must tolerate those Pokémon being temporarily absent.

## Test foundation

Automated layers now available to later phases:

1. `tests/follower_phase1_assets_test.lua` is a ROM-free catalogue/asset
   contract for 100 Johto normal+shiny walkers plus Gorochu.
2. `tools/follower_phase1_e2e_driver.lua` is a guarded real-LÖVE driver for
   Red/Blue/Yellow. It checks candidate load, real input walking, a real
   `Warp.destination` outside/inside round trip, party identity through reorder
   and evolution, and native save/reload in isolated slot 6101.
3. Existing focused drivers remain useful: engine
   `pikachu_follow_distance_bug410_test.lua`, `pikachu_talk_bug407_test.lua`,
   `pc_deposit_test.lua`, evolution drivers, plus Ascendant
   `yellow_partner_qa_driver.lua` and `raichu_reactions_qa_driver.lua`.
4. The existing ROM-free CI suite and strict Modkit validation remain the
   first gate before real ROM-cache runs.

The real E2E command shape is:

```sh
cd /path/to/clean/gen1recomp
POKEPORT_IDENTITY=kanto-ascendant-follower-phase1-qa \
POKEPORT_VERSION=red \
POKEPORT_DRIVER=/path/to/kanto-ascendant/tools/follower_phase1_e2e_driver.lua \
POKEPORT_TOUCH=0 \
/path/to/love.app/Contents/MacOS/love .
```

Repeat with `blue` and `yellow`. The identity must contain legally prepared
caches and only the candidate `trainer_rematch` mod. Never use a player's
normal identity for this driver.

The ROM-free gate is the existing CI command set in
`.github/workflows/ci.yml`; locally, from the engine checkout:

```sh
export POKEPORT_DATA_DIR=tests/fixture_data
export TRAINER_REMATCH_MOD_DIR=/path/to/kanto-ascendant
luajit /path/to/kanto-ascendant/tests/trainer_rematch_test.lua
luajit /path/to/kanto-ascendant/tests/follower_phase1_assets_test.lua
luajit /path/to/kanto-ascendant/tests/upgrade_matrix_test.lua
MODKIT_LUAJIT=luajit python3 tools/modkit.py validate \
  /path/to/kanto-ascendant --base fixture --strict
```

Run the remaining commands listed in CI as one gate, including Gorochu,
field economy, reachability, Johto Signals and engine-backed map tests. A
release-shaped build uses `tools/modkit.py pack`, `unzip -tq`, and then
`tools/johto_signals_release_audit.py` against the archive.

## Risks and Phase-2 order

Primary risks are duplicate Yellow entities, losing exact partner identity,
multiple followers sharing one trail target, stale entities on map changes,
scripted movement bypassing history, external mods patching the same globals,
and PC/party mutations with no engine event. True-colour rectangles must be
marked narrowly so UI/battle palettes are not affected.

Exact Phase-2 order:

1. Add ROM-free state/id migration tests and a single-follower resolver.
2. Add the species walker registry and verify Kanto/Johto/Gorochu lookup.
3. Add one generic entity with a one-follower committed-cell history.
4. Wire map connection, warp, teleport and scripted-movement lifecycle.
5. Add the Yellow adapter and duplicate suppression; preserve all legacy talk
   and story calls.
6. Add PARTY-only selection and the smallest existing Party submenu seam.
7. Run ROM-free suite, strict package validation, then the guarded E2E driver
   for Red, Blue and Yellow plus the focused Yellow regression drivers.
8. Stop. Do not add multi-followers or CUSTOM-order UI until Phase 3+.
