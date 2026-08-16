# Kanto Ascendant Core / Rematch 2.0 — Phase 10 Final Report

Basis is the released Kanto Ascendant 6.0.7 identity. Phase 10 integrates and
re-tests Phases 1–9; it does not start Green, Starfall Tides, Hoenn Evolution
Dungeon or another expansion.

## 1. Files changed

Phase 10 changes `difficulty.lua`, `rematch_rewards.lua`,
`vision_encounters.lua` and `ascendant.lua`; extends the Phase-8/9/integration
tests and the real-LÖVE Core driver; adds `tests/core_phase10_audit_test.py`;
and promotes the Phase-6–9 gates into CI. `THIRD_PARTY_NOTICES.md` now states
explicitly that Follower EX code and assets are not bundled.

## 2. Save data and versioning

The public manifest remains `trainer_rematch` 6.0.7, preserving the released
mod-data namespace. Follower configuration and Rematch reward state retain
schema version 1. Vision state now normalizes to version 1 with strict boolean
Ho-Oh/Lugia flags. Old reward queues are compacted without losing quantities.
The 6,603-case upgrade matrix passed; unrelated options and story data are not
rewritten.

## 3. Follower architecture and status

One native controller owns a predecessor trail for 1–6 followers. Runtime
ownership is weak-keyed per overworld, trails are capped at 64 cells, and NPC
objects are never serialized. PARTY and stable per-Pokémon CUSTOM identities
reconstruct after save/load, evolution, reorder and box transfer. The official
Followers EX and PokéPC controllers are manifest conflicts so only one owner
can reach the runtime.

## 4. Kanto, Johto and Gorochu coverage

The registries passed at 151/151 Kanto, 100/100 Johto plus shiny variants,
Raichu, Gorochu and custom registration. A real Red registry sweep instantiated
17 representative Kanto/Johto/custom walkers. Mixed-generation six-member
chains passed in Red, Blue and Yellow. Gorochu has its native follower asset;
the documented party-icon fallback remains allowed.

## 5. Rematch architecture

Progress is keyed per trainer and persisted independently. Only victories
advance it. Original party identity, additions, class pools and bounded
anti-repeat history feed a single team-generation path; the Phase-6 write and
fresh-process reload drivers passed in all three editions.

## 6. Evolution progression

Deterministic exhaustive tests cover two-stage, three-stage and branched
evolution distributions plus progression gates. The real-LÖVE Phase-6 driver
also verifies original-team evolution and the absolute level cap.

## 7. Trainer pools

Class-themed Kanto pools remain the pre-unlock source. Johto candidates become
eligible only after the corresponding progression gate. Multiple class pools,
recruitment and 1,917 imported-data references passed without early Johto
leakage or invalid species.

## 8. Anti-repeat

Recent selections are capped to three entries. Repeated generation tests and
the Phase-6 reload probe passed, including restoration of history after a new
process. Fallback selection remains possible when the legal pool is small.

## 9. Level-100 mastery

Level 100 is an absolute stored and rendered cap. Later victories improve
bounded DV, Stat Experience and moveset quality. Difficulty overflow uses a
separate modest 62–74% band and cannot create instant perfection. Phase-7
write/reload E2E passed in Red, Blue and Yellow.

## 10. Moveset system

The generator scores STAB, coverage, role, recovery, setup, status and utility;
preserves selected tactical sets; and gates Johto moves. Deterministic tests
cover legality, redundant-damage avoidance and tactical retention. No moveset
balance constants changed in Phase 10.

## 11. Elite Four and Champion progression

Elite/Champion contexts continue beyond level 100 through the same capped
mastery model with specialist/champion bonuses. Field, level-100, post-100,
tactics, Elite and Champion paths passed in the Phase-7 real process matrix.

## 12. Reward system

Ball, healing, PP, vitamin/permanent, evolution-item, normal-money and
level-100 tiers passed deterministic coverage. Master Ball is excluded from
normal rewards. Normal and level-100 money distributions each total 10,000
weight units. Full-Bag reservations now merge equal rows and cap stack quantity
at 9,999, preventing one duplicate save row per repeated reward.

## 13. EXP Share

OFF, CLASSIC and TEAM allocation passed. Unlock defaults to OFF, the Bag item
opens the setting, PC storage does not remove availability, and setting/unlock
state survives a fresh process in all three editions.

## 14. EXP multiplier

×2 is exactly 1:300; ×3 and ×5 are each 1:250 and sequentially gated.
Unlocks never change the active setting. OFF/×2/×3/×5 persistence, PC-item
location and combined Share allocation passed 130,093 deterministic Phase-8
assertions plus write/reload E2E. Multiplication occurs once and respects the
level cap.

## 15. Difficulty

STANDARD 0/0, HIGH +3/+2, HARD +5/+3, VERY HARD +8/+5 and EXTREME +10/+7
trainer/wild offsets passed. Trainer and wild levels cap at 100. EXTREME blocks
trainer-battle items but not wild-battle Balls. The pending preview queue is
now FIFO-bounded to eight records so an external preview caller cannot create
unbounded runtime growth.

## 16. Gorochu rendering

The generic custom-species send-out gate retains Poké Ball timing. Crystal on
uses registered Crystal-compatible art; off uses registered original art.
The visual and audio suites passed 40/40 and 55/55 checks, and every edition's
Core driver verified the registered guest Dex entry.

