# Kanto Ascendant 6.7.32 — narrower Pyro volcano platform

Pyro/Blaine's suspended court is now 14 rather than 18 cells wide, centered on the same Pokéball marking. This leaves more of the surrounding lava visible with the matching VASC MAP battle view.

- Native collision and the VASC v3 geometry contract agree.
- Bridge, stair destinations, leader identity/party, quiz, music, badge and rewards retain their existing behavior.
- The engine's existing position recovery safely places older edge saves on the new walkable floor.
- Includes the complete public 6.7.31 baseline. No stat, ability or battle-rule changes.

**Update together with [VASC 3.0.60](https://github.com/Roxas2712/voxel-ascendant/releases/tag/v3.0.60)** for the central MAP battle, visible lava/fountains and new Sea Terrarium. Replace the existing mod copies and keep saves/settings.

Promoted from the tested 6.7.32-rc.1 candidate with identical runtime code and assets. The route suite passed 1,564 checks, and the native desktop test confirmed safe loading from all four removed edge columns. Lua syntax, archive CRC and file-hash checks passed.

---

Earlier candidate documentation (historical):

# KASC 6.7.32-rc.1 — narrower Blaine volcano court

Local candidate based on complete public KASC 6.7.31. The suspended court changes from 18 to 14 cells wide, centered on the same Pokéball. Native collision and the VASC v3 geometry contract agree. Bridge, stair destinations, Pyro's identity/party, quiz, music, badge and rewards are retained. The engine's existing invalid-position recovery places older edge saves on the new walkable floor.

Use with VASC 3.0.60-rc.1 for the central MAP battle, visible lava/fountains and new Sea Terrarium. Keep saves/settings and replace the existing mod copies. No stat or ability changes. Not publicly released.

---

Historical notes:

# Kanto Ascendant 6.7.31 — volcano audio and visitor fixes

- Plays one native transition cue after each successful scripted volcano stair link. Failed transitions stay silent.
- Uses Gym music in Blaine's corridor and battle chamber; keeps Dungeon music at the volcano foot.
- Supplies exact stair metadata for the matching VASC route geometry without changing collision or destinations.
- Declining honey no longer makes the Hoenn visitor disappear as her visit timer expires. She stays until the player leaves the house, then resumes her normal return schedule; the reward remains one-time.
- Makes rival spectator-duel Pokémon available to VASC's follower-style selection while retaining KASC's actor movement and lifetime.

Update together with **VASC 3.0.58** for the restored gatehouses, continuous glass-door view, lava battle arena, 3D stairs and seated visitor. Complete public 6.7.30 integration retained; no new save required.

The paired candidates passed 25 targeted suites and native desktop checks. A controlled Gorochu/Arcanine entry test found Intimidate lowering temporary Attack only; the user's uncertain historical stat change was not reproduced. No stat or ability logic changed. See the attached QA report for precise coverage.

---

Earlier candidate documentation (historical):

# Kanto Ascendant 6.7.30 — integrated Hoenn NG+ and Blaine volcano

- Combines the complete public 6.7.29 / latest integration base with Hoenn NG+, the revised Hoenn visitor, Blaine's volcano route and the Crystal colour correction. Keeps the embedded startup/loading screen, character/wardrobe integration, Wilds and memory/performance fixes.
- Restores eligible previously caught Hoenn families as base forms in the shared NG+ habitat pool. Latias and Latios can roam in NG+ with the Hoenn Dex; the visitor uses revised Gen-1 artwork and visit scheduling.
- Moves Blaine from the original final Gym room through a connecting tunnel and volcano approach to a compact battle platform. Preserves the quiz, existing saves, native story battle, Volcano Badge, Fire Blast and Master/Crown recognition.
- Keeps Gorochu's normal/shiny colours when Crystal battle graphics are explicitly selected, including the static fallback. Intentional Classic/native monochrome palettes remain supported.

Recommended companion: **VASC 3.0.57**. No new save is required. This replaces the incomplete local 6.7.29-rc.4.pyro.1/.2 companion, which had accidentally been based on 6.7.28. The unfinished, separate Sevii expansion is not included.

13 targeted regression suites plus native startup/continue, save/reload, Blaine route/battle-entry/reward/return checks passed. The reward test completes the native battle callback with a fixture victory; it is not an AI or balance test.

---

Earlier candidate documentation (historical):

# KASC 6.7.30-rc.1 — vollständige Integration mit Pyro und Hoenn NG+

Lokaler Teststand auf Basis des öffentlichen KASC 6.7.29 und des lokalen Integrations-RC.3. Enthält zusätzlich die Hoenn-NG+-Habitate, Eon-Roamer, den überarbeiteten Hoenn-Besucher, Pyros Vulkanroute mit kompakter 18×12-Kampfplattform und die explizite Crystal-Farbwahl für Gorochu.

Der ältere Begleiter 6.7.29-rc.4.pyro.2 basierte versehentlich auf 6.7.28. Dieser Kandidat stellt die fehlenden Lade-, Figuren- und Performance-Änderungen wieder her. Details und Prüfgrenzen stehen in BASE_INTEGRATION_AUDIT.md. Der separate, noch nicht freigabefertige Sevii-Entwicklungsstand ist nicht Bestandteil dieses Kandidaten.

Siehe auch BLAINE_VOLCANO_QA.md und NGPLUS_HOENN_QA.md.

---


# KASC 6.7.28 — Randomizer progression hotfix

Restores Mythic, Johto and Hoenn progress with the Wild Randomizer while preserving existing saves, seeds and counter values. No new game is required. See [release notes](RELEASE_NOTES_6.7.28.md) and [validation](QA-REPORT.md).

---

# KASC 6.7.27 — Errors / Diagnostics and support logs

One menu for errors, device diagnostics and manually confirmed KASC/VASC support logs, including when no error is present. See [release notes](RELEASE_NOTES.md), [support reports](SUPPORT_REPORTS.md) and [validation](QA-REPORT.md).

---

# KASC 6.7.26 — Habitat, Hunting Club and Mira update

Habitat music, a concise contract board and a distinctive Mira with short returning dialogue. See [release notes](RELEASE_NOTES.md) and [validation](QA-REPORT.md).

---

# Kanto Ascendant 6.7.23 — Legacy Bank fix

Prevents previous-run saves from re-locking the Bank after an NG+ handoff and recovers affected current saves when the stored transfer evidence is complete. See [release notes](RELEASE_NOTES_6.7.23.md) for installation and recovery details.

---

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

---

## Previous release documentation

## KASC 6.7.19 — Hunting Club and wardrobe (1/3)

Public test release, published as a regular GitHub release. Recommended pairing: VASC 3.0.37. These notes cover changes since KASC 6.7.18.

- Integrated the PKMN Hunting Club: 120 one-time contracts available after the eighth badge, requests involving up to three Pokemon, generation-aware requirements, Club Points, rare items, outfits and shiny eggs.
- Integrated a separate wardrobe Card with a home cabinet, outfit previews and per-character ownership. Only the current character's wardrobe is shown: Red cannot turn into Blue or Green by changing clothes.
- Club outfits unlock complete sets; their clothing and accessory parts can then be combined individually. Club sets cost 100 CP after ten completed contracts. Rewards belonging to other characters cannot be purchased for the current character.
- Champion clothing is awarded for that character's League/Hall of Fame victory. Existing victories are credited retroactively without another Elite Four clear or Club visit. Blue/Green need their own NG+ League victory; one character's win does not unlock everyone else's Champion outfit.
- The Champion reward unlocks its own set and parts, not the entire wardrobe. Other sets retain their individual Club reward requirements.
- Caps, reversed caps, glasses and sunglasses are exposed through their corresponding unlocked sets. Existing purchases receive the matching accessories retroactively without paying again.
- Switching HD, Voxel or native presentation preserves the selected clothing. Champion colors, collars, bags, trousers, shoes and fishing-pose overlays have been aligned more closely while retaining each style's own artwork.
- Club and wardrobe progress survives Legacy transitions. Combined installations use KASC's wardrobe authority; VASC alone supplies Red's wardrobe.

---

## KASC 6.7.19 — Exploration and combat fixes (2/3)

- Roaming rivals now provide the appropriate starter-habitat follow-up hints in normal postgame and NG+, including eligible NG+ runs without a new current-run Hall of Fame entry.
- Rival clues create starter-family traces, and the existing Trace Finder opens the authored paths. No extra unlock item is required. Normal-run opening receipts remain in that save.
- Fixed Route 14's unreachable search target and separated the southern clue from the eastern exit. Fixed Fuchsia's approach/return placement and Route 6's blocked passage; already-open Route 6 entrances are repaired.
- All 16 starter entrances were exercised in normal postgame and NG+, including entry and return. Red/Yellow geometry for all 20 starter/legendary access definitions was checked. The four legendary gates retain their existing NG+ and character-seal requirements.
- Driftglass's crystal now reports that it is dormant. Its evolution items can instead appear as very rare rematch drops.
- Volcano stairs activate automatically when walked onto, across both approach columns. Arrival landings prevent immediate return loops; expedition/puzzle gates and boat-return dialogue remain intact.
- Fixed the Research Atlas crash when selecting a seen Bulbasaur from habitats.
- Corrected Heavy Slam's interaction with Focus Punch disruption.
- Paired VASC includes safer hero-art handling, improved battle presentation and consistent character/outfit rendering.

---

## KASC 6.7.19 — Mythic Signals, Johto trials and validation (3/3)

- Fixed Mythic Signals progress being blocked by the first unfought visible Pokemon. Other eligible wild battles now advance the hunt independently.
- Regression example: starting at 432 remaining, 15 eligible battles now show 417 even when an earlier visible Pokemon remains unfought.
- Merely spawning or despawning Pokemon does not consume progress. Exact opponent matching, duplicate-event protection and single reservations for visible rare signals remain enforced. Concurrent progress cannot overwrite a newer seal, completion or bound signal.
- Status text explains eligible ordinary Kanto land encounters; water, Safari and protected special encounters do not count. Existing counters resume, but previously missed progress cannot be reconstructed.
- Removed repeated Legacy-archive writes from Johto quiz availability checks and repeated question reads. New quiz selection and actual answers/gate transitions still create checkpoints; wrong answers still reset the challenge.
- In the local nine-question comparison, archive writes fell from 54 to 12 and processing time from 346 to 80 ms (about 77% less). This measures processing/storage work, not the time spent reading or overall game FPS.
- Silver, Kris and Gold question/answer flows and their battle-portal transitions were checked in native LOVE. The paired VASC update shows the live countdown and question in ORAS fullscreen.
- The community's multi-minute quiz delay was not reproduced locally and still needs confirmation on the affected device/save. Physical Windows/mobile and longer sessions with the final paired build remain open checks.

Install: close the game and update the existing mod, preserving saves and optional artwork. Use the Preserve-Installed-Sprites installer for a backed-up desktop update, or merge the ZIP contents into the existing mod folder. Fully restart after updating.

---

## Previous documentation

# KASC 6.7.18 — Character selection confirmation

• Added a YES / NO confirmation after choosing a New Game character.
• NO or Back returns to the selection; the character is committed only after YES.
• NO is selected initially to prevent accidental confirmation.

Validation: native selection flow checked for confirm, cancel and return; paired with VASC 3.0.36.

---

## Previous release documentation

# Kanto Ascendant 6.7.17

World encounter artwork and Hoenn compatibility for Voxel Ascendant 3.0.34. Includes the occupied PC-box visibility fix from 6.7.16.

- Bundles species-specific native sheets and detailed voxel fronts for Groudon, Kyogre and Rayquaza, without requiring the optional follower archive.
- Adds 682 existing authored Crystal/Emerald animation frames for 22 world encounter species. VASC uses these as pixel-art fallbacks; selected available HD and Stadium providers retain priority. Frame timings and original artwork are preserved.
- Fixes the Deoxys puzzle triangle's runtime cell/pixel position so its visual location and interaction position move together through the puzzle. Encounter and capture gates remain intact.
- Corrects RED/BLUE/GREEN trial visibility in the voxel camera using world depth, while retaining the intended puzzle visibility radius. Older renderers retain a guarded fallback.
- Avoids projecting flat 2D world-surround padding into voxel views; native 2D surroundings remain available.

Install **Kanto-Ascendant-6.7.17.zip** and **Voxel Ascendant 3.0.34** for the combined scenery/animation update. An optional installer backs up the existing mod and preserves omitted downloaded sprites. Existing saves and HD downloads do not need to be deleted.

Native encounter/puzzle checks and focused regression tests passed. This update does not claim a complete redesign of every Hoenn room or a full new playthrough on physical mobile hardware.

---

## Previous release documentation

# Kanto Ascendant 6.7.16 — PC box visibility hotfix

PC boxes could look empty after a Pokémon image failed to load, even while the stored Pokémon remained selectable. This update fixes a reproducible cause of that display failure.

- PC previews and box sprites now use the engine's asset loader, including generated and overridden artwork.
- A failed image or sprite-provider lookup can recover without restarting the session. Changing a Pokémon's appearance no longer reuses a stale image for that species.
- If artwork remains unavailable, a visible Poké Ball marks the occupied slot. Stored Pokémon and save data are not modified by this display fix.
- Includes the 6.7.15 fixes for Yellow NG+ Thunderheart progression and reachable Rocket raid checkpoints in Cerulean Cave.

## Updating

Update KASC to 6.7.16 and fully restart the game. Keep installed sprite downloads and imports; do not delete the mod folder first. The ZIP is the normal launcher package. The optional **Preserve-Installed-Sprites** installer backs up the installation and preserves optional sprite content.

## Validation

28 focused PC-rendering checks passed on Gen1 Recomp 0.2.60, covering both FireRed layouts, withdrawal previews, HGSS grid icons, asset resolution, cache invalidation, recovery and unchanged box contents. Native LÖVE rendering was visually checked with 20 sprites and with 20 fallback markers. The assembled package was loaded with Blue data, and Lua syntax, archive integrity and installer preservation checks passed. The reporting player's exact mod configuration was unavailable; manual Windows/mobile testing was not performed.
