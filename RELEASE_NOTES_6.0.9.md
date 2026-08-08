# Kanto Ascendant 6.0.9 — Battle Art Voxel Presentation Fix

Version 6.0.9 is a save-compatible compatibility fix for
`BATTLE_ART_VOXEL_FORK` 1.7.6.

## Fixed

- Mega Evolution and Gorochu's 230×207 Voxel cards now report anchors that
  match their own canvas. This keeps their feet and centre aligned with
  BATTLE_ART's staged battle camera instead of inheriting the 160×144
  Game Boy card anchor.
- BATTLE_ART's **FRONT SPRITES** and world-space **BACK SPRITES** selections
  now choose the matching Kanto Mega/Gorochu master art.
- BATTLE_ART owns every live staged battle card. Kanto Ascendant's classic 2D
  Mega rear overlay remains available only when BATTLE_ART falls back to a
  non-staged Game Boy battle.

## Compatibility and saves

- Pokémon Red, Blue and Yellow.
- English and German.
- BATTLE_ART_VOXEL_FORK 1.7.6 and legacy Dramatic Shape installs.
- Existing Kanto Ascendant saves; no migration is required.
- No story, Pokémon, inventory or progression data is reset or changed.

## Verification

- BATTLE_ART public-API regression coverage for Mega front/back routing,
  staged fallback behaviour and card anchors.
- Gorochu Voxel front/back and anchor regression coverage.
- ROM-free suite, strict Modkit validation and package-boundary audit.
