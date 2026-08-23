# Kanto Ascendant 6.5.14 — Wandertrainer Blackout Hotfix

Kanto Ascendant 6.5.14 is a save-compatible control-flow hotfix for Pokémon
Red, Blue and Yellow. No new game, story reset or save migration is required.

## Legacy Wandertrainer defeats

- Losing a Legacy Wandertrainer battle no longer leaves RED unable to move or
  open the menu after the native blackout returns the party to a Pokémon
  Center.
- Encounter cleanup now releases the route controller that started the battle
  and the current post-blackout overworld controller before retiring the stale
  Wandertrainer actor.
- The normal blackout, party healing, protected Wandertrainer money, loss
  relief, encounter frequency, party scaling, rewards and battle AI are
  unchanged.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.14.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.14.txt`.
