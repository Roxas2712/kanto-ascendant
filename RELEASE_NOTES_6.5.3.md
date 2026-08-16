# Kanto Ascendant 6.5.3 — Hidden Evolution

Kanto Ascendant 6.5.3 is a save-compatible release for Pokémon Red, Blue and
Yellow. It expands the postgame, improves long-run continuity and repairs a
large set of presentation, input and save/retry edge cases.

This document is intentionally spoiler-light. Players who want exact routes,
requirements or puzzle solutions can use the clearly marked spoiler sections
in `FAQ.md` or the optional offline Hidden Evolution guide included with the
GitHub release.

## Highlights

- Three new character-specific Hidden Evolution trials await RED, BLUE and
  GREEN. Each route has its own maps, traversal rules, knowledge trials and
  final encounter.
- Quiz statues now look different from optional floor-light relics. Their
  expanded question catalog covers Kanto, Johto, general Pokémon knowledge and
  Sinnoh in a deterministic but non-fixed order.
- Questions use the Kanto Ascendant exam presentation with a visible
  20-second timer. The final seal explains which trial requirements are still
  missing without erasing progress.
- Professor Oak's laboratory now has one direct KASC Terminal for advanced
  postgame and run setup. Both visible monitor halves work.
- Randomizer and Nuzlocke choices are fully explained through SELECT and stay
  editable until the explicit final confirmation. Once a run starts, its
  chosen seed and rules remain stable across reloads.
- Long-term Pokémon, item, title and progression continuity has been expanded
  with safer confirmations, clearer transfer rules and modernized storage
  screens. The deeper mechanics are left for players to discover naturally.
- The optional Johto decision is now explicit, defaults to No and receives a
  second safety confirmation before a Kanto-only choice becomes final.
- Kanto Ascendant dialogue now pauses after at most two visible Gen-I lines,
  while authored CONT/page waits and deliberate automatic messages retain
  their intended timing.

## Fixes and presentation

- Professor Oak's hosted postgame presentation keeps the complete native text
  box visible and uses the approved high-resolution Oak portrait when
  available.
- Surprise-trainer losses now resolve the current encounter instead of
  immediately respawning the same challenger.
- Lt. Surge/Major Bob correctly recognizes the canonical Gym victory state,
  allows a previously declined optional reward to be reconsidered and restores
  an already earned but missing Thunderheart without duplicating it.
- Hidden Evolution completion reports, cave visibility helpers, quiz progress,
  save/reload behavior and recovery paths were hardened across all three
  characters.
- Existing question IDs, solved statues, progression receipts and compatible
  Red, Blue and Yellow saves remain valid after updating.

## Compatibility

- Pokémon Red, Blue and Yellow.
- English and German.
- Gen 1 Recomp 0.1.90 or newer; current engine 0.1.96 is included in the
  release acceptance matrix.
- Native 2D and the exact reviewed renderer versions listed in `FAQ.md`.
- Existing Kanto Ascendant saves upgrade in place. No ordinary story,
  inventory, Pokédex or trainer progress is intentionally reset.

Kanto Ascendant already contains its own systems for visible encounters,
followers, Crystal presentation, rematches, bag/quick-select, breeding/gender,
Randomizer and Nuzlocke rules. Disable conflicting standalone versions before
launching the game.

## Install or update

1. Close the game and launcher.
2. Back up important saves, especially before testing irreversible postgame
   choices.
3. Remove or disable older Kanto Ascendant test packages if the launcher keeps
   multiple local builds.
4. Import the `kanto_ascendant-6.5.3.zip` release asset.
5. Resolve every launcher conflict and restart the launcher/game completely.

If upgrading from an older test build that used the `trainer_rematch` package
identity, move that old Kanto Ascendant folder completely out of the mods
directory. Renaming it inside the mods directory is not sufficient.

## Help and full solutions

- Start with the spoiler-free FAQ hints.
- Open the FAQ's clearly marked full-spoiler sections only when you want exact
  access conditions, routes, puzzle answers or postgame rules.
- The optional offline HTML guide contains annotated maps for all three Hidden
  Evolution paths.

Please report reproducible issues with edition, engine version, renderer,
enabled mods, exact steps and—when progression is involved—a save file.
