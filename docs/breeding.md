# Breeding and Eggs — Phase 7

## Day-Care and save model

Route 5 Day-Care retains the original step-based experience gain and stores
two deposited records in `daycare_plus.parents`. `reservedEggs` holds a
ready-to-collect egg if the party is full. The v3 record additionally stores
the Crystal-style randomized countdown to the next egg check. Existing
v2 records remain valid and begin a fresh countdown at their next check.

Eggs are ordinary party/box Pokémon carrying `isEgg`, their real future
species in `eggSpecies`, a remaining-step counter and origin metadata. This
preserves normal save serialization and PC transfers without creating fake
SRAM/species slots. Eggs are kept at zero HP, cannot be Day-Care parents and
are excluded from HM field-move eligibility. At hatch, the same record becomes
the level-5 offspring, receives the player OT/ID, recalculated stats and the
normal nickname flow/presentation.

## Crystal reference and compatibility

The implementation follows [pret/pokecrystal's breeding routines](https://github.com/pret/pokecrystal/blob/master/engine/pokemon/breeding.asm)
and [DayCareStep](https://github.com/pret/pokecrystal/blob/master/engine/events/happiness_egg.asm).
`breeding_data.lua` provides the canonical two Egg Groups and hatch-cycle
value for every supported Gen-I/II species. The Phase-6 central gender API is
the only gender calculation used.

`daycare.compatible(game, monA, monB)` is authoritative and returns a boolean
plus Crystal's compatibility byte:

| Pair | Different OT | Same OT |
|---|---:|---:|
| Same species | 255 | 254 |
| Different compatible species, including Ditto | 128 | 51 |

No-Egg species, two Ditto, incompatible groups, same genders and genderless
non-Ditto pairs fail. Crystal's Defense-DV / low-three-Special-DV matching
restriction is retained. The countdown is initially a random 150–255 steps,
then a random 0–255-step interval after each check; its egg rolls are 80/256,
30/256 or 10/256 for the reachable compatibility bands, exactly matching the
original's byte thresholds.

## Offspring, DVs and moves

The maternal (or non-Ditto) evolutionary family determines the child, with
the original two-pre-evolution behavior and the existing baby-family table.
Nidoran♀ is the Gen-II exception: its offspring is Nidoran♀ or Nidoran♂ at
50/50. Ditto supplies the non-Ditto species but does not magically bypass
No-Egg restrictions.

Defense and the low three Special-DV bits inherit from Ditto or the
opposite-gender parent; Attack, Speed and the high Special bit stay randomly
rolled. This is the existing authentic Gen-II shiny/gender-compatible method,
not modern IV inheritance.

`egg_moves.lua` is a centralized transcription of Crystal's egg-move lists.
The starting level-5 set is built first, then Crystal ordering applies: the
father provides listed Egg Moves and compatible TM/HM moves; a level-up move
passes only if both parents know it. Each added move shifts the oldest move at
the four-move limit. A female paired with Ditto is not a move donor, matching
Gen II.

## Intentional limits

No later-generation mechanics are present: no natures, abilities, incense,
balls, Destiny Knot, Everstone, Masuda method, modern move transfer or modern
IV rules. Egg moves whose IDs are not implemented by the current engine move
registry are safely skipped rather than creating an invalid move record.

## Phase 8 safety hardening

Eggs are also filtered at the Party submenu boundary: they retain STAT and,
outside battle, ordinary party reordering, but never display field-move rows
or a battle-switch row. This matches their zero-HP, non-combat status and
prevents a later eligibility rejection from presenting a misleading action.

The save-compatible Egg record remains intentionally adapted to Gen1Recomp.
Its final step now pushes a dedicated opaque hatch movie: quiet reveal,
accelerating wobble, progressive cracks, flying shell fragments, newborn
front picture, species cry and only then the localized result text. Multiple
ready Eggs are processed sequentially. The movie changes the existing Egg in
place at the reveal frame, so save ownership, Pokédex credit, Shiny handling
and research completion still pass through the original Day-Care finalizer.

The fallback Egg picture is authored procedurally and redistributable. If an
active Crystal-251 installation has legally extracted
`crystal_251/generated/egg/front.png` from the user's own Crystal ROM, the
hatch state uses that mounted picture automatically. The fallback remains
fully functional without Crystal-251. That external repository has no
declared license, so its Lua source and ROM-derived assets are not copied into
Kanto Ascendant.
