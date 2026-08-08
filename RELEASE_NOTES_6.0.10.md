# Kanto Ascendant 6.0.10 — Visible Classic Voxel Camera Fix

Version 6.0.10 corrects the `CLASSIC VOXEL` compatibility setting for the
compatible Voxel renderer.

## Fixed

- `CLASSIC VOXEL` now updates the renderer's `frameH` battle composition
  setting, not only the virtual camera position. Its calibrated wider frame
  compensates for the renderer's larger models to match the original Voxel
  battle scale.
- `WIDE VOXEL` offers a further-out 3× frame for players who want the whole
  large Mega model in view.
- Switching back to `VOXEL DEFAULT` restores the renderer's original
  distance, height and frame size exactly.
- The setting is now in the regular **OPTIONS** menu beside the Voxel
  controls. It is shown only while the compatible renderer is enabled, rather than
  under Kanto Ascendant's per-mod options.

## Compatibility

- Existing saves remain compatible; the setting only affects battle
  presentation.
- Compatible Voxel renderer installations remain supported.

## Verification

- Regression coverage checks the real option-change event, battle-boundary
  persistence and exact restoration to the fork defaults.
- Live Voxel Mega-Evolution QA compares the standard and classic camera
  modes in isolated profiles.
