# Rematch 2.0 — Phase 7 Mastery

Phase 7 extends trainer growth without adding levels above 100 and without
changing the Phase-8 reward layer or Phase-9 difficulty options.

## Persistent progression

- Field trainers retain their Phase-6 `rematches` and `trainingCycles` data.
- A separate `masteryWins` counter advances only after a won battle whose
  complete enemy party is already level 100.
- Elite Four, Champion and post-game specialists read their existing,
  persistent `ascendant.bossBattles` count. No second boss history exists.
- Schema version 3 adds only the mastery counter. Missing or malformed values
  normalize to zero, and Phase-6 evolution/recruit history remains intact.

Level 100 is clamped in both the existing level engine and
`rematch_mastery.lua`. Post-cap growth changes only legal Gen-I stat inputs:
DVs remain integer `0..15`, HP DV is derived from the other four DVs, and each
Stat EXP value remains integer `0..65535`. Stats are recalculated through the
engine's `Stats.calc`; final battle stats are never multiplied directly.

## Quality bands

The deterministic trainer/species seed picks a value inside an upward-only
band. Existing higher DVs or Stat EXP are preserved.

| Stage | Target quality |
| --- | ---: |
| First level-100 battle | 70–80% |
| First post-cap wins | 75–85% |
| Established mastery | 80–90% |
| Advanced mastery | 85–95% |
| Long-term mastery | 90–100% |

Specialists and the Champion receive a small capped band bonus, allowing
near-perfect and eventually perfect legal inputs without level 101.

## Moves and team coherence

Candidate moves come only from the Pokémon's authored trainer set, level-1
moves, reached level-up learnset rows, TM/HM list, and the existing legal
Driftglass resonance table. Scoring considers:

- STAB, power, accuracy and damage category;
- coverage not already supplied by the team;
- physical, special, mixed and bulky roles;
- setup, status, recovery and utility;
- duplicate damaging types and mixed tactical/damaging composition.

Authored tactical tools such as `MINIMIZE`, recovery, sleep, paralysis,
`SWORDS_DANCE` and `AMNESIA` are retained when appropriate. This prevents a
Clefairy + Minimize set from being flattened into four high-base-power moves.

The implemented Generation-II move IDs are blocked until the existing
Driftglass receiver has been repaired. The same gate applies to authored,
learnset, TM/HM and resonance candidates, preventing pre-unlock leakage.

The battle AI itself is unchanged. After a legal moveset update, the existing
`aiUsesFor()` path is refreshed so the normal AI sees the current four moves.

## Debug inspection

`exports.rematchMastery.inspect(battle)` returns a copy of the runtime report:

- trainer kind/key, progression and mastery wins;
- Johto gate state and all-level-100 flag;
- per Pokémon: level, tier, quality/band, DVs, Stat EXP, moves, legal sources,
  role and whether optimization changed the set.

This is an internal inspection seam; no player-facing debug UI is added.

## Verification

- `tests/rematch_phase7_test.lua`: early, middle, first L100, three post-cap
  bands, Elite Four and Champion; stat limits, upward stats, tactical set,
  coverage and Johto gate.
- `tests/trainer_rematch_test.lua`: complete ROM-free mod integration.
- `tests/rematch_phase6_test.lua`: Phase-6 progression regression.
- `tests/recruitment_full_data_test.lua`: imported full-data progression.
- `tests/upgrade_matrix_test.lua`: legacy/off-on/reload save matrix.
- `tests/reachability_test.lua`: 251/251 acquisition and reference audit.
- `tools/rematch_phase7_e2e_driver.lua`: real LÖVE write + new-process reload
  in Red, Blue and Yellow, using isolated identity
  `kanto-ascendant-rematch-phase7-20260808` and reserved slot 6707.

Phase 8 rewards are intentionally not implemented or modified here.
