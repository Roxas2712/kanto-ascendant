# Kanto Ascendant 6.5.18 — VASC Compatibility Hotfix

Fixes the launcher disabling/blocking Kanto Ascendant when used with
**Voxel Ascendant — Beyond the Horizon (RC66d)**.

KASC 6.5.17's compatibility manifest excluded all VASC 3.x versions. This
hotfix explicitly allows the current VASC package version `3.0.0-rc.12`, while
retaining support for the previously approved VASC 0.x/1.x/2.x range and the
blocks on other unreviewed versions.

The downloadable ZIP is the public 6.5.17 package with **only `manifest.json`
changed**. All gameplay code, graphics, save handling and settings are
byte-identical. No new game, migration or Pokémon-HD redownload is required.
This is not the unreleased KASC development branch and does not include the
pending VASC mobile-weather changes.

## Install

1. Close the game and update **Kanto Ascendant to 6.5.18** through the launcher,
   or import `kanto_ascendant-6.5.18.zip`.
2. If the conflict previously disabled KASC, **enable Kanto Ascendant again**;
   updating cannot safely assume it should override your saved enable choices.
3. Keep Voxel Ascendant enabled, then restart the launcher/game.

No VASC reinstallation is needed for this fix. If an important save was played
and saved while KASC was disabled, keep its existing backups; this manifest-only
hotfix does not claim to reconstruct missing mod-owned data.

## Checks

- Reproduced the original `conflicts with VOXEL_ASCENDANT 3.0.0-rc.12` failure.
- Exact package-range regression: current release admitted, older approved
  versions retained, other unreviewed versions still blocked.
- Byte-exact public KASC gender/trainer bridge and mobile HUD capability tests.
- Native desktop smoke using public VASC RC66d and the fixed KASC package:
  both loaded, settings, overworld, MAP battle, team menu and return.

No physical-phone acceptance is claimed. Existing VASC visual issues are not
represented as fixed by this compatibility-only update.