## 17. Bicycle

The real `input.step` seam consumes logical SELECT only on the overworld. The
final Red/Blue/Yellow driver generated SELECT through default keyboard Tab,
SDL controller Back, remapped keyboard Q and remapped controller X, mounting
and dismounting each time. Menu SELECT remains outside the wrapper's scope.

## 18. Prism Cave

The return is a visible `PRISM_EXIT_ARCH` at the existing destination. Fixture
structure and imported Red/Blue/Yellow runtime checks passed. No invisible A
interaction is required.

## 19. Menus and Kanto 151

The central root has five one-row categories: Gameplay, Followers, Visuals,
Content and System. The real driver opened it and found both Difficulty and
the existing persistent Kanto 151 setting. Follower and dynamic EXP rows use
the same option/save stores; no duplicate disconnected state was added.

## 20. Item locks

Master Ball is the first entry in a small generic protection registry and the
feature is optional. The final real driver exercised field use, wild-battle
throw, `TOSS ITEM` and `SELL` through the actual Bag/ListMenu wrappers. All
four opened a default-NO choice without consuming/calling through; an ordinary
Poké Ball selected directly.

## 21. Vision and Nuzlocke

Ho-Oh (1%) and Lugia (0.75%) use once-per-save versioned flags. With the
bundled Nuzlocke loaded, the final driver forced both visions in Red, Blue and
Yellow, verified uncatchable non-demo state, no EXP, complete party restore,
latched flags, and normal EXP/encounter behavior afterward. The Nuzlocke demo
exemption is scoped only around faint handlers, so normal battle rendering is
unchanged. Marking Seen is intentionally not enabled (the specification made
it optional).

## 22. Exact builds run

- Imported Red: 222 maps, 151 native species, 165 moves; candidate path
  `mods/aaa_phase10_exact`; actual LÖVE boot passed.
- Imported Blue: 222 maps, 151 native species, 165 moves; same candidate path;
  actual LÖVE boot passed.
- Imported Yellow: 223 maps, 151 native species, 165 moves; same candidate
  path; actual LÖVE boot passed with Yellow partner protection.
- Strict Modkit validation against imported data passed. The final launcher
  package is ZIP-integrity and manifest audited after the commit.

## 23. Exact E2E and regression tests run

- Real LÖVE: Follower Phase 1, 2 and 4 once per Red/Blue/Yellow; Phase 5
  write+fresh reload per edition; Phase 3 representative registry in Red.
- Real LÖVE: Rematch Phase 6, 7 and 8 write+fresh reload per edition.
- Real LÖVE: final Core/input/item/dual-vision driver per edition with an
  exact candidate-path assertion and Nuzlocke loaded.
- Visual evidence: six-follower chains, party editor, reload reconstruction,
  Raichu Ascendant box and Yellow-centered box, all 1024×768.
- Headless: 6,569 integration; 6,603 upgrade; 130,093 Phase-8; 1,917 imported
  recruitment; 251/251 reachability; 40 Gorochu visual; 55 audio; 148 Mythic;
  all follower, Phase-6/7, Signals, map, UI, scope and release audits.
- Phase-10 static audit: 28 checks. `git diff --check`: clean.

## 24. Regressions found and fixed in Phase 10

1. Difficulty preview records could grow without a bound: capped FIFO at 8.
2. A permanently full Bag could accumulate duplicate pending reward rows:
   normalized/merged with quantity preservation and caps.
3. Vision once-flags had no explicit schema marker and accepted dirty values:
   versioned and boolean-normalized.
4. Trainer rank used an unsupported Unicode star in the real Gen-I font:
   removed and guarded by headless/static/real-LÖVE tests.
5. CI omitted the Phase-6–9 suites: all are now required with the Phase-10
   release-boundary audit.
6. New QA/tests were not excluded from launcher packages: the Phase-10 audit
   now requires every QA, test, tool, review and source-only file to be listed
   at the packer's exact-file boundary.

## 25. Known limitations

The acceptance matrix is scripted targeted E2E rather than a human full-story
playthrough. Controller behavior was exercised through the real LÖVE/SDL
callback path with synthetic button events; no particular physical USB pad
model was certified. Performance evidence is bounded-structure inspection,
large deterministic simulations and repeated real process restarts, not a
multi-hour frame-time soak. No critical Core path remains known broken.

## 26. Remaining external asset gaps

Followers EX is not required or bundled. Followers EX, PokéPC Followers and
the external Quality of Life package are manifest conflicts because Ascendant
owns the overlapping controllers and hooks. Crystal presentation mods may
still override their documented visual seams. Native Kanto/Johto/Gorochu
followers and bundled Crystal-compatible assets function without external
follower packages.

## 27. Credits and license requirements

Keep `THIRD_PARTY_NOTICES.md` in every package. It records PokéPC/Crystal Clear
Kanto follower provenance, PokeWilds Johto sheets, PokéAPI/Pokémon Database
Crystal assets, Pokémon Channel-derived Raichu clips and the MIT notice for All
Pokémon Catchable. PokéPC publishes no separate art/software license, so the
current use remains explicitly unofficial and non-commercial and should be
reviewed before any different distribution. No Follower EX payload is present.

## Final gate

`KANTO ASCENDANT CORE / REMATCH 2.0: COMPLETE`
