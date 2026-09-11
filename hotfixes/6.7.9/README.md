# Trace encounter counting hotfix candidate 6.7.9

The 6.7.8 trace counter rejected native grass, cave and surf battles because engine 0.2.57 provides checkpointOrigin instead of encounterSource. The fix accepts the explicit wild_encounter checkpoint for the pending proposal's map. Explicit non-wild sources and protected, scripted, ghost, Safari and trainer battles remain excluded. Species, level, map and stale-transaction checks remain intact.

Equipment initialization and item transactions also rebind the mod save API after replacing metadata, including failed-write rollback. This prevents trace counters and other subsequent mod progress from being written to an obsolete table instead of the active save. No data format changes are involved.

Built directly on the published 6.7.8 ZIP. Only hoenn_discovery.lua, the two equipment modules, manifest.json and the package hash index change. No save migration. Rollback: reinstall 6.7.8.

Build: `python3 hotfixes/6.7.9/build.py /path/to/kanto_ascendant-6.7.8.zip /path/to/output`

Verify: `python3 hotfixes/6.7.9/verify.py /path/to/output/packed --engine /path/to/engine-0.2.57 --results /path/to/results.json`

Live driver: see live_driver.lua. Run in a disposable engine 0.2.57 portable directory with the candidate enabled, imported Red data and a separate save identity. It seeds a Route 1 clue and controls only the 1–10000 encounter RNG to exercise the worst-case deadline; the engine step path creates and publishes the battles. Battles are rendered then finished by the driver. This is an instrumented desktop test, not manual play or a physical mobile-device test.

The candidate is prepared locally and has not been published.

Validation: 307 live assertions passed. Native step encounters incremented from 1 to 49, disk save/load retained 25, and Poochyena appeared and committed on encounter 50. See live-results.json.
