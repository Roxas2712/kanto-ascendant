# Kanto Ascendant 6.0.0 — Johto Signals

Johto migration can now begin during the Kanto story, but only when the
player chooses an active current. Version 6.0 also adds an independent
Mew/Celebi signal hunt while preserving the normal Kanto opening.

## Early Johto

- After receiving a starter and the Pokédex, a hidden 128–768-step signal can
  lead to a field capsule in Pallet Town. The fifth eligible visit guarantees
  the discovery.
- A warned, reversible boat trip reaches the Driftglass signal station. Its
  return boat is available during every quest stage.
- Repairing the Migration Receiver unlocks three voluntary currents:
  - **Kanto First** keeps early encounters unchanged.
  - **Wanderwaves** adds badge- and habitat-aware Johto encounters at 2%, or
    4% while the signal is strong.
  - **Johto Unleashed** raises the matching habitat share to 10%.
- Four hidden primal traces separately unlock Chikorita, Totodile, Cyndaquil
  and Larvitar. Their names remain `???` until actually seen.
- Trace species use their own protected counters: 1:512 in Wanderwaves and
  1:256 in Johto Unleashed, with the next eligible battle guaranteed at the
  limit.
- The receiver can be changed later under
  **ASCENDANT → WORLD → JOHTO SIGNALS**.

## Mythic Signals

- Mythic Signals are enabled by default but can be disabled independently.
  Rare Mew or Celebi echoes can appear in genuine Kanto grass after the
  Pokédex is active, even before the Migration Receiver is repaired. The first
  echo is guaranteed by roll 512 and later echoes by roll 2048.
- Echoes scale from level 60 up to level 100. They remain at 1 HP, escape
  after one to three turns and reject a Master Ball without consuming it.
- Exactly three echoes, a repaired receiver and four Badges let the
  Driftglass researcher create the Resonance Seal.
- Sealed true manifestations use a protected 1:8192 counter. If one escapes
  or defeats the party, the same Pokémon returns later with its battle state
  preserved instead of requiring another full search.
- Already-owned or disabled Mew/Celebi outcomes are removed from the pool and
  existing story conclusions remain authoritative.

## Integration and save safety

- One shared **WORLD** submenu now contains Johto Signals, Mythic Signals and
  the existing world-event status.
- Turning **EARLY JOHTO** off disables only early migration encounters. With
  **MYTHIC SIGNALS** still on, the shared capsule, receiver and Driftglass
  researcher remain available under the safe Kanto First current.
- Journal and Research Atlas pages show the next optional signal goal without
  replacing Gold or another required main objective.
- Signal locations are localized in English and German, and unseen species
  remain hidden in every Dex-aware view.
- Visible Wilds encounters and ordinary grass battles use the same protected
  selection and pity transactions. Repel, scripted events, roamers, outbreaks
  and other authored encounters cannot consume a guaranteed signal.
- Professor Elm recognizes an already-caught early specimen and gives a safe,
  deterministic research compensation instead of a duplicate Pokémon.
- Existing Red, Blue and Yellow saves upgrade in place through the unchanged
  `trainer_rematch` save namespace. Disabling and re-enabling either signal
  system preserves counters and cannot strand the player away from Kanto.
- A save made during a live Driftglass visit leaves the current visit
  uninterrupted, while continuing that written slot resumes at the native
  Pallet landing.
- The automated upgrade gate uses separate, schema-derived 5.3 fixtures for
  Red, Blue and Yellow and checks fresh Signals defaults, pre- and postgame
  starts, legacy world events, existing Mew/Celebi ownership, native
  encode/decode restart and mod off/on. Player, party, PC, Bag, money, trainer
  and return-map data are protected by assertions. These fixtures pin the
  public 5.3 package hash but are not presented as published player saves;
  original full-save UAT evidence is reported separately when a source is
  available.

Existing Kanto Ascendant saves remain compatible.
