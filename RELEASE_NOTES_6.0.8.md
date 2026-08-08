# Kanto Ascendant 6.0.8 — Battle Art Voxel Compatibility Hotfix

Version 6.0.8 is a save-compatible hotfix for Battle Art Voxel 1.7.6. It also
includes the prepared 6.0.7 release-gate correction and the 6.0.6 reachable
New Game+ Steward fix.

## Fixed

- Mega Evolution recognizes Battle Art Voxel's renamed
  `BATTLE_ART_VOXEL_FORK` export.
- Front-facing Voxel battles no longer receive Kanto Ascendant's classic 2D
  Mega rear-sprite overlay or its white background card.
- Gorochu's high-resolution Voxel front/back cards work with both Battle Art
  Voxel 1.7.6 and legacy Dramatic Shape installs.

## Compatibility and saves

- Pokémon Red, Blue and Yellow.
- English and German.
- Battle Art Voxel 1.7.6 and legacy Dramatic Shape Voxel installs.
- Existing Kanto Ascendant saves; no migration is required.
- No story, Pokémon, inventory or progression data is reset or changed.

## Verification

- Battle Art Voxel 1.7.6 API regression coverage for Mega Evolution.
- Gorochu Voxel presentation regression coverage.
- ROM-free suite, strict Modkit validation and package-boundary audit.
