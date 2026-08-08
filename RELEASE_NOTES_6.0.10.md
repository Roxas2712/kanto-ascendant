# Kanto Ascendant 6.0.10 — Visible Classic Voxel Camera Fix

Version 6.0.10 corrects the `CLASSIC VOXEL` compatibility setting for
`DRAMALESS_SHAPE` 1.6.2.ST.

## Fixed

- `CLASSIC VOXEL` now updates Dramaless Shape's `frameH` battle composition
  setting, not only the virtual camera position. The classic selection is
  therefore visibly closer during a live Voxel battle.
- Switching back to `FORK DEFAULT` restores Dramaless Shape's original
  distance, height and frame size exactly.

## Compatibility

- Existing saves remain compatible; the setting only affects battle
  presentation.
- Dramaless Shape 1.6.2.ST and legacy Dramatic Shape installations remain
  supported.

## Verification

- Regression coverage checks the real option-change event, battle-boundary
  persistence and exact restoration to the fork defaults.
- Live Dramaless Voxel Mega-Evolution QA compares the fork and classic camera
  modes in isolated profiles.
