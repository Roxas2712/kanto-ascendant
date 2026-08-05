# Kanto Ascendant 6.0 — Johto Signals

## Release boundary

Version 6.0 is the focused release for two connected systems:

1. the optional early Johto migration; and
2. mythical Mew/Celebi signals.

The normal Kanto migration experience remains the default. Early Johto
encounters do not begin until the player deliberately repairs the Migration
Receiver and selects an active current. Mythic Signals are independent,
enabled by default and can produce protected echoes once the Pokédex is
active; players can disable that system separately. Existing Kanto Ascendant
saves continue in the public `trainer_rematch` save bucket.

The Orange campaign, Jirachi, Fairy research, Sylveon, planned Starfall-only
forms and every experimental Starfall debug facility are frozen for a later
release. They are not optional 6.0 features and must not be present in the
package.

## Player flow

### Early Johto

1. After the starter and Pokédex, Professor Oak calls after a hidden target of
   1–200 eligible steps.
2. The call places a physical dark capsule on Pallet Town's southern coast.
   If it remains untouched, Oak gives one reminder after another 400 steps.
3. The capsule may be declined, taken and opened now, or taken and opened
   later from the Johto Signals menu.
4. Its coordinates must be shown to Pallet's boatman before the clearly
   confirmed trip to the independent Driftglass signal station opens.
5. The station researcher repairs the receiver and explains all three modes:
   Kanto First, Wanderwaves and Johto Unleashed.
6. Four unknown traces unlock Chikorita, Totodile, Cyndaquil and Larvitar
   separately. Names remain `???` until a real Pokédex sighting.
7. The player can always return to Pallet Town immediately and can later
   change the current under `ASCENDANT → WORLD → JOHTO SIGNALS`.

Wanderwaves use badge-dependent habitat groups at 2 PCT, or 4 PCT during a
strong signal. Johto Unleashed uses 10 PCT across matching Kanto habitats.
The four trace species use independent 1:512 and 1:256 counters respectively,
with a guaranteed eligible battle at the limit. Repel and a higher-priority
authored encounter cannot consume that guarantee.

### Mythic Signals

1. Once the Pokédex is active, rare Mew or Celebi echoes can answer in native
   Kanto grass. The first echo is guaranteed no later than roll 512; later
   echoes no later than roll 2048.
2. Echoes are level 60 or twenty levels above the player's strongest party
   member, capped at level 100. They cannot be caught or knocked out and
   prevent the player from running. The warning ends only at party defeat;
   a rejected Master Ball is not consumed.
3. Exactly three echoes are required. No additional echoes occur while the
   receiver is ready for sealing.
4. With the repaired receiver and four badges, the Driftglass researcher
   creates the Resonance Seal. The menu never creates it remotely.
5. True manifestations use a guaranteed 1:8192 counter. A failed catch binds
   that same species as a retrying roamer, preserving its battle state and
   avoiding another full 8192-roll search.
6. Already-owned or disabled species are removed from the pool. Existing Mew
   and Celebi conclusions remain canonical rather than generating duplicates.

## Encounter ownership rule

The Signals selector may replace only a successful native encounter.
Anything marked as an event, outbreak, roamer, research reward or other
authored result wins. Early Johto runs at priority `-30`; Mythic Signals runs
at priority `-10`. Both candidates are transactional: counters commit only
when the exact candidate becomes the actual wild battle.

## Save and upgrade rule

Production state uses one versioned `johto_signals` record with only:

- `earlyJohto`
- `resonance`

UI-open flags, pending candidates and dialogue locks are runtime-only.
Loading, disabling and re-enabling the mod may never trap a save on a custom
map. The Driftglass return boat is available at every quest stage. Saving
during a live Driftglass visit does not move the active player, but the
written slot records the native Pallet landing as its next resume point.

UAT uses a dedicated LOVE identity, `kanto-ascendant-signals-uat`. It must
never write `SF E2E` or `KA6 UAT` slots into the player's normal identity.

## Automated release gates

- Modkit strict and all existing Kanto Ascendant suites pass.
- Early Johto probability, pity, priority, Wilds parity and Lind compensation
  tests pass.
- Mythic damage, residual status, Master Ball, seal and retry tests pass.
- Red, Blue and Yellow; English and German; save/restart and mod off/on pass.
- Schema-derived 5.3 Red/Blue/Yellow fixtures initialize both Signals
  sections without resetting prior progress. They cover pre/post-Hall-of-Fame
  states, legacy `johto_migration`, canonical Mew/Celebi repair and a native
  encode/decode restart boundary while preserving player, party, PC, Bag,
  money, trainer and return-map data. These fixtures pin the exact public 5.3
  package hash but are not described as published player saves.
- Full-save upgrade rows use only original local/player/UAT files whose
  provenance is recorded. A missing source is `NOT EXECUTED`, never PASS.
- The real `.modpkg` imports over 5.3 in the isolated launcher identity.
- `tools/johto_signals_release_audit.py` passes against the exact packaged
  archive.

## Manual UAT matrix

Every row has a named isolated save, an explicit action and a binary result.
No save starts on a frozen experimental map.

| ID | Start | Required action | PASS |
|---|---|---|---|
| 01 | Pallet, pre-trigger | Walk to target and revisit Pallet | Capsule appears once; refusal is repeatable |
| 02 | Pallet, capsule ready | Accept and use the boat | Warning names Driftglass and promises return |
| 03 | Driftglass, pre-repair | Save/restart, sail back, repair, test both boats | Restart resumes at Pallet; repair stages persist; both boats work |
| 04 | Repaired, Kanto First | Fight 30 valid encounters | Native results are bit-identical |
| 05 | Wanderwaves | Test normal and strong signals | 2 PCT / 4 PCT and correct badge pool |
| 06 | Unleashed | Test several habitats | 10 PCT and habitat matching |
| 07 | Wanderwaves, forest pity 511 | Start the 512th eligible battle | Chikorita appears; Repel cannot burn pity |
| 08 | Wanderwaves, Seafoam B2F pity 511 | Start the 512th eligible cave battle | Totodile appears |
| 09 | Unleashed, Mansion B1F pity 255 | Start the 256th eligible battle | Cyndaquil appears |
| 10 | Unleashed, Victory Road 3F pity 255 | Start the 256th eligible battle | Larvitar appears |
| 11 | Postgame Lind | Complete matching research | Early catch is recognized; no duplicate gift |
| 12 | Echo pity boundary | Battle, inflict status, throw Master Ball, try RUN | 1 HP floor, ball restored, capture and escape rejected |
| 13 | Three echoes, three badges | Ask researcher to seal | Researcher refuses and explains fourth badge |
| 14 | Three echoes, four badges, full bag | Ask researcher to seal | Key item is safely granted; state is atomic |
| 15 | True manifestation boundary | Start next native grass battle | Enabled unowned Mew/Celebi appears |
| 16 | Bound Mew | Fail once, find it again, catch | Same bound Mew returns; canonical event closes |
| 17 | Bound Celebi | Fail once, find it again, catch | Same bound Celebi returns; canonical event closes |
| 18 | Original 5.3 save copy, if supplied | Load/save/restart and toggle mod | No data loss, no custom-map trap, no false Dex entries; otherwise NOT EXECUTED |

The final UAT handoff records version, package SHA-256, launcher identity,
base-save provenance and PASS/FAIL evidence for every row.
