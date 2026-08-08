# Kanto Ascendant 6.0.7 — Release Gate Hotfix

Version 6.0.7 is a save-compatible packaging hotfix following the New
Game+ Steward fix in 6.0.6.

## Fixed

- The Atlas/Legacy ROM-free regression now tracks the current release
  manifest instead of the obsolete 6.0.5 version.
- CI packaging, audit and release-candidate filenames are aligned with
  version 6.0.7.

## Compatibility and saves

- Pokémon Red, Blue and Yellow.
- English and German.
- Existing Kanto Ascendant saves; no migration is required.
- No gameplay, progress, inventory, party or New Game+ state is changed by
  this release.

## Verification

- ROM-free regression suite, including Atlas/Legacy and New Game+ Steward
  location coverage.
- Strict Modkit validation, release-boundary audit and package inspection.
