# Kanto Ascendant 6.5.7 — Trainer Card and Yellow Partner Hotfix

Kanto Ascendant 6.5.7 is a save-compatible hotfix for Pokémon Red, Blue and
Yellow. No new save or story reset is required.

## HD standard Trainer Card

- The native Trainer Card entry now renders the approved 640×400 HD standard
  card instead of scaling the old low-resolution layout.
- The card keeps the fixed **KANTO ASCENDANT** brand, selected trainer identity,
  active earned title, money, play time and all eight Kanto Leader/badge slots
  together on one screen.
- Existing 128-pixel player and Leader masters supply the character art. The
  badges are drawn by the card and require no new third-party image assets.
- Giovanni stays a completely black silhouette until the save contains one of
  the real Giovanni victory flags. An Earth Badge by itself cannot reveal him.
- This hotfix contains one fixed standard card. Unlockable card variants, the
  larger title catalogue and cards around scheduled battles remain outside
  6.5.7.

## Yellow partner emotions

- Yellow's original Oak script gives its level-5 Pikachu with three command
  arguments. Ascendant now recognizes that exact vanilla signature and marks
  only the newly created Oak gift as the persistent partner.
- Other Pikachu do not receive partner emotions. The marked identity remains
  attached to the same Pokémon while it is fainted, stored or evolves into
  Raichu or Gorochu, so independently selected followers can keep using their
  existing fallback behavior.
- Existing affected saves repair only an unambiguous case with exactly one
  eligible self-owned Pikachu, Raichu or Gorochu. If several candidates exist,
  Ascendant does not guess which one was Oak's gift.

## Yellow's German Oak's Lab text

- The ungrammatical line is replaced with the approved exchange:

  ```text
  GRÜN: Ich nehme
  dieses POKéMON!

  Moment, {PLAYER}!
  War das für dich?
  ```

- Both authored pages use the two visible dialogue rows cleanly. The adjacent
  English text is byte-for-byte unchanged, and the broader Red, Green and Blue
  character-dialogue revisions remain outside this hotfix.

## Optional HGSS Box-grid walkers

- **START → ASCENDANT → OPTIONS → BAG / STORAGE → BOX ICONS** now offers
  `CURRENT` and `HGSS WALKERS`. Existing and fresh saves remain on `CURRENT`
  unless the player explicitly opts in.
- The optional style changes only the twenty cells in the right-hand 5×4 Box
  grid. The large selected-Pokémon preview on the left remains on its existing
  front-sprite renderer.
- It uses frame zero of an already bundled Wilds 16×96 normal or Shiny walking
  sheet after resolving the Pokémon's real source-Dex identity. Gorochu,
  unsupported forms and absent or invalid sheets fall back to the established
  grid icon.
- Version 6.5.7 adds no new walker image bytes. The existing Wilds/follower
  attribution and licensing notice in `THIRD_PARTY_NOTICES.md` remains the
  authoritative provenance record.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.7.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.7.txt`.

Please report reproducible issues with edition, engine version, platform,
renderer, enabled mods, exact steps and—when progression is involved—a save
file.
