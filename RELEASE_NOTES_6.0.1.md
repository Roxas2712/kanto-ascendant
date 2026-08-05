# Kanto Ascendant 6.0.1 — Johto Signals Story Hotfix

Version 6.0.1 repairs and rewrites the beginning of the optional Johto
Signals quest. It is a save-compatible hotfix for Red, Blue and Yellow.

## What changed

- Professor Oak now calls after **1–200 eligible steps** once the player has a
  starter and the Pokédex.
- The call places a real dark-capsule object on Pallet Town's southern coast.
- If it remains untouched, Oak gives exactly one reminder after another 400
  eligible steps.
- Declining leaves the object in place. Taking it removes the object and
  permanently stops the reminder.
- The sealed capsule can be opened immediately or later under
  **ASCENDANT → WORLD → JOHTO SIGNALS**.
- Its contents now establish the story clearly: foreign pollen, starry sand,
  a damaged receiver and etched coordinates.
- The Pallet boatman identifies the coordinates before offering passage to
  Driftglass. The researcher then identifies the material and repairs the
  receiver before the player chooses a current.
- English and German dialogue, menu labels, Journal objectives and Mythic
  guidance were rewritten and checked against the Gen-I text width.

## Compatibility

- Existing 6.0 saves upgrade automatically.
- Players who already completed the old capsule interaction keep Driftglass
  access and all receiver, trace, encounter and Mythic progress.
- Players still waiting for the old 128–768-step target are clamped to the new
  200-step maximum.
- Johto and Mythic Signals remain optional and independently configurable.

## Verification

- Red, Blue and Yellow upgrade matrix: restart and mod off/on covered.
- Physical Pallet capsule: spawn, interaction, removal and no-duplication
  covered.
- Full English/German dialogue render: 278 texts and 1,786 rendered lines.
- Johto encounter, Driftglass map, Mythic battle and release-boundary suites
  covered.
