# Kanto Ascendant 6.7.12

Public release of the tested 6.7.11 Test-RC9 runtime, retaining its gameplay, UI, optional-content and cache fixes. Version 6.7.11 is intentionally skipped for this public release. Compatible with Voxel Ascendant 3.0.25.

- Optional Pokémon graphics use the in-game download/import catalogue; existing installed graphics can be retained.
- Includes the latest shared verified-cache/startup fixes and the compact elevator floor selector when used with the corresponding VASC presentation.
- Retains KASC's standalone menu presentation, shared content session with VASC, and storage extension without removing occupied boxes.

**Updating an existing installation:** close the game and use the accompanying `KASC-6.7.12-Preserve-Installed-Sprites.tar.gz` installer (Python 3.8+ on desktop). It verifies the package, creates a full backup and preserves installed files omitted from the new release. An ordinary replacing ZIP import may remove formerly bundled optional Pokémon graphics; the ZIP is provided for fresh installations or a deliberate replacement. Downloaded DLC is managed through the in-game content menu. No save reset or ROM is required for the update.

Fully restart after updating. Existing saves and user settings are retained. Runtime files match Test-RC9; this public package updates the version, release documentation and local paths in source-provenance records. Final ZIP CRC and all Lua files are checked. Prior native RC validation was on macOS; no physical mobile or Windows acceptance is claimed.
