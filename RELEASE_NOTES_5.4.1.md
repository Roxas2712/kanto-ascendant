# Kanto Ascendant 5.4.1 — Thunder Reforged

5.4.1 is a compatibility, progression and visual-quality release for Red,
Blue and Yellow. It keeps existing saves compatible while repairing authored
Ascendant battles under the Gen-I Randomizer and completing Gorochu's intended
quest, presentation and edition-aware audio.

## Highlights

### Randomizer-safe Ascendant battles

Master and Crown Leaders, Apex and Crown Elite battles, Johto Masters, the
Grand Tour, Heritage Cups, research trials, tournaments and hunts now build a
temporary authored party before the Randomizer runs.

The Randomizer remains authoritative for species and moves. Ascendant then
reapplies only the authored team size, slot levels and stats, full HP,
experience, boss AI, rules, rewards and progression metadata. Empty, invalid,
wrong-sized or swallowed output falls back safely, and temporary construction
state is removed after both success and error.

Ordinary field rematches keep their existing order: randomized roster first,
earned recruits second, then persistent rematch and silent-training levels up
to level 100.

### Deterministic Johto recruitment

Once Elm's research exposes an eligible Johto family, suitable field-trainer
classes can add it through normal team growth. Locked families remain absent,
legendary Pokémon remain excluded and each trainer's selected families are
stored per save. Later research unlocks never reroll an existing recruit.

### Independent Pokédex art

The new **DEX SPRITES** option affects Kanto #001-151 only:

- `ORIGINAL` (default) preserves the active Red, Blue or Yellow ROM's
  palette-aware Pokédex fronts.
- `CRYSTAL` uses the bundled static normal frame-one artwork.

This setting never changes battle sprites, Crystal animation, summaries,
icons, followers, evolutions, trades or Hall-of-Fame screens. Johto, guest
species and externally owned sprite registrations retain their own art.

### Gorochu's Thunder Path

The former bond/Thunder/Power-Plant level-up trigger has been replaced:

1. Red and Blue players can accept the permanent **Thunderheart** from
   Lt. Surge after earning the Thunder Badge.
2. Yellow keeps its original-partner trial: walk 251 steps and win three
   trainer battles together, then return to Surge.
3. The Thunderheart points to a silent condenser in the Power Plant's remote
   east wing, away from Zapdos.
4. The condenser creates one consumable **Thunder Tear** and returns the
   permanent Heart to the Bag.
5. Use the Tear outside battle on the Raichu you choose. The evolution is
   permanent.

The **THUNDER PATH / DONNERPFAD** menu entry always reports the next step.
Owning a Heart or Tear does not reveal Gorochu to opposing trainers: they
continue to receive Raichu until the player personally completes the
evolution on that save.

### Complete Gorochu presentation

- Sharp dedicated 96×96 normal/shiny front and back masters for Dramatic
  Shape/Voxel, rendered with nearest-neighbor filtering.
- The existing sharp 2D normal/shiny front, back and six-frame Crystal
  animation remain independent from the Voxel assets.
- Normal/shiny six-pose follower sheets for classic 2D and Voxel follower
  paths.
- Complete animated normal/shiny conversation portraits for both Raichu and
  Gorochu across sleepy, unwell, upset, wary, content, devoted and excited
  moods.
- Yellow NPC dialogue that means the player's tracked partner now follows its
  Pikachu, Raichu or Gorochu identity without rewriting unrelated Pikachu.
- Yellow uses the dedicated spoken Gorochu cry. Red and Blue use a
  Raichu-derived Gen-I chip cry. A Gorochu cry registered by another mod
  always has priority.

## Save and mod compatibility

- Existing Red, Blue and Yellow saves require no manual migration.
- A 5.4.0 save that already completed the player evolution retains Gorochu
  discovery and opponent access.
- Saves from the unpublished Storm Bond prototype that accepted its research
  receive the permanent Thunderheart.
- Existing externally registered Gorochu cries are not overwritten.
- Kanto Ascendant owns Pokédex #152-251; do not enable another complete-Johto
  species mod at the same time.

## Install or update

1. Download `kanto-ascendant-5.4.1.modpkg` from the
   [5.4.1 release](https://github.com/Roxas2712/kanto-ascendant/releases/tag/v5.4.1).
2. Import it through the Gen1 Recomp launcher.
3. Replace the older Kanto Ascendant installation when prompted, then continue
   the same save normally.

The release also provides a byte-identical `.zip` and
`SHA256SUMS-5.4.1.txt` for manual verification.
