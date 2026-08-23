# Kanto Ascendant 6.5.12 — Legacy Journey, Visual and Rival Hotfix

Kanto Ascendant 6.5.12 is a save-compatible menu, presentation and dialogue hotfix for
Pokémon Red, Blue and Yellow. No new game or story reset is required.

## Legacy Wanderers

- Active Legacy Journeys now have a dedicated path at `START → ASCENDANT →
  OPTIONS → GAMEPLAY → LEGACY NG+`.
- `WANDERER FREQ.` remains a four-way `NEVER / RARE / NORMAL / OFTEN`
  control. New Legacy journeys default to the less intrusive `RARE` cadence.
- Existing explicit frequency choices remain unchanged. `NEVER` stops new
  challengers while already reserved rewards remain deliverable.
- The underlying cadence, safe-field retry, rewards, loss relief and party
  rules are unchanged.

## Saves predating 6.5

- A continued save with no 6.5 character record now applies its selected
  `FIELD CHARACTERS` and `TRAINER PORTRAITS` families to the canonical Red
  player / Blue rival visual pair.
- This compatibility path is visual only. It does not create or alter a hero
  selection, player/rival name, dialogue role, team progression or story
  state.
- A present disabled or unknown/future character record is preserved and is
  never guessed.
- The base game's locked `SPRITE PACK: GAME/KASC` row is unrelated to these
  two controls. They are under `START → ASCENDANT → OPTIONS → VISUALS →
  CHARACTERS / TRAINERS`.

## Red and Green rival dialogue

- Red and Green now keep their selected identity through both Route 22
  victories. Their immediate defeat line and separate walk-away dialogue no
  longer fall back to Blue's edition-native wording.
- The complete Red/Green main-story dialogue surface was reviewed in English
  and German against its actual scene and battle outcome. Red remains concise,
  attentive and confident; Green remains lively and humorous without being
  portrayed as incompetent.
- All 46 bilingual story keys per authored rival preserve runtime placeholders
  and the two-row Gen-I textbox contract. Blue continues to use the active
  Red, Blue or Yellow edition's original dialogue.

## Install or update

1. Close the game and launcher.
2. Back up important saves.
3. Import `kanto_ascendant-6.5.12.zip` through the launcher.
4. Resolve every reported conflict, then restart the launcher and game.

The matching checksum file is `SHA256SUMS-6.5.12.txt`.
