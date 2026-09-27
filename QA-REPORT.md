# KASC 6.7.28 validation

2026-09-27. Complete hotfix based on the verified public 6.7.27 package.

## Regression coverage
- The portable `tests/randomizer_progress_test.lua` fails on 6.7.27 (31 failed checks) and passes on the hotfix (69 checks). It exercises the production controllers and Randomizer hooks: classic/visible Mythic progress; echo, true-manifestation and retry guarantees; all four Johto primal traces; Hoenn introductions and 50-encounter trace guarantee/capture; authored encounter protection; Shiny Dex counters; Trace Finder rematch guarantee; world-event countdown; cancellation and mismatched battle rejection.
- Real Mythic/visible-Wilds adapter: 120 checks, including 50 concurrent visible candidates, exact starts, despawns, both Randomizer modes and protected guarantees.
- Hoenn visible/mixed encounter and catch suite: 377 checks each in normal and randomized fixtures. Includes reload at encounter 25, both traces by encounter 50, duplicate starts, failed queues, rejected/foreign/scripted battles and active Nuzlocke exclusions.
- Engine-construction smoke test: 377 checks through the bundled Wilds start path and the engine's WorldAPI, script runner and BattleState. Rendering/stack presentation is stubbed; this is not a played graphical session.
- All twelve Generation IV–VII starter habitats: 14,631 checks through real habitat and Randomizer controllers, normal/randomized settings, 151 encounters per family and capture/unlock. Access prerequisites, registered species/assets and battle starts are fixtures.
- Existing Mythic suite: 147 checks. Johto suite: 2,501 checks. Run Rules: 262 checks. Hoenn runtime: 110 checks. Hoenn field overlay: 31 checks. Exploration Device: 256 checks. Hunting Club: 4,402 checks. Pure Discovery Core: 282,760 assertions.
- Historical test fixtures were adapted only for current registry/API and intended Randomizer policy contracts. The obsolete global reservation expectation in the old visible-Wilds mock suite already fails on 6.7.27; the production adapter is covered by the real-controller tests above.

## Audit and packaging
Step-driven events/cooldowns and counters based on actual battle, catch or submitted-party records do not compare a randomized species to its former encounter-table slot. Encounter ownership and existing Nuzlocke restrictions remain intact. No save schema, seed, encounter odds or guarantee thresholds changed.

All 2,048 Lua files compile. ZIP CRC, manifest version, complete file inventory and every packaged byte are verified against the committed source. Unchanged files remain byte-identical to the verified public 6.7.27 package. SHA-256 is supplied alongside the ZIP.

## Limits
No reporter save was provided. No full campaign, physical mobile/Windows test or graphical playthrough is claimed. Counters resume from their saved value; previously uncounted encounters cannot be reconstructed. The Hoenn discovery exclusion for an active Nuzlocke is intentionally retained.
