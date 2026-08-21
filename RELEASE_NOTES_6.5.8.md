# Kanto Ascendant 6.5.8 — Gen1Recomp 0.2.14 New-Game Hotfix

Kanto Ascendant 6.5.8 is a save-compatible compatibility hotfix for Pokémon
Red, Blue and Yellow. No new save or story reset is required.

## New-game freeze fixed

- Gen1Recomp 0.2.14 changed Oak's introduction so the first player-name prompt
  remains held until the engine's native naming step releases it.
- Kanto Ascendant replaces that naming step with its Red/Green/Blue selector
  and NamingScreen. The held prompt could therefore reappear after player and
  rival selection and prevent the transition into the game world.
- Ascendant now releases the engine-owned prompt immediately before opening
  its custom NamingScreen. Red, Blue and Yellow use the repaired shared path.
- Legacy Journey / New Game Plus keeps its existing Oak hand-off and archive
  behavior.

## Engine compatibility

- The cleanup is feature-detected. Gen1Recomp 0.2.14 and later builds that
  expose the held-prompt lifecycle use it.
- Older builds—and any future upstream version that removes that lifecycle
  again—continue through Ascendant's previous naming path unchanged.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.8.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.8.txt`.

Please report reproducible issues with edition, engine version, platform,
renderer, enabled mods, exact steps and—when progression is involved—a save
file.
