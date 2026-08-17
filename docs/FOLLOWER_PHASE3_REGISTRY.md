# Follower Phase 3 — Sprite Registry and Coverage

## Scope

Phase 3 makes the native one-follower sprite path fully auditable for Kanto,
Johto, Raichu and Gorochu. It does not change the Phase-2 selection policy,
movement transport, Yellow story adapter, Talking Box artwork or the later
multi-follower/options work.

## Registry contract

`follower_sprites.lua` is the one species-to-walker registry. Every resolved
definition contains a concrete normal/shiny resource, six frames, 16×96 sheet
geometry, walker/true-colour flags, provenance and an explicit failure policy.

- Kanto #001-151 resolves by canonical dex number to distinct normal and
  shiny walkers under `assets/followers_kanto/`. Every shiny walker preserves
  the authored PokéPC geometry and maps its two colour roles to the matching
  indices of that species' exact Crystal shiny palette. A missing or corrupt
  shiny sheet safely falls back to that same species' normal walker.
- Johto #152-251 is registered eagerly from `johto_data.lua` to its concrete
  normal and shiny runtime sheets.
- Raichu uses the regular Kanto #026 definition in every edition; the registry
  does not touch the legacy Talking Box presentation.
- Gorochu uses its dedicated original normal and shiny runtime sheets. It does
  **not** borrow Raichu when art is missing: the safe result is hide plus one
  diagnostic log for that species/variant.
- Future custom species call `followerSprites.register("SPECIES", definition)`
  with their own authored sheet. No movement or selection source change is
  needed.

The engine's `SPRITE_PIKACHU` key remains a transport slot only. The active
NPC exposes its actual `followerSpecies` and `followerSprite`; all sheets go
through the same `SpriteRenderer` true-colour walker path, with no second
Crystal/Follower-EX pipeline.

## Assets and attribution

- Kanto: 151/151 authored normal plus 151/151 palette-derived shiny 16×96
  walkers adapted from PokéPC Followers. The index mapping is reproducible
  through `tools/build_kanto_shiny_followers.py` and recorded per species in
  `assets/followers_kanto/shiny/palette_contract.json`.
- Johto: 100/100 normal plus 100/100 shiny 16×96 walkers from PokeWilds,
  likewise documented in `THIRD_PARTY_NOTICES.md`.
- Gorochu: dedicated normal/shiny Ascendant adaptations of the bundled Raichu
  walker, retaining its six-pose gait with Gorochu-specific visual changes.
- Follower EX was not used as an asset source: no accessible package/source
  was available during the Phase-1 audit.

## Verification

ROM-free gates:

- `tests/follower_phase1_assets_test.lua`: Johto 100/100 normal+shiny and
  Gorochu normal+shiny sheet geometry.
- `tests/follower_phase2_assets_test.lua`: Kanto normal sheet geometry.
- `tests/kanto_shiny_follower_assets_test.py`: 151 normal+shiny sheets, exact
  Crystal palette-index mapping, pixel-identical geometry/alpha/black and
  protected Johto/extended/Gorochu source hashes.
- `tests/kanto_shiny_follower_routing_test.lua`: runtime variant selection and
  missing/corrupt-shiny fallback to the same species' normal walker.
- `tests/follower_phase2_test.lua`: native selection/lifecycle/movement and
  external-follower precedence regression.
- `tests/follower_phase3_registry_test.lua`: all 252 current definitions
  (Kanto 151 + Johto 100 + Gorochu), actual resource loading, Raichu,
  true-colour configuration, missing-art hide/log and future custom
  registration.

`tools/follower_phase3_e2e_driver.lua` is the guarded real-LÖVE catalogue
gate. Under an isolated `follower-phase3` identity it renders and captures
Pikachu, Raichu, Charizard, Onix, Lapras, Chikorita, Cyndaquil, Totodile,
Crobat, Espeon, Umbreon, Scizor, Heracross, Tyranitar, Lugia, Ho-Oh and
Gorochu after real map entry and walking. The existing Phase-2 Red/Blue/Yellow
driver remains the lifecycle, seam, door, save and Yellow-story gate.

Phase-3 real-LÖVE status: pending isolated-run execution. The local desktop
currently has another active Gen1Recomp app instance, which macOS routes
LÖVE launch requests to; it loads that instance's older mod state instead of
the isolated Phase-3 identity. No E2E result is claimed until the dedicated
identity can be launched independently.
