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
