# Kanto Ascendant 6.0.9 — Dramaless Shape Presentation Fix

Version 6.0.9 is a save-compatible compatibility fix for
`DRAMALESS_SHAPE` 1.6.2.ST.

## Fixed

- Mega Evolution and Gorochu now redraw their 96px masters into Dramaless
  Shape's renderer-native 160×144 cards while retaining its 80×96 anchor.
  This keeps their feet and centre aligned with the staged battle camera.
- Dramaless Shape's **FRONT SPRITES** and world-space **BACK SPRITES**
  selections now choose the matching Kanto Mega/Gorochu master art in the
  renderer's 2D-3D views.
- Dramaless Shape owns every live staged battle card. Kanto Ascendant's classic
  2D Mega rear overlay remains available only when the renderer falls back to
  a non-staged Game Boy battle.
- Dramaless Shape's **STADIUM** views keep their own 3D models; Kanto
  Ascendant does not overlay 2D cards onto those models.

## Camera choice

- `DRAMALESS BATTLE CAMERA` is a default-off presentation choice. Select
  **CLASSIC VOXEL** in Kanto Ascendant's options to restore the original
  Dramatic Shape telephoto battle framing; **FORK DEFAULT** keeps Dramaless
  Shape's wider framing for its larger models. This affects only the current
  renderer session and does not change save progress.

## Compatibility

- Pokémon Red, Blue and Yellow.
- English and German.
- Dramaless Shape 1.6.2.ST and legacy Dramatic Shape installs.
- Existing Kanto Ascendant saves; no migration is required.
- No story, Pokémon, inventory or progression data is reset or changed.

## Verification

- Dramaless Shape public-API regression coverage for Mega front/back routing,
  staged fallback behaviour and card anchors.
- Gorochu Voxel front/back and anchor regression coverage.
- Full trainer-rematch regression suite, static scope audit, strict package
  validation and packed-release audit.
