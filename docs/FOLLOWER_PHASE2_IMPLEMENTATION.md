# Follower Phase 2 — Native Single-Follower Foundation

## Result

Phase 2 adds one native, species-generic follower to Kanto Ascendant 6.0.7.
It does not add multi-followers, custom ordering, a party submenu, or the final
options UI.

The data flow is:

`party Pokémon -> follower_selection -> follower_sprites -> single_follower -> NPC/SpriteRenderer`

The low-level movement transport reuses Gen1Recomp's already-tested Yellow
trail implementation. Ascendant replaces its Pikachu-only spawn predicate and
owns selection, identity, species, sprite lookup, lifecycle refresh and
external-mod precedence. `SPRITE_PIKACHU` remains only the engine's synthetic
sprite slot; the Ascendant entity is not species-hardcoded.

## Modules

- `follower_selection.lua`: Red/Blue first-healthy PARTY policy; Yellow exact
  marked-partner policy; session-stable runtime identity; no save pointer.
- `follower_sprites.lua`: data-driven Kanto/Johto/Gorochu resolver, true-color
  six-pose sheet configuration, per-species cache, safe hide-and-log failure.
- `single_follower.lua`: one live entity, movement history/FIFO observation,
  rendering refresh, interaction adapter, hot-reload restore and external
  follower-mod precedence.
- `yellow_partner.lua`: remains the story authority for identity, happiness,
  Oak gift, evolved-partner reactions and scripted partner behavior.

The live NPC exposes the Phase-2 entity contract through:

- `followerIdentity`
- `followerSpecies`
- `followerSprite`
- `cellX/cellY`, `px/py`
- `facing` / `followerFacing`
- `followerAnimation`
- `followerActive`
- `followerMovement.history` and `followerMovement.queue`

The `followerMon` field is runtime-only and is never serialized. The Phase-2
policy is derived from the current party after every world update, so saves do
not gain a fragile raw pointer or duplicate selection state.

## Behavior

- Red/Blue: first healthy, non-egg party Pokémon follows. Reorder, slot-1
  replacement, deposit, withdrawal, party-size changes and faint/revive are
  reflected without save migration.
- Yellow: only the marked partner follows. The generic layer wraps the legacy
  entity rather than creating a second one. Pikachu, Raichu and Gorochu render
  as their actual species; Yellow interaction, happiness and scripts remain in
  the Yellow adapter.
- Bike/surf and all-fainted/empty-party states hide the follower safely.
- Missing art never borrows another species. It logs once for the missing
  species/variant and leaves no invalid entity.
- External follower mods exporting `activeMon()` take precedence; the native
  layer remains inactive instead of stacking another entity.

## Assets and provenance

Kanto #001-151 uses the 151 complete 16x96 six-pose sheets adapted from
PokéPC Followers' local upstream checkout. That project credits ShockSlayer
and Pokémon Crystal Clear. The exact provenance and the upstream repository
are recorded in `THIRD_PARTY_NOTICES.md`. The source publishes no separate
art/software license, so this work remains internal and non-commercial unless
the maintainer resolves redistribution permission.

Johto and Gorochu continue to use Ascendant's existing Phase-1 registry and
bundled runtime sheets. No external mod is needed at runtime.

## Verification

ROM-free:

- strict Modkit validation: pass
- `tests/follower_phase2_assets_test.lua`: 151/151 Kanto sheets, pass
- `tests/follower_phase2_test.lua`: selection, registry, lifecycle, movement
  history and external precedence, pass
- `tests/trainer_rematch_test.lua`: 6567/6567, pass
- `tests/upgrade_matrix_test.lua`: 6603/6603, pass
- Gorochu, field economy, Atlas/Legacy, reachability, Johto Signals, Driftglass,
  Wilds compatibility, map-structure, Mythic and Yellow Bill parity suites:
  pass

Real-LÖVE E2E under the isolated
`kanto-ascendant-follower-phase2-20260808` identity:

- Red: pass
- Blue: pass
- Yellow: pass

Every edition covers one entity, real input corners/backtracking, route seam,
evolution, reorder, faint/revive, deposit/withdraw, real door warp and native
save/reload. Yellow additionally covers Raichu and Gorochu art, interaction,
happiness, hide/show and the Bill's House scripted scene.

Screenshots are stored under `qa/follower_phase2/`.

## Phase boundary

Not implemented here: 2-4 followers, CUSTOM order, full party UI, final options
tree, final Raichu presentation toggle, Talking Box centering or Phase-3 sprite
rollout work.
