# Kanto Ascendant 6.5.13 — Wandertrainer and Yellow Battle-Art Hotfix

Kanto Ascendant 6.5.13 is a save-compatible presentation and dialogue hotfix
for Pokémon Red, Blue and Yellow. No new game or story reset is required.

## Contextual Wandertrainer dialogue

- Legacy Wandertrainers now draw from twelve role-aware English/German
  greetings instead of the small generic road-text set.
- Greetings that claim victories over legendary Pokémon appear only after the
  current playthrough has entered the Hall of Fame. Progress inherited from
  another life cannot trigger them early.
- A committed Legacy partner is acknowledged only while it is actually in the
  active party. The dialogue names both that Pokémon and the Wandertrainer's
  lead partner.
- Red, Blue and Green path challengers distinguish an accomplishment completed
  in the current life from one inherited from another life.

## Farewells and field departure

- Player victories and defeats each use six distinct bilingual farewells.
- The opposing trainer speaks while still visible, then walks over a bounded
  safe route until outside the camera.
- Departure never walks through walls, warps, signs, NPCs or the player.
  Missing paths and rejected movement use a bounded exact-once removal
  fallback, so the encounter cannot block the field.
- Wandertrainer cadence, frequency settings, party scaling, rewards, loss
  relief and battle AI are unchanged.

## Yellow Jessie, James and Meowth battle identity

- Yellow's four Jessie/James encounters now use the approved combined
  Jessie/James/Meowth staged battle art instead of being reduced to a generic
  Team Rocket grunt by supported Voxel battle renderers.
- The resolver requires Yellow, the exact live Rocket trainer record and one
  of the four original story-party indices. Ordinary Rocket grunts and every
  Red/Blue battle remain unchanged.
- Both packaged sizes and the provenance receipt are verified by exact
  SHA-256. If no approved surface can be decoded, the battle safely returns to
  Yellow's native Jessie/James picture rather than showing the wrong trainer.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.13.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.13.txt`.
