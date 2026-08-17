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
- Professor Oak and the Viridian old man remain the visible presenters during
  their scripted catching tutorials. The selected player character no longer
  replaces them in native 2D or supported staged renderer paths.
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

This follower update does not claim that free-roaming Wilds can preview the
Shiny state of a later battle encounter. Engines 0.1.96 and 0.1.98 generate
that Pokémon's DVs only when the battle starts; Ascendant does not pre-roll or
reroll them merely for an overworld colour preview.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.6.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.6.txt`.

Please report reproducible issues with edition, engine version, platform,
renderer, enabled mods, exact steps and—when progression is involved—a save
file.
