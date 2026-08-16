# Kanto Ascendant 6.5.0 RC26 Test

RC26 replaces the withdrawn RC25 test archive after the first full-save field
test. No requested gameplay system was removed.

- Repairs imported RC25 saves whose bedroom-PC Randomizer/Nuzlocke controls
  were silently locked before the player ever confirmed them.
- Prevents RED from entering BLUE/GREEN trials, safely rescues already trapped
  saves, and makes RED tablets physically interactable.
- Reattaches RED darkness on direct save loads, assigns the dungeon music to
  every RED floor and keeps the five-statue visibility contract explicit.
- Preserves the character-bound Level-70 (cycle-scaled to 100) trial encounter
  tables and the bundled Visible Wilds path.
- Removes the grey 16x16 terrain boxes around transparent true-colour world
  actors, including on older compatible apps.
- Preserves animated Crystal Pokémon/player colour in the Hall of Fame and
  adds versioned FULL-Voxel standees for Lorelei, Bruno, Agatha and Lance
  without overwriting their existing 2D art.
- Restores the post-Elite-Four Johto Masters host for qualifying existing
  saves and keeps Silver/Kris/Gold progression intact.
- Adds SELECT item information to Ascendant's pocket Bag.
- Rebalances the Crown League's unnecessary duplicate species: Lorelei uses
  ARTICUNO, Agatha uses MISMAGIUS, and Lance uses KINGDRA plus DRAGONITE;
  the Champion retains his authored Johto legendary roster.

Do not use `kanto-ascendant-6.5.0-rc25-test.zip` after installing RC26.
