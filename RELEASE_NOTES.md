# Kanto Ascendant 6.7.32 — narrower Pyro volcano platform

Pyro/Blaine's suspended court is now 14 rather than 18 cells wide, centered on the same Pokéball marking. This leaves more of the surrounding lava visible with the matching VASC MAP battle view.

- Native collision and the VASC v3 geometry contract agree.
- Bridge, stair destinations, leader identity/party, quiz, music, badge and rewards retain their existing behavior.
- The engine's existing position recovery safely places older edge saves on the new walkable floor.
- Includes the complete public 6.7.31 baseline. No stat, ability or battle-rule changes.

**Update together with [VASC 3.0.60](https://github.com/Roxas2712/voxel-ascendant/releases/tag/v3.0.60)** for the central MAP battle, visible lava/fountains and new Sea Terrarium. Replace the existing mod copies and keep saves/settings.

Promoted from the tested 6.7.32-rc.1 candidate with identical runtime code and assets. The route suite passed 1,564 checks, and the native desktop test confirmed safe loading from all four removed edge columns. Lua syntax, archive CRC and file-hash checks passed.
