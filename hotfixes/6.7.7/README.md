# Kanto Ascendant 6.7.7 — Wanderer clues and battle fixes

Built on the published 6.7.6 package. All earlier fixes remain included.

- Wanderer clues name the Pokémon and its exact nearby route or area, including floors where needed. No distant fallback. New clues use the Pokémon’s authored habitat; older saved clue locations remain valid.
- A clue unlocks the named Pokémon within 1–50 eligible wild encounters at that location. Progress survives save/load; simultaneous clues share a deadline-aware queue. This counts encounters, not steps.
- Six English/German dialogue variants per trainer style, covering all 49 trainer classes, with no immediate repetition.
- Wanderer Mega Evolution must respect the approved surprise plan and its level-80 threshold, including direct activation.
- Focus Punch loses focus after direct HP damage; Sucker Punch checks the opponent’s pending damaging action. Imported recharge attacks (Giga Impact, Blast Burn, Hydro Cannon, Frenzy Plant, Rock Wrecker and Roar of Time) recharge correctly. Freeze Shock and Ice Burn charge before attacking. Native Gen1 Hyper Beam is unchanged.

Import the new ZIP and fully restart the game. No save migration is required. Requires Gen1 Recomp 0.2.57 or newer, as in 6.7.6.

## Verification and scope

Regression checks cover local clue selection, all 62 trace families, the 50-encounter ceiling, saved progress, exact species, all trainer dialogue styles, Mega gates and native battle execution. The full extracted package is loaded through the Mod SDK on the released 0.2.57 engine. Package verification checks every indexed file hash and ensures only five runtime files plus two version/index files differ from 6.7.6. No physical mobile-device visual test was performed.

The broader move audit also identified candidates for separate follow-up: Outrage, Last Resort, Belch, Eruption/Water Spout and Future Sight/Doom Desire. They are not claimed fixed in this release. Mechanics reference: [Pokémon Showdown move definitions](https://github.com/smogon/pokemon-showdown/blob/master/data/moves.ts).

## Reproduce

Download the 6.7.6 release ZIP, then run from the repository root:

```sh
python3 hotfixes/6.7.7/build.py /path/to/kanto_ascendant-6.7.6.zip /path/to/output
python3 hotfixes/6.7.7/verify.py /path/to/output/packed /path/to/engine-0.2.57 /path/to/gen1recomp-source --results /path/to/results.json
```

The test runner defaults to LuaJIT. The engine source checkout supplies `tests.modkit` fixtures and generated font data; the extracted engine release supplies runtime code and generated data. `runtime.patch` records the exact changes against the prior release. Rollback: reinstall the 6.7.6 ZIP from its GitHub release.
