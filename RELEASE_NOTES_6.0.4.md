# Kanto Ascendant 6.0.4 — Prism Grotto and Compatibility Update

Version 6.0.4 expands Driftglass with an optional evolution-item grotto and
Johto Move Resonance while completing the latest Johto presentation,
restart-safety and Shiny-wrapper fixes. It upgrades existing Pokémon Red,
Blue and Yellow saves in place.

## Prism Grotto

- Repairing the Migration Receiver opens a concealed second glass seam at
  Driftglass.
- Six distinct crystal pillars support five short reusable symbol-sequence
  riddles.
- The riddles award one guaranteed Sun Stone, King's Rock, Metal Coat, Dragon
  Scale and Up-Grade.
- A wrong input resets only the current sequence. Completed inscriptions
  remain readable and their rewards cannot duplicate.
- A full Bag preserves an earned item for later collection.
- The repeatable Twilight Mirror rite prepares Eevee for its existing
  day/night evolution conditions without directly evolving it.

## Johto Move Resonance

- The central crystal tablet behind the Prism Reader offers a separate
  optional move function; the six puzzle pillars remain puzzle controls.
- 104 original Kanto species can access compatible Generation-II moves that
  are already implemented by Kanto Ascendant.
- Crystal-compatible TM and inherited access is available immediately.
- Genuine level-up moves retain their original Pokémon Crystal level
  requirement and report the exact required level when locked.
- The tablet never overwrites a full moveset. It directs the player to the
  existing Route 5 Move Deleter, which may also remove HMs while retaining at
  least one move.
- Crystal-taught and deliberately forgotten moves remain available through
  the existing Move Reminder.

## Visual, audio and restart fixes

- Johto species #152-251 consistently register their bundled
  species-authentic Crystal fronts and backs for battle and National Dex
  presentation.
- All Johto species use their bundled legacy cries when no external cry
  provider is active.
- Accepted and declined direct-start choices are committed to the selected
  save immediately, so the onboarding question does not return after a
  restart without another manual save.
- Guaranteed and bonus-roll wild Shinies receive their Shiny state before
  Crystal, Voxel or another non-delegating graphics wrapper selects artwork.
  This prevents a technically Shiny event encounter from appearing in normal
  colours.
- Driftglass and the Prism Grotto retain their distinct native island and cave
  music with imported Red, Blue and Yellow audio. The ROM-less Modkit fixture
  skips those optional references so strict package validation remains
  reproducible.

## Compatibility and save safety

- Pokémon Red, Blue and Yellow.
- English and German.
- New games and existing Kanto Ascendant saves.
- Classic 2D, bundled Crystal art, Crystal Animated Sprites and Voxel paths.
- Optional Wilds of Kanto 1.7.1 visible-encounter link.
- No Johto Signals, Mythic Signals, National Dex, primal-trace, encounter,
  trainer or post-game progress is reset.

## Verification

- Targeted Prism Grotto and move-resonance tests.
- Full ROM-free gameplay and upgrade regression suites.
- Red, Blue and Yellow map-backed tests.
- English/German dialogue layout checks.
- Crystal/Voxel Shiny-wrapper ordering regression.
- Strict Modkit validation, reproducible package build, archive inspection and
  release-boundary audit.
- Isolated launcher import/update and prepared manual UAT saves for every
  edition.
