# Kanto Ascendant 6.5.15 — Wandertrainer Blackout Follow-up

Kanto Ascendant 6.5.15 is a save-compatible control-flow hotfix for Pokémon
Red, Blue and Yellow. No new game, story reset or save migration is required.

## Legacy Wandertrainer defeats

- Losing a Legacy Wandertrainer battle no longer leaves the trainer's queued
  farewell movement active after the native blackout changes maps.
- Cleanup now cancels only the retiring Wandertrainer's stale movement before
  it can keep the destination field in scripted-input mode.
- The 6.5.14 route/Center controller unlock remains in place.
- Normal blackout, party healing, protected Wandertrainer money, loss relief,
  encounter frequency, party scaling, rewards and battle AI are unchanged.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.15.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.15.txt`.
