# Riolu native walking friendship fix — 6.7.10 candidate

Engine 0.2.57 native world.stepped events omit the Game object. Riolu's dedicated walking listener now uses the live Game captured at startup/game.ready when the event does not provide one. It reads the current save and party each time, so reloads and party changes do not leave it tracking stale Pokémon.

The existing rate remains one point per 64 steps, capped at 255. Eggs and fainted Riolu remain excluded. Evolution still requires friendship 100 and a daytime level-up. No save migration, evolution shortcut or change to other species' rates.

Built directly on published 6.7.9, retaining the Trace and equipment-save fixes. Only backend_gift_species_67.lua, manifest.json and the package hash index change.

Build: `python3 hotfixes/6.7.10/build.py /path/to/kanto_ascendant-6.7.9.zip /path/to/output`

Run tests/riolu_native_steps_test.lua from the extracted package with LuaJIT. It fails on 6.7.9 and passes with the fix. The two live drivers run in a disposable portable engine 0.2.57 environment with imported Red data, this package enabled, KA_TEST_UTIL pointing to tests/drivers/util.lua and SHOT_DIR to an existing output folder. They use accelerated native step callbacks and render the actual evolution UI; level-up triggers and threshold boundary values are test-controlled. The Riolu fixture uses a synthetic local gift receipt, with no live redemption code.

Desktop runtime test only; no physical mobile-device test. Candidate not published. Import ZIP and restart fully to install. Rollback: reinstall 6.7.9.

Validation: 132 live assertions passed (21 Riolu, 111 existing friendship systems). Tested Pichu, Cleffa, Igglybuff, Togepi, Golbat, Chansey, Eevee day/night, and postgame research party-wide gain. All nine evolution outcomes rendered through the native evolution UI. Save/load preserves walking remainder, friendship and evolved species. No additional faults found in these existing paths.
