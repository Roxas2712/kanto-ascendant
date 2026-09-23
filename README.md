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
