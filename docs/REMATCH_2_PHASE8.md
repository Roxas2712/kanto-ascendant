# Rematch 2.0 — Phase 8 Rewards and EXP Helpers

Phase 8 adds the complete reward layer without changing Phase-6 trainer
progression or Phase-7 mastery. Ordinary trainer prize money and Pay Day remain
engine-owned and are not replaced or suppressed.

## Reward order

After a qualifying field, Gym, Elite Four or Champion rematch victory:

1. evaluate the one-time EXP Share or next sequential EXP Multiplier unlock;
2. evaluate one normal item stack;
3. if no item was selected, evaluate the additional money table.

Balanced mode awards a normal item on 65% of regular wins and 72% of complete
Level-100-team wins. Generous mode uses 80% and 87%. Post-cap mastery can add at
most three percentage points and at most 25% relative weight to premium item
rows, so rewards never scale without a cap.

The item pool is built only from registered items. It includes all required
Poké/Great/Ultra Ball stack sizes, healing and PP recovery, vitamins, Rare
Candy, PP Up, native stones, and supported Ascendant evolution items. Additional
ordinary registered Balls join automatically. Master Ball, Safari Ball and
unsupported placeholders are explicitly excluded.

The ordinary and Level-100 money tables are fixed integer distributions out of
10,000 and each totals exactly 10,000. A zero result in the ordinary table is a
valid 5% outcome. The Level-100 table ranges from ¥1,000 to ¥8,000.

If the Bag is full, item stacks are reserved and delivered later instead of
being lost. The existing Ascendant loot mode still controls normal item/money
bonuses; special one-time unlocks remain separately eligible.

## EXP Share

The previous ordinary EXP.ALL reward was 5%. Phase 8 replaces it with a
one-time 225/10,000 (2.25%) unlock and stores an explicit persistent flag.
Existing released saves that already own EXP.ALL, store it on the PC, or have
Oak's acquisition flag migrate to the unlock without enabling assistance.

After unlocking, `ASCENDANT -> OPTIONS -> GAMEPLAY -> EXP SHARE` offers:

- OFF;
- CLASSIC, matching the vanilla EXP.ALL allocation path;
- TEAM, with normal participant EXP and half of an undivided award for each
  other healthy party member.

Acquisition always leaves the setting OFF. The physical EXP.ALL remains a
visible shortcut to the focused GAMEPLAY row; it does not toggle the setting.
The explicit unlock remains authoritative while the item is stored on the PC.

## Progressive EXP Multiplier

One `EXP MULTIPLIER` option expands through a strict chain:

| Stage | Eligibility | Exact chance | Available values after unlock |
| --- | --- | ---: | --- |
| ×2 | immediately | 1/300 | OFF, ×2 |
| ×3 | only after ×2 | 1/250 | OFF, ×2, ×3 |
| ×5 | only after ×3 | 1/250 | OFF, ×2, ×3, ×5 |

Unlocked stages are removed from drop eligibility. ×2 creates one physical
shortcut item; ×3 and ×5 expand that same setting and never create duplicate
items or extra menu rows. Every acquisition preserves the current selection,
with first acquisition remaining OFF. Impossible persisted stages and selected
values normalize to the nearest valid sequential state.

EXP allocation runs first. The selected final ×2, ×3 or ×5 multiplier then
wraps the resulting battle EXP exactly once. Unlocks and active selection are
independent of Bag/PC placement.

## Verification

- `tests/rematch_phase8_test.lua`: 130,091 deterministic assertions covering
  every integer ordinary roll, exact money boundaries and totals, required
  item reachability, excluded Balls, special rates, sequential unlocks,
  duplicate prevention, dynamic menu rows, Bag shortcuts, PC storage,
  allocation order, single multiplication and released-save migration.
- Phase-6 and Phase-7 tests remain green.
- Trainer integration, imported recruitment, upgrade matrix, Atlas, field
  economy and 251/251 reachability remain green.
- All follower, Driftglass, Gorochu, Johto Signals, Mythic Signals and Wilds
  compatibility suites remain green.
- strict Modkit validation against imported data passes.
- `tools/rematch_phase8_e2e_driver.lua` runs twice per edition in the isolated
  identity `kanto-ascendant-rematch-phase8-20260808-qa4`, reserved slot 6808.
  Red, Blue and Yellow each pass the write process and a separate reload
  process, including real registry items, Runtime EXP hooks, complete menu
  traversal, shortcut behavior, PC storage and persisted settings.

Phase 9 is outside this change.
