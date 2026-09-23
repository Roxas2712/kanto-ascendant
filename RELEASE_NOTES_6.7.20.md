# KASC 6.7.20 — Habitat and legendary access hotfix

Public test release. Recommended pairing: VASC 3.0.38. Changes since 6.7.19:

- Opened hidden paths now also activate when walked onto on supported engines without native edge-warp support. The A-button compatibility action remains available. Live progression checks and opening receipts still apply; unsuccessful warps roll back safely.
- Route 14 now explains the actual path: south through the gap, east along the shore, then SURF east. Using the Trace Finder again repeats the guidance.
- Rayquaza and Kyogre hidden entrances now lead to their existing encounter chambers; the Jirachi convergence entrance leads to the wish chamber. Existing NG+, character-seal and collection prerequisites remain enforced.
- Hidden legendary chambers return to the entrance used, including safe-save relocation. Ordinary portals and captain journeys retain their normal destinations.
- Regice's two-minute stationary vigil now opens the seal automatically, without another A press.
- Corrected Groudon's chamber arrival, where native elevation collisions could trap the player.
- Fixed generic STRENGTH interactions overriding volcano drill dialogs and Regi inscriptions. Authored puzzle stones, seals and markers no longer behave as ordinary pushable boulders.
- Birth Island arrival no longer overlaps the return sailor.

## Validation

Input-driven macOS gameplay checks covered all 16 starter entrances in Normal and NG+, entry/return travel, the 12 unique starter captures, Normal Route 14 capture and save/reload, and rival hints in both modes. The three Regis, both Rayquaza approaches, Kyogre, Groudon, Jirachi, Birth Island and the complete volcano route were checked through their relevant puzzles, captures and return travel. Focused tests cover all 20 guarded entrance definitions, successful/failed handoffs and rollback.

Correction to the previous release's testing claim: some 6.7.19 access checks skipped physical handoffs and were not complete gameplay roundtrips. The new checks use native movement, menus and puzzle input. Prior story/collection progress, starting locations and capture supplies are fixtures; this is not a complete campaign replay or a physical mobile/Windows certification. Optional artwork was not part of the habitat test inventory. Detailed reproducible drivers and limits are included in tests/habitat_playthrough/RESULTS.md.

## Install

Close the game, preserve your saves and optional artwork, update the existing mod, then restart. The ZIP contains the complete mod. The optional Preserve-Installed-Sprites desktop installer backs up the installation and retains omitted optional files. SHA-256 files accompany both downloads.
