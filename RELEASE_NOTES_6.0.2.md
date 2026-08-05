# Kanto Ascendant 6.0.2 — Trainer Name Hotfix

Version 6.0.2 fixes the greeting in Professor Oak's optional Johto Signals
call. It is a save-compatible hotfix for Pokémon Red, Blue and Yellow.

## Fixed

- Professor Oak and Professor Eich now address the trainer by the actual name
  stored in the active save.
- The literal `[PLAYER]` placeholder can no longer appear in either the first
  call or the later reminder.
- A safe localized fallback is used only if a malformed save has no trainer
  name.

## Compatibility

- Existing 6.0 and 6.0.1 saves upgrade in place.
- No quest, encounter, receiver, trace, Mythic or Pokédex progress is reset.
- English and German are covered across Red, Blue and Yellow.

## Verification

- A regression test reproduced the published 6.0.1 defect before the fix.
- The initial call and reminder now use the active save name and reject any
  unresolved placeholder.
- The full Johto Signals dialogue-width suite remains clean.
