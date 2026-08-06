# Kanto Ascendant 6.0.5 — Johto Encounter Level Fix

Version 6.0.5 is a save-compatible balance hotfix for the optional Johto
currents and postgame researched habitats.

## Fixed

- Ordinary Johto replacements now use the rounded, Gen-I-probability-weighted
  average level of the active route plus a random 2-5 levels.
- The same rule is used by classic 2D encounters, Wilds of Kanto 1.7.1 and
  permanent researched Johto habitats.
- Ordinary Johto encounters can never exceed the route average plus five or
  the level-100 ceiling.
- Primal traces, guaranteed story encounters and other explicitly authored
  special battles retain their designed levels.
- The FAQ's researched-habitat table now lists locations without obsolete
  fixed encounter levels and explains the route-based scaling.

## Compatibility and saves

- Pokémon Red, Blue and Yellow.
- English and German.
- Existing Kanto Ascendant 6.0.x saves; no migration is required.
- Classic 2D, Crystal, Crystal Animated Sprites, Voxel and Wilds paths.
- Encounter frequency, species pools, rare pity counters and scripted special
  encounters are otherwise unchanged.

## Verification

- Full ROM-free regression suite and Johto Signals contracts.
- Wilds of Kanto 1.7.1 compatibility suite.
- Strict Modkit validation and release-boundary audit.
- Reproducible `.modpkg`/`.zip` package inspection.
