# Post-release regression checks, 2026-09-30

Local pair: VASC 3.0.58-rc.1 + KASC 6.7.31-rc.1. Complete baselines: public VASC 3.0.57 and KASC 6.7.30. No release publication or automatic installation.

## Fixes

- Glass sliding leaves use exact box geometry. Fractional coordinates previously produced empty unit-stepped leaves, causing the atomic building claim to reject gatehouses entirely.
- Window-enabled interiors use one continuous transformed exterior through their glass exit and adjacent windows. The separate miniature doorway image is omitted only at verified exterior openings. Existing cached exterior rendering is reused.
- The KASC volcano leader map selects the authored Cinnabar lava battle terrarium, guarded by exact map ownership and geometry. KASC retains battle, rewards and map authority.
- The four scripted route stair positions have native-footprint 3D stairs, sound on successful transitions, Gym music in corridor and arena, and Dungeon music at the volcano foot. STAIRS OFF restores the intact foot foundation.
- The Hoenn visitor receives the existing seated pose on an actual chair, matched by live actor, asset and position. Floor fallback stays standing.
- Declining honey holds the visitor for the current house visit. After leaving, the normal clock resumes and she returns on her next scheduled visit. The reward remains one-time.
- Rival spectator Pokémon publish their owned presentation identity and use follower appearance settings without becoming player followers. Live style changes and OFF restore the owner renderer.

## Validation

Native LOVE 11.5, disposable saves and options, engine 0.1.90 fixture:

- Gatehouse model claims and nonempty glass leaves on Routes 2, 5, 6, 7, 8, 11, 12, 15, 16 and 18; restored facade screenshot.
- Silph 1F opened door visually continues the adjacent windows at the same scale. Cinnabar Mart and Center openings exercised too.
- Hoenn visitor seated; declined offer remains after clock expiry; departure and later scheduled return pass.
- All six scripted volcano links exercised; save/load, chamber navigation, correct leader, battle entry, reward callback, badge/TM uniqueness, rematch dialogue and town return pass. Fixture win callback was used, not a full manual fight.
- Rival fixture actors use follower context and live source changes. Cobblemon appearance checked in native rendering. Optional HD/MMO packs were absent in this host, so their concrete replacement and restoration are covered by the unit fixture, not native asset screenshots. The full autonomous rival duel was not replayed.
- Controlled native Gorochu/Arcanine entry: Intimidate lowers temporary Attack by one; Special Defense, HP and persistent stats unchanged. This does not identify the user's uncertain historical stat change. No stat or ability code changed.

Targeted unit suites: Blaine route (1,564 checks), Hoenn schedule (33 checks), volcano geometry and OFF/cache fallback, terrarium map selection, seats/contact/all character profiles, glass door/window apertures and clipping, observation windows, staircase geometry (128 combinations), department stairs, terrarium locations/light reuse, Pokémon refresh and rival style restoration.

Evidence is in artifacts/postrelease-fixes-20260930 in the maintainer workspace. Native runs include blaine-native.log, visitor-native.log, duel-native.log, ability-native.log, and visual-fixes.log. The last contains an initial QA-only options setter error after the building/window checks; the corrected independent visitor driver passed. Earlier diagnostic runs intentionally reproduce regressions. No real save was modified.

Package verification reports accompany the ZIPs: complete baseline path preservation, all Lua syntax, archive CRC, exact source bytes and per-file receipts. Mobile rendering and a broad gameplay/performance benchmark were not rerun for this candidate. Existing optional assets are preserved.
