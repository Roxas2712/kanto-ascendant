# Kanto Ascendant 6.5.19 — VASC Compatibility & HUD Hotfix

**Use this version instead of 6.5.18. It includes the complete fix.**

- KASC stays enabled alongside **Voxel Ascendant — Beyond the Horizon (RC66d)**.
- Corrects both the launcher compatibility range and KASC's internal renderer
  admission for the current VASC package version `3.0.0-rc.12`.
- Removes stray gender symbols floating above Pokémon or in the sky when the
  modern VASC/KASC ORAS HP cards have already drawn them.
- Preserves gender symbols in HP cards and normal 2D battles. Stale, failed,
  unknown and classic-renderer frames retain their native fallback.

Based only on public KASC 6.5.17, not the unreleased development branch. Changes
are limited to the manifest and the two renderer/gender presentation modules.
No save migration, gameplay changes, new game or Pokémon-HD redownload.
Pending VASC weather improvements are not part of this KASC hotfix.

## Update

1. Close the game and update KASC to **6.5.19**, or import
   `kanto_ascendant-6.5.19.zip` through the launcher.
2. If the earlier conflict disabled KASC, **enable it again** while keeping VASC
   enabled. Restart the launcher/game.

No VASC reinstall is required. Keep existing backups if you saved while KASC
was disabled; this fix cannot promise to reconstruct missing mod-owned data.

## Verification

Original load conflict reproduced. Version-range and renderer-resolver tests,
public legacy bridge/HUD tests, exact-shot gender ownership/fallback tests and
a native desktop run of the combined released packages were checked. Other
unreviewed VASC versions are not broadly admitted. No physical-phone acceptance
is claimed.
