# Kanto Ascendant 6.7.0-rc.1 — Frozen Preview

This is a **public pre-release**, not a replacement for stable 6.5.22.
Download **kanto_ascendant-6.7.0-rc.1.zip** from the release assets and import
that ZIP through the Recompiler launcher. Back up your save before testing.

This distribution-only tag records the frozen binary/source-payload archive
and its verification. GitHub's automatically generated “Source code” archives
contain these release records, **not the installable mod**. The installable ZIP
contains the runtime Lua sources and assets. The development worktree and
private maintenance material have not been published by this tag.

## Changes since the last full release, 6.5.22

- New Game+ partner selection adds separate **Random Starter Pool** and
  **Random Global** paths. Your partner and the rival's partner are rolled
  independently; cancelling the selection remains possible.
- New starter habitats and revised exploration areas, including the
  multi-floor Moltres volcano, hidden Regi sanctuaries and Hoenn legendary
  encounters. Current-playthrough event completion controls the relevant
  legendary progression rather than inherited Pokédex ownership alone.
- Separate Rocket raid maps keep the original locations intact, with varied
  team configurations and return handling. Rival journeys add persistent,
  separated encounters and revised dialogue. Full device/visual coverage
  remains a follow-up, not a claim of this preview.
- Extended Legacy Bank support for Gold, Silver and Crystal on hosts with
  the required bank/battle interfaces. Mega equipment permissions copy
  without removing the source equipment; transferred Pokémon retain single
  ownership. Gen-II Mega presentation additionally depends on the companion.
- Internal species identities extend through national number **1025**, with
  separately tracked supported forms and direct/egg/shiny gift profiles.
  **The visible Pokédex is not expanded.** Profiles blocked by missing art or
  runtime support stay unavailable; this is not a promise of every form.
- Expanded front/back sprite coverage and available animations for later
  Pokémon, with static fallback where needed. Existing protected Gen-I/II
  Crystal, Gorochu and Mega artwork is retained. Not every sprite is animated
  and the full visual catalogue review is not complete.
- Generation-aware AUTO/manual rules and learnsets retain earlier legal
  tutor/TM options. Held-item ownership, wild-item rolls, egg handling and
  item separation at the bank are integrated; reward pools use implemented,
  era-approved effects. Only supported ability/move/item effects are active.
- Battle-checkpoint retention for the rule profile and supported effect
  markers, plus the embedded Wilds OFF → map change → ON recovery fix.

## Compatibility — read before installing

The exact paired companion reviewed for this frozen RC is **Voxel Ascendant
RC66f (3.0.0-rc.14)**. **RC66g / 3.0.0-rc.15 is not admitted by this archive.**
Do not assume a newer live VASC works with this RC and do not bypass the
compatibility gate. VASC is not bundled. The future combined Custom Cart is
not part of this release; automatic Cart download/import is not yet approved.

This is a deliberately bounded preview. Gigantamax factors can be preserved,
but Gigantamax battle activation is **not implemented**. Remaining later moves,
abilities, held-item effects and missing form art are follow-up work, not
advertised as complete. Link battles are deferred/disabled for this release.
The finished walkthrough is also deferred.

## Verification and limits

- 227/227 selected regression tests passed on the frozen v57 source.
- Exact source/package parity, required assets, package hygiene and ZIP CRC
  checks passed: 102,362 payload files, 152,279,962 archive bytes.
- The exact archive passed six startup checks: Red, Blue, Yellow (German),
  Gold, Silver and Crystal on the prepared test hosts.
- A native desktop Wilds re-enable flow with RC66f passed. These checks are
  **not** complete playthroughs or physical iOS/Android/Windows certification;
  they do not close the remaining full sprite/transfer/visual review.

The stable release remains 6.5.22. Please include your engine, KASC and VASC
versions, edition, generation settings and reproduction steps in bug reports.

## Frozen archive

SHA256: `bf80c3a844fc8c9f550b496bea74db054b562cac91f81a0f789b42ea2741854c`

The follow-up will be a separately versioned build, not an unnoticed
replacement of this archive.
