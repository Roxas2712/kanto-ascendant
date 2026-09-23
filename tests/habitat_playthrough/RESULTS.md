# Habitat and legendary entrance playthrough — 23 September 2026

This audit follows the Route 14 player report. Earlier route tests did not constitute an end-to-end gameplay test: they skipped the final walk-on handoff or directly called return helpers.

## Environment and limits

Native LÖVE 11.5, Red edition, packaged VASC 3.0.37 plus KASC 6.7.19 with the local fixes listed below. Isolated QA save identity; no player save changed. Tests drive ordinary buttons, item menus, movement, puzzle interactions and capture menus. Starting positions, story completion, HMs, collection prerequisites and Master Balls are fixtures. Ordinary random encounters/trainers are disabled during access-route checks; these tests do not replay entire campaigns or prove encounter probabilities. Screenshots and input drivers are retained in the private QA directory.

## Confirmed defects fixed locally

- Opened hidden entrances on the supported older engine only reacted to A from a particular adjacent cell. They now also trigger on walking onto the guarded exit, preserving live eligibility checks.
- Route 14 now gives explicit south-through-gap, east-along-shore, SURF guidance after opening and when using the finder again.
- Rayquaza and Kyogre route entrances referenced unregistered destinations. They now use the existing authored encounter chambers. Jirachi uses its actual wish chamber. The destination's existing progression requirements still apply.
- Hidden legendary entrances retain their source entrance for the return trip and safe-save relocation; ordinary antechamber entry retains its existing return.
- Regice's two-minute vigil now opens the wall automatically instead of requiring a second interaction with the inscription.

## Verified gameplay

- All 16 starter entrances: finder use, physical entry, physical exit and walk back to the source reveal point, in the normal postgame fixture. Evidence: `starters-first12.log`, `starters-last4.log`, `route14-walk-fixed.log`.
- Registeel, Regirock and Regice: public source map approach, scientist dialogue, chamber entry, actual puzzle input, protected battle, Master Ball capture, completion receipt, return prompt and return to the source. Evidence: `regis.log`, `ALL_REGI_PHYSICAL_PASS`.
- Focused automated checks: all 20 guarded access definitions, live gate recheck, stale step rejection, failed warp rollback, canonical source return, Route 14 guidance/reuse. Evidence: `tests/hidden_access_walkthrough_test.lua`.

This document is not a claim of full Windows/mobile, Blue/Yellow, or all-renderer coverage.

## Additional gameplay results

- Rival follow-up dialogue produced and recorded a starter hint in both normal postgame and NG+ (normal: Rowlet; NG+: Froakie). A deterministic rival visit and prior introductions were fixtures; the two conversations themselves used ordinary input. Evidence: `rivals-normal.log`, `rivals-ngplus.log`.
- Both Rayquaza entrances (Rock Tunnel 1F, Route 23), Kyogre's Seafoam entrance: finder, walk-in, capture and matching source return passed. The second Rayquaza route correctly shared the capture receipt. Evidence: `legends-green.log`, `legends-blue.log`.
- Groudon's ordinary antechamber portal exposed another real defect: arrival was enclosed on cave elevation tile 0x20, whose boundary to 0x05 is impassable. Four directional input attempts confirmed the trap (`groudon-blocked-before.log`). Replaced the two landing blocks with contiguous cave floor; native entry, capture and return passed (`portals.log`).
- Birth Island: Cinnabar researcher travel, all six triangle positions, Deoxys capture and return to Vermilion passed (`birth-capture.log`). Existing collection/seal/capture prerequisites were fixtures, not a replay of three full HEVO campaigns. The arrival overlapped the return sailor; local fix moves entry one cell north, with a separate arrival/return recheck.
- Jirachi's Victory Road entrance: reveal, actual chamber entry, capture/certificate flow and return to Victory Road passed (`legends-jirachi.log`). Full Dex, three completed HEVO paths and old portal capture receipts were prerequisites supplied in the isolated fixture.
- Birth Island corrected arrival and return passed without overlapping an NPC (`birth-entry-fixed.log`).
- A further native Vulkan test exposed a dialog ownership conflict: Easy Interactions replaced the authored drill prompt with generic STRENGTH. Fixed puzzle rocks, inscriptions, seals and stair markers now explicitly set `pushable=false`, preserving their scripts and preventing them from being moved as ordinary boulders. This fix applies to the volcano and the Regi sanctums.
- Complete volcano quest passed with no injected volcano puzzle flags: researcher travel, heat shield, six drill stones, four blockages, Magmar capture, east/south/west vents, both ascending stairs, Moltres capture, both descending stairs and departure. Evidence: `volcano.log`, `VOLCANO_PHYSICAL_ROUNDTRIP_PASS`. The initial Champion/Dex/HM prerequisites and capture items were fixtures as described above.

