# Native habitat playthrough

These drivers use the Gen1Recomp native driver hook (`POKEPORT_DRIVER`) and
`tests.drivers.util`, with ordinary input, menus and walking. They require a
separate engine checkout containing those test seams, the actual game data,
KASC and VASC. Do not run against a player save. The runner forces its own
`kasc-habitat-playthrough-qa` identity and starts a fixture save.

Example:

```sh
python3 tests/habitat_playthrough/run.py regis --host /path/to/qa-engine --love /path/to/love
HABITAT_NGPLUS=1 HABITAT_CATCH=1 python3 tests/habitat_playthrough/run.py starters --host /path/to/qa-engine --timeout 1200
```

Run only one native driver at a time. Logs and screenshots go in `evidence/`.
This suite currently targets Red edition; it does not claim Blue/Yellow,
Windows or mobile coverage.

## Cases

- `starters`: all 16 source-map approaches, finder use, walk-on entry, physical
  exit and return to the reveal point. `HABITAT_NGPLUS=1` uses a fresh NG+ run.
  `HABITAT_CATCH=1` restores native encounters inside the habitat and catches
  each starter family once. `HABITAT_ONLY=ROUTE_14` limits one source map;
  `HABITAT_FROM=ROUTE_18` resumes the ordered matrix at that source map.
- `rivals`: deterministic ordinary rival visit, two actual conversations,
  stored starter hint and corresponding access eligibility. Supports
  `HABITAT_NGPLUS=1`.
- `regis`: all three scientist approaches, puzzles, capture and return.
  Regice waits 121 game seconds without changing the clock or re-interacting.
- `legends`: hidden Rayquaza (`LEGEND_PROFILE=GREEN`) or Kyogre
  (`LEGEND_PROFILE=BLUE`) entrances, capture and source-specific return.
  `LEGEND_JIRACHI=1 LEGEND_PROFILE=GREEN` tests the wish chamber instead.
- `portals`: ordinary Groudon antechamber portal, capture and return.
- `birth`: researcher travel, six triangle positions, Deoxys and departure.
  `BIRTH_ENTRY_ONLY=1` checks arrival collision and departure only.
- `volcano`: complete current-run expedition puzzle, Magmar, Moltres, both
  directions of both stairs, departure. Puzzle flags are not pre-completed.
- `route14-reload`: actual guidance text, entry, save, restore, guidance reuse,
  re-entry and physical exit.
- `gates`: actual runtime authorities for normal/NG+, missing seal/collection,
  disabled portal card and incomplete finale.

## Fixtures and limits

Starting points on public maps, story prerequisites, HMs, collection receipts,
legacy seals and Master Balls are fixtures. Rival introductions and visit RNG
are fixtures, but no starter hint is injected in the rival test. Ordinary
random encounters/trainer sight and living-world spawns are suppressed during
route traversal. The capture test restores native random encounters after
entry and sets the existing sighting counter to 150, so the next eligible
encounter exercises its guarantee. It does not measure natural rarity.

The tests do not replay the entire base campaign, all three HEVO campaigns,
or 130 prior collection captures. Read the logs for completed cases; a static
map check is not an input-driven roundtrip.
