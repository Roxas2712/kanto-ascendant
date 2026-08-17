# Kanto Ascendant 6.5.5 — Interaction and Safety Hotfix

Kanto Ascendant 6.5.5 is a save-compatible hotfix for Pokémon Red, Blue and
Yellow. It concentrates on Wilds spawn safety, reliable Field Kit and Bag
controls, character-specific rival writing, and two presentation defects
reported after 6.5.4.

No restart or new save is required. Existing options are preserved, including
an explicitly disabled battle-animation setting.

This document remains spoiler-light. Exact progression and location details
stay in the collapsed sections of [FAQ.md](FAQ.md).

## Wilds and progression safety

- Oak's Lab remains free of visible Wilds until the player has received a
  starter. A Wilds entity can no longer block the starter choice.
- Visible spawns avoid doors, exits, warps, player and NPC positions, items,
  Poké Balls, signs, switches, scripted interaction cells and their required
  approaches, and critical traversal corridors.
- The checks cover both the bundled provider and compatible external Wilds
  providers. A provider that cannot expose enough position/collision authority
  fails closed instead of placing an unchecked entity.
- Unsafe saved, orphaned or targeted spawns are repaired deterministically on
  load or map refresh. This does not reroll encounter tables or alter
  Randomizer, Nuzlocke or story progression.

## Controls and menus

- Tap **SELECT** in the overworld to use the saved favourite Field Kit tool.
  Hold **SELECT** for about 0.35 seconds to open the complete kit.
- In the Field Kit, **A** uses a tool, **SELECT** assigns the favourite and
  **B** closes the menu. Cut, Fly, Surf, Strength, Flash, Bicycle and Itemfinder
  keep their normal field checks.
- In the Bag, **SELECT** marks and places an item for sorting, **B** cancels an
  active move or exits, and **START** opens help. The Bicycle no longer steals
  SELECT from a configured Field Kit action.
- Existing saves receive a one-time control-state normalization without
  changing inventory or story data.

## Characters and presentation

- The new authored Red, Green and Blue Crystal walking sheets are now the
  primary overworld sprites. Their previous six-frame sheets remain packaged
  as validated fallbacks; bicycle, fishing, battle, profile, throw and Voxel
  art are unchanged.
- Rival writing once again follows the selected identity across the original
  story, Legend Hunter and Champion rematches. Blue keeps the confident native
  voice; Red is calm, analytical and polite; Green is friendly, humorous and
  occasionally absent-minded. English and German branches are covered.
- Trainer Card character art temporarily uses nearest-neighbour filtering and
  restores the previous graphics state afterward. Pixel art therefore remains
  crisp at scaled window and mobile resolutions.
- Battle Art's retained staged-battle canvas refreshes when an authored Mega
  form advances its animation frame. Battle Art remains the only owner of its
  stage, camera and HUD.
- Battle animation still defaults to **ON**. If a save explicitly set it to
  **OFF**, the update respects that choice; it can be changed under
  **START → ASCENDANT → OPTIONS → VISUALS → POKÉMON SPRITES**.

## Compatibility

- Unique Menu Icons and Dynamic Cries now appear as explicit manager conflicts
  because they register expanded-species icon or cry keys already supplied by
  Ascendant. Keep those standalone packages disabled beside Ascendant.
- All Pokémon Catchable, Kanto Reforged, Modern Party UI and standalone Trainer
  Rematch must also remain disabled. Ascendant already owns their encounter,
  registry, party/summary or rematch surfaces; the manager prevents every
  listed pair from loading together.
- The 6.5.4 best-effort renderer-series policy is unchanged: one official
  Voxel Ascendant, Battle Art, Dramaless or PotatoVoxel build below 3.0.0 may
  run at a time. If an upstream update breaks rendering, roll that renderer
  back to its last working version.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.5.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.5.txt`.

Please report reproducible issues with edition, engine version, platform,
renderer, enabled mods, exact steps and—when progression is involved—a save
file.