## Completed starter matrix and persistence

- All 16 starter entrances also passed physical entry and return in NG+. All 12 unique starter families were encountered through native movement/encounter handling, captured, and checked against the discovery receipt: Turtwig, Chimchar, Piplup, Snivy, Tepig, Oshawott, Chespin, Fennekin, Froakie, Rowlet, Litten and Popplio. Evidence: `starters-ngplus-captures.log` (16 roundtrip markers, 12 unique capture markers).
- The normal-game matrix covers Viridian City, Route 14, Viridian Forest, Route 15, Mt. Moon B1F, Routes 4/6/8/10, Celadon City, Route 12, Fuchsia City, Routes 18/21/25 and the Power Plant. The same 16 entrances passed in NG+.
- A dedicated normal-game Route 14 test also captured Snivy and returned (`route14-native-capture.log`).
- Route 14's actual displayed guidance was checked both after opening and on reuse. Saving inside the habitat, restoring into that habitat, physically leaving, re-entering and leaving again passed (`route14-reload.log`). Starter habitats intentionally resume inside their saved location; unlike the separate legendary safe-save mechanism, they do not relocate every save outside.
- Runtime gate checks passed for normal-game legendary denial, missing current seal, missing collection prerequisites, completed NG+ prerequisites, disabled portal option and incomplete Jirachi finale (`gates.log`).

## Test limits and corrected test assumptions

- Encounter captures used Master Balls and the existing 150-sighting guarantee. They validate native encounter/capture/discovery handling, not natural rarity or a normal player's time to find each starter.
- The normal matrix was completed in two runs. The first had 12 successful roundtrips before a living-world encounter interrupted the next test; the remaining four were rerun with living-world spawns disabled. The full NG+ matrix uses that traversal isolation throughout.
- The initial reload assertion incorrectly expected a starter habitat save to relocate outside. Source review confirmed supported in-habitat resume; the corrected driver then exercised resume, exit and re-entry successfully. The initial gate fixture omitted Hoenn Honey, a real generation prerequisite; that test fixture was corrected without weakening the product gate.
- Optional Pokémon graphics packs were not installed in this isolated base-package test. Some starter battles therefore show the packaged DLC placeholder. The Regi overworld objects currently use the generic authored monster sprite. This run does not certify species-accurate graphics or all model packs.
- Red edition on macOS/LÖVE only. No claim of Blue/Yellow, Windows/mobile, every renderer, full story progression, or complete HEVO campaign playthrough. Existing story, HMs, collection and seal requirements were supplied as fixtures; puzzle movement, interaction, battles, captures and return travel were performed through native input.

## Final Regi recheck

All three Regi scientist visits, puzzle solutions, actual captures, completion receipts and physical returns passed again after the final fixed-stone/dialog change. Regice waited 121 game seconds and opened without another interaction. Final evidence: `regis.log`, `ALL_REGI_PHYSICAL_PASS`; native process exited successfully after 208 seconds.

## Delivery

`Kanto-Ascendant-6.7.20-rc.1.zip` is a local test candidate only, not uploaded or installed in the player's game. It overlays the listed source changes onto the exact public 6.7.19 archive; every unchanged archive member remains byte-identical. `package-verification.json` records SHA-256 hashes and CRC verification. The nine changed runtime Lua files were byte-compared against the tested host and syntax-checked; the focused 20-entrance/40-guard-case suite passed.
