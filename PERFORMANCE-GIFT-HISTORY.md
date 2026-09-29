# Immutable gift history memory reduction

`backend_gift_profiles_67.lua` shares identical immutable move-build records
and seven-era revision vectors. It retains all 34 historical revisions and
all profile identities; redemption still copies selected moves. This reduces
the real 3,981-profile catalog from 2,115,277 Lua tables to 36,331 without
changing its values or saved receipt format. Per-species projected learnsets
are reused across gift kinds, and historical selections are recalculated only
at an eligible move's introduction revision. Direct native construction measured
2.60 s before versus 0.58 s after; this is not total application startup.

Validation:
- `tests/gift_history_sharing_test.lua`: exact early/late revision selections,
  era metadata, level-15 versus egg moves, unavailable species, independent
  mutable profile metadata, and sharing of identical revisions.
- VASC native `tests/native/rc19_gift_memory.lua`: exhaustive comparison against
  this file from pre-change HEAD, plus mutation isolation through the real
  `eventArchive.profileForGame` delivery path.
- Native QA host uses this worktree directly. Receipts under project root
  `artifacts/vasc-rc19-lookouts/gift-memory/` and the VASC worktree's
  `docs/rc19-acceptance.md` contain measured heap and rendering results.

This change is needed alongside VASC's global performance changes; a VASC-only
package will not include this KASC memory reduction. No release was packaged.
