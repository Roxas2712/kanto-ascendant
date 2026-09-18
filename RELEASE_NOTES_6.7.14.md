# Kanto Ascendant 6.7.14 — Smaller saves, readable battle sprites & gameplay fixes

Changes since 6.7.13:

- **Smaller saves:** lossless compaction removes unnecessary whitespace from KASC save serialization. Pokémon, boxes and mod data are retained. This reduces size pressure on cloud sync; the server's 2 MiB limit is unchanged, so arbitrarily large saves may still exceed it. Load and save once to apply the compact format.
- **Readable battle sprites with VASC 3.0.29:** publishes verified visible sprite dimensions across full animations, including normal/shiny, Mega and Gorochu artwork. Transparent borders and high-resolution source cards no longer make Pokémon disproportionately large. Form-specific size data and expanded animation canvases are retained.
- **Sprite maintenance:** the integrated sprite-content menus support checking/repairing, reinstalling and removing downloaded content while protecting saves, bundled artwork and imports.
- **Visible Wilds discovery:** fixes the discovery guarantee for eligible visible encounters, including the reported Aron path.
- **Swagger / Flatter:** fixes the associated stat/confusion behavior while respecting native protection and ability rules.
- Retains the 6.7.13 iPhone support-log transport fix and the previous sprite upkeep.

## Updating

Use **KASC 6.7.14 together with VASC 3.0.29** for the complete battle-size update. Update both mods and fully restart the game. Existing saves remain compatible. Keep downloaded/imported sprite content; do not delete the existing mod folders first. The ZIP is the normal mod package. For manual desktop updates, the optional **Preserve-Installed-Sprites** installer creates a backup and preserves optional downloads; follow its included instructions.

## Validation

The reviewed release-candidate runtime is unchanged. Tests covered 1,351 canonical height/form entries, 78,779 PNG records in 6,153 animation/palette groups, 382 animated variants / 3,921 frames and 424 static variants. Native macOS tests included Pikachu versus Manectric and Wailord, Crystal mode, Mega Manectric and Gorochu, plus 1X/3X MAP camera checks. All packaged Lua files, archive integrity and installer preservation checks passed. Fifteen additional gameplay regression tests passed.

Not every form has been manually played. Physical mobile-device and live cloud-sync verification remain pending.
