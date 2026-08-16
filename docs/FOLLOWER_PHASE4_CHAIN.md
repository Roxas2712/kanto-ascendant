# Follower Phase 4 — True 1–4 Movement Chain

## Scope

Phase 4 extends the native Phase-2 follower transport from one follower to a
generic chain of one through four. It deliberately does not implement the
Phase-5 options UI, persistent PARTY/CUSTOM ordering or rematch work.

The configured runtime count is clamped to `1..4`. Red and Blue select healthy
party members in party order. Yellow keeps its exact marked special partner at
position 1 and fills the remaining positions from healthy party members without
duplicating that object. A smaller valid party produces a shorter chain; no
dummy or duplicate is synthesized.

## Transport architecture

Follower 1 remains the engine's `PikachuFollower` entity. This preserves the
existing, battle-tested movement, route-seam, Yellow happiness, interaction and
script ownership. Followers 2–4 are passable, non-interactive `NPC`-shaped draw
entities owned by Ascendant. They are never added to `ow.npcs`, never receive
`pikachuFollower`, and therefore cannot become a second Yellow story partner or
block/talk like a map NPC.

Each link follows the committed cell vacated by its direct predecessor:

1. follower 1 consumes the player's engine trail;
2. follower 2 consumes follower 1's committed step;
3. follower 3 consumes follower 2's committed step;
4. follower 4 consumes follower 3's committed step.

No extra independently chases the player. Per-link queues and diagnostic
history are bounded to 64 entries. Catch-up uses the same shortened step/two-cell
hop concepts as the native transport, while large forced-coordinate gaps snap
to the predecessor trail instead of growing an unbounded backlog.

Every entity owns an independent cloned sprite definition. Changing or evolving
one party member cannot mutate another follower's sheet, facing, animation
phase or true-colour renderer.

## Lifecycle

- Runtime count transitions rebuild only the necessary tail of the chain.
- A party reorder/species change refreshes the affected visual and identity.
- Normal warps discard stale extras and reconstruct a clean ordered chain.
- Seamless route connections preserve and rebase all four concrete instances,
  their active targets and queued trail cells.
- Bike/surf and engine visibility policy apply to the complete chain.
- Yellow scripted hide/show and Bill's House continue to be owned by the first
  engine follower; extras are hidden during those scenes.
- An external follower mod with the established `activeMon` export still takes
  precedence over Ascendant's native system.

## Verification gates

ROM-free CI runs:

- Phase-1 Johto/Gorochu asset audit;
- Phase-2 Kanto sheet and single-follower regression;
- Phase-3 252-definition registry audit;
- `tests/follower_phase4_chain_test.lua`, covering counts 1–4, all required
  runtime transitions, mixed Raichu → Espeon → Scizor → Tyranitar order,
  direct-predecessor corners/reversals/U-turns, bounded trails, evolution,
  removal, short party, route seam, warp rebuild, hide/show and Yellow dedupe.

`tools/follower_phase4_e2e_driver.lua` is the guarded real-LÖVE gate. It must be
run under an isolated identity containing `follower-phase4`, once for Red, Blue
and Yellow. It uses only reserved save slot 6404 and checks actual 16×96
true-colour renderers and every count transition. Counts 1, 2, 3 and 4 each run
real-input straight/turn/corner/reversal movement, the Pallet/Route 1 seam, a
real building entry and exit, and a Rock Tunnel map entry/walk. The remaining
gate covers bike hide/restore, evolution, removal, short-party behavior,
screenshots and Yellow's scripted visibility/Bill scene.

Real-LÖVE result under `kanto-ascendant-follower-phase4-20260808`:

- Red: pass;
- Blue: pass;
- Yellow: pass, including exact marked-partner ownership, scripted hide/show
  and Bill's House;
- six 1024×768 evidence captures are stored in `qa/follower_phase4/`.

The first Red acceptance run exposed a permanent two-cell gap when a seamless
map swap interrupted an extra follower's final landing frame. Phase 4 now
reconstructs only stretched, idle and commandless links on the new map. The
fixed Red run and the subsequent Blue/Yellow runs pass the same seam assertion,
and the ROM-free test contains a deterministic interrupted-landing regression.

Example command shape:

```sh
cd /path/to/gen1recomp
POKEPORT_IDENTITY=kanto-ascendant-follower-phase4-qa \
POKEPORT_VERSION=red \
POKEPORT_DRIVER=/path/to/kanto-ascendant/tools/follower_phase4_e2e_driver.lua \
POKEPORT_TOUCH=0 \
/path/to/love.app/Contents/MacOS/love .
```

Repeat for `blue` and `yellow`; never point the driver at a normal player
identity.

## Phase boundary

Not implemented here: persistent follower count/mode, PARTY/CUSTOM selection
UI, manual custom ordering, first-follower sprite-style presentation options,
the final options tree or any Rematch 2.0 work. Those belong to Phase 5 or later.
