# Kanto Ascendant 6.5.17 — Legacy Bank and HD Trainer Hotfix

Kanto Ascendant 6.5.17 is a save-compatible storage and presentation hotfix
for Pokémon Red, Blue and Yellow. No new game or archive migration is needed.

## Legacy Bank

- The Legacy Bank menu now includes **ALL TO PC BOXES** / **ALLE IN
  PC-BOXEN**. It transfers every currently withdrawable Pokémon directly to
  free ordinary PC Box slots.
- The complete PC capacity is checked before the first Bank lease. If space is
  insufficient, the operation changes nothing and reports how many additional
  slots are required. Sealed Pokémon remain safely in the Legacy Bank.
- In the FireRed organizer, START marks or unmarks Pokémon. The selection
  persists across Bank pages; A then opens one action for the full selection.
- Every individual, selected or complete Bank withdrawal now records the
  species as seen and owned in the Pokédex.
- On load, the hotfix repairs missing Pokédex ownership for older Legacy
  withdrawals still physically present in the Party or PC Boxes.

## HD combat-front trainers

- The authored 128px KASC trainer fronts were already packaged. Pixelated
  staged trainers occurred when a renderer lifecycle reload replaced the
  public source function but left the old boolean compatibility marker set;
  the native 64px trainer picture was then enlarged in the Voxel scene.
- KASC now verifies the exact installed wrapper function on every save load
  and rebinds the approved HD source if VASC recreated that public seam.
- The small companion assets remain available only for native 2D and safe
  fallback compatibility. Supported staged battles resolve the authored HD
  combat-front source.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.17.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.17.txt`.
