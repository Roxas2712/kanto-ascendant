# Kanto Ascendant 5.4.2 — Support Hotfix

5.4.2 is a save-safe hotfix for current 5.4.x players. It contains the
confirmed Discord support fixes completed after 5.4.1 without introducing the
separate Johto Signals expansion planned for 6.0.

## Fixed

- Master and Crown Leader victories are committed through both the battle
  callback and the victory-only battle event. Existing saves with a missing
  circuit crest repair their progress from Ascendant's recorded boss history.
- Lt. Surge/Major Bob now checks the permanent Thunderheart before choosing
  his conversation:
  - If the item is missing, he offers it first even after the Elite Four or
    when the save already records Gorochu.
  - Once it is owned, he returns to the normal Master/Crown rematch chain.
- Event Archive entries now explain that `READY` means unlocked and direct
  players to the relevant Cup city or roaming habitat.

## Documentation

- Added the complete public FAQ with individually collapsed gameplay spoiler
  sections and a spoiler-free current-support status.

## Compatibility

- Existing Red, Blue and Yellow saves update in place.
- The internal mod ID remains `trainer_rematch`.
- No Johto Signals or Orange Islands development content is included.

## Install or update

1. Download `kanto-ascendant-5.4.2.modpkg`.
2. Import it through the Gen1 Recomp launcher.
3. Replace the existing Kanto Ascendant installation when prompted.
4. Continue the same save normally.
