# Kanto Ascendant 6.5.11 — Stability and Backport Hotfix

Kanto Ascendant 6.5.11 is a save-compatible gameplay, UI and compatibility
hotfix for Pokémon Red, Blue and Yellow. No new save or story reset is
required.

## Safe runtime placement

- Dynamically generated hosts now choose only reachable public floor tiles.
- The Verdant Relic guide no longer blocks Celadon's Game Corner entrance.
- Indigo Plateau visitors are randomized among separate accessible lobby
  pools and cannot appear behind counters, in walls or on access lanes.
- The same bounded placement authority now protects optional Heritage Cup,
  Johto research, event, starter-relic, tournament, NG+, Johto Masters and
  Factory hosts.
- Visible Wilds also reserve full multi-cell map connections, including the
  documented Viridian north exit.

## Battle, rewards and progression

- The Poké Flute is visible and usable from the normal battle Bag. Link and
  explicitly itemless battles remain sealed.
- Multiple Ascendant rewards promised while the Bag is full are stored in a
  persistent FIFO and delivered exactly once in their original order. Older
  scalar pending rewards migrate automatically.
- Rematch Mastery no longer distributes Overheat, Frenzy Plant, Blast Burn or
  Hydro Cannon before the corresponding save-bound authority is earned.
- Field-rematch rosters now seal their random authority to the durable
  playthrough identity before the first build. Changing visual options,
  mounting the Bicycle or reloading can no longer reroll a recruit family or
  evolution branch.
- Legacy Wanderers choose only parties appropriate to the scaled target level,
  repair explicit status-only sets with a species-legal damaging move and use
  Rest only at half HP or below. Their English and German challenge/farewell
  lines are now contextual and suppress immediate repeats.
- Permanently earned Hoenn starters remain available in Oak's middle starter
  catalogue in later lives.

## Menus and compatibility

- The release list uses vertical list navigation instead of the storage
  screen's 5×4 grid controller.
- KANTO and JOHTO Box filters are bounded to Dex #001–151 and #152–251;
  later/private IDs no longer leak into either region.
- Save-derived character art uses the engine Assets API instead of a
  sandbox-forbidden filesystem probe on minimum supported engines.
- Blue and Green retain their selected identity when mounting the Bicycle in
  GAME/KASC field-art mode instead of falling back to Red's development sheet.
- Native Voxel Ascendant trainer backs retain their correct role and facing.
- Valid Crystal sprite caches survive a cold start without redundant decode,
  clear and rewrite work.
- Gorochu uses one current catalogue/Summary/Box composition and one Shiny
  authority instead of overlapping legacy layers.
- Red's Crystal walking sheet uses the corrected gait phase.
- Engines with native custom-ball preflight no longer receive a second legacy
  Apricorn preview; older supported engines retain the compatibility bridge.

## Johto Masters text and handoff

- Johto Masters passages now describe the implemented direct-item and level
  evolution rules instead of canonical trade requirements.
- Reward target, reset and full-Bag behavior are stated accurately, and the
  completion-status handoff follows the actual 6.5 authority.

## Followers

- A selected friendship-evolution follower now earns one friendship point for
  every 32 genuine world steps, including before the Hall of Fame. Party
  reserves, boxed Pokémon and synthetic trainer clocks do not gain progress;
  starting from zero, 1,600 following steps leave the initial wary band.

## Included previous hotfixes

Version 6.5.11 includes 6.5.10's corrected Yellow rival progression and Tower
music, Leafeon's species-scoped physical Leaf Blade and selectable corrected
Raichu faces. It also includes 6.5.9's renewable Yellow Koffing and Weezing
encounters and edition-separated 251-species reachability matrix.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.11.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.11.txt`.
