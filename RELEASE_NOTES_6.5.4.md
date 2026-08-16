# Kanto Ascendant 6.5.4 — Stability Hotfix

Kanto Ascendant 6.5.4 is a save-compatible hotfix for Pokémon Red, Blue and
Yellow. It focuses on progression repairs, safer storage, battle and trainer
presentation, and the exact renderer versions reviewed for this release.

No restart is required. Existing Kanto Ascendant saves upgrade in place, and
the Johto repairs are designed to be idempotent when an affected 6.5.3 save is
loaded after updating.

This document remains spoiler-light. Exact habitats, routes and puzzle
solutions stay in the collapsed sections of [FAQ.md](FAQ.md) and the optional
offline Hidden Evolution guide.

## Progression and save repairs

- Fresh campaigns correctly begin the optional Johto Signals cadence after
  the starter and Pokédex milestones.
- A confirmed Johto choice now activates its intended wild distribution in
  Legacy/New Game+ runs, including a repair path for already affected 6.5.3
  saves.
- When Johto becomes available during a normal randomized run, its saved
  deterministic pool expands from #001-151 to #001-251 without rerolling the
  existing seed.
- Legacy storage is available from every player PC in an eligible run.
  Multi-item withdrawals are quantity-aware and atomic.
- The original Kanto starter families have their intended rare early Legacy
  availability. Protected story encounters are not randomized by this change.
- Pre-name character selection keeps the name hidden as `???` until Oak's
  naming confirmation.

## Battles, menus and presentation

- Early difficulty bonuses now phase in with badge progress. Surprise trainers
  also respond more fairly to repeated losses.
- Rematch battlers stay synchronized with their evolved display, and expert AI
  no longer loops recovery moves when recovery is useless.
- Pokédex `AREA`, the Fighting Dojo prize choice and a blocked optional cave
  exit received bounded crash/progression fixes.
- Yellow's follower selection and the genuine partner's evolved portraits work
  again without affecting unrelated Pokémon of the same species.
- Normal 2D battles consistently use the chosen Red, Blue or Green back sprite.
  Original Blue/Green identity presets, scripted catching-tutorial art and
  selected trainer identity are preserved across renderer paths.
- Trainer Cards keep profile art inside the frame, use the approved KASC Gym
  Leader faces and no longer label a fresh zero-badge save as Champion.
- Visual settings are inspectable again and grouped into Pokémon-sprite and
  character/trainer sections.

## Reviewed renderer versions

The 6.5.4 compatibility work is pinned to these exact upstream packages:

- Battle Art `1.9.2`
- Dramaless `2.0.2`
- PotatoVoxel `1.7.2`

These are exact package/version contracts, not a blanket compatibility claim
for adjacent releases, forks, every platform or multi-renderer combinations.
Use only one voxel renderer at a time. Other previously reviewed paths remain
listed in the [FAQ compatibility section](FAQ.md#installation-and-compatibility);
unreviewed combinations continue to fail closed.

## Install or update

1. Close the game and launcher.
2. Back up important saves before testing irreversible postgame choices.
3. Remove or disable older Kanto Ascendant test packages if the launcher keeps
   multiple local builds.
4. Import the `kanto_ascendant-6.5.4.zip` release asset.
5. Resolve every launcher conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.4.txt`.

If upgrading from an older test build that used the `trainer_rematch` package
identity, move that old Kanto Ascendant folder completely out of the mods
directory. Renaming it inside the mods directory is not sufficient.

Please report reproducible issues with edition, engine version, renderer,
enabled mods, exact steps and—when progression is involved—a save file.
