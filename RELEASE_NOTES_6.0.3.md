# Kanto Ascendant 6.0.3 — National Dex & Wilds Compatibility

Version 6.0.3 makes the Johto Pokédex progression part of the Driftglass
story and adds an optional compatibility bridge for Wilds of Kanto 1.7.1.
It is a save-safe update for Pokémon Red, Blue and Yellow.

## National Dex progression

- Before Driftglass research, the ordinary Pokédex ends at #151.
- Repairing the Migration Receiver upgrades it into the complete National
  Dex through #251.
- A seen Johto species reveals its name and sprite; full measurements and
  description still require catching it.
- Existing 6.0.0-6.0.2 saves with an already active receiver receive the
  National Dex automatically.
- Saves that only started the quest keep their exact progress and receive the
  upgrade normally from the Driftglass researcher.

## Wilds of Kanto 1.7.1

- The optional Visible Johto bridge lets newly generated Wilds overworld
  encounters use the active Johto current and researched habitats.
- The new Wilds Link page reports whether integration is active, disabled or
  unavailable.
- Changing currents, scanning a trace or changing the link setting clears
  stale visible rolls safely.
- Normal and Shiny Johto walkers use six-frame providers without replacing
  the existing Kanto follower provider.

## Verification

- Fresh, quest-started and already-active saves were tested as separate
  migration paths.
- Red, Blue and Yellow are covered in English and German.
- Save/restart, mod disable/re-enable, seen-versus-caught Dex behavior,
  repeated declines, late acceptance and map changes are covered.
- The exact release package passes strict Modkit validation, release-boundary
  auditing and archive inspection.
