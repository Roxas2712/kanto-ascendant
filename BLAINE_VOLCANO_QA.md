# Compact Pyro arena — KASC 6.7.29-rc.4.pyro.1

Local candidate for the requested smaller Pokemon court, paired with VASC 3.0.57-rc.9. Based on the committed rc.3 Blaine route (`b30cfad48`); the separate, unfinished Sevii worktree was not included or edited.

The chamber keeps its 48×36-cell envelope and native impassable, non-surfable lava. Its walkable platform is now **18×12 cells** at (16,10)–(33,21): 28.125% of the previous area, with lava along all four edges. The two-cell-wide bridge is at (24,22)–(25,29), arrival at (24,28), return trigger at (24,29). Blaine stands at (25,12). `kaArenaGeometry.version=2` describes these exact bounds. The tunnel, clearing, quiz rooms, leader identity, canonical trainer key and rewards keep their existing implementation.

VASC renders the court, lines, Pokeball, chains, recessed flowing lava, basalt, ember light, ash and mist. Without KASC, VASC does not create this route or move Blaine. VASC also recognises the old geometry contract for earlier rc.3 KASC packages.

Validation: 1,554 native-data unit assertions cover all six reciprocal links, collision, reachable leader, lava around every side, unchanged quiz blocks/trainer indices, battle header, story difficulty and canonical rematch identity. Native LOVE/Red input-driven roundtrip passes with the compact geometry: perimeter walk, save/write/load/restore, battle start, native victory callback, Volcano Badge, Fire Blast TM, no duplicate TM, Master/Crown lookup and return to Cinnabar Island. Battle victory is fixture-completed; full combat AI is not claimed.

Evidence: `/Users/maarten/Documents/Recompile/artifacts/doors-volcano-20260930/kasc-unit.log`, `kasc-native.log`, and `kasc-native/`. The engine already relocates nonwalkable saved positions to the nearest valid cell; no live user save was edited. Changed sources and the complete local ZIP receive Lua syntax, CRC, byte equality and SHA-256 checks.

---

# Blaine/Pyro volcano route — KASC 6.7.29-rc.3

Local candidate, not published or installed in a player's game. Includes all Hoenn changes from rc.2.

## Route and geometry

The six quiz rooms and their trainer indices are unchanged. Blaine's former room contains a descending stair at (3,2). The player arrives at the right end of a 48×14-cell service tunnel, walks left, then north up the stair at (5,4). This leads to an outdoor volcano clearing; its northern cave entrance leads to Blaine's new chamber. All passages support a physical return trip.

The tunnel uses the native FACILITY tileset, matching the Gym. The clearing and chamber reuse the Lavados/Moltres quest's volcanic rock artwork and warm palette. There are no wild encounters, quest gates, Honey/Dex requirements, HM gates or Hall-of-Fame requirements on this route.

The chamber is **48×36 cells**, including a **32×24-cell walkable arena** at (8,6)–(39,29), a four-cell-wide southern bridge and a non-surfable lava basin. Blaine stands at (24,10). Each cell is 16 native pixels. The map's `kaArenaGeometry` defines the platform, bridge, lava bounds and four suspension anchors. This is the flat gameplay foundation for a later hanging VASC arena; it does not yet render hanging chains, vertical separation or a complete anime-style 3D set.

Stable identities: `KA_BLAINE_GYM_TUNNEL` (1996), `KA_BLAINE_VOLCANO_FOOT` (1997), `KA_BLAINE_VOLCANO_GYM` (1998). Keep these ids, the 48×36 chamber envelope and the entry coordinate stable during visual work. Decorative objects must not reduce the clear platform or obstruct access to Blaine.

## Compatibility

- Existing campaigns can continue without restarting. Original Gym coordinates and gate flags remain valid; the only changed native block is the leader-room stair. Quiz NPC object indices remain 2–9.
- Blaine keeps his native object name, index, trainer class, party, battle header, text, flag, Vulkanorden and Feuersturm reward. Story difficulty, AI/healing policy and Master/Crown leader lookup recognise the new chamber. His existing KASC trainer cooldown record retains its canonical key.
- The outdoor clearing updates the engine's last outdoor map. Therefore the two original Gym exit warps now explicitly return to Cinnabar Island; they cannot bounce into the clearing.
- Paired VASC `3.0.53-rc.18.hoenn.2` adds only the moved leader's catalog location, preserving his dedicated artwork. Detailed VASC suspension scenery is deliberately left for the later visual pass requested by the user.

## Validation

- `tests/blaine_volcano_route_test.lua`: 1,552 checks with real Red map/tileset/header data. All six transitions, reciprocal landings, right-to-left reachability, 768 platform cells, non-surfable lava, native quiz geometry, canonical identity and real story difficulty/battle-policy hooks pass.
- `tests/blaine_volcano_native_driver.lua`: actual input-driven roundtrip through Gym → tunnel → clearing → chamber → Gym → town, perimeter walk, save/write/load/restore in the new chamber, native Blaine battle start, native victory callback, badge/TM/flag, no duplicate TM and Master/Crown lookup pass.
- Battle victory is fixture-completed through the battle's native callback; this is not a full combat/AI playthrough. Native graphical run covers Red. No full Blue/Yellow campaign or finished VASC suspended-arena render is claimed.
- Native host: isolated links to `gen1recomp-gen3-20260919`, separate `kasc-blaine-volcano-qa-20260928-v3` profile. Red generated fixture cache; two missing town-map image assets supplied from the local Red reference. The QA copy of main.lua disables stdout buffering. No gameplay engine code or player save modified.
- All changed Lua files compile; whitespace/diff checks pass. Paired VASC identity test resolves the same Blaine artwork at both old and new locations.

Re-run the unit suite with `KASC_ENGINE=/path/to/engine KASC_NATIVE_DATA=/path/to/data/generated luajit tests/blaine_volcano_route_test.lua`. The native driver requires an isolated engine with KASC, `BLAINE_KASC_ROOT`, `BLAINE_QA_OUTPUT`, `HABITAT_QA_ROOT`, `POKEPORT_DRIVER` and a dedicated `POKEPORT_IDENTITY`.
