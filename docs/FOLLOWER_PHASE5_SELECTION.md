# Follower Phase 5 — Selection, Options and Persistence

## Result

Phase 5 completes the native follower system without changing the Phase-4
predecessor-chain transport:

- `FOLLOWER COUNT` is a central one-row option with values 1–4 and default 1.
- `FOLLOWER ORDER` selects `PARTY` or `CUSTOM`, defaulting to `PARTY`.
- Yellow alone receives `YELLOW PARTNER UI`, choosing the existing Ascendant
  corner box or the classic centered Yellow presentation.
- The field party submenu contains a compact `FOLLOWER` action. It can switch
  to CUSTOM and add, remove, or move the selected Pokémon in the saved order.

Red and Blue use the chosen PARTY/CUSTOM order directly. Yellow always places
its exact marked Pikachu/Raichu/Gorochu partner first and deduplicates that save
object from the remaining selection.

## Persistent identity

`follower_config.lua` stores a versioned `follower_config` table in Ascendant's
existing `mod.save` bucket. It contains count, mode, custom string ids, the
Yellow presentation and the next-id counter. A selected Pokémon receives one
small `_ascendantFollowerId` string in its ordinary save table.

No runtime NPC, Lua object address, party index or pointer is serialized. The
marker therefore survives evolution, party reorder, deposit and withdrawal.
Unavailable custom entries are skipped but retained, so Count 4 → 1 → 4 and a
later withdrawal restore the original priority. Duplicate imported markers are
repaired deterministically.

Legacy saves always migrate to 1/PARTY/Ascendant Box. They do not inherit the
last global option value used by a different Red/Blue/Yellow slot. Existing
Phase-5 state is normalized in place without resetting unrelated Ascendant
data.

## Raichu presentation

The Ascendant Raichu/Gorochu talking portraits remain bundled and animated.
The corner renderer now computes the visible non-transparent bounds of each
frame once and centers those bounds inside the 40×40 picture container. This
fixes asymmetric transparent padding without resolution-specific offsets.

The alternative `YELLOW CENTER` mode uses the engine's established centered
Yellow picture box with Ascendant's existing Raichu/Gorochu portrait frames.
`KA-INTERNAL: YELLOW-PRESENTATION-001`

## Verification

ROM-free gates:

- 6,569/6,569 main Ascendant checks;
- 6,603/6,603 upgrade/migration checks;
- Phase-1 through Phase-5 follower contracts;
- strict Modkit package validation;
- the complete Johto Signals, map, Wilds, recruitment and release-audit sets.

Real LÖVE Phase-5 acceptance ran under isolated identity
`kanto-ascendant-follower-phase5-final-20260808`, reserved slot 6505:

- Red: write and process-restart/load pass;
- Blue: write and process-restart/load pass;
- Yellow: write and process-restart/load pass with marked Gorochu, no duplicate,
  both partner presentations and Raichu visual evidence;
- PARTY/CUSTOM, counts 1–4, evolution, real box deposit/withdrawal and party
  reorder all passed.

The full Phase-4 real-input movement/transition matrix was rerun on the final
Phase-5 code in a separate copied identity. Red, Blue and Yellow passed counts
1–4 across walking, corners, reversal, Route 1 seams, building entry/exit,
Rock Tunnel, bike restore, evolution/removal and Yellow Bill visibility.

Visual evidence is under `qa/follower_phase5/`.

## Phase boundary

Phase 5 does not begin Rematch 2.0. RC10, the accepted Phase-4 commit and the
6.0.7 fallback artifacts remain unchanged.
