# Kanto Ascendant 6.7.20-rc.1 — Habitat access hotfix candidate

Local test candidate, not a published release. Based on 6.7.19 and tested with VASC 3.0.37.

Validation correction: the earlier 6.7.19 access checks skipped parts of the physical handoff and were not complete gameplay roundtrips. This candidate was checked with native movement, menus, puzzle input, captures and return travel; see [the exact test results and limitations](tests/habitat_playthrough/RESULTS.md).

- Opened hidden paths now also activate by walking onto the exit on supported engines without native edge-warp support. A-button compatibility remains available; receipts and live progression gates still apply.
- Route 14 explains the actual route after opening: south through the gap, east along the shore, then SURF east. Using the finder again repeats that guidance.
- Rayquaza and Kyogre entrances now target their existing encounter chambers. The Jirachi convergence entrance leads to the wish chamber. Existing destination progression requirements remain enforced.
- Hidden legendary chambers return to the entrance used, including safe-save relocation. Ordinary portal and captain journeys retain their normal return destinations.
- Regice's two-minute vigil opens the seal automatically.
- Fixed Groudon’s chamber arrival being trapped by native elevation collisions.
- Fixed volcano drill dialogs and Regi inscriptions being replaced by generic STRENGTH dialogs. Authored puzzle stones and seals cannot be pushed as ordinary boulders.
- Birth Island arrival no longer overlaps the return sailor.

Input-driven gameplay drivers and fixture documentation are included under `tests/habitat_playthrough`. See the accompanying test report for completed cases and limitations. Starting positions and prior story/collection requirements are fixtures; this is not a replay of entire campaigns or a cross-platform certification.
