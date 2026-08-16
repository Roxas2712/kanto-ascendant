# Rematch 2.0 Phase 6 architecture

Phase 6 extends the released field-rematch path; it does not introduce a
second trainer system or save namespace.

## Stable progress

`trainers[stable_trainer_key].rematches` remains the authoritative count. The
stable key is the existing NPC ID, with map ID plus object index as the legacy
fallback. Two trainers of the same class therefore never share progression.
The count changes only when that trainer's rematch finishes with `win`.

Old numeric `rematches`, `trainingCycles`, cooldowns and `recruitFamilies` are
kept. Phase-6 fields initialize lazily when the trainer is next used:

- `originalStages` and `originalBranches` prevent a won original evolution
  from regressing after reload;
- `recruitHistory` stores at most the last three arrays of additional species;
- `rematchProgressionVersion = 2` records the compact-state migration.

## Battle generation

Teams are generated when the player accepts the battle. Complete generated
teams and transient stats are not saved. Only the progression and short
anti-repeat history above are committed. This avoids save bloat and lets new
registered species/evolution branches enter existing saves automatically.

Original slots are copied from the authored trainer roster and tagged as
`origin = original`. They use registry evolution edges, exact Phase-6 stage
weights, the projected battle level and Ascendant's existing release flags.
An external trainer randomizer remains authoritative: Ascendant changes an
original species only when the downstream constructor still returned that
authored species.

Additional slots are tagged as `origin = additional`. Authored class seeds are
expanded from registered family/type data, then filtered by release state,
legendary exclusions, already represented families and recent history. The
selector makes one bounded pass; if every legal candidate is excluded by two
consecutive appearances, it relaxes those weights once instead of retrying.

## Verification

`tests/rematch_phase6_test.lua` exhausts every integer roll for all specified
two-stage Rematch 1-5+ and three-stage Rematch 1-7+ distributions. It also
covers level gates, two registered Poliwhirl outcomes, the Gorochu gate,
Johto before/after release, required class archetypes and pool exhaustion.

`tools/rematch_phase6_e2e_driver.lua` exercises the installed Overworld talk
hook and real trainer constructor in Red, Blue and Yellow, writes reserved slot
6606, then reloads it in a second process.
