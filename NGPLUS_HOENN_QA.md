# KASC 6.7.29-rc.2: Hoenn catch-up and visitor

Local candidate based on 6.7.28 (`4a1c8c66d`). Not published or installed into a live game by this task.

## Player behavior

- In NG+, an earlier completed Red, Blue or Green path makes its ordinary Hoenn families available in their authored habitats, including families missed in that path. Older saved character-pack receipts are also recognized.
- Previously caught families qualify too, including catches represented only by evolved forms in old ownership records or the current team/boxes. Eggs do not count as catches. Earned or previously caught Hoenn starters join the corresponding habitat pool.
- Eligible families share one **1% roll per qualifying habitat encounter**. A separate uniform choice selects a family; only its base form appears. Adding families does not multiply the total rate. Current-run Wanderer clues retain their separate encounter chance and guaranteed-fund counter. Existing unfinished clues finish under their existing rules, even if their family now qualifies through an earlier path.
- This applies to ordinary grass encounters and contact with bundled visible wild Pokémon. Scripted battles, Nuzlocke restrictions, generation availability and the Hoenn encounter option remain respected.
- Latias and Latios can roam in NG+ once the Hoenn Dex is owned. No Honey is required in NG+. Normal campaigns still require carried Honey and the Dex. Their existing route-based 1-in-32 encounter roll, retained HP/status/DVs and three-map KO recovery remain. The 1% family pool does not replace authored legendary quests.
- Oak explains the new rule in English/German, including once for an existing NG+ save that already owns the Dex. The option help is updated.
- The Honey visitor uses a dedicated six-frame Hoenn traveler sprite, replacing the generic little-girl model. A visit lasts one of four five-minute / 256-step phases (the later clock determines progress). The clock starts outside her house after the first badge. It no longer starts only on first house entry. Idle time in the house can update her presence; conversations, scripts, transitions and player movement defer the change. The original resident is preserved. The visitor remains hidden in NG+.

## Existing playthroughs

Install the complete candidate with the game closed, then load the existing slot. **No new campaign or NG+ restart is required.** The update derives eligibility from existing path/catch receipts; it does not restart quests, reset the bank, modify teams, reroll the Randomizer seed or reset encounter counters.

Visitor schedule anchors already present in a save are preserved. Older saves without anchors use their elapsed saved clocks rather than receiving a new guaranteed visit on load. Owned Honey, Dex and pack receipts are retained. The schedule is now home for one phase instead of two.

## Validation (2026-09-28)

Engine checkout: `/Users/maarten/Documents/Recompile/gen1recomp`; executable: `.tools/luajit-src/src/luajit` from that checkout. Run new tests from this mod root with `KASC_ENGINE=/path/to/gen1recomp luajit tests/<file>.lua`.

| Test | Result |
| --- | --- |
| `ngplus_hoenn_habitats_test.lua` | 3,913 checks passed: all previous/current character pairs, 10,000-roll enumeration per authored habitat, actual encounter-table habitat availability, base forms, equal family selection, generation/card gates, existing-save state and 49/50 clue preservation, classic and visible encounter receipts, roaming identity and recovery |
| `ngplus_hoenn_native_test.lua` | 130 checks passed: actual bundled Wilds → WorldAPI → ScriptRunner → BattleState with actual Randomizer, on/off × Poochyena/Latias/Latios × success/rejected queue/exception/reload/wrong map/wrong level/protected encounter |
| `hoenn_visitor_schedule_test.lua` | 24 checks passed: first badge outside house, delayed first visit, steps and time, no duplicate NPC, own model, deferred departure, legacy anchors/missing anchors, Honey/Dex/other state preservation, NG+ exclusion |
| `randomizer_progress_test.lua .` | 69 checks, 0 failures |
| Existing discovery-core regression | 282,760 assertions passed |
| Existing visible-wild regression with native engine chain | 377 checks passed |
| Existing randomized visible-wild regression with original fixture | 377 checks passed |
| Lua syntax | All 2,051 Lua files compile with LuaJIT |
| Sprite conversion | Six distinct 16x16 frames in a 16x96 sheet; three opaque hardware shades plus binary transparency; all six frames visually inspected |
| Whitespace | `git diff --check` passed |

The new native integration suite stubs rendering and stack presentation; it tests the real battle construction chain. Existing-save tests use synthetic representative saves and do not write to a player's slot. No complete graphical playthrough was performed. The old randomized-visible fixture cannot run in its optional native mode because its pool can choose an undefined fixture species (`MAGIKARP`); its original fixture mode passed, and the new native matrix covers this change with the actual Randomizer.

Sprite source, exact built-in Imagegen prompt and deterministic conversion are recorded in `assets/sources/characters/hoenn_visitor/PROVENANCE.md` and `build.py`.

## Visual revision 2

The initial visitor artwork was superseded at the user’s request. The new six-frame native sheet follows the original Gen-1 female NPC proportions, pixel outline and three-shade OBJ palette. Its headband/bandana, short bob and satchel match the new HD, Voxel and Cobble Human set in the paired VASC candidate `3.0.53-rc.18.hoenn.1`. The model registration, visit schedule and existing-save behavior are unchanged from rc.1. Exact generation prompt and conversion are under `assets/sources/characters/hoenn_visitor/PROVENANCE.md`.
