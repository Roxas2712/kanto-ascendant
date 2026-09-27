# KASC 6.7.28 — Randomizer progression hotfix

Complete update based on 6.7.27. Fixes progress that could stop when the Wild Randomizer changed an encounter's species.

## Changes
- Mythic Signals now count eligible randomized grass battles for echoes, true manifestations and retries. This covers visible Wilds and classic encounters; the existing odds and guarantees are unchanged.
- Johto primal-trace counters follow the actual randomized battle. Guaranteed trace Pokémon retain their authored species.
- Hoenn introductions and trace hunts now work with the Wild Randomizer, including visible battles and the existing 50-encounter guarantee. Active Nuzlocke exclusions remain unchanged.
- The Randomizer respects protection carried by authored encounters, including Mythics, Hoenn discoveries/roamers and starter habitats.
- Only the matching started battle advances encounter progress. Rendering, despawning, suppressed encounters and duplicate notifications do not grant progress.

Existing counter values, seeds, run rules and saves are preserved. Missed encounters from before this fix cannot be reconstructed and are not added retroactively. No new game is required.

## Validation
Regression tests cover the reported 509 stall, all three Mythic counters and guarantees, all four Johto primal traces, Hoenn introductions and classic/visible trace hunts, and all twelve Generation IV–VII starter habitats through their 151st encounter and capture, with and without the Randomizer. Additional checks cover Shiny Dex statistics, Trace Finder rematch guarantees, world-event timers, Hunting Club contracts, cancellation, duplicate starts, persistence and existing Nuzlocke exclusions. See QA-REPORT.md for scope and limits.

## Install
Close the game, update KASC through the launcher or import `Kanto-Ascendant-6.7.28.zip`, then restart. This hotfix does not require a new VASC release.
