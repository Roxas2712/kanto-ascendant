# Kanto Ascendant 6.5.6 — Character and Follower Hotfix

Kanto Ascendant 6.5.6 is a save-compatible hotfix for Pokémon Red, Blue and
Yellow. No new save or story reset is required.

## Characters and catching tutorials

- Red and Green keep their own English and German voices throughout every
  Oak's Lab starter branch. Blue retains the native confident dialogue and is
  the only rival who treats Oak as his grandfather.
- Red addresses Professor Oak respectfully. Green remains friendly and
  absent-minded, and now acknowledges and apologizes when she takes the
  starter that was intended for the player.
- Yellow's scripted catching tutorial uses the existing approved Professor
  Oak standee in supported staged renderers instead of their small 2D
  fallback. No approved staged model exists for Viridian's old man, so only
  the Red/Blue old-man tutorial temporarily delegates to the native 2D battle;
  the next battle uses the configured renderer normally. The selected player
  character replaces neither presenter.
- Green uses the corrected six-frame Crystal walking sheet. The public 6.5.5
  sheet remains the first validated fallback and the older sheet remains the
  second fallback. Battle, profile, bicycle, fishing, throwing, HD and Voxel
  artwork are unchanged.

## Kanto Shiny followers

- All Kanto species #001-151 have separate normal and Shiny follower sheets
  derived from their canonical Crystal palettes.
- The owned Pokémon's actual DV-based Shiny state selects the matching sheet.
- If a Shiny sheet is absent or invalid, the normal sheet remains the safe
  fallback instead of breaking the follower.
- Existing Johto and Gorochu normal/Shiny routing remains unchanged.
- In Yellow, fainting or storing the authored partner no longer hides the
  independently selected extras. Its logical first slot remains reserved, so
  a configured count of two shows one extra and six shows up to five; when
  Pikachu returns, it is prepended exactly once and keeps its native story and
  mood interaction.

This follower update does not claim that free-roaming Wilds can preview the
Shiny state of a later battle encounter. Engines 0.1.96 and 0.1.98 generate
that Pokémon's DVs only when the battle starts; Ascendant does not pre-roll or
reroll them merely for an overworld colour preview.

## Pokédex boundary and areas

- A fresh Pokédex stops at #151. After its real Driftglass National Dex
  upgrade it stops at Celebi (#251), even though private runtime species slots
  #252-279 remain registered for their own systems.
- A seen Johto species shows its authored Kanto habitat on **AREA** only while
  that habitat is genuinely active under the save's research and migration
  current. Inactive or undiscovered habitats remain hidden.

## Gameplay and text

- **Wild Level Scaling** is now a separate option and defaults to **OFF**.
  Trainer difficulty is unchanged. Turning the option on restores the previous
  badge-phased difficulty bonus for wild Pokémon; leaving it off preserves the
  level supplied by the game, Randomizer or encounter author.
- In native 2D battles, Ascendant-owned enemy Crystal fronts sit eight pixels
  higher and farther left. Large animated, Shiny, Mega and Gorochu frames no
  longer cover the player's Pokémon name; Gen-I sprites, trainer art, player
  backs and staged renderers keep their existing placement.
- Dialogue now uses both visible text rows before asking for another button
  press. Authored pauses and page breaks remain intact, while long English and
  German lines still paginate safely instead of scrolling past unread.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.6.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.6.txt`.

Please report reproducible issues with edition, engine version, platform,
renderer, enabled mods, exact steps and—when progression is involved—a save
file.
