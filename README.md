# Kanto Ascendant 6.7 RC3 — Custom Carts + Riolu hotfix

Public **pre-release**. Stable 6.5.22 remains Latest.

## In this update

- Custom Carts for **Red, Blue and Yellow**, using the original edition covers
  and existing Cart/save identities.
- Required, SHA256-pinned pair: **KASC 6.7.0-rc.3 + VASC RC66g (3.0.0-rc.15)**.
- **Riolu can now evolve into Lucario** on a daytime level-up with high
  friendship. It follows KASC's existing friendship/day system: 100 bond;
  AUTO uses 06:00–17:59 local time, or the selected day/night override.
- A hatched, healthy Riolu gains one bond per 64 travel steps, including
  before the postgame research programme opens. Eggs/fainted Riolu do not.
- Verified Riolu gifts can complete this evolution before Johto unlocks.
  Other generation locks stay in place. Shiny status and gift provenance persist.
- Already redeemed eggs/Riolu work after updating; no new gift code needed.

## Install / update

1. **Back up your saves.** Use a Recompiler with Custom Carts/mod indexes
   (tested host: 0.2.56) and your own matching ROM.
2. Add this source under **Find mods** in the launcher:

   https://raw.githubusercontent.com/Roxas2712/kanto-ascendant/codex/kasc-6.7-card-distribution/kasc-card-index.json

3. Import the edition's **1.3.0-rc.3.g1rcart**, install/update its required
   pinned mods, then Play. When updating, replace the old KASC installation.

Manual alternative: import `kanto_ascendant-6.7.0-rc.3.zip` plus VASC's
`Voxel-Ascendant-RC66g-Wildlife-Returns.zip`, then import the Cart.
[VASC RC66g download](https://github.com/Roxas2712/voxel-ascendant/releases/tag/v3.0.0-rc66g).
Do **not** install GitHub's automatically generated Source code archives.
No ROMs are included. Non-Cart save migration is not automatic; keep a backup.

## Scope and limits

This is a narrow hotfix on frozen RC1/RC2, not completion of every 6.7 backlog
item. RC3 changes only the manifest, Riolu's backend evolution/bond registration
and the narrow gift exception in the Kanto evolution gate. Artwork and VASC
code are unchanged. Other backend species do not gain missing evolution rules
merely because they have catalogue entries.

Unfinished later move/item/ability effects, missing form artwork, Gigantamax
battles and Link battles are not newly enabled. VASC's own published limits
remain, including its separately reported graphics-resource issue. A full
physical-device/sprite audit is not claimed.

Cards pin a reviewed pair; arbitrary future VASC releases are not silently
substituted. The host allows deliberately breaking a seal; this is not DRM.
RC1/RC2 assets remain unchanged for rollback. Runtime is in the installable ZIP;
this tag's source snapshot contains distribution records only.
