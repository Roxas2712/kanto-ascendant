# Kanto Ascendant 6.0.11 — Neutral Voxel Terminology

Version 6.0.11 keeps the verified Voxel camera compatibility while removing
renderer-specific wording from player-facing menus and current documentation.

## Changed

- The regular **OPTIONS** row is now called **VOXEL BATTLE CAMERA**.
- Its choices are **VOXEL DEFAULT**, **CLASSIC VOXEL** and **WIDE VOXEL**.
- Existing saved camera selections remain valid and continue to apply without
  changing save data, progress or battle behavior.

## Verification

- Camera compatibility and menu-row regression coverage pass.
- The full trainer-rematch suite, strict package validation and package
  integrity checks pass.
