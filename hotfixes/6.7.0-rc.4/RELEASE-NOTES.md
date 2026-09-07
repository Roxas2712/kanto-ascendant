# Kanto Ascendant — NG+ performance hotfix

Public hotfix **6.7.0-rc.4**, following the public RC3 package.

- Fixes recurring multi-second pauses on old NG+ saves by reusing a private,
  save-scoped read view of the Legacy Bank. Writes, migration, validation and
  recovery still use authoritative storage; save switches invalidate the view.
- Removes KASC's always-on diagnostic recorder and reproduction markers.
  It no longer creates/appends KASC-Logs, mirrors the host logger or offers the
  repro-marker menu. Normal engine warnings/errors remain available.
- Retains the RC3 Riolu/Lucario fix and existing gameplay, artwork and save IDs.
- Updated [Red/Blue/Yellow Cards](https://github.com/Roxas2712/kasc-cards/releases/tag/v1.3.0-rc.4)
  pin this exact KASC ZIP plus the existing VASC RC66g (3.0.0-rc.15) ZIP.

## Update

Close Gen1Recomp, keep/back up both saves and mod_storage, and replace the old
KASC installation with `kanto_ascendant-6.7.0-rc.4.zip`. Restart the game.
Card users should also import the edition's updated **1.3.0-rc.4** Card and
install its pinned mods. Card IDs, artwork, options and save scope are retained.
Do not delete the Legacy Bank or import GitHub's automatic source archives.

Card index: https://raw.githubusercontent.com/Roxas2712/kasc-cards/main/kasc-card-index.json

## Validation and limits

The original affected save reproduced approximately 2 seconds of recurring
step processing before the cache fix and 2–6 ms afterward on macOS/0.2.56.
This measures the recurring event processing, not total frame time. The bank
stall was reproduced independently of diagnostic-log growth; removing the
recorder eliminates its overhead but is not claimed as the original cause.

Archive/integrity/migration, NG+ journey/reward and cache regression checks pass.
100,000 disabled diagnostic calls perform no filesystem/graphics access and
do not wrap the normal logger. Native Cart codec/index checks preserve the
three identities, artwork and exact dependency pins.

The final RC4 + VASC RC66g native run also passed: recurring steps took
7.02–9.37 ms (median 8.06 ms); the first migration/save step took 883 ms.
KASC diagnostic recording was confirmed disabled in the running game.

Initial loading and a one-time migration/save can still pause. Windows player
confirmation is pending. No other unfinished 6.7 features are newly enabled.
The previous RC3 package and Cards remain available for rollback; keep saves
and Bank storage when reinstalling. Old diagnostic files are not deleted.

The source snapshot includes the exact four changed Lua files, patch,
hash-pinned packaging script and verification records under `hotfixes/6.7.0-rc.4`.
The installable ZIP is the complete mod.
