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
